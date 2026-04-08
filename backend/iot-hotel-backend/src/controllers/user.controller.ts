import { Router, Response } from 'express';
import { AuthRequest } from '../types';
import { successResponse, errorResponse, sendSuccess, sendError } from '../types';
import { hashPassword, comparePassword } from '../utils/password';

const router = Router();

// 获取用户列表 (管理员权限)
export async function list(req: AuthRequest, res: Response) {
  try {
    const db = require('../config/database');
    const { page = 1, limit = 10, role, keyword } = req.query;
    
    const offset = (Number(page) - 1) * Number(limit);
    
    let sql = `SELECT u.id, u.username, u.email, u.role, u.created_at,
                GROUP_CONCAT(r.role_name) as roles
                FROM users u
                LEFT JOIN user_roles ur ON u.id = ur.user_id
                LEFT JOIN roles r ON ur.role_id = r.id`;
    
    let countSql = 'SELECT COUNT(*) as total FROM users u';
    
    const conditions: string[] = [];
    const params: any[] = [];
    
    if (keyword) {
      conditions.push('(u.username LIKE ? OR u.email LIKE ?)');
      params.push(`%${keyword}%`, `%${keyword}%`);
    }
    
    if (role) {
      conditions.push('r.role_name = ?');
      params.push(role);
    }
    
    if (conditions.length > 0) {
      sql += ' WHERE ' + conditions.join(' AND ');
      countSql += ' LEFT JOIN user_roles ur ON u.id = ur.user_id LEFT JOIN roles r ON ur.role_id = r.id WHERE ' + conditions.join(' AND ');
    }
    
    sql += ' GROUP BY u.id ORDER BY u.created_at DESC LIMIT ? OFFSET ?';
    params.push(Number(limit), offset);
    
    const [users]: any = await db.execute(sql, params);
    const [countResult]: any = await db.execute(countSql, params.slice(0, -2));
    
    sendSuccess(res, {
      users,
      total: countResult[0].total,
      page: Number(page),
      limit: Number(limit)
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
    const db = require('../config/database');
    
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
    const { username, password, email, role } = req.body;
    
    if (!username || !password) {
      return sendError(res, errorResponse('用户名和密码不能为空', 400));
    }
    
    const db = require('../config/database');
    
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
      'INSERT INTO users (username, password, email, role) VALUES (?, ?, ?, ?)',
      [username, hashedPassword, email || null, role || 'user']
    );
    
    const userId = result.insertId;
    
    // 关联角色
    if (role) {
      const [userRole]: any = await db.execute(
        'SELECT id FROM roles WHERE role_name = ?',
        [role]
      );
      
      if (userRole.length > 0) {
        await db.execute(
          'INSERT INTO user_roles (user_id, role_id) VALUES (?, ?)',
          [userId, userRole[0].id]
        );
      }
    }
    
    sendSuccess(res, { userId, username, role: role || 'user' }, '用户创建成功');
  } catch (error) {
    console.error('创建用户失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

// 更新用户信息
export async function update(req: AuthRequest, res: Response) {
  try {
    const userId = req.params.id;
    const { email, role } = req.body;
    const db = require('../config/database');
    
    // 检查用户是否存在
    const [users]: any = await db.execute(
      'SELECT * FROM users WHERE id = ?',
      [userId]
    );
    
    if (users.length === 0) {
      return sendError(res, errorResponse('用户不存在', 404));
    }
    
    // 更新用户基本信息
    await db.execute(
      'UPDATE users SET email = ? WHERE id = ?',
      [email || null, userId]
    );
    
    // 更新角色
    if (role) {
      const [userRole]: any = await db.execute(
        'SELECT id FROM roles WHERE role_name = ?',
        [role]
      );
      
      if (userRole.length > 0) {
        await db.execute(
          'DELETE FROM user_roles WHERE user_id = ?',
          [userId]
        );
        
        await db.execute(
          'INSERT INTO user_roles (user_id, role_id) VALUES (?, ?)',
          [userId, userRole[0].id]
        );
        
        // 更新 users 表的 role 字段 (向后兼容)
        await db.execute(
          'UPDATE users SET role = ? WHERE id = ?',
          [role, userId]
        );
      }
    }
    
    sendSuccess(res, { message: '用户信息更新成功' });
  } catch (error) {
    console.error('更新用户失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

// 删除用户
export async function remove(req: AuthRequest, res: Response) {
  try {
    const userId = req.params.id;
    const db = require('../config/database');
    
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
    const db = require('../config/database');
    
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
