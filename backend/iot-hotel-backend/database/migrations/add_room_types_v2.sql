-- 智慧酒店物联网控制系统 - 房型与楼层管理更新脚本 (增强安全版)
-- 版本: v2.4.1
-- 更新内容：添加房型管理表，支持楼层索引，增强数据迁移安全性

USE iot_hotel_system;

-- 1. 数据备份 (如果表已存在)
CREATE TABLE IF NOT EXISTS rooms_backup_v241 AS SELECT * FROM rooms;

-- 2. 创建房型表
CREATE TABLE IF NOT EXISTS room_types (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE COMMENT '房型名称',
    code VARCHAR(20) NOT NULL UNIQUE COMMENT '房型代码',
    base_price DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '基础价格',
    area DECIMAL(6,2) DEFAULT NULL COMMENT '面积',
    bed_type VARCHAR(20) DEFAULT 'single' COMMENT '床型',
    max_guests INT DEFAULT 1 COMMENT '最大入住人数',
    facilities JSON DEFAULT NULL COMMENT '设施',
    description TEXT DEFAULT NULL COMMENT '描述',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. 数据完整性检查：确保所有房间都有对应的房型代码
-- 这一步在脚本中无法直接阻断，但可以通过 SELECT 观察
-- SELECT DISTINCT room_type FROM rooms WHERE room_type IS NOT NULL;

-- 4. 从现有数据导入房型
-- 仅导入不存在的房型，避免重复
INSERT INTO room_types (name, code, base_price, area, bed_type, max_guests)
SELECT DISTINCT room_type, room_type, room_price, area, bed_type, max_guests 
FROM rooms 
WHERE room_type IS NOT NULL 
AND room_type NOT IN (SELECT code FROM room_types);

-- 5. 修改 rooms 表，添加房型 ID 关联 (如果不存在)
SET @dbname = DATABASE();
SET @tablename = 'rooms';
SET @columnname = 'room_type_id';
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
   WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = @tablename AND COLUMN_NAME = @columnname) > 0,
  'SELECT 1',
  'ALTER TABLE rooms ADD COLUMN room_type_id INT AFTER room_type'
));
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 6. 建立关联数据
-- 使用 INNER JOIN 确保只更新匹配成功的行，并检查未匹配的行
UPDATE rooms r 
JOIN room_types rt ON r.room_type = rt.code 
SET r.room_type_id = rt.id;

-- 7. 验证迁移结果：检查是否有房间未关联到房型 ID
-- SELECT id, room_number, room_type FROM rooms WHERE room_type_id IS NULL AND room_type IS NOT NULL;

-- 8. 添加外键与索引
-- 检查外键是否已存在，避免重复添加错误
SET @fk_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS WHERE CONSTRAINT_NAME = 'fk_room_type' AND TABLE_NAME = 'rooms' AND TABLE_SCHEMA = DATABASE());
SET @preparedStatement = IF(@fk_exists > 0, 'SELECT 1', 'ALTER TABLE rooms ADD CONSTRAINT fk_room_type FOREIGN KEY (room_type_id) REFERENCES room_types(id) ON DELETE SET NULL');
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 检查索引是否已存在
SET @idx_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE INDEX_NAME = 'idx_room_floor' AND TABLE_NAME = 'rooms' AND TABLE_SCHEMA = DATABASE());
SET @preparedStatement = IF(@idx_exists > 0, 'SELECT 1', 'CREATE INDEX idx_room_floor ON rooms(floor)');
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 9. 回滚说明：
-- 如果迁移失败，请执行以下操作：
-- UPDATE rooms r JOIN rooms_backup_v241 b ON r.id = b.id SET r.room_type_id = NULL;
-- ALTER TABLE rooms DROP FOREIGN KEY fk_room_type;
-- ALTER TABLE rooms DROP COLUMN room_type_id;
-- DROP TABLE room_types;
