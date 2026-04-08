import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { v4 as uuidv4 } from 'uuid';

export const get = async (req: AuthRequest, res: Response) => {
  try {
    const { page = 1, pageSize = 10, status, guest_name } = req.query;
    const offset = (Number(page) - 1) * Number(pageSize);
    
    let whereClause = 'WHERE 1=1';
    const params: any[] = [];
    
    if (status) {
      whereClause += ' AND b.status = ?';
      params.push(status);
    }
    
    if (guest_name) {
      whereClause += ' AND b.guest_name LIKE ?';
      params.push(`%${guest_name}%`);
    }
    
    const [totalRows] = await pool.query<RowDataPacket[]>(`SELECT COUNT(*) as total FROM bookings b ${whereClause}`, params);
    const total = (totalRows[0] as any).total;
    
    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT b.*, r.room_number, r.room_type FROM bookings b LEFT JOIN rooms r ON b.room_id = r.id ${whereClause} ORDER BY b.id DESC LIMIT ? OFFSET ?`,
      [...params, Number(pageSize), offset]
    );
    
    res.json(successResponse({
      list: rows,
      total,
      page: Number(page),
      pageSize: Number(pageSize),
      totalPages: Math.ceil(total / Number(pageSize))
    }, '获取预订列表成功'));
  } catch (error) {
    logger.error('获取预订列表失败:', error);
    res.status(500).json(errorResponse('获取预订列表失败'));
  }
};

export const getById = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    
    const [rows] = await pool.query<RowDataPacket[]>(
      'SELECT b.*, r.room_number, r.room_type FROM bookings b LEFT JOIN rooms r ON b.room_id = r.id WHERE b.id = ?',
      [id]
    );
    
    if (rows.length === 0) {
      res.status(404).json(errorResponse('预订不存在'));
      return;
    }
    
    res.json(successResponse(rows[0], '获取预订详情成功'));
  } catch (error) {
    logger.error('获取预订详情失败:', error);
    res.status(500).json(errorResponse('获取预订详情失败'));
  }
};

export const create = async (req: AuthRequest, res: Response) => {
  try {
    const { room_id, guest_name, guest_phone, guest_id_number, check_in_date, check_out_date, guest_count, special_requests, payment_method, status } = req.body;
    
    const [roomRows] = await pool.query<RowDataPacket[]>('SELECT room_price, hotel_id FROM rooms WHERE id = ?', [room_id]);
    
    if (roomRows.length === 0) {
      res.status(404).json(errorResponse('房间不存在'));
      return;
    }
    
    const roomPrice = (roomRows[0] as any).room_price;
    const hotelId = (roomRows[0] as any).hotel_id;
    const checkIn = new Date(check_in_date);
    const checkOut = new Date(check_out_date);
    const days = Math.ceil((checkOut.getTime() - checkIn.getTime()) / (1000 * 60 * 60 * 24));
    const totalPrice = roomPrice * days;
    
    const bookingNumber = `BK${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${uuidv4().slice(0, 8).toUpperCase()}`;
    const bookingStatus = status || 'pending';
    
    const [result] = await pool.query<ResultSetHeader>(
      'INSERT INTO bookings (booking_number, hotel_id, room_id, guest_name, guest_phone, guest_id_number, check_in_date, check_out_date, guest_count, special_requests, payment_method, total_price, deposit, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [bookingNumber, hotelId, room_id, guest_name, guest_phone, guest_id_number, check_in_date, check_out_date, guest_count, special_requests, payment_method, totalPrice, 0, bookingStatus]
    );
    
    res.json(successResponse({ id: result.insertId, booking_number: bookingNumber, total_price: totalPrice }, '创建预订成功'));
  } catch (error) {
    logger.error('创建预订失败:', error);
    res.status(500).json(errorResponse('创建预订失败'));
  }
};

export const confirm = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    
    const [result] = await pool.query<ResultSetHeader>(
      'UPDATE bookings SET status = ? WHERE id = ?',
      ['confirmed', id]
    );
    
    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('预订不存在'));
      return;
    }
    
    res.json(successResponse(null, '确认预订成功'));
  } catch (error) {
    logger.error('确认预订失败:', error);
    res.status(500).json(errorResponse('确认预订失败'));
  }
};

export const checkin = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    
    const [result] = await pool.query<ResultSetHeader>(
      'UPDATE bookings SET status = ?, check_in_time = CURRENT_TIMESTAMP WHERE id = ?',
      ['checked_in', id]
    );
    
    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('预订不存在'));
      return;
    }
    
    res.json(successResponse(null, '办理入住成功'));
  } catch (error) {
    logger.error('办理入住失败:', error);
    res.status(500).json(errorResponse('办理入住失败'));
  }
};

export const checkout = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    
    const [result] = await pool.query<ResultSetHeader>(
      'UPDATE bookings SET status = ?, check_out_time = CURRENT_TIMESTAMP WHERE id = ?',
      ['checked_out', id]
    );
    
    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('预订不存在'));
      return;
    }
    
    res.json(successResponse(null, '办理退房成功'));
  } catch (error) {
    logger.error('办理退房失败:', error);
    res.status(500).json(errorResponse('办理退房失败'));
  }
};

export const cancel = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    
    const [result] = await pool.query<ResultSetHeader>(
      'UPDATE bookings SET status = ?, cancelled_at = CURRENT_TIMESTAMP WHERE id = ?',
      ['cancelled', id]
    );
    
    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('预订不存在'));
      return;
    }
    
    res.json(successResponse(null, '取消预订成功'));
  } catch (error) {
    logger.error('取消预订失败:', error);
    res.status(500).json(errorResponse('取消预订失败'));
  }
};
