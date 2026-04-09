import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { v4 as uuidv4 } from 'uuid';

export const get = async (req: AuthRequest, res: Response) => {
  try {
    const { page = 1, pageSize = 10, status } = req.query;
    const offset = (Number(page) - 1) * Number(pageSize);
    
    let whereClause = 'WHERE 1=1';
    const params: any[] = [];
    
    if (status) {
      whereClause += ' AND status = ?';
      params.push(status);
    }
    
    const [totalRows] = await pool.query<RowDataPacket[]>(`SELECT COUNT(*) as total FROM delivery_orders ${whereClause}`, params);
    const total = (totalRows[0] as any).total;
    
    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT d.*, r.room_number FROM delivery_orders d LEFT JOIN rooms r ON d.room_id = r.id ${whereClause} ORDER BY d.id DESC LIMIT ? OFFSET ?`,
      [...params, Number(pageSize), offset]
    );
    
    res.json(successResponse({
      list: rows,
      total,
      page: Number(page),
      pageSize: Number(pageSize),
      totalPages: Math.ceil(total / Number(pageSize))
    }, '获取送物订单列表成功'));
  } catch (error) {
    logger.error('获取送物订单列表失败:', error);
    res.status(500).json(errorResponse('获取送物订单列表失败'));
  }
};

export const getById = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    
    const [rows] = await pool.query<RowDataPacket[]>(
      'SELECT d.*, r.room_number FROM delivery_orders d LEFT JOIN rooms r ON d.room_id = r.id WHERE d.id = ?',
      [id]
    );
    
    if (rows.length === 0) {
      res.status(404).json(errorResponse('送物订单不存在'));
      return;
    }
    
    res.json(successResponse(rows[0], '获取送物订单详情成功'));
  } catch (error) {
    logger.error('获取送物订单详情失败:', error);
    res.status(500).json(errorResponse('获取送物订单详情失败'));
  }
};

export const create = async (req: AuthRequest, res: Response) => {
  try {
    const { room_id, booking_id, guest_id, item_name, quantity, note } = req.body;
    
    if (!room_id || !item_name || !quantity) {
      res.status(400).json(errorResponse('缺少必要参数（room_id, item_name, quantity）'));
      return;
    }
    
    const orderNo = `DEL${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${uuidv4().slice(0, 8).toUpperCase()}`;
    
    const [result] = await pool.query<ResultSetHeader>(
      'INSERT INTO delivery_orders (order_no, room_id, booking_id, guest_id, item_name, quantity, note, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [orderNo, room_id, booking_id || null, guest_id || null, item_name, quantity, note || '', 'pending']
    );
    
    res.json(successResponse({ id: result.insertId, order_no: orderNo }, '创建送物订单成功'));
  } catch (error) {
    logger.error('创建送物订单失败:', error);
    res.status(500).json(errorResponse('创建送物订单失败'));
  }
};

export const complete = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;

    const [result] = await pool.query<ResultSetHeader>(
      'UPDATE delivery_orders SET status = ?, completed_at = CURRENT_TIMESTAMP WHERE id = ?',
      ['completed', id]
    );

    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('送物订单不存在'));
      return;
    }

    res.json(successResponse(null, '完成送物订单成功'));
  } catch (error) {
    logger.error('完成送物订单失败:', error);
    res.status(500).json(errorResponse('完成送物订单失败'));
  }
};

export const updateStatus = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!status) {
      res.status(400).json(errorResponse('缺少状态参数'));
      return;
    }

    // 验证状态流转是否合法
    const validTransitions: Record<string, string[]> = {
      'pending': ['delivering', 'cancelled'],
      'delivering': ['completed'],
      'completed': [],
      'cancelled': []
    };

    // 获取当前状态
    const [rows] = await pool.query<RowDataPacket[]>(
      'SELECT status FROM delivery_orders WHERE id = ?',
      [id]
    );

    if (rows.length === 0) {
      res.status(404).json(errorResponse('送物订单不存在'));
      return;
    }

    const currentStatus = (rows[0] as any).status;
    const allowedNextStates = validTransitions[currentStatus] || [];

    if (!allowedNextStates.includes(status)) {
      res.status(400).json(errorResponse(`不允许从 ${currentStatus} 状态转换到 ${status} 状态`));
      return;
    }

    let updateQuery = 'UPDATE delivery_orders SET status = ? WHERE id = ?';
    const params: any[] = [status, id];

    if (status === 'delivering') {
      updateQuery = 'UPDATE delivery_orders SET status = ?, started_delivering_at = CURRENT_TIMESTAMP WHERE id = ?';
    } else if (status === 'completed') {
      updateQuery = 'UPDATE delivery_orders SET status = ?, completed_at = CURRENT_TIMESTAMP WHERE id = ?';
    }

    const [result] = await pool.query<ResultSetHeader>(updateQuery, params);

    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('送物订单不存在'));
      return;
    }

    res.json(successResponse(null, '更新送物订单状态成功'));
  } catch (error) {
    logger.error('更新送物订单状态失败:', error);
    res.status(500).json(errorResponse('更新送物订单状态失败'));
  }
};