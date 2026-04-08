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

export const lookupForGuest = async (req: Request, res: Response) => {
  try {
    const { keyword } = req.query;
    const normalizedKeyword = String(keyword || '').trim();

    if (!normalizedKeyword) {
      res.status(400).json(errorResponse('请输入预订号或手机号'));
      return;
    }

    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT b.id, b.booking_number, b.guest_name, b.guest_phone, b.check_in_date, b.check_out_date, b.status,
              r.id as room_id, r.room_number, r.room_name
       FROM bookings b
       LEFT JOIN rooms r ON b.room_id = r.id
       WHERE b.booking_number = ? OR b.guest_phone = ?
       ORDER BY b.id DESC
       LIMIT 1`,
      [normalizedKeyword, normalizedKeyword]
    );

    if (rows.length === 0) {
      res.status(404).json(errorResponse('未找到匹配预订'));
      return;
    }

    const booking = rows[0] as any;
    res.json(successResponse({
      id: booking.id,
      booking_no: booking.booking_number,
      guest_name: booking.guest_name,
      guest_phone: booking.guest_phone,
      room_id: booking.room_id,
      room_name: booking.room_name || booking.room_number,
      check_in: booking.check_in_date,
      check_out: booking.check_out_date,
      status: booking.status
    }, '查询预订成功'));
  } catch (error) {
    logger.error('查询预订失败:', error);
    res.status(500).json(errorResponse('查询预订失败'));
  }
};

export const checkinOnline = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { guest_phone, real_name, id_type, id_number, arrival_time, plate_number } = req.body || {};

    if (!guest_phone || !real_name || !id_number) {
      res.status(400).json(errorResponse('缺少必要参数（guest_phone, real_name, id_number）'));
      return;
    }

    const [bookingRows] = await pool.query<RowDataPacket[]>(
      `SELECT b.id, b.booking_number, b.guest_phone, b.status, b.room_id,
              r.room_number, r.room_name
       FROM bookings b
       LEFT JOIN rooms r ON b.room_id = r.id
       WHERE b.id = ?
       LIMIT 1`,
      [id]
    );

    if (bookingRows.length === 0) {
      res.status(404).json(errorResponse('预订不存在'));
      return;
    }

    const booking = bookingRows[0] as any;
    if (String(booking.guest_phone) !== String(guest_phone)) {
      res.status(403).json(errorResponse('手机号与预订信息不匹配'));
      return;
    }

    if (!['pending', 'confirmed', 'checked_in'].includes(booking.status)) {
      res.status(400).json(errorResponse('当前预订状态不允许办理入住'));
      return;
    }

    await pool.query<ResultSetHeader>(
      `UPDATE bookings
       SET guest_name = ?, guest_id_number = ?, status = ?, check_in_time = CURRENT_TIMESTAMP
       WHERE id = ?`,
      [real_name, id_number, 'checked_in', id]
    );

    const roomPin = uuidv4().replace(/-/g, '').slice(0, 6).toUpperCase();
    res.json(successResponse({
      booking_id: booking.id,
      booking_no: booking.booking_number,
      room_id: booking.room_id,
      room_name: booking.room_name || booking.room_number,
      room_pin: roomPin,
      profile: {
        real_name,
        id_type: id_type || 'idcard',
        id_number,
        arrival_time: arrival_time || null,
        plate_number: plate_number || null
      }
    }, '在线入住办理成功'));
  } catch (error) {
    logger.error('在线办理入住失败:', error);
    res.status(500).json(errorResponse('在线办理入住失败'));
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
