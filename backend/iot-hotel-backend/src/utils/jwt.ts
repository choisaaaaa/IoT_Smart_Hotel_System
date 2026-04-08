import jwt from 'jsonwebtoken';

const secret = process.env.JWT_SECRET || 'your_jwt_secret_key_here';
const expiresIn: string | number = (process.env.JWT_EXPIRES_IN as string) || '24h';

export interface JwtPayload {
  id: number;
  username: string;
  role: string;
  hotel_id: number;
  permissions?: string[];
}

export function generateToken(payload: JwtPayload): string {
  return jwt.sign(payload, secret, { expiresIn: expiresIn as any });
}

export function verifyToken(token: string): JwtPayload | null {
  try {
    return jwt.verify(token, secret) as JwtPayload;
  } catch (error) {
    return null;
  }
}