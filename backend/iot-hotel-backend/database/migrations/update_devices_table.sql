-- 智慧酒店物联网控制系统 - 设备表更新脚本
-- 版本: v2.3.0
-- 更新内容：添加设备注册审核与区域分配相关字段

USE iot_hotel_system;

-- 1. 更新 devices 表，添加审核与分配字段
ALTER TABLE devices 
ADD COLUMN audit_status ENUM('pending', 'approved', 'rejected') NOT NULL DEFAULT 'pending' COMMENT '审核状态',
ADD COLUMN room_id INT NULL COMMENT '关联房间ID',
ADD COLUMN area VARCHAR(50) NULL COMMENT '所属区域',
ADD COLUMN ip_address VARCHAR(45) NULL COMMENT '上报IP地址',
ADD COLUMN mac_address VARCHAR(17) NULL COMMENT '设备MAC地址',
ADD CONSTRAINT fk_device_room FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE SET NULL;

-- 2. 添加索引
ALTER TABLE devices 
ADD INDEX idx_audit_status (audit_status),
ADD INDEX idx_room_id (room_id),
ADD INDEX idx_mac_address (mac_address);
