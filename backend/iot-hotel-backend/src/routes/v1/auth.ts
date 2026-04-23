import { Router } from 'express';
import { AuthRequest } from '../../types';
import { hashPassword, comparePassword } from '../../utils/password';
import { generateToken, verifyToken, JwtPayload } from '../../utils/jwt';
import { successResponse, errorResponse, sendSuccess, sendError } from '../../types';
import { authenticate } from '../../middleware/auth';
import crypto from 'crypto';
import db from '../../config/database';
import logger from '../../utils/logger';
import { normalizeRole, isSystemAdmin, isHotelAdmin, isCustomer, isGuest, CANONICAL_ROLES } from '../../utils/role';

const router = Router();

/**
 * @swagger
 * tags:
 *   name: Auth
 *   description: 用户认证与扫码登录接口
 */

/**
 * @swagger
 * /auth/qr-generate:
 *   post:
 *     summary: 生成扫码登录二维码Token
 *     tags: [Auth]
 *     responses:
 *       200:
 *         description: 成功生成Token
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 code:
 *                   type: integer
 *                   example: 200
 *                 data:
 *                   type: object
 *                   properties:
 *                     token:
 *                       type: string
 *                     expiresAt:
 *                       type: string
 *                       format: date-time
 */
router.post('/qr-generate', async (req, res) => {
  try {
    const token = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000);

    await db.execute(
      `INSERT INTO api_tokens (user_id, token, token_type, status, expires_at)
       VALUES (NULL, ?, 'qr_login', 'pending', ?)`,
      [token, expiresAt]
    );

    sendSuccess(res, { token, expiresAt });
  } catch (error) {
    console.error('生成扫码Token失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
});

// APP确认扫码（需要APP的JWT认证）
router.post('/qr-confirm', authenticate as any, async (req: AuthRequest, res) => {
  try {
    const user = req.user;
    if (!user) {
      return sendError(res, errorResponse('未认证', 401));
    }

    const { token } = req.body;
    if (!token) {
      return sendError(res, errorResponse('Token不能为空', 400));
    }

    const [tokens]: any = await db.execute(
      `SELECT * FROM api_tokens WHERE token = ? AND token_type = 'qr_login' AND status = 'pending' AND expires_at > NOW()`,
      [token]
    );

    if (tokens.length === 0) {
      return sendError(res, errorResponse('二维码无效或已过期', 401));
    }

    const tokenData = tokens[0];

    await db.execute(
      `UPDATE api_tokens SET user_id = ?, status = 'confirmed' WHERE id = ?`,
      [user.id, tokenData.id]
    );

    sendSuccess(res, { message: '扫码确认成功' });
  } catch (error) {
    console.error('扫码确认失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
});

/**
 * @swagger
 * /auth/qr-status:
 *   get:
 *     summary: Web端轮询扫码状态
 *     tags: [Auth]
 *     parameters:
 *       - in: query
 *         name: token
 *         required: true
 *         schema:
 *           type: string
 *         description: 扫码Token
 *     responses:
 *       200:
 *         description: 扫码状态
 */
router.get('/qr-status', async (req, res) => {
  try {
    const { token } = req.query;

    if (!token) {
      return sendError(res, errorResponse('Token不能为空', 400));
    }

    const [tokens]: any = await db.execute(
      `SELECT * FROM api_tokens WHERE token = ? AND token_type = 'qr_login'`,
      [token]
    );

    if (tokens.length === 0) {
      return sendError(res, errorResponse('Token无效', 401));
    }

    const tokenData = tokens[0];

    if (tokenData.expires_at < new Date()) {
      return sendSuccess(res, { status: 'expired' });
    }

    if (tokenData.status !== 'confirmed') {
      return sendSuccess(res, { status: 'pending' });
    }

    const [users]: any = await db.execute(
      `SELECT u.*, h.hotel_name FROM users u LEFT JOIN hotels h ON u.hotel_id = h.id WHERE u.id = ?`,
      [tokenData.user_id]
    );

    if (users.length === 0) {
      return sendError(res, errorResponse('用户不存在', 404));
    }

    const user = users[0];
    const role = normalizeRole(user.role);

    const parsePermissions = (p: any) => {
      if (!p) return [];
      if (Array.isArray(p)) return p;
      if (typeof p === 'string') {
        try { return JSON.parse(p); } catch (e) { return p.split(',').map((s: string) => s.trim()); }
      }
      return [];
    };

    const [userRoles]: any = await db.execute(
      `SELECT r.permissions FROM user_roles ur JOIN roles r ON ur.role_id = r.id WHERE ur.user_id = ?`,
      [user.id]
    );
    const permissions = userRoles.length > 0 ? parsePermissions(userRoles[0].permissions) : parsePermissions(user.permissions);

    const jwtPayload: JwtPayload = {
      id: user.id,
      username: user.username,
      phone: user.phone,
      role,
      hotel_id: user.hotel_id,
      permissions
    };

    const jwtToken = generateToken(jwtPayload);
    logger.info(`[Auth] User logged in via QR Status: ${user.username}, Role: ${role}, Token generated`);

    await db.execute(
      `UPDATE api_tokens SET is_used = 1, status = 'used', used_at = NOW() WHERE id = ?`,
      [tokenData.id]
    );

    const sessionToken = crypto.randomBytes(32).toString('hex');
    const sessionExpiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);
    const deviceInfo = 'QR Scan Login';
    const ipAddress = req.ip || req.socket.remoteAddress || 'Unknown';

    await db.execute(
      `INSERT INTO login_sessions (user_id, session_token, device_info, ip_address, expires_at) VALUES (?, ?, ?, ?, ?)`,
      [user.id, sessionToken, deviceInfo, ipAddress, sessionExpiresAt]
    );

    sendSuccess(res, {
      status: 'confirmed',
      token: jwtToken,
      sessionToken,
      user: {
        id: user.id,
        username: user.username,
        role,
        permissions,
        email: user.email,
        phone: user.phone,
        avatar: user.avatar,
        hotel_id: user.hotel_id,
        hotel_name: user.hotel_name
      }
    });
  } catch (error) {
    console.error('查询扫码状态失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
});

// 生成 API Token (用于扫码登录)
router.post('/generate-token', async (req, res) => {
  try {
    const { phone, password } = req.body;

    if (!phone || !password) {
      return sendError(res, errorResponse('手机号和密码不能为空', 400));
    }

    const [users]: any = await db.execute(
      'SELECT * FROM users WHERE phone = ?',
      [phone]
    );

    if (users.length === 0) {
      console.log(`Login failed: user ${phone} not found`);
      return sendError(res, errorResponse('手机号或密码错误', 401));
    }

    const user = users[0];
    const isPasswordValid = await comparePassword(password, user.password);

    if (!isPasswordValid) {
      console.log(`Login failed: password mismatch for user ${phone}`);
      return sendError(res, errorResponse('手机号或密码错误', 401));
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
      if (!p) {return [];}
      if (Array.isArray(p)) {return p;}
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
    const role = normalizeRole(user.role);
    const jwtPayload: JwtPayload = {
      id: user.id,
      username: user.username,
      phone: user.phone,
      role,
      hotel_id: user.hotel_id,
      permissions: [] // 后续可以加上
    };

    const jwtToken = generateToken(jwtPayload);
    logger.info(`[Auth] User logged in via QR/Token: ${user.username}, Role: ${role}, Token generated`);

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
        role,
        permissions: [],
        email: user.email,
        phone: user.phone,
        avatar: user.avatar,
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

/**
 * @swagger
 * /auth/login:
 *   post:
 *     summary: 手机号密码登录
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - phone
 *               - password
 *             properties:
 *               phone:
 *                 type: string
 *                 example: "13800138000"
 *               password:
 *                 type: string
 *                 format: password
 *                 example: "123456"
 *     responses:
 *       200:
 *         description: 登录成功
 */
router.post('/login', async (req, res) => {
  try {
    const { phone, password } = req.body;

    if (!phone || !password) {
      return sendError(res, errorResponse('手机号和密码不能为空', 400));
    }

    // 检查账户是否被锁定
    const { LoginSecurityService } = await import('../../services/login-security.service');
    const lockStatus = await LoginSecurityService.isLocked(phone);
    
    if (lockStatus.isLocked) {
      const remainingMinutes = Math.ceil(((lockStatus.lockedUntil!.getTime()) - Date.now()) / 60000);
      logger.warn(`[Auth] 登录被拒绝 - 账户已锁定: ${phone}, 剩余时间: ${remainingMinutes}分钟`);
      return sendError(res, errorResponse(
        `账户已被锁定，请在 ${remainingMinutes} 分钟后再试`,
        429
      ));
    }

    // 获取用户信息
    const [users]: any = await db.execute(
      `SELECT u.*, h.hotel_name
       FROM users u
       LEFT JOIN hotels h ON u.hotel_id = h.id
       WHERE u.phone = ?`,
      [phone]
    );

    if (users.length === 0) {
      // 即使用户不存在也记录失败，防止枚举攻击
      await LoginSecurityService.recordFailedLogin(phone);
      return sendError(res, errorResponse('手机号或密码错误', 401));
    }

    const user = users[0];
    const isPasswordValid = await comparePassword(password, user.password);

    if (!isPasswordValid) {
      // 记录登录失败
      const failResult = await LoginSecurityService.recordFailedLogin(phone);

      if (failResult.isLocked) {
        const lockMinutes = LoginSecurityService.calculateLockoutMinutes(failResult.attempts);
        logger.warn(`[Auth] 账户 ${phone} 因连续登录失败被锁定至 ${failResult.lockedUntil?.toISOString()}`);
        return sendError(res, errorResponse(
          `密码错误，账户已被锁定 ${lockMinutes} 分钟`,
          429
        ));
      }

      // 计算剩余警告次数和锁定时间
      const config = LoginSecurityService.getConfig();
      let warningMessage = '';

      if (failResult.warningAttempts > 0 && failResult.warningAttempts <= config.incrementFailedCount) {
        // 在5次错误范围内，显示警告消息
        warningMessage = `，错误 ${failResult.attempts} 次后将被禁止登录 ${config.initialLockoutMinutes} 分钟`;
      }

      logger.warn(`[Auth] 密码错误 - 账户: ${phone}, 剩余尝试次数: ${failResult.remainingAttempts}`);
      return sendError(res, errorResponse(
        `手机号或密码错误${warningMessage}`,
        401
      ));
    }

    // 登录成功，重置失败计数
    await LoginSecurityService.resetFailedLogin(phone);

    // 更新最后登录时间
    await db.execute(
      'UPDATE users SET last_login_at = NOW() WHERE id = ?',
      [user.id]
    );

    // 获取用户角色和权限
    const [userRoles]: any = await db.execute(
      `SELECT r.role_name, r.permissions
       FROM user_roles ur
       JOIN roles r ON ur.role_id = r.id
       WHERE ur.user_id = ?`,
      [user.id]
    );

    const parsePermissions = (p: any) => {
      if (!p) {return [];}
      if (Array.isArray(p)) {return p;}
      if (typeof p === 'string') {
        try {
          return JSON.parse(p);
        } catch (e) {
          return p.split(',').map((s: string) => s.trim());
        }
      }
      return [];
    };

    const isSystemAccount = normalizeRole(user.role) === CANONICAL_ROLES.SYSTEM_ADMIN;
    const role = isSystemAccount
      ? CANONICAL_ROLES.SYSTEM_ADMIN
      : normalizeRole(userRoles.length > 0 ? userRoles[0].role_name : user.role);
    const permissions = userRoles.length > 0
      ? parsePermissions(userRoles[0].permissions)
      : parsePermissions(user.permissions);

    // 生成 JWT
    const jwtPayload: JwtPayload = {
      id: user.id,
      username: user.username,
      phone: user.phone,
      role,
      hotel_id: user.hotel_id,
      permissions
    };

    const jwtToken = generateToken(jwtPayload);
    logger.info(`[Auth] User logged in: ${user.username}, Role: ${role}, UserID: ${user.id}`);

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
        phone: user.phone,
        avatar: user.avatar,
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
    const { username, password, phone, email, role, hotel_id } = req.body;

    if (!phone || !password) {
      return sendError(res, errorResponse('手机号和密码不能为空', 400));
    }

    if (!username) {
      return sendError(res, errorResponse('姓名不能为空', 400));
    }

    const phoneRegex = /^1[3-9]\d{9}$/;
    if (!phoneRegex.test(phone)) {
      return sendError(res, errorResponse('请输入11位手机号', 400));
    }

    const [existingPhones]: any = await db.execute(
      'SELECT * FROM users WHERE phone = ?',
      [phone]
    );

    if (existingPhones.length > 0) {
      return sendError(res, errorResponse('该手机号已注册', 400));
    }

    const hashedPassword = await hashPassword(password);

    let targetHotelId = hotel_id;
    if (!targetHotelId) {
      const [hotels]: any = await db.execute('SELECT id FROM hotels LIMIT 1');
      if (hotels.length > 0) {
        targetHotelId = hotels[0].id;
      }
    }

    const uid = `UID${Date.now()}${Math.random().toString(36).slice(2, 8).toUpperCase()}`;

    const userRole = CANONICAL_ROLES.CUSTOMER;

    const [result]: any = await db.execute(
      `INSERT INTO users (username, password, phone, uid, email, role, hotel_id)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [username, hashedPassword, phone, uid, email || null, userRole, targetHotelId || null]
    );

    const userId = result.insertId;

    const [roleRows]: any = await db.execute(
      'SELECT id FROM roles WHERE role_name = ?',
      [userRole]
    );

    if (roleRows.length > 0) {
      await db.execute(
        'INSERT INTO user_roles (user_id, role_id) VALUES (?, ?)',
        [userId, roleRows[0].id]
      );
    }

    sendSuccess(res, {
      userId,
      username,
      uid,
      role: userRole,
      phone,
      message: '注册成功'
    });
  } catch (error) {
    console.error('注册失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
});

// 发送密码重置验证码
router.post('/reset-password/send-code', async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone) {
      return sendError(res, errorResponse('手机号不能为空', 400));
    }

    // 检查手机号是否已注册
    const [users]: any = await db.execute(
      'SELECT id FROM users WHERE phone = ?',
      [phone]
    );

    if (users.length === 0) {
      return sendError(res, errorResponse('该手机号未注册', 404));
    }

    // 导入短信验证服务
    const smsService = await import('../../services/sms-verification.service');
    const result = await smsService.default.generateAndSendCode(phone, 'password_reset');

    if (result.success) {
      sendSuccess(res, { message: result.message });
    } else {
      sendError(res, errorResponse(result.message, 400));
    }
  } catch (error) {
    console.error('发送验证码失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
});

// 手机号找回密码（需要短信验证）
router.post('/reset-password', async (req, res) => {
  try {
    const { phone, new_password, verification_code } = req.body;

    if (!phone || !new_password || !verification_code) {
      return sendError(res, errorResponse('手机号、新密码和验证码不能为空', 400));
    }

    if (new_password.length < 6) {
      return sendError(res, errorResponse('密码长度不能少于6位', 400));
    }

    // 验证短信验证码
    const smsService = await import('../../services/sms-verification.service');
    const verifyResult = await smsService.default.verifyCode(phone, verification_code, 'password_reset');

    if (!verifyResult.success) {
      return sendError(res, errorResponse(verifyResult.message, 400));
    }

    // 检查手机号是否已注册
    const [users]: any = await db.execute(
      'SELECT * FROM users WHERE phone = ?',
      [phone]
    );

    if (users.length === 0) {
      return sendError(res, errorResponse('该手机号未注册', 404));
    }

    // 检查新密码是否与旧密码相同
    const user = users[0];
    const isSamePassword = await comparePassword(new_password, user.password);
    if (isSamePassword) {
      return sendError(res, errorResponse('新密码不能与旧密码相同', 400));
    }

    const hashedPassword = await hashPassword(new_password);

    await db.execute(
      'UPDATE users SET password = ? WHERE phone = ?',
      [hashedPassword, phone]
    );

    // 记录密码重置日志
    logger.info(`用户密码重置成功: ${phone}`);

    sendSuccess(res, { message: '密码重置成功' });
  } catch (error) {
    console.error('密码重置失败:', error);
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

    const token = authHeader.replace(/Bearer /i, '').trim();
    const decoded = verifyToken(token);

    if (!decoded) {
      return sendError(res, errorResponse('令牌无效', 401));
    }

    const [users]: any = await db.execute(
      `SELECT id, username, email, role, phone, uid, avatar, hotel_id, created_at FROM users WHERE id = ?`,
      [decoded.id]
    );

    if (users.length === 0) {
      return sendError(res, errorResponse('用户不存在', 404));
    }

    const normalizedRole = normalizeRole(decoded.role);

    const [hotelRows]: any = await db.execute(
      'SELECT h.id, h.hotel_name FROM user_hotels uh JOIN hotels h ON uh.hotel_id = h.id WHERE uh.user_id = ?',
      [decoded.id]
    );

    sendSuccess(res, {
      user: {
        ...users[0],
        role: normalizedRole
      },
      role: normalizedRole,
      permissions: decoded.permissions,
      managed_hotels: hotelRows
    });
  } catch (error) {
    console.error('获取用户信息失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
});

// 角色升级申请
router.post('/role-application', async (req: AuthRequest, res) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader) {return sendError(res, errorResponse('未提供认证令牌', 401));}

    const token = authHeader.replace(/Bearer /i, '').trim();
    const decoded = verifyToken(token);
    if (!decoded) {return sendError(res, errorResponse('令牌无效', 401));}

    const { application_type, hotel_id, hotel_name, hotel_address, reason } = req.body;

    if (!application_type || !['create_hotel', 'bind_employee'].includes(application_type)) {
      return sendError(res, errorResponse('申请类型无效', 400));
    }

    if (application_type === 'create_hotel' && (!hotel_name || !hotel_address)) {
      return sendError(res, errorResponse('酒店名称和地址不能为空', 400));
    }

    if (application_type === 'bind_employee' && !hotel_id) {
      return sendError(res, errorResponse('请选择要绑定的酒店', 400));
    }

    const [existing]: any = await db.execute(
      'SELECT * FROM role_applications WHERE user_id = ? AND status = ?',
      [decoded.id, 'pending']
    );

    if (existing.length > 0) {
      return sendError(res, errorResponse('您已有待审核的申请', 400));
    }

    const [result]: any = await db.execute(
      `INSERT INTO role_applications (user_id, application_type, hotel_id, hotel_name, hotel_address, reason, status)
       VALUES (?, ?, ?, ?, ?, ?, 'pending')`,
      [
        decoded.id,
        application_type,
        application_type === 'bind_employee' ? hotel_id : null,
        application_type === 'create_hotel' ? hotel_name : null,
        application_type === 'create_hotel' ? hotel_address : null,
        reason || null
      ]
    );

    sendSuccess(res, {
      application_id: result.insertId,
      message: '申请已提交，请等待审核'
    });
  } catch (error) {
    console.error('角色申请失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
});

// 获取角色申请列表（管理端/系统管理员）
router.get('/role-applications', async (req: AuthRequest, res) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader) {return sendError(res, errorResponse('未提供认证令牌', 401));}

    const token = authHeader.replace(/Bearer /i, '').trim();
    const decoded = verifyToken(token);
    if (!decoded) {return sendError(res, errorResponse('令牌无效', 401));}

    const role = normalizeRole(decoded.role);
    let whereClause = 'WHERE 1=1';
    const params: any[] = [];

    if (isHotelAdmin(role)) {
      whereClause += ' AND ra.application_type = ? AND ra.hotel_id IN (SELECT hotel_id FROM user_hotels WHERE user_id = ?)';
      params.push('bind_employee', decoded.id);
    }

    if (isCustomer(role) || isGuest(role)) {
      whereClause += ' AND ra.user_id = ?';
      params.push(decoded.id);
    }

    const status = req.query.status as string;
    if (status) {
      whereClause += ' AND ra.status = ?';
      params.push(status);
    }

    const [rows]: any = await db.execute(
      `SELECT ra.*, u.username, u.phone, u.uid, h.hotel_name as target_hotel_name
       FROM role_applications ra
       LEFT JOIN users u ON ra.user_id = u.id
       LEFT JOIN hotels h ON ra.hotel_id = h.id
       ${whereClause}
       ORDER BY ra.created_at DESC`,
      params
    );

    sendSuccess(res, rows);
  } catch (error) {
    console.error('获取角色申请列表失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
});

// 审核角色申请
router.put('/role-applications/:id/review', async (req: AuthRequest, res) => {
  const connection = await (await import('../../config/database')).default.getConnection();
  try {
    await connection.beginTransaction();

    const authHeader = req.headers.authorization;
    if (!authHeader) { await connection.rollback(); return sendError(res, errorResponse('未提供认证令牌', 401)); }

    const token = authHeader.replace(/Bearer /i, '').trim();
    const decoded = verifyToken(token);
    if (!decoded) { await connection.rollback(); return sendError(res, errorResponse('令牌无效', 401)); }

    const reviewerRole = normalizeRole(decoded.role);
    if (!isSystemAdmin(reviewerRole) && !isHotelAdmin(reviewerRole)) {
      await connection.rollback();
      return sendError(res, errorResponse('权限不足，仅管理员可审核', 403));
    }

    const { id } = req.params;
    const { status, review_note } = req.body;

    if (!['approved', 'rejected'].includes(status)) {
      await connection.rollback();
      return sendError(res, errorResponse('审核状态无效', 400));
    }

    const [apps]: any = await connection.execute(
      'SELECT * FROM role_applications WHERE id = ? AND status = ?',
      [id, 'pending']
    );

    if (apps.length === 0) {
      await connection.rollback();
      return sendError(res, errorResponse('申请不存在或已审核', 404));
    }

    const app = apps[0];

    await connection.execute(
      'UPDATE role_applications SET status = ?, reviewed_by = ?, reviewed_at = NOW(), review_note = ? WHERE id = ?',
      [status, decoded.id, review_note || null, id]
    );

    if (status === 'approved') {
      if (app.application_type === 'create_hotel') {
        const [hotelResult]: any = await connection.execute(
          'INSERT INTO hotels (hotel_name, hotel_address, hotel_type, star_rating, contact_phone, description) VALUES (?, ?, ?, ?, ?, ?)',
          [app.hotel_name, app.hotel_address, '商务酒店', 3, '', '']
        );
        const newHotelId = hotelResult.insertId;

        await connection.execute(
          'UPDATE users SET role = ? WHERE id = ?',
          [CANONICAL_ROLES.HOTEL_ADMIN, app.user_id]
        );

        await connection.execute(
          'INSERT IGNORE INTO user_hotels (user_id, hotel_id) VALUES (?, ?)',
          [app.user_id, newHotelId]
        );

        const [managerRole]: any = await connection.execute(
          'SELECT id FROM roles WHERE role_name = ?',
          [CANONICAL_ROLES.HOTEL_ADMIN]
        );
        if (managerRole.length > 0) {
          await connection.execute(
            'DELETE FROM user_roles WHERE user_id = ?',
            [app.user_id]
          );
          await connection.execute(
            'INSERT INTO user_roles (user_id, role_id) VALUES (?, ?)',
            [app.user_id, managerRole[0].id]
          );
        }
      } else if (app.application_type === 'bind_employee') {
        await connection.execute(
          'UPDATE users SET role = ? WHERE id = ?',
          [CANONICAL_ROLES.STAFF, app.user_id]
        );

        if (app.hotel_id) {
          await connection.execute(
            'INSERT IGNORE INTO user_hotels (user_id, hotel_id) VALUES (?, ?)',
            [app.user_id, app.hotel_id]
          );
        }

        const [staffRole]: any = await connection.execute(
          'SELECT id FROM roles WHERE role_name = ?',
          [CANONICAL_ROLES.STAFF]
        );
        if (staffRole.length > 0) {
          await connection.execute(
            'DELETE FROM user_roles WHERE user_id = ?',
            [app.user_id]
          );
          await connection.execute(
            'INSERT INTO user_roles (user_id, role_id) VALUES (?, ?)',
            [app.user_id, staffRole[0].id]
          );
        }
      }
    }

    await connection.commit();
    sendSuccess(res, { message: status === 'approved' ? '申请已通过' : '申请已拒绝' });
  } catch (error) {
    await connection.rollback();
    console.error('审核角色申请失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  } finally {
    connection.release();
  }
});

// 切换酒店 (仅系统管理员可用)
router.post('/switch-hotel', authenticate as any, async (req: AuthRequest, res) => {
  try {
    const user = req.user;

    if (!user || user.role !== CANONICAL_ROLES.SYSTEM_ADMIN) {
      return res.status(403).json(errorResponse('权限不足', 403));
    }

    const { hotel_id } = req.body;

    if (hotel_id === undefined) {
      return res.status(400).json(errorResponse('酒店 ID 不能为空', 400));
    }

    let hotelName = '智联酒店集团总部';
    const targetHotelId = Number(hotel_id);

    if (targetHotelId !== 0) {
      // 验证酒店是否存在
      const [hotels]: any = await db.execute(
        'SELECT id, hotel_name FROM hotels WHERE id = ?',
        [targetHotelId]
      );

      if (hotels.length === 0) {
        return res.status(404).json(errorResponse('酒店不存在', 404));
      }
      hotelName = hotels[0].hotel_name;
    }

    // 生成新的 JWT，包含指定的 hotel_id
    const jwtPayload: JwtPayload = {
      id: user.id,
      username: user.username,
      phone: user.phone,
      role: user.role,
      hotel_id: targetHotelId,
      permissions: user.permissions
    };

    const jwtToken = generateToken(jwtPayload);

    sendSuccess(res, {
      token: jwtToken,
      hotel: {
        id: targetHotelId,
        name: hotelName
      },
      message: `成功切换到: ${hotelName}`
    });
  } catch (error) {
    console.error('切换酒店失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
});

export default router;
