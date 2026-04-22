import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import crypto from 'crypto';
import { hashDeviceKey, encryptDeviceKey, generateSecureDeviceKey, verifyDeviceKey, getKeyStorageFormat } from '../utils/device-key';
import CacheService from './cache.service';

export interface DeviceData {
  id?: number;
  hotel_id?: number;
  device_id: string;
  device_type: string;
  device_name: string;
  device_key?: string;
  device_status: string;
  firmware_version?: string;
  last_seen?: Date;
  audit_status: 'pending' | 'approved' | 'rejected';
  room_id?: number;
  room_number?: string;
  area?: string;
  ip_address?: string;
  mac_address?: string;
}

class DeviceService {
  private columnCache = new Map<string, boolean>();

  private async hasColumn(table: string, column: string): Promise<boolean> {
    const key = `${table}.${column}`;
    if (this.columnCache.has(key)) {
      return this.columnCache.get(key) as boolean;
    }
    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT COUNT(*) AS total
       FROM information_schema.COLUMNS
       WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
      [table, column]
    );
    const exists = Number((rows[0] as any)?.total || 0) > 0;
    this.columnCache.set(key, exists);
    return exists;
  }

  /**
   * 硬件设备上报注册/连接信息
   */
  async registerDevice(data: Partial<DeviceData> & { hotel_id: number }) {
    const { device_id, device_type, device_name, firmware_version, ip_address, mac_address, hotel_id, room_number: requested_room_number } = data;

    if (!device_id) {
      throw new Error('Device ID is required');
    }

    try {
      // 检查设备是否已存在
      const [rows] = await pool.query<RowDataPacket[]>(
        'SELECT * FROM devices WHERE device_id = ?',
        [device_id]
      );

      if (rows.length > 0) {
        const device = rows[0] as DeviceData;
        let final_room_id = device.room_id;

        // 如果请求中包含房号，尝试查找并关联（仅当设备未分配房间或管理员允许覆盖时）
        if (requested_room_number) {
          const [roomRows] = await pool.query<RowDataPacket[]>(
            'SELECT id FROM rooms WHERE room_number = ? AND hotel_id = ?',
            [requested_room_number, hotel_id]
          );
          if (roomRows.length > 0) {
            final_room_id = roomRows[0].id;
          }
        }

        // 更新现有设备信息
        await pool.query<ResultSetHeader>(
          `UPDATE devices SET
            firmware_version = COALESCE(?, firmware_version),
            ip_address = COALESCE(?, ip_address),
            mac_address = COALESCE(?, mac_address),
            last_seen = NOW(),
            device_status = 'online',
            hotel_id = ?,
            room_id = COALESCE(?, room_id)
          WHERE device_id = ?`,
          [firmware_version, ip_address, mac_address, hotel_id, final_room_id, device_id]
        );

        // 清除相关缓存，确保设备状态更新
        await CacheService.delete(CacheService.deviceKeys.info(device.id!));
        await CacheService.deletePattern('device:list:*');

        // 获取更新后的详细信息，包括关联房间号
        const [updatedRows] = await pool.query<RowDataPacket[]>(
          `SELECT d.*, r.room_number 
           FROM devices d 
           LEFT JOIN rooms r ON d.room_id = r.id 
           WHERE d.device_id = ?`,
          [device_id]
        );
        const updatedDevice = updatedRows[0] as any;

        return {
          status: 'existing',
          audit_status: updatedDevice.audit_status,
          device_key: updatedDevice.audit_status === 'approved' ? updatedDevice.device_key : null,
          room_id: updatedDevice.room_id,
          room_number: updatedDevice.room_number,
          area: updatedDevice.area,
          device_name: updatedDevice.device_name,
          device_id: updatedDevice.device_id
        };
      } else {
        // 创建新设备时，如果提供了房号也尝试关联
        let initial_room_id: number | null = null;
        if (requested_room_number) {
          const [roomRows] = await pool.query<RowDataPacket[]>(
            'SELECT id FROM rooms WHERE room_number = ? AND hotel_id = ?',
            [requested_room_number, hotel_id]
          );
          if (roomRows.length > 0) {
            initial_room_id = roomRows[0].id;
          }
        }

        // 创建新设备，状态为待审核
        await pool.query<ResultSetHeader>(
          `INSERT INTO devices (
            device_id, device_type, device_name, device_key,
            device_status, firmware_version, last_seen,
            audit_status, ip_address, mac_address, hotel_id, room_id
          ) VALUES (?, ?, ?, ?, ?, ?, NOW(), ?, ?, ?, ?, ?)`,
          [
            device_id,
            device_type || 'unknown',
            device_name || `New Device ${device_id}`,
            '', 
            'online',
            firmware_version,
            'pending',
            ip_address,
            mac_address,
            hotel_id,
            initial_room_id
          ]
        );

        // 清除待审核设备列表缓存，确保新注册设备能立即显示
        await CacheService.delete(CacheService.deviceKeys.pending());
        await CacheService.deletePattern('device:list:*');

        return {
          status: 'new',
          audit_status: 'pending',
          device_key: null
        };
      }
    } catch (error) {
      logger.error('Error registering device:', error.message);
      throw error;
    }
  }

  /**
   * 管理员审核或重新分配设备位置
   */
  async auditDevice(id: number, status: 'approved' | 'rejected', assignment?: { room_id?: number; area?: string; device_name?: string }) {
    try {
      const { room_id, area, device_name } = assignment || {};

      // 获取当前设备信息，检查是否已有 key
      const [currentRows] = await pool.query<RowDataPacket[]>(
        'SELECT device_id, device_type, device_key, device_key_encrypted, audit_status, hotel_id FROM devices WHERE id = ?',
        [id]
      );
      
      const currentDevice = currentRows[0];
      if (!currentDevice) {
        throw new Error('Device not found');
      }

      // 注意：currentDevice.device_key 现在存储的是哈希值
      // device_key_encrypted 存储的是AES加密的原始密钥（用于签名验证）
      let rawDeviceKey = '';
      const hasExistingKey = currentDevice?.device_key && currentDevice.device_key !== '';

      // 只有在第一次从非 approved 变为 approved 时，或者没有 key 时，才生成新 key
      if (status === 'approved' && (!hasExistingKey || currentDevice?.audit_status !== 'approved')) {
        // 生成新的原始设备密钥（用于下发给硬件）
        rawDeviceKey = generateSecureDeviceKey();
      }

      // 将密钥哈希后存储到 device_key 列
      const deviceKeyHash = rawDeviceKey ? hashDeviceKey(rawDeviceKey) : (currentDevice?.device_key || '');
      // 将原始密钥加密后存储到 device_key_encrypted 列（用于签名验证）
      const deviceKeyEncrypted = rawDeviceKey ? encryptDeviceKey(rawDeviceKey) : (currentDevice?.device_key_encrypted || null);

      await pool.query<ResultSetHeader>(
        `UPDATE devices SET
          audit_status = ?,
          device_key = ?,
          device_key_encrypted = ?,
          room_id = ?,
          device_name = COALESCE(?, device_name),
          updated_at = NOW()
        WHERE id = ?`,
        [status, deviceKeyHash, deviceKeyEncrypted, room_id || null, device_name || null, id]
      );

      // 清除相关缓存
      await CacheService.delete(CacheService.deviceKeys.info(id));
      await CacheService.delete(CacheService.deviceKeys.pending());
      await CacheService.deletePattern('device:list:*');

      // 获取分配后的房号
      let room_number = '';
      if (room_id) {
        const [roomRows] = await pool.query<RowDataPacket[]>(
          'SELECT room_number FROM rooms WHERE id = ?',
          [room_id]
        );
        if (roomRows.length > 0) {
          room_number = roomRows[0].room_number;
        }
      }

      // --- 关键修复：同步清除 MQTT 服务缓存并通知硬件 ---
      const mqttService = require('./mqtt.service').default;
      mqttService.clearDeviceCache(currentDevice.device_id);

      // 主动推送配置更新到硬件
      // 注意：只有在生成新密钥时才下发原始密钥，否则硬件已经有密钥
      mqttService.publish(`hotel/device/config/${currentDevice.device_type}/${currentDevice.device_id}`, {
        device_id: currentDevice.device_id,
        audit_status: status,
        // 只在首次审批时下发原始密钥，后续不再下发
        device_key: (status === 'approved' && rawDeviceKey) ? rawDeviceKey : null,
        room_id: room_id,
        room_number: room_number,
        hotel_id: currentDevice.hotel_id,
        timestamp: new Date().toISOString()
      });

      // 触发 WebSocket 广播，确保前台界面的在线列表和审核状态同步更新
      const websocketService = require('./websocket.service').default;
      websocketService.broadcastOnlineStatus().catch((err: any) => 
        logger.error('[DeviceService] 审核后广播失败:', err.message)
      );

      return {
        id,
        status,
        device_key: (status === 'approved' && rawDeviceKey) ? rawDeviceKey : null,
        room_id,
        room_number,
        device_name
      };
    } catch (error) {
      logger.error('Error auditing device:', error);
      throw error;
    }
  }

  /**
   * 获取待审核设备列表
   */
  async getPendingDevices() {
    try {
      return await CacheService.getOrSet(
        CacheService.deviceKeys.pending(),
        async () => {
          const [rows] = await pool.query<RowDataPacket[]>(
            'SELECT * FROM devices WHERE audit_status = ? ORDER BY created_at DESC',
            ['pending']
          );
          return rows as DeviceData[];
        },
        { ttl: 60 }
      );
    } catch (error) {
      logger.error('Error getting pending devices:', error.message);
      throw error;
    }
  }

  /**
   * 获取所有设备列表（支持过滤）
   */
  async getAllDevices(hotelId?: number, filters?: { status?: string; audit_status?: string; room_id?: number }) {
    try {
      const cacheKey = CacheService.generateKey(
        CacheService.deviceKeys.list(hotelId || 0),
        JSON.stringify(filters || {})
      );

      return await CacheService.getOrSet(
        cacheKey,
        async () => {
          const hasDeviceHotelId = await this.hasColumn('devices', 'hotel_id');
          const hasDeviceRoomId = await this.hasColumn('devices', 'room_id');
          const hasDeviceAuditStatus = await this.hasColumn('devices', 'audit_status');
          const selectFields = ['d.*'];
          if (hasDeviceRoomId) {
            selectFields.push('r.room_number');
          }
          selectFields.push('h.hotel_name');
          let query = `SELECT ${selectFields.join(', ')} FROM devices d`;
          if (hasDeviceRoomId) {
            query += ' LEFT JOIN rooms r ON d.room_id = r.id';
          }
          if (hasDeviceHotelId) {
            query += ' LEFT JOIN hotels h ON d.hotel_id = h.id';
          } else if (hasDeviceRoomId) {
            query += ' LEFT JOIN hotels h ON r.hotel_id = h.id';
          } else {
            query += ' LEFT JOIN hotels h ON 1 = 0';
          }
          query += ' WHERE 1=1';
          const params: unknown[] = [];

          if (hotelId) {
            if (hasDeviceHotelId) {
              query += ' AND d.hotel_id = ?';
              params.push(hotelId);
            } else if (hasDeviceRoomId) {
              query += ' AND r.hotel_id = ?';
              params.push(hotelId);
            }
          }

          if (filters?.status) {
            query += ' AND d.device_status = ?';
            params.push(filters.status);
          }
          if (filters?.audit_status) {
            if (hasDeviceAuditStatus) {
              query += ' AND d.audit_status = ?';
              params.push(filters.audit_status);
            }
          }
          if (filters?.room_id) {
            if (hasDeviceRoomId) {
              query += ' AND d.room_id = ?';
              params.push(filters.room_id);
            }
          }

          query += ' ORDER BY d.updated_at DESC';

          const [rows] = await pool.query<RowDataPacket[]>(query, params);
          return rows;
        },
        { ttl: 300 }
      );
    } catch (error) {
      logger.error('Error getting devices:', error.message);
      throw error;
    }
  }

  /**
   * 获取单个设备详情
   */
  async getDeviceById(id: number, hotelId: number) {
    try {
      return await CacheService.getOrSet(
        CacheService.deviceKeys.info(id),
        async () => {
          const hasDeviceHotelId = await this.hasColumn('devices', 'hotel_id');
          const hasDeviceRoomId = await this.hasColumn('devices', 'room_id');
          let query = 'SELECT d.*';
          if (hasDeviceRoomId) {
            query += ', r.room_number';
          }
          query += ' FROM devices d';
          if (hasDeviceRoomId) {
            query += ' LEFT JOIN rooms r ON d.room_id = r.id';
          }
          query += ' WHERE d.id = ?';
          const params: unknown[] = [id];
          if (hasDeviceHotelId) {
            query += ' AND d.hotel_id = ?';
            params.push(hotelId);
          } else if (hasDeviceRoomId) {
            query += ' AND r.hotel_id = ?';
            params.push(hotelId);
          }
          const [rows] = await pool.query<RowDataPacket[]>(query, params);
          return rows.length > 0 ? (rows[0] as DeviceData) : null;
        },
        { ttl: 300 }
      );
    } catch (error) {
      logger.error('Error getting device by id:', error.message);
      throw error;
    }
  }

  /**
   * 删除设备
   */
  async deleteDevice(id: number, hotelId: number) {
    try {
      const hasDeviceHotelId = await this.hasColumn('devices', 'hotel_id');
      const hasDeviceRoomId = await this.hasColumn('devices', 'room_id');
      if (hasDeviceHotelId) {
        await pool.query<ResultSetHeader>('DELETE FROM devices WHERE id = ? AND hotel_id = ?', [id, hotelId]);
      } else if (hasDeviceRoomId) {
        await pool.query<ResultSetHeader>(
          `DELETE d FROM devices d
           LEFT JOIN rooms r ON d.room_id = r.id
           WHERE d.id = ? AND r.hotel_id = ?`,
          [id, hotelId]
        );
      } else {
        await pool.query<ResultSetHeader>('DELETE FROM devices WHERE id = ?', [id]);
      }

      // 清除相关缓存
      await CacheService.delete(CacheService.deviceKeys.info(id));
      await CacheService.delete(CacheService.deviceKeys.pending());
      await CacheService.deletePattern('device:list:*');

      return true;
    } catch (error) {
      logger.error('Error deleting device:', error.message);
      throw error;
    }
  }
}

export default new DeviceService();
