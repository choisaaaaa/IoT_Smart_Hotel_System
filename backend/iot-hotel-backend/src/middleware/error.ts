import { Request, Response, NextFunction } from 'express';
import logger from '../utils/logger';

// M-02安全加固: 错误处理不应泄露内部信息
const isProduction = process.env.NODE_ENV === 'production';

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  _next: NextFunction
): void {
  const statusCode = (err as any).statusCode || 500;
  
  // 记录详细错误信息到日志（仅服务器端可见）
  logger.error(`${req.method} ${req.originalUrl} ${statusCode} - ${err.message}`, {
    stack: err.stack,
    requestId: (req as any).requestId
  });

  // 根据环境决定返回详细程度
  res.status(statusCode).json({
    code: statusCode,
    message: isProduction ? '服务器错误' : err.message || '服务器错误',
    ...(isProduction ? {} : { stack: err.stack }),
    timestamp: Date.now()
  });
}

export function notFoundHandler(req: Request, res: Response, _next: NextFunction): void {
  logger.warn(`${req.method} ${req.originalUrl} 404`);
  res.status(404).json({
    code: 404,
    message: '接口不存在',
    timestamp: Date.now()
  });
}
