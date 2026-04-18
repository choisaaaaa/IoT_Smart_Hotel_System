import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { v4 as uuidv4 } from 'uuid';
import { isCustomer, isGuest } from '../utils/role';

export const get = async (req: AuthRequest, res: Response) => {
  try {
    const { page = 1, pageSize = 10, status } = req.query;
    const offset = (Number(page) - 1) * Number(pageSize);
    const hotelId = req.user?.hotel_id;
    const userRole = req.user?.role;
    const userId = req.user?.id;
    
    let whereClause = 'WHERE 1=1';
    const params: any[] = [];
    
    // 如果是顾客/游客角色，只能查看自己房间的订单
    if (isCustomer(userRole) || isGuest(userRole)) {
      // 获取顾客当前入住的房间
      const [bookingRows] = await pool.query<RowDataPacket[]>(
        `SELECT room_id FROM bookings 
         WHERE user_id = ? AND status = 'checked_in'
         LIMIT 1`,
        [userId]
      );
      
      if (bookingRows.length === 0) {
        // 顾客没有入住，返回空列表
        return res.json(successResponse({
          list: [],
          total: 0,
          page: Number(page),
          pageSize: Number(pageSize),
          totalPages: 0
        }, '获取送物订单列表成功'));
      }
      
      const roomId = (bookingRows[0] as any).room_id;
      whereClause += ' AND d.room_id = ?';
      params.push(roomId);
    } else if (hotelId) {
      // 按酒店过滤：通过 room_id 关联 rooms 表
      whereClause += ' AND r.hotel_id = ?';
      params.push(hotelId);
    }
    
    if (status) {
      whereClause += ' AND d.status = ?';
      params.push(status);
    }
    
    const [totalRows] = await pool.query<RowDataPacket[]>(
      `SELECT COUNT(*) as total FROM delivery_orders d LEFT JOIN rooms r ON d.room_id = r.id ${whereClause}`, 
      params
    );
    const total = (totalRows[0] as any).total;
    
    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT d.*, r.room_number, r.hotel_id FROM delivery_orders d LEFT JOIN rooms r ON d.room_id = r.id ${whereClause} ORDER BY d.id DESC LIMIT ? OFFSET ?`,
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
    logger.error('获取送物订单列表失败:', error.message);
    res.status(500).json(errorResponse('获取送物订单列表失败'));
  }
};

export const getById = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const hotelId = req.user?.hotel_id;
    const userRole = req.user?.role;
    const userId = req.user?.id;
    
    let query = 'SELECT d.*, r.room_number FROM delivery_orders d LEFT JOIN rooms r ON d.room_id = r.id WHERE d.id = ?';
    const params: any[] = [id];

    // 如果是顾客/游客角色，只能查看自己房间的订单
    if (isCustomer(userRole) || isGuest(userRole)) {
      const [bookingRows] = await pool.query<RowDataPacket[]>(
        `SELECT room_id FROM bookings 
         WHERE user_id = ? AND status = 'checked_in'
         LIMIT 1`,
        [userId]
      );
      
      if (bookingRows.length === 0) {
        res.status(403).json(errorResponse('您当前没有入住记录'));
        return;
      }
      
      const roomId = (bookingRows[0] as any).room_id;
      query += ' AND d.room_id = ?';
      params.push(roomId);
    } else if (hotelId) {
      query += ' AND r.hotel_id = ?';
      params.push(hotelId);
    }
    
    const [rows] = await pool.query<RowDataPacket[]>(query, params);
    
    if (rows.length === 0) {
      res.status(404).json(errorResponse('送物订单不存在或无权访问'));
      return;
    }
    
    res.json(successResponse(rows[0], '获取送物订单详情成功'));
  } catch (error) {
    logger.error('获取送物订单详情失败:', error.message);
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

    // 关键修复：客房服务只对前台已确认入住用户开放
    const [checkinRows] = await pool.query<RowDataPacket[]>(
      `SELECT id, status, hotel_id FROM bookings 
       WHERE room_id = ? AND status = 'checked_in'
       LIMIT 1`,
      [room_id]
    );

    if (checkinRows.length === 0) {
      res.status(403).json(errorResponse('该房间当前未办理入住，无法请求客房服务'));
      return;
    }

    const currentBooking = checkinRows[0] as any;
    
    const orderNo = `DEL${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${uuidv4().slice(0, 8).toUpperCase()}`;
    
    const [result] = await pool.query<ResultSetHeader>(
      'INSERT INTO delivery_orders (order_no, room_id, booking_id, guest_id, item_name, quantity, note, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [orderNo, room_id, booking_id || currentBooking.id, guest_id || null, item_name, quantity, note || '', 'pending']
    );
    
    res.json(successResponse({ id: result.insertId, order_no: orderNo }, '创建送物订单成功'));
  } catch (error) {
    logger.error('创建送物订单失败:', error.message);
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
    logger.error('完成送物订单失败:', error.message);
    res.status(500).json(errorResponse('完成送物订单失败'));
  }
};

export const updateStatus = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    const hotelId = req.user?.hotel_id;

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

    // 获取当前状态并检查酒店权限
    let query = 'SELECT d.status FROM delivery_orders d LEFT JOIN rooms r ON d.room_id = r.id WHERE d.id = ?';
    const params: any[] = [id];

    if (hotelId) {
      query += ' AND r.hotel_id = ?';
      params.push(hotelId);
    }

    const [rows] = await pool.query<RowDataPacket[]>(query, params);

    if (rows.length === 0) {
      res.status(404).json(errorResponse('送物订单不存在或无权访问'));
      return;
    }

    const currentStatus = (rows[0] as any).status;
    const allowedNextStates = validTransitions[currentStatus] || [];

    if (!allowedNextStates.includes(status)) {
      res.status(400).json(errorResponse(`不允许从 ${currentStatus} 状态转换到 ${status} 状态`));
      return;
    }

    let updateQuery = 'UPDATE delivery_orders SET status = ? WHERE id = ?';
    const updateParams: any[] = [status, id];

    if (status === 'delivering') {
      updateQuery = 'UPDATE delivery_orders SET status = ?, started_delivering_at = CURRENT_TIMESTAMP WHERE id = ?';
    } else if (status === 'completed') {
      updateQuery = 'UPDATE delivery_orders SET status = ?, completed_at = CURRENT_TIMESTAMP WHERE id = ?';
    }

    const [result] = await pool.query<ResultSetHeader>(updateQuery, updateParams);

    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('更新送物订单状态失败'));
      return;
    }

    res.json(successResponse(null, '更新送物订单状态成功'));
  } catch (error) {
    logger.error('更新送物订单状态失败:', error.message);
    res.status(500).json(errorResponse('更新送物订单状态失败'));
  }
};