import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import crypto from 'crypto';
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
    const { device_id, device_type, device_name, firmware_version, ip_address, mac_address, hotel_id } = data;

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

        // 更新现有设备信息
        await pool.query<ResultSetHeader>(
          `UPDATE devices SET
            firmware_version = COALESCE(?, firmware_version),
            ip_address = COALESCE(?, ip_address),
            mac_address = COALESCE(?, mac_address),
            last_seen = NOW(),
            device_status = 'online',
            hotel_id = ?
          WHERE device_id = ?`,
          [firmware_version, ip_address, mac_address, hotel_id, device_id]
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
        // 创建新设备，状态为待审核
        await pool.query<ResultSetHeader>(
          `INSERT INTO devices (
            device_id, device_type, device_name, device_key,
            device_status, firmware_version, last_seen,
            audit_status, ip_address, mac_address, hotel_id
          ) VALUES (?, ?, ?, ?, ?, ?, NOW(), ?, ?, ?, ?)`,
          [
            device_id,
            device_type || 'unknown',
            device_name || `New Device ${device_id}`,
            '', // 初始 key 为空，审核通过后再生成
            'online',
            firmware_version,
            'pending',
            ip_address,
            mac_address,
            hotel_id
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
        'SELECT device_key, audit_status FROM devices WHERE id = ?',
        [id]
      );
      
      const currentDevice = currentRows[0];
      let device_key = currentDevice?.device_key || '';

      // 只有在第一次从非 approved 变为 approved 时，或者没有 key 时，才生成新 key
      if (status === 'approved' && (!device_key || currentDevice?.audit_status !== 'approved')) {
        device_key = crypto.randomBytes(16).toString('hex');
      }

      await pool.query<ResultSetHeader>(
        `UPDATE devices SET
          audit_status = ?,
          device_key = ?,
          room_id = ?,
          area = ?,
          device_name = COALESCE(?, device_name),
          updated_at = NOW()
        WHERE id = ?`,
        [status, device_key, room_id || null, area || null, device_name || null, id]
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

      return {
        id,
        status,
        device_key: status === 'approved' ? device_key : null,
        room_id,
        room_number,
        area,
        device_name
      };
    } catch (error) {
      logger.error('Error auditing device:', error.message);
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
