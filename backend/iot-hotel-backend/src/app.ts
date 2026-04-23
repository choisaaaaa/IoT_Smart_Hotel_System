import express, { Application, Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import path from 'path';
import expressWinston from 'express-winston';
import logger from './utils/logger';
import { redisClient } from './utils/redis';
import { requestIdMiddleware } from './middleware/request-id';

import appConfig from './config/app';
import routes from './routes';
import { notFoundHandler, errorHandler } from './middleware/error';

const app: Application = express();

// 初始化Redis连接
redisClient.connect().catch(err => {
  logger.warn('Redis初始化失败，应用将继续运行:', err.message);
});

// 启用信任代理（用于Nginx反向代理）
// 设置为特定IP地址，避免 express-rate-limit 的安全警告
app.set('trust proxy', ['127.0.0.1', '8.134.166.69']);

// Helmet安全头配置
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'", "https://cdn.jsdelivr.net"],
      scriptSrc: ["'self'", "https://cdn.jsdelivr.net"],
      imgSrc: ["'self'", "data:", "blob:", "https:"],
      connectSrc: ["'self'", "ws:", "wss:"],
      fontSrc: ["'self'", "https://cdn.jsdelivr.net"],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'", "blob:"],
      frameSrc: ["'none'"],
      frameAncestors: ["'none'"],
      baseUri: ["'self'"],
      formAction: ["'self'"],
      upgradeInsecureRequests: process.env.NODE_ENV === 'production' ? [] : null
    }
  },
  crossOriginEmbedderPolicy: false, // 允许嵌入资源
  crossOriginResourcePolicy: { policy: "cross-origin" },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  },
  referrerPolicy: { policy: "strict-origin-when-cross-origin" },
  noSniff: true,
  xssFilter: true
}));

// CORS配置
const corsOptions = {
  origin: (origin: string | undefined, callback: (err: Error | null, allow?: boolean) => void) => {
    const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || [
      'http://localhost:3000',
      'http://localhost:5173',
      'http://localhost:8080',
      'http://127.0.0.1:3000',
      'http://127.0.0.1:5173'
    ];

    // 允许无origin的请求（如移动应用、Postman）
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      logger.warn(`CORS拒绝访问: ${origin}`);
      callback(new Error('不允许的来源'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: [
    'Content-Type',
    'Authorization',
    'X-Device-Id',
    'X-Device-Key',
    'X-Timestamp',
    'X-Signature',
    'X-Request-Id'
  ],
  exposedHeaders: ['X-Request-Id'],
  maxAge: 86400 // 24小时
};

app.use(requestIdMiddleware);
app.use(cors(corsOptions));
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// 实时请求日志中间件
app.use((req, res, next) => {
  logger.info(`[Incoming Request] ${req.method} ${req.url} - Auth Header: ${req.headers.authorization ? 'Present' : 'Missing'}`);
  next();
});

app.use(expressWinston.logger({
  winstonInstance: logger,
  meta: false,
  msg: "HTTP {{req.method}} {{req.url}} {{res.statusCode}} {{res.responseTime}}ms",
  expressFormat: true,
  colorize: true,
  ignoreRoute: function (req, res) { return false; }
}));

// 静态资源服务
app.use('/uploads', express.static(path.join(process.cwd(), 'public/uploads'), {
  maxAge: '1d',
  etag: true,
  lastModified: true
}));

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
