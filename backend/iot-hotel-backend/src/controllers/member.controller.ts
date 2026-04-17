import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { hashPassword, comparePassword } from '../utils/password';
import { isCustomer } from '../utils/role';
import { systemConfigService } from '../services/system-config.service';

import { LEVEL_DISCOUNTS, LEVEL_POINTS_MULTIPLIER } from '../config/constants';

export const updateLevelDiscounts = async (req: AuthRequest, res: Response) => {
  try {
    const { discounts } = req.body;
    if (!discounts) return res.status(400).json(errorResponse('缺少参数'));
    
    // 使用 Object.assign 更新对象属性，而不是对导入的常量进行重新赋值
    Object.assign(LEVEL_DISCOUNTS, discounts);
    res.json(successResponse(LEVEL_DISCOUNTS, '更新会员折扣成功'));
  } catch (error) {
    logger.error('更新会员折扣失败:', error.message);
    res.status(500).json(errorResponse('更新会员折扣失败'));
  }
};

export const getLevelDiscounts = async (_req: Request, res: Response) => {
  res.json(successResponse(LEVEL_DISCOUNTS, '获取会员折扣成功'));
};

export const rechargeBalance = async (req: AuthRequest, res: Response) => {
  try {
    const { amount } = req.body;
    if (!amount || isNaN(amount) || amount <= 0) {
      return res.status(400).json(errorResponse('无效的充值金额'));
    }

    const phone = req.user?.phone || req.user?.username;
    if (!phone) return res.status(401).json(errorResponse('用户未登录'));

    // 获取当前会员等级以计算优惠
    const [memberRows] = await pool.query<RowDataPacket[]>(
      'SELECT id, member_level, balance FROM members WHERE phone = ?',
      [phone]
    );

    if (!memberRows || memberRows.length === 0) {
      return res.status(404).json(errorResponse('会员信息不存在'));
    }

    const member = memberRows[0];
    
    // 获取动态会员方案配置
    const levelConfig = await systemConfigService.getLevelConfig(member.member_level);
    const discountRate = levelConfig ? Number(levelConfig.discount || 1.0) : (LEVEL_DISCOUNTS[member.member_level] || 1.0);
    
    const bonusRate = 1 - discountRate;
    const bonusAmount = Math.floor((amount * bonusRate) * 100) / 100;
    const creditAmount = Math.floor((amount + bonusAmount) * 100) / 100;
    const newBalance = Number(member.balance || 0) + creditAmount;

    await pool.query(
      'UPDATE members SET balance = ? WHERE id = ?',
      [newBalance, member.id]
    );

    logger.info(`会员充值成功: 手机号 ${phone}, 支付 ${amount}, 获得余额 ${creditAmount}(含赠送 ${bonusAmount}), 最终余额 ${newBalance}`);

    res.json(successResponse({
      paid_amount: amount,
      credit_amount: creditAmount,
      bonus_amount: bonusAmount,
      new_balance: newBalance
    }, '充值成功'));
  } catch (error) {
    logger.error('会员充值失败:', error.message);
    res.status(500).json(errorResponse('会员充值失败'));
  }
};

/**
 * 获取等级标签
 */
async function getLevelLabel(memberLevel: string): Promise<string> {
  const levelConfig = await systemConfigService.getLevelConfig(memberLevel);
  if (levelConfig) return levelConfig.name;

  const labels: Record<string, string> = {
    'diamond': '钻石会员',
    'platinum': '铂金会员',
    'gold': '金会员',
    'silver': '银会员',
    'standard': '普通会员'
  };
  return labels[memberLevel] || '普通会员';
}

/**
 * 根据关键字获取数字等级
 */
function getLevelNumber(memberLevel: string): number {
  const mapping: Record<string, number> = {
    'diamond': 5,
    'platinum': 4,
    'gold': 3,
    'silver': 2,
    'standard': 1
  };
  return mapping[memberLevel] || 1;
}

/**
 * 根据经验值计算会员等级关键字
 * 使用系统配置的会员方案
 */
async function calculateMemberLevel(experience: number): Promise<string> {
  return systemConfigService.calculateLevel(experience);
}

export const get = async (req: AuthRequest, res: Response) => {
  try {
    const { page = 1, pageSize = 10, level } = req.query;
    const offset = (Number(page) - 1) * Number(pageSize);

    // 如果是普通用户且没有提供特定ID，返回自己的信息
    if (isCustomer(req.user?.role)) {
      const user = req.user as any;
      const phone = user.phone || user.username; // 优先使用 phone
      const [rows] = await pool.query<RowDataPacket[]>('SELECT * FROM members WHERE phone = ?', [phone]);
      if (rows.length === 0) {
        return res.json(successResponse({
          list: [], total: 0, page: 1, pageSize: 10, totalPages: 0
        }, '获取会员列表成功'));
      }
      
      const membersWithLevel = await Promise.all(rows.map(async m => ({
      ...m,
      level: getLevelNumber(m.member_level),
      level_label: await getLevelLabel(m.member_level)
    })));
    return res.json(successResponse({
      list: membersWithLevel, total: 1, page: 1, pageSize: 10, totalPages: 1
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

  const membersWithLevel = await Promise.all(rows.map(async m => ({
    ...m,
    level: getLevelNumber(m.member_level),
    level_label: await getLevelLabel(m.member_level)
  })));

    res.json(successResponse({
      list: membersWithLevel,
      total,
      page: Number(page),
      pageSize: Number(pageSize),
      totalPages: Math.ceil(total / Number(pageSize))
    }, '获取会员列表成功'));
  } catch (error) {
    logger.error('获取会员列表失败:', error.message);
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

    const member = {
      ...rows[0],
      level: getLevelNumber(rows[0].member_level),
      level_label: await getLevelLabel(rows[0].member_level)
    };

    res.json(successResponse(member, '获取会员详情成功'));
  } catch (error) {
    logger.error('获取会员详情失败:', error.message);
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
    logger.error('注册会员失败:', error.message);
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
    logger.error('更新会员信息失败:', error.message);
    res.status(500).json(errorResponse('更新会员信息失败'));
  }
};

// 临时数据库修复接口
export const fixDatabaseSchema = async (req: AuthRequest, res: Response) => {
  try {
    await pool.query('ALTER TABLE bookings ADD COLUMN used_points INT DEFAULT 0 AFTER coupon_id');
    await pool.query('ALTER TABLE bookings ADD COLUMN points_discount DECIMAL(10,2) DEFAULT 0.00 AFTER used_points');
    res.json(successResponse(null, '数据库表 bookings 修复成功'));
  } catch (error: any) {
    if (error.code === 'ER_DUP_COLUMN_NAME') {
      return res.json(successResponse(null, '字段已存在，无需修复'));
    }
    logger.error('修复数据库失败:', error.message);
    res.status(500).json(errorResponse('修复数据库失败: ' + error.message));
  }
};

// 辅助函数：确保会员记录存在
async function ensureMemberRecord(phone: string, name: string) {
  const [rows] = await pool.query<RowDataPacket[]>('SELECT * FROM members WHERE phone = ?', [phone]);
  if (rows.length > 0) return rows[0];

  // 创建会员记录
  const [result] = await pool.query<ResultSetHeader>(
    'INSERT INTO members (phone, name, member_level, experience, points, balance) VALUES (?, ?, "standard", 0, 0, 0.00)',
    [phone, name]
  );
  
  const [newRows] = await pool.query<RowDataPacket[]>('SELECT * FROM members WHERE id = ?', [result.insertId]);
  return newRows[0];
}

export const getMe = async (req: AuthRequest, res: Response) => {
  try {
    if (!req.user) return res.status(401).json(errorResponse('未认证'));

    const user = req.user as any;
    const phone = user.phone || user.username;

    // 确保会员记录存在
    const member = await ensureMemberRecord(phone, user.username);

    // 增加优惠券数量统计
    const [couponRows]: any = await pool.query(
      'SELECT COUNT(*) as count FROM member_coupons WHERE member_id = ? AND status = "unused"',
      [member.id]
    );

    // 获取系统配置的会员方案
    const memberScheme = await systemConfigService.getMemberScheme();

    // 构建动态的 level_discounts 和 level_multipliers
    const levelDiscounts: Record<string, number> = {};
    const levelMultipliers: Record<string, number> = {};
    memberScheme.forEach((level: any) => {
      levelDiscounts[level.key] = Number(level.discount || 1.0);
      levelMultipliers[level.key] = Number(level.points_multiplier || 1);
    });

    // 计算等级 (以数据库存储的 member_level 为准，映射数字等级和标签)
    const levelNum = getLevelNumber(member.member_level);
    const levelLabel = await getLevelLabel(member.member_level);

    // 显式构建结果对象，确保所有字段都包含在内
    const result = {
      id: member.id,
      phone: member.phone,
      name: member.name,
      member_level: member.member_level, // 关键字 member_level (数据库原始值)
      level: levelNum,                   // 数字等级
      level_label: levelLabel,           // 中文标签
      experience: Number(member.experience || 0),
      points: Number(member.points || 0),
      balance: member.balance,
      total_spent: member.total_spent,
      total_stays: member.total_stays,
      last_checkin_date: member.last_checkin_date,
      coupons_count: Number(couponRows[0]?.count || 0),
      level_discounts: levelDiscounts,   // 使用系统配置的折扣
      level_multipliers: levelMultipliers // 使用系统配置的积分倍率
    };

    logger.info(`获取会员资产成功: 手机号 ${phone}, 成长值 ${result.experience}, 等级 ${result.member_level}`);
    res.json(successResponse(result, '获取资产成功'));
  } catch (error) {
    logger.error('获取会员资产失败:', error.message);
    res.status(500).json(errorResponse('获取资产失败'));
  }
};

export const getStatus = async (req: AuthRequest, res: Response) => {
  try {
    if (!req.user) return res.status(401).json(errorResponse('未认证'));

    const user = req.user as any;
    const phone = user.phone || user.username;
    const userId = user.id;

    // 检查会员状态
    const [memberRows] = await pool.query<RowDataPacket[]>('SELECT * FROM members WHERE phone = ?', [phone]);
    const isMember = memberRows.length > 0;
    let memberInfo = isMember ? memberRows[0] : null;

    if (memberInfo) {
      memberInfo = {
        ...memberInfo,
        level: getLevelNumber(memberInfo.member_level),
        level_label: await getLevelLabel(memberInfo.member_level)
      };
    }

    // 检查入住状态
    const [guestRows] = await pool.query<RowDataPacket[]>(
      `SELECT g.*, r.room_number, r.room_name, r.hotel_id, b.booking_number
       FROM guests g
       LEFT JOIN rooms r ON g.room_id = r.id
       LEFT JOIN bookings b ON g.booking_id = b.id
       WHERE (b.user_id = ? OR g.guest_phone = ?) 
       AND g.check_out_time IS NULL 
       AND b.status = 'checked_in'
       AND DATE(b.check_out_date) >= CURDATE()
       ORDER BY g.check_in_time DESC
       LIMIT 1`,
      [userId, phone]
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
    logger.error('获取用户状态失败:', error.message);
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
    logger.error('会员登录失败:', error.message);
    res.status(500).json(errorResponse('登录失败'));
  }
};

// 会员签到 (每日领取成长值)
export const checkin = async (req: AuthRequest, res: Response) => {
  try {
    logger.info('收到会员签到请求:', req.user?.username);
    if (!req.user) return res.status(401).json(errorResponse('未认证'));

    const user = req.user as any;
    const phone = user.phone || user.username;
    
    // 确保会员记录存在
    const member = await ensureMemberRecord(phone, user.username);
    
    // 使用本地时间获取日期，避免 ISOString 时区导致的问题
    const now = new Date();
    const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;

    logger.info(`签到校验: 手机号 ${phone}, 数据库日期 ${member.last_checkin_date}, 今天日期 ${today}`);

    // 检查是否已签到
    if (member.last_checkin_date) {
      const lastDateObj = new Date(member.last_checkin_date);
      const lastDate = `${lastDateObj.getFullYear()}-${String(lastDateObj.getMonth() + 1).padStart(2, '0')}-${String(lastDateObj.getDate()).padStart(2, '0')}`;
      
      if (lastDate === today) {
        return res.json(successResponse({ already_checked_in: true }, '今日已签到'));
      }
    }

    // 计算获得的奖励
    // 1. 成长值 (从配置获取，默认 10 点)
    const expGain = await systemConfigService.getCheckinExp();
    const newExp = (member.experience || 0) + expGain;
    
    // 2. 积分 (从配置获取，默认 50 点)
    const pointsGain = await systemConfigService.getCheckinPoints();
    const newPoints = (member.points || 0) + pointsGain;
    
    // 自动升级逻辑
    const newLevelKey = await calculateMemberLevel(newExp);
    const newLevelNum = getLevelNumber(newLevelKey);
    const newLevelLabel = await getLevelLabel(newLevelKey);

    await pool.query(
      'UPDATE members SET experience = ?, points = ?, member_level = ?, last_checkin_date = ? WHERE id = ?',
      [newExp, newPoints, newLevelKey, today, member.id]
    );

    res.json(successResponse({
      already_checked_in: false,
      experience: expGain,
      points: pointsGain,
      total_experience: newExp,
      total_points: newPoints,
      member_level: newLevelKey,
      level: newLevelNum,
      level_label: newLevelLabel
    }, '签到成功'));
  } catch (error) {
    logger.error('会员签到失败:', error.message);
    res.status(500).json(errorResponse('签到失败'));
  }
};
