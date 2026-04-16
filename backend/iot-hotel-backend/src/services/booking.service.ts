import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { v4 as uuidv4 } from 'uuid';
import mqttService from './mqtt.service';
import CacheService from './cache.service';

export interface Booking extends RowDataPacket {
  id: number;
  booking_number: string;
  room_id: number;
  guest_name: string;
  guest_phone: string;
  guest_id_number: string;
  check_in_date: Date;
  check_out_date: Date;
  guest_count: number;
  special_requests: string;
  payment_method: string;
  total_price: number;
  deposit: number;
  status: string;
  created_at: Date;
  updated_at: Date;
  check_in_time: Date;
  check_out_time: Date;
  cancelled_at: Date;
  room_number?: string;
  room_type?: string;
}

export interface BookingListResponse {
  list: Booking[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

export class BookingService {
  static async getBookings(params: {
    page?: number;
    pageSize?: number;
    status?: string;
    guest_name?: string;
    check_in_date?: string;
    hotelId: number;
  }): Promise<BookingListResponse> {
    try {
      const { page = 1, pageSize = 10, status, guest_name, check_in_date, hotelId } = params;

      // 预订列表变化频繁，使用较短的缓存时间
      const cacheKey = CacheService.generateKey(
        CacheService.bookingKeys.list(hotelId),
        JSON.stringify({ page, pageSize, status, guest_name, check_in_date })
      );

      return await CacheService.getOrSet(
        cacheKey,
        async () => {
          const offset = (Number(page) - 1) * Number(pageSize);

          let whereClause = 'WHERE b.hotel_id = ?';
          const paramsArray: unknown[] = [hotelId];

          if (status) {
            whereClause += ' AND b.status = ?';
            paramsArray.push(status);

            // 预入住信息过滤过往日期：只显示今日及以后的
            if (status === 'pre_checked_in') {
              whereClause += ' AND DATE(b.check_out_date) >= CURDATE()';
            }
          }

          if (guest_name) {
            whereClause += ' AND b.guest_name LIKE ?';
            paramsArray.push(`%${guest_name}%`);
          }

          if (check_in_date) {
            if (check_in_date === 'today') {
              whereClause += ' AND DATE(b.check_in_date) = CURDATE()';
            } else {
              whereClause += ' AND DATE(b.check_in_date) = ?';
              paramsArray.push(check_in_date);
            }
          }

          const [totalRows] = await pool.query<RowDataPacket[]>(`SELECT COUNT(*) as total FROM bookings b ${whereClause}`, paramsArray);
          const total = (totalRows[0] as { total: number }).total;

          const [rows] = await pool.query<RowDataPacket[]>(
            `SELECT b.*, r.room_number, r.room_type FROM bookings b LEFT JOIN rooms r ON b.room_id = r.id ${whereClause} ORDER BY b.id DESC LIMIT ? OFFSET ?`,
            [...paramsArray, Number(pageSize), offset]
          );

          return {
            list: rows as Booking[],
            total,
            page: Number(page),
            pageSize: Number(pageSize),
            totalPages: Math.ceil(total / Number(pageSize))
          };
        },
        { ttl: 120 } // 预订列表缓存2分钟
      );
    } catch (error) {
      logger.error('获取预订列表失败:', (error as Error).message);
      throw new Error('获取预订列表失败');
    }
  }

  static async getBookingById(id: number, hotelId: number): Promise<Booking | null> {
    try {
      return await CacheService.getOrSet(
        CacheService.bookingKeys.info(id),
        async () => {
          const [rows] = await pool.query<RowDataPacket[]>(
            'SELECT b.*, r.room_number, r.room_type FROM bookings b LEFT JOIN rooms r ON b.room_id = r.id WHERE b.id = ? AND b.hotel_id = ?',
            [id, hotelId]
          );
          return (rows[0] as Booking) || null;
        },
        { ttl: 180 }
      );
    } catch (error) {
      logger.error('获取预订详情失败:', (error as Error).message);
      throw new Error('获取预订详情失败');
    }
  }

  static async createBooking(data: {
    hotel_id: number;
    room_id: number;
    guest_name: string;
    guest_phone: string;
    guest_id_number: string;
    check_in_date: string;
    check_out_date: string;
    guest_count: number;
    special_requests: string;
    payment_method: string;
  }): Promise<{ id: number; booking_number: string; total_price: number }> {
    try {
      const { hotel_id, room_id, guest_name, guest_phone, guest_id_number, check_in_date, check_out_date, guest_count, special_requests, payment_method } = data;

      const [roomRows] = await pool.query<RowDataPacket[]>('SELECT room_price FROM rooms WHERE id = ? AND hotel_id = ?', [room_id, hotel_id]);

      if (roomRows.length === 0) {
        throw new Error('房间不存在或不属于该酒店');
      }

      const roomPrice = (roomRows[0] as any).room_price;
      const checkIn = new Date(check_in_date);
      const checkOut = new Date(check_out_date);
      const days = Math.ceil((checkOut.getTime() - checkIn.getTime()) / (1000 * 60 * 60 * 24));
      const totalPrice = roomPrice * days;

      const bookingNumber = `BK${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${uuidv4().slice(0, 8).toUpperCase()}`;

      const [result] = await pool.query<ResultSetHeader>(
        'INSERT INTO bookings (hotel_id, booking_number, room_id, guest_name, guest_phone, guest_id_number, check_in_date, check_out_date, guest_count, special_requests, payment_method, total_price, deposit, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [hotel_id, bookingNumber, room_id, guest_name, guest_phone, guest_id_number, check_in_date, check_out_date, guest_count, special_requests, payment_method, totalPrice, 0, 'pending']
      );

      // 清除相关缓存
      await CacheService.deletePattern(`booking:list:${hotel_id}*`);

      return {
        id: result.insertId,
        booking_number: bookingNumber,
        total_price: totalPrice
      };
    } catch (error) {
      logger.error('创建预订失败:', error.message);
      throw new Error('创建预订失败');
    }
  }

  static async confirmBooking(id: number, hotelId: number): Promise<boolean> {
    try {
      const [result] = await pool.query<ResultSetHeader>(
        'UPDATE bookings SET status = ? WHERE id = ? AND hotel_id = ?',
        ['confirmed', id, hotelId]
      );

      if (result.affectedRows > 0) {
        await CacheService.delete(CacheService.bookingKeys.info(id));
        await CacheService.deletePattern(`booking:list:${hotelId}*`);
      }

      return result.affectedRows > 0;
    } catch (error) {
      logger.error('确认预订失败:', (error as Error).message);
      throw new Error('确认预订失败');
    }
  }

  static async checkIn(id: number, hotelId: number): Promise<boolean> {
    try {
      // 1. 获取预订信息（包含 room_id）
      const [bookings] = await pool.query<RowDataPacket[]>(
        'SELECT room_id FROM bookings WHERE id = ? AND hotel_id = ?',
        [id, hotelId]
      );

      if (bookings.length === 0) {return false;}
      const roomId = bookings[0].room_id;

      // 2. 更新预订状态
      const [result] = await pool.query<ResultSetHeader>(
        'UPDATE bookings SET status = ?, check_in_time = CURRENT_TIMESTAMP WHERE id = ? AND hotel_id = ?',
        ['checked_in', id, hotelId]
      );

      if (result.affectedRows > 0) {
        // 3. 联动硬件：触发欢迎场景
        // 查找房间对应的客房端设备
        const [devices] = await pool.query<RowDataPacket[]>(
          'SELECT device_id FROM devices WHERE room_id = ? AND device_type = "room_terminal" AND audit_status = "approved"',
          [roomId]
        );

        for (const device of devices) {
          await mqttService.sendDeviceCommand(device.device_id, 'scene', 'welcome', 'system_checkin');
        }

        // 清除相关缓存
        await CacheService.delete(CacheService.bookingKeys.info(id));
        await CacheService.deletePattern(`booking:list:${hotelId}*`);

        return true;
      }
      return false;
    } catch (error) {
      logger.error('办理入住失败:', error.message);
      throw new Error('办理入住失败');
    }
  }

  static async checkOut(id: number, hotelId: number): Promise<boolean> {
    try {
      const [result] = await pool.query<ResultSetHeader>(
        'UPDATE bookings SET status = ?, check_out_time = CURRENT_TIMESTAMP WHERE id = ? AND hotel_id = ?',
        ['checked_out', id, hotelId]
      );

      if (result.affectedRows > 0) {
        await CacheService.delete(CacheService.bookingKeys.info(id));
        await CacheService.deletePattern(`booking:list:${hotelId}*`);
      }

      return result.affectedRows > 0;
    } catch (error) {
      logger.error('办理退房失败:', (error as Error).message);
      throw new Error('办理退房失败');
    }
  }

  static async cancelBooking(id: number, hotelId: number): Promise<boolean> {
    try {
      const [result] = await pool.query<ResultSetHeader>(
        'UPDATE bookings SET status = ?, cancelled_at = CURRENT_TIMESTAMP WHERE id = ? AND hotel_id = ?',
        ['cancelled', id, hotelId]
      );

      if (result.affectedRows > 0) {
        await CacheService.delete(CacheService.bookingKeys.info(id));
        await CacheService.deletePattern(`booking:list:${hotelId}*`);
      }

      return result.affectedRows > 0;
    } catch (error) {
      logger.error('取消预订失败:', (error as Error).message);
      throw new Error('取消预订失败');
    }
  }
}
