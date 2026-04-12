import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import crypto from 'crypto';

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

        return {
          status: 'existing',
          audit_status: device.audit_status,
          device_key: device.audit_status === 'approved' ? device.device_key : null
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
   * 管理员审核设备
   */
  async auditDevice(id: number, status: 'approved' | 'rejected', assignment?: { room_id?: number; area?: string }) {
    try {
      let device_key = '';
      if (status === 'approved') {
        // 生成唯一的设备密钥，用于后续通信签名
        device_key = crypto.randomBytes(16).toString('hex');
      }

      const { room_id, area } = assignment || {};

      await pool.query<ResultSetHeader>(
        `UPDATE devices SET 
          audit_status = ?, 
          device_key = CASE WHEN ? = 'approved' THEN ? ELSE device_key END,
          room_id = ?,
          area = ?,
          updated_at = NOW()
        WHERE id = ?`,
        [status, status, device_key, room_id || null, area || null, id]
      );

      return {
        id,
        status,
        device_key: status === 'approved' ? device_key : null
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
      const [rows] = await pool.query<RowDataPacket[]>(
        'SELECT * FROM devices WHERE audit_status = ? ORDER BY created_at DESC',
        ['pending']
      );
      return rows as DeviceData[];
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
      const params: any[] = [];

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
      const params: any[] = [id];
      if (hasDeviceHotelId) {
        query += ' AND d.hotel_id = ?';
        params.push(hotelId);
      } else if (hasDeviceRoomId) {
        query += ' AND r.hotel_id = ?';
        params.push(hotelId);
      }
      const [rows] = await pool.query<RowDataPacket[]>(query, params);
      return rows.length > 0 ? (rows[0] as DeviceData) : null;
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
      return true;
    } catch (error) {
      logger.error('Error deleting device:', error.message);
      throw error;
    }
  }
}

export default new DeviceService();
