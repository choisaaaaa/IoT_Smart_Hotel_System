
import pool from './src/config/database';

async function migrate() {
  try {
    console.log('Starting migration: updating coupons and adding room_prices tables...');
    
    // 1. 更新 coupons 表
    await pool.query(`
      ALTER TABLE coupons 
      ADD COLUMN coupon_code VARCHAR(50) UNIQUE DEFAULT NULL AFTER coupon_name,
      ADD COLUMN is_multiple_use BOOLEAN DEFAULT FALSE AFTER total_count,
      ADD COLUMN hotel_id INT DEFAULT 0 AFTER updated_at,
      MODIFY COLUMN coupon_type ENUM('discount', 'cash') DEFAULT 'discount';
    `);

    // 2. 创建价格日历表 room_prices
    await pool.query(`
      CREATE TABLE IF NOT EXISTS room_prices (
        id INT AUTO_INCREMENT PRIMARY KEY,
        room_type_id INT NOT NULL,
        hotel_id INT NOT NULL,
        price_date DATE NOT NULL,
        discount_rate DECIMAL(3,2) DEFAULT 1.00,
        base_price DECIMAL(10,2) NOT NULL,
        final_price DECIMAL(10,2) NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY \`unique_room_date\` (room_type_id, price_date)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);

    // 3. 更新 room_types 表增加 hotel_id 归属
    await pool.query(`
      ALTER TABLE room_types ADD COLUMN hotel_id INT DEFAULT 0 AFTER updated_at;
    `);

    console.log('Migration successful.');
    process.exit(0);
  } catch (error: any) {
    console.error('Migration failed:', error);
    process.exit(1);
  }
}

migrate();
