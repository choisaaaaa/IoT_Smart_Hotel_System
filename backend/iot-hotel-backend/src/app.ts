import express, { Application, Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import rateLimit from 'express-rate-limit';

import appConfig from './config/app';
import routes from './routes';
import { notFoundHandler, errorHandler } from './middleware/error';

const app: Application = express();

// 启用信任代理（用于Nginx反向代理）
app.set('trust proxy', true);

app.use(helmet());
app.use(cors());
app.use(compression());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: '请求过于频繁，请稍后再试',
  validate: false
});
app.use(apiLimiter);

app.get('/', (_req: Request, res: Response) => {
  res.json({
    code: 200,
    message: '智慧酒店物联网控制系统API',
    timestamp: Date.now(),
    version: '2.0.0',
    endpoints: {
      health: '/health',
      docs: '/api/v1/docs'
    }
  });
});

app.use(appConfig.apiPrefix, routes);

app.use(notFoundHandler);
app.use(errorHandler);

export default app;