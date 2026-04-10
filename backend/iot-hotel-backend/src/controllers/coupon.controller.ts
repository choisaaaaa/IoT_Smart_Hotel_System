import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';

export const get = async (req: Request, res: Response) => {
  try {
    const { page = 1, pageSize = 10, status } = req.query;
    const offset = (Number(page) - 1) * Number(pageSize);

    let whereClause = 'WHERE 1=1';
    const params: any[] = [];

    if (status) {
      whereClause += ' AND status = ?';
      params.push(status);
    }

    const [totalRows] = await pool.query<RowDataPacket[]>(`SELECT COUNT(*) as total FROM coupons ${whereClause}`, params);
    const total = (totalRows[0] as any).total;

    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT * FROM coupons ${whereClause} ORDER BY id DESC LIMIT ? OFFSET ?`,
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
    logger.error('获取优惠券列表失败:', error);
    res.status(500).json(errorResponse('获取优惠券列表失败'));
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
    logger.error('获取优惠券详情失败:', error);
    res.status(500).json(errorResponse('获取优惠券详情失败'));
  }
};

export const getMe = async (req: AuthRequest, res: Response) => {
  try {
    if (!req.user) return res.status(401).json(errorResponse('未认证'));

    // 查找会员ID
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
    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT mc.id as id, c.id as coupon_id, c.coupon_name, c.coupon_code, c.coupon_type, c.discount_value, c.min_amount, c.valid_from, c.valid_to, mc.status as my_status, mc.created_at as received_at
       FROM member_coupons mc
       JOIN coupons c ON mc.coupon_id = c.id
       WHERE mc.member_id = ? AND mc.status = 'unused' AND (c.valid_to >= CURDATE() OR c.valid_to IS NULL)`,
      [memberId]
    );

    res.json(successResponse(rows, '获取优惠券成功'));
  } catch (error) {
    logger.error('获取会员优惠券失败:', error);
    res.status(500).json(errorResponse('获取优惠券失败'));
  }
};

// 领取优惠券 (用户自主领取)
export const receive = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    if (!req.user) return res.status(401).json(errorResponse('未认证'));

    const user = req.user as any;
    const phone = user.phone || (user.username && user.username.match(/^\d{11}$/) ? user.username : null);
    if (!phone) return res.status(400).json(errorResponse('您的账户信息中没有手机号，无法领取优惠券'));

    const [members] = await pool.query<RowDataPacket[]>('SELECT id FROM members WHERE phone = ?', [phone]);
    if (members.length === 0) return res.status(404).json(errorResponse('未找到会员记录'));
    const memberId = members[0].id;

    // 检查券是否存在及库存
    const [couponRows] = await pool.query<RowDataPacket[]>('SELECT * FROM coupons WHERE id = ? AND valid_to >= CURDATE()', [id]);
    if (couponRows.length === 0) return res.status(404).json(errorResponse('优惠券不存在或已过期'));
    const coupon = couponRows[0];

    if (coupon.total_count > 0 && coupon.received_count >= coupon.total_count) {
      return res.status(400).json(errorResponse('优惠券已被领完'));
    }

    // 检查是否已领过
    const [existing] = await pool.query<RowDataPacket[]>('SELECT id FROM member_coupons WHERE member_id = ? AND coupon_id = ?', [memberId, id]);
    if (existing.length > 0 && !coupon.is_multiple_use) {
      return res.status(400).json(errorResponse('您已经领过这张券了'));
    }

    await pool.query('INSERT INTO member_coupons (member_id, coupon_id, status) VALUES (?, ?, "unused")', [memberId, id]);
    await pool.query('UPDATE coupons SET received_count = received_count + 1 WHERE id = ?', [id]);

    res.json(successResponse(null, '领取成功'));
  } catch (error) {
    logger.error('领取优惠券失败:', error);
    res.status(500).json(errorResponse('领取失败'));
  }
};

// 发放优惠券给特定用户
export const issueToUser = async (req: AuthRequest, res: Response) => {
  try {
    const { coupon_id, phone } = req.body;
    if (!coupon_id || !phone) {
      return res.status(400).json(errorResponse('缺少参数'));
    }

    // 查找会员
    const [members] = await pool.query<RowDataPacket[]>('SELECT id FROM members WHERE phone = ?', [phone]);
    if (members.length === 0) {
      return res.status(404).json(errorResponse('未找到会员记录，请先注册'));
    }
    const memberId = members[0].id;

    // 查找优惠券并检查库存
    const [couponRows] = await pool.query<RowDataPacket[]>('SELECT * FROM coupons WHERE id = ?', [coupon_id]);
    if (couponRows.length === 0) {
      return res.status(404).json(errorResponse('优惠券不存在'));
    }
    const coupon = couponRows[0];

    if (coupon.total_count > 0 && coupon.received_count >= coupon.total_count) {
      return res.status(400).json(errorResponse('优惠券已领完'));
    }

    // 发放
    await pool.query(
      'INSERT INTO member_coupons (member_id, coupon_id, status) VALUES (?, ?, "unused")',
      [memberId, coupon.id]
    );

    // 更新领取数
    if (coupon.total_count > 0) {
      await pool.query('UPDATE coupons SET received_count = received_count + 1 WHERE id = ?', [coupon.id]);
    }

    res.json(successResponse(null, '优惠券发放成功'));
  } catch (error) {
    logger.error('发放优惠券失败:', error);
    res.status(500).json(errorResponse('发放优惠券失败'));
  }
};

export const create = async (req: AuthRequest, res: Response) => {
  try {
    const {
      coupon_name, coupon_type, discount_value, min_amount,
      total_count, valid_from, valid_to, coupon_code, is_multiple_use,
      hotel_id
    } = req.body;

    // 非住客用户发放自己权限范围内门店的优惠券
    const user = req.user as any;
    let finalHotelId = hotel_id || 0;

    if (user.role !== 'system') {
      finalHotelId = user.hotel_id;
    }

    const [result] = await pool.query<ResultSetHeader>(
      'INSERT INTO coupons (coupon_name, coupon_code, coupon_type, discount_value, min_amount, total_count, is_multiple_use, received_count, valid_from, valid_to, hotel_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [coupon_name, coupon_code || null, coupon_type, discount_value, min_amount, total_count, is_multiple_use || false, 0, valid_from, valid_to, finalHotelId]
    );

    res.json(successResponse({ id: result.insertId }, '创建优惠券成功'));
  } catch (error) {
    logger.error('创建优惠券失败:', error);
    res.status(500).json(errorResponse('创建优惠券失败'));
  }
};

// 导入优惠券 (通过券码)
export const importCoupon = async (req: AuthRequest, res: Response) => {
  try {
    const { coupon_code } = req.body;
    if (!req.user) return res.status(401).json(errorResponse('未认证'));
    if (!coupon_code) return res.status(400).json(errorResponse('请输入券码'));

    const user = req.user as any;
    const phone = user.phone || (user.username && user.username.match(/^\d{11}$/) ? user.username : null);

    if (!phone) {
      return res.status(400).json(errorResponse('您的账户信息中没有手机号，无法导入优惠券'));
    }

    // 查找会员记录
    let [members] = await pool.query<RowDataPacket[]>('SELECT id FROM members WHERE phone = ?', [phone]);
    let memberId: number;

    // 如果没有会员记录，为当前用户创建一个 (以防万一)
    if (members.length === 0) {
      const [insertResult] = await pool.query<ResultSetHeader>(
        'INSERT INTO members (phone, name) VALUES (?, ?)',
        [phone, user.username || '新用户']
      );
      memberId = insertResult.insertId;
    } else {
      memberId = members[0].id;
    }

    // 查找优惠券定义 (忽略大小写)
    const [couponRows] = await pool.query<RowDataPacket[]>(
      'SELECT * FROM coupons WHERE LOWER(coupon_code) = LOWER(?) AND (valid_to >= CURDATE() OR valid_to IS NULL)',
      [coupon_code.trim()]
    );

    if (couponRows.length === 0) {
      return res.status(404).json(errorResponse('无效或已过期的优惠券码'));
    }

    const coupon = couponRows[0];

    // 检查是否为单次导入且已被该用户领取过
    const [existing] = await pool.query<RowDataPacket[]>(
      'SELECT id FROM member_coupons WHERE member_id = ? AND coupon_id = ?',
      [memberId, coupon.id]
    );

    if (existing.length > 0 && !coupon.is_multiple_use) {
      return res.status(400).json(errorResponse('您已经导入过该优惠券了'));
    }

    // 检查发行总量 (仅针对有总量限制的)
    if (coupon.total_count > 0 && coupon.received_count >= coupon.total_count) {
      return res.status(400).json(errorResponse('该优惠券已被领完'));
    }

    // 插入用户优惠券记录
    const [result] = await pool.query<ResultSetHeader>(
      'INSERT INTO member_coupons (member_id, coupon_id, status) VALUES (?, ?, "unused")',
      [memberId, coupon.id]
    );

    // 更新领取数 (仅限非无限次券)
    if (coupon.total_count > 0) {
      await pool.query('UPDATE coupons SET received_count = received_count + 1 WHERE id = ?', [coupon.id]);
    }

    res.json(successResponse({ id: result.insertId }, '优惠券导入成功'));
  } catch (error) {
    logger.error('导入优惠券失败:', error);
    res.status(500).json(errorResponse('导入优惠券失败'));
  }
};

export const update = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { coupon_name, coupon_type, discount_value, min_amount, total_count, valid_from, valid_to, coupon_code, is_multiple_use } = req.body;

    const [result] = await pool.query<ResultSetHeader>(
      'UPDATE coupons SET coupon_name = ?, coupon_type = ?, discount_value = ?, min_amount = ?, total_count = ?, valid_from = ?, valid_to = ?, coupon_code = ?, is_multiple_use = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      [coupon_name, coupon_type, discount_value, min_amount, total_count, valid_from, valid_to, coupon_code || null, is_multiple_use || false, id]
    );

    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('优惠券不存在'));
      return;
    }

    res.json(successResponse(null, '更新优惠券成功'));
  } catch (error) {
    logger.error('更新优惠券失败:', error);
    res.status(500).json(errorResponse('更新优惠券失败'));
  }
};

export const remove = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;

    const [result] = await pool.query<ResultSetHeader>('DELETE FROM coupons WHERE id = ?', [id]);

    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('优惠券不存在'));
      return;
    }

    res.json(successResponse(null, '删除优惠券成功'));
  } catch (error) {
    logger.error('删除优惠券失败:', error);
    res.status(500).json(errorResponse('删除优惠券失败'));
  }
};

