const mysql = require('mysql2/promise');

async function runMigration() {
  const connection = await mysql.createConnection({
    host: '8.134.166.69',
    port: 3306,
    user: 'iot_user',
    password: 'Iot2026.',
    database: 'iot_hotel_system'
  });

  try {
    // 检查列是否已存在
    const [columns] = await connection.query(`
      SELECT COLUMN_NAME FROM information_schema.COLUMNS 
      WHERE TABLE_SCHEMA = 'iot_hotel_system' 
      AND TABLE_NAME = 'devices' 
      AND COLUMN_NAME = 'device_key_encrypted'
    `);

    if (columns.length > 0) {
      console.log('device_key_encrypted 列已存在，跳过添加');
    } else {
      // 添加加密密钥存储列
      await connection.query(`
        ALTER TABLE devices 
        ADD COLUMN device_key_encrypted TEXT DEFAULT NULL 
        COMMENT '设备密钥AES-256-GCM加密存储（用于签名验证）' 
        AFTER device_key
      `);
      console.log('成功添加 device_key_encrypted 列');
    }

    // 数据迁移：将现有的明文device_key加密到device_key_encrypted
    // 注意：这只迁移非空且非哈希格式的密钥
    const [rows] = await connection.query(`
      SELECT id, device_key FROM devices 
      WHERE device_key IS NOT NULL 
        AND device_key != '' 
        AND (CHAR_LENGTH(device_key) != 64 OR device_key NOT REGEXP '^[a-f0-9]+$')
    `);

    console.log(`找到 ${rows.length} 条需要迁移的明文密钥记录`);

    if (rows.length > 0) {
      // 使用相同的加密逻辑进行迁移
      const crypto = require('crypto');
      const keyStr = process.env.DEVICE_KEY_ENCRYPTION_KEY || 'iot-hotel-device-key-encryption-key-2024-production-must-change';
      const encryptionKey = crypto.createHash('sha256').update(keyStr).digest();
      
      for (const row of rows) {
        const rawKey = row.device_key;
        const iv = crypto.randomBytes(16);
        const cipher = crypto.createCipheriv('aes-256-gcm', encryptionKey, iv);
        let encrypted = cipher.update(rawKey, 'utf8', 'hex');
        encrypted += cipher.final('hex');
        const authTag = cipher.getAuthTag();
        const encryptedValue = iv.toString('hex') + authTag.toString('hex') + encrypted;
        
        await connection.query(
          'UPDATE devices SET device_key_encrypted = ? WHERE id = ?',
          [encryptedValue, row.id]
        );
      }
      console.log(`成功迁移 ${rows.length} 条明文密钥`);
    }

    console.log('设备密钥加密迁移完成');
  } catch (error) {
    console.error('迁移失败:', error.message);
  } finally {
    await connection.end();
  }
}

runMigration();
