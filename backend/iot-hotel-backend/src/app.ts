import express, { Application, Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import path from 'path';
import expressWinston from 'express-winston';
import logger from './utils/logger';
import { redisClient } from './utils/redis';

import appConfig from './config/app';
import routes from './routes';
import { notFoundHandler, errorHandler } from './middleware/error';

const app: Application = express();

// 初始化Redis连接
redisClient.connect().catch(err => {
  logger.warn('Redis初始化失败，应用将继续运行:', err.message);
});

// 启用信任代理（用于Nginx反向代理）
app.set('trust proxy', true);

app.use(helmet());
app.use(cors());
app.use(compression());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 实时请求日志中间件
app.use(expressWinston.logger({
  winstonInstance: logger,
  meta: false, // 不记录元数据，保持日志简洁
  msg: "HTTP {{req.method}} {{req.url}} {{res.statusCode}} {{res.responseTime}}ms",
  expressFormat: true,
  colorize: true,
  ignoreRoute: function (req, res) { return false; }
}));

// 静态资源服务
app.use('/uploads', express.static(path.join(process.cwd(), 'public/uploads')));

// 请求频率限制（已放宽）
const apiLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1分钟窗口
  max: 1000, // 每分钟最多1000个请求
  message: '请求过于频繁，请稍后再试',
  validate: false
});
app.use(apiLimiter);

app.get('/', (_req: Request, res: Response) => {
  res.json({
    code: 200,
    message: '慧宿智联·云边端一体化智能酒店物联网设备管理与服务全栈解决方案 API',
    timestamp: Date.now(),
    version: '2.2.0',
    endpoints: {
      health: '/health',
      docs: '/api/v1/docs'
    }
  });
});

app.use(appConfig.apiPrefix, (req, res, next) => {
  logger.info(`路由进入 API Prefix: ${req.method} ${req.url}`);
  next();
}, routes);

app.use(notFoundHandler);
app.use(errorHandler);

export default app;
