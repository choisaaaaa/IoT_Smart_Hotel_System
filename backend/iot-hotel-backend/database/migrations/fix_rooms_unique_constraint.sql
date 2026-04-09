-- 智慧酒店物联网控制系统 - 房间表唯一约束优化
-- 版本: v2.5.1
-- 更新内容：将房间号的唯一约束从全局改为按酒店隔离

USE iot_hotel_system;

-- 1. 检查是否存在旧的全局唯一索引并删除
SET @idx_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'rooms' AND INDEX_NAME = 'room_number');
SET @preparedStatement = IF(@idx_exists > 0, 'ALTER TABLE rooms DROP INDEX room_number', 'SELECT 1');
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 2. 创建按酒店隔离的联合唯一索引
SET @idx_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'rooms' AND INDEX_NAME = 'uk_hotel_room');
SET @preparedStatement = IF(@idx_exists = 0, 'ALTER TABLE rooms ADD UNIQUE INDEX uk_hotel_room (hotel_id, room_number)', 'SELECT 1');
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
