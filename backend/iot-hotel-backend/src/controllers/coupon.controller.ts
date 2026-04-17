import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { isSystemAdmin, isHotelAdmin, isStaff, normalizeRole } from '../utils/role';

export const get = async (req: AuthRequest, res: Response) => {
  try {
    const { page = 1, pageSize = 10, status, hotel_id, scope_type } = req.query;
    const offset = (Number(page) - 1) * Number(pageSize);
    const user = req.user as any;
    const userRole = user.role;

    let whereClause = 'WHERE 1=1';
    const params: any[] = [];

    if (status) {
      whereClause += ' AND status = ?';
      params.push(status);
    }

    if (scope_type) {
      whereClause += ' AND c.scope_type = ?';
      params.push(scope_type);
    }

    // 权限过滤
    const targetHotelId = hotel_id || user.hotel_id || 0;
    if (isSystemAdmin(userRole)) {
      // 系统管理员可以查看所有优惠券
      if (hotel_id) {
        whereClause += ' AND (c.hotel_id = ? OR FIND_IN_SET(?, c.hotel_ids))';
        params.push(hotel_id, hotel_id);
      }
    } else if (isHotelAdmin(userRole)) {
      // 酒店管理员只能查看全局优惠券和本店优惠券
      whereClause += ' AND (c.scope_type = "global" OR c.hotel_id = ? OR FIND_IN_SET(?, c.hotel_ids))';
      params.push(user.hotel_id || 0, user.hotel_id || 0);
    } else if (isStaff(userRole)) {
      // 前台员工只能查看本店可用的优惠券（用于发放）
      whereClause += ' AND (c.scope_type = "global" OR ((c.hotel_id = ? OR FIND_IN_SET(?, c.hotel_ids)) AND c.is_public = 1))';
      params.push(user.hotel_id || 0, user.hotel_id || 0);
    } else {
      // 顾客只能查看公开的优惠券
      whereClause += ' AND c.is_public = 1 AND (c.scope_type = "global" OR c.hotel_id = ? OR FIND_IN_SET(?, c.hotel_ids))';
      params.push(targetHotelId, targetHotelId);
    }

    const [totalRows] = await pool.query<RowDataPacket[]>(`SELECT COUNT(*) as total FROM coupons c ${whereClause}`, params);
    const total = (totalRows[0] as any).total;

    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT c.*, h.hotel_name FROM coupons c LEFT JOIN hotels h ON c.hotel_id = h.id ${whereClause} ORDER BY c.id DESC LIMIT ? OFFSET ?`,
      [...params, Number(pageSize), offset]
    );

    res.json(successResponse({
      list: rows,
      total,
      page: Number(page),
      pageSize: Number(pageSize),
      totalPages: Math.ceil(total / Number(pageSize))
    }, '获取优惠券列表成功'));
  } catch (error) {
    logger.error('获取优惠券列表失败:', error.message);
    res.status(500).json(errorResponse('获取优惠券列表失败'));
  }
};

export const redeemByCode = async (req: AuthRequest, res: Response) => {
  try {
    const { code } = req.body;
    if (!req.user) {return res.status(401).json(errorResponse('未认证'));}
    if (!code) {return res.status(400).json(errorResponse('请输入券码'));}

    const user = req.user as any;

    const [couponRows] = await pool.query<RowDataPacket[]>(
      'SELECT * FROM coupons WHERE LOWER(coupon_code) = LOWER(?)',
      [code.trim()]
    );
    if (couponRows.length === 0) {
      return res.status(404).json(errorResponse('优惠券码不存在'));
    }
    const coupon = couponRows[0] as any;

    if (coupon.valid_to && new Date(coupon.valid_to) < new Date()) {
      return res.status(400).json(errorResponse('该优惠券已过期'));
    }

    if (isStaff(user.role) && coupon.hotel_id !== user.hotel_id && coupon.hotel_id !== 0 && (!coupon.hotel_ids || !coupon.hotel_ids.split(',').includes(String(user.hotel_id)))) {
      return res.status(403).json(errorResponse('您只能核销本酒店的优惠券'));
    }

    const [mcRows] = await pool.query<RowDataPacket[]>(
      `SELECT mc.* FROM member_coupons mc WHERE mc.coupon_id = ? AND mc.status = 'unused' LIMIT 1`,
      [coupon.id]
    );
    if (mcRows.length === 0) {
      return res.status(404).json(errorResponse('没有可核销的优惠券记录'));
    }

    const mcId = (mcRows[0] as any).id;
    await pool.query('UPDATE member_coupons SET status = "used", used_at = NOW() WHERE id = ?', [mcId]);

    res.json(successResponse(null, '核销成功'));
  } catch (error) {
    logger.error('按码核销优惠券失败:', error.message);
    res.status(500).json(errorResponse('核销失败'));
  }
};
export const getHotels = async (req: AuthRequest, res: Response) => {
  try {
    const user = req.user as any;
    
    let whereClause = 'WHERE 1=1';
    const params: any[] = [];
    
    if (!isSystemAdmin(user.role) && user.hotel_id) {
      whereClause += ' AND id = ?';
      params.push(user.hotel_id);
    }
    
    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT id, hotel_name, hotel_address FROM hotels ${whereClause} ORDER BY id`,
      params
    );
    
    res.json(successResponse(rows, '获取酒店列表成功'));
  } catch (error) {
    logger.error('获取酒店列表失败:', error.message);
    res.status(500).json(errorResponse('获取酒店列表失败'));
  }
};

export const getById = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    const [rows] = await pool.query<RowDataPacket[]>('SELECT * FROM coupons WHERE id = ?', [id]);

    if (rows.length === 0) {
      res.status(404).json(errorResponse('优惠券不存在'));
      return;
    }

    res.json(successResponse(rows[0], '获取优惠券详情成功'));
  } catch (error) {
    logger.error('获取优惠券详情失败:', error.message);
    res.status(500).json(errorResponse('获取优惠券详情失败'));
  }
};

export const getMe = async (req: AuthRequest, res: Response) => {
  try {
    if (!req.user) {return res.status(401).json(errorResponse('未认证'));}

    let phone = req.query.phone as string;
    if (!phone) {
      const user = req.user as any;
      phone = user.phone || (user.username && user.username.match(/^\d{11}$/) ? user.username : null);
    }

    if (!phone) {
      return res.json(successResponse([], '获取优惠券成功'));
    }

    const [members] = await pool.query<RowDataPacket[]>('SELECT id FROM members WHERE phone = ?', [phone]);

    if (members.length === 0) {
      return res.json(successResponse([], '获取优惠券成功'));
    }

    const memberId = members[0].id;
    const { hotel_id } = req.query;
    let query = `
       SELECT mc.id as id, c.id as coupon_id, c.coupon_name, c.coupon_code, c.coupon_type, 
              c.discount_value, c.min_amount, c.valid_from, c.valid_to, c.hotel_id, c.hotel_ids,
              mc.status as my_status, mc.created_at as received_at
       FROM member_coupons mc
       JOIN coupons c ON mc.coupon_id = c.id
       WHERE mc.member_id = ? AND mc.status = 'unused' AND (c.valid_to >= CURDATE() OR c.valid_to IS NULL)
    `;
    const params: any[] = [memberId];

    if (hotel_id) {
      query += ' AND (c.scope_type = "global" OR c.hotel_id = ? OR FIND_IN_SET(?, c.hotel_ids))';
      params.push(hotel_id, hotel_id);
    }

    const [rows] = await pool.query<RowDataPacket[]>(query, params);

    res.json(successResponse(rows, '获取优惠券成功'));
  } catch (error) {
    logger.error('获取会员优惠券失败:', error.message);
    res.status(500).json(errorResponse('获取优惠券失败'));
  }
};

export const receive = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    if (!req.user) {return res.status(401).json(errorResponse('未认证'));}

    const user = req.user as any;
    const userRole = user.role;
    const phone = user.phone || (user.username && user.username.match(/^\d{11}$/) ? user.username : null);
    if (!phone) {return res.status(400).json(errorResponse('您的账户信息中没有手机号，无法领取优惠券'));}

    const [members] = await pool.query<RowDataPacket[]>('SELECT id FROM members WHERE phone = ?', [phone]);
    if (members.length === 0) {return res.status(404).json(errorResponse('未找到会员记录'));}
    const memberId = members[0].id;

    const [couponRows] = await pool.query<RowDataPacket[]>('SELECT * FROM coupons WHERE id = ? AND valid_to >= CURDATE()', [id]);
    if (couponRows.length === 0) {return res.status(404).json(errorResponse('优惠券不存在或已过期'));}
    const coupon = couponRows[0] as any;

    // 权限检查：私密优惠券只有管理员可以发放，顾客不能领取
    if (coupon.scope_type === 'private' && !isSystemAdmin(userRole) && !isHotelAdmin(userRole) && !isStaff(userRole)) {
      return res.status(403).json(errorResponse('该优惠券为私密发放，无法直接领取'));
    }

    // 酒店专属优惠券检查
    if (coupon.scope_type === 'hotel' && (coupon.hotel_id !== 0 || coupon.hotel_ids)) {
      const allowedHotelIds = [coupon.hotel_id];
      if (coupon.hotel_ids) {
        coupon.hotel_ids.split(',').forEach((id: string) => allowedHotelIds.push(Number(id.trim())));
      }
      
      // 检查用户是否有其中一个酒店的预订或入住记录
      const [bookingRows] = await pool.query<RowDataPacket[]>(
        `SELECT id FROM bookings 
         WHERE guest_phone = ? AND hotel_id IN (?) 
         AND status IN ('confirmed', 'checked_in', 'pre_checked_in')
         LIMIT 1`,
        [phone, allowedHotelIds]
      );
      if (bookingRows.length === 0 && !isSystemAdmin(userRole) && !isHotelAdmin(userRole) && !isStaff(userRole)) {
        return res.status(403).json(errorResponse('该优惠券仅限适用门店顾客领取'));
      }
    }

    // 公开优惠券检查
    if (!coupon.is_public && !isSystemAdmin(userRole) && !isHotelAdmin(userRole) && !isStaff(userRole)) {
      return res.status(403).json(errorResponse('该优惠券不对外开放领取'));
    }

    if (coupon.total_count > 0 && coupon.received_count >= coupon.total_count) {
      return res.status(400).json(errorResponse('优惠券已被领完'));
    }

    const [existing] = await pool.query<RowDataPacket[]>('SELECT id FROM member_coupons WHERE member_id = ? AND coupon_id = ?', [memberId, id]);
    if (existing.length > 0 && !coupon.is_multiple_use) {
      return res.status(400).json(errorResponse('您已经领过这张券了'));
    }

    await pool.query('INSERT INTO member_coupons (member_id, coupon_id, status) VALUES (?, ?, "unused")', [memberId, id]);
    await pool.query('UPDATE coupons SET received_count = received_count + 1 WHERE id = ?', [id]);

    res.json(successResponse(null, '领取成功'));
  } catch (error) {
    logger.error('领取优惠券失败:', error.message);
    res.status(500).json(errorResponse('领取失败'));
  }
};

export const issueToUser = async (req: AuthRequest, res: Response) => {
  try {
    const { coupon_id, phone } = req.body;
    if (!req.user) {return res.status(401).json(errorResponse('未认证'));}
    if (!coupon_id || !phone) {
      return res.status(400).json(errorResponse('缺少参数'));
    }

    const user = req.user as any;
    const userRole = user.role;
    const userHotelId = user.hotel_id;

    // 权限检查：只有管理员和前台员工可以发放优惠券
    if (!isSystemAdmin(userRole) && !isHotelAdmin(userRole) && !isStaff(userRole)) {
      return res.status(403).json(errorResponse('您没有权限发放优惠券'));
    }

    const [members] = await pool.query<RowDataPacket[]>('SELECT id FROM members WHERE phone = ?', [phone]);
    if (members.length === 0) {
      return res.status(404).json(errorResponse('未找到会员记录，请先注册'));
    }
    const memberId = members[0].id;

    const [couponRows] = await pool.query<RowDataPacket[]>('SELECT * FROM coupons WHERE id = ?', [coupon_id]);
    if (couponRows.length === 0) {
      return res.status(404).json(errorResponse('优惠券不存在'));
    }
    const coupon = couponRows[0] as any;

    // 权限检查：检查是否有权限发放该优惠券
    if (isHotelAdmin(userRole) || isStaff(userRole)) {
      // 酒店管理员和前台只能发放本店的优惠券或全局优惠券
      const isApplicableToMyHotel = coupon.hotel_id === userHotelId || 
        (coupon.hotel_ids && coupon.hotel_ids.split(',').includes(String(userHotelId)));
      
      if (coupon.scope_type !== 'global' && !isApplicableToMyHotel) {
        return res.status(403).json(errorResponse('您只能发放适用本酒店的优惠券'));
      }
    }
    // 系统管理员可以发放任何优惠券

    if (coupon.total_count > 0 && coupon.received_count >= coupon.total_count) {
      return res.status(400).json(errorResponse('优惠券已领完'));
    }

    await pool.query(
      'INSERT INTO member_coupons (member_id, coupon_id, status) VALUES (?, ?, "unused")',
      [memberId, coupon.id]
    );

    if (coupon.total_count > 0) {
      await pool.query('UPDATE coupons SET received_count = received_count + 1 WHERE id = ?', [coupon.id]);
    }

    res.json(successResponse(null, '优惠券发放成功'));
  } catch (error) {
    logger.error('发放优惠券失败:', error.message);
    res.status(500).json(errorResponse('发放优惠券失败'));
  }
};

export const create = async (req: AuthRequest, res: Response) => {
  try {
    const {
      coupon_name, coupon_type, discount_value, min_amount,
      total_count, valid_from, valid_to, coupon_code, is_multiple_use,
      hotel_id, hotel_ids, scope_type, is_public
    } = req.body;

    const user = req.user as any;
    const userRole = user.role;

    // 权限检查：只有系统管理员和酒店管理员可以创建优惠券
    if (!isSystemAdmin(userRole) && !isHotelAdmin(userRole)) {
      return res.status(403).json(errorResponse('您没有权限创建优惠券'));
    }

    // 确定最终hotel_id和scope_type
    let finalHotelId = hotel_id || user.hotel_id || 0;
    let finalHotelIds = Array.isArray(hotel_ids) ? hotel_ids.join(',') : (hotel_ids || null);
    let finalScopeType = scope_type || 'hotel';
    let finalIsPublic = is_public !== undefined ? is_public : true;

    // 系统管理员可以创建全局优惠券或任意酒店的专属优惠券
    if (isSystemAdmin(userRole)) {
      if (scope_type === 'global') {
        finalHotelId = 0;
        finalHotelIds = null;
        finalIsPublic = true;
      } else {
        finalHotelId = hotel_id ? Number(hotel_id) : (user.hotel_id || 0);
        finalScopeType = scope_type || 'hotel';
      }
    } else if (isHotelAdmin(userRole)) {
      // 酒店管理员只能创建本店优惠券
      if (scope_type === 'global') {
        return res.status(403).json(errorResponse('您没有权限创建全局优惠券'));
      }
      finalHotelId = user.hotel_id || 0;
      finalHotelIds = null; // 门店管理员暂时只能创建单店券，或者根据需要支持多店
      finalScopeType = scope_type === 'private' ? 'private' : 'hotel';
    }

    const [result] = await pool.query<ResultSetHeader>(
      `INSERT INTO coupons (coupon_name, coupon_code, coupon_type, discount_value, min_amount, 
        total_count, is_multiple_use, received_count, valid_from, valid_to, hotel_id, hotel_ids,
        scope_type, is_public, created_by_role) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [coupon_name, coupon_code || null, coupon_type, discount_value, min_amount, 
       total_count, is_multiple_use || false, 0, valid_from, valid_to, finalHotelId, finalHotelIds,
       finalScopeType, finalIsPublic, userRole]
    );

    res.json(successResponse({ id: result.insertId }, '创建优惠券成功'));
  } catch (error) {
    logger.error('创建优惠券失败:', error.message);
    res.status(500).json(errorResponse('创建优惠券失败'));
  }
};

export const importCoupon = async (req: AuthRequest, res: Response) => {
  try {
    const { coupon_code } = req.body;
    if (!req.user) {return res.status(401).json(errorResponse('未认证'));}
    if (!coupon_code) {return res.status(400).json(errorResponse('请输入券码'));}

    const user = req.user as any;
    const phone = user.phone || (user.username && user.username.match(/^\d{11}$/) ? user.username : null);

    if (!phone) {
      return res.status(400).json(errorResponse('您的账户信息中没有手机号，无法导入优惠券'));
    }

    const [members] = await pool.query<RowDataPacket[]>('SELECT id FROM members WHERE phone = ?', [phone]);
    let memberId: number;

    if (members.length === 0) {
      const [insertResult] = await pool.query<ResultSetHeader>(
        'INSERT INTO members (phone, name) VALUES (?, ?)',
        [phone, user.username || '新用户']
      );
      memberId = insertResult.insertId;
    } else {
      memberId = members[0].id;
    }

    const [couponRows] = await pool.query<RowDataPacket[]>(
      'SELECT * FROM coupons WHERE LOWER(coupon_code) = LOWER(?) AND (valid_to >= CURDATE() OR valid_to IS NULL)',
      [coupon_code.trim()]
    );

    if (couponRows.length === 0) {
      return res.status(404).json(errorResponse('无效或已过期的优惠券码'));
    }

    const coupon = couponRows[0];

    const [existing] = await pool.query<RowDataPacket[]>(
      'SELECT id FROM member_coupons WHERE member_id = ? AND coupon_id = ?',
      [memberId, coupon.id]
    );

    if (existing.length > 0 && !coupon.is_multiple_use) {
      return res.status(400).json(errorResponse('您已经导入过该优惠券了'));
    }

    if (coupon.total_count > 0 && coupon.received_count >= coupon.total_count) {
      return res.status(400).json(errorResponse('该优惠券已被领完'));
    }

    const [result] = await pool.query<ResultSetHeader>(
      'INSERT INTO member_coupons (member_id, coupon_id, status) VALUES (?, ?, "unused")',
      [memberId, coupon.id]
    );

    if (coupon.total_count > 0) {
      await pool.query('UPDATE coupons SET received_count = received_count + 1 WHERE id = ?', [coupon.id]);
    }

    res.json(successResponse({ id: result.insertId }, '优惠券导入成功'));
  } catch (error) {
    logger.error('导入优惠券失败:', error.message);
    res.status(500).json(errorResponse('导入优惠券失败'));
  }
};

export const update = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { 
      coupon_name, coupon_type, discount_value, min_amount, 
      total_count, valid_from, valid_to, coupon_code, is_multiple_use,
      hotel_id, hotel_ids, scope_type, is_public
    } = req.body;
    const user = req.user as any;

    const [existingRows] = await pool.query<RowDataPacket[]>('SELECT * FROM coupons WHERE id = ?', [id]);
    if (existingRows.length === 0) {
      res.status(404).json(errorResponse('优惠券不存在'));
      return;
    }

    const coupon = existingRows[0] as any;
    if (!isSystemAdmin(user.role)) {
      if (coupon.hotel_id !== (user.hotel_id || 0) && coupon.hotel_id !== 0 && (!coupon.hotel_ids || !coupon.hotel_ids.split(',').includes(String(user.hotel_id)))) {
        return res.status(403).json(errorResponse('无权操作其他门店的优惠券'));
      }
    }

    const finalHotelIds = hotel_ids !== undefined 
      ? (Array.isArray(hotel_ids) ? hotel_ids.join(',') : hotel_ids) 
      : coupon.hotel_ids;

    const [result] = await pool.query<ResultSetHeader>(
      `UPDATE coupons SET 
        coupon_name = ?, coupon_type = ?, discount_value = ?, min_amount = ?, 
        total_count = ?, valid_from = ?, valid_to = ?, coupon_code = ?, 
        is_multiple_use = ?, hotel_id = ?, hotel_ids = ?, scope_type = ?, is_public = ?,
        updated_at = CURRENT_TIMESTAMP WHERE id = ?`,
      [
        coupon_name, coupon_type, discount_value, min_amount, 
        total_count, valid_from, valid_to, coupon_code || null, 
        is_multiple_use || false, hotel_id || coupon.hotel_id, finalHotelIds, 
        scope_type || coupon.scope_type, is_public !== undefined ? is_public : coupon.is_public, id
      ]
    );

    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('优惠券不存在'));
      return;
    }

    res.json(successResponse(null, '更新优惠券成功'));
  } catch (error) {
    logger.error('更新优惠券失败:', error.message);
    res.status(500).json(errorResponse('更新优惠券失败'));
  }
};

export const remove = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const user = req.user as any;

    const [existingRows] = await pool.query<RowDataPacket[]>('SELECT * FROM coupons WHERE id = ?', [id]);
    if (existingRows.length === 0) {
      res.status(404).json(errorResponse('优惠券不存在'));
      return;
    }

    if (!isSystemAdmin(user.role)) {
      const coupon = existingRows[0] as any;
      if (coupon.hotel_id !== (user.hotel_id || 0) && coupon.hotel_id !== 0) {
        return res.status(403).json(errorResponse('无权操作其他门店的优惠券'));
      }
    }

    const [result] = await pool.query<ResultSetHeader>('DELETE FROM coupons WHERE id = ?', [id]);

    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('优惠券不存在'));
      return;
    }

    res.json(successResponse(null, '删除优惠券成功'));
  } catch (error) {
    logger.error('删除优惠券失败:', error.message);
    res.status(500).json(errorResponse('删除优惠券失败'));
  }
};

export const redeemCoupon = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    if (!req.user) {return res.status(401).json(errorResponse('未认证'));}

    const user = req.user as any;

    const [mcRows] = await pool.query<RowDataPacket[]>(
      `SELECT mc.*, c.hotel_id FROM member_coupons mc JOIN coupons c ON mc.coupon_id = c.id WHERE mc.id = ?`,
      [id]
    );
    if (mcRows.length === 0) {return res.status(404).json(errorResponse('优惠券记录不存在'));}

    const mc = mcRows[0] as any;

    if (mc.status !== 'unused') {
      return res.status(400).json(errorResponse('该优惠券已使用或已过期'));
    }

    if (isStaff(user.role) && mc.hotel_id !== user.hotel_id && mc.hotel_id !== 0) {
      return res.status(403).json(errorResponse('您只能核销本酒店的优惠券'));
    }

    await pool.query('UPDATE member_coupons SET status = "used", used_at = NOW() WHERE id = ?', [id]);

    res.json(successResponse(null, '核销成功'));
  } catch (error) {
    logger.error('核销优惠券失败:', error.message);
    res.status(500).json(errorResponse('核销失败'));
  }
};
