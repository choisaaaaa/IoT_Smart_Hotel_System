import { Router, Request, Response } from 'express';
import { AuthRequest } from '../types';
import { successResponse, errorResponse, sendSuccess, sendError } from '../types';
import { hashPassword, comparePassword } from '../utils/password';
import { normalizeRole, isSystemAdmin, isHotelAdmin, isStaff, isCustomer, CANONICAL_ROLES } from '../utils/role';
import db from '../config/database';
import { LoginSecurityService } from '../services/login-security.service';

const router = Router();

export async function list(req: AuthRequest, res: Response) {
  try {
    const { page = 1, limit = 10, role, keyword, hotel_id } = req.query;
    const currentUser = req.user;

    if (!currentUser) {
      return sendError(res, errorResponse('未授权', 401));
    }

    const p = Math.max(1, parseInt(page as string) || 1);
    const l = Math.max(1, parseInt(limit as string) || 10);
    const offset = (p - 1) * l;

    let sql = `SELECT u.id, u.username, u.phone, u.email, u.role, u.hotel_id, u.created_at,
                u.last_login_at, h.hotel_name
                FROM users u
                LEFT JOIN hotels h ON u.hotel_id = h.id`;

    let countSql = 'SELECT COUNT(*) as total FROM users u';

    const conditions: string[] = [];
    const params: any[] = [];

    const userRole = normalizeRole(currentUser.role);
    if (isHotelAdmin(userRole) || isStaff(userRole)) {
      conditions.push('u.hotel_id = ?');
      params.push(currentUser.hotel_id);
      conditions.push("u.role NOT IN ('customer', 'user', 'guest')");
      conditions.push('u.role != ?');
      params.push('system');
    } else if (isSystemAdmin(userRole)) {
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

    const [users]: any = await db.query(sql, [...params, l, offset]);
    const [countResult]: any = await db.query(countSql, params);

    const usersWithLockStatus = await Promise.all(
      users.map(async (user: any) => {
        const lockStatus = await LoginSecurityService.isLocked(user.phone);
        return {
          ...user,
          is_locked: lockStatus.isLocked
        };
      })
    );

    sendSuccess(res, {
      users: usersWithLockStatus,
      total: countResult[0].total,
      page: p,
      limit: l
    });
  } catch (error) {
    console.error('获取用户列表失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

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

    let finalHotelId = hotel_id;
    const finalRole = role || CANONICAL_ROLES.CUSTOMER;

    if (isHotelAdmin(currentUser.role)) {
      finalHotelId = currentUser.hotel_id;
      if (![CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.CUSTOMER].includes(finalRole)) {
        return sendError(res, errorResponse('酒店管理员只能创建门店管理员、员工或顾客', 403));
      }
    } else if (isSystemAdmin(currentUser.role)) {
      // 如果未显式指定 hotel_id，则尝试使用当前上下文中的 hotel_id
      finalHotelId = finalHotelId || currentUser.hotel_id;
      
      if (finalRole !== CANONICAL_ROLES.SYSTEM_ADMIN && !finalHotelId) {
        return sendError(res, errorResponse('创建非系统管理员用户必须指定酒店 ID', 400));
      }
    } else {
      return sendError(res, errorResponse('权限不足', 403));
    }

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

export async function update(req: AuthRequest, res: Response) {
  try {
    const { id: userId } = req.params;
    const { email, phone, role, hotel_id, password } = req.body;
    const currentUser = req.user;

    if (!currentUser) {
      return sendError(res, errorResponse('未授权', 401));
    }

    const [users]: any = await db.execute(
      'SELECT * FROM users WHERE id = ?',
      [userId]
    );

    if (users.length === 0) {
      return sendError(res, errorResponse('用户不存在', 404));
    }

    const targetUser = users[0];

    const finalRole = role || targetUser.role;
    let finalHotelId = hotel_id || targetUser.hotel_id;

    if (isHotelAdmin(currentUser.role)) {
      if (targetUser.hotel_id !== currentUser.hotel_id) {
        return sendError(res, errorResponse('无权修改其他门店的用户', 403));
      }
      if (finalRole === CANONICAL_ROLES.SYSTEM_ADMIN) {
        return sendError(res, errorResponse('无权授予系统管理员角色', 403));
      }
      finalHotelId = currentUser.hotel_id;
    } else if (isSystemAdmin(currentUser.role)) {
      // System 可以修改任何信息
    } else {
      return sendError(res, errorResponse('权限不足', 403));
    }

    const updateFields = ['email = ?', 'phone = ?', 'role = ?', 'hotel_id = ?', 'avatar = ?'];
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

export async function remove(req: AuthRequest, res: Response) {
  try {
    const { id: userId } = req.params;
    const currentUser = req.user;

    if (!currentUser) {
      return sendError(res, errorResponse('未授权', 401));
    }

    const [users]: any = await db.execute(
      'SELECT * FROM users WHERE id = ?',
      [userId]
    );

    if (users.length === 0) {
      return sendError(res, errorResponse('用户不存在', 404));
    }

    if (users[0].username === 'admin') {
      return sendError(res, errorResponse('不能删除管理员账户', 403));
    }

    if (isHotelAdmin(currentUser.role) && users[0].hotel_id !== currentUser.hotel_id) {
      return sendError(res, errorResponse('无权删除其他门店的用户', 403));
    }

    await db.execute('DELETE FROM users WHERE id = ?', [userId]);

    sendSuccess(res, { message: '用户删除成功' });
  } catch (error) {
    console.error('删除用户失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

export async function lock(req: AuthRequest, res: Response) {
  try {
    const { id: userId } = req.params;
    const currentUser = req.user;

    if (!currentUser) {
      return sendError(res, errorResponse('未授权', 401));
    }

    if (!isSystemAdmin(currentUser.role)) {
      return sendError(res, errorResponse('只有系统管理员可以锁定用户', 403));
    }

    const [users]: any = await db.execute(
      'SELECT * FROM users WHERE id = ?',
      [userId]
    );

    if (users.length === 0) {
      return sendError(res, errorResponse('用户不存在', 404));
    }

    const targetUser = users[0];

    if (targetUser.username === 'admin') {
      return sendError(res, errorResponse('不能锁定管理员账户', 403));
    }

    await LoginSecurityService.lockAccount(targetUser.phone);

    sendSuccess(res, { message: '用户已锁定' });
  } catch (error) {
    console.error('锁定用户失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

export async function unlock(req: AuthRequest, res: Response) {
  try {
    const { id: userId } = req.params;
    const currentUser = req.user;

    if (!currentUser) {
      return sendError(res, errorResponse('未授权', 401));
    }

    if (!isSystemAdmin(currentUser.role) && !isHotelAdmin(currentUser.role)) {
      return sendError(res, errorResponse('只有管理员可以解锁用户', 403));
    }

    const [users]: any = await db.execute(
      'SELECT * FROM users WHERE id = ?',
      [userId]
    );

    if (users.length === 0) {
      return sendError(res, errorResponse('用户不存在', 404));
    }

    const targetUser = users[0];

    await LoginSecurityService.unlockAccount(targetUser.phone);

    sendSuccess(res, { message: '用户已解锁' });
  } catch (error) {
    console.error('解锁用户失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

export async function authorizeManager(req: AuthRequest, res: Response) {
  try {
    const { manager_id, password } = req.body;
    const currentUser = req.user;

    if (!currentUser) {
      return sendError(res, errorResponse('未授权', 401));
    }

    if (!manager_id || !password) {
      return sendError(res, errorResponse('经理ID和密码不能为空', 400));
    }

    const [users]: any = await db.execute(
      'SELECT * FROM users WHERE id = ?',
      [manager_id]
    );

    if (users.length === 0) {
      return sendError(res, errorResponse('经理用户不存在', 404));
    }

    const manager = users[0];
    const role = normalizeRole(manager.role);

    // 只有门店管理员或系统管理员才能授权
    if (!isHotelAdmin(role) && !isSystemAdmin(role)) {
      return sendError(res, errorResponse('该用户没有授权权限', 403));
    }

    // 如果是门店管理员，必须属于同一门店
    if (isHotelAdmin(role) && manager.hotel_id !== currentUser.hotel_id) {
      return sendError(res, errorResponse('无权为该门店授权', 403));
    }

    const isPasswordCorrect = await comparePassword(password, manager.password);
    if (!isPasswordCorrect) {
      return sendError(res, errorResponse('密码错误', 401));
    }

    sendSuccess(res, { message: '授权成功' });
  } catch (error) {
    console.error('经理授权失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

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

    if (!isHotelAdmin(req.user?.role) && !isSystemAdmin(req.user?.role) && oldPassword) {
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

export async function updateProfile(req: AuthRequest, res: Response) {
  try {
    const userId = req.user?.id;
    const { username, email, phone, code, avatar } = req.body;

    if (!userId) {
      return sendError(res, errorResponse('未授权', 401));
    }

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
      if (!code || !/^\d{6}$/.test(code)) {
        return sendError(res, errorResponse('验证码错误或已过期 (模拟环境：请输入任意6位数字)', 400));
      }

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

    const [users]: any = await db.execute('SELECT id, username, email, phone, avatar, role, hotel_id FROM users WHERE id = ?', [userId]);

    sendSuccess(res, { user: users[0] }, '个人资料更新成功');
  } catch (error) {
    console.error('更新个人资料失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

export async function sendVerificationCode(req: Request, res: Response) {
  try {
    const { phone } = req.body;
    if (!phone || !/^1[3-9]\d{9}$/.test(phone)) {
      return sendError(res, errorResponse('请输入正确的手机号', 400));
    }

    console.log(`[Mock SMS] Sending verification code to ${phone}...`);
    
    sendSuccess(res, { message: '验证码已发送 (模拟)' });
  } catch (error) {
    console.error('发送验证码失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

export default router;
