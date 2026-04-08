-- 智慧酒店物联网控制系统 - 全量初始化脚本
-- 版本: v2.2.0
-- 包含：数据库结构、认证体系、常用联系人、以及默认演示数据

CREATE DATABASE IF NOT EXISTS iot_hotel_system DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE iot_hotel_system;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- 清理旧表
-- ----------------------------
DROP TABLE IF EXISTS frequent_guests;
DROP TABLE IF EXISTS login_sessions;
DROP TABLE IF EXISTS api_tokens;
DROP TABLE IF EXISTS user_roles;
DROP TABLE IF EXISTS roles;
DROP TABLE IF EXISTS security_events;
DROP TABLE IF EXISTS control_commands;
DROP TABLE IF EXISTS sensor_data;
DROP TABLE IF EXISTS devices;
DROP TABLE IF EXISTS device_auth;
DROP TABLE IF EXISTS calls;
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS maintenance_tickets;
DROP TABLE IF EXISTS delivery_orders;
DROP TABLE IF EXISTS member_coupons;
DROP TABLE IF EXISTS coupons;
DROP TABLE IF EXISTS members;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS guests;
DROP TABLE IF EXISTS bookings;
DROP TABLE IF EXISTS rooms;
DROP TABLE IF EXISTS hotels;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS employees;

-- ----------------------------
-- 1. 酒店与房间
-- ----------------------------
CREATE TABLE hotels (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hotel_name VARCHAR(100) NOT NULL UNIQUE,
    hotel_address VARCHAR(255) DEFAULT NULL,
    hotel_phone VARCHAR(20) DEFAULT NULL,
    hotel_star INT DEFAULT 3,
    total_rooms INT DEFAULT 0,
    occupied_rooms INT DEFAULT 0,
    occupancy_rate DECIMAL(5,2) DEFAULT 0.00,
    logo VARCHAR(255) DEFAULT NULL,
    description TEXT DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE rooms (
    id INT AUTO_INCREMENT PRIMARY KEY,
    room_number VARCHAR(20) NOT NULL UNIQUE,
    room_type VARCHAR(20) NOT NULL DEFAULT 'standard',
    room_name VARCHAR(100) DEFAULT NULL,
    room_price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    room_status VARCHAR(20) NOT NULL DEFAULT 'available',
    floor INT DEFAULT 1,
    area DECIMAL(6,2) DEFAULT NULL,
    bed_type VARCHAR(20) DEFAULT 'single',
    max_guests INT DEFAULT 1,
    description TEXT DEFAULT NULL,
    facilities JSON DEFAULT NULL,
    images JSON DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_room_status (room_status),
    INDEX idx_room_type (room_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------
-- 2. 用户、角色与认证
-- ----------------------------
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) DEFAULT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'user',
    permissions JSON DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE roles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE,
    role_description VARCHAR(255) DEFAULT NULL,
    permissions JSON DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE user_roles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    role_id INT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_user_role (user_id, role_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE api_tokens (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    token VARCHAR(255) NOT NULL UNIQUE,
    token_type VARCHAR(50) DEFAULT 'login',
    expires_at DATETIME NOT NULL,
    is_used TINYINT(1) DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    used_at DATETIME DEFAULT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE login_sessions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    session_token VARCHAR(255) NOT NULL UNIQUE,
    device_info VARCHAR(255) DEFAULT NULL,
    ip_address VARCHAR(50) DEFAULT NULL,
    expires_at DATETIME NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_active_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE frequent_guests (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    id_type ENUM('idcard', 'passport') DEFAULT 'idcard',
    id_number VARCHAR(50) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------
-- 3. 预订与业务
-- ----------------------------
CREATE TABLE bookings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    booking_number VARCHAR(50) NOT NULL UNIQUE,
    room_id INT NOT NULL,
    guest_name VARCHAR(100) NOT NULL,
    guest_phone VARCHAR(20) NOT NULL,
    guest_id_number VARCHAR(50) DEFAULT NULL,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    guest_count INT DEFAULT 1,
    special_requests VARCHAR(255) DEFAULT NULL,
    payment_method VARCHAR(20) DEFAULT 'balance',
    total_price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    deposit DECIMAL(10,2) DEFAULT 0.00,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    check_in_time DATETIME DEFAULT NULL,
    check_out_time DATETIME DEFAULT NULL,
    cancelled_at DATETIME DEFAULT NULL,
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE,
    INDEX idx_status (status),
    INDEX idx_date (check_in_date, check_out_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE guests (
    id INT PRIMARY KEY AUTO_INCREMENT,
    booking_id INT NOT NULL,
    guest_name VARCHAR(100) NOT NULL,
    guest_phone VARCHAR(20) NOT NULL,
    guest_id_number VARCHAR(50),
    room_id INT NOT NULL,
    check_in_time DATETIME NOT NULL,
    check_out_time DATETIME,
    guest_count INT DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE payments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    payment_no VARCHAR(50) NOT NULL UNIQUE,
    order_type VARCHAR(20) NOT NULL DEFAULT 'booking',
    order_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    payment_method VARCHAR(20) NOT NULL DEFAULT 'wechat',
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    transaction_no VARCHAR(100) DEFAULT NULL,
    paid_at DATETIME DEFAULT NULL,
    description VARCHAR(255) DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_order (order_type, order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------
-- 4. 物联网设备与控制
-- ----------------------------
CREATE TABLE devices (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL UNIQUE,
    device_type VARCHAR(20) NOT NULL,
    device_name VARCHAR(50) NOT NULL,
    device_key VARCHAR(50) NOT NULL,
    device_status VARCHAR(20) NOT NULL DEFAULT 'offline',
    firmware_version VARCHAR(20) DEFAULT NULL,
    last_seen DATETIME DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE sensor_data (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    sensor_type VARCHAR(20) NOT NULL,
    sensor_value VARCHAR(50) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_device_sensor (device_id, sensor_type),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE control_commands (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    command_type VARCHAR(20) NOT NULL,
    command_value VARCHAR(50) NOT NULL,
    command_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_by VARCHAR(50) DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    executed_at DATETIME DEFAULT NULL,
    INDEX idx_device_id (device_id),
    INDEX idx_command_status (command_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------
-- 5. 酒店服务 (送物、报修、通话)
-- ----------------------------
CREATE TABLE delivery_orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_no VARCHAR(50) NOT NULL UNIQUE,
    booking_id INT NULL,
    guest_id INT NULL,
    room_id INT NOT NULL,
    item_category VARCHAR(50) NOT NULL DEFAULT 'food',
    item_name VARCHAR(100) NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    note VARCHAR(255) DEFAULT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    completed_at DATETIME DEFAULT NULL,
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE maintenance_tickets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ticket_no VARCHAR(50) NOT NULL UNIQUE,
    booking_id INT NULL,
    guest_id INT NULL,
    room_id INT NOT NULL,
    fault_type VARCHAR(50) NOT NULL DEFAULT 'other',
    fault_description TEXT DEFAULT NULL,
    photos JSON DEFAULT NULL,
    priority VARCHAR(20) NOT NULL DEFAULT 'medium',
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    completed_at DATETIME DEFAULT NULL,
    repair_description TEXT DEFAULT NULL,
    repair_cost DECIMAL(10,2) DEFAULT 0.00,
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE calls (
    id INT AUTO_INCREMENT PRIMARY KEY,
    call_id VARCHAR(64) NOT NULL UNIQUE,
    caller_type ENUM('room', 'front_desk', 'ai', 'app') NOT NULL,
    caller_id VARCHAR(64) NOT NULL,
    callee_type ENUM('room', 'front_desk', 'ai', 'app') NOT NULL,
    callee_id VARCHAR(64) NOT NULL,
    status ENUM('calling', 'outgoing', 'ringing', 'connected', 'ended', 'rejected', 'missed', 'busy') NOT NULL DEFAULT 'calling',
    started_at DATETIME NOT NULL,
    answered_at DATETIME DEFAULT NULL,
    ended_at DATETIME DEFAULT NULL,
    duration_sec INT NOT NULL DEFAULT 0,
    recording_url VARCHAR(512) DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------
-- 6. 会员与优惠券
-- ----------------------------
CREATE TABLE members (
    id INT AUTO_INCREMENT PRIMARY KEY,
    phone VARCHAR(20) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(100) DEFAULT NULL,
    id_number VARCHAR(50) DEFAULT NULL,
    member_level VARCHAR(20) NOT NULL DEFAULT 'standard',
    points INT NOT NULL DEFAULT 0,
    balance DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    total_spent DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total_stays INT NOT NULL DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE coupons (
    id INT AUTO_INCREMENT PRIMARY KEY,
    coupon_name VARCHAR(100) NOT NULL,
    coupon_type VARCHAR(20) NOT NULL DEFAULT 'discount',
    discount_value DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    min_amount DECIMAL(10,2) DEFAULT 0.00,
    total_count INT NOT NULL DEFAULT 0,
    received_count INT NOT NULL DEFAULT 0,
    valid_from DATE NOT NULL,
    valid_to DATE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE member_coupons (
    id INT AUTO_INCREMENT PRIMARY KEY,
    member_id INT NOT NULL,
    coupon_id INT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'unused',
    used_at DATETIME DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
    FOREIGN KEY (coupon_id) REFERENCES coupons(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------
-- 7. 演示数据
-- ----------------------------

-- 角色
INSERT INTO roles (role_name, role_description, permissions) VALUES
('admin', '系统管理员，拥有所有权限', '["read","write","delete","manage_users","manage_roles","manage_devices","view_reports","system_config"]'),
('staff', '酒店员工，拥有业务操作权限', '["read","write","manage_bookings","manage_rooms","manage_orders","view_reports","manage_guests"]'),
('user', '普通用户，拥有基础权限', '["read","manage_own_bookings","manage_own_profile","use_services"]');

-- 用户 (密码均为 bcrypt 加密后的 admin123 / user123)
INSERT INTO users (username, password, email, role, permissions) VALUES
('admin', '$2a$10$N9qo8uLOickg2ZARZ5XpSOp/VOJJPYJZTqPqIwMf8KFNhFqXjQK7m', 'admin@iot-hotel.com', 'admin', '["read","write","delete","manage_users","manage_devices","view_reports"]'),
('user', '$2a$10$N9qo8uLOickg2ZARZ5XpSOp/VOJJPYJZTqPqIwMf8KFNhFqXjQK7m', 'user@iot-hotel.com', 'user', '["read","manage_own_bookings"]');

-- 关联角色
INSERT INTO user_roles (user_id, role_id) VALUES (1, 1), (2, 3);

-- 酒店
INSERT INTO hotels (hotel_name, hotel_address, hotel_phone, hotel_star, total_rooms, occupied_rooms, occupancy_rate, description) 
VALUES ('智联酒店 (旗舰店)', '北京市朝阳区科技园路88号', '010-12345678', 5, 200, 87, 43.50, '智慧酒店物联网控制系统示范酒店，提供全屋智能语音控制与极速自助入住体验');

-- 房间
INSERT INTO rooms (room_number, room_type, room_name, room_price, room_status, floor, area, bed_type, max_guests, description, facilities) VALUES
('101', 'standard', '智选大床房', 299.00, 'available', 1, 25.00, 'king', 2, '高性价比智能客房', '["WiFi","智能音箱","空调","电视"]'),
('201', 'deluxe', '豪华景观房', 499.00, 'available', 2, 35.00, 'king', 2, '配备落地窗与全屋智能调光', '["WiFi","智能音箱","浴缸","阳台"]'),
('301', 'suite', '行政智能套房', 899.00, 'available', 3, 60.00, 'king', 3, '尊享独立客厅与智能客控终端', '["WiFi","智能音箱","浴缸","办公区","厨房"]');

SET FOREIGN_KEY_CHECKS = 1;
