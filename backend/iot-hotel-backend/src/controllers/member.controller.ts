import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { hashPassword, comparePassword } from '../utils/password';

export const get = async (req: AuthRequest, res: Response) => {
  try {
    const { page = 1, pageSize = 10, level } = req.query;
    const offset = (Number(page) - 1) * Number(pageSize);

    // 如果是普通用户且没有提供特定ID，返回自己的信息
    if (req.user?.role === 'user') {
      const user = req.user as any;
      const phone = user.phone || user.username; // 优先使用 phone
      const [rows] = await pool.query<RowDataPacket[]>('SELECT * FROM members WHERE phone = ?', [phone]);
      if (rows.length === 0) {
        return res.json(successResponse({
          list: [], total: 0, page: 1, pageSize: 10, totalPages: 0
        }, '获取会员列表成功'));
      }
      return res.json(successResponse({
        list: rows, total: 1, page: 1, pageSize: 10, totalPages: 1
      }, '获取会员列表成功'));
    }

    let whereClause = 'WHERE 1=1';
    const params: any[] = [];

    if (level) {
      whereClause += ' AND member_level = ?';
      params.push(level);
    }

    const [totalRows] = await pool.query<RowDataPacket[]>(`SELECT COUNT(*) as total FROM members ${whereClause}`, params);
    const total = (totalRows[0] as any).total;

    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT * FROM members ${whereClause} ORDER BY id DESC LIMIT ? OFFSET ?`,
      [...params, Number(pageSize), offset]
    );

    res.json(successResponse({
      list: rows,
      total,
      page: Number(page),
      pageSize: Number(pageSize),
      totalPages: Math.ceil(total / Number(pageSize))
    }, '获取会员列表成功'));
  } catch (error) {
    logger.error('获取会员列表失败:', error);
    res.status(500).json(errorResponse('获取会员列表失败'));
  }
};

export const getById = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;

    const [rows] = await pool.query<RowDataPacket[]>('SELECT * FROM members WHERE id = ?', [id]);

    if (rows.length === 0) {
      res.status(404).json(errorResponse('会员不存在'));
      return;
    }

    res.json(successResponse(rows[0], '获取会员详情成功'));
  } catch (error) {
    logger.error('获取会员详情失败:', error);
    res.status(500).json(errorResponse('获取会员详情失败'));
  }
};

export const create = async (req: Request, res: Response) => {
  try {
    const { phone, password, name, id_number } = req.body;

    const [existingRows] = await pool.query<RowDataPacket[]>('SELECT * FROM members WHERE phone = ?', [phone]);

    if (existingRows.length > 0) {
      res.status(400).json(errorResponse('手机号已注册'));
      return;
    }

    const hashedPassword = await hashPassword(password);

    const [result] = await pool.query<ResultSetHeader>(
      'INSERT INTO members (phone, password, name, id_number, member_level, points, balance, total_spent, total_stays) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [phone, hashedPassword, name, id_number, 'standard', 0, 0.00, 0.00, 0]
    );

    res.json(successResponse({ id: result.insertId }, '注册会员成功'));
  } catch (error) {
    logger.error('注册会员失败:', error);
    res.status(500).json(errorResponse('注册会员失败'));
  }
};

export const update = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { name, id_number, member_level, points, balance, total_spent, total_stays } = req.body;

    const [result] = await pool.query<ResultSetHeader>(
      'UPDATE members SET name = ?, id_number = ?, member_level = ?, points = ?, balance = ?, total_spent = ?, total_stays = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      [name, id_number, member_level, points, balance, total_spent, total_stays, id]
    );

    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('会员不存在'));
      return;
    }

    res.json(successResponse(null, '更新会员信息成功'));
  } catch (error) {
    logger.error('更新会员信息失败:', error);
    res.status(500).json(errorResponse('更新会员信息失败'));
  }
};

export const getMe = async (req: AuthRequest, res: Response) => {
  try {
    if (!req.user) return res.status(401).json(errorResponse('未认证'));

    const user = req.user as any;
    // 如果没有对应的会员记录，先尝试通过 phone 查找
    const phone = user.phone || user.username; // 优先使用 phone
    let [rows] = await pool.query<RowDataPacket[]>('SELECT * FROM members WHERE phone = ?', [phone]);

    // 如果没有，再尝试通过 user_id 查找 (以防 user_id 列不存在)
    if (rows.length === 0) {
      try {
        const [userIdRows] = await pool.query<RowDataPacket[]>('SELECT * FROM members WHERE user_id = ?', [user.id]);
        rows = userIdRows;
      } catch (e) {
        // 如果没有 user_id 列，忽略错误
        logger.warn('members 表可能缺少 user_id 列:', e);
      }
    }

    if (rows.length === 0) {
      // 如果仍未找到对应的会员记录，返回默认空资产，而不是 500
      return res.json(successResponse({
        id: 0,
        phone: user.username,
        name: user.username,
        member_level: 'standard',
        points: 0,
        balance: 0.00,
        total_spent: 0.00,
        total_stays: 0,
        coupons_count: 0
      }, '获取资产成功'));
    }

    // 增加优惠券数量统计
    const [couponRows] = await pool.query<RowDataPacket[]>(
      'SELECT COUNT(*) as count FROM user_coupons WHERE user_id = ? AND status = "unused"',
      [user.id]
    );
    const result = { ...rows[0], coupons_count: (couponRows[0] as any).count || 0 };

    res.json(successResponse(result, '获取资产成功'));
  } catch (error) {
    logger.error('获取会员资产失败:', error);
    // 降级返回默认信息，而不是 500
    const user = req.user as any;
    res.json(successResponse({
      id: 0,
      phone: user?.username || '',
      name: user?.username || '',
      member_level: 'standard',
      points: 0,
      balance: 0.00,
      total_spent: 0.00,
      total_stays: 0,
      coupons_count: 0
    }, '获取资产成功(降级)'));
  }
};

export const getStatus = async (req: AuthRequest, res: Response) => {
  try {
    if (!req.user) return res.status(401).json(errorResponse('未认证'));

    const user = req.user as any;
    const phone = user.phone || user.username;

    // 检查会员状态
    const [memberRows] = await pool.query<RowDataPacket[]>('SELECT * FROM members WHERE phone = ?', [phone]);
    const isMember = memberRows.length > 0;
    const memberInfo = isMember ? memberRows[0] : null;

    // 检查入住状态
    const [guestRows] = await pool.query<RowDataPacket[]>(
      `SELECT g.*, r.room_number, r.room_name, b.booking_number
       FROM guests g
       LEFT JOIN rooms r ON g.room_id = r.id
       LEFT JOIN bookings b ON g.booking_id = b.id
       WHERE g.guest_phone = ? AND g.check_out_time IS NULL
       LIMIT 1`,
      [phone]
    );
    const isCheckedIn = guestRows.length > 0;
    const checkinInfo = isCheckedIn ? guestRows[0] : null;

    res.json(successResponse({
      phone,
      is_member: isMember,
      member_info: memberInfo,
      is_checked_in: isCheckedIn,
      checkin_info: checkinInfo
    }, '获取状态成功'));
  } catch (error) {
    logger.error('获取用户状态失败:', error);
    res.status(500).json(errorResponse('获取状态失败'));
  }
};

export const login = async (req: Request, res: Response) => {
  try {
    const { phone, password } = req.body;

    const [rows] = await pool.query<RowDataPacket[]>('SELECT * FROM members WHERE phone = ?', [phone]);

    if (rows.length === 0) {
      res.status(401).json(errorResponse('手机号或密码错误'));
      return;
    }

    const member = rows[0];
    const isPasswordValid = await comparePassword(password, member.password);

    if (!isPasswordValid) {
      res.status(401).json(errorResponse('手机号或密码错误'));
      return;
    }

    res.json(successResponse({
      id: member.id,
      phone: member.phone,
      name: member.name,
      member_level: member.member_level,
      points: member.points,
      balance: member.balance
    }, '登录成功'));
  } catch (error) {
    logger.error('会员登录失败:', error);
    res.status(500).json(errorResponse('登录失败'));
  }
};
