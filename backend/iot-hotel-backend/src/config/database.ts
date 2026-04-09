import mysql, { Pool, PoolOptions, RowDataPacket, ResultSetHeader } from 'mysql2/promise';
import config from '../config';

const poolOptions: PoolOptions = {
  host: config.database.host,
  port: config.database.port,
  user: config.database.user,
  password: config.database.password,
  database: config.database.database,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  charset: 'utf8mb4_unicode_ci',
  enableKeepAlive: true,
  keepAliveInitialDelay: 0,
  connectTimeout: 10000 // 10秒连接超时
};

const pool: Pool = mysql.createPool(poolOptions);

export type { RowDataPacket, ResultSetHeader };
export default pool;
