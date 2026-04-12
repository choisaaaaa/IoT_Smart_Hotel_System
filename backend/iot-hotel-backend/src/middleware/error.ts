import { Request, Response, NextFunction } from 'express';
import logger from '../utils/logger';

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  _next: NextFunction
): void {
  const statusCode = (err as any).statusCode || 500;
  
  logger.error(`${req.method} ${req.originalUrl} ${statusCode} - ${err.message}`);

  res.status(statusCode).json({
    code: statusCode,
    message: err.message || '服务器错误',
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
