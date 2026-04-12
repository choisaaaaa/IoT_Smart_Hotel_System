
import { Response } from 'express';
import { AuthRequest, successResponse, errorResponse } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';

export const getRatePlans = async (req: AuthRequest, res: Response) => {
  try {
    const { room_type_id } = req.query;
    const hotelId = req.user?.hotel_id;

    let sql = 'SELECT * FROM rate_plans WHERE hotel_id = ?';
    const params: any[] = [hotelId];

    if (room_type_id) {
      sql += ' AND room_type_id = ?';
      params.push(room_type_id);
    }

    const [rows] = await pool.query<RowDataPacket[]>(sql, params);
    res.json(successResponse(rows, '获取房价方案成功'));
  } catch (error) {
    logger.error('获取房价方案失败:', error.message);
    res.status(500).json(errorResponse('获取房价方案失败'));
  }
};

export const createRatePlan = async (req: AuthRequest, res: Response) => {
  try {
    const hotelId = req.user?.hotel_id;
    const { 
      room_type_id, plan_name, base_price, meal_plan, breakfast_count, 
      cancellation_policy, cancel_time_limit, payment_type, 
      is_guaranteed, prepayment_ratio 
    } = req.body;

    if (!room_type_id || !plan_name) {
      return res.status(400).json(errorResponse('缺少必要参数（房型ID或方案名称）'));
    }

    const [result] = await pool.query<ResultSetHeader>(
      `INSERT INTO rate_plans (
        hotel_id, room_type_id, plan_name, base_price, meal_plan, breakfast_count, 
        cancellation_policy, cancel_time_limit, payment_type, 
        is_guaranteed, prepayment_ratio
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        hotelId, 
        room_type_id, 
        plan_name, 
        Number(base_price) || 0,
        meal_plan || 'none', 
        breakfast_count || 0,
        cancellation_policy || 'free', 
        cancel_time_limit || 0,
        payment_type || 'all', 
        is_guaranteed || 0, 
        prepayment_ratio || 0
      ]
    );

    res.status(201).json(successResponse({ id: result.insertId }, '创建房价方案成功'));
  } catch (error) {
    logger.error('创建房价方案失败:', error.message);
    res.status(500).json(errorResponse('创建房价方案失败'));
  }
};

export const updateRatePlan = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const hotelId = req.user?.hotel_id;
    const { 
      plan_name, base_price, meal_plan, breakfast_count, 
      cancellation_policy, cancel_time_limit, payment_type, 
      is_guaranteed, prepayment_ratio, is_active 
    } = req.body;

    logger.info(`更新房价方案 [ID: ${id}]:`, { plan_name, base_price });

    if (!plan_name) {
      return res.status(400).json(errorResponse('方案名称不能为空'));
    }

    const [result] = await pool.query<ResultSetHeader>(
      `UPDATE rate_plans SET 
        plan_name = ?, base_price = ?, meal_plan = ?, breakfast_count = ?, 
        cancellation_policy = ?, cancel_time_limit = ?, payment_type = ?, 
        is_guaranteed = ?, prepayment_ratio = ?, is_active = ? 
       WHERE id = ? AND hotel_id = ?`,
      [
        plan_name, 
        Number(base_price) || 0, 
        meal_plan || 'none', 
        breakfast_count || 0, 
        cancellation_policy || 'free', 
        cancel_time_limit || 0, 
        payment_type || 'all', 
        is_guaranteed || 0, 
        prepayment_ratio || 0, 
        is_active === undefined ? 1 : is_active, 
        id, 
        hotelId
      ]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json(errorResponse('方案不存在或无权操作'));
    }

    res.json(successResponse(null, '更新房价方案成功'));
  } catch (error) {
    logger.error('更新房价方案失败:', error.message);
    res.status(500).json(errorResponse('更新房价方案失败'));
  }
};

export const deleteRatePlan = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const hotelId = req.user?.hotel_id;

    // 检查是否有依赖
    const [priceRows] = await pool.query<RowDataPacket[]>('SELECT id FROM room_prices WHERE rate_plan_id = ? LIMIT 1', [id]);
    if (priceRows.length > 0) {
      return res.status(400).json(errorResponse('该方案已有价格设置，无法删除，请先下架'));
    }

    const [result] = await pool.query<ResultSetHeader>('DELETE FROM rate_plans WHERE id = ? AND hotel_id = ?', [id, hotelId]);
    
    if (result.affectedRows === 0) {
      return res.status(404).json(errorResponse('方案不存在或无权操作'));
    }

    res.json(successResponse(null, '删除房价方案成功'));
  } catch (error) {
    logger.error('删除房价方案失败:', error.message);
    res.status(500).json(errorResponse('删除房价方案失败'));
  }
};
