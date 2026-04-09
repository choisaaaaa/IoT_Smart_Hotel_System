import pool, { RowDataPacket } from './config/database';
import logger from './utils/logger';

export async function migrate() {
  try {
    logger.info('Starting database migration...');
    
    // Check if user_id column exists in bookings
    const [columns] = await pool.query<any[]>(`
      SELECT COLUMN_NAME 
      FROM INFORMATION_SCHEMA.COLUMNS 
      WHERE TABLE_SCHEMA = DATABASE() 
      AND TABLE_NAME = 'bookings' 
      AND COLUMN_NAME = 'user_id'
    `);

    if (columns.length === 0) {
      logger.info('Adding user_id to bookings table...');
      await pool.query(`
        ALTER TABLE bookings 
        ADD COLUMN user_id INT NULL AFTER booking_number,
        ADD INDEX idx_user_id (user_id),
        ADD CONSTRAINT fk_booking_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
      `);
      logger.info('Successfully added user_id to bookings table.');
    }

    // --- 对齐 hotels 表结构 ---
    const [hotelColumns] = await pool.query<any[]>(`
      SELECT COLUMN_NAME 
      FROM INFORMATION_SCHEMA.COLUMNS 
      WHERE TABLE_SCHEMA = DATABASE() 
      AND TABLE_NAME = 'hotels'
    `);
    const hotelColNames = hotelColumns.map(c => c.COLUMN_NAME.toLowerCase());

    const hotelAdditions = [
      { name: 'hotel_id', type: 'INT NULL' },
      { name: 'hotel_code', type: 'VARCHAR(50) NULL' },
      { name: 'city', type: 'VARCHAR(100) NULL' },
      { name: 'location', type: 'VARCHAR(255) NULL' },
      { name: 'star_rating', type: 'INT DEFAULT 3' },
      { name: 'rating', type: 'DECIMAL(3,2) DEFAULT 4.50' },
      { name: 'review_count', type: 'INT DEFAULT 0' },
      { name: 'image_url', type: 'VARCHAR(255) NULL' },
      { name: 'promotion', type: 'VARCHAR(255) NULL' }
    ];

    for (const col of hotelAdditions) {
      if (!hotelColNames.includes(col.name.toLowerCase())) {
        logger.info(`Adding column ${col.name} to hotels table...`);
        await pool.query(`ALTER TABLE hotels ADD COLUMN ${col.name} ${col.type}`);
      }
    }

    // 同步现有数据
    if (hotelColNames.includes('hotel_id') && hotelColNames.includes('id')) {
      await pool.query('UPDATE hotels SET hotel_id = IFNULL(hotel_id, id) WHERE hotel_id IS NULL');
    }
    if (hotelColNames.includes('location') && hotelColNames.includes('hotel_address')) {
      await pool.query('UPDATE hotels SET location = IFNULL(location, hotel_address) WHERE location IS NULL');
    }
    if (hotelColNames.includes('star_rating') && hotelColNames.includes('hotel_star')) {
      await pool.query('UPDATE hotels SET star_rating = IFNULL(star_rating, hotel_star) WHERE star_rating IS NULL');
    }

    // --- 对齐 rooms 表结构 ---
    const [roomColumns] = await pool.query<any[]>(`
      SELECT COLUMN_NAME 
      FROM INFORMATION_SCHEMA.COLUMNS 
      WHERE TABLE_SCHEMA = DATABASE() 
      AND TABLE_NAME = 'rooms'
    `);
    const roomColNames = roomColumns.map(c => c.COLUMN_NAME.toLowerCase());

    const roomAdditions = [
      { name: 'hotel_id', type: 'INT NULL' },
      { name: 'room_id', type: 'INT NULL' },
      { name: 'image_url', type: 'VARCHAR(255) NULL' }
    ];

    for (const col of roomAdditions) {
      if (!roomColNames.includes(col.name.toLowerCase())) {
        logger.info(`Adding column ${col.name} to rooms table...`);
        await pool.query(`ALTER TABLE rooms ADD COLUMN ${col.name} ${col.type}`);
      }
    }

    // 同步现有数据
    if (roomColNames.includes('hotel_id')) {
      await pool.query('UPDATE rooms SET hotel_id = IFNULL(hotel_id, 1) WHERE hotel_id IS NULL');
    }
    if (roomColNames.includes('room_id') && roomColNames.includes('id')) {
      await pool.query('UPDATE rooms SET room_id = IFNULL(room_id, id) WHERE room_id IS NULL');
    }

    logger.info('Database migration completed.');

    // 添加调试账号
    logger.info('Checking debug accounts...');
    const [existingUsers] = await pool.query<RowDataPacket[]>(
      'SELECT username FROM users WHERE username IN (?, ?)',
      ['admin2', 'staff2']
    );

    const bcrypt = require('bcryptjs');
    const hashedPassword = await bcrypt.hash('admin123', 10);

    // 获取第一个酒店的 ID
    const [hotels] = await pool.query<RowDataPacket[]>('SELECT id FROM hotels LIMIT 1');
    const hotelId = hotels.length > 0 ? hotels[0].id : 1;

    if (!existingUsers.some(u => u.username === 'admin2')) {
      logger.info('Adding debug admin account (admin2)...');
      await pool.query(
        'INSERT INTO users (username, password, role, hotel_id) VALUES (?, ?, ?, ?)',
        ['admin2', hashedPassword, 'admin', hotelId]
      );
    }

    // 确保调试账号绑定了酒店
    await pool.query(
      'UPDATE users SET hotel_id = ? WHERE username IN (?, ?) AND (hotel_id IS NULL OR hotel_id = 0)',
      [hotelId, 'admin2', 'staff2']
    );
    logger.info('Debug accounts hotel_id updated.');
    
    logger.info('Debug accounts check completed.');
  } catch (error) {
    logger.error('Database migration failed:', error);
  }
}

// 如果直接运行此文件，则执行迁移
if (require.main === module) {
  migrate().then(() => {
    logger.info('Migration task finished.');
    process.exit(0);
  }).catch(err => {
    logger.error('Migration task failed:', err);
    process.exit(1);
  });
}
