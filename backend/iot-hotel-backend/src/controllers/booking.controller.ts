import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import { PoolConnection } from 'mysql2/promise';
import logger from '../utils/logger';
import dayjs from 'dayjs';
import { v4 as uuidv4 } from 'uuid';
import { isSystemAdmin, isCustomer, isStaff, isHotelAdmin, CANONICAL_ROLES } from '../utils/role';
import { LEVEL_DISCOUNTS, LEVEL_POINTS_MULTIPLIER } from '../config/constants';
import { orderTimeoutService } from '../services/order-timeout.service';

// 辅助函数：退房后更新会员成长值、积分与等级
async function updateMemberExperienceAfterCheckout(connection: PoolConnection, guestPhone: string, totalPrice: number) {
  try {
    // 1. 获取系统积分配置 (默认 1元 = 10积分)
    let pointsRate = 10;
    try {
      const [configRows] = await connection.query<RowDataPacket[]>(
        'SELECT config_value FROM system_settings WHERE config_key = ?',
        ['points_rate']
      );
      if (configRows.length > 0) {
        pointsRate = Number(configRows[0].config_value);
      }
    } catch (e) {
      logger.warn('获取积分倍率配置失败，使用默认值 10');
    }

    // 2. 获取会员当前信息
    const [memberRows] = await connection.query<RowDataPacket[]>(
      'SELECT id, experience, points, member_level, total_spent, total_stays FROM members WHERE phone = ?',
      [guestPhone]
    );

    if (!memberRows || memberRows.length === 0) return;

    const member = memberRows[0];
    
    // 3. 计算奖励
    // 成长值: 10元 = 1点 (固定)
    const expGain = Math.floor(totalPrice / 10);
    const newExp = (member.experience || 0) + expGain;
    
    // 积分: 1元 = pointsRate点 * 会员等级倍率
    const multiplier = LEVEL_POINTS_MULTIPLIER[member.member_level] || 1;
    const pointsGain = Math.floor(totalPrice * pointsRate * multiplier);
    const newPoints = (member.points || 0) + pointsGain;
    
    const newSpent = Number(member.total_spent || 0) + Number(totalPrice);
    const newStays = (member.total_stays || 0) + 1;

    // 4. 自动升级逻辑 (基于成长值)
    let newLevel = member.member_level;
    if (newExp >= 5000) newLevel = 'diamond';
    else if (newExp >= 2000) newLevel = 'platinum';
    else if (newExp >= 500) newLevel = 'gold';
    else if (newExp >= 100) newLevel = 'silver';
    else newLevel = 'standard';

    // 5. 更新数据库
    await connection.query(
      'UPDATE members SET experience = ?, points = ?, member_level = ?, total_spent = ?, total_stays = ? WHERE id = ?',
      [newExp, newPoints, newLevel, newSpent, newStays, member.id]
    );

    logger.info(`会员退房奖励成功: 手机号 ${guestPhone}, 获得成长值 ${expGain}(总:${newExp}), 获得积分 ${pointsGain}(总:${newPoints}), 最终等级 ${newLevel}`);
  } catch (error) {
    logger.error('更新会员退房奖励失败:', error.message);
    // 退房流程不应因为奖励失败而中断
  }
}

// 辅助函数：计算预订最终价格 (集成价格日历、会员折扣、优惠券与积分抵扣)
async function calculateBookingPrice(
  connection: PoolConnection, 
  roomId: number, 
  checkInDate: string, 
  checkOutDate: string, 
  memberPhone?: string, 
  couponId?: number,
  usedPoints?: number,
  ratePlanId?: number
) {
  const floor2 = (v: number) => Math.floor(Number(v || 0) * 100) / 100;

  const checkIn = dayjs(checkInDate);
  const checkOut = dayjs(checkOutDate);
  if (!checkIn.isValid() || !checkOut.isValid()) {
    throw new Error('入住或退房日期无效');
  }

  const nights = checkOut.diff(checkIn, 'day');
  if (nights <= 0) {
    throw new Error('退房日期必须晚于入住日期');
  }

  const [roomRows] = await connection.query<RowDataPacket[]>(
    'SELECT r.room_price, r.hotel_id, COALESCE(r.room_type_id, rt.id) as room_type_id FROM rooms r LEFT JOIN room_types rt ON r.room_type = rt.code AND (rt.hotel_id = r.hotel_id OR rt.hotel_id = 0) WHERE r.id = ?',
    [roomId]
  );
  if (roomRows.length === 0) throw new Error('房间不存在');
  const room = roomRows[0];

  let planBasePrice = 0;
  if (ratePlanId) {
    const [planRows] = await connection.query<RowDataPacket[]>(
      'SELECT base_price FROM rate_plans WHERE id = ?',
      [ratePlanId]
    );
    if (planRows.length > 0) {
      planBasePrice = Number(planRows[0].base_price);
    }
  }

  let basePrice = 0;
  const normalizedPlanId = ratePlanId ?? null;

  for (let i = 0; i < nights; i++) {
    const dateStr = checkIn.add(i, 'day').format('YYYY-MM-DD');
    const [priceRows] = await connection.query<RowDataPacket[]>(
      'SELECT final_price FROM room_prices WHERE room_type_id = ? AND price_date = ? AND (rate_plan_id = ? OR (rate_plan_id IS NULL AND ? IS NULL))',
      [room.room_type_id, dateStr, normalizedPlanId, normalizedPlanId]
    );

    if (priceRows.length > 0) {
      basePrice += Number(priceRows[0].final_price);
    } else if (planBasePrice > 0) {
      basePrice += planBasePrice;
    } else {
      basePrice += Number(room.room_price);
    }
  }
  basePrice = floor2(basePrice);

  let discountRate = 1.0;
  let memberId: number | null = null;
  let availablePoints = 0;
  let memberLevel = 'standard';

  if (memberPhone) {
    const [memberRows] = await connection.query<RowDataPacket[]>('SELECT id, member_level, points FROM members WHERE phone = ?', [memberPhone]);
    if (memberRows.length > 0) {
      memberId = memberRows[0].id;
      // 关键修复：确保等级名称小写并去除可能的空格，匹配 constants.ts 中的键名
      memberLevel = String(memberRows[0].member_level || 'standard').toLowerCase().trim();
      availablePoints = memberRows[0].points || 0;
      
      // 调试：打印当前所有的折扣配置和匹配到的等级
      logger.info(`价格计算 - 当前 LEVEL_DISCOUNTS: ${JSON.stringify(LEVEL_DISCOUNTS)}`);
      logger.info(`价格计算 - 尝试匹配等级: [${memberLevel}]`);
      
      // 增加冗余匹配逻辑：处理可能的中文字符或大小写
      let rate = LEVEL_DISCOUNTS[memberLevel];
      if (rate === undefined) {
        if (memberLevel.includes('银') || memberLevel === 'silver') rate = LEVEL_DISCOUNTS['silver'];
        else if (memberLevel.includes('金') || memberLevel === 'gold') rate = LEVEL_DISCOUNTS['gold'];
        else if (memberLevel.includes('铂') || memberLevel === 'platinum') rate = LEVEL_DISCOUNTS['platinum'];
        else if (memberLevel.includes('钻') || memberLevel === 'diamond') rate = LEVEL_DISCOUNTS['diamond'];
      }
      
      discountRate = Number(rate || 1.0);
      logger.info(`价格计算 - 识别到会员: 手机号=${memberPhone}, 等级=${memberLevel}, 最终采用折扣率=${discountRate}`);
    } else {
      logger.warn(`价格计算 - 未找到手机号为 ${memberPhone} 的会员`);
    }
  }

  const memberDiscountedPrice = floor2(basePrice * discountRate);
  let totalPrice = memberDiscountedPrice;
  const memberDiscount = floor2(basePrice - memberDiscountedPrice);
  let couponDiscount = 0;

  logger.info(`价格计算 - 基础总价: ${basePrice}, 会员价: ${totalPrice}, 优惠: ${memberDiscount}, 折扣率: ${discountRate}`);

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
          const priceBeforeCoupon = totalPrice;
          totalPrice = floor2(totalPrice * (Number(coupon.discount_value) / 10));
          couponDiscount = floor2(priceBeforeCoupon - totalPrice);
        } else if (coupon.coupon_type === 'cash') {
          couponDiscount = floor2(Number(coupon.discount_value));
          totalPrice = floor2(Math.max(0, totalPrice - couponDiscount));
        }
        logger.info(`价格计算 - 应用优惠券: 类型=${coupon.coupon_type}, 优惠=${couponDiscount}`);
      }
    }
  }

  let pointsDiscount = 0;
  let actualUsedPoints = 0;
  if (usedPoints && usedPoints > 0 && memberId) {
    actualUsedPoints = Math.min(usedPoints, availablePoints);

    let redeemRate = 10;
    try {
      const [configRows] = await connection.query<RowDataPacket[]>(
        'SELECT config_value FROM system_settings WHERE config_key = ?',
        ['points_redeem_rate']
      );
      if (configRows.length > 0) redeemRate = Number(configRows[0].config_value);
    } catch (e) {}

    if (!redeemRate || redeemRate <= 0) redeemRate = 10;
    pointsDiscount = floor2(actualUsedPoints / redeemRate);
    if (pointsDiscount > totalPrice) {
      pointsDiscount = totalPrice;
      actualUsedPoints = Math.ceil(pointsDiscount * redeemRate);
    }
    totalPrice = floor2(Math.max(0, totalPrice - pointsDiscount));
    logger.info(`价格计算 - 应用积分: 使用=${actualUsedPoints}, 抵扣=${pointsDiscount}`);
  }

  return {
    total_price: totalPrice,
    discount_rate: discountRate,
    base_price: basePrice,
    member_level: memberLevel,
    member_discount: memberDiscount,
    coupon_discount: couponDiscount,
    points_discount: pointsDiscount,
    pointsDiscount: pointsDiscount,
    usedPoints: actualUsedPoints,
    used_points: actualUsedPoints,
    debug: {
      received_phone: memberPhone || '未提供',
      member_found: !!memberId,
      member_level_raw: memberLevel,
      discount_rate_applied: discountRate,
      all_discounts_config: LEVEL_DISCOUNTS,
      base_price_raw: basePrice,
      total_after_member_discount: memberDiscountedPrice
    }
  };
}

export const get = async (req: AuthRequest, res: Response) => {
  try {
    const isUser = isCustomer(req.user?.role);
    let hotelId = req.user?.hotel_id;

    if (isSystemAdmin(req.user?.role)) {
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
      if (!hotelId && !isSystemAdmin(req.user?.role)) {
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
    logger.error('获取预订列表失败:', error.message);
    res.status(500).json(errorResponse('获取预订列表失败'));
  }
};

export const getById = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;

    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT b.*, r.room_number, r.room_type, rp.plan_name, rp.meal_plan, rp.cancellation_policy
       FROM bookings b 
       LEFT JOIN rooms r ON b.room_id = r.id 
       LEFT JOIN rate_plans rp ON b.rate_plan_id = rp.id
       WHERE b.id = ?`,
      [id]
    );

    if (rows.length === 0) {
      res.status(404).json(errorResponse('预订不存在'));
      return;
    }

    res.json(successResponse(rows[0], '获取预订详情成功'));
  } catch (error) {
    logger.error('获取预订详情失败:', error.message);
    res.status(500).json(errorResponse('获取预订详情失败'));
  }
};

export const create = async (req: AuthRequest, res: Response) => {
  logger.info(`收到创建预订请求: body=${JSON.stringify(req.body)}`);
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const { 
      room_id, rate_plan_id, guest_name, guest_phone, guest_id_number, 
      check_in_date, check_out_date, guest_count, special_requests, 
      payment_method, coupon_id, used_points, status 
    } = req.body;

    const [roomRows] = await connection.query<RowDataPacket[]>(
      'SELECT room_price, hotel_id, room_status, room_number, locked_by_booking FROM rooms WHERE id = ? FOR UPDATE',
      [room_id]
    );

    if (roomRows.length === 0) {
      await connection.rollback();
      res.status(404).json(errorResponse('房间不存在'));
      return;
    }

    const room = roomRows[0] as any;
    const hotelId = room.hotel_id;
    const roomNumber = room.room_number;
    const bookingStatus = status || 'pending';

    // 悲观锁：校验房间是否可预订
    if (bookingStatus !== 'checked_in') {
      if (room.room_status !== 'available' && room.room_status !== 'cleaning') {
        if (room.locked_by_booking) {
          await connection.rollback();
          return res.status(409).json(errorResponse('该房间已被其他顾客预订，请选择其他房间'));
        }
      }
    }

    // 校验子房价方案及其限制
    if (rate_plan_id) {
      const [planRows] = await connection.query<RowDataPacket[]>('SELECT * FROM rate_plans WHERE id = ?', [rate_plan_id]);
      if (planRows.length === 0) {
        await connection.rollback();
        return res.status(400).json(errorResponse('无效的房价方案'));
      }
      const plan = planRows[0];
      if (plan.payment_type === 'online_only' && payment_method === 'front_desk') {
        await connection.rollback();
        return res.status(400).json(errorResponse('该方案仅限在线支付'));
      }
      if (plan.payment_type === 'front_desk_only' && payment_method !== 'front_desk') {
        await connection.rollback();
        return res.status(400).json(errorResponse('该方案仅限到店支付'));
      }
    }

    // 对于前台端办理入住，需要根据顾客手机号查找或创建顾客用户
    let userId = req.user?.id || null;
    const phone = guest_phone || req.user?.phone || req.user?.username;
    
    // 如果当前用户是前台/管理员，且提供了顾客手机号，则查找顾客用户
    if (isStaff(req.user?.role) || isHotelAdmin(req.user?.role)) {
      if (guest_phone) {
        // 查找顾客用户
        const [userRows] = await connection.query<RowDataPacket[]>(
          'SELECT id FROM users WHERE phone = ? AND role = "guest" LIMIT 1',
          [guest_phone]
        );
        if (userRows.length > 0) {
          userId = (userRows[0] as any).id;
          logger.info(`前台端办理入住：找到顾客用户 ID=${userId}, phone=${guest_phone}`);
        } else {
          // 如果没有找到顾客用户，创建一个新顾客用户
          const [createResult] = await connection.query<ResultSetHeader>(
            `INSERT INTO users (username, phone, role, status, created_at, updated_at) 
             VALUES (?, ?, 'guest', 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)`,
            [guest_name || guest_phone, guest_phone]
          );
          userId = createResult.insertId;
          logger.info(`前台端办理入住：创建新顾客用户 ID=${userId}, phone=${guest_phone}`);
        }
      }
    }

    // 使用辅助函数计算最终价格 (集成价格日历、子房价方案、会员折扣、优惠券、积分抵扣)
    const { total_price, discount_rate, used_points: actualUsedPoints, points_discount } = await calculateBookingPrice(
      connection,
      room_id,
      check_in_date,
      check_out_date,
      phone,
      coupon_id,
      used_points,
      rate_plan_id
    );

    // 如果使用了优惠券，标记为已使用
    if (coupon_id) {
       await connection.query('UPDATE member_coupons SET status = "used", used_at = CURRENT_TIMESTAMP WHERE id = ?', [coupon_id]);
    }

    // 如果使用了积分，扣除积分
    if (actualUsedPoints > 0) {
      await connection.query('UPDATE members SET points = points - ? WHERE phone = ?', [actualUsedPoints, phone]);
    }

    const bookingNumber = `BK${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${uuidv4().slice(0, 8).toUpperCase()}`;
    const checkInTime = bookingStatus === 'checked_in' ? new Date() : null;
    const paymentDeadline = orderTimeoutService.getPaymentDeadline();
    const autoCheckoutAt = orderTimeoutService.calculateAutoCheckoutTime(check_out_date);

    const [result] = await connection.query<ResultSetHeader>(
      `INSERT INTO bookings (
        booking_number, hotel_id, room_id, rate_plan_id, user_id, 
        guest_name, guest_phone, guest_id_number, check_in_date, check_out_date, 
        guest_count, special_requests, payment_method, coupon_id, used_points, 
        points_discount, total_price, deposit, status, check_in_time,
        locked_at, locked_by, payment_deadline, auto_checkout_at, room_number
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        bookingNumber, hotelId, room_id, rate_plan_id || null, userId, 
        guest_name, guest_phone, guest_id_number, check_in_date, check_out_date, 
        guest_count, special_requests, payment_method, coupon_id || null, actualUsedPoints, 
        points_discount, total_price, 0, bookingStatus, checkInTime,
        new Date(), userId, bookingStatus === 'pending' ? paymentDeadline : null, autoCheckoutAt, roomNumber
      ]
    );

    const bookingId = result.insertId;

    if (bookingStatus === 'checked_in') {
      await connection.query(
        `INSERT INTO guests (booking_id, guest_name, guest_phone, guest_id_number, room_id, check_in_time)
         VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
         ON DUPLICATE KEY UPDATE guest_name = VALUES(guest_name), guest_id_number = VALUES(guest_id_number), room_id = VALUES(room_id)`,
        [bookingId, guest_name, guest_phone, guest_id_number || null, room_id]
      );
      await connection.query(
        `UPDATE rooms SET room_status = 'occupied', locked_by_booking = ?, locked_at = NOW() WHERE id = ?`,
        [bookingId, room_id]
      );
    } else if (bookingStatus === 'pending') {
      await connection.query(
        `UPDATE rooms SET room_status = 'reserved', locked_by_booking = ?, locked_at = NOW() WHERE id = ?`,
        [bookingId, room_id]
      );
      logger.info(`[悲观锁] 房间 ${roomNumber}(id=${room_id}) 已被预订 ${bookingNumber} 锁定，15分钟内需完成支付`);
    } else if (bookingStatus === 'confirmed') {
      await connection.query(
        `UPDATE rooms SET room_status = 'reserved', locked_by_booking = ?, locked_at = NOW() WHERE id = ?`,
        [bookingId, room_id]
      );
    }

    await connection.commit();
    res.json(successResponse({ 
      id: bookingId, 
      booking_number: bookingNumber, 
      total_price: total_price,
      payment_deadline: bookingStatus === 'pending' ? paymentDeadline : null,
      auto_checkout_at: autoCheckoutAt,
      room_number: roomNumber
    }, '创建预订成功'));
  } catch (error) {
    await connection.rollback();
    logger.error('创建预订失败:', error.message);
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
    logger.error('查询预订失败:', error.message);
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

    if (!['confirmed', 'pre_checked_in'].includes(booking.status)) {
      await connection.rollback();
      res.status(400).json(errorResponse('当前预订状态不允许办理入住，请先完成支付'));
      return;
    }

    const [paymentRows] = await connection.query<RowDataPacket[]>(
      'SELECT id FROM payments WHERE order_type = ? AND order_id = ? AND status = ? LIMIT 1',
      ['booking', id, 'paid']
    );
    if (paymentRows.length === 0) {
      await connection.rollback();
      res.status(400).json(errorResponse('请先完成支付后再办理入住'));
      return;
    }

    // 在线办理入住：状态改为 pre_checked_in（预入住），等待前台核实
    await connection.query<ResultSetHeader>(
      `UPDATE bookings
       SET guest_name = ?, guest_id_number = ?, status = ?, pre_checkin_time = CURRENT_TIMESTAMP
       WHERE id = ?`,
      [real_name, id_number, 'pre_checked_in', id]
    );

    // 插入到 guests 表，状态为预入住
    await connection.query(
      `INSERT INTO guests (booking_id, guest_name, guest_phone, guest_id_number, room_id, status, check_in_time)
       VALUES (?, ?, ?, ?, ?, 'pre_checked_in', CURRENT_TIMESTAMP)
       ON DUPLICATE KEY UPDATE guest_name = VALUES(guest_name), guest_id_number = VALUES(guest_id_number), room_id = VALUES(room_id), status = 'pre_checked_in'`,
      [id, real_name, guest_phone, id_number, booking.room_id]
    );

    // 预入住状态不更新房间状态，等待前台核实后才更新

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
    logger.error('在线办理入住失败:', error.message);
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
    logger.error('确认预订失败:', error.message);
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
    const [bookingRows] = await connection.query<RowDataPacket[]>('SELECT room_id, guest_name, guest_phone, guest_id_number, status FROM bookings WHERE id = ?', [id]);
    if (bookingRows.length === 0) {
      await connection.rollback();
      res.status(404).json(errorResponse('预订不存在'));
      return;
    }
    const booking = bookingRows[0] as any;
    const roomId = booking.room_id;

    // 检查状态：支持 confirmed 和 pre_checked_in 转为 checked_in
    if (!['confirmed', 'pre_checked_in'].includes(booking.status)) {
      await connection.rollback();
      res.status(400).json(errorResponse('当前预订状态不允许办理入住'));
      return;
    }

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
       VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
       ON DUPLICATE KEY UPDATE guest_name = VALUES(guest_name), guest_id_number = VALUES(guest_id_number), room_id = VALUES(room_id)`,
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
    logger.error('办理入住失败:', error.message);
    res.status(500).json(errorResponse('办理入住失败'));
  } finally {
    connection.release();
  }
};

// 拒绝预入住申请
export const rejectPreCheckin = async (req: AuthRequest, res: Response) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const { id } = req.params;

    // 获取订单信息
    const [bookingRows] = await connection.query<RowDataPacket[]>('SELECT status FROM bookings WHERE id = ?', [id]);
    if (bookingRows.length === 0) {
      await connection.rollback();
      res.status(404).json(errorResponse('预订不存在'));
      return;
    }
    const booking = bookingRows[0] as any;

    // 检查状态
    if (booking.status !== 'pre_checked_in') {
      await connection.rollback();
      res.status(400).json(errorResponse('当前预订不是预入住状态'));
      return;
    }

    // 退回为 confirmed 状态
    await connection.query<ResultSetHeader>(
      'UPDATE bookings SET status = ?, pre_checkin_time = NULL WHERE id = ?',
      ['confirmed', id]
    );

    // 更新 guests 表状态
    await connection.query(
      'UPDATE guests SET status = ? WHERE booking_id = ?',
      ['confirmed', id]
    );

    await connection.commit();
    res.json(successResponse(null, '已拒绝预入住申请'));
  } catch (error) {
    await connection.rollback();
    logger.error('拒绝预入住失败:', error.message);
    res.status(500).json(errorResponse('拒绝预入住失败'));
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
    logger.error('办理退房失败:', error.message);
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
      'UPDATE bookings SET status = ?, cancelled_at = CURRENT_TIMESTAMP, lock_version = lock_version + 1 WHERE id = ?',
      ['cancelled', id]
    );

    await connection.query(
      `UPDATE payments SET status = 'expired', expired_at = NOW() 
       WHERE order_type = 'booking' AND order_id = ? AND status = 'pending'`,
      [id]
    );

    if (roomId) {
      await connection.query(
        `UPDATE rooms SET room_status = 'available', locked_by_booking = NULL, locked_at = NULL WHERE id = ?`,
        [roomId]
      );
    }

    await connection.commit();
    res.json(successResponse(null, '取消预订成功'));
  } catch (error) {
    await connection.rollback();
    logger.error('取消预订失败:', error.message);
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
      'UPDATE bookings SET status = ?, lock_version = lock_version + 1 WHERE id = ?',
      [status, id]
    );

    if (status === 'checked_out') {
      await connection.query(
        'UPDATE guests SET check_out_time = CURRENT_TIMESTAMP WHERE booking_id = ? AND check_out_time IS NULL',
        [id]
      );
      await connection.query(
        'UPDATE bookings SET check_out_time = NOW() WHERE id = ? AND check_out_time IS NULL',
        [id]
      );
      if (booking.guest_phone && booking.total_price) {
        await updateMemberExperienceAfterCheckout(connection, booking.guest_phone, booking.total_price);
      }
    }

    if (status === 'checked_in') {
      await connection.query(
        `INSERT INTO guests (booking_id, guest_name, guest_phone, guest_id_number, room_id, check_in_time)
         SELECT id, guest_name, guest_phone, guest_id_number, room_id, CURRENT_TIMESTAMP
         FROM bookings WHERE id = ? AND NOT EXISTS (
           SELECT 1 FROM guests WHERE booking_id = ?
         )`,
        [id, id]
      );
    }

    if (roomId) {
      let roomStatus: string | null = null;
      let clearLock = false;
      if (status === 'checked_in') roomStatus = 'occupied';
      else if (status === 'confirmed') roomStatus = 'reserved';
      else if (status === 'checked_out') { roomStatus = 'cleaning'; clearLock = true; }
      else if (status === 'cancelled') { roomStatus = 'available'; clearLock = true; }

      if (roomStatus) {
        if (clearLock) {
          await connection.query(
            `UPDATE rooms SET room_status = ?, locked_by_booking = NULL, locked_at = NULL WHERE id = ?`,
            [roomStatus, roomId]
          );
        } else {
          await connection.query(
            `UPDATE rooms SET room_status = ?, locked_by_booking = ? WHERE id = ?`,
            [roomStatus, id, roomId]
          );
        }
      }
    }

    await connection.commit();
    res.json(successResponse(null, '更新预订状态成功'));
  } catch (error) {
    await connection.rollback();
    logger.error('更新预订状态失败:', error.message);
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
    logger.error('续住失败:', error.message);
    res.status(500).json(errorResponse('续住失败'));
  } finally {
    connection.release();
  }
};

export const getCalculatedPrice = async (req: AuthRequest, res: Response) => {
  const connection = await pool.getConnection();
  try {
    const { room_id, check_in_date, check_out_date, guest_phone, coupon_id, used_points, rate_plan_id } = req.query;

    if (!room_id || !check_in_date || !check_out_date) {
      return res.status(400).json(errorResponse('缺少必要参数'));
    }

    const candidatePhone = String(guest_phone || '').trim();
    // 灵活识别：只要 candidatePhone 有值，我们就优先用它去查会员，不强制要求 11 位
    const phone = candidatePhone || (req.user?.phone || req.user?.username);
    
    // 强制把 "undefined" 或 "null" 字符串转换回真正的 undefined，防止传错
    const finalPhone = (phone === 'undefined' || phone === 'null' || !phone) ? undefined : phone;

    // 调试：打印 phone 的来源
    logger.info(`价格计算 - 参数 phone: ${phone}, candidatePhone: ${candidatePhone}, user.phone: ${req.user?.phone}, user.username: ${req.user?.username}, finalPhone: ${finalPhone}`);
    
    // 规范化 rate_plan_id，支持 "null" 字符串和数字
    let normalizedPlanId: number | undefined = undefined;
    if (rate_plan_id && rate_plan_id !== 'null' && rate_plan_id !== 'undefined') {
      normalizedPlanId = Number(rate_plan_id);
    }

    logger.info(`收到价格计算请求: room_id=${room_id}, phone=${finalPhone}, plan_id=${normalizedPlanId}, points=${used_points}`);

    const result = await calculateBookingPrice(
      connection,
      Number(room_id),
      check_in_date as string,
      check_out_date as string,
      finalPhone,
      coupon_id ? Number(coupon_id) : undefined,
      used_points ? Number(used_points) : undefined,
      normalizedPlanId
    );

    res.json(successResponse(result, '价格计算成功'));
  } catch (error: any) {
    logger.error('计算价格失败:', error.message);
    res.status(500).json(errorResponse(error.message || '计算价格失败'));
  } finally {
    connection.release();
  }
};
