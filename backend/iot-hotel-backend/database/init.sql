-- 智慧酒店物联网控制系统 - 数据库初始化脚本
-- 数据库架构版本: v2.6.0
-- 适配多酒店隔离、AI管家、动态价格日历、会员系统

CREATE DATABASE IF NOT EXISTS iot_hotel_system DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE iot_hotel_system;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- -----------------------------------------------------------------------------
-- 清理旧表 (按依赖顺序倒序)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS login_sessions;
DROP TABLE IF EXISTS api_tokens;
DROP TABLE IF EXISTS sensor_data;
DROP TABLE IF EXISTS control_commands;
DROP TABLE IF EXISTS devices;
DROP TABLE IF EXISTS maintenance_tickets;
DROP TABLE IF EXISTS delivery_orders;
DROP TABLE IF EXISTS calls;
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS guests;
DROP TABLE IF EXISTS bookings;
DROP TABLE IF EXISTS room_prices;
DROP TABLE IF EXISTS rooms;
DROP TABLE IF EXISTS member_coupons;
DROP TABLE IF EXISTS coupons;
DROP TABLE IF EXISTS room_types;
DROP TABLE IF EXISTS floors;
DROP TABLE IF EXISTS user_hotels;
DROP TABLE IF EXISTS user_roles;
DROP TABLE IF EXISTS roles;
DROP TABLE IF EXISTS members;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS hotels;
DROP TABLE IF EXISTS system_settings;

-- -----------------------------------------------------------------------------
-- 1. 酒店信息表 (Hotels)
-- -----------------------------------------------------------------------------
CREATE TABLE hotels (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hotel_name VARCHAR(100) NOT NULL,
    hotel_address VARCHAR(255) DEFAULT NULL,
    hotel_phone VARCHAR(20) DEFAULT NULL,
    hotel_star INT DEFAULT 3,
    total_rooms INT DEFAULT 0,
    occupied_rooms INT DEFAULT 0,
    occupancy_rate DECIMAL(5,2) DEFAULT 0.00,
    logo VARCHAR(255) DEFAULT NULL,
    description TEXT DEFAULT NULL,
    hotel_code VARCHAR(50) DEFAULT NULL,
    city VARCHAR(100) DEFAULT NULL,
    location VARCHAR(255) DEFAULT NULL,
    star_rating INT DEFAULT 3,
    rating DECIMAL(3,2) DEFAULT 4.50,
    review_count INT DEFAULT 0,
    image_url VARCHAR(255) DEFAULT NULL,
    promotion VARCHAR(255) DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    hotel_id INT DEFAULT NULL COMMENT '兼容旧字段',
    UNIQUE KEY uk_hotel_name (hotel_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 2. 用户信息表 (Users)
-- -----------------------------------------------------------------------------
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    password VARCHAR(255) NOT NULL,
    phone VARCHAR(20) DEFAULT NULL,
    uid VARCHAR(50) DEFAULT NULL,
    email VARCHAR(100) DEFAULT NULL,
    avatar VARCHAR(255) DEFAULT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'customer',
    hotel_id INT DEFAULT 0 COMMENT '0表示系统管理员，>0表示所属酒店ID',
    permissions JSON DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_username (username),
    UNIQUE KEY uk_phone (phone),
    UNIQUE KEY uk_uid (uid),
    INDEX idx_hotel_id (hotel_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 3. 房型信息表 (Room Types)
-- -----------------------------------------------------------------------------
CREATE TABLE room_types (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hotel_id INT NOT NULL DEFAULT 0 COMMENT '0表示集团全局房型，>0表示酒店自定义房型',
    name VARCHAR(50) NOT NULL,
    code VARCHAR(20) NOT NULL,
    base_price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    area DECIMAL(6,2) DEFAULT NULL,
    bed_type VARCHAR(20) DEFAULT 'single',
    max_guests INT DEFAULT 1,
    facilities JSON DEFAULT NULL,
    description TEXT DEFAULT NULL,
    images JSON DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_hotel_type_code (hotel_id, code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 4. 房间信息表 (Rooms)
-- -----------------------------------------------------------------------------
CREATE TABLE rooms (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hotel_id INT NOT NULL,
    room_number VARCHAR(20) NOT NULL,
    room_type VARCHAR(20) NOT NULL DEFAULT 'standard',
    room_type_id INT DEFAULT NULL,
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
    image_url VARCHAR(255) DEFAULT NULL,
    room_id INT DEFAULT NULL COMMENT '兼容硬件端ID',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_hotel_room (hotel_id, room_number),
    INDEX idx_room_status (room_status),
    INDEX idx_room_type (room_type),
    CONSTRAINT fk_room_type_ref FOREIGN KEY (room_type_id) REFERENCES room_types(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 5. 价格日历表 (Room Prices)
-- -----------------------------------------------------------------------------
CREATE TABLE room_prices (
    id INT AUTO_INCREMENT PRIMARY KEY,
    room_type_id INT NOT NULL,
    hotel_id INT NOT NULL,
    price_date DATE NOT NULL,
    discount_rate DECIMAL(3,2) DEFAULT 1.00,
    base_price DECIMAL(10,2) NOT NULL,
    final_price DECIMAL(10,2) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_room_type_date (room_type_id, price_date),
    INDEX idx_hotel_date (hotel_id, price_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 6. 预订表 (Bookings)
-- -----------------------------------------------------------------------------
CREATE TABLE bookings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    booking_number VARCHAR(50) NOT NULL,
    user_id INT DEFAULT NULL,
    room_id INT NOT NULL,
    hotel_id INT NOT NULL,
    guest_name VARCHAR(100) NOT NULL,
    guest_phone VARCHAR(20) NOT NULL,
    guest_id_number VARCHAR(50) DEFAULT NULL,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    guest_count INT DEFAULT 1,
    special_requests VARCHAR(255) DEFAULT NULL,
    payment_method VARCHAR(20) DEFAULT 'balance',
    coupon_id INT DEFAULT NULL,
    used_points INT DEFAULT 0,
    points_discount DECIMAL(10,2) DEFAULT 0.00,
    total_price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    deposit DECIMAL(10,2) DEFAULT 0.00,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    check_in_time DATETIME DEFAULT NULL,
    check_out_time DATETIME DEFAULT NULL,
    cancelled_at DATETIME DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_booking_number (booking_number),
    INDEX idx_hotel_status (hotel_id, status),
    INDEX idx_room_id (room_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 7. 实际住客表 (Guests - 与预订表解耦，支持同房间多住客及硬件同步)
-- -----------------------------------------------------------------------------
CREATE TABLE guests (
    id INT AUTO_INCREMENT PRIMARY KEY,
    booking_id INT NOT NULL,
    guest_name VARCHAR(100) NOT NULL,
    guest_phone VARCHAR(20) NOT NULL,
    guest_id_number VARCHAR(50) DEFAULT NULL,
    room_id INT NOT NULL,
    check_in_time DATETIME NOT NULL,
    check_out_time DATETIME DEFAULT NULL,
    guest_count INT DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_booking_id (booking_id),
    INDEX idx_room_id (room_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 8. 支付表 (Payments)
-- -----------------------------------------------------------------------------
CREATE TABLE payments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hotel_id INT NOT NULL DEFAULT 1,
    payment_no VARCHAR(50) NOT NULL,
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
    UNIQUE KEY uk_payment_no (payment_no),
    INDEX idx_hotel_order (hotel_id, order_type, order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 9. 会员资产表 (Members)
-- -----------------------------------------------------------------------------
CREATE TABLE members (
    id INT AUTO_INCREMENT PRIMARY KEY,
    phone VARCHAR(20) NOT NULL,
    password VARCHAR(255) DEFAULT NULL,
    name VARCHAR(100) DEFAULT NULL,
    id_number VARCHAR(50) DEFAULT NULL,
    member_level ENUM('standard', 'silver', 'gold', 'platinum', 'diamond') DEFAULT 'standard',
    experience INT DEFAULT 0,
    points INT NOT NULL DEFAULT 0,
    balance DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    total_spent DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total_stays INT NOT NULL DEFAULT 0,
    last_checkin_date DATE DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_member_phone (phone)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 会员等级配色方案配置 (可选)
INSERT INTO system_settings (config_key, config_value, description) 
VALUES ('color_standard', '#4b6cb7', '普通会员主色'),
       ('color_silver', '#bdc3c7', '银会员主色'),
       ('color_gold', '#d4af37', '金会员主色'),
       ('color_platinum', '#e5e4e2', '铂金会员主色'),
       ('color_diamond', '#30cfd0', '钻石会员主色');

-- -----------------------------------------------------------------------------
-- 10. 优惠券定义表 (Coupons)
-- -----------------------------------------------------------------------------
CREATE TABLE coupons (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hotel_id INT DEFAULT 0 COMMENT '0表示集团通用券，>0表示门店专属券',
    coupon_name VARCHAR(100) NOT NULL,
    coupon_code VARCHAR(50) DEFAULT NULL,
    coupon_type ENUM('discount','cash') DEFAULT 'discount',
    discount_value DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    min_amount DECIMAL(10,2) DEFAULT 0.00,
    total_count INT NOT NULL DEFAULT 0,
    received_count INT NOT NULL DEFAULT 0,
    is_multiple_use TINYINT(1) DEFAULT 0,
    valid_from DATE NOT NULL,
    valid_to DATE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_coupon_code (coupon_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 11. 会员领券表 (Member Coupons)
-- -----------------------------------------------------------------------------
CREATE TABLE member_coupons (
    id INT AUTO_INCREMENT PRIMARY KEY,
    member_id INT NOT NULL,
    coupon_id INT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'unused',
    used_at DATETIME DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_member_id (member_id),
    INDEX idx_coupon_id (coupon_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 12. 物联网设备表 (Devices)
-- -----------------------------------------------------------------------------
CREATE TABLE devices (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    device_type VARCHAR(20) NOT NULL,
    device_name VARCHAR(50) NOT NULL,
    device_key VARCHAR(50) NOT NULL,
    device_status VARCHAR(20) NOT NULL DEFAULT 'offline',
    firmware_version VARCHAR(20) DEFAULT NULL,
    last_seen DATETIME DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_device_id (device_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 13. 传感器数据表 (Sensor Data)
-- -----------------------------------------------------------------------------
CREATE TABLE sensor_data (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    sensor_type VARCHAR(20) NOT NULL,
    sensor_value VARCHAR(50) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_device_time (device_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 14. 报修工单表 (Maintenance Tickets)
-- -----------------------------------------------------------------------------
CREATE TABLE maintenance_tickets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ticket_no VARCHAR(50) NOT NULL,
    booking_id INT DEFAULT NULL,
    guest_id INT DEFAULT NULL,
    room_id INT NOT NULL,
    fault_type VARCHAR(50) NOT NULL DEFAULT 'other',
    fault_description TEXT DEFAULT NULL,
    photos JSON DEFAULT NULL,
    priority VARCHAR(20) NOT NULL DEFAULT 'medium',
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    repairer VARCHAR(50) DEFAULT NULL,
    assigned_at DATETIME DEFAULT NULL,
    completed_at DATETIME DEFAULT NULL,
    repair_description TEXT DEFAULT NULL,
    repair_cost DECIMAL(10,2) DEFAULT 0.00,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_ticket_no (ticket_no),
    INDEX idx_room_id (room_id),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 15. 系统配置表 (System Settings)
-- -----------------------------------------------------------------------------
CREATE TABLE system_settings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    config_key VARCHAR(50) NOT NULL,
    config_value TEXT DEFAULT NULL,
    description VARCHAR(255) DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_config_key (config_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 16. API 访问令牌表 (API Tokens)
-- -----------------------------------------------------------------------------
CREATE TABLE api_tokens (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    token VARCHAR(255) NOT NULL,
    token_type VARCHAR(50) DEFAULT 'login',
    expires_at DATETIME NOT NULL,
    is_used TINYINT(1) DEFAULT 0,
    used_at DATETIME DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_token (token),
    INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 初始化基础数据
-- -----------------------------------------------------------------------------

-- 默认集团总部 (Hotel ID: 0 系统管理员所在逻辑层，Hotel ID: 1 默认首家门店)
INSERT INTO hotels (id, hotel_name, hotel_star, description) VALUES (1, '智联酒店旗舰店', 5, '智慧物联网样板店');

-- 默认系统管理员 (密码: admin123)
INSERT INTO users (username, password, role, hotel_id) 
VALUES ('sys_admin', '$2a$10$p0M96fI3D0eI8V1v.H6o7u/8h6Q6q5n0V8i1W5a4C0g7Y6e5f4a3b', 'system_admin', 0);

-- 系统全局配置
INSERT INTO system_settings (config_key, config_value, description) 
VALUES ('member_program_name', '智联尊享会', '会员计划名称'),
       ('points_rate', '1', '消费1元获得积分数'),
       ('points_redeem_rate', '10', '多少积分抵扣1元'),
       ('checkin_points', '50', '每日签到获得积分数');

SET FOREIGN_KEY_CHECKS = 1;
