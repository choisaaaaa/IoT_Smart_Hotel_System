import { Router, Response } from 'express';
import { AuthRequest } from '../types';
import { successResponse, errorResponse, sendSuccess, sendError } from '../types';
import { hashPassword, comparePassword } from '../utils/password';
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
    
    let sql = `SELECT u.id, u.username, u.email, u.role, u.hotel_id, u.created_at,
                h.hotel_name
                FROM users u
                LEFT JOIN hotels h ON u.hotel_id = h.id`;
    
    let countSql = 'SELECT COUNT(*) as total FROM users u';
    
    const conditions: string[] = [];
    const params: any[] = [];
    
    // 权限过滤逻辑
    if (currentUser.role === 'admin' || currentUser.role === 'staff') {
      // Admin 和 Staff 只能看到自己门店的用户
      conditions.push('u.hotel_id = ?');
      params.push(currentUser.hotel_id);
      // 不能看到 system 用户
      conditions.push('u.role != ?');
      params.push('system');
    } else if (currentUser.role === 'system') {
      // System 可以看到所有用户，也可以按门店过滤
      if (hotel_id && hotel_id !== 'undefined') {
        conditions.push('u.hotel_id = ?');
        params.push(hotel_id);
      }
    } else {
      return sendError(res, errorResponse('权限不足', 403));
    }

    if (keyword) {
      conditions.push('(u.username LIKE ? OR u.email LIKE ?)');
      params.push(`%${keyword}%`, `%${keyword}%`);
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
    const { username, password, email, role, hotel_id } = req.body;
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
      'INSERT INTO users (username, password, email, role, hotel_id) VALUES (?, ?, ?, ?, ?)',
      [username, hashedPassword, email || null, finalRole, finalHotelId || 0]
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
    const { email, role, hotel_id, password } = req.body;
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
    let updateSql = 'UPDATE users SET email = ?, role = ?, hotel_id = ?';
    const params = [email || targetUser.email, finalRole, finalHotelId, userId];

    if (password) {
      const hashedPassword = await hashPassword(password);
      updateSql += ', password = ?';
      params.splice(3, 0, hashedPassword);
    }

    updateSql += ' WHERE id = ?';
    
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

export default router;
