import jwt from 'jsonwebtoken';
import config from '../config';

export interface JwtPayload {
  id: number;
  username: string;
  phone?: string;
  role: string;
  hotel_id: number;
  permissions?: string[];
}

// 获取 JWT 秘钥，增加兜底
const getSecret = () => config.jwt.secret || process.env.JWT_SECRET || 'your_jwt_secret_key_here';

export function generateToken(payload: JwtPayload): string {
  const secret = getSecret();
  const expiresIn = config.jwt.expiresIn || '24h';
  return jwt.sign(payload, secret, { expiresIn: expiresIn as any });
}

export function verifyToken(token: string): JwtPayload {
  const secret = getSecret();
  // 调试日志 (只打印秘钥前4位)
  console.log(`[JWT Debug] Secret Prefix: ${secret.substring(0, 4)}***`);
  return jwt.verify(token, secret) as JwtPayload;
}
