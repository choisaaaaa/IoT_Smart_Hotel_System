-- 智慧酒店物联网控制系统 - 房型与楼层管理更新脚本
-- 版本: v2.4.0
-- 更新内容：添加房型管理表，支持楼层索引

USE iot_hotel_system;

-- 1. 创建房型表
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

-- 2. 从现有数据导入房型 (尝试性导入)
INSERT IGNORE INTO room_types (name, code, base_price, area, bed_type, max_guests)
SELECT DISTINCT room_type, room_type, room_price, area, bed_type, max_guests FROM rooms;

-- 3. 修改 rooms 表，添加房型 ID 关联
ALTER TABLE rooms ADD COLUMN room_type_id INT AFTER room_type;

-- 4. 建立关联数据
UPDATE rooms r 
JOIN room_types rt ON r.room_type = rt.code 
SET r.room_type_id = rt.id;

-- 5. 添加外键与索引
ALTER TABLE rooms ADD CONSTRAINT fk_room_type FOREIGN KEY (room_type_id) REFERENCES room_types(id) ON DELETE SET NULL;
CREATE INDEX idx_room_floor ON rooms(floor);

-- 6. (可选) 如果不再需要旧的 room_type 字符串字段，可以删除，但为了兼容性先保留
-- ALTER TABLE rooms DROP COLUMN room_type;
