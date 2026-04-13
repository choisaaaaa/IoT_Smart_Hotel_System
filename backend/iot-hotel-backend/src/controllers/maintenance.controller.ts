import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { v4 as uuidv4 } from 'uuid';

export const get = async (req: AuthRequest, res: Response) => {
  try {
    const { page = 1, pageSize = 10, status, fault_type, priority } = req.query;
    const offset = (Number(page) - 1) * Number(pageSize);
    const hotelId = req.user?.hotel_id;
    
    let whereClause = 'WHERE 1=1';
    const params: any[] = [];
    
    if (hotelId) {
      whereClause += ' AND r.hotel_id = ?';
      params.push(hotelId);
    }

    if (status) {
      whereClause += ' AND m.status = ?';
      params.push(status);
    }
    
    if (fault_type) {
      whereClause += ' AND m.fault_type = ?';
      params.push(fault_type);
    }
    
    if (priority) {
      whereClause += ' AND m.priority = ?';
      params.push(priority);
    }
    
    const [totalRows] = await pool.query<RowDataPacket[]>(
      `SELECT COUNT(*) as total FROM maintenance_tickets m LEFT JOIN rooms r ON m.room_id = r.id ${whereClause}`, 
      params
    );
    const total = (totalRows[0] as any).total;
    
    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT m.*, r.room_number FROM maintenance_tickets m LEFT JOIN rooms r ON m.room_id = r.id ${whereClause} ORDER BY m.id DESC LIMIT ? OFFSET ?`,
      [...params, Number(pageSize), offset]
    );
    
    res.json(successResponse({
      list: rows,
      total,
      page: Number(page),
      pageSize: Number(pageSize),
      totalPages: Math.ceil(total / Number(pageSize))
    }, '获取报修工单列表成功'));
  } catch (error) {
    logger.error('获取报修工单列表失败:', error.message);
    res.status(500).json(errorResponse('获取报修工单列表失败'));
  }
};

export const getById = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const hotelId = req.user?.hotel_id;

    let query = 'SELECT m.*, r.room_number FROM maintenance_tickets m LEFT JOIN rooms r ON m.room_id = r.id WHERE m.id = ?';
    const params: any[] = [id];

    if (hotelId) {
      query += ' AND r.hotel_id = ?';
      params.push(hotelId);
    }
    
    const [rows] = await pool.query<RowDataPacket[]>(query, params);
    
    if (rows.length === 0) {
      res.status(404).json(errorResponse('报修工单不存在或无权访问'));
      return;
    }
    
    res.json(successResponse(rows[0], '获取报修工单详情成功'));
  } catch (error) {
    logger.error('获取报修工单详情失败:', error.message);
    res.status(500).json(errorResponse('获取报修工单详情失败'));
  }
};

export const create = async (req: AuthRequest, res: Response) => {
  try {
    const { room_id, booking_id, guest_id, fault_type, fault_description, photos, priority } = req.body;
    
    const ticketNo = `MT${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${uuidv4().slice(0, 8).toUpperCase()}`;
    
    const [result] = await pool.query<ResultSetHeader>(
      'INSERT INTO maintenance_tickets (ticket_no, room_id, booking_id, guest_id, fault_type, fault_description, photos, priority, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [ticketNo, room_id, booking_id || null, guest_id || null, fault_type, fault_description, JSON.stringify(photos || []), priority, 'pending']
    );

    if (room_id) {
      await pool.query('UPDATE rooms SET room_status = ? WHERE id = ?', ['maintenance', room_id]);
    }
    
    res.json(successResponse({ id: result.insertId, ticket_no: ticketNo }, '创建报修工单成功'));
  } catch (error) {
    logger.error('创建报修工单失败:', error.message);
    res.status(500).json(errorResponse('创建报修工单失败'));
  }
};

export const assign = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { repairer } = req.body;
    
    const [result] = await pool.query<ResultSetHeader>(
      'UPDATE maintenance_tickets SET status = ?, repairer = ?, assigned_at = CURRENT_TIMESTAMP WHERE id = ?',
      ['assigned', repairer, id]
    );
    
    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('报修工单不存在'));
      return;
    }
    
    res.json(successResponse(null, '分配维修人员成功'));
  } catch (error) {
    logger.error('分配维修人员失败:', error.message);
    res.status(500).json(errorResponse('分配维修人员失败'));
  }
};

export const updateStatus = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    const hotelId = req.user?.hotel_id;

    if (!['pending', 'assigned', 'processing', 'completed'].includes(status)) {
      res.status(400).json(errorResponse('无效的工单状态'));
      return;
    }

    // 权限检查
    let checkQuery = 'SELECT m.id FROM maintenance_tickets m LEFT JOIN rooms r ON m.room_id = r.id WHERE m.id = ?';
    const checkParams: any[] = [id];
    if (hotelId) {
      checkQuery += ' AND r.hotel_id = ?';
      checkParams.push(hotelId);
    }
    const [checkRows] = await pool.query<RowDataPacket[]>(checkQuery, checkParams);
    if (checkRows.length === 0) {
      res.status(404).json(errorResponse('报修工单不存在或无权访问'));
      return;
    }

    const [result] = await pool.query<ResultSetHeader>(
      'UPDATE maintenance_tickets SET status = ? WHERE id = ?',
      [status, id]
    );

    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('更新工单状态失败'));
      return;
    }

    res.json(successResponse(null, '更新工单状态成功'));
  } catch (error) {
    logger.error('更新工单状态失败:', error.message);
    res.status(500).json(errorResponse('更新工单状态失败'));
  }
};

export const complete = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { repair_description, repair_cost } = req.body;
    const hotelId = req.user?.hotel_id;

    let checkQuery = 'SELECT m.room_id, m.status FROM maintenance_tickets m LEFT JOIN rooms r ON m.room_id = r.id WHERE m.id = ?';
    const checkParams: any[] = [id];
    if (hotelId) {
      checkQuery += ' AND r.hotel_id = ?';
      checkParams.push(hotelId);
    }
    
    const [ticketRows] = await pool.query<RowDataPacket[]>(checkQuery, checkParams);

    if (ticketRows.length === 0) {
      res.status(404).json(errorResponse('报修工单不存在或无权访问'));
      return;
    }

    const roomId = (ticketRows[0] as any).room_id;
    
    const [result] = await pool.query<ResultSetHeader>(
      'UPDATE maintenance_tickets SET status = ?, repair_description = ?, repair_cost = ?, completed_at = CURRENT_TIMESTAMP WHERE id = ?',
      ['completed', repair_description, repair_cost, id]
    );
    
    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('报修工单不存在'));
      return;
    }

    if (roomId) {
      const [pendingTickets] = await pool.query<RowDataPacket[]>(
        'SELECT COUNT(*) as cnt FROM maintenance_tickets WHERE room_id = ? AND status IN (?, ?, ?)',
        [roomId, 'pending', 'assigned', 'processing']
      );
      if ((pendingTickets[0] as any).cnt === 0) {
        await pool.query('UPDATE rooms SET room_status = ? WHERE id = ? AND room_status = ?', ['available', roomId, 'maintenance']);
      }
    }
    
    res.json(successResponse(null, '完成报修工单成功'));
  } catch (error) {
    logger.error('完成报修工单失败:', error.message);
    res.status(500).json(errorResponse('完成报修工单失败'));
  }
};

export const remove = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const hotelId = req.user?.hotel_id;

    // 先检查工单是否存在并校验权限
    let checkQuery = 'SELECT m.status FROM maintenance_tickets m LEFT JOIN rooms r ON m.room_id = r.id WHERE m.id = ?';
    const checkParams: any[] = [id];
    if (hotelId) {
      checkQuery += ' AND r.hotel_id = ?';
      checkParams.push(hotelId);
    }
    const [rows] = await pool.query<RowDataPacket[]>(checkQuery, checkParams);

    if (rows.length === 0) {
      res.status(404).json(errorResponse('报修工单不存在或无权访问'));
      return;
    }

    // 检查是否允许删除（只有pending或cancelled状态的工单可以删除）
    const ticketStatus = (rows[0] as any).status;
    if (!['pending', 'cancelled'].includes(ticketStatus)) {
      res.status(400).json(errorResponse(`当前状态(${ticketStatus})的工单不允许删除`));
      return;
    }

    const [result] = await pool.query<ResultSetHeader>(
      'DELETE FROM maintenance_tickets WHERE id = ?',
      [id]
    );

    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('报修工单不存在'));
      return;
    }

    res.json(successResponse(null, '删除报修工单成功'));
  } catch (error) {
    logger.error('删除报修工单失败:', error.message);
    res.status(500).json(errorResponse('删除报修工单失败'));
  }
};