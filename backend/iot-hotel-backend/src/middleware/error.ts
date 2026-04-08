import { Request, Response, NextFunction } from 'express';
import logger from '../utils/logger';

export function errorHandler(
  err: Error,
  _req: Request,
  res: Response,
  _next: NextFunction
): void {
  const statusCode = (err as any).statusCode || 500;
  
  // 实时输出错误日志到终端
  logger.error(`${_req.method} ${_req.url} - Error: ${err.message}`, {
    stack: err.stack,
    body: _req.body,
    query: _req.query
  });

  res.status(statusCode).json({
    code: statusCode,
    message: err.message || '服务器错误',
    details: process.env.NODE_ENV === 'development' ? { stack: err.stack } : undefined,
    timestamp: Date.now()
  });
}

export function notFoundHandler(_req: Request, res: Response, _next: NextFunction): void {
  res.status(404).json({
    code: 404,
    message: '接口不存在',
    timestamp: Date.now()
  });
}
