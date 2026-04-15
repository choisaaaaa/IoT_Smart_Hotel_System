-- 智慧酒店物联网控制系统 - 数据库架构补丁 (v3.1.1)
-- 解决“获取今日余量失败 500”问题：确保默认余量字段存在

USE iot_hotel_system;

-- -----------------------------------------------------------------------------
-- 1. 确保 rate_plans 表有 default_inventory 字段
-- -----------------------------------------------------------------------------
SET @dbname = DATABASE();
SET @tablename = "rate_plans";
SET @columnname = "default_inventory";
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = @tablename AND COLUMN_NAME = @columnname) > 0,
  "SELECT 'Column default_inventory already exists in rate_plans.'",
  "ALTER TABLE rate_plans ADD COLUMN default_inventory INT DEFAULT 10 COMMENT '该方案每日默认可售余量'"
));
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- -----------------------------------------------------------------------------
-- 2. 确保 room_types 表有 default_inventory 字段 (用于标准价方案)
-- -----------------------------------------------------------------------------
SET @tablename = "room_types";
SET @columnname = "default_inventory";
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = @dbname AND TABLE_NAME = @tablename AND COLUMN_NAME = @columnname) > 0,
  "SELECT 'Column default_inventory already exists in room_types.'",
  "ALTER TABLE room_types ADD COLUMN default_inventory INT DEFAULT 10 COMMENT '该房型标准价每日默认可售余量'"
));
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- -----------------------------------------------------------------------------
-- 3. 补丁执行完毕
-- -----------------------------------------------------------------------------
