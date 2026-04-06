import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { v4 as uuidv4 } from 'uuid';

export const get = async (req: AuthRequest, res: Response) => {
  try {
    const { page = 1, pageSize = 10, status, fault_type, priority } = req.query;
    const offset = (Number(page) - 1) * Number(pageSize);
    
    let whereClause = 'WHERE 1=1';
    const params: any[] = [];
    
    if (status) {
      whereClause += ' AND status = ?';
      params.push(status);
    }
    
    if (fault_type) {
      whereClause += ' AND fault_type = ?';
      params.push(fault_type);
    }
    
    if (priority) {
      whereClause += ' AND priority = ?';
      params.push(priority);
    }
    
    const [totalRows] = await pool.query<RowDataPacket[]>(`SELECT COUNT(*) as total FROM maintenance_tickets ${whereClause}`, params);
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
    logger.error('获取报修工单列表失败:', error);
    res.status(500).json(errorResponse('获取报修工单列表失败'));
  }
};

export const getById = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    
    const [rows] = await pool.query<RowDataPacket[]>(
      'SELECT m.*, r.room_number FROM maintenance_tickets m LEFT JOIN rooms r ON m.room_id = r.id WHERE m.id = ?',
      [id]
    );
    
    if (rows.length === 0) {
      res.status(404).json(errorResponse('报修工单不存在'));
      return;
    }
    
    res.json(successResponse(rows[0], '获取报修工单详情成功'));
  } catch (error) {
    logger.error('获取报修工单详情失败:', error);
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
    
    res.json(successResponse({ id: result.insertId, ticket_no: ticketNo }, '创建报修工单成功'));
  } catch (error) {
    logger.error('创建报修工单失败:', error);
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
    logger.error('分配维修人员失败:', error);
    res.status(500).json(errorResponse('分配维修人员失败'));
  }
};

export const complete = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { repair_description, repair_cost } = req.body;
    
    const [result] = await pool.query<ResultSetHeader>(
      'UPDATE maintenance_tickets SET status = ?, repair_description = ?, repair_cost = ?, completed_at = CURRENT_TIMESTAMP WHERE id = ?',
      ['completed', repair_description, repair_cost, id]
    );
    
    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('报修工单不存在'));
      return;
    }
    
    res.json(successResponse(null, '完成报修工单成功'));
  } catch (error) {
    logger.error('完成报修工单失败:', error);
    res.status(500).json(errorResponse('完成报修工单失败'));
  }
};