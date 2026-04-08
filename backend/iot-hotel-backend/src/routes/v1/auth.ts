import { Router } from 'express';
import { AuthRequest } from '../../types';
import { hashPassword, comparePassword } from '../../utils/password';
import { generateToken, verifyToken, JwtPayload } from '../../utils/jwt';
import { successResponse, errorResponse, sendSuccess, sendError } from '../../types';
import crypto from 'crypto';
import db from '../../config/database';

const router = Router();

// 生成 API Token (用于扫码登录)
router.post('/generate-token', async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return sendError(res, errorResponse('用户名和密码不能为空', 400));
    }

    const [users]: any = await db.execute(
      'SELECT * FROM users WHERE username = ?',
      [username]
    );

    if (users.length === 0) {
      console.log(`Login failed: user ${username} not found`);
      return sendError(res, errorResponse('用户名或密码错误', 401));
    }

    const user = users[0];
    const isPasswordValid = await comparePassword(password, user.password);

    if (!isPasswordValid) {
      console.log(`Login failed: password mismatch for user ${username}`);
      return sendError(res, errorResponse('用户名或密码错误', 401));
    }

    // 生成一次性 Token，5 分钟过期
    const token = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 分钟

    await db.execute(
      `INSERT INTO api_tokens (user_id, token, token_type, expires_at) 
       VALUES (?, ?, 'login', ?)`,
      [user.id, token, expiresAt]
    );

    sendSuccess(res, {
      token,
      expiresAt,
      message: 'Token 生成成功，请在 5 分钟内使用'
    });
  } catch (error) {
    console.error('生成 Token 失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
});

// 扫码登录 - 使用 API Token 登录
router.post('/scan-login', async (req, res) => {
  try {
    const { token } = req.body;

    if (!token) {
      return sendError(res, errorResponse('Token 不能为空', 400));
    }

    // 查询并验证 Token
    const [tokens]: any = await db.execute(
      `SELECT at.*, u.username, u.role, u.permissions, u.email, u.hotel_id
       FROM api_tokens at
       JOIN users u ON at.user_id = u.id
       WHERE at.token = ? AND at.is_used = 0 AND at.expires_at > NOW()`,
      [token]
    );

    if (tokens.length === 0) {
      return sendError(res, errorResponse('Token 无效或已过期', 401));
    }

    const tokenData = tokens[0];

    const parsePermissions = (p: any) => {
      if (!p) return [];
      if (Array.isArray(p)) return p;
      if (typeof p === 'string') {
        try {
          return JSON.parse(p);
        } catch (e) {
          return p.split(',').map((s: string) => s.trim());
        }
      }
      return [];
    };

    // 获取用户信息
    const [users]: any = await db.execute(
      `SELECT u.*, h.hotel_name 
       FROM users u 
       LEFT JOIN hotels h ON u.hotel_id = h.id 
       WHERE u.id = ?`,
      [tokenData.user_id]
    );

    if (users.length === 0) {
      return sendError(res, errorResponse('用户不存在', 404));
    }

    const user = users[0];

    // 生成 JWT
    const jwtPayload: JwtPayload = {
      id: user.id,
      username: user.username,
      role: user.role,
      hotel_id: user.hotel_id,
      permissions: [] // 后续可以加上
    };

    const jwtToken = generateToken(jwtPayload);

    // 标记 Token 为已使用
    await db.execute(
      'UPDATE api_tokens SET is_used = 1, used_at = NOW() WHERE id = ?',
      [tokenData.id]
    );

    // 创建登录会话
    const sessionToken = crypto.randomBytes(32).toString('hex');
    const sessionExpiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 小时

    await db.execute(
      `INSERT INTO login_sessions (user_id, session_token, expires_at)
       VALUES (?, ?, ?)`,
      [user.id, sessionToken, sessionExpiresAt]
    );

    sendSuccess(res, {
      token: jwtToken,
      sessionToken,
      user: {
        id: user.id,
        username: user.username,
        role: user.role,
        permissions: [],
        email: user.email,
        hotel_id: user.hotel_id,
        hotel_name: user.hotel_name
      },
      message: '登录成功'
    });
  } catch (error) {
    console.error('扫码登录失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
});

// 用户名密码登录
router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return sendError(res, errorResponse('用户名和密码不能为空', 400));
    }

    // 获取用户信息
    const [users]: any = await db.execute(
      `SELECT u.*, h.hotel_name 
       FROM users u 
       LEFT JOIN hotels h ON u.hotel_id = h.id 
       WHERE u.username = ?`,
      [username]
    );

    if (users.length === 0) {
      return sendError(res, errorResponse('用户名或密码错误', 401));
    }

    const user = users[0];
    const isPasswordValid = await comparePassword(password, user.password);

    if (!isPasswordValid) {
      return sendError(res, errorResponse('用户名或密码错误', 401));
    }

    // 获取用户角色和权限
    const [userRoles]: any = await db.execute(
      `SELECT r.role_name, r.permissions 
       FROM user_roles ur
       JOIN roles r ON ur.role_id = r.id
       WHERE ur.user_id = ?`,
      [user.id]
    );

    const parsePermissions = (p: any) => {
      if (!p) return [];
      if (Array.isArray(p)) return p;
      if (typeof p === 'string') {
        try {
          return JSON.parse(p);
        } catch (e) {
          return p.split(',').map((s: string) => s.trim());
        }
      }
      return [];
    };

    const role = userRoles.length > 0 ? userRoles[0].role_name : user.role;
    const permissions = userRoles.length > 0 
      ? parsePermissions(userRoles[0].permissions) 
      : parsePermissions(user.permissions);

    // 生成 JWT
    const jwtPayload: JwtPayload = {
      id: user.id,
      username: user.username,
      role,
      hotel_id: user.hotel_id,
      permissions
    };

    const jwtToken = generateToken(jwtPayload);

    // 创建登录会话
    const sessionToken = crypto.randomBytes(32).toString('hex');
    const sessionExpiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 小时
    const deviceInfo = req.headers['user-agent'] || 'Unknown';
    const ipAddress = req.ip || req.socket.remoteAddress || 'Unknown';

    await db.execute(
      `INSERT INTO login_sessions (user_id, session_token, device_info, ip_address, expires_at)
       VALUES (?, ?, ?, ?, ?)`,
      [user.id, sessionToken, deviceInfo, ipAddress, sessionExpiresAt]
    );

    sendSuccess(res, {
      token: jwtToken,
      sessionToken,
      user: {
        id: user.id,
        username: user.username,
        role,
        permissions,
        email: user.email,
        hotel_id: user.hotel_id,
        hotel_name: user.hotel_name
      },
      message: '登录成功'
    });
  } catch (error) {
    console.error('登录失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
});

// 用户注册
router.post('/register', async (req, res) => {
  try {
    const { username, password, email, hotel_id } = req.body;

    if (!username || !password || !hotel_id) {
      return sendError(res, errorResponse('用户名、密码和酒店ID不能为空', 400));
    }

    // 检查用户名是否已存在
    const [existingUsers]: any = await db.execute(
      'SELECT * FROM users WHERE username = ?',
      [username]
    );

    if (existingUsers.length > 0) {
      return sendError(res, errorResponse('用户名已存在', 400));
    }

    // 加密密码
    const hashedPassword = await hashPassword(password);

    // 创建用户 (默认为 user 角色)
    const [result]: any = await db.execute(
      `INSERT INTO users (username, password, email, role, hotel_id) 
       VALUES (?, ?, ?, 'user', ?)`,
      [username, hashedPassword, email || null, hotel_id]
    );

    const userId = result.insertId;

    // 关联 user 角色
    const [userRole]: any = await db.execute(
      'SELECT id FROM roles WHERE role_name = ?',
      ['user']
    );

    if (userRole.length > 0) {
      await db.execute(
        'INSERT INTO user_roles (user_id, role_id) VALUES (?, ?)',
        [userId, userRole[0].id]
      );
    }

    sendSuccess(res, {
      userId,
      username,
      role: 'user',
      message: '注册成功'
    });
  } catch (error) {
    console.error('注册失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
});

// 登出
router.post('/logout', async (req: AuthRequest, res) => {
  try {
    const sessionToken = req.headers.authorization?.replace('Bearer ', '');
    
    if (sessionToken) {
      await db.execute(
        'DELETE FROM login_sessions WHERE session_token = ?',
        [sessionToken]
      );
    }

    sendSuccess(res, { message: '登出成功' });
  } catch (error) {
    console.error('登出失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
});

// 获取当前用户信息
router.get('/me', async (req: AuthRequest, res) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader) {
      return sendError(res, errorResponse('未提供认证令牌', 401));
    }

    const token = authHeader.replace('Bearer ', '');
    const decoded = verifyToken(token);

    if (!decoded) {
      return sendError(res, errorResponse('令牌无效', 401));
    }

    const [users]: any = await db.execute(
      'SELECT id, username, email, role, created_at FROM users WHERE id = ?',
      [decoded.id]
    );

    if (users.length === 0) {
      return sendError(res, errorResponse('用户不存在', 404));
    }

    sendSuccess(res, {
      user: users[0],
      role: decoded.role,
      permissions: decoded.permissions
    });
  } catch (error) {
    console.error('获取用户信息失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
});

export default router;
