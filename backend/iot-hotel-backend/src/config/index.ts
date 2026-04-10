import { config } from 'dotenv';
import path from 'path';

config({ path: path.resolve(process.cwd(), '.env') });

export default {
  app: {
    host: process.env.APP_HOST || '127.0.0.1',
    port: parseInt(process.env.APP_PORT || '3000'),
    env: process.env.NODE_ENV || 'development',
    apiPrefix: process.env.API_PREFIX || '/api/v1',
    publicUrl: process.env.APP_PUBLIC_URL || '' // 增加公网访问 URL 配置
  },
  database: {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3306'),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'iot_hotel_system'
  },
  redis: {
    url: process.env.REDIS_URL || 'redis://localhost:6379'
  },
  mqtt: {
    host: process.env.MQTT_HOST || 'localhost',
    port: parseInt(process.env.MQTT_PORT || '1883'),
    username: process.env.MQTT_USERNAME,
    password: process.env.MQTT_PASSWORD
  },
  jwt: {
    secret: process.env.JWT_SECRET || 'your_jwt_secret_key_here',
    expiresIn: process.env.JWT_EXPIRES_IN || '24h'
  },
  logging: {
    level: process.env.LOG_LEVEL || 'info',
    dir: process.env.LOG_DIR || './logs'
  }
};
