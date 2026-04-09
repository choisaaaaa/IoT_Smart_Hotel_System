-- 智慧酒店物联网控制系统 - 楼层管理更新脚本
-- 版本: v2.5.0
-- 更新内容：添加楼层管理表，支持楼层平面图

USE iot_hotel_system;

-- 1. 创建楼层表
CREATE TABLE IF NOT EXISTS floors (
    id INT AUTO_INCREMENT PRIMARY KEY,
    floor_number INT NOT NULL UNIQUE COMMENT '楼层号',
    floor_name VARCHAR(50) NOT NULL COMMENT '楼层名称',
    floor_plan_image VARCHAR(255) DEFAULT NULL COMMENT '楼层平面图',
    description TEXT DEFAULT NULL COMMENT '描述',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. 从现有 rooms 表中提取楼层数据并初始化 floors 表
INSERT IGNORE INTO floors (floor_number, floor_name, floor_plan_image, description)
SELECT DISTINCT floor, CONCAT(floor, 'F'), '', ''
FROM rooms
WHERE floor IS NOT NULL;

-- 3. 检查 rooms 表中的 floor 字段类型，确保与 floors.floor_number 匹配
-- 在某些版本中，rooms.floor 可能是 VARCHAR 类型，需要确保比较时没有问题
-- 楼层号通常为整数，建议保持一致
