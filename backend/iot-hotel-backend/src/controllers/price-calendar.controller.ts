
import { Response } from 'express';
import { AuthRequest, successResponse, errorResponse } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';

export const getPriceCalendar = async (req: AuthRequest, res: Response) => {
  try {
    const { room_type_id, start_date, end_date } = req.query;
    const hotelId = req.user?.hotel_id;

    if (!room_type_id || !start_date || !end_date) {
      return res.status(400).json(errorResponse('缺少必要参数'));
    }

    const [rows] = await pool.query<RowDataPacket[]>(
      'SELECT * FROM room_prices WHERE room_type_id = ? AND hotel_id = ? AND price_date BETWEEN ? AND ?',
      [room_type_id, hotelId, start_date, end_date]
    );

    res.json(successResponse(rows, '获取价格日历成功'));
  } catch (error) {
    logger.error('获取价格日历失败:', error);
    res.status(500).json(errorResponse('获取价格日历失败'));
  }
};

export const setPriceCalendar = async (req: AuthRequest, res: Response) => {
  try {
    const { room_type_id, prices } = req.body; // prices: [{date, discount_rate, base_price}]
    const hotelId = req.user?.hotel_id;

    if (!room_type_id || !prices || !Array.isArray(prices)) {
      return res.status(400).json(errorResponse('无效的参数'));
    }

    for (const item of prices) {
      const { date, discount_rate, base_price } = item;
      const finalPrice = base_price * (discount_rate || 1.0);
      
      await pool.query(
        `INSERT INTO room_prices (room_type_id, hotel_id, price_date, discount_rate, base_price, final_price) 
         VALUES (?, ?, ?, ?, ?, ?) 
         ON DUPLICATE KEY UPDATE discount_rate = ?, base_price = ?, final_price = ?`,
        [room_type_id, hotelId, date, discount_rate, base_price, finalPrice, discount_rate, base_price, finalPrice]
      );
    }

    res.json(successResponse(null, '设置价格日历成功'));
  } catch (error) {
    logger.error('设置价格日历失败:', error);
    res.status(500).json(errorResponse('设置价格日历失败'));
  }
};
