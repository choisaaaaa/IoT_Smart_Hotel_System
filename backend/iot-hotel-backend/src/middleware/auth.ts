import { Request, Response, NextFunction } from 'express';
import { AuthRequest } from '../types';

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

  const token = authHeader.replace('Bearer ', '');
  
  if (!token) {
    res.status(401).json({
      code: 401,
      message: '认证令牌无效',
      timestamp: Date.now()
    });
    return;
  }

  try {
    const jwt = require('jsonwebtoken');
    const secret = process.env.JWT_SECRET || 'your_jwt_secret_key_here';
    const decoded = jwt.verify(token, secret);
    
    req.user = decoded;
    next();
  } catch (error) {
    res.status(401).json({
      code: 401,
      message: '令牌验证失败',
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

    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        code: 403,
        message: '权限不足',
        timestamp: Date.now()
      });
    }

    next();
  };
}

export function deviceAuthMiddleware(req: Request, res: Response, next: NextFunction): void {
  const deviceId = req.headers['x-device-id'] as string;
  const deviceKey = req.headers['x-device-key'] as string;

  if (!deviceId || !deviceKey) {
    res.status(401).json({
      code: 401,
      message: '设备认证信息缺失',
      timestamp: Date.now()
    });
    return;
  }

  req.headers['device_id'] = deviceId;
  req.headers['device_key'] = deviceKey;
  next();
}
