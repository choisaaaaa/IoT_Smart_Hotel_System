import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import { PoolConnection } from 'mysql2/promise';
import logger from '../utils/logger';
import { v4 as uuidv4 } from 'uuid';
import { isSystemRole } from '../utils/role';
import { LEVEL_DISCOUNTS } from './member.controller';

// 辅助函数：退房后更新会员成长值与等级
async function updateMemberExperienceAfterCheckout(connection: PoolConnection, guestPhone: string, totalPrice: number) {
  try {
    const [memberRows] = await connection.query<RowDataPacket[]>(
      'SELECT id, experience, member_level, total_spent, total_stays FROM members WHERE phone = ?',
      [guestPhone]
    );

    if (!memberRows || memberRows.length === 0) return;

    const member = memberRows[0];
    const expGain = Math.floor(totalPrice / 10);
    const newExp = (member.experience || 0) + expGain;
    const newSpent = Number(member.total_spent || 0) + Number(totalPrice);
    const newStays = (member.total_stays || 0) + 1;

    // 自动升级逻辑
    let newLevel = member.member_level;
    if (newExp >= 5000) newLevel = 'diamond';
    else if (newExp >= 2000) newLevel = 'platinum';
    else if (newExp >= 500) newLevel = 'gold';
    else if (newExp >= 100) newLevel = 'silver';
    else newLevel = 'standard';

    await connection.query(
      'UPDATE members SET experience = ?, member_level = ?, total_spent = ?, total_stays = ? WHERE id = ?',
      [newExp, newLevel, newSpent, newStays, member.id]
    );

    logger.info(`会员退房奖励: 手机号 ${guestPhone}, 获得成长值 ${expGain}, 总成长值 ${newExp}, 最终等级 ${newLevel}`);
  } catch (error) {
    logger.error('更新会员退房奖励失败:', error);
    // 退房流程不应因为奖励失败而中断
  }
}

// 辅助函数：计算预订最终价格 (集成价格日历与会员/优惠券逻辑)
async function calculateBookingPrice(connection: PoolConnection, roomId: number, checkInDate: string, checkOutDate: string, memberPhone?: string, couponId?: number) {
  const [roomRows] = await connection.query<RowDataPacket[]>(
    'SELECT r.room_price, r.hotel_id, r.room_type_id FROM rooms r WHERE r.id = ?',
    [roomId]
  );
  if (roomRows.length === 0) throw new Error('房间不存在');
  const room = roomRows[0];

  const start = new Date(checkInDate);
  const end = new Date(checkOutDate);
  let totalPrice = 0;

  // 1. 遍历每一天，根据价格日历计算基础总价
  for (let d = new Date(start); d < end; d.setDate(d.getDate() + 1)) {
    const dateStr = d.toISOString().split('T')[0];
    const [priceRows] = await connection.query<RowDataPacket[]>(
      'SELECT final_price FROM room_prices WHERE room_type_id = ? AND price_date = ?',
      [room.room_type_id, dateStr]
    );
    
    if (priceRows.length > 0) {
      totalPrice += Number(priceRows[0].final_price);
    } else {
      totalPrice += Number(room.room_price); // 无日历设置则使用房间默认价
    }
  }

  // 2. 应用会员折扣
  let discountRate = 1.0;
  let memberId = null;
  if (memberPhone) {
    const [memberRows] = await connection.query<RowDataPacket[]>('SELECT id, member_level FROM members WHERE phone = ?', [memberPhone]);
    if (memberRows.length > 0) {
      memberId = memberRows[0].id;
      discountRate = LEVEL_DISCOUNTS[memberRows[0].member_level] || 1.0;
      totalPrice = Math.floor(totalPrice * discountRate * 100) / 100;
    }
  }

  // 3. 应用优惠券
  if (couponId && memberId) {
    const [couponRows] = await connection.query<RowDataPacket[]>(
      `SELECT c.* FROM member_coupons mc 
       JOIN coupons c ON mc.coupon_id = c.id 
       WHERE mc.id = ? AND mc.member_id = ? AND mc.status = 'unused' AND c.valid_to >= CURDATE()`,
      [couponId, memberId]
    );

    if (couponRows.length > 0) {
      const coupon = couponRows[0];
      if (totalPrice >= (coupon.min_amount || 0)) {
        if (coupon.coupon_type === 'discount') {
          totalPrice = Math.floor(totalPrice * (Number(coupon.discount_value) / 10) * 100) / 100; // 假设折扣券存的是几折，如 8.5 表示 85 折
        } else if (coupon.coupon_type === 'cash') {
          totalPrice = Math.max(0, totalPrice - Number(coupon.discount_value));
        }
      }
    }
  }

  return { totalPrice, discountRate };
}

export const get = async (req: AuthRequest, res: Response) => {
  try {
    const isUser = req.user?.role === 'user';
    let hotelId = req.user?.hotel_id;

    if (isSystemRole(req.user?.role)) {
      const queryHotelId = req.query.hotel_id;
      if (queryHotelId) {
        hotelId = parseInt(queryHotelId as string);
      }
    }

    const { page = 1, pageSize = 10, status, guest_name, check_in_date, hotel_id: queryHotelId } = req.query;
    const offset = (Number(page) - 1) * Number(pageSize);

    let whereClause = 'WHERE 1=1';
    const params: any[] = [];

    // 如果不是普通用户，通常需要按酒店过滤
    if (!isUser) {
      if (!hotelId && !isSystemRole(req.user?.role)) {
        return res.status(401).json(errorResponse('未授权'));
      }
      if (hotelId) {
        whereClause += ' AND b.hotel_id = ?';
        params.push(hotelId);
      }
    } else {
      // 普通用户，可以按手机号、姓名或用户ID过滤
      const phone = req.user?.phone || req.user?.username;
      whereClause += ' AND (b.user_id = ? OR b.guest_phone = ? OR b.guest_name = ?)';
      params.push(req.user?.id);
      params.push(phone);
      params.push(req.user?.username);

      // 普通用户也可以传 hotel_id 来筛选特定酒店
      if (queryHotelId) {
        whereClause += ' AND b.hotel_id = ?';
        params.push(parseInt(queryHotelId as string));
      }
    }

    if (status) {
      whereClause += ' AND b.status = ?';
      params.push(status);
    }

    if (guest_name) {
      whereClause += ' AND b.guest_name LIKE ?';
      params.push(`%${guest_name}%`);
    }

    if (check_in_date) {
      if (check_in_date === 'today') {
        whereClause += ' AND DATE(b.check_in_date) = CURDATE()';
      } else {
        whereClause += ' AND DATE(b.check_in_date) = ?';
        params.push(check_in_date);
      }
    }

    const [totalRows] = await pool.query<RowDataPacket[]>(
      `SELECT COUNT(*) as total FROM bookings b ${whereClause}`,
      params
    );
    const total = (totalRows[0] as any).total;

    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT b.*, r.room_number, r.room_type, h.hotel_name
       FROM bookings b
       LEFT JOIN rooms r ON b.room_id = r.id
       LEFT JOIN hotels h ON b.hotel_id = h.id
       ${whereClause}
       ORDER BY b.id DESC LIMIT ? OFFSET ?`,
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
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const { room_id, guest_name, guest_phone, guest_id_number, check_in_date, check_out_date, guest_count, special_requests, payment_method, coupon_id, status } = req.body;

    const [roomRows] = await connection.query<RowDataPacket[]>('SELECT room_price, hotel_id FROM rooms WHERE id = ?', [room_id]);

    if (roomRows.length === 0) {
      await connection.rollback();
      res.status(404).json(errorResponse('房间不存在'));
      return;
    }

    const hotelId = (roomRows[0] as any).hotel_id;
    const userId = req.user?.id || null;
    const phone = guest_phone || req.user?.phone || req.user?.username;

    // 使用辅助函数计算最终价格 (集成价格日历、会员折扣、优惠券)
    const { totalPrice, discountRate } = await calculateBookingPrice(
      connection, 
      room_id, 
      check_in_date, 
      check_out_date, 
      phone, 
      coupon_id
    );

    // 如果使用了优惠券，标记为已使用
    if (coupon_id) {
       await connection.query('UPDATE member_coupons SET status = "used", used_at = CURRENT_TIMESTAMP WHERE id = ?', [coupon_id]);
    }

    const bookingNumber = `BK${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${uuidv4().slice(0, 8).toUpperCase()}`;
    const bookingStatus = status || 'pending';
    const checkInTime = bookingStatus === 'checked_in' ? new Date() : null;

    const [result] = await connection.query<ResultSetHeader>(
      'INSERT INTO bookings (booking_number, hotel_id, room_id, user_id, guest_name, guest_phone, guest_id_number, check_in_date, check_out_date, guest_count, special_requests, payment_method, coupon_id, total_price, deposit, status, check_in_time) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [bookingNumber, hotelId, room_id, userId, guest_name, guest_phone, guest_id_number, check_in_date, check_out_date, guest_count, special_requests, payment_method, coupon_id || null, totalPrice, 0, bookingStatus, checkInTime]
    );

    const bookingId = result.insertId;

    // 如果是直接办理入住，插入到 guests 表
    if (bookingStatus === 'checked_in') {
      await connection.query(
        `INSERT INTO guests (booking_id, guest_name, guest_phone, guest_id_number, room_id, check_in_time)
         VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)`,
        [bookingId, guest_name, guest_phone, guest_id_number || null, room_id]
      );

      // 同步更新房间状态为“在住”
      await connection.query('UPDATE rooms SET room_status = ? WHERE id = ?', ['occupied', room_id]);
    } else if (bookingStatus === 'confirmed') {
      // 同步更新房间状态为“已预订”
      await connection.query('UPDATE rooms SET room_status = ? WHERE id = ?', ['reserved', room_id]);
    }

    await connection.commit();
    res.json(successResponse({ id: bookingId, booking_number: bookingNumber, total_price: totalPrice }, '创建预订成功'));
  } catch (error) {
    await connection.rollback();
    logger.error('创建预订失败:', error);
    res.status(500).json(errorResponse('创建预订失败'));
  } finally {
    connection.release();
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
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const { id } = req.params;
    const { guest_phone, real_name, id_type, id_number, arrival_time, plate_number } = req.body || {};

    if (!guest_phone || !real_name || !id_number) {
      await connection.rollback();
      res.status(400).json(errorResponse('缺少必要参数（guest_phone, real_name, id_number）'));
      return;
    }

    const [bookingRows] = await connection.query<RowDataPacket[]>(
      `SELECT b.id, b.booking_number, b.guest_phone, b.status, b.room_id,
              r.room_number, r.room_name
       FROM bookings b
       LEFT JOIN rooms r ON b.room_id = r.id
       WHERE b.id = ?
       LIMIT 1`,
      [id]
    );

    if (bookingRows.length === 0) {
      await connection.rollback();
      res.status(404).json(errorResponse('预订不存在'));
      return;
    }

    const booking = bookingRows[0] as any;
    if (String(booking.guest_phone) !== String(guest_phone)) {
      await connection.rollback();
      res.status(403).json(errorResponse('手机号与预订信息不匹配'));
      return;
    }

    if (!['pending', 'confirmed', 'checked_in'].includes(booking.status)) {
      await connection.rollback();
      res.status(400).json(errorResponse('当前预订状态不允许办理入住'));
      return;
    }

    await connection.query<ResultSetHeader>(
      `UPDATE bookings
       SET guest_name = ?, guest_id_number = ?, status = ?, check_in_time = CURRENT_TIMESTAMP
       WHERE id = ?`,
      [real_name, id_number, 'checked_in', id]
    );

    // 插入到 guests 表
    await connection.query(
      `INSERT INTO guests (booking_id, guest_name, guest_phone, guest_id_number, room_id, check_in_time)
       VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)`,
      [id, real_name, guest_phone, id_number, booking.room_id]
    );

    // 同步更新房间状态为“在住”
    if (booking.room_id) {
      await connection.query('UPDATE rooms SET room_status = ? WHERE id = ?', ['occupied', booking.room_id]);
    }

    await connection.commit();
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
    await connection.rollback();
    logger.error('在线办理入住失败:', error);
    res.status(500).json(errorResponse('在线办理入住失败'));
  } finally {
    connection.release();
  }
};

export const confirm = async (req: AuthRequest, res: Response) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const { id } = req.params;

    // 获取订单信息
    const [bookingRows] = await connection.query<RowDataPacket[]>('SELECT room_id FROM bookings WHERE id = ?', [id]);
    if (bookingRows.length === 0) {
      await connection.rollback();
      res.status(404).json(errorResponse('预订不存在'));
      return;
    }
    const roomId = (bookingRows[0] as any).room_id;

    await connection.query<ResultSetHeader>(
      'UPDATE bookings SET status = ? WHERE id = ?',
      ['confirmed', id]
    );

    // 同步更新房间状态为“已预订”
    if (roomId) {
      await connection.query('UPDATE rooms SET room_status = ? WHERE id = ?', ['reserved', roomId]);
    }

    await connection.commit();
    res.json(successResponse(null, '确认预订成功'));
  } catch (error) {
    await connection.rollback();
    logger.error('确认预订失败:', error);
    res.status(500).json(errorResponse('确认预订失败'));
  } finally {
    connection.release();
  }
};

export const checkin = async (req: AuthRequest, res: Response) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const { id } = req.params;
    const { user_id, guest_name, guest_phone, guest_id_number, special_requests } = req.body || {};

    // 获取订单信息
    const [bookingRows] = await connection.query<RowDataPacket[]>('SELECT room_id, guest_name, guest_phone, guest_id_number FROM bookings WHERE id = ?', [id]);
    if (bookingRows.length === 0) {
      await connection.rollback();
      res.status(404).json(errorResponse('预订不存在'));
      return;
    }
    const booking = bookingRows[0] as any;
    const roomId = booking.room_id;

    // 构建更新字段
    const updateFields: string[] = ['status = ?', 'check_in_time = CURRENT_TIMESTAMP'];
    const params: any[] = ['checked_in', id];

    // 如果提供了user_id，则关联用户账号
    if (user_id) {
      updateFields.push('user_id = ?');
      params.splice(params.length - 1, 0, user_id); // 在id之前插入user_id
    }

    // 如果提供了其他信息，也一并更新
    if (guest_name) {
      updateFields.push('guest_name = ?');
      params.splice(params.length - 1, 0, guest_name);
    }
    if (guest_phone) {
      updateFields.push('guest_phone = ?');
      params.splice(params.length - 1, 0, guest_phone);
    }
    if (guest_id_number) {
      updateFields.push('guest_id_number = ?');
      params.splice(params.length - 1, 0, guest_id_number);
    }
    if (special_requests !== undefined) {
      updateFields.push('special_requests = ?');
      params.splice(params.length - 1, 0, special_requests);
    }

    await connection.query<ResultSetHeader>(
      `UPDATE bookings SET ${updateFields.join(', ')} WHERE id = ?`,
      params
    );

    // 插入到 guests 表
    await connection.query(
      `INSERT INTO guests (booking_id, guest_name, guest_phone, guest_id_number, room_id, check_in_time)
       VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)`,
      [id, guest_name || booking.guest_name, guest_phone || booking.guest_phone, guest_id_number || booking.guest_id_number, roomId]
    );

    // 同步更新房间状态为“在住”
    if (roomId) {
      await connection.query('UPDATE rooms SET room_status = ? WHERE id = ?', ['occupied', roomId]);
    }

    await connection.commit();
    res.json(successResponse(null, '办理入住成功'));
  } catch (error) {
    await connection.rollback();
    logger.error('办理入住失败:', error);
    res.status(500).json(errorResponse('办理入住失败'));
  } finally {
    connection.release();
  }
};

export const checkout = async (req: AuthRequest, res: Response) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const { id } = req.params;

    // 获取订单信息
    const [bookingRows] = await connection.query<RowDataPacket[]>('SELECT room_id, guest_phone, total_price FROM bookings WHERE id = ?', [id]);
    if (bookingRows.length === 0) {
      await connection.rollback();
      res.status(404).json(errorResponse('预订不存在'));
      return;
    }
    const booking = bookingRows[0] as any;
    const roomId = booking.room_id;

    await connection.query<ResultSetHeader>(
      'UPDATE bookings SET status = ?, check_out_time = CURRENT_TIMESTAMP WHERE id = ?',
      ['checked_out', id]
    );

    // 更新 guests 表
    await connection.query(
      'UPDATE guests SET check_out_time = CURRENT_TIMESTAMP WHERE booking_id = ? AND check_out_time IS NULL',
      [id]
    );

    // 同步更新房间状态为“待扫”
    if (roomId) {
      await connection.query('UPDATE rooms SET room_status = ? WHERE id = ?', ['cleaning', roomId]);
    }

    // 更新会员成长值
    if (booking.guest_phone && booking.total_price) {
      await updateMemberExperienceAfterCheckout(connection, booking.guest_phone, booking.total_price);
    }

    await connection.commit();
    res.json(successResponse(null, '办理退房成功'));
  } catch (error) {
    await connection.rollback();
    logger.error('办理退房失败:', error);
    res.status(500).json(errorResponse('办理退房失败'));
  } finally {
    connection.release();
  }
};

export const cancel = async (req: AuthRequest, res: Response) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const { id } = req.params;

    // 获取订单信息
    const [bookingRows] = await connection.query<RowDataPacket[]>('SELECT room_id FROM bookings WHERE id = ?', [id]);
    if (bookingRows.length === 0) {
      await connection.rollback();
      res.status(404).json(errorResponse('预订不存在'));
      return;
    }
    const roomId = (bookingRows[0] as any).room_id;

    await connection.query<ResultSetHeader>(
      'UPDATE bookings SET status = ?, cancelled_at = CURRENT_TIMESTAMP WHERE id = ?',
      ['cancelled', id]
    );

    // 如果取消预订，将房间状态恢复为“空闲”
    if (roomId) {
      await connection.query('UPDATE rooms SET room_status = ? WHERE id = ?', ['available', roomId]);
    }

    await connection.commit();
    res.json(successResponse(null, '取消预订成功'));
  } catch (error) {
    await connection.rollback();
    logger.error('取消预订失败:', error);
    res.status(500).json(errorResponse('取消预订失败'));
  } finally {
    connection.release();
  }
};

export const updateStatus = async (req: AuthRequest, res: Response) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const { id } = req.params;
    const { status } = req.body;

    if (!status) {
      await connection.rollback();
      return res.status(400).json(errorResponse('缺少状态参数'));
    }

    const [bookingRows] = await connection.query<RowDataPacket[]>('SELECT room_id, guest_phone, total_price FROM bookings WHERE id = ?', [id]);
    if (bookingRows.length === 0) {
      await connection.rollback();
      res.status(404).json(errorResponse('预订不存在'));
      return;
    }
    const booking = bookingRows[0] as any;
    const roomId = booking.room_id;

    await connection.query<ResultSetHeader>(
      'UPDATE bookings SET status = ? WHERE id = ?',
      [status, id]
    );

    if (status === 'checked_out') {
      await connection.query(
        'UPDATE guests SET check_out_time = CURRENT_TIMESTAMP WHERE booking_id = ? AND check_out_time IS NULL',
        [id]
      );
      if (booking.guest_phone && booking.total_price) {
        await updateMemberExperienceAfterCheckout(connection, booking.guest_phone, booking.total_price);
      }
    }

    if (roomId) {
      let roomStatus: string | null = null;
      if (status === 'checked_in') roomStatus = 'occupied';
      else if (status === 'confirmed') roomStatus = 'reserved';
      else if (status === 'checked_out') roomStatus = 'cleaning';
      else if (status === 'cancelled') roomStatus = 'available';

      if (roomStatus) {
        await connection.query('UPDATE rooms SET room_status = ? WHERE id = ?', [roomStatus, roomId]);
      }
    }

    await connection.commit();
    res.json(successResponse(null, '更新预订状态成功'));
  } catch (error) {
    await connection.rollback();
    logger.error('更新预订状态失败:', error);
    res.status(500).json(errorResponse('更新预订状态失败'));
  } finally {
    connection.release();
  }
};

export const extendStay = async (req: AuthRequest, res: Response) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const { id } = req.params;
    const { check_out_date } = req.body;

    if (!check_out_date) {
      await connection.rollback();
      return res.status(400).json(errorResponse('请提供新的退房日期'));
    }

    const [bookingRows] = await connection.query<RowDataPacket[]>(
      'SELECT * FROM bookings WHERE id = ?',
      [id]
    );

    if (bookingRows.length === 0) {
      await connection.rollback();
      res.status(404).json(errorResponse('预订不存在'));
      return;
    }

    const booking = bookingRows[0] as any;

    if (!['checked_in', 'confirmed'].includes(booking.status)) {
      await connection.rollback();
      return res.status(400).json(errorResponse('当前预订状态不允许续住'));
    }

    const currentCheckOut = new Date(booking.check_out_date);
    const newCheckOut = new Date(check_out_date);

    if (newCheckOut <= currentCheckOut) {
      await connection.rollback();
      return res.status(400).json(errorResponse('新退房日期必须晚于当前退房日期'));
    }

    const [roomRows] = await connection.query<RowDataPacket[]>(
      'SELECT room_price FROM rooms WHERE id = ?',
      [booking.room_id]
    );

    const roomPrice = roomRows.length > 0 ? (roomRows[0] as any).room_price : 0;
    const currentCheckIn = new Date(booking.current_check_in_date || booking.check_in_date);
    const newTotalDays = Math.ceil((newCheckOut.getTime() - currentCheckIn.getTime()) / (1000 * 60 * 60 * 24));
    
    // 续住加收费用计算 (也需要应用会员折扣)
    const phone = req.user?.phone || req.user?.username;
    let discountRate = 1.0;
    if (phone) {
      const [memberRows] = await connection.query<RowDataPacket[]>('SELECT member_level FROM members WHERE phone = ?', [phone]);
      if (memberRows.length > 0) {
        discountRate = LEVEL_DISCOUNTS[memberRows[0].member_level] || 1.0;
      }
    }

    const newTotalPrice = Math.floor(roomPrice * newTotalDays * discountRate * 100) / 100;
    const additionalDays = Math.ceil((newCheckOut.getTime() - currentCheckOut.getTime()) / (1000 * 60 * 60 * 24));
    const additionalPrice = Math.floor(roomPrice * additionalDays * discountRate * 100) / 100;

    await connection.query<ResultSetHeader>(
      'UPDATE bookings SET check_out_date = ?, total_price = ? WHERE id = ?',
      [check_out_date, newTotalPrice, id]
    );

    await connection.commit();
    res.json(successResponse({
      booking_id: id,
      new_check_out_date: check_out_date,
      additional_nights: additionalDays,
      additional_price: additionalPrice,
      new_total_price: newTotalPrice,
      need_payment: additionalPrice > 0
    }, '续住成功'));
  } catch (error) {
    await connection.rollback();
    logger.error('续住失败:', error);
    res.status(500).json(errorResponse('续住失败'));
  } finally {
    connection.release();
  }
};

export const getCalculatedPrice = async (req: AuthRequest, res: Response) => {
  const connection = await pool.getConnection();
  try {
    const { room_id, check_in_date, check_out_date, guest_phone, coupon_id } = req.query;
    
    if (!room_id || !check_in_date || !check_out_date) {
      return res.status(400).json(errorResponse('缺少必要参数'));
    }

    const phone = (guest_phone as string) || req.user?.phone || req.user?.username;

    const { totalPrice, discountRate } = await calculateBookingPrice(
      connection,
      Number(room_id),
      check_in_date as string,
      check_out_date as string,
      phone,
      coupon_id ? Number(coupon_id) : undefined
    );

    res.json(successResponse({
      total_price: totalPrice,
      discount_rate: discountRate
    }, '价格计算成功'));
  } catch (error: any) {
    logger.error('计算价格失败:', error);
    res.status(500).json(errorResponse(error.message || '计算价格失败'));
  } finally {
    connection.release();
  }
};
