import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import CacheService from './cache.service';

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
      return await CacheService.getOrSet(
        CacheService.hotelKeys.list(),
        async () => {
          const [rows] = await pool.query<Hotel[]>('SELECT * FROM hotels ORDER BY id ASC');
          return rows;
        },
        { ttl: 600 } // 10分钟缓存
      );
    } catch (error) {
      logger.error('获取所有酒店列表失败:', error.message);
      throw new Error('获取所有酒店列表失败');
    }
  }

  static async getHotelById(id: number): Promise<Hotel | null> {
    try {
      return await CacheService.getOrSet(
        CacheService.hotelKeys.info(id),
        async () => {
          const [rows] = await pool.query<RowDataPacket[]>('SELECT * FROM hotels WHERE id = ?', [id]);
          return (rows[0] as Hotel) || null;
        },
        { ttl: 600 } // 10分钟缓存
      );
    } catch (error) {
      logger.error('获取酒店信息失败:', error.message);
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

      // 清除酒店列表缓存
      await CacheService.delete(CacheService.hotelKeys.list());

      return result.insertId;
    } catch (error) {
      logger.error('创建酒店失败:', error.message);
      throw new Error('创建酒店失败');
    }
  }

  static async updateHotel(id: number, data: Partial<Hotel>): Promise<boolean> {
    try {
      const existing = await this.getHotelById(id);
      if (!existing) {return false;}

      const {
        hotel_name = existing.hotel_name,
        hotel_code = existing.hotel_code,
        hotel_address = existing.hotel_address,
        city = existing.city,
        hotel_phone = existing.hotel_phone,
        hotel_star = existing.hotel_star,
        logo = existing.logo,
        description = existing.description
      } = data;

      await pool.query<ResultSetHeader>(
        'UPDATE hotels SET hotel_name = ?, hotel_code = ?, hotel_address = ?, city = ?, hotel_phone = ?, hotel_star = ?, logo = ?, description = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        [hotel_name, hotel_code, hotel_address, city, hotel_phone, hotel_star, logo, description, id]
      );

      // 清除相关缓存
      await CacheService.delete(CacheService.hotelKeys.info(id));
      await CacheService.delete(CacheService.hotelKeys.list());

      return true;
    } catch (error) {
      logger.error('更新酒店信息失败:', error.message);
      throw new Error('更新酒店信息失败');
    }
  }

  /**
   * 删除酒店 (仅限 System 角色)
   */
  static async deleteHotel(id: number): Promise<boolean> {
    try {
      const [result] = await pool.query<ResultSetHeader>('DELETE FROM hotels WHERE id = ?', [id]);

      if (result.affectedRows > 0) {
        // 清除相关缓存
        await CacheService.delete(CacheService.hotelKeys.info(id));
        await CacheService.delete(CacheService.hotelKeys.list());
      }

      return result.affectedRows > 0;
    } catch (error) {
      logger.error('删除酒店失败:', error.message);
      throw new Error('删除酒店失败');
    }
  }
}
