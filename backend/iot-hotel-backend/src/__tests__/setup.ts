import { Pool } from 'mysql2/promise';

// 测试环境配置
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-secret-key';
process.env.DB_HOST = 'localhost';
process.env.DB_PORT = '3306';
process.env.DB_USER = 'test';
process.env.DB_PASSWORD = 'test';
process.env.DB_NAME = 'test_db';

// 全局测试超时设置
jest.setTimeout(30000);

// 测试完成后的清理
afterAll(async () => {
  // 清理资源
});
