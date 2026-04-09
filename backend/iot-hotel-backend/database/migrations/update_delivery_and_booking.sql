USE iot_hotel_system;

-- ============================================================
-- 数据库迁移: 送物订单优化 & 预订用户关联增强
-- 版本: v2026-04-10
-- 说明:
--   1. 创建/更新 delivery_orders 表结构
--   2. 移除 item_category 字段的强制要求
--   3. 添加配送状态流转相关字段 (started_delivering_at)
--   4. 为 bookings 表添加 user_id 字段支持用户关联
-- ============================================================

-- 1. 创建 delivery_orders 表（如果不存在）
SET @create_delivery_table = (
  SELECT COUNT(*)
  FROM information_schema.TABLES
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'delivery_orders'
);

SET @sql_create_delivery = IF(
  @create_delivery_table > 0,
  'SELECT ''delivery_orders table already exists'' AS status',
  '
    CREATE TABLE delivery_orders (
      id INT AUTO_INCREMENT PRIMARY KEY,
      order_no VARCHAR(50) NOT NULL,
      room_id INT NOT NULL,
      booking_id INT DEFAULT NULL,
      guest_id INT DEFAULT NULL,
      item_name VARCHAR(200) NOT NULL COMMENT ''商品名称（自由输入，不做分类限制）'',
      quantity INT NOT NULL DEFAULT 1 COMMENT ''数量'',
      note TEXT DEFAULT NULL COMMENT ''备注'',
      status VARCHAR(20) NOT NULL DEFAULT ''pending'' COMMENT ''状态: pending, delivering, completed, cancelled'',
      started_delivering_at DATETIME DEFAULT NULL COMMENT ''开始配送时间'',
      completed_at DATETIME DEFAULT NULL COMMENT ''完成时间'',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uk_order_no (order_no),
      INDEX idx_room_id (room_id),
      INDEX idx_status (status),
      INDEX idx_created_at (created_at),
      CONSTRAINT fk_delivery_room FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  '
);

PREPARE stmt_create_delivery FROM @sql_create_delivery;
EXECUTE stmt_create_delivery;
DEALLOCATE PREPARE stmt_create_delivery;

-- 2. 检查并移除 item_category 字段（如果存在）
SET @item_category_exists = (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'delivery_orders' AND COLUMN_NAME = 'item_category'
);

SET @sql_drop_item_category = IF(
  @item_category_exists > 0,
  'ALTER TABLE delivery_orders DROP COLUMN item_category',
  'SELECT ''item_category column does not exist or already removed'' AS status'
);

PREPARE stmt_drop_item_category FROM @sql_drop_item_category;
EXECUTE stmt_drop_item_category;
DEALLOCATE PREPARE stmt_drop_item_category;

-- 3. 添加/更新 started_delivering_at 字段
SET @started_delivering_exists = (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'delivery_orders' AND COLUMN_NAME = 'started_delivering_at'
);

SET @sql_add_started_delivering = IF(
  @started_delivering_exists > 0,
  'SELECT ''started_delivering_at column already exists'' AS status',
  'ALTER TABLE delivery_orders ADD COLUMN started_delivering_at DATETIME DEFAULT NULL COMMENT ''开始配送时间'' AFTER status'
);

PREPARE stmt_add_started_delivering FROM @sql_add_started_delivering;
EXECUTE stmt_add_started_delivering;
DEALLOCATE PREPARE stmt_add_started_delivering;

-- 4. 确保 item_name 字段存在且为 NOT NULL
SET @item_name_exists = (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'delivery_orders' AND COLUMN_NAME = 'item_name'
);

SET @sql_ensure_item_name = IF(
  @item_name_exists > 0,
  'ALTER TABLE delivery_orders MODIFY COLUMN item_name VARCHAR(200) NOT NULL COMMENT ''商品名称（自由输入，不做分类限制）''',
  'ALTER TABLE delivery_orders ADD COLUMN item_name VARCHAR(200) NOT NULL COMMENT ''商品名称（自由输入，不做分类限制）'' AFTER guest_id'
);

PREPARE stmt_ensure_item_name FROM @sql_ensure_item_name;
EXECUTE stmt_ensure_item_name;
DEALLOCATE PREPARE stmt_ensure_item_name;

-- 5. 为 bookings 表添加 user_id 字段（如果不存在）
SET @user_id_exists = (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bookings' AND COLUMN_NAME = 'user_id'
);

SET @sql_add_user_id = IF(
  @user_id_exists > 0,
  'SELECT ''user_id column already exists in bookings'' AS status',
  'ALTER TABLE bookings ADD COLUMN user_id INT DEFAULT NULL COMMENT ''关联用户ID（前台办理入住时关联）'' AFTER hotel_id'
);

PREPARE stmt_add_user_id FROM @sql_add_user_id;
EXECUTE stmt_add_user_id;
DEALLOCATE PREPARE stmt_add_user_id;

-- 6. 为 bookings.user_id 添加索引和外键约束
SET @idx_bookings_user_id_exists = (
  SELECT COUNT(*)
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bookings' AND INDEX_NAME = 'idx_bookings_user_id'
);

SET @sql_idx_bookings_user_id = IF(
  @idx_bookings_user_id_exists > 0,
  'SELECT ''index idx_bookings_user_id already exists'' AS status',
  'CREATE INDEX idx_bookings_user_id ON bookings(user_id)'
);

PREPARE stmt_idx_bookings_user_id FROM @sql_idx_bookings_user_id;
EXECUTE stmt_idx_bookings_user_id;
DEALLOCATE PREPARE stmt_idx_bookings_user_id;

SET @fk_bookings_user_exists = (
  SELECT COUNT(*)
  FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bookings' AND CONSTRAINT_NAME = 'fk_bookings_user_id'
);

SET @sql_fk_bookings_user = IF(
  @fk_bookings_user_exists > 0,
  'SELECT ''foreign key fk_bookings_user_id already exists'' AS status',
  'ALTER TABLE bookings ADD CONSTRAINT fk_bookings_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL'
);

PREPARE stmt_fk_bookings_user FROM @sql_fk_bookings_user;
EXECUTE stmt_fk_bookings_user;
DEALLOCATE PREPARE stmt_fk_bookings_user;

-- 7. 更新 delivery_orders 表注释（说明状态流转）
ALTER TABLE delivery_orders MODIFY COLUMN status VARCHAR(20) NOT NULL DEFAULT 'pending'
  COMMENT '状态流转: pending→delivering→completed, pending→cancelled';

-- 迁移完成提示
SELECT '✅ 数据库迁移完成 - 送物订单优化 & 预订用户关联增强 (v2026-04-10)' AS migration_status;
SELECT '  • delivery_orders 表已创建/更新' AS detail1;
SELECT '  • item_category 字段已移除（不再强制分类）' AS detail2;
SELECT '  • item_name 改为自由输入（不做分类限制）' AS detail3;
SELECT '  • started_delivering_at 字段已添加（配送状态追踪）' AS detail4;
SELECT '  • bookings.user_id 字段已添加（支持前台入住关联用户）' AS detail5;