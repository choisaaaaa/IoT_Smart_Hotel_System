import mysql from 'mysql2/promise';
import fs from 'fs';
import path from 'path';

async function runMigration() {
  console.log('🚀 开始执行数据库迁移...\n');

  const connection = await mysql.createConnection({
    host: '8.134.166.69',
    port: 3306,
    user: 'iot_user',
    password: 'Iot2026.',
    database: 'iot_hotel_system',
    multipleStatements: true, // 支持执行多条SQL语句
  });

  try {
    console.log('✅ 数据库连接成功\n');

    // 读取迁移脚本
    const migrationPath = path.join(__dirname, '../database/migrations/update_delivery_and_booking.sql');
    const sql = fs.readFileSync(migrationPath, 'utf8');

    console.log('📄 正在执行迁移脚本: update_delivery_and_booking.sql\n');
    console.log('--- SQL 执行开始 ---\n');

    // 执行迁移
    await connection.query(sql);

    console.log('\n--- SQL 执行完成 ---\n');

    // 验证表结构
    console.log('✅ 验证迁移结果...\n');

    // 检查 delivery_orders 表
    const [deliveryColumns] = await connection.query<any[]>(`
      SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_COMMENT
      FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = 'iot_hotel_system' AND TABLE_NAME = 'delivery_orders'
      ORDER BY ORDINAL_POSITION
    `);

    if (Array.isArray(deliveryColumns) && deliveryColumns.length > 0) {
      console.log('📦 delivery_orders 表结构:');
      deliveryColumns.forEach((col: any) => {
        console.log(`   • ${col.COLUMN_NAME}: ${col.COLUMN_TYPE} ${col.IS_NULLABLE === 'YES' ? '(可空)' : '(非空)'} - ${col.COLUMN_COMMENT || ''}`);
      });
    }

    // 检查 bookings 表的 user_id 字段
    const [bookingColumns] = await connection.query<any[]>(`
      SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_COMMENT
      FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = 'iot_hotel_system' AND TABLE_NAME = 'bookings' AND COLUMN_NAME = 'user_id'
    `);

    if (Array.isArray(bookingColumns) && bookingColumns.length > 0) {
      console.log('\n📋 bookings.user_id 字段:');
      bookingColumns.forEach((col: any) => {
        console.log(`   ✅ ${col.COLUMN_NAME}: ${col.COLUMN_TYPE} ${col.IS_NULLABLE === 'YES' ? '(可空)' : '(非空)'} - ${col.COLUMN_COMMENT || ''}`);
      });
    }

    // 检查 item_category 是否已移除
    const [itemCategoryCheck] = await connection.query<any[]>(`
      SELECT COUNT(*) as count
      FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = 'iot_hotel_system' AND TABLE_NAME = 'delivery_orders' AND COLUMN_NAME = 'item_category'
    `);

    if (itemCategoryCheck[0].count === 0) {
      console.log('\n✅ item_category 字段已成功移除');
    } else {
      console.log('\n⚠️ item_category 字段仍然存在（可能需要手动处理）');
    }

    console.log('\n🎉 数据库迁移执行成功！\n');

  } catch (error: any) {
    console.error('❌ 迁移执行失败:', error.message);
    console.error('错误详情:', error);
    process.exit(1);
  } finally {
    await connection.end();
  }
}

runMigration();