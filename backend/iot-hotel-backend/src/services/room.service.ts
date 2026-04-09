import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';

export interface Room extends RowDataPacket {
  id: number;
  room_number: string;
  room_type: string;
  room_type_id: number;
  room_name: string;
  room_price: number;
  room_status: string;
  floor: number;
  area: number;
  bed_type: string;
  max_guests: number;
  description: string;
  facilities: string;
  images: string;
  created_at: Date;
  updated_at: Date;
  // Join fields
  room_type_name?: string;
  room_type_code?: string;
}

export interface RoomListResponse {
  list: Room[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

export class RoomService {
  private static tableCache = new Map<string, boolean>();

  private static async hasTable(tableName: string): Promise<boolean> {
    if (this.tableCache.has(tableName)) {
      return this.tableCache.get(tableName) as boolean;
    }
    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT COUNT(*) AS total
       FROM information_schema.TABLES
       WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?`,
      [tableName]
    );
    const exists = Number((rows[0] as any)?.total || 0) > 0;
    this.tableCache.set(tableName, exists);
    return exists;
  }

  static async getRooms(params: {
    page?: number;
    pageSize?: number;
    status?: string;
    type?: string;
    floor?: number;
    hotelId: number;
  }): Promise<RoomListResponse> {
    try {
      const { page = 1, pageSize = 10, status, type, floor, hotelId } = params;
      const offset = (Number(page) - 1) * Number(pageSize);
      const hasRoomTypesTable = await this.hasTable('room_types');
      
      let whereClause = 'WHERE r.hotel_id = ?';
      const paramsArray: any[] = [hotelId];
      
      if (status) {
        whereClause += ' AND r.room_status = ?';
        paramsArray.push(status);
      }
      
      if (type) {
        if (hasRoomTypesTable) {
          whereClause += ' AND (r.room_type = ? OR rt.code = ?)';
          paramsArray.push(type, type);
        } else {
          whereClause += ' AND r.room_type = ?';
          paramsArray.push(type);
        }
      }

      if (floor) {
        whereClause += ' AND r.floor = ?';
        paramsArray.push(Number(floor));
      }
      
      const totalSql = hasRoomTypesTable
        ? `SELECT COUNT(*) as total
           FROM rooms r
           LEFT JOIN room_types rt ON r.room_type_id = rt.id
           ${whereClause}`
        : `SELECT COUNT(*) as total
           FROM rooms r
           ${whereClause}`;
      const [totalRows] = await pool.query<RowDataPacket[]>(totalSql, paramsArray);
      const total = (totalRows[0] as any).total;
      
      const listSql = hasRoomTypesTable
        ? `SELECT r.*, rt.name as room_type_name, rt.code as room_type_code
           FROM rooms r
           LEFT JOIN room_types rt ON r.room_type_id = rt.id
           ${whereClause}
           ORDER BY r.floor ASC, r.room_number ASC
           LIMIT ? OFFSET ?`
        : `SELECT r.*, r.room_type as room_type_name, r.room_type as room_type_code
           FROM rooms r
           ${whereClause}
           ORDER BY r.floor ASC, r.room_number ASC
           LIMIT ? OFFSET ?`;
      const [rows] = await pool.query<RowDataPacket[]>(listSql, [...paramsArray, Number(pageSize), offset]);
      
      return {
        list: rows as Room[],
        total,
        page: Number(page),
        pageSize: Number(pageSize),
        totalPages: Math.ceil(total / Number(pageSize))
      };
    } catch (error) {
      logger.error('获取房间列表失败:', error);
      throw new Error('获取房间列表失败');
    }
  }

  static async getRoomsByFloor(hotelId: number): Promise<any> {
    try {
      const hasRoomTypesTable = await this.hasTable('room_types');
      const listByFloorSql = hasRoomTypesTable
        ? `SELECT r.*, rt.name as room_type_name, rt.code as room_type_code
           FROM rooms r
           LEFT JOIN room_types rt ON r.room_type_id = rt.id
           WHERE r.hotel_id = ?
           ORDER BY r.floor ASC, r.room_number ASC`
        : `SELECT r.*, r.room_type as room_type_name, r.room_type as room_type_code
           FROM rooms r
           WHERE r.hotel_id = ?
           ORDER BY r.floor ASC, r.room_number ASC`;
      const [rows] = await pool.query<RowDataPacket[]>(listByFloorSql, [hotelId]);

      const grouped: Record<number, Room[]> = {};
      rows.forEach((row) => {
        const floor = row.floor;
        if (!grouped[floor]) {
          grouped[floor] = [];
        }
        grouped[floor].push(row as Room);
      });

      return Object.keys(grouped).map(floor => ({
        floor: Number(floor),
        rooms: grouped[Number(floor)]
      }));
    } catch (error) {
      logger.error('按楼层获取房间失败:', error);
      throw new Error('按楼层获取房间失败');
    }
  }

  static async getRoomById(id: number, hotelId: number): Promise<Room | null> {
    try {
      const hasRoomTypesTable = await this.hasTable('room_types');
      const getByIdSql = hasRoomTypesTable
        ? `SELECT r.*, rt.name as room_type_name, rt.code as room_type_code
           FROM rooms r
           LEFT JOIN room_types rt ON r.room_type_id = rt.id
           WHERE r.id = ? AND r.hotel_id = ?`
        : `SELECT r.*, r.room_type as room_type_name, r.room_type as room_type_code
           FROM rooms r
           WHERE r.id = ? AND r.hotel_id = ?`;
      const [rows] = await pool.query<RowDataPacket[]>(getByIdSql, [id, hotelId]);
      return (rows[0] as Room) || null;
    } catch (error) {
      logger.error('获取房间详情失败:', error);
      throw new Error('获取房间详情失败');
    }
  }

  static async createRoom(data: Partial<Room> & { hotel_id: number }): Promise<number> {
    try {
      const { room_number, room_type_id, room_type, room_name, room_price, room_status, floor, area, bed_type, max_guests, description, facilities, images, hotel_id } = data;
      
      // 检查是否存在 room_type_id 字段
      const [columns] = await pool.query<RowDataPacket[]>(
        `SELECT COLUMN_NAME 
         FROM information_schema.COLUMNS 
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'rooms' AND COLUMN_NAME = 'room_type_id'`
      );
      const hasRoomTypeId = columns.length > 0;
      
      let sql: string;
      let values: any[];
      
      if (hasRoomTypeId) {
        // 使用 room_type_id 字段
        sql = `INSERT INTO rooms (room_number, room_type_id, room_name, room_price, room_status, floor, area, bed_type, max_guests, description, facilities, images, hotel_id) 
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`;
        values = [room_number, room_type_id, room_name, room_price, room_status, floor, area, bed_type, max_guests, description, JSON.stringify(facilities || []), JSON.stringify(images || []), hotel_id];
      } else {
        // 使用 room_type 字段（字符串类型）
        sql = `INSERT INTO rooms (room_number, room_type, room_name, room_price, room_status, floor, area, bed_type, max_guests, description, facilities, images, hotel_id) 
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`;
        values = [room_number, room_type || 'standard', room_name, room_price, room_status, floor, area, bed_type, max_guests, description, JSON.stringify(facilities || []), JSON.stringify(images || []), hotel_id];
      }
      
      const [result] = await pool.query<ResultSetHeader>(sql, values);
      
      return result.insertId;
    } catch (error) {
      logger.error('创建房间失败:', error);
      throw new Error('创建房间失败');
    }
  }

  static async updateRoom(id: number, hotelId: number, data: Partial<Room>): Promise<boolean> {
    try {
      const { room_number, room_type_id, room_type, room_name, room_price, room_status, floor, area, bed_type, max_guests, description, facilities, images } = data;
      
      // 检查是否存在 room_type_id 字段
      const [columns] = await pool.query<RowDataPacket[]>(
        `SELECT COLUMN_NAME 
         FROM information_schema.COLUMNS 
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'rooms' AND COLUMN_NAME = 'room_type_id'`
      );
      const hasRoomTypeId = columns.length > 0;
      
      let sql: string;
      let values: any[];
      
      if (hasRoomTypeId) {
        // 使用 room_type_id 字段
        sql = `UPDATE rooms SET 
          room_number = COALESCE(?, room_number), 
          room_type_id = COALESCE(?, room_type_id), 
          room_name = COALESCE(?, room_name), 
          room_price = COALESCE(?, room_price), 
          room_status = COALESCE(?, room_status), 
          floor = COALESCE(?, floor), 
          area = COALESCE(?, area), 
          bed_type = COALESCE(?, bed_type), 
          max_guests = COALESCE(?, max_guests), 
          description = COALESCE(?, description), 
          facilities = ?, 
          images = ?, 
          updated_at = CURRENT_TIMESTAMP 
        WHERE id = ? AND hotel_id = ?`;
        values = [room_number, room_type_id, room_name, room_price, room_status, floor, area, bed_type, max_guests, description, JSON.stringify(facilities || []), JSON.stringify(images || []), id, hotelId];
      } else {
        // 使用 room_type 字段（字符串类型）
        sql = `UPDATE rooms SET 
          room_number = COALESCE(?, room_number), 
          room_type = COALESCE(?, room_type), 
          room_name = COALESCE(?, room_name), 
          room_price = COALESCE(?, room_price), 
          room_status = COALESCE(?, room_status), 
          floor = COALESCE(?, floor), 
          area = COALESCE(?, area), 
          bed_type = COALESCE(?, bed_type), 
          max_guests = COALESCE(?, max_guests), 
          description = COALESCE(?, description), 
          facilities = ?, 
          images = ?, 
          updated_at = CURRENT_TIMESTAMP 
        WHERE id = ? AND hotel_id = ?`;
        values = [room_number, room_type, room_name, room_price, room_status, floor, area, bed_type, max_guests, description, JSON.stringify(facilities || []), JSON.stringify(images || []), id, hotelId];
      }
      
      const [result] = await pool.query<ResultSetHeader>(sql, values);
      
      return result.affectedRows > 0;
    } catch (error) {
      logger.error('更新房间失败:', error);
      throw new Error('更新房间失败');
    }
  }

  static async deleteRoom(id: number, hotelId: number): Promise<boolean> {
    try {
      const [result] = await pool.query<ResultSetHeader>('DELETE FROM rooms WHERE id = ? AND hotel_id = ?', [id, hotelId]);
      return result.affectedRows > 0;
    } catch (error) {
      logger.error('删除房间失败:', error);
      throw new Error('删除房间失败');
    }
  }
}
