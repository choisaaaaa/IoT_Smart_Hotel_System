import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { v4 as uuidv4 } from 'uuid';

export const get = async (req: AuthRequest, res: Response) => {
  try {
    const { page = 1, pageSize = 10, status, item_category } = req.query;
    const offset = (Number(page) - 1) * Number(pageSize);
    
    let whereClause = 'WHERE 1=1';
    const params: any[] = [];
    
    if (status) {
      whereClause += ' AND status = ?';
      params.push(status);
    }
    
    if (item_category) {
      whereClause += ' AND item_category = ?';
      params.push(item_category);
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
    const { room_id, booking_id, guest_id, item_category, item_name, quantity, note } = req.body;
    
    const orderNo = `DEL${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${uuidv4().slice(0, 8).toUpperCase()}`;
    
    const [result] = await pool.query<ResultSetHeader>(
      'INSERT INTO delivery_orders (order_no, room_id, booking_id, guest_id, item_category, item_name, quantity, note, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [orderNo, room_id, booking_id || null, guest_id || null, item_category, item_name, quantity, note, 'pending']
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