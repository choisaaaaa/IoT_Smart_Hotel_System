-- 智慧酒店物联网控制系统 - 演示数据脚本
USE iot_hotel_system;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 1;

-- ----------------------------
-- 7. 演示数据
-- ----------------------------

-- 角色
INSERT INTO roles (role_name, role_description, permissions) VALUES
('system_admin', '系统管理员，拥有所有权限', JSON_ARRAY('read','write','delete','manage_users','manage_roles','manage_devices','view_reports','system_config')),
('hotel_admin', '酒店管理员，拥有酒店管理权限', JSON_ARRAY('read','write','manage_bookings','manage_rooms','manage_orders','view_reports','manage_guests','hotel_manage')),
('staff', '酒店员工，拥有业务操作权限', JSON_ARRAY('read','write','manage_bookings','manage_rooms','manage_orders','view_reports','manage_guests')),
('customer', '顾客，拥有基本服务权限', JSON_ARRAY('read','manage_own_bookings','manage_own_profile','use_services'));

INSERT INTO users (username, password, email, role, permissions) VALUES
('admin', '$2a$10$N9qo8uLOickg2ZARZ5XpSOp/VOJJPYJZTqPqIwMf8KFNhFqXjQK7m', 'admin@iot-hotel.com', 'system_admin', JSON_ARRAY('read','write','delete','manage_users','manage_devices','view_reports')),
('user', '$2a$10$N9qo8uLOickg2ZARZ5XpSOp/VOJJPYJZTqPqIwMf8KFNhFqXjQK7m', 'user@iot-hotel.com', 'customer', JSON_ARRAY('read','manage_own_bookings'));

INSERT INTO user_roles (user_id, role_id) VALUES (1, 1), (2, 4);

-- 酒店
INSERT INTO hotels (hotel_name, hotel_address, hotel_phone, hotel_star, total_rooms, occupied_rooms, occupancy_rate, description) 
VALUES ('智联酒店 (旗舰店)', '北京市朝阳区科技园路 88 号', '010-12345678', 5, 200, 87, 43.50, '智慧酒店物联网控制系统示范酒店，提供全屋智能语音控制与极速自助入住体验');

-- 房间
INSERT INTO rooms (room_number, room_type, room_name, room_price, room_status, floor, area, bed_type, max_guests, description, facilities) VALUES
('101', 'standard', '智选大床房', 299.00, 'available', 1, 25.00, 'king', 2, '高性价比智能客房', JSON_ARRAY('WiFi','智能音箱','空调','电视')),
('201', 'deluxe', '豪华景观房', 499.00, 'available', 2, 35.00, 'king', 2, '配备落地窗与全屋智能调光', JSON_ARRAY('WiFi','智能音箱','浴缸','阳台')),
('301', 'suite', '行政智能套房', 899.00, 'available', 3, 60.00, 'king', 3, '尊享独立客厅与智能客控终端', JSON_ARRAY('WiFi','智能音箱','浴缸','办公区','厨房'));
