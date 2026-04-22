import { Request, Response, NextFunction } from 'express';
import { v4 as uuidv4 } from 'uuid';

/**
 * 请求ID追踪中间件
 * 
 * 功能:
 * 1. 为每个请求生成唯一的 request ID
 * 2. 支持客户端传递的 X-Request-Id 头（优先使用）
 * 3. 在响应头中返回 request ID
 * 4. 将 request ID 附加到请求对象，便于日志追踪
 */

declare global {
  namespace Express {
    interface Request {
      requestId?: string;
    }
  }
}

export function requestIdMiddleware(req: Request, res: Response, next: NextFunction): void {
  // 优先使用客户端提供的 request ID，否则生成新的
  const requestId = req.headers['x-request-id'] as string || uuidv4();
  
  req.requestId = requestId;
  
  // 在响应头中设置 request ID
  res.setHeader('X-Request-Id', requestId);
  
  next();
}

/**
 * 获取当前请求的 request ID
 * @param req Express 请求对象
 * @returns request ID 字符串
 */
export function getRequestId(req: Request): string {
  return req.requestId || 'unknown';
}
