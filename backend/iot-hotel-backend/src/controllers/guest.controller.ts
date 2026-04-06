import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';

export const get = async (req: AuthRequest, res: Response) => {
  try {
    const { page = 1, pageSize = 10, booking_id, name, phone, status } = req.query;
    const offset = (Number(page) - 1) * Number(pageSize);
    
    let whereClause = 'WHERE 1=1';
    const params: any[] = [];
    
    if (booking_id) {
      whereClause += ' AND g.booking_id = ?';
      params.push(booking_id);
    }
    
    if (name) {
      whereClause += ' AND g.name LIKE ?';
      params.push(`%${name}%`);
    }
    
    if (phone) {
      whereClause += ' AND g.phone = ?';
      params.push(phone);
    }
    
    if (status) {
      whereClause += ' AND g.status = ?';
      params.push(status);
    }
    
    const [totalRows] = await pool.query<RowDataPacket[]>(`SELECT COUNT(*) as total FROM guests g ${whereClause}`, params);
    const total = (totalRows[0] as any).total;
    
    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT g.*, b.booking_number, r.room_number FROM guests g 
       LEFT JOIN bookings b ON g.booking_id = b.id 
       LEFT JOIN rooms r ON b.room_id = r.id 
       ${whereClause} ORDER BY g.id DESC LIMIT ? OFFSET ?`,
      [...params, Number(pageSize), offset]
    );
    
    res.json(successResponse({
      list: rows,
      total,
      page: Number(page),
      pageSize: Number(pageSize),
      totalPages: Math.ceil(total / Number(pageSize))
    }, '获取住客列表成功'));
  } catch (error) {
    logger.error('获取住客列表失败:', error);
    res.status(500).json(errorResponse('获取住客列表失败'));
  }
};

export const getById = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    
    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT g.*, b.booking_number, r.room_number FROM guests g 
       LEFT JOIN bookings b ON g.booking_id = b.id 
       LEFT JOIN rooms r ON b.room_id = r.id 
       WHERE g.id = ?`,
      [id]
    );
    
    if (rows.length === 0) {
      res.status(404).json(errorResponse('住客不存在'));
      return;
    }
    
    res.json(successResponse(rows[0], '获取住客详情成功'));
  } catch (error) {
    logger.error('获取住客详情失败:', error);
    res.status(500).json(errorResponse('获取住客详情失败'));
  }
};

export const create = async (req: AuthRequest, res: Response) => {
  try {
    const { booking_id, name, phone, id_type, id_number, check_in_time, status = 'checked_in' } = req.body;
    
    if (!booking_id || !name || !phone) {
      res.status(400).json(errorResponse('请求参数错误：缺少必要参数（booking_id, name, phone）'));
      return;
    }
    
    const [bookingRows] = await pool.query<RowDataPacket[]>('SELECT id, room_id FROM bookings WHERE id = ?', [booking_id]);
    
    if (bookingRows.length === 0) {
      res.status(404).json(errorResponse('预订不存在'));
      return;
    }
    
    const [result] = await pool.query<ResultSetHeader>(
      'INSERT INTO guests (booking_id, name, phone, id_type, id_number, check_in_time, status) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [booking_id, name, phone, id_type || null, id_number || null, check_in_time || new Date(), status]
    );
    
    res.json(successResponse({ id: result.insertId }, '创建住客记录成功'));
  } catch (error) {
    logger.error('创建住客记录失败:', error);
    res.status(500).json(errorResponse('创建住客记录失败'));
  }
};

export const update = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { name, phone, id_type, id_number, status, check_out_time } = req.body;
    
    const [existingGuest] = await pool.query<RowDataPacket[]>('SELECT * FROM guests WHERE id = ?', [id]);
    
    if (existingGuest.length === 0) {
      res.status(404).json(errorResponse('住客不存在'));
      return;
    }
    
    const updateFields: string[] = [];
    const params: any[] = [];
    
    if (name !== undefined) {
      updateFields.push('name = ?');
      params.push(name);
    }
    
    if (phone !== undefined) {
      updateFields.push('phone = ?');
      params.push(phone);
    }
    
    if (id_type !== undefined) {
      updateFields.push('id_type = ?');
      params.push(id_type);
    }
    
    if (id_number !== undefined) {
      updateFields.push('id_number = ?');
      params.push(id_number);
    }
    
    if (status !== undefined) {
      updateFields.push('status = ?');
      params.push(status);
      
      if (status === 'checked_out' && !check_out_time) {
        updateFields.push('check_out_time = ?');
        params.push(new Date());
      }
    }
    
    if (check_out_time !== undefined) {
      updateFields.push('check_out_time = ?');
      params.push(check_out_time);
    }
    
    if (updateFields.length === 0) {
      res.status(400).json(errorResponse('没有需要更新的字段'));
      return;
    }
    
    params.push(id);
    
    await pool.query<ResultSetHeader>(
      `UPDATE guests SET ${updateFields.join(', ')} WHERE id = ?`,
      params
    );
    
    res.json(successResponse(null, '更新住客信息成功'));
  } catch (error) {
    logger.error('更新住客信息失败:', error);
    res.status(500).json(errorResponse('更新住客信息失败'));
  }
};

export const remove = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    
    const [result] = await pool.query<ResultSetHeader>('DELETE FROM guests WHERE id = ?', [id]);
    
    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('住客不存在'));
      return;
    }
    
    res.json(successResponse(null, '删除住客记录成功'));
  } catch (error) {
    logger.error('删除住客记录失败:', error);
    res.status(500).json(errorResponse('删除住客记录失败'));
  }
};

export const getByBookingId = async (req: AuthRequest, res: Response) => {
  try {
    const { booking_id } = req.params;
    
    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT g.* FROM guests g WHERE g.booking_id = ? ORDER BY g.id`,
      [booking_id]
    );
    
    res.json(successResponse({ items: rows }, '获取预订住客列表成功'));
  } catch (error) {
    logger.error('获取预订住客列表失败:', error);
    res.status(500).json(errorResponse('获取预订住客列表失败'));
  }
};
