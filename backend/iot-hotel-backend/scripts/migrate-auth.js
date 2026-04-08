const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

async function runMigration() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT) || 3307,
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'iot_hotel_system',
    multipleStatements: true
  });

  try {
    console.log('开始执行数据库迁移...');

    // 读取迁移 SQL 文件
    const migrationPath = path.join(__dirname, '../database/migrations/add_auth_tables.sql');
    const migrationSQL = fs.readFileSync(migrationPath, 'utf-8');

    // 执行迁移
    await connection.query(migrationSQL);

    console.log('✓ 数据库迁移完成!');
    console.log('✓ 已创建角色表 (roles)');
    console.log('✓ 已创建用户角色关联表 (user_roles)');
    console.log('✓ 已创建 API Token 表 (api_tokens)');
    console.log('✓ 已创建登录会话表 (login_sessions)');
    console.log('✓ 已初始化默认角色数据 (admin/staff/user)');

  } catch (error) {
    console.error('✗ 数据库迁移失败:', error);
    process.exit(1);
  } finally {
    await connection.end();
  }
}

runMigration();
