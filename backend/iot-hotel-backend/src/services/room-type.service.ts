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

  static async getAllRoomTypes(): Promise<RoomType[]> {
    try {
      const hasRoomTypesTable = await this.hasTable('room_types');
      if (!hasRoomTypesTable) {
        const [rows] = await pool.query<RowDataPacket[]>(
          `SELECT DISTINCT room_type
           FROM rooms
           WHERE room_type IS NOT NULL AND room_type <> ''
           ORDER BY room_type ASC`
        );
        return rows.map((item, index) => ({
          id: index + 1,
          name: String(item.room_type),
          code: String(item.room_type),
          base_price: 0,
          area: 0,
          bed_type: '',
          max_guests: 0,
          facilities: '[]',
          description: '',
          created_at: new Date(0),
          updated_at: new Date(0)
        })) as RoomType[];
      }
      const [rows] = await pool.query<RoomType[]>('SELECT * FROM room_types ORDER BY id DESC');
      return rows;
    } catch (error) {
      logger.error('获取房型列表失败:', error);
      throw new Error('获取房型列表失败');
    }
  }

  static async getRoomTypeById(id: number): Promise<RoomType | null> {
    try {
      const hasRoomTypesTable = await this.hasTable('room_types');
      if (!hasRoomTypesTable) {
        return null;
      }
      const [rows] = await pool.query<RoomType[]>('SELECT * FROM room_types WHERE id = ?', [id]);
      return rows[0] || null;
    } catch (error) {
      logger.error('获取房型详情失败:', error);
      throw new Error('获取房型详情失败');
    }
  }

  static async createRoomType(data: Partial<RoomType>): Promise<number> {
    try {
      const hasRoomTypesTable = await this.hasTable('room_types');
      if (!hasRoomTypesTable) {
        throw new Error('当前数据库未启用房型表');
      }
      const { name, code, base_price, area, bed_type, max_guests, facilities, description, images } = data;
      const [result] = await pool.query<ResultSetHeader>(
        'INSERT INTO room_types (name, code, base_price, area, bed_type, max_guests, facilities, description, images) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [name, code, base_price, area, bed_type, max_guests, JSON.stringify(facilities || []), description, JSON.stringify(images || [])]
      );
      return result.insertId;
    } catch (error) {
      logger.error('创建房型失败:', error);
      const serviceError: ServiceError = new Error('创建房型失败');
      const dbError = error as { code?: string; sqlMessage?: string };
      const sqlMessage = dbError?.sqlMessage || '';

      if (error instanceof Error && error.message === '当前数据库未启用房型表') {
        serviceError.message = '当前数据库未启用房型表，请先完成数据库迁移';
        serviceError.statusCode = 500;
        throw serviceError;
      }

      if (dbError?.code === 'ER_DUP_ENTRY') {
        if (sqlMessage.includes('room_types.name')) {
          serviceError.message = '房型名称已存在，请更换名称后重试';
          serviceError.statusCode = 409;
          throw serviceError;
        }
        if (sqlMessage.includes('room_types.code')) {
          serviceError.message = '房型编码已存在，请更换编码后重试';
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
      const hasRoomTypesTable = await this.hasTable('room_types');
      if (!hasRoomTypesTable) {
        throw new Error('当前数据库未启用房型表');
      }
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
      logger.error('更新房型失败:', error);
      const serviceError: ServiceError = new Error('更新房型失败');
      const dbError = error as { code?: string; sqlMessage?: string };
      const sqlMessage = dbError?.sqlMessage || '';

      if (dbError?.code === 'ER_DUP_ENTRY') {
        if (sqlMessage.includes('room_types.name')) {
          serviceError.message = '房型名称已存在，请更换名称后重试';
          serviceError.statusCode = 409;
          throw serviceError;
        }
        if (sqlMessage.includes('room_types.code')) {
          serviceError.message = '房型编码已存在，请更换编码后重试';
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
      logger.error('删除房型失败:', error);
      throw new Error('删除房型失败');
    }
  }
}
