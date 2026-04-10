import { Router, Request, Response } from 'express';
import { AuthRequest } from '../types';
import { successResponse, errorResponse, sendSuccess, sendError } from '../types';
import { hashPassword, comparePassword } from '../utils/password';
import { normalizeRole } from '../utils/role';
import db from '../config/database';

const router = Router();

// 获取用户列表 (管理员权限)
export async function list(req: AuthRequest, res: Response) {
  try {
    const { page = 1, limit = 10, role, keyword, hotel_id } = req.query;
    const currentUser = req.user;

    if (!currentUser) {
      return sendError(res, errorResponse('未授权', 401));
    }

    // 获取分页参数并确保为正整数
    const p = Math.max(1, parseInt(page as string) || 1);
    const l = Math.max(1, parseInt(limit as string) || 10);
    const offset = (p - 1) * l;

    let sql = `SELECT u.id, u.username, u.phone, u.email, u.role, u.hotel_id, u.created_at,
                h.hotel_name
                FROM users u
                LEFT JOIN hotels h ON u.hotel_id = h.id`;

    let countSql = 'SELECT COUNT(*) as total FROM users u';

    const conditions: string[] = [];
    const params: any[] = [];

    // 权限隔离：非系统管理员只能查看自己酒店的员工，且不能查看普通用户 (user 角色)
    const userRole = normalizeRole(currentUser.role);
    if (userRole === 'admin' || userRole === 'staff' || userRole === 'manager') {
      conditions.push('u.hotel_id = ?');
      params.push(currentUser.hotel_id);
      // 门店管理人员不能看到普通用户
      conditions.push("u.role NOT IN ('user')");
      // 不能看到 system 用户
      conditions.push('u.role != ?');
      params.push('system');
    } else if (userRole === 'system') {
      // System 可以看到所有用户，也可以按门店过滤
      if (hotel_id && hotel_id !== 'undefined') {
        conditions.push('u.hotel_id = ?');
        params.push(hotel_id);
      }
    } else {
      return sendError(res, errorResponse('权限不足', 403));
    }

    if (keyword) {
      conditions.push('(u.username LIKE ? OR u.email LIKE ? OR u.phone LIKE ?)');
      params.push(`%${keyword}%`, `%${keyword}%`, `%${keyword}%`);
    }

    if (role) {
      conditions.push('u.role = ?');
      params.push(role);
    }

    if (conditions.length > 0) {
      sql += ' WHERE ' + conditions.join(' AND ');
      countSql += ' WHERE ' + conditions.join(' AND ');
    }

    sql += ' ORDER BY u.created_at DESC LIMIT ? OFFSET ?';

    // 使用 db.query 而非 db.execute 以更好地支持 LIMIT/OFFSET 的参数替换
    const [users]: any = await db.query(sql, [...params, l, offset]);
    const [countResult]: any = await db.query(countSql, params);

    sendSuccess(res, {
      users,
      total: countResult[0].total,
      page: p,
      limit: l
    });
  } catch (error) {
    console.error('获取用户列表失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

// 获取用户详情
export async function detail(req: AuthRequest, res: Response) {
  try {
    const userId = req.params.id;

    const [users]: any = await db.execute(
      `SELECT u.*, GROUP_CONCAT(r.role_name) as roles
       FROM users u
       LEFT JOIN user_roles ur ON u.id = ur.user_id
       LEFT JOIN roles r ON ur.role_id = r.id
       WHERE u.id = ?
       GROUP BY u.id`,
      [userId]
    );

    if (users.length === 0) {
      return sendError(res, errorResponse('用户不存在', 404));
    }

    sendSuccess(res, { user: users[0] });
  } catch (error) {
    console.error('获取用户详情失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

// 创建用户
export async function create(req: AuthRequest, res: Response) {
  try {
    const { username, password, email, phone, role, hotel_id } = req.body;
    const currentUser = req.user;

    if (!currentUser) {
      return sendError(res, errorResponse('未授权', 401));
    }

    if (!username || !password) {
      return sendError(res, errorResponse('用户名和密码不能为空', 400));
    }

    // 权限检查
    let finalHotelId = hotel_id;
    let finalRole = role || 'user';

    if (currentUser.role === 'admin') {
      // Admin 只能创建自己门店的 admin 或 staff
      finalHotelId = currentUser.hotel_id;
      if (!['admin', 'staff', 'user'].includes(finalRole)) {
        return sendError(res, errorResponse('Admin 只能创建门店管理员、员工或普通用户', 403));
      }
    } else if (currentUser.role === 'system') {
      // System 可以创建任何角色，必须指定 hotel_id (除非是创建 system)
      if (finalRole !== 'system' && !finalHotelId) {
        return sendError(res, errorResponse('创建非系统管理员用户必须指定酒店 ID', 400));
      }
    } else {
      return sendError(res, errorResponse('权限不足', 403));
    }

    // 检查用户名是否已存在
    const [existingUsers]: any = await db.execute(
      'SELECT * FROM users WHERE username = ?',
      [username]
    );

    if (existingUsers.length > 0) {
      return sendError(res, errorResponse('用户名已存在', 400));
    }

    const hashedPassword = await hashPassword(password);

    const [result]: any = await db.execute(
      'INSERT INTO users (username, password, email, phone, role, hotel_id) VALUES (?, ?, ?, ?, ?, ?)',
      [username, hashedPassword, email || null, phone || null, finalRole, finalHotelId || 0]
    );

    const userId = result.insertId;

    sendSuccess(res, { userId, username, role: finalRole, hotel_id: finalHotelId }, '用户创建成功');
  } catch (error) {
    console.error('创建用户失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

// 更新用户信息
export async function update(req: AuthRequest, res: Response) {
  try {
    const { id: userId } = req.params;
    const { email, phone, role, hotel_id, password } = req.body;
    const currentUser = req.user;

    if (!currentUser) {
      return sendError(res, errorResponse('未授权', 401));
    }

    // 检查被修改的用户是否存在
    const [users]: any = await db.execute(
      'SELECT * FROM users WHERE id = ?',
      [userId]
    );

    if (users.length === 0) {
      return sendError(res, errorResponse('用户不存在', 404));
    }

    const targetUser = users[0];

    // 权限检查
    let finalRole = role || targetUser.role;
    let finalHotelId = hotel_id || targetUser.hotel_id;

    if (currentUser.role === 'admin') {
      // Admin 只能修改自己门店的用户
      if (targetUser.hotel_id !== currentUser.hotel_id) {
        return sendError(res, errorResponse('无权修改其他门店的用户', 403));
      }
      // Admin 不能将用户修改为 system 角色
      if (finalRole === 'system') {
        return sendError(res, errorResponse('无权授予系统管理员角色', 403));
      }
      // Admin 不能修改 hotel_id
      finalHotelId = currentUser.hotel_id;
    } else if (currentUser.role === 'system') {
      // System 可以修改任何信息
    } else {
      return sendError(res, errorResponse('权限不足', 403));
    }

    // 更新用户基本信息
    let updateFields = ['email = ?', 'phone = ?', 'role = ?', 'hotel_id = ?', 'avatar = ?'];
    const params = [
      email || targetUser.email,
      phone || targetUser.phone,
      finalRole,
      finalHotelId,
      req.body.avatar || targetUser.avatar
    ];

    if (password) {
      updateFields.push('password = ?');
      const hashedPassword = await hashPassword(password);
      params.push(hashedPassword);
    }

    params.push(userId);
    const updateSql = `UPDATE users SET ${updateFields.join(', ')} WHERE id = ?`;
    await db.execute(updateSql, params);

    sendSuccess(res, { message: '用户信息更新成功' });
  } catch (error) {
    console.error('更新用户失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

// 删除用户
export async function remove(req: AuthRequest, res: Response) {
  try {
    const { id: userId } = req.params;

    // 检查用户是否存在
    const [users]: any = await db.execute(
      'SELECT * FROM users WHERE id = ?',
      [userId]
    );

    if (users.length === 0) {
      return sendError(res, errorResponse('用户不存在', 404));
    }

    // 不允许删除 admin 用户
    if (users[0].username === 'admin') {
      return sendError(res, errorResponse('不能删除管理员账户', 403));
    }

    await db.execute('DELETE FROM users WHERE id = ?', [userId]);

    sendSuccess(res, { message: '用户删除成功' });
  } catch (error) {
    console.error('删除用户失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

// 修改用户密码
export async function updatePassword(req: AuthRequest, res: Response) {
  try {
    const userId = req.params.id;
    const { oldPassword, newPassword } = req.body;

    if (!newPassword) {
      return sendError(res, errorResponse('新密码不能为空', 400));
    }

    const [users]: any = await db.execute(
      'SELECT * FROM users WHERE id = ?',
      [userId]
    );

    if (users.length === 0) {
      return sendError(res, errorResponse('用户不存在', 404));
    }

    // 如果是管理员修改其他用户密码，不需要验证旧密码
    if (req.user?.role !== 'admin' && oldPassword) {
      const isPasswordValid = await comparePassword(oldPassword, users[0].password);
      if (!isPasswordValid) {
        return sendError(res, errorResponse('原密码错误', 400));
      }
    }

    const hashedPassword = await hashPassword(newPassword);
    await db.execute(
      'UPDATE users SET password = ? WHERE id = ?',
      [hashedPassword, userId]
    );

    sendSuccess(res, { message: '密码修改成功' });
  } catch (error) {
    console.error('修改密码失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

// 用户自助更新个人资料
export async function updateProfile(req: AuthRequest, res: Response) {
  try {
    const userId = req.user?.id;
    const { username, email, phone, code, avatar } = req.body;

    if (!userId) {
      return sendError(res, errorResponse('未授权', 401));
    }

    // 构建更新字段
    const updateFields: string[] = [];
    const params: any[] = [];

    if (username) {
      updateFields.push('username = ?');
      params.push(username);
    }

    if (email !== undefined) {
      updateFields.push('email = ?');
      params.push(email || null);
    }

    if (avatar !== undefined) {
      updateFields.push('avatar = ?');
      params.push(avatar || null);
    }

    if (phone) {
      // 模拟验证码校验：简单校验验证码是否存在且为6位数字
      if (!code || !/^\d{6}$/.test(code)) {
        return sendError(res, errorResponse('验证码错误或已过期 (模拟环境：请输入任意6位数字)', 400));
      }

      // 检查手机号是否已被其他用户使用
      const [existing]: any = await db.execute(
        'SELECT id FROM users WHERE phone = ? AND id != ?',
        [phone, userId]
      );
      if (existing.length > 0) {
        return sendError(res, errorResponse('手机号已被占用', 400));
      }
      updateFields.push('phone = ?');
      params.push(phone);
    }

    if (updateFields.length === 0) {
      return sendError(res, errorResponse('没有提供更新内容', 400));
    }

    params.push(userId);
    const sql = `UPDATE users SET ${updateFields.join(', ')} WHERE id = ?`;

    await db.execute(sql, params);

    // 获取更新后的用户信息
    const [users]: any = await db.execute('SELECT id, username, email, phone, avatar, role, hotel_id FROM users WHERE id = ?', [userId]);

    sendSuccess(res, { user: users[0] }, '个人资料更新成功');
  } catch (error) {
    console.error('更新个人资料失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

// 模拟发送短信验证码
export async function sendVerificationCode(req: Request, res: Response) {
  try {
    const { phone } = req.body;
    if (!phone || !/^1[3-9]\d{9}$/.test(phone)) {
      return sendError(res, errorResponse('请输入正确的手机号', 400));
    }

    // 模拟发送成功
    console.log(`[Mock SMS] Sending verification code to ${phone}...`);
    
    // 这里的逻辑可以根据需要扩展，目前仅返回成功
    sendSuccess(res, { message: '验证码已发送 (模拟)' });
  } catch (error) {
    console.error('发送验证码失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

export default router;
