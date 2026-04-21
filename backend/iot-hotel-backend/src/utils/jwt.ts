import jwt from 'jsonwebtoken';
import config from '../config';
import logger from './logger';

export interface JwtPayload {
  id: number;
  username: string;
  phone?: string;
  role: string;
  hotel_id: number;
  permissions?: string[];
}

// 禁止的弱密钥列表
const FORBIDDEN_SECRETS = [
  'your_jwt_secret_key_here',
  'your_super_secret_key_change_me',
  'secret',
  'jwt_secret',
  '123456',
  'password',
  'admin',
  'test'
];

/**
 * 获取 JWT 密钥
 * 生产环境必须配置强密钥，否则抛出错误
 */
const getSecret = (): string => {
  const secret = config.jwt.secret || process.env.JWT_SECRET;
  
  // 检查密钥是否存在
  if (!secret) {
    const error = 'JWT_SECRET 未配置，请在环境变量中设置';
    logger.error(error);
    throw new Error(error);
  }
  
  // 检查是否使用弱密钥
  const lowerSecret = secret.toLowerCase().trim();
  if (FORBIDDEN_SECRETS.some(weak => lowerSecret.includes(weak.toLowerCase()))) {
    const error = 'JWT_SECRET 使用了禁止的弱密钥，请更换为强密钥';
    logger.error(error);
    throw new Error(error);
  }
  
  // 检查密钥长度（至少32字符）
  if (secret.length < 32) {
    const error = 'JWT_SECRET 长度必须至少32个字符';
    logger.error(error);
    throw new Error(error);
  }
  
  return secret;
};

/**
 * 生成 JWT Token
 */
export function generateToken(payload: JwtPayload): string {
  try {
    const secret = getSecret();
    const expiresIn = config.jwt.expiresIn || '24h';
    return jwt.sign(payload, secret, { 
      expiresIn: expiresIn as any,
      issuer: 'iot-hotel-system',
      audience: 'iot-hotel-users'
    });
  } catch (error) {
    logger.error('生成Token失败:', error);
    throw error;
  }
}

/**
 * 验证 JWT Token
 */
export function verifyToken(token: string): JwtPayload {
  try {
    const secret = getSecret();
    return jwt.verify(token, secret, {
      issuer: 'iot-hotel-system',
      audience: 'iot-hotel-users'
    }) as JwtPayload;
  } catch (error) {
    logger.error('Token验证失败:', error.message);
    throw error;
  }
}

/**
 * 解码 Token（不验证）
 */
export function decodeToken(token: string): JwtPayload | null {
  try {
    return jwt.decode(token) as JwtPayload;
  } catch {
    return null;
  }
}
