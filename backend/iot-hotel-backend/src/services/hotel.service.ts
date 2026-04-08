import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';

export interface Hotel extends RowDataPacket {
  id: number;
  hotel_name: string;
  hotel_code: string;
  hotel_address: string;
  city: string;
  hotel_phone: string;
  hotel_star: number;
  total_rooms: number;
  occupied_rooms: number;
  occupancy_rate: number;
  logo: string;
  description: string;
  created_at: Date;
  updated_at: Date;
}

export class HotelService {
  /**
   * 获取所有酒店 (仅限 System 角色)
   */
  static async getAllHotels(): Promise<Hotel[]> {
    try {
      const [rows] = await pool.query<Hotel[]>('SELECT * FROM hotels ORDER BY id ASC');
      return rows;
    } catch (error) {
      logger.error('获取所有酒店列表失败:', error);
      throw new Error('获取所有酒店列表失败');
    }
  }

  static async getHotelById(id: number): Promise<Hotel | null> {
    try {
      const [rows] = await pool.query<RowDataPacket[]>('SELECT * FROM hotels WHERE id = ?', [id]);
      return (rows[0] as Hotel) || null;
    } catch (error) {
      logger.error('获取酒店信息失败:', error);
      throw new Error('获取酒店信息失败');
    }
  }

  /**
   * 创建酒店 (仅限 System 角色)
   */
  static async createHotel(data: Partial<Hotel>): Promise<number> {
    try {
      const { hotel_name, hotel_code, hotel_address, city, hotel_phone, hotel_star, logo, description } = data;
      const [result] = await pool.query<ResultSetHeader>(
        'INSERT INTO hotels (hotel_name, hotel_code, hotel_address, city, hotel_phone, hotel_star, logo, description) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [hotel_name, hotel_code, hotel_address, city, hotel_phone, hotel_star || 3, logo, description]
      );
      return result.insertId;
    } catch (error) {
      logger.error('创建酒店失败:', error);
      throw new Error('创建酒店失败');
    }
  }

  static async updateHotel(id: number, data: Partial<Hotel>): Promise<boolean> {
    try {
      const { hotel_name, hotel_code, hotel_address, city, hotel_phone, hotel_star, logo, description } = data;
      
      await pool.query<ResultSetHeader>(
        'UPDATE hotels SET hotel_name = ?, hotel_code = ?, hotel_address = ?, city = ?, hotel_phone = ?, hotel_star = ?, logo = ?, description = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        [hotel_name, hotel_code, hotel_address, city, hotel_phone, hotel_star, logo, description, id]
      );
      
      return true;
    } catch (error) {
      logger.error('更新酒店信息失败:', error);
      throw new Error('更新酒店信息失败');
    }
  }

  /**
   * 删除酒店 (仅限 System 角色)
   */
  static async deleteHotel(id: number): Promise<boolean> {
    try {
      const [result] = await pool.query<ResultSetHeader>('DELETE FROM hotels WHERE id = ?', [id]);
      return result.affectedRows > 0;
    } catch (error) {
      logger.error('删除酒店失败:', error);
      throw new Error('删除酒店失败');
    }
  }
}
