import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import CacheService from './cache.service';

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
    room_type_id?: number;
    floor?: number;
    hotelId: number;
  }): Promise<RoomListResponse> {
    try {
      const { page = 1, pageSize = 10, status, type, room_type_id, floor, hotelId } = params;
      const cacheKey = CacheService.generateKey(
        CacheService.roomKeys.list(hotelId),
        JSON.stringify({ page, pageSize, status, type, room_type_id, floor })
      );

      return await CacheService.getOrSet(
        cacheKey,
        async () => {
          const offset = (Number(page) - 1) * Number(pageSize);

          let whereClause = 'WHERE r.hotel_id = ?';
          const paramsArray: unknown[] = [hotelId];

          if (status) {
            whereClause += ' AND r.room_status = ?';
            paramsArray.push(status);
          }

          if (type) {
            whereClause += ' AND (r.room_type = ? OR rt.code = ?)';
            paramsArray.push(type, type);
          }

          if (room_type_id) {
            whereClause += ' AND (r.room_type_id = ? OR rt.id = ?)';
            paramsArray.push(Number(room_type_id), Number(room_type_id));
          }

          if (floor) {
            whereClause += ' AND r.floor = ?';
            paramsArray.push(Number(floor));
          }

          const totalSql = `SELECT COUNT(*) as total
               FROM rooms r
               LEFT JOIN room_types rt ON r.room_type_id = rt.id OR (r.room_type_id IS NULL AND r.room_type = rt.code AND (rt.hotel_id = r.hotel_id OR rt.hotel_id = 0))
               ${whereClause}`;
          const [totalRows] = await pool.query<RowDataPacket[]>(totalSql, paramsArray);
          const total = (totalRows[0] as { total: number }).total;

          const listSql = `SELECT r.*, rt.name as room_type_name, rt.code as room_type_code
               FROM rooms r
               LEFT JOIN room_types rt ON r.room_type_id = rt.id OR (r.room_type_id IS NULL AND r.room_type = rt.code AND (rt.hotel_id = r.hotel_id OR rt.hotel_id = 0))
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
        },
        { ttl: 180 }
      );
    } catch (error) {
      logger.error('获取房间列表失败:', error.message);
      throw new Error('获取房间列表失败');
    }
  }

  static async getRoomsByFloor(hotelId: number): Promise<unknown> {
    try {
      return await CacheService.getOrSet(
        `rooms:byFloor:${hotelId}`,
        async () => {
          const listByFloorSql = `SELECT r.*, rt.name as room_type_name, rt.code as room_type_code
               FROM rooms r
               LEFT JOIN room_types rt ON r.room_type_id = rt.id OR (r.room_type_id IS NULL AND r.room_type = rt.code AND (rt.hotel_id = r.hotel_id OR rt.hotel_id = 0))
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
        },
        { ttl: 180 }
      );
    } catch (error) {
      logger.error('按楼层获取房间失败:', error.message);
      throw new Error('按楼层获取房间失败');
    }
  }

  static async getRoomById(id: number, hotelId: number): Promise<Room | null> {
    try {
      return await CacheService.getOrSet(
        CacheService.roomKeys.info(id),
        async () => {
          const hasRoomTypesTable = await this.hasTable('room_types');
          const getByIdSql = hasRoomTypesTable
            ? `SELECT r.*, rt.name as room_type_name, rt.code as room_type_code
               FROM rooms r
               LEFT JOIN room_types rt ON r.room_type_id = rt.id OR (r.room_type_id IS NULL AND r.room_type = rt.code AND (rt.hotel_id = r.hotel_id OR rt.hotel_id = 0))
               WHERE r.id = ? AND r.hotel_id = ?`
            : `SELECT r.*, r.room_type as room_type_name, r.room_type as room_type_code
               FROM rooms r
               WHERE r.id = ? AND r.hotel_id = ?`;
          const [rows] = await pool.query<RowDataPacket[]>(getByIdSql, [id, hotelId]);
          return (rows[0] as Room) || null;
        },
        { ttl: 300 }
      );
    } catch (error) {
      logger.error('获取房间详情失败:', error.message);
      throw new Error('获取房间详情失败');
    }
  }

  static async createRoom(data: Partial<Room> & { hotel_id: number }): Promise<number> {
    try {
      const { room_number, room_type_id, room_name, room_price, room_status, floor, area, bed_type, max_guests, description, facilities, images, hotel_id } = data;

      const sql = `INSERT INTO rooms (room_number, room_type_id, room_name, room_price, room_status, floor, area, bed_type, max_guests, description, facilities, images, hotel_id)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`;
      const values = [room_number, room_type_id, room_name, room_price, room_status, floor, area, bed_type, max_guests, description, JSON.stringify(facilities || []), JSON.stringify(images || []), hotel_id];

      const [result] = await pool.query<ResultSetHeader>(sql, values);

      // 清除相关缓存
      await CacheService.deletePattern(`${CacheService.roomKeys.list(hotel_id)}*`);
      await CacheService.delete(`rooms:byFloor:${hotel_id}`);

      return result.insertId;
    } catch (error: unknown) {
      if ((error as { code?: string }).code === 'ER_DUP_ENTRY') {
        const customError = new Error(`房间号 ${data.room_number} 已存在，请更换后重试`);
        (customError as { status?: number }).status = 409;
        throw customError;
      }
      if ((error as { code?: string }).code === 'ER_BAD_FIELD_ERROR') {
        const customError = new Error('房间表字段不完整，请联系管理员执行数据库迁移');
        (customError as { status?: number }).status = 500;
        throw customError;
      }
      logger.error('创建房间失败:', (error as Error).message);
      throw error;
    }
  }

  static async updateRoom(id: number, hotelId: number, data: Partial<Room>): Promise<boolean> {
    try {
      const { room_number, room_type_id, room_name, room_price, room_status, floor, area, bed_type, max_guests, description, facilities, images } = data;

      const sql = `UPDATE rooms SET
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
      const values = [room_number, room_type_id, room_name, room_price, room_status, floor, area, bed_type, max_guests, description, JSON.stringify(facilities || []), JSON.stringify(images || []), id, hotelId];

      const [result] = await pool.query<ResultSetHeader>(sql, values);

      if (result.affectedRows > 0) {
        // 清除相关缓存
        await CacheService.delete(CacheService.roomKeys.info(id));
        await CacheService.deletePattern(`${CacheService.roomKeys.list(hotelId)}*`);
        await CacheService.delete(`rooms:byFloor:${hotelId}`);
      }

      return result.affectedRows > 0;
    } catch (error) {
      logger.error('更新房间失败:', (error as Error).message);
      throw new Error('更新房间失败');
    }
  }

  static async updateRoomStatus(id: number, status: string, hotelId?: number): Promise<boolean> {
    try {
      let result: ResultSetHeader;
      if (hotelId) {
        [result] = await pool.query<ResultSetHeader>(
          'UPDATE rooms SET room_status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND hotel_id = ?',
          [status, id, hotelId]
        );
      } else {
        [result] = await pool.query<ResultSetHeader>(
          'UPDATE rooms SET room_status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
          [status, id]
        );
      }

      if (result.affectedRows > 0) {
        // 清除相关缓存
        await CacheService.delete(CacheService.roomKeys.info(id));
        if (hotelId) {
          await CacheService.deletePattern(`${CacheService.roomKeys.list(hotelId)}*`);
          await CacheService.delete(`rooms:byFloor:${hotelId}`);
        }
      }

      return result.affectedRows > 0;
    } catch (error) {
      logger.error('更新房间状态失败:', (error as Error).message);
      throw new Error('更新房间状态失败');
    }
  }

  static async deleteRoom(id: number, hotelId: number): Promise<boolean> {
    try {
      const [result] = await pool.query<ResultSetHeader>('DELETE FROM rooms WHERE id = ? AND hotel_id = ?', [id, hotelId]);

      if (result.affectedRows > 0) {
        // 清除相关缓存
        await CacheService.delete(CacheService.roomKeys.info(id));
        await CacheService.deletePattern(`${CacheService.roomKeys.list(hotelId)}*`);
        await CacheService.delete(`rooms:byFloor:${hotelId}`);
      }

      return result.affectedRows > 0;
    } catch (error) {
      logger.error('删除房间失败:', (error as Error).message);
      throw new Error('删除房间失败');
    }
  }
}
