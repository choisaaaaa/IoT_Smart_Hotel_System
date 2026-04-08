import { Router, Response } from 'express';
import { AuthRequest } from '../../types';
import { successResponse, errorResponse, sendSuccess, sendError } from '../../types';
import dayjs from 'dayjs';

const router = Router();

// 搜索酒店
export async function search(req: AuthRequest, res: Response) {
  try {
    const db = require('../../config/database');
    const { destination, check_in, check_out, rooms = 1, guests = 2 } = req.query;

    // 查询酒店列表（包含可用房间数）
    const sql = `
      SELECT DISTINCT h.*, 
             COUNT(CASE WHEN r.room_status = 'available' THEN 1 END) as available_rooms,
             MIN(r.room_price) as min_price
      FROM hotels h
      LEFT JOIN rooms r ON h.hotel_id = r.hotel_id AND r.room_status = 'available'
      WHERE h.hotel_name LIKE ? OR h.location LIKE ?
      GROUP BY h.hotel_id
      HAVING available_rooms > 0
    `;

    const keyword = `%${destination || ''}%`;
    const [hotels]: any = await db.execute(sql, [keyword, keyword]);

    sendSuccess(res, {
      hotels: hotels.map((h: any) => ({
        id: h.hotel_id,
        name: h.hotel_name,
        location: h.location,
        star: h.star_rating,
        rating: h.rating || 4.5,
        reviewCount: h.review_count || 0,
        price: h.min_price || 299,
        image: h.image_url || '/hotel-placeholder.jpg',
        promotion: h.promotion,
        availableRooms: h.available_rooms
      }))
    });
  } catch (error) {
    console.error('搜索酒店失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

// 获取酒店详情
export async function detail(req: AuthRequest, res: Response) {
  try {
    const hotelId = req.params.id;
    const db = require('../../config/database');

    const [hotels]: any = await db.execute(
      'SELECT * FROM hotels WHERE hotel_id = ?',
      [hotelId]
    );

    if (hotels.length === 0) {
      return sendError(res, errorResponse('酒店不存在', 404));
    }

    const hotel = hotels[0];

    sendSuccess(res, {
      hotel: {
        id: hotel.hotel_id,
        name: hotel.hotel_name,
        location: hotel.location,
        star: hotel.star_rating,
        rating: hotel.rating || 4.5,
        reviewCount: hotel.review_count || 0,
        image: hotel.image_url,
        promotion: hotel.promotion
      }
    });
  } catch (error) {
    console.error('获取酒店详情失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

// 查询客房余量
export async function roomAvailability(req: AuthRequest, res: Response) {
  try {
    const hotelId = req.params.id;
    const { check_in, check_out } = req.query;
    const db = require('../../config/database');

    if (!check_in || !check_out) {
      return sendError(res, errorResponse('请选择入住和退房日期', 400));
    }

    const checkInDate = dayjs(check_in);
    const checkOutDate = dayjs(check_out);

    // 查询在指定日期范围内可用的房间
    // 可用房间 = 总房间 - 已预订房间
    const sql = `
      SELECT 
        r.room_id,
        r.room_number,
        r.room_name,
        r.room_type,
        r.room_price,
        r.floor,
        r.area,
        r.bed_type,
        r.max_guests,
        r.room_status,
        r.facilities,
        r.image_url,
        COUNT(DISTINCT r.room_id) as total_rooms,
        COUNT(DISTINCT b.room_id) as booked_rooms,
        (COUNT(DISTINCT r.room_id) - COUNT(DISTINCT b.room_id)) as available_count
      FROM rooms r
      LEFT JOIN bookings b ON r.room_id = b.room_id 
        AND b.status IN ('confirmed', 'checked_in')
        AND (
          (b.check_in_date <= ? AND b.check_out_date >= ?)
          OR (b.check_in_date <= ? AND b.check_out_date >= ?)
          OR (b.check_in_date >= ? AND b.check_out_date <= ?)
        )
      WHERE r.hotel_id = ? AND r.room_status = 'available'
      GROUP BY r.room_id, r.room_number, r.room_name, r.room_type, 
               r.room_price, r.floor, r.area, r.bed_type, r.max_guests,
               r.room_status, r.facilities, r.image_url
      HAVING available_count > 0
    `;

    const params = [
      checkInDate.format('YYYY-MM-DD'),
      checkInDate.format('YYYY-MM-DD'),
      checkOutDate.format('YYYY-MM-DD'),
      checkOutDate.format('YYYY-MM-DD'),
      checkInDate.format('YYYY-MM-DD'),
      checkOutDate.format('YYYY-MM-DD'),
      hotelId
    ];

    const [rooms]: any = await db.execute(sql, params);

    sendSuccess(res, {
      rooms: rooms.map((r: any) => ({
        id: r.room_id,
        room_number: r.room_number,
        room_name: r.room_name,
        room_type: r.room_type,
        room_price: r.room_price,
        floor: r.floor,
        area: r.area,
        bed_type: r.bed_type,
        max_guests: r.max_guests,
        room_status: r.room_status,
        facilities: r.facilities ? JSON.parse(r.facilities) : [],
        image: r.image_url || '/room-placeholder.jpg',
        available_count: r.available_count || 0,
        // 兼容前端字段
        name: r.room_name,
        description: `${r.room_type} · ${r.floor}楼`,
        area: r.area,
        bedType: r.bed_type === 'king' ? '大床' : r.bed_type === 'twin' ? '双床' : '单床',
        maxGuests: r.max_guests,
        hasBreakfast: r.facilities?.includes('含早餐'),
        freeCancel: r.facilities?.includes('免费取消'),
        hasWifi: r.facilities?.includes('免费 WiFi')
      }))
    });
  } catch (error) {
    console.error('查询客房余量失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

export default router;
