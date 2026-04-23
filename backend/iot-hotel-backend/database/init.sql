-- 智慧酒店物联网控制系统 - 数据库初始化脚本
-- 数据库架构版本: v3.6.0 (统一完整版)
-- 创建日期: 2026-04-23
-- 说明: 合并所有表结构为单一文件，包含全部53张表定义

CREATE DATABASE IF NOT EXISTS iot_hotel_system DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE iot_hotel_system;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- -----------------------------------------------------------------------------
-- 清理旧表 (按依赖顺序倒序)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS ai_conversations;
DROP TABLE IF EXISTS ai_knowledge_entries;
DROP TABLE IF EXISTS ai_knowledge_base;
DROP TABLE IF EXISTS hotel_images;
DROP TABLE IF EXISTS login_sessions;
DROP TABLE IF EXISTS api_tokens;
DROP TABLE IF EXISTS sensor_data;
DROP TABLE IF EXISTS control_commands;
DROP TABLE IF EXISTS card_lifecycle_logs;
DROP TABLE IF EXISTS staff_access_policies;
DROP TABLE IF EXISTS door_security_states;
DROP TABLE IF EXISTS occupancy_verification;
DROP TABLE IF EXISTS rfid_access_logs;
DROP TABLE IF EXISTS rfid_cards;
DROP TABLE IF EXISTS scene_configs;
DROP TABLE IF EXISTS devices;
DROP TABLE IF EXISTS device_groups;
DROP TABLE IF EXISTS device_group_members;
DROP TABLE IF EXISTS device_alarms;
DROP TABLE IF EXISTS ir_remote_codes;
DROP TABLE IF EXISTS firmware_updates;
DROP TABLE IF EXISTS device_status_history;
DROP TABLE IF EXISTS energy_consumption;
DROP TABLE IF EXISTS scene_execution_logs;
DROP TABLE IF EXISTS call_quality_logs;
DROP TABLE IF EXISTS maintenance_tickets;
DROP TABLE IF EXISTS delivery_orders;
DROP TABLE IF EXISTS calls;
DROP TABLE IF EXISTS mqtt_communication_logs;
DROP TABLE IF EXISTS review_appeals;
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS guests;
DROP TABLE IF EXISTS frequent_guests;
DROP TABLE IF EXISTS bookings;
DROP TABLE IF EXISTS room_prices;
DROP TABLE IF EXISTS rate_plans;
DROP TABLE IF EXISTS rooms;
DROP TABLE IF EXISTS user_favorites;
DROP TABLE IF EXISTS member_coupons;
DROP TABLE IF EXISTS coupons;
DROP TABLE IF EXISTS room_types;
DROP TABLE IF EXISTS floors;
DROP TABLE IF EXISTS role_applications;
DROP TABLE IF EXISTS user_hotels;
DROP TABLE IF EXISTS user_roles;
DROP TABLE IF EXISTS roles;
DROP TABLE IF EXISTS members;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS hotels;
DROP TABLE IF EXISTS system_settings;
DROP TABLE IF EXISTS sms_verifications;
DROP TABLE IF EXISTS security_events;
DROP TABLE IF EXISTS device_auth;
DROP TABLE IF EXISTS system_logs;
DROP TABLE IF EXISTS network_config;

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
    last_login_at DATETIME DEFAULT NULL COMMENT '最后登录时间',
    UNIQUE KEY uk_username (username),
    UNIQUE KEY uk_phone (phone),
    UNIQUE KEY uk_uid (uid),
    INDEX idx_hotel_id (hotel_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 3. 角色表 (Roles)
-- -----------------------------------------------------------------------------
CREATE TABLE roles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE,
    role_description VARCHAR(255) DEFAULT NULL,
    permissions JSON DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 4. 用户角色关联表 (User Roles)
-- -----------------------------------------------------------------------------
CREATE TABLE user_roles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    role_id INT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_user_role (user_id, role_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 5. 用户酒店关联表 (User Hotels)
-- -----------------------------------------------------------------------------
CREATE TABLE user_hotels (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    hotel_id INT NOT NULL,
    role VARCHAR(20) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_user_hotel (user_id, hotel_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 5a. 角色/入驻申请表 (Role Applications)
-- -----------------------------------------------------------------------------
CREATE TABLE role_applications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    application_type VARCHAR(20) NOT NULL,
    hotel_id INT DEFAULT NULL,
    hotel_name VARCHAR(100) DEFAULT NULL,
    hotel_address VARCHAR(255) DEFAULT NULL,
    reason VARCHAR(500) DEFAULT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    reviewed_by INT DEFAULT NULL,
    reviewed_at DATETIME DEFAULT NULL,
    review_note VARCHAR(500) DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_hotel_id (hotel_id),
    INDEX idx_status (status),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 6. 楼层表 (Floors)
-- -----------------------------------------------------------------------------
CREATE TABLE floors (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hotel_id INT NOT NULL,
    floor_number INT NOT NULL,
    floor_name VARCHAR(50) DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_hotel_floor (hotel_id, floor_number),
    FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 7. 房型信息表 (Room Types)
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
-- 7a. 价格方案表 (Rate Plans)
-- -----------------------------------------------------------------------------
CREATE TABLE rate_plans (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hotel_id INT NOT NULL,
    room_type_id INT NOT NULL,
    plan_name VARCHAR(100) NOT NULL,
    base_price DECIMAL(10,2) DEFAULT 0.00,
    meal_plan ENUM('none', 'breakfast', 'half_board', 'full_board') DEFAULT 'none',
    breakfast_count INT DEFAULT 0,
    cancellation_policy ENUM('free', 'no_cancel', 'restricted') DEFAULT 'free',
    cancel_time_limit INT DEFAULT 0,
    payment_type ENUM('all', 'online_only', 'front_desk_only') DEFAULT 'all',
    is_guaranteed TINYINT(1) DEFAULT 0,
    prepayment_ratio DECIMAL(5,2) DEFAULT 0.00,
    is_active TINYINT(1) DEFAULT 1,
    default_inventory INT DEFAULT 10,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_hotel_id (hotel_id),
    FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE,
    FOREIGN KEY (room_type_id) REFERENCES room_types(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 8. 房间信息表 (Rooms)
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
    INDEX idx_hotel_id (hotel_id),
    CONSTRAINT fk_room_hotel FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE,
    CONSTRAINT fk_room_type_ref FOREIGN KEY (room_type_id) REFERENCES room_types(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 9. 价格日历表 (Room Prices)
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
-- 10. 预订表 (Bookings)
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
    INDEX idx_room_id (room_id),
    INDEX idx_checkin_checkout (check_in_date, check_out_date),
    CONSTRAINT fk_booking_room FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 11. 实际住客表 (Guests)
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
    INDEX idx_room_id (room_id),
    CONSTRAINT fk_guest_booking FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
    CONSTRAINT fk_guest_room FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 11a. 常住人表 (Frequent Guests)
-- -----------------------------------------------------------------------------
CREATE TABLE frequent_guests (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    id_type VARCHAR(50) DEFAULT 'idcard',
    id_number VARCHAR(50) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 12. 支付表 (Payments)
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
-- 13. 服务评价表 (Reviews)
-- -----------------------------------------------------------------------------
CREATE TABLE reviews (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    order_type VARCHAR(20) DEFAULT 'booking',
    member_id INT DEFAULT NULL,
    hotel_id INT DEFAULT NULL,
    room_type_id INT DEFAULT NULL,
    user_id INT DEFAULT NULL,
    score DECIMAL(2,1) DEFAULT 5.0,
    environment_rating INT DEFAULT 5 COMMENT '环境评分1-5',
    facility_rating INT DEFAULT 5 COMMENT '设施评分1-5',
    comfort_rating INT DEFAULT 5 COMMENT '舒适评分1-5',
    content TEXT,
    photos JSON,
    reply TEXT DEFAULT NULL,
    replied_at DATETIME DEFAULT NULL,
    is_deleted TINYINT(1) DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_hotel_id (hotel_id),
    INDEX idx_user_id (user_id),
    INDEX idx_order_id (order_id),
    FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 14. 评价申诉表 (Review Appeals)
-- -----------------------------------------------------------------------------
CREATE TABLE review_appeals (
    id INT AUTO_INCREMENT PRIMARY KEY,
    review_id INT NOT NULL,
    hotel_id INT NOT NULL,
    appellant_id INT NOT NULL,
    appeal_reason TEXT NOT NULL,
    status ENUM('pending', 'approved', 'rejected') DEFAULT 'pending',
    handler_id INT DEFAULT NULL,
    handle_reason TEXT DEFAULT NULL,
    handled_at DATETIME DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_review_id (review_id),
    INDEX idx_hotel_id (hotel_id),
    INDEX idx_status (status),
    FOREIGN KEY (review_id) REFERENCES reviews(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 15. 会员资产表 (Members)
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

-- -----------------------------------------------------------------------------
-- 16. 优惠券定义表 (Coupons)
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
-- 17. 会员领券表 (Member Coupons)
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
    INDEX idx_coupon_id (coupon_id),
    FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
    FOREIGN KEY (coupon_id) REFERENCES coupons(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 17a. 用户收藏表 (User Favorites)
-- -----------------------------------------------------------------------------
CREATE TABLE user_favorites (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    hotel_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_hotel_id (hotel_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 18. 物联网设备表 (Devices)
-- -----------------------------------------------------------------------------
CREATE TABLE devices (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    device_type VARCHAR(20) NOT NULL,
    device_name VARCHAR(50) NOT NULL,
    device_key VARCHAR(255) NOT NULL COMMENT '设备密钥哈希存储',
    device_status VARCHAR(20) NOT NULL DEFAULT 'offline',
    firmware_version VARCHAR(20) DEFAULT NULL,
    last_seen DATETIME DEFAULT NULL,
    audit_status VARCHAR(20) DEFAULT 'pending' COMMENT '设备审核状态: pending/approved/rejected',
    hotel_id INT DEFAULT 0 COMMENT '设备所属酒店ID',
    room_id INT DEFAULT NULL COMMENT '关联房间ID',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_device_id (device_id),
    INDEX idx_device_status (device_status),
    INDEX idx_hotel_id (hotel_id),
    INDEX idx_audit_status (audit_status),
    INDEX idx_device_hotel_status (device_status, hotel_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 19. 设备组表 (Device Groups)
-- -----------------------------------------------------------------------------
CREATE TABLE device_groups (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hotel_id INT NOT NULL,
    group_name VARCHAR(50) NOT NULL,
    group_type VARCHAR(20) NOT NULL COMMENT '按房间/按楼层/自定义',
    description TEXT DEFAULT NULL,
    created_by INT DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_hotel_id (hotel_id),
    FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 20. 设备组成员表 (Device Group Members)
-- -----------------------------------------------------------------------------
CREATE TABLE device_group_members (
    id INT AUTO_INCREMENT PRIMARY KEY,
    group_id INT NOT NULL,
    device_id VARCHAR(50) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_group_device (group_id, device_id),
    FOREIGN KEY (group_id) REFERENCES device_groups(id) ON DELETE CASCADE,
    FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 21. 设备告警表 (Device Alarms)
-- -----------------------------------------------------------------------------
CREATE TABLE device_alarms (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    alarm_type VARCHAR(50) NOT NULL,
    alarm_level ENUM('info', 'warning', 'critical') DEFAULT 'warning',
    message TEXT NOT NULL,
    is_acknowledged TINYINT(1) DEFAULT 0,
    acknowledged_by INT DEFAULT NULL,
    acknowledged_at DATETIME DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_device_id (device_id),
    INDEX idx_alarm_level (alarm_level),
    INDEX idx_created_at (created_at),
    FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 22. 红外遥控码表 (IR Remote Codes)
-- -----------------------------------------------------------------------------
CREATE TABLE ir_remote_codes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    brand VARCHAR(50) NOT NULL,
    device_type VARCHAR(20) NOT NULL COMMENT 'ac/tv/projector等',
    code_name VARCHAR(50) NOT NULL,
    code_data JSON NOT NULL COMMENT '红外编码数据',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_device_brand (device_id, brand),
    FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 23. 固件更新表 (Firmware Updates)
-- -----------------------------------------------------------------------------
CREATE TABLE firmware_updates (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_type VARCHAR(20) NOT NULL,
    version VARCHAR(20) NOT NULL,
    file_url VARCHAR(255) NOT NULL,
    file_size INT DEFAULT 0,
    checksum VARCHAR(64) DEFAULT NULL COMMENT 'SHA256校验值',
    release_notes TEXT DEFAULT NULL,
    is_force_update TINYINT(1) DEFAULT 0,
    status ENUM('draft', 'released', 'archived') DEFAULT 'draft',
    created_by INT DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_device_type (device_type),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 24. 设备状态历史表 (Device Status History)
-- -----------------------------------------------------------------------------
CREATE TABLE device_status_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    old_status VARCHAR(20) NOT NULL,
    new_status VARCHAR(20) NOT NULL,
    reason VARCHAR(255) DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_device_id (device_id),
    INDEX idx_created_at (created_at),
    FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 25. 能耗记录表 (Energy Consumption)
-- -----------------------------------------------------------------------------
CREATE TABLE energy_consumption (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    energy_type VARCHAR(20) NOT NULL COMMENT 'electricity/water/gas',
    consumption_value DECIMAL(10,2) NOT NULL,
    unit VARCHAR(10) NOT NULL DEFAULT 'kWh',
    recorded_at DATETIME NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_device_time (device_id, recorded_at),
    INDEX idx_energy_type (energy_type),
    FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 26. 场景执行日志表 (Scene Execution Logs)
-- -----------------------------------------------------------------------------
CREATE TABLE scene_execution_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    scene_id INT NOT NULL,
    device_id VARCHAR(50) NOT NULL,
    action VARCHAR(50) NOT NULL,
    status ENUM('success', 'failed', 'timeout') NOT NULL,
    error_message TEXT DEFAULT NULL,
    executed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_scene_id (scene_id),
    INDEX idx_executed_at (executed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 27. 传感器数据表 (Sensor Data)
-- -----------------------------------------------------------------------------
CREATE TABLE sensor_data (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    sensor_type VARCHAR(20) NOT NULL,
    sensor_value VARCHAR(50) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_device_time (device_id, created_at),
    INDEX idx_created_at_device (created_at, device_id),
    FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 28. 控制指令表 (Control Commands)
-- -----------------------------------------------------------------------------
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
    INDEX idx_created_at (created_at),
    INDEX idx_command_status (command_status),
    FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 29. 房卡管理表 (RFID Cards)
-- -----------------------------------------------------------------------------
CREATE TABLE rfid_cards (
    id INT AUTO_INCREMENT PRIMARY KEY,
    card_uid VARCHAR(50) NOT NULL,
    hotel_id INT NOT NULL,
    booking_id INT DEFAULT NULL,
    room_id INT DEFAULT NULL,
    member_id INT DEFAULT NULL,
    card_type ENUM('guest', 'master', 'floor', 'staff') DEFAULT 'guest',
    status ENUM('active', 'inactive', 'lost') DEFAULT 'active',
    issued_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_card_uid (card_uid),
    INDEX idx_hotel_card (hotel_id),
    INDEX idx_booking_card (booking_id),
    CONSTRAINT fk_rfid_hotel FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 29a. 房卡门禁记录表 (RFID Access Logs)
-- -----------------------------------------------------------------------------
CREATE TABLE rfid_access_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    card_uid VARCHAR(50) NOT NULL,
    room_id INT DEFAULT NULL,
    hotel_id INT NOT NULL,
    access_type ENUM('entry', 'exit', 'denied') NOT NULL,
    access_result ENUM('success', 'failed', 'expired', 'invalid') NOT NULL,
    identity_type ENUM('guest', 'staff', 'visitor', 'illegal') DEFAULT 'guest',
    fail_reason VARCHAR(100) DEFAULT NULL,
    device_id VARCHAR(50) DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_card_uid (card_uid),
    INDEX idx_room_id (room_id),
    INDEX idx_hotel_id (hotel_id),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 29b. 房卡全生命周期审计表 (Card Lifecycle Logs)
-- -----------------------------------------------------------------------------
CREATE TABLE card_lifecycle_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    card_uid VARCHAR(50) NOT NULL,
    hotel_id INT NOT NULL,
    action_type ENUM('issue', 'recycle', 'lost', 'reset', 'activate', 'deactivate') NOT NULL,
    operator_id INT DEFAULT NULL,
    target_booking_id INT DEFAULT NULL,
    target_user_id INT DEFAULT NULL,
    notes VARCHAR(255) DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_card_uid (card_uid),
    INDEX idx_hotel_action (hotel_id, action_type),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 29c. 员工访问策略表 (Staff Access Policies)
-- -----------------------------------------------------------------------------
CREATE TABLE staff_access_policies (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hotel_id INT NOT NULL,
    user_id INT NOT NULL,
    access_scope ENUM('all', 'floor', 'room_list', 'public_area') NOT NULL DEFAULT 'room_list',
    scope_value TEXT DEFAULT NULL,
    time_slots JSON DEFAULT NULL,
    is_emergency TINYINT(1) DEFAULT 0,
    is_active TINYINT(1) DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_user_hotel (user_id, hotel_id),
    INDEX idx_active_status (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 29d. 门锁状态表 (Door Security States)
-- -----------------------------------------------------------------------------
CREATE TABLE door_security_states (
    id INT AUTO_INCREMENT PRIMARY KEY,
    room_id INT NOT NULL UNIQUE,
    device_id VARCHAR(50) NOT NULL,
    lock_state ENUM('closed', 'open', 'unlocked_timeout', 'forced_open') NOT NULL DEFAULT 'closed',
    internal_deadbolt TINYINT(1) DEFAULT 0,
    battery_level TINYINT DEFAULT 100,
    last_event_type ENUM('rfid', 'app', 'physical_key', 'remote', 'button') DEFAULT 'rfid',
    last_event_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_lock_battery (lock_state, battery_level),
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 29e. 房间占用校验表 (Occupancy Verification)
-- -----------------------------------------------------------------------------
CREATE TABLE occupancy_verification (
    id INT AUTO_INCREMENT PRIMARY KEY,
    room_id INT NOT NULL UNIQUE,
    booking_id INT DEFAULT NULL,
    last_pir_activity DATETIME DEFAULT NULL,
    last_card_power_state TINYINT(1) DEFAULT 0,
    last_energy_pulse DATETIME DEFAULT NULL,
    discrepancy_flag TINYINT(1) DEFAULT 0,
    verified_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_discrepancy (discrepancy_flag),
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 30. 场景配置表 (Scene Configs)
-- -----------------------------------------------------------------------------
CREATE TABLE scene_configs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hotel_id INT NOT NULL,
    scene_name VARCHAR(50) NOT NULL,
    scene_code VARCHAR(50) NOT NULL,
    config_json JSON NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_hotel_scene (hotel_id, scene_code),
    CONSTRAINT fk_scene_hotel FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 31. 通话记录表 (Calls)
-- -----------------------------------------------------------------------------
CREATE TABLE calls (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hotel_id INT NOT NULL,
    call_id VARCHAR(50) NOT NULL,
    caller_type ENUM('room', 'front_desk', 'ai', 'app') NOT NULL,
    caller_id VARCHAR(50) NOT NULL,
    callee_type ENUM('room', 'front_desk', 'ai', 'app') NOT NULL,
    callee_id VARCHAR(50) NOT NULL,
    status ENUM('calling', 'outgoing', 'ringing', 'connected', 'ended', 'rejected', 'missed', 'busy') DEFAULT 'calling',
    started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    answered_at DATETIME DEFAULT NULL,
    ended_at DATETIME DEFAULT NULL,
    duration_sec INT DEFAULT 0,
    recording_url VARCHAR(255) DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_call_id (call_id),
    INDEX idx_hotel_call (hotel_id),
    CONSTRAINT fk_call_hotel FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 32. 通话质量日志表 (Call Quality Logs)
-- -----------------------------------------------------------------------------
CREATE TABLE call_quality_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    call_id VARCHAR(50) NOT NULL,
    mos_score DECIMAL(3,2) DEFAULT NULL COMMENT '语音质量评分1-5',
    jitter_ms INT DEFAULT NULL COMMENT '抖动毫秒',
    packet_loss_pct DECIMAL(5,2) DEFAULT NULL COMMENT '丢包率',
    latency_ms INT DEFAULT NULL COMMENT '延迟毫秒',
    recorded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_call_id (call_id),
    INDEX idx_recorded_at (recorded_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 33. MQTT 通信日志表 (MQTT Logs)
-- -----------------------------------------------------------------------------
CREATE TABLE mqtt_communication_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hotel_id INT DEFAULT 0,
    device_id VARCHAR(50) DEFAULT NULL,
    topic VARCHAR(255) NOT NULL,
    payload TEXT DEFAULT NULL,
    direction ENUM('in', 'out') NOT NULL,
    qos TINYINT DEFAULT 0,
    retain TINYINT DEFAULT 0,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_device_topic (device_id, topic),
    INDEX idx_timestamp (timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 34. 送物订单表 (Delivery Orders)
-- -----------------------------------------------------------------------------
CREATE TABLE delivery_orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_no VARCHAR(50) NOT NULL,
    booking_id INT DEFAULT NULL,
    guest_id INT DEFAULT NULL,
    room_id INT NOT NULL,
    item_category VARCHAR(50) NOT NULL DEFAULT 'food',
    item_name VARCHAR(100) NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    note VARCHAR(255) DEFAULT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    completed_at DATETIME DEFAULT NULL,
    UNIQUE KEY uk_order_no (order_no),
    INDEX idx_room_id (room_id),
    INDEX idx_status (status),
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 35. 报修工单表 (Maintenance Tickets)
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
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    completed_at DATETIME DEFAULT NULL,
    repair_description TEXT DEFAULT NULL,
    repair_cost DECIMAL(10,2) DEFAULT 0.00,
    UNIQUE KEY uk_ticket_no (ticket_no),
    INDEX idx_room_id (room_id),
    INDEX idx_status (status),
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 36. 酒店图片表 (Hotel Images)
-- -----------------------------------------------------------------------------
CREATE TABLE hotel_images (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hotel_id INT NOT NULL COMMENT '酒店ID',
    image_url VARCHAR(500) NOT NULL COMMENT '图片URL',
    image_type VARCHAR(20) DEFAULT 'gallery' COMMENT '图片类型: cover-封面, gallery-相册, room-房型',
    sort_order INT DEFAULT 0 COMMENT '排序顺序',
    is_active TINYINT(1) DEFAULT 1 COMMENT '是否启用',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_hotel_id (hotel_id),
    INDEX idx_image_type (image_type),
    FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='酒店图片表';

-- -----------------------------------------------------------------------------
-- 37. AI知识库表 (AI Knowledge Base) - H-05统一表
-- -----------------------------------------------------------------------------
CREATE TABLE ai_knowledge_base (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hotel_id INT NOT NULL DEFAULT 0 COMMENT '酒店ID，0表示全局词条',
    category VARCHAR(50) NOT NULL COMMENT '分类: restaurant-餐厅, facility-设施, policy-政策, activity-活动, other-其他',
    title VARCHAR(200) NOT NULL COMMENT '标题',
    content TEXT NOT NULL COMMENT '知识详细内容（支持Markdown格式）',
    keywords VARCHAR(500) DEFAULT NULL COMMENT '关键词（逗号分隔，用于AI检索匹配）',
    priority INT DEFAULT 0 COMMENT '优先级，数值越大越优先',
    is_active TINYINT(1) DEFAULT 1 COMMENT '是否启用',
    sort_order INT DEFAULT 0 COMMENT '排序权重',
    usage_count INT DEFAULT 0 COMMENT '使用次数统计',
    created_by INT COMMENT '创建者用户ID',
    updated_by INT COMMENT '最后更新者用户ID',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_hotel_id (hotel_id),
    INDEX idx_category (category),
    INDEX idx_is_active (is_active),
    INDEX idx_priority (priority)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='AI知识库表';

-- -----------------------------------------------------------------------------
-- 38. AI对话历史表 (AI Conversations)
-- -----------------------------------------------------------------------------
CREATE TABLE ai_conversations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    session_id VARCHAR(64) NOT NULL COMMENT '会话ID',
    user_id INT COMMENT '用户ID（登录用户）',
    user_type ENUM('guest', 'member', 'staff', 'admin') DEFAULT 'guest' COMMENT '用户类型',
    hotel_id INT DEFAULT 0 COMMENT '关联酒店ID',
    room_id INT COMMENT '关联房间ID',
    message TEXT NOT NULL COMMENT '消息内容',
    role ENUM('user', 'assistant', 'system') NOT NULL COMMENT '消息角色',
    intent VARCHAR(50) COMMENT '识别到的意图',
    matched_entry_id INT COMMENT '匹配到的知识库词条ID',
    tokens_used INT COMMENT '使用的token数',
    response_time_ms INT COMMENT '响应时间（毫秒）',
    is_helpful TINYINT(1) COMMENT '是否有帮助（用户反馈）',
    ip_address VARCHAR(45) COMMENT '用户IP地址',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_session_id (session_id),
    INDEX idx_user_id (user_id),
    INDEX idx_hotel_id (hotel_id),
    INDEX idx_created_at (created_at),
    INDEX idx_intent (intent),
    FOREIGN KEY (matched_entry_id) REFERENCES ai_knowledge_base(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='AI对话历史表';

-- -----------------------------------------------------------------------------
-- 39. API 访问令牌表 (API Tokens)
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
    INDEX idx_user_id (user_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 40. 登录会话表 (Login Sessions)
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- 41. 短信验证码表 (SMS Verifications)
-- -----------------------------------------------------------------------------
CREATE TABLE sms_verifications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    phone VARCHAR(20) NOT NULL,
    verification_code VARCHAR(10) NOT NULL,
    purpose VARCHAR(20) NOT NULL DEFAULT 'reset_password' COMMENT '用途: reset_password, login, register',
    is_used TINYINT(1) DEFAULT 0,
    expires_at DATETIME NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    used_at DATETIME DEFAULT NULL,
    INDEX idx_phone (phone),
    INDEX idx_expires_at (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='短信验证码表';

-- -----------------------------------------------------------------------------
-- 42. 安防事件表 (Security Events)
-- -----------------------------------------------------------------------------
CREATE TABLE security_events (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    event_type VARCHAR(20) NOT NULL,
    event_data TEXT,
    event_level VARCHAR(20) DEFAULT 'info',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_device_id (device_id),
    INDEX idx_created_at (created_at),
    INDEX idx_event_type (event_type),
    FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 43. 系统设置表 (System Settings)
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

-- =============================================================================
-- 初始化基础数据
-- =============================================================================

-- 默认酒店数据
INSERT INTO hotels (id, hotel_name, hotel_star, description) VALUES
(1, '智联酒店旗舰店', 5, '智慧物联网样板店'),
(2, '无畏电竞酒店', 4, '专业电竞主题酒店');

-- 默认系统管理员 (密码: 123123)
INSERT INTO users (username, password, phone, role, hotel_id) VALUES
('sys_admin1', '$2a$10$p0M96fI3D0eI8V1v.H6o7u/8h6Q6q5n0V8i1W5a4C0g7Y6e5f4a3b', '13900000001', 'system_admin', 0);

-- 角色初始化
INSERT INTO roles (role_name, role_description, permissions) VALUES
('system_admin', '系统管理员，拥有所有权限', '["read","write","delete","manage_users","manage_roles","manage_devices","view_reports","system_config"]'),
('hotel_admin', '酒店管理员，拥有酒店管理权限', '["read","write","manage_bookings","manage_rooms","manage_orders","view_reports","manage_guests","hotel_manage"]'),
('receptionist', '前台员工，拥有业务操作权限', '["read","write","manage_bookings","manage_rooms","manage_orders","view_reports","manage_guests"]'),
('customer', '顾客，拥有基本服务权限', '["read","manage_own_bookings","manage_own_profile","use_services"]'),
('guest', '住客，拥有房间服务权限', '["read","use_room_services","ai_butler","order_delivery","order_maintenance"]');

-- 系统全局配置
INSERT INTO system_settings (config_key, config_value, description)
VALUES ('member_program_name', '智联尊享会', '会员计划名称'),
       ('points_rate', '1', '消费1元获得积分数'),
       ('points_redeem_rate', '10', '多少积分抵扣1元'),
       ('checkin_points', '50', '每日签到获得积分数');

-- 会员等级配色方案配置 (可选)
INSERT INTO system_settings (config_key, config_value, description)
VALUES ('color_standard', '#4b6cb7', '普通会员主色'),
       ('color_silver', '#bdc3c7', '银会员主色'),
       ('color_gold', '#d4af37', '金会员主色'),
       ('color_platinum', '#e5e4e2', '铂金会员主色'),
       ('color_diamond', '#30cfd0', '钻石会员主色');

SET FOREIGN_KEY_CHECKS = 1;
