import { Request, Response, NextFunction } from 'express';
import { AuthRequest, DeviceAuthRequest } from '../types';
import { verifyToken } from '../utils/jwt';
import { hasRole, normalizeRole } from '../utils/role';
import pool, { RowDataPacket } from '../config/database';
import logger from '../utils/logger';
import crypto from 'crypto';

/**
 * JWT认证中间件
 * 验证请求中的Bearer Token
 */
export function authenticate(req: AuthRequest, res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization;
  
  if (!authHeader) {
    res.status(401).json({
      code: 401,
      message: '未提供认证令牌',
      timestamp: Date.now()
    });
    return;
  }

  const token = authHeader.replace(/Bearer /i, '').trim();
  
  if (!token) {
    res.status(401).json({
      code: 401,
      message: '认证令牌无效',
      timestamp: Date.now()
    });
    return;
  }

  try {
    const decoded = verifyToken(token);
    if (!decoded) {
      throw new Error('Token verification failed');
    }
    
    req.user = {
      ...decoded,
      role: normalizeRole(decoded.role)
    };
    next();
  } catch (error: any) {
    logger.error('JWT验证失败:', error.message);
    res.status(401).json({
      code: 401,
      message: '令牌验证失败: ' + (error.message || 'Unauthorized'),
      timestamp: Date.now()
    });
  }
}

/**
 * 角色鉴权中间件
 * @param roles 允许的角色列表
 */
export function authorize(roles: string[]): any {
  return (req: AuthRequest, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({
        code: 401,
        message: '未授权，请先登录',
        timestamp: Date.now()
      });
    }

    if (!hasRole(req.user.role, roles)) {
      const currentRole = normalizeRole(req.user.role);
      const allowedRoles = roles.map((role) => normalizeRole(role)).join(' / ');
      return res.status(403).json({
        code: 403,
        message: `权限不足：当前角色为 ${currentRole || 'unknown'}，需要角色 ${allowedRoles}`,
        timestamp: Date.now()
      });
    }

    next();
  };
}

/**
 * 设备认证中间件
 * 验证设备ID和设备密钥的有效性
 */
export async function deviceAuthMiddleware(
  req: DeviceAuthRequest, 
  res: Response, 
  next: NextFunction
): Promise<void> {
  const deviceId = req.headers['x-device-id'] as string;
  const deviceKey = req.headers['x-device-key'] as string;
  const timestamp = req.headers['x-timestamp'] as string;
  const signature = req.headers['x-signature'] as string;

  // 检查必要参数
  if (!deviceId || !deviceKey) {
    res.status(401).json({
      code: 401,
      message: '设备认证信息缺失',
      timestamp: Date.now()
    });
    return;
  }

  try {
    // 查询设备信息
    const [devices]: any = await pool.query<RowDataPacket[]>(
      'SELECT id, device_id, device_key, audit_status, hotel_id, device_status FROM devices WHERE device_id = ?',
      [deviceId]
    );

    if (devices.length === 0) {
      res.status(401).json({
        code: 401,
        message: '设备未注册',
        timestamp: Date.now()
      });
      return;
    }

    const device = devices[0];

    // 验证设备密钥
    if (device.device_key !== deviceKey) {
      logger.warn(`设备密钥验证失败: ${deviceId}`);
      res.status(401).json({
        code: 401,
        message: '设备认证失败',
        timestamp: Date.now()
      });
      return;
    }

    // 检查设备审核状态
    if (device.audit_status !== 'approved') {
      res.status(403).json({
        code: 403,
        message: '设备未通过审核',
        timestamp: Date.now()
      });
      return;
    }

    // 验证时间戳（防重放攻击，5分钟窗口）
    if (timestamp) {
      const requestTime = parseInt(timestamp);
      const now = Date.now();
      if (isNaN(requestTime) || Math.abs(now - requestTime) > 5 * 60 * 1000) {
        res.status(401).json({
          code: 401,
          message: '请求时间戳无效或已过期',
          timestamp: Date.now()
        });
        return;
      }
    }

    // 验证签名（如果提供）
    if (signature && timestamp) {
      const payload = `${deviceId}:${timestamp}:${deviceKey}`;
      const expectedSignature = crypto
        .createHmac('sha256', deviceKey)
        .update(payload)
        .digest('hex');
      
      if (signature !== expectedSignature) {
        logger.warn(`设备签名验证失败: ${deviceId}`);
        res.status(401).json({
          code: 401,
          message: '设备签名验证失败',
          timestamp: Date.now()
        });
        return;
      }
    }

    // 更新设备最后活跃时间
    await pool.query(
      'UPDATE devices SET last_seen = NOW() WHERE id = ?',
      [device.id]
    );

    // 将设备信息附加到请求对象
    req.device = {
      id: device.id,
      deviceId: device.device_id,
      hotelId: device.hotel_id,
      status: device.device_status,
      auditStatus: device.audit_status
    };

    next();
  } catch (error) {
    logger.error('设备认证中间件错误:', error);
    res.status(500).json({
      code: 500,
      message: '设备认证过程发生错误',
      timestamp: Date.now()
    });
  }
}

/**
 * 可选设备认证中间件
 * 不强制要求认证，但如果提供则验证
 */
export async function optionalDeviceAuthMiddleware(
  req: DeviceAuthRequest, 
  res: Response, 
  next: NextFunction
): Promise<void> {
  const deviceId = req.headers['x-device-id'] as string;
  const deviceKey = req.headers['x-device-key'] as string;

  if (!deviceId || !deviceKey) {
    // 未提供设备认证信息，继续但不附加设备信息
    return next();
  }

  // 调用主认证逻辑
  return deviceAuthMiddleware(req, res, next);
}
