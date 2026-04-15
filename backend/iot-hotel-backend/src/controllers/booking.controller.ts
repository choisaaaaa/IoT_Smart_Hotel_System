import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import { PoolConnection } from 'mysql2/promise';
import logger from '../utils/logger';
import dayjs from 'dayjs';
import isSameOrBefore from 'dayjs/plugin/isSameOrBefore';
dayjs.extend(isSameOrBefore);
import { v4 as uuidv4 } from 'uuid';
import { isSystemAdmin, isCustomer, isStaff, isHotelAdmin, CANONICAL_ROLES } from '../utils/role';
import { LEVEL_DISCOUNTS, LEVEL_POINTS_MULTIPLIER } from '../config/constants';
import { orderTimeoutService } from '../services/order-timeout.service';
import { systemConfigService } from '../services/system-config.service';

// 辅助函数：退房后更新会员成长值、积分与等级
async function updateMemberExperienceAfterCheckout(connection: PoolConnection, guestPhone: string, totalPrice: number, guestName?: string) {
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

    // 2. 获取会员当前信息，如果不存在则创建
    let [memberRows] = await connection.query<RowDataPacket[]>(
      'SELECT id, experience, points, member_level, total_spent, total_stays FROM members WHERE phone = ?',
      [guestPhone]
    );

    let member: any;
    if (!memberRows || memberRows.length === 0) {
      // 创建新会员记录
      const [insertResult] = await connection.query<ResultSetHeader>(
        'INSERT INTO members (phone, name, member_level, experience, points, balance, total_spent, total_stays) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [guestPhone, guestName || guestPhone, 'standard', 0, 0, 0.00, 0, 0]
      );
      member = {
        id: insertResult.insertId,
        experience: 0,
        points: 0,
        member_level: 'standard',
        total_spent: 0,
        total_stays: 0
      };
      logger.info(`创建新会员记录: 手机号 ${guestPhone}`);
    } else {
      member = memberRows[0];
    }
    
    // 3. 计算奖励
    // 从系统配置获取动态会员方案
    const memberScheme = await systemConfigService.getMemberScheme();

    // 成长值: 10元 = 1点 (固定)
    const expGain = Math.floor(totalPrice / 10);
    const newExp = (member.experience || 0) + expGain;
    
    // 积分: 1元 = pointsRate点 * 会员等级倍率
    let multiplier = 1;
    const levelConfig = memberScheme.find(s => s.key === member.member_level);
    if (levelConfig) {
      multiplier = Number(levelConfig.points_multiplier || 1);
    } else {
      multiplier = LEVEL_POINTS_MULTIPLIER[member.member_level] || 1;
    }

    const pointsGain = Math.floor(totalPrice * pointsRate * multiplier);
    const newPoints = (member.points || 0) + pointsGain;
    
    const newSpent = Number(member.total_spent || 0) + Number(totalPrice);
    const newStays = (member.total_stays || 0) + 1;

    // 4. 自动升级逻辑 (基于成长值)
    let newLevel = member.member_level;
    if (memberScheme.length > 0) {
      // 按门槛从高到低排序，找到符合条件的最高等级
      const sortedScheme = [...memberScheme].sort((a, b) => (b.min_experience || 0) - (a.min_experience || 0));
      const match = sortedScheme.find(s => newExp >= (s.min_experience || 0));
      if (match) {
        newLevel = match.key;
      }
    } else {
      // 降级使用硬编码逻辑
      if (newExp >= 5000) newLevel = 'diamond';
      else if (newExp >= 2000) newLevel = 'platinum';
      else if (newExp >= 500) newLevel = 'gold';
      else if (newExp >= 100) newLevel = 'silver';
      else newLevel = 'standard';
    }

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
  roomId: number | null, 
  checkInDate: string, 
  checkOutDate: string, 
  memberPhone?: string, 
  couponId?: number,
  usedPoints?: number,
  ratePlanId?: number,
  manualDiscount?: number,
  manualReduce?: number,
  roomTypeId?: number // 新增参数
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

  let finalRoomTypeId = roomTypeId;
  let fallbackPrice = 0;
  let hotelId = 0;

  if (roomId) {
    const [roomRows] = await connection.query<RowDataPacket[]>(
      'SELECT r.room_price, r.hotel_id, COALESCE(r.room_type_id, rt.id) as room_type_id FROM rooms r LEFT JOIN room_types rt ON r.room_type = rt.code AND (rt.hotel_id = r.hotel_id OR rt.hotel_id = 0) WHERE r.id = ?',
      [roomId]
    );
    if (roomRows.length > 0) {
      const room = roomRows[0];
      if (!finalRoomTypeId) finalRoomTypeId = room.room_type_id;
      fallbackPrice = Number(room.room_price);
      hotelId = room.hotel_id;
    }
  }

  if (!finalRoomTypeId) {
    throw new Error('未指定房型，无法计算价格');
  }

  // 获取房型基础价格（如果没有房间，则从房型表获取）
  if (fallbackPrice === 0) {
    const [rtRows] = await connection.query<RowDataPacket[]>('SELECT base_price, hotel_id FROM room_types WHERE id = ?', [finalRoomTypeId]);
    if (rtRows.length > 0) {
      fallbackPrice = Number(rtRows[0].base_price);
      hotelId = rtRows[0].hotel_id;
    }
  }

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
      [finalRoomTypeId, dateStr, normalizedPlanId, normalizedPlanId]
    );

    if (priceRows.length > 0) {
      basePrice += Number(priceRows[0].final_price);
    } else if (planBasePrice > 0) {
      basePrice += planBasePrice;
    } else {
      basePrice += fallbackPrice;
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
      memberLevel = String(memberRows[0].member_level || 'standard').toLowerCase().trim();
      availablePoints = memberRows[0].points || 0;
      
      // 使用 SystemConfigService 获取动态折扣
      const levelConfig = await systemConfigService.getLevelConfig(memberLevel);
      if (levelConfig) {
        discountRate = Number(levelConfig.discount || 1.0);
        logger.info(`价格计算 - 动态方案匹配成功: 等级=${memberLevel}, 折扣=${discountRate}`);
      } else {
        // 降级处理：使用静态配置或默认1.0
        discountRate = Number(LEVEL_DISCOUNTS[memberLevel] || 1.0);
      }
      
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
    logger.info(`价格计算 - 应用积分: 使用=${actualUsedPoints},抵扣=${pointsDiscount}`);
  }

  // 应用前台手动打折 (现场打折)
  if (manualDiscount !== undefined && manualDiscount < 1 && manualDiscount > 0) {
    const priceBeforeManual = totalPrice;
    totalPrice = floor2(totalPrice * manualDiscount);
    logger.info(`价格计算 - 应用手动折扣: 折扣=${manualDiscount}, 之前=${priceBeforeManual}, 之后=${totalPrice}`);
  }

  // 应用前台手动立减
  if (manualReduce !== undefined && manualReduce > 0) {
    const priceBeforeManualReduce = totalPrice;
    totalPrice = floor2(Math.max(0, totalPrice - manualReduce));
    logger.info(`价格计算 - 应用手动立减: 立减=${manualReduce}, 之前=${priceBeforeManualReduce}, 之后=${totalPrice}`);
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
      
      // 预入住信息过滤过往日期：只显示今日及以后的
      if (status === 'pre_checked_in') {
        whereClause += ' AND DATE(b.check_out_date) >= CURDATE()';
      }
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
      `SELECT b.*, r.room_number, r.room_type, r.room_name, h.hotel_name, rt.name as room_type_name,
              rt.base_price as room_type_base_price, rp.plan_name, rp.base_price as plan_base_price,
              c.coupon_name as coupon_name
       FROM bookings b
       LEFT JOIN rooms r ON b.room_id = r.id
       LEFT JOIN hotels h ON b.hotel_id = h.id
       LEFT JOIN room_types rt ON b.room_type_id = rt.id
       LEFT JOIN rate_plans rp ON b.rate_plan_id = rp.id
       LEFT JOIN coupons c ON b.coupon_id = c.id
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
      `SELECT b.*, r.room_number, r.room_type, r.room_name, rt.name as room_type_name,
              rt.base_price as room_type_base_price, rp.plan_name, rp.base_price as plan_base_price,
              rp.meal_plan, rp.cancellation_policy, c.coupon_name as coupon_name
       FROM bookings b 
       LEFT JOIN rooms r ON b.room_id = r.id 
       LEFT JOIN room_types rt ON b.room_type_id = rt.id
       LEFT JOIN rate_plans rp ON b.rate_plan_id = rp.id
       LEFT JOIN coupons c ON b.coupon_id = c.id
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
      room_id, room_type_id, rate_plan_id, guest_name, guest_phone, guest_id_number, 
      check_in_date, check_out_date, guest_count, special_requests, 
      payment_method, coupon_id, used_points, status,
      manual_discount, manual_reduce
    } = req.body;

    if (!room_id && !room_type_id) {
      await connection.rollback();
      return res.status(400).json(errorResponse('请选择房间或房型'));
    }

    let hotelId = 0;
    let finalRoomTypeId = room_type_id;
    let roomNumber = null;

    if (room_id) {
      const [roomRows] = await connection.query<RowDataPacket[]>(
        'SELECT hotel_id, room_status, room_number, COALESCE(room_type_id, (SELECT id FROM room_types WHERE code = rooms.room_type LIMIT 1)) as room_type_id FROM rooms WHERE id = ? FOR UPDATE',
        [room_id]
      );

      if (roomRows.length === 0) {
        await connection.rollback();
        res.status(404).json(errorResponse(`房间(ID:${room_id})不存在`));
        return;
      }

      const room = roomRows[0] as any;
      hotelId = room.hotel_id;
      roomNumber = room.room_number;
      if (!finalRoomTypeId) finalRoomTypeId = room.room_type_id;
    } else {
      const [rtRows] = await connection.query<RowDataPacket[]>('SELECT hotel_id FROM room_types WHERE id = ?', [room_type_id]);
      if (rtRows.length === 0) {
        await connection.rollback();
        return res.status(404).json(errorResponse('房型不存在'));
      }
      hotelId = rtRows[0].hotel_id;
    }

    // 检查房型余量 (解耦逻辑)
    const checkIn = dayjs(check_in_date);
    const checkOut = dayjs(check_out_date);
    const nights = checkOut.diff(checkIn, 'day');
    
    for (let i = 0; i < nights; i++) {
      const dateStr = checkIn.add(i, 'day').format('YYYY-MM-DD');
      let currentInventory = 0;
      let currentSold = 0;

      if (rate_plan_id) {
        const [inventoryRows] = await connection.query<RowDataPacket[]>(
          `SELECT p.inventory_count, p.sold_count, rp.default_inventory 
           FROM rate_plans rp
           LEFT JOIN room_prices p ON rp.id = p.rate_plan_id AND p.room_type_id = rp.room_type_id AND p.price_date = ?
           WHERE rp.id = ?`,
          [dateStr, rate_plan_id]
        );
        if (inventoryRows.length > 0) {
          const inv = inventoryRows[0];
          currentInventory = inv.inventory_count !== null ? inv.inventory_count : (inv.default_inventory || 10);
          currentSold = inv.sold_count || 0;
        } else {
          await connection.rollback();
          return res.status(409).json(errorResponse(`日期 ${dateStr} 的房价方案已不存在`));
        }
      } else {
        // 标准价方案
        const [pRows] = await connection.query<RowDataPacket[]>(
          'SELECT inventory_count, sold_count FROM room_prices WHERE room_type_id = ? AND price_date = ? AND rate_plan_id IS NULL',
          [finalRoomTypeId, dateStr]
        );
        currentInventory = pRows.length > 0 ? pRows[0].inventory_count : 10;
        currentSold = pRows.length > 0 ? pRows[0].sold_count : 0;
      }

      if (currentInventory <= currentSold) {
        await connection.rollback();
        return res.status(409).json(errorResponse(`日期 ${dateStr} 的该方案已售罄`));
      }
    }

    const bookingStatus = status || 'pending';

    // 计算最终价格
    const { total_price, discount_rate, used_points: actualUsedPoints, points_discount } = await calculateBookingPrice(
      connection,
      room_id || null,
      check_in_date,
      check_out_date,
      guest_phone,
      coupon_id,
      used_points,
      rate_plan_id,
      manual_discount,
      manual_reduce,
      finalRoomTypeId
    );

    const bookingNumber = `BK${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${uuidv4().slice(0, 8).toUpperCase()}`;
    const checkInTime = bookingStatus === 'checked_in' ? new Date() : null;
    const paymentDeadline = orderTimeoutService.getPaymentDeadline();
    const autoCheckoutAt = orderTimeoutService.calculateAutoCheckoutTime(check_out_date);

    const [result] = await connection.query<ResultSetHeader>(
      `INSERT INTO bookings (
        booking_number, hotel_id, room_id, room_type_id, rate_plan_id, user_id, 
        guest_name, guest_phone, id_type, guest_id_number, check_in_date, check_out_date, 
        guest_count, special_requests, payment_method, coupon_id, used_points, 
        points_discount, total_price, deposit, status, check_in_time,
        locked_at, payment_deadline, auto_checkout_at, room_number
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        bookingNumber, hotelId, room_id || null, finalRoomTypeId, rate_plan_id || null, null, 
        guest_name, guest_phone, req.body.id_type || 'idcard', guest_id_number, check_in_date, check_out_date, 
        guest_count, special_requests, payment_method, coupon_id || null, actualUsedPoints, 
        points_discount, total_price, 0, bookingStatus, checkInTime,
        new Date(), bookingStatus === 'pending' ? paymentDeadline : null, autoCheckoutAt, roomNumber
      ]
    );

    const bookingId = result.insertId;

    // 增加已售数量
    for (let i = 0; i < nights; i++) {
      const dateStr = checkIn.add(i, 'day').format('YYYY-MM-DD');
      if (rate_plan_id) {
        await connection.query(
          `INSERT INTO room_prices (room_type_id, rate_plan_id, hotel_id, price_date, inventory_count, sold_count, base_price, final_price)
           SELECT ?, ?, ?, ?, default_inventory, 1, base_price, base_price
           FROM rate_plans WHERE id = ?
           ON DUPLICATE KEY UPDATE sold_count = sold_count + 1`,
          [finalRoomTypeId, rate_plan_id, hotelId, dateStr, rate_plan_id]
        );
      } else {
        // 标准价方案 (rate_plan_id 为空)
        const [rtRows] = await connection.query<RowDataPacket[]>('SELECT base_price FROM room_types WHERE id = ?', [finalRoomTypeId]);
        const basePrice = rtRows.length > 0 ? rtRows[0].base_price : 0;
        await connection.query(
          `INSERT INTO room_prices (room_type_id, rate_plan_id, hotel_id, price_date, inventory_count, sold_count, base_price, final_price)
           VALUES (?, NULL, ?, ?, 10, 1, ?, ?)
           ON DUPLICATE KEY UPDATE sold_count = sold_count + 1`,
          [finalRoomTypeId, hotelId, dateStr, basePrice, basePrice]
        );
      }
    }

    if (bookingStatus === 'checked_in' && room_id) {
      await connection.query(
        `UPDATE rooms SET room_status = 'occupied', locked_by_booking = ?, locked_at = NOW() WHERE id = ?`,
        [bookingId, room_id]
      );
    }

    await connection.commit();
    res.json(successResponse({ 
      id: bookingId, 
      booking_number: bookingNumber, 
      total_price: total_price
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
              b.room_type_id, b.hotel_id, rt.name as room_type_name,
              r.id as room_id, r.room_number, r.room_name
       FROM bookings b
       LEFT JOIN room_types rt ON b.room_type_id = rt.id
       LEFT JOIN rooms r ON b.room_id = r.id
       WHERE (b.booking_number = ? OR b.guest_phone = ?) 
       AND b.status IN ('confirmed', 'pending', 'pre_checked_in')
       AND DATE(b.check_out_date) >= CURDATE()
       ORDER BY CASE WHEN b.status = 'confirmed' THEN 1 WHEN b.status = 'pre_checked_in' THEN 2 ELSE 3 END ASC, b.id DESC
       LIMIT 1`,
      [normalizedKeyword, normalizedKeyword]
    );

    if (rows.length === 0) {
      res.status(404).json(errorResponse('未找到匹配预订'));
      return;
    }

    const booking = rows[0] as any;
    // 调试日志
    logger.info(`查找预订结果: id=${booking.id}, room_type_id=${booking.room_type_id}, hotel_id=${booking.hotel_id}, room_type_name=${booking.room_type_name}`);

    res.json(successResponse({
      id: booking.id,
      booking_no: booking.booking_number,
      guest_name: booking.guest_name,
      guest_phone: booking.guest_phone,
      room_id: booking.room_id,
      room_type_id: booking.room_type_id,
      room_name: booking.room_type_name || booking.room_name || booking.room_number || '未知房型',
      check_in: booking.check_in_date,
      check_out: booking.check_out_date,
      status: booking.status,
      hotel_id: booking.hotel_id
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
    const { guest_phone, real_name, id_type, id_number, arrival_time, plate_number, room_id } = req.body || {};

    if (!guest_phone || !real_name || !id_number) {
      await connection.rollback();
      res.status(400).json(errorResponse('缺少必要参数（guest_phone, real_name, id_number）'));
      return;
    }

    const [bookingRows] = await connection.query<RowDataPacket[]>(
      `SELECT b.id, b.booking_number, b.guest_phone, b.status, b.room_id, b.check_in_date, b.check_out_date,
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
    
    // 检查日期：如果退房日期已过，不能办理入住
    if (dayjs(booking.check_out_date).isBefore(dayjs(), 'day')) {
      await connection.rollback();
      res.status(400).json(errorResponse('该预订已超过退房日期，无法办理入住'));
      return;
    }

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

    // 如果用户选择了房间，则验证并更新房间ID
    let finalRoomId = room_id || booking.room_id;
    let roomNumber = booking.room_number;

    if (room_id) {
      const [roomRows] = await connection.query<RowDataPacket[]>(
        'SELECT id, room_number, room_name, room_status FROM rooms WHERE id = ? FOR UPDATE',
        [room_id]
      );
      if (roomRows.length === 0) {
        await connection.rollback();
        res.status(404).json(errorResponse('所选房间不存在'));
        return;
      }
      
      // 允许选择自己已经锁定的房间，或者是空闲房间
      const isRoomAvailable = roomRows[0].room_status === 'available' || roomRows[0].room_status === 'cleaning';
      const isSameAsOldRoom = booking.room_id && Number(booking.room_id) === Number(room_id);

      if (!isRoomAvailable && !isSameAsOldRoom) {
        await connection.rollback();
        res.status(400).json(errorResponse('所选房间已被占用，请选择其他房间'));
        return;
      }
      
      // 如果换了新房间，释放旧房间
      if (booking.room_id && Number(booking.room_id) !== Number(room_id)) {
        await connection.query(
          "UPDATE rooms SET room_status = 'available', locked_by_booking = NULL, locked_at = NULL WHERE id = ?",
          [booking.room_id]
        );
      }

      finalRoomId = room_id;
      roomNumber = roomRows[0].room_number;
    }

    // 在线办理入住：状态改为 pre_checked_in（预入住），等待前台核实
    await connection.query<ResultSetHeader>(
      `UPDATE bookings
       SET guest_name = ?, id_type = ?, guest_id_number = ?, room_id = ?, room_number = ?, status = ?, pre_checkin_time = CURRENT_TIMESTAMP
       WHERE id = ?`,
      [real_name, id_type || 'idcard', id_number, finalRoomId, roomNumber, 'pre_checked_in', id]
    );

    // 修改房间状态为 reserved
    if (finalRoomId) {
      await connection.query(
        `UPDATE rooms SET room_status = 'reserved', locked_by_booking = ?, locked_at = NOW() WHERE id = ?`,
        [id, finalRoomId]
      );
    }

    // 插入到 guests 表，状态为预入住
    await connection.query(
      `INSERT INTO guests (booking_id, guest_name, guest_phone, id_type, guest_id_number, room_id, status, check_in_time)
       VALUES (?, ?, ?, ?, ?, ?, 'pre_checked_in', CURRENT_TIMESTAMP)
       ON DUPLICATE KEY UPDATE guest_name = VALUES(guest_name), id_type = VALUES(id_type), guest_id_number = VALUES(guest_id_number), room_id = VALUES(room_id), status = 'pre_checked_in'`,
      [id, real_name, guest_phone, id_type || 'idcard', id_number, finalRoomId]
    );

    await connection.commit();
    const roomPin = uuidv4().replace(/-/g, '').slice(0, 6).toUpperCase();
    res.json(successResponse({
      booking_id: booking.id,
      booking_no: booking.booking_number,
      room_id: finalRoomId,
      room_name: roomNumber || booking.room_name || booking.room_number,
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
    const { 
      user_id, guest_name, guest_phone, guest_id_number, special_requests,
      manual_discount, manual_reduce, total_price 
    } = req.body || {};

    // 获取订单信息
    const [bookingRows] = await connection.query<RowDataPacket[]>('SELECT room_id, guest_name, guest_phone, guest_id_number, status, auto_checkout_at, check_out_date, total_price FROM bookings WHERE id = ?', [id]);
    if (bookingRows.length === 0) {
      await connection.rollback();
      res.status(404).json(errorResponse('预订不存在'));
      return;
    }
    const booking = bookingRows[0] as any;
    const roomId = booking.room_id;

    // 关键修复：实现同一证件号跨店入住限制
    const finalIdNumber = guest_id_number || booking.guest_id_number;
    if (finalIdNumber) {
      const today = dayjs().format('YYYY-MM-DD');
      const [duplicateIdRows] = await connection.query<RowDataPacket[]>(
        `SELECT b.id, b.booking_number, h.hotel_name, r.room_number 
         FROM bookings b
         LEFT JOIN hotels h ON b.hotel_id = h.id
         LEFT JOIN rooms r ON b.room_id = r.id
         WHERE b.guest_id_number = ? 
         AND b.id != ?
         AND b.status = 'checked_in'
         LIMIT 1`,
        [finalIdNumber, id]
      );

      if (duplicateIdRows.length > 0) {
        const dup = duplicateIdRows[0] as any;
        await connection.rollback();
        return res.status(409).json(errorResponse(
          `证件号 ${finalIdNumber} 当前已在其他房间入住（酒店: ${dup.hotel_name}, 房号: ${dup.room_number}）。请先退房后再办理新入住。`
        ));
      }
    }

    // 自动关联用户账号：如果未提供user_id，尝试通过手机号查找
    let resolvedUserId = user_id;
    if (!resolvedUserId) {
      const phoneToLookup = guest_phone || booking.guest_phone;
      if (phoneToLookup) {
        const [userRows] = await connection.query<RowDataPacket[]>(
          'SELECT id FROM users WHERE phone = ? LIMIT 1',
          [phoneToLookup]
        );
        if (userRows.length > 0) {
          resolvedUserId = userRows[0].id;
        }
      }
    }

    if (!['pending', 'confirmed', 'pre_checked_in'].includes(booking.status)) {
      await connection.rollback();
      res.status(400).json(errorResponse('当前预订状态不允许办理入住'));
      return;
    }

    // 构建更新字段
    const updateFields: string[] = ['status = ?', 'check_in_time = CURRENT_TIMESTAMP'];
    const params: any[] = ['checked_in', id];

    // 如果能关联用户账号，则更新user_id
    if (resolvedUserId) {
      updateFields.push('user_id = ?');
      params.splice(params.length - 1, 0, resolvedUserId);
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
    if (req.body.id_type) {
      updateFields.push('id_type = ?');
      params.splice(params.length - 1, 0, req.body.id_type);
    }
    if (special_requests !== undefined) {
      updateFields.push('special_requests = ?');
      params.splice(params.length - 1, 0, special_requests);
    }

    if (manual_discount !== undefined) {
      updateFields.push('manual_discount = ?');
      params.splice(params.length - 1, 0, manual_discount);
    }
    if (manual_reduce !== undefined) {
      updateFields.push('manual_reduce = ?');
      params.splice(params.length - 1, 0, manual_reduce);
    }
    if (total_price !== undefined) {
      updateFields.push('total_price = ?');
      params.splice(params.length - 1, 0, total_price);
    }

    if (!booking.auto_checkout_at) {
      const autoCheckoutAt = orderTimeoutService.calculateAutoCheckoutTime(booking.check_out_date);
      updateFields.push('auto_checkout_at = ?');
      params.splice(params.length - 1, 0, autoCheckoutAt);
    }

    await connection.query<ResultSetHeader>(
      `UPDATE bookings SET ${updateFields.join(', ')} WHERE id = ?`,
      params
    );

    // 插入到 guests 表（先删后插，避免重复记录）
    await connection.query('DELETE FROM guests WHERE booking_id = ?', [id]);
    await connection.query(
      `INSERT INTO guests (booking_id, guest_name, guest_phone, id_type, guest_id_number, room_id, check_in_time)
       VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)`,
      [
        id, 
        guest_name || booking.guest_name, 
        guest_phone || booking.guest_phone, 
        booking.id_type || 'idcard',
        guest_id_number || booking.guest_id_number, 
        roomId
      ]
    );

    // 同步更新房间状态为“在住”
    if (roomId) {
      await connection.query('UPDATE rooms SET room_status = ?, locked_by_booking = ?, locked_at = NOW() WHERE id = ?', ['occupied', id, roomId]);
    }

    if (booking.status === 'pending') {
      await connection.query(
        `UPDATE payments SET status = 'paid', paid_at = CURRENT_TIMESTAMP 
         WHERE order_type = 'booking' AND order_id = ? AND status = 'pending'`,
        [id]
      );
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
    const [bookingRows] = await connection.query<RowDataPacket[]>('SELECT room_id, guest_phone, total_price, coupon_id, used_points, status FROM bookings WHERE id = ?', [id]);
    if (bookingRows.length === 0) {
      await connection.rollback();
      res.status(404).json(errorResponse('预订不存在'));
      return;
    }
    const booking = bookingRows[0] as any;
    const roomId = booking.room_id;

    if (!['checked_in'].includes(booking.status)) {
      await connection.rollback();
      res.status(400).json(errorResponse('当前预订状态不允许办理退房，仅已入住状态可退房'));
      return;
    }

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
      await connection.query(
        `UPDATE rooms SET room_status = ?, locked_by_booking = NULL, locked_at = NULL WHERE id = ?`,
        ['cleaning', roomId]
      );
    }

    // 更新会员成长值
    if (booking.guest_phone && booking.total_price) {
      await updateMemberExperienceAfterCheckout(connection, booking.guest_phone, booking.total_price, booking.guest_name);
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

    const [bookingRows] = await connection.query<RowDataPacket[]>(
      'SELECT room_id, room_type_id, rate_plan_id, check_in_date, check_out_date, guest_phone, coupon_id, used_points, points_discount, status FROM bookings WHERE id = ?',
      [id]
    );
    if (bookingRows.length === 0) {
      await connection.rollback();
      res.status(404).json(errorResponse('预订不存在'));
      return;
    }
    const booking = bookingRows[0] as any;
    const roomId = booking.room_id;

    if (['checked_out', 'cancelled'].includes(booking.status)) {
      await connection.rollback();
      res.status(400).json(errorResponse(`当前预订状态为${booking.status === 'checked_out' ? '已退房' : '已取消'}，无法取消`));
      return;
    }

    await connection.query<ResultSetHeader>(
      'UPDATE bookings SET status = ?, cancelled_at = CURRENT_TIMESTAMP, lock_version = lock_version + 1 WHERE id = ?',
      ['cancelled', id]
    );

    // 1. 恢复库存 (针对房型级库存)
    if (booking.room_type_id && booking.check_in_date && booking.check_out_date) {
      const checkIn = dayjs(booking.check_in_date);
      const checkOut = dayjs(booking.check_out_date);
      const nights = checkOut.diff(checkIn, 'day');
      
      for (let i = 0; i < nights; i++) {
        const dateStr = checkIn.add(i, 'day').format('YYYY-MM-DD');
        await connection.query(
          'UPDATE room_prices SET sold_count = GREATEST(0, sold_count - 1) WHERE room_type_id = ? AND price_date = ? AND (rate_plan_id = ? OR (rate_plan_id IS NULL AND ? IS NULL))',
          [booking.room_type_id, dateStr, booking.rate_plan_id || null, booking.rate_plan_id || null]
        );
      }
      logger.info(`取消订单恢复库存: booking_id=${id}, room_type_id=${booking.room_type_id}, nights=${nights}`);
    }

    // 2. 处理退款逻辑
    // 先获取所有已支付的记录
    const [paidPayments] = await connection.query<RowDataPacket[]>(
      `SELECT id, amount, payment_method, status FROM payments 
       WHERE order_type IN ('booking', 'booking_extend') AND order_id = ? AND status = 'paid'`,
      [id]
    );

    for (const pay of paidPayments) {
      const refundAmount = Number(pay.amount);
      if (refundAmount <= 0) continue;

      if (pay.payment_method === 'balance') {
        // 余额支付：回退到会员余额
        await connection.query(
          'UPDATE members SET balance = balance + ? WHERE phone = ?',
          [refundAmount, booking.guest_phone]
        );
        logger.info(`取消订单回退余额: booking_id=${id}, amount=${refundAmount}, phone=${booking.guest_phone}`);
      } else {
        // 其他支付方式（微信/支付宝/到店）：目前系统内模拟原路退回，标记为已退款
        logger.info(`取消订单标记模拟退款 (${pay.payment_method}): booking_id=${id}, amount=${refundAmount}`);
      }

      // 统一标记支付记录为已退款
      await connection.query(
        'UPDATE payments SET status = ?, updated_at = NOW() WHERE id = ?',
        ['refunded', pay.id]
      );
    }

    // 3. 处理待支付记录 (将 pending 设为 expired)
    await connection.query(
      `UPDATE payments SET status = 'expired', expired_at = NOW() 
       WHERE order_type IN ('booking', 'booking_extend') AND order_id = ? AND status = 'pending'`,
      [id]
    );

    // 4. 回退积分和优惠券
    const isPaid = booking.status === 'confirmed' || booking.status === 'checked_in' || booking.status === 'pre_checked_in';
    
    if (isPaid) {
      // 回退已使用的优惠券
      if (booking.coupon_id) {
        const [memberRows] = await connection.query<RowDataPacket[]>(
          'SELECT id FROM members WHERE phone = ?', [booking.guest_phone]
        );
        if (memberRows.length > 0) {
          await connection.query(
            `UPDATE member_coupons SET status = 'unused', used_at = NULL WHERE id = ? AND member_id = ? AND status = 'used'`,
            [booking.coupon_id, memberRows[0].id]
          );
          logger.info(`取消订单回退优惠券: booking_id=${id}, coupon_id=${booking.coupon_id}`);
        }
      }

      // 回退已扣除的积分
      if (booking.used_points && booking.used_points > 0) {
        await connection.query(
          'UPDATE members SET points = points + ? WHERE phone = ?',
          [booking.used_points, booking.guest_phone]
        );
        logger.info(`取消订单回退积分: booking_id=${id}, points=${booking.used_points}`);
      }
    }

    if (roomId) {
      await connection.query(
        `UPDATE rooms SET room_status = 'available', locked_by_booking = NULL, locked_at = NULL WHERE id = ?`,
        [roomId]
      );
    }

    await connection.query(
      `UPDATE guests SET check_out_time = NOW() WHERE booking_id = ? AND check_out_time IS NULL`,
      [id]
    );

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

    const [bookingRows] = await connection.query<RowDataPacket[]>('SELECT room_id, room_type_id, rate_plan_id, check_in_date, check_out_date, guest_phone, total_price, status AS current_status, coupon_id, used_points FROM bookings WHERE id = ?', [id]);
    if (bookingRows.length === 0) {
      await connection.rollback();
      res.status(404).json(errorResponse('预订不存在'));
      return;
    }
    const booking = bookingRows[0] as any;
    const roomId = booking.room_id;
    const currentStatus = booking.current_status;

    const validTransitions: Record<string, string[]> = {
      pending: ['confirmed', 'pre_checked_in', 'checked_in', 'cancelled'],
      confirmed: ['pre_checked_in', 'checked_in', 'cancelled'],
      pre_checked_in: ['checked_in', 'cancelled'],
      checked_in: ['checked_out'],
      checked_out: [],
      cancelled: []
    };
    const allowed = validTransitions[currentStatus] || [];
    if (!allowed.includes(status)) {
      await connection.rollback();
      return res.status(400).json(errorResponse(`不允许从"${currentStatus}"状态转换到"${status}"状态`));
    }

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
        await updateMemberExperienceAfterCheckout(connection, booking.guest_phone, booking.total_price, booking.guest_name);
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

    if (status === 'cancelled') {
      // 1. 恢复库存 (针对房型级库存)
      if (booking.room_type_id && booking.check_in_date && booking.check_out_date) {
        const checkIn = dayjs(booking.check_in_date);
        const checkOut = dayjs(booking.check_out_date);
        const nights = checkOut.diff(checkIn, 'day');
        
        for (let i = 0; i < nights; i++) {
          const dateStr = checkIn.add(i, 'day').format('YYYY-MM-DD');
          await connection.query(
            'UPDATE room_prices SET sold_count = GREATEST(0, sold_count - 1) WHERE room_type_id = ? AND price_date = ? AND (rate_plan_id = ? OR (rate_plan_id IS NULL AND ? IS NULL))',
            [booking.room_type_id, dateStr, booking.rate_plan_id || null, booking.rate_plan_id || null]
          );
        }
        logger.info(`状态更新取消订单恢复库存: booking_id=${id}, room_type_id=${booking.room_type_id}, nights=${nights}`);
      }

      // 2. 处理退款逻辑 (余额、积分、优惠券)
      // 先获取所有已支付的记录
      const [paidPayments] = await connection.query<RowDataPacket[]>(
        `SELECT id, amount, payment_method, status FROM payments 
         WHERE order_type IN ('booking', 'booking_extend') AND order_id = ? AND status = 'paid'`,
        [id]
      );

      for (const pay of paidPayments) {
        const refundAmount = Number(pay.amount);
        if (refundAmount <= 0) continue;

        if (pay.payment_method === 'balance' && booking.guest_phone) {
          // 余额支付：回退到会员余额
          await connection.query(
            'UPDATE members SET balance = balance + ? WHERE phone = ?',
            [refundAmount, booking.guest_phone]
          );
          logger.info(`状态更新取消订单回退余额: booking_id=${id}, amount=${refundAmount}, phone=${booking.guest_phone}`);
        }

        // 统一标记支付记录为已退款
        await connection.query(
          'UPDATE payments SET status = ?, updated_at = NOW() WHERE id = ?',
          ['refunded', pay.id]
        );
      }

      // 3. 处理待支付记录 (将 pending 设为 expired)
      await connection.query(
        `UPDATE payments SET status = 'expired', expired_at = NOW() 
         WHERE order_type IN ('booking', 'booking_extend') AND order_id = ? AND status = 'pending'`,
        [id]
      );

      // 4. 回退积分和优惠券 (如果订单已支付或预入住)
      const isPaid = currentStatus === 'confirmed' || currentStatus === 'checked_in' || currentStatus === 'pre_checked_in';
      
      if (isPaid && booking.guest_phone) {
        // 回退优惠券
        if (booking.coupon_id) {
          const [memberRows] = await connection.query<RowDataPacket[]>(
            'SELECT id FROM members WHERE phone = ?', [booking.guest_phone]
          );
          if (memberRows.length > 0) {
            await connection.query(
              `UPDATE member_coupons SET status = 'unused', used_at = NULL WHERE id = ? AND member_id = ? AND status = 'used'`,
              [booking.coupon_id, memberRows[0].id]
            );
          }
        }

        // 回退积分
        if (booking.used_points && booking.used_points > 0) {
          await connection.query(
            'UPDATE members SET points = points + ? WHERE phone = ?',
            [booking.used_points, booking.guest_phone]
          );
        }
      }

      // 5. 更新住客表状态
      await connection.query(
        `UPDATE guests SET check_out_time = NOW() WHERE booking_id = ? AND check_out_time IS NULL`,
        [id]
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

export const calculateExtendPrice = async (req: AuthRequest, res: Response) => {
  const connection = await pool.getConnection();
  try {
    const { id } = req.params;
    const { new_check_out_date, coupon_id, used_points } = req.body;

    if (!new_check_out_date) {
      return res.status(400).json(errorResponse('请提供新的退房日期'));
    }

    const [bookingRows] = await connection.query<RowDataPacket[]>(
      'SELECT room_id, check_in_date, check_out_date, guest_phone, status FROM bookings WHERE id = ?',
      [id]
    );

    if (bookingRows.length === 0) {
      return res.status(404).json(errorResponse('预订不存在'));
    }

    const booking = bookingRows[0] as any;

    if (!['checked_in', 'confirmed'].includes(booking.status)) {
      return res.status(400).json(errorResponse('当前预订状态不允许续住'));
    }

    const currentCheckOut = dayjs(booking.check_out_date);
    const newCheckOut = dayjs(new_check_out_date);

    if (!newCheckOut.isValid() || newCheckOut.isSameOrBefore(currentCheckOut)) {
      return res.status(400).json(errorResponse('新退房日期必须晚于当前退房日期'));
    }

    const priceResult = await calculateBookingPrice(
      connection,
      booking.room_id,
      currentCheckOut.format('YYYY-MM-DD'),
      newCheckOut.format('YYYY-MM-DD'),
      booking.guest_phone,
      coupon_id,
      used_points
    );

    res.json(successResponse({
      booking_id: id,
      current_check_out_date: currentCheckOut.format('YYYY-MM-DD'),
      new_check_out_date: newCheckOut.format('YYYY-MM-DD'),
      extend_nights: newCheckOut.diff(currentCheckOut, 'day'),
      base_price: priceResult.base_price,
      discount_rate: priceResult.discount_rate,
      member_discount: priceResult.member_discount,
      coupon_discount: priceResult.coupon_discount,
      points_discount: priceResult.points_discount,
      used_points: priceResult.used_points,
      total_price: priceResult.total_price,
    }, '计算续住价格成功'));
  } catch (error) {
    logger.error('计算续住价格失败:', error.message);
    res.status(500).json(errorResponse('计算续住价格失败'));
  } finally {
    connection.release();
  }
};

export const extendStay = async (req: AuthRequest, res: Response) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const { id } = req.params;
    const { new_check_out_date, coupon_id, used_points, payment_method } = req.body;

    if (!new_check_out_date) {
      await connection.rollback();
      return res.status(400).json(errorResponse('请提供新的退房日期'));
    }

    const [bookingRows] = await connection.query<RowDataPacket[]>(
      'SELECT * FROM bookings WHERE id = ?',
      [id]
    );

    if (bookingRows.length === 0) {
      await connection.rollback();
      return res.status(404).json(errorResponse('预订不存在'));
    }

    const booking = bookingRows[0] as any;

    if (!['checked_in', 'confirmed'].includes(booking.status)) {
      await connection.rollback();
      return res.status(400).json(errorResponse('当前预订状态不允许续住'));
    }

    const currentCheckOut = dayjs(booking.check_out_date);
    const newCheckOut = dayjs(new_check_out_date);

    if (!newCheckOut.isValid() || newCheckOut.isSameOrBefore(currentCheckOut)) {
      await connection.rollback();
      return res.status(400).json(errorResponse('新退房日期必须晚于当前退房日期'));
    }

    const extendNights = newCheckOut.diff(currentCheckOut, 'day');

    const [conflictRows] = await connection.query<RowDataPacket[]>(
      `SELECT id FROM bookings 
       WHERE room_id = ? AND status IN ('confirmed', 'checked_in', 'pending')
       AND id != ? 
       AND check_in_date < ? AND check_out_date > ?`,
      [booking.room_id, id, newCheckOut.format('YYYY-MM-DD'), currentCheckOut.format('YYYY-MM-DD')]
    );

    if (conflictRows.length > 0) {
      await connection.rollback();
      return res.status(409).json(errorResponse('续住日期与已有预订冲突，请选择其他日期'));
    }

    const priceResult = await calculateBookingPrice(
      connection,
      booking.room_id,
      currentCheckOut.format('YYYY-MM-DD'),
      newCheckOut.format('YYYY-MM-DD'),
      booking.guest_phone,
      coupon_id,
      used_points
    );

    const additionalPrice = priceResult.total_price;

    let couponUsed = false;
    if (coupon_id && priceResult.coupon_discount > 0) {
      const [memberRows] = await connection.query<RowDataPacket[]>(
        'SELECT id FROM members WHERE phone = ?', [booking.guest_phone]
      );
      if (memberRows.length > 0) {
        await connection.query(
          `UPDATE member_coupons SET status = 'used', used_at = NOW() WHERE id = ? AND member_id = ? AND status = 'unused'`,
          [coupon_id, memberRows[0].id]
        );
        couponUsed = true;
      }
    }

    let pointsDeducted = 0;
    if (priceResult.used_points > 0 && priceResult.points_discount > 0) {
      const [memberRows] = await connection.query<RowDataPacket[]>(
        'SELECT id, points FROM members WHERE phone = ?', [booking.guest_phone]
      );
      if (memberRows.length > 0) {
        pointsDeducted = Math.min(priceResult.used_points, memberRows[0].points || 0);
        await connection.query(
          'UPDATE members SET points = points - ? WHERE id = ? AND points >= ?',
          [pointsDeducted, memberRows[0].id, pointsDeducted]
        );
      }
    }

    const newTotalPrice = Math.floor((Number(booking.total_price || 0) + additionalPrice) * 100) / 100;
    const newAutoCheckoutAt = orderTimeoutService.calculateAutoCheckoutTime(new_check_out_date);

    await connection.query<ResultSetHeader>(
      'UPDATE bookings SET check_out_date = ?, total_price = ?, auto_checkout_at = ? WHERE id = ?',
      [new_check_out_date, newTotalPrice, newAutoCheckoutAt, id]
    );

    let paymentId = null;
    if (additionalPrice > 0) {
      const method = payment_method || 'balance';
      const [payResult] = await connection.query<ResultSetHeader>(
        `INSERT INTO payments (hotel_id, payment_no, order_type, order_id, amount, payment_method, status, created_at)
         VALUES (?, ?, 'booking_extend', ?, ?, ?, 'pending', NOW())`,
        [booking.hotel_id, `PAY${Date.now()}${Math.random().toString(36).slice(2, 6).toUpperCase()}`, id, additionalPrice, method]
      );
      paymentId = payResult.insertId;
    }

    await connection.commit();
    res.json(successResponse({
      booking_id: id,
      new_check_out_date,
      extend_nights: extendNights,
      base_price: priceResult.base_price,
      discount_rate: priceResult.discount_rate,
      member_discount: priceResult.member_discount,
      coupon_discount: priceResult.coupon_discount,
      points_discount: priceResult.points_discount,
      used_points: pointsDeducted,
      additional_price: additionalPrice,
      new_total_price: newTotalPrice,
      need_payment: additionalPrice > 0,
      payment_id: paymentId,
      coupon_used: couponUsed,
    }, '续住成功'));
  } catch (error) {
    await connection.rollback();
    logger.error('续住失败:', error.message || error);
    logger.error('续住失败堆栈:', error.stack || 'no stack');
    res.status(500).json(errorResponse('续住失败: ' + (error.message || '未知错误')));
  } finally {
    connection.release();
  }
};

export const getCalculatedPrice = async (req: AuthRequest, res: Response) => {
  const connection = await pool.getConnection();
  try {
    const { 
      room_id, room_type_id, check_in_date, check_out_date, guest_phone, coupon_id, 
      used_points, rate_plan_id, manual_discount, manual_reduce 
    } = req.query;

    if ((!room_id && !room_type_id) || !check_in_date || !check_out_date) {
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

    logger.info(`收到价格计算请求: room_id=${room_id}, room_type_id=${room_type_id}, phone=${finalPhone}, plan_id=${normalizedPlanId}, points=${used_points}`);

    const result = await calculateBookingPrice(
      connection,
      room_id ? Number(room_id) : null,
      check_in_date as string,
      check_out_date as string,
      finalPhone,
      coupon_id ? Number(coupon_id) : undefined,
      used_points ? Number(used_points) : undefined,
      normalizedPlanId,
      manual_discount ? Number(manual_discount) : undefined,
      manual_reduce ? Number(manual_reduce) : undefined,
      room_type_id ? Number(room_type_id) : undefined
    );

    res.json(successResponse(result, '价格计算成功'));
  } catch (error: any) {
    logger.error('计算价格失败:', error.message);
    res.status(500).json(errorResponse(error.message || '计算价格失败'));
  } finally {
    connection.release();
  }
};
