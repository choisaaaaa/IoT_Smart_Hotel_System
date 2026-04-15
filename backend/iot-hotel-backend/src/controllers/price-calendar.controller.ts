
import { Response } from 'express';
import { AuthRequest, successResponse, errorResponse } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import dayjs from 'dayjs';

export const getPriceCalendar = async (req: AuthRequest, res: Response) => {
  try {
    const { room_type_id, rate_plan_id, start_date, end_date } = req.query;
    const hotelId = req.user?.hotel_id;

    if (!room_type_id || !start_date || !end_date) {
      return res.status(400).json(errorResponse('缺少必要参数'));
    }

    let sql = 'SELECT * FROM room_prices WHERE room_type_id = ? AND hotel_id = ? AND price_date BETWEEN ? AND ?';
    const params: any[] = [room_type_id, hotelId, start_date, end_date];

    if (rate_plan_id) {
      sql += ' AND rate_plan_id = ?';
      params.push(rate_plan_id);
    } else {
      sql += ' AND rate_plan_id IS NULL';
    }

    const [rows] = await pool.query<RowDataPacket[]>(sql, params);
    res.json(successResponse(rows, '获取价格日历成功'));
  } catch (error) {
    logger.error('获取价格日历失败:', error.message);
    res.status(500).json(errorResponse('获取价格日历失败'));
  }
};

export const setPriceCalendar = async (req: AuthRequest, res: Response) => {
  try {
    const { room_type_id, rate_plan_id, prices } = req.body; // prices: [{date, discount_rate, base_price}]
    const hotelId = req.user?.hotel_id;

    if (!room_type_id || !prices || !Array.isArray(prices)) {
      return res.status(400).json(errorResponse('无效的参数'));
    }

    for (const item of prices) {
      const { date, discount_rate, base_price, inventory_count } = item;
      const finalPrice = base_price * (discount_rate || 1.0);
      
      await pool.query(
        `INSERT INTO room_prices (room_type_id, rate_plan_id, hotel_id, price_date, discount_rate, base_price, final_price, inventory_count) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?) 
         ON DUPLICATE KEY UPDATE discount_rate = ?, base_price = ?, final_price = ?, inventory_count = COALESCE(?, inventory_count)`,
        [room_type_id, rate_plan_id || null, hotelId, date, discount_rate, base_price, finalPrice, inventory_count || 0, discount_rate, base_price, finalPrice, inventory_count]
      );
    }

    res.json(successResponse(null, '设置价格日历成功'));
  } catch (error) {
    logger.error('设置价格日历失败:', error.message);
    res.status(500).json(errorResponse('设置价格日历失败'));
  }
};

export const getTodayInventory = async (req: AuthRequest, res: Response) => {
  try {
    const hotelId = req.user?.hotel_id;
    const today = dayjs().format('YYYY-MM-DD');

    // 使用 UNION 确保包含每个房型的“标准价”方案 (rate_plan_id 为 NULL) 和所有自定义方案
    const query = `
      SELECT * FROM (
        -- 1. 每个房型的“标准价”方案
        SELECT rt.id as room_type_id, rt.name as room_type_name, rt.code as room_type_code,
               NULL as rate_plan_id, '标准价' as plan_name, rt.default_inventory as default_inventory,
               p.final_price, 
               COALESCE(p.inventory_count, rt.default_inventory) as inventory_count, 
               COALESCE(p.sold_count, 0) as sold_count,
               COALESCE(p.final_price, rt.base_price) as current_price
        FROM room_types rt
        LEFT JOIN room_prices p ON rt.id = p.room_type_id AND p.rate_plan_id IS NULL AND p.price_date = ?
        WHERE rt.hotel_id = ? OR rt.hotel_id = 0

        UNION ALL

        -- 2. 房型关联的自定义房价方案
        SELECT rt.id as room_type_id, rt.name as room_type_name, rt.code as room_type_code,
               rp.id as rate_plan_id, rp.plan_name, rp.default_inventory as default_inventory,
               p.final_price, 
               COALESCE(p.inventory_count, rp.default_inventory) as inventory_count, 
               COALESCE(p.sold_count, 0) as sold_count,
               COALESCE(p.final_price, rp.base_price, rt.base_price) as current_price
        FROM room_types rt
        JOIN rate_plans rp ON rt.id = rp.room_type_id
        LEFT JOIN room_prices p ON rt.id = p.room_type_id AND rp.id = p.rate_plan_id AND p.price_date = ?
        WHERE rt.hotel_id = ? OR rt.hotel_id = 0
      ) as combined_inventory
      ORDER BY room_type_id ASC, rate_plan_id IS NOT NULL ASC, rate_plan_id ASC
    `;

    const [rows] = await pool.query<RowDataPacket[]>(query, [today, hotelId, today, hotelId]);
    res.json(successResponse(rows, '获取今日余量成功'));
  } catch (error: any) {
    logger.error('获取今日余量失败:', error);
    res.status(500).json(errorResponse(`获取今日余量失败: ${error.message}`));
  }
};

export const updateTodayInventory = async (req: AuthRequest, res: Response) => {
  try {
    const hotelId = req.user?.hotel_id;
    const today = dayjs().format('YYYY-MM-DD');
    const { updates } = req.body; // updates: [{room_type_id, rate_plan_id, price, inventory, default_inventory}]

    if (!updates || !Array.isArray(updates)) {
      return res.status(400).json(errorResponse('无效的参数'));
    }

    for (const item of updates) {
      const { room_type_id, rate_plan_id, price, inventory, default_inventory } = item;
      
      // 1. 更新今日价格与余量 (room_prices)
      // 使用 COALESCE 处理 rate_plan_id 为 null 的情况
      await pool.query(
        `INSERT INTO room_prices (room_type_id, rate_plan_id, hotel_id, price_date, base_price, final_price, inventory_count) 
         VALUES (?, ?, ?, ?, ?, ?, ?) 
         ON DUPLICATE KEY UPDATE base_price = ?, final_price = ?, inventory_count = ?`,
        [room_type_id, rate_plan_id || null, hotelId, today, price, price, inventory, price, price, inventory]
      );

      // 2. 更新标准余量 (默认值)
      if (default_inventory !== undefined) {
        if (!rate_plan_id) {
          // 更新房型表的默认余量 (标准价方案)
          await pool.query(
            'UPDATE room_types SET default_inventory = ? WHERE id = ? AND (hotel_id = ? OR hotel_id = 0)',
            [default_inventory, room_type_id, hotelId]
          );
        } else {
          // 更新方案表的默认余量 (自定义方案)
          await pool.query(
            'UPDATE rate_plans SET default_inventory = ? WHERE id = ? AND hotel_id = ?',
            [default_inventory, rate_plan_id, hotelId]
          );
        }
      }
    }

    res.json(successResponse(null, '更新今日余量与标准值成功'));
  } catch (error) {
    logger.error('更新今日余量失败:', error.message);
    res.status(500).json(errorResponse('更新今日余量失败'));
  }
};
