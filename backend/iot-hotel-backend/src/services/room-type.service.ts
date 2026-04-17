import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';

export interface RoomType extends RowDataPacket {
  id: number;
  name: string;
  code: string;
  base_price: number;
  area: number;
  bed_type: string;
  max_guests: number;
  facilities: string;
  description: string;
  images: string;
  hotel_id: number;
  created_at: Date;
  updated_at: Date;
}

type ServiceError = Error & { statusCode?: number };

export class RoomTypeService {
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

  static async getRoomTypes(hotelId?: number): Promise<RoomType[]> {
    try {
      let sql = 'SELECT * FROM room_types';
      const params = [];
      if (hotelId) {
        sql += ' WHERE hotel_id = ? OR hotel_id = 0';
        params.push(hotelId);
      }
      sql += ' ORDER BY id DESC';
      const [rows] = await pool.query<RoomType[]>(sql, params);
      return rows;
    } catch (error) {
      logger.error('获取房型列表失败:', error.message);
      throw new Error('获取房型列表失败');
    }
  }

  static async getRoomTypeById(id: number, hotelId?: number): Promise<RoomType | null> {
    try {
      let sql = 'SELECT * FROM room_types WHERE id = ?';
      const params: any[] = [id];
      if (hotelId) {
        sql += ' AND (hotel_id = ? OR hotel_id = 0)';
        params.push(hotelId);
      }
      const [rows] = await pool.query<RoomType[]>(sql, params);
      return (rows[0] as RoomType) || null;
    } catch (error) {
      logger.error('获取房型详情失败:', error.message);
      throw new Error('获取房型详情失败');
    }
  }

  static async createRoomType(data: Partial<RoomType> & { hotel_id?: number }): Promise<number> {
    try {
      const { name, code, base_price, area, bed_type, max_guests, facilities, description, images, hotel_id } = data;
      const [result] = await pool.query<ResultSetHeader>(
        'INSERT INTO room_types (name, code, base_price, area, bed_type, max_guests, facilities, description, images, hotel_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [name, code, base_price, area, bed_type, max_guests, JSON.stringify(facilities || []), description, JSON.stringify(images || []), hotel_id || 0]
      );
      return result.insertId;
    } catch (error) {
      logger.error('创建房型失败:', error.message);
      const serviceError: ServiceError = new Error('创建房型失败');
      const dbError = error as { code?: string; sqlMessage?: string };
      const sqlMessage = dbError?.sqlMessage || '';

      if (dbError?.code === 'ER_DUP_ENTRY') {
        if (sqlMessage.includes('uk_hotel_code')) {
          serviceError.message = '该酒店下已存在相同编码的房型，请更换编码后重试';
          serviceError.statusCode = 409;
          throw serviceError;
        }
      }

      if (dbError?.code === 'ER_BAD_FIELD_ERROR') {
        serviceError.message = '房型表字段不完整，请联系管理员执行数据库迁移';
        serviceError.statusCode = 500;
        throw serviceError;
      }

      serviceError.message = '创建房型失败，请检查输入后重试';
      serviceError.statusCode = 500;
      throw serviceError;
    }
  }

  static async updateRoomType(id: number, data: Partial<RoomType>): Promise<boolean> {
    try {
      const { name, code, base_price, area, bed_type, max_guests, facilities, description, images } = data;
      const [result] = await pool.query<ResultSetHeader>(
        `UPDATE room_types SET 
          name = COALESCE(?, name),
          code = COALESCE(?, code),
          base_price = COALESCE(?, base_price),
          area = COALESCE(?, area),
          bed_type = COALESCE(?, bed_type),
          max_guests = COALESCE(?, max_guests),
          facilities = COALESCE(?, facilities),
          description = COALESCE(?, description),
          images = COALESCE(?, images)
        WHERE id = ?`,
        [name, code, base_price, area, bed_type, max_guests, facilities ? JSON.stringify(facilities) : null, description, images ? JSON.stringify(images) : null, id]
      );
      return result.affectedRows > 0;
    } catch (error) {
      logger.error('更新房型失败:', error.message);
      const serviceError: ServiceError = new Error('更新房型失败');
      const dbError = error as { code?: string; sqlMessage?: string };
      const sqlMessage = dbError?.sqlMessage || '';

      if (dbError?.code === 'ER_DUP_ENTRY') {
        if (sqlMessage.includes('uk_hotel_code')) {
          serviceError.message = '该酒店下已存在相同编码的房型，请更换编码后重试';
          serviceError.statusCode = 409;
          throw serviceError;
        }
      }
      serviceError.message = '更新房型失败，请检查输入后重试';
      serviceError.statusCode = 500;
      throw serviceError;
    }
  }

  static async deleteRoomType(id: number): Promise<boolean> {
    try {
      const hasRoomTypesTable = await this.hasTable('room_types');
      if (!hasRoomTypesTable) {
        throw new Error('当前数据库未启用房型表');
      }
      const [result] = await pool.query<ResultSetHeader>('DELETE FROM room_types WHERE id = ?', [id]);
      return result.affectedRows > 0;
    } catch (error) {
      logger.error('删除房型失败:', error.message);
      throw new Error('删除房型失败');
    }
  }
}
