import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';

export interface Floor extends RowDataPacket {
  id: number;
  floor_number: number;
  floor_name: string;
  floor_plan_image: string;
  description: string;
  created_at: Date;
  updated_at: Date;
}

export class FloorService {
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

  static async getFloors(): Promise<Floor[]> {
    try {
      const [rows] = await pool.query<Floor[]>('SELECT * FROM floors ORDER BY floor_number ASC');
      return rows;
    } catch (error) {
      logger.error('获取楼层列表失败:', error);
      throw new Error('获取楼层列表失败');
    }
  }

  static async getFloorById(id: number): Promise<Floor | null> {
    try {
      const [rows] = await pool.query<Floor[]>('SELECT * FROM floors WHERE id = ?', [id]);
      return rows[0] || null;
    } catch (error) {
      logger.error('获取楼层详情失败:', error);
      throw new Error('获取楼层详情失败');
    }
  }

  static async createFloor(data: Partial<Floor>): Promise<number> {
    try {
      const { floor_number, floor_name, floor_plan_image, description } = data;
      const [result] = await pool.query<ResultSetHeader>(
        'INSERT INTO floors (floor_number, floor_name, floor_plan_image, description) VALUES (?, ?, ?, ?)',
        [floor_number, floor_name, floor_plan_image, description]
      );
      return result.insertId;
    } catch (error: any) {
      if (error.code === 'ER_DUP_ENTRY') {
        const customError = new Error(`楼层号 ${data.floor_number} 已存在，请更换后重试`);
        (customError as any).status = 409;
        throw customError;
      }
      if (error.code === 'ER_BAD_FIELD_ERROR') {
        const customError = new Error('楼层表字段不完整，请联系管理员执行数据库迁移');
        (customError as any).status = 500;
        throw customError;
      }
      logger.error('创建楼层失败:', error);
      throw error;
    }
  }

  static async updateFloor(id: number, data: Partial<Floor>): Promise<boolean> {
    try {
      const { floor_number, floor_name, floor_plan_image, description } = data;
      const [result] = await pool.query<ResultSetHeader>(
        `UPDATE floors SET 
          floor_number = COALESCE(?, floor_number),
          floor_name = COALESCE(?, floor_name),
          floor_plan_image = COALESCE(?, floor_plan_image),
          description = COALESCE(?, description)
        WHERE id = ?`,
        [floor_number, floor_name, floor_plan_image, description, id]
      );
      return result.affectedRows > 0;
    } catch (error: any) {
      if (error.code === 'ER_DUP_ENTRY') {
        const customError = new Error(`楼层号 ${data.floor_number} 已存在，请更换后重试`);
        (customError as any).status = 409;
        throw customError;
      }
      logger.error('更新楼层失败:', error);
      throw error;
    }
  }

  static async deleteFloor(id: number): Promise<boolean> {
    try {
      // 检查楼层下是否有房间
      const [rows] = await pool.query<RowDataPacket[]>(
        'SELECT COUNT(*) as count FROM rooms r JOIN floors f ON r.floor = f.floor_number WHERE f.id = ?',
        [id]
      );
      if ((rows[0] as any).count > 0) {
        const error = new Error('该楼层下尚有房间，无法删除');
        (error as any).status = 400;
        throw error;
      }

      const [result] = await pool.query<ResultSetHeader>('DELETE FROM floors WHERE id = ?', [id]);
      return result.affectedRows > 0;
    } catch (error: any) {
      logger.error('删除楼层失败:', error);
      throw error;
    }
  }
}
