CREATE DATABASE IF NOT EXISTS iot_hotel_system DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE iot_hotel_system;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS security_events;
DROP TABLE IF EXISTS control_commands;
DROP TABLE IF EXISTS sensor_data;
DROP TABLE IF EXISTS devices;
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS maintenance_tickets;
DROP TABLE IF EXISTS delivery_orders;
DROP TABLE IF EXISTS member_coupons;
DROP TABLE IF EXISTS coupons;
DROP TABLE IF EXISTS members;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS bookings;
DROP TABLE IF EXISTS rooms;
DROP TABLE IF EXISTS room_types;
DROP TABLE IF EXISTS floors;
DROP TABLE IF EXISTS hotels;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS calls;

-- 1. 酒店信息表
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
    rating DECIMAL(3,2) DEFAULT 4.50,
    review_count INT DEFAULT 0,
    image_url VARCHAR(255) DEFAULT NULL,
    promotion VARCHAR(255) DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_hotel_name (hotel_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. 房型信息表
CREATE TABLE room_types (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    code VARCHAR(50) NOT NULL UNIQUE,
    base_price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    area INT DEFAULT 0,
    bed_type VARCHAR(50) DEFAULT 'single',
    max_guests INT DEFAULT 1,
    facilities JSON DEFAULT NULL,
    description TEXT DEFAULT NULL,
    images JSON DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. 楼层信息表
CREATE TABLE floors (
    id INT AUTO_INCREMENT PRIMARY KEY,
    floor_number INT NOT NULL UNIQUE,
    floor_name VARCHAR(50) NOT NULL,
    floor_plan_image VARCHAR(255) DEFAULT NULL,
    description TEXT DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. 房间信息表
CREATE TABLE rooms (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hotel_id INT NOT NULL DEFAULT 1,
    room_number VARCHAR(20) NOT NULL,
    room_type VARCHAR(20) DEFAULT 'standard',
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
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_hotel_room (hotel_id, room_number),
    INDEX idx_room_status (room_status),
    INDEX idx_room_type (room_type),
    CONSTRAINT fk_room_type FOREIGN KEY (room_type_id) REFERENCES room_types(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. 预订表
CREATE TABLE bookings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    booking_number VARCHAR(50) NOT NULL,
    hotel_id INT NOT NULL DEFAULT 1,
    user_id INT DEFAULT NULL COMMENT '关联用户ID（前台办理入住时关联）',
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
    UNIQUE KEY uk_booking_number (booking_number),
    INDEX idx_room_id (room_id),
    INDEX idx_user_id (user_id),
    INDEX idx_status (status),
    INDEX idx_check_in_date (check_in_date),
    INDEX idx_check_out_date (check_out_date),
    CONSTRAINT fk_bookings_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6. 支付表
CREATE TABLE payments (
    id INT AUTO_INCREMENT PRIMARY KEY,
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
    INDEX idx_order (order_type, order_id),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 7. 会员表
CREATE TABLE members (
    id INT AUTO_INCREMENT PRIMARY KEY,
    phone VARCHAR(20) NOT NULL,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(100) DEFAULT NULL,
    id_number VARCHAR(50) DEFAULT NULL,
    member_level VARCHAR(20) NOT NULL DEFAULT 'standard',
    points INT NOT NULL DEFAULT 0,
    balance DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    total_spent DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total_stays INT NOT NULL DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_phone (phone),
    INDEX idx_member_level (member_level)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 8. 报修工单表
CREATE TABLE maintenance_tickets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ticket_no VARCHAR(50) NOT NULL,
    room_id INT NOT NULL,
    fault_type VARCHAR(50) NOT NULL DEFAULT 'other',
    fault_description TEXT DEFAULT NULL,
    photos JSON DEFAULT NULL,
    priority VARCHAR(20) NOT NULL DEFAULT 'medium',
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    repairer VARCHAR(50) DEFAULT NULL,
    assigned_at DATETIME DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    completed_at DATETIME DEFAULT NULL,
    repair_description TEXT DEFAULT NULL,
    repair_cost DECIMAL(10,2) DEFAULT 0.00,
    UNIQUE KEY uk_ticket_no (ticket_no),
    INDEX idx_room_id (room_id),
    INDEX idx_status (status),
    INDEX idx_priority (priority),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 9. 送物订单表
CREATE TABLE delivery_orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_no VARCHAR(50) NOT NULL,
    room_id INT NOT NULL,
    booking_id INT DEFAULT NULL,
    guest_id INT DEFAULT NULL,
    item_name VARCHAR(200) NOT NULL COMMENT '商品名称（自由输入，不做分类限制）',
    quantity INT NOT NULL DEFAULT 1 COMMENT '数量',
    note TEXT DEFAULT NULL COMMENT '备注',
    status VARCHAR(20) NOT NULL DEFAULT 'pending' COMMENT '状态流转: pending→delivering→completed, pending→cancelled',
    started_delivering_at DATETIME DEFAULT NULL COMMENT '开始配送时间',
    completed_at DATETIME DEFAULT NULL COMMENT '完成时间',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_order_no (order_no),
    INDEX idx_room_id (room_id),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at),
    CONSTRAINT fk_delivery_room FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 10. 用户表
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) DEFAULT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'user',
    permissions JSON DEFAULT NULL,
    hotel_id INT DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_username (username),
    INDEX idx_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 初始演示数据插入 (略，保持与 README 同步即可)

SET FOREIGN_KEY_CHECKS = 1;
