-- 智慧酒店物联网控制系统 - 数据库初始化脚本
-- 版本: v2.0.0

-- 创建数据库
CREATE DATABASE IF NOT EXISTS iot_hotel_system CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 使用数据库
USE iot_hotel_system;

-- 创建用户
CREATE USER IF NOT EXISTS 'iot_user'@'%' IDENTIFIED BY 'iot_password';
GRANT ALL PRIVILEGES ON iot_hotel_system.* TO 'iot_user'@'%';
FLUSH PRIVILEGES;

-- 1. 酒店信息表（hotels）
CREATE TABLE IF NOT EXISTS hotels (
    id INT PRIMARY KEY AUTO_INCREMENT,
    hotel_name VARCHAR(100) NOT NULL UNIQUE,
    hotel_address VARCHAR(255),
    hotel_phone VARCHAR(20),
    hotel_star INT DEFAULT 3,
    total_rooms INT DEFAULT 0,
    occupied_rooms INT DEFAULT 0,
    occupancy_rate DECIMAL(5,2) DEFAULT 0.00,
    logo VARCHAR(255),
    description TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. 房间信息表（rooms）
CREATE TABLE IF NOT EXISTS rooms (
    id INT PRIMARY KEY AUTO_INCREMENT,
    room_number VARCHAR(20) NOT NULL UNIQUE,
    room_type VARCHAR(20) DEFAULT 'standard',
    room_name VARCHAR(100),
    room_price DECIMAL(10,2) DEFAULT 0.00,
    room_status VARCHAR(20) DEFAULT 'available',
    floor INT DEFAULT 1,
    area DECIMAL(6,2),
    bed_type VARCHAR(20) DEFAULT 'single',
    max_guests INT DEFAULT 1,
    description TEXT,
    facilities JSON,
    images JSON,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. 预订表（bookings）
CREATE TABLE IF NOT EXISTS bookings (
    id INT PRIMARY KEY AUTO_INCREMENT,
    booking_number VARCHAR(50) NOT NULL UNIQUE,
    room_id INT NOT NULL,
    guest_name VARCHAR(100) NOT NULL,
    guest_phone VARCHAR(20) NOT NULL,
    guest_id_number VARCHAR(50),
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    guest_count INT DEFAULT 1,
    special_requests VARCHAR(255),
    payment_method VARCHAR(20) DEFAULT 'balance',
    total_price DECIMAL(10,2) DEFAULT 0.00,
    deposit DECIMAL(10,2) DEFAULT 0.00,
    status VARCHAR(20) DEFAULT 'pending',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    check_in_time DATETIME,
    check_out_time DATETIME,
    cancelled_at DATETIME,
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. 支付表（payments）
CREATE TABLE IF NOT EXISTS payments (
    id INT PRIMARY KEY AUTO_INCREMENT,
    payment_no VARCHAR(50) NOT NULL UNIQUE,
    order_type VARCHAR(20) DEFAULT 'booking',
    order_id INT NOT NULL,
    amount DECIMAL(10,2) DEFAULT 0.00,
    payment_method VARCHAR(20) DEFAULT 'wechat',
    status VARCHAR(20) DEFAULT 'pending',
    transaction_no VARCHAR(100),
    paid_at DATETIME,
    description VARCHAR(255),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 5. 会员表（members）
CREATE TABLE IF NOT EXISTS members (
    id INT PRIMARY KEY AUTO_INCREMENT,
    phone VARCHAR(20) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(100),
    id_number VARCHAR(50),
    member_level VARCHAR(20) DEFAULT 'standard',
    points INT DEFAULT 0,
    balance DECIMAL(10,2) DEFAULT 0.00,
    total_spent DECIMAL(12,2) DEFAULT 0.00,
    total_stays INT DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 6. 优惠券表（coupons）
CREATE TABLE IF NOT EXISTS coupons (
    id INT PRIMARY KEY AUTO_INCREMENT,
    coupon_name VARCHAR(100) NOT NULL,
    coupon_type VARCHAR(20) DEFAULT 'discount',
    discount_value DECIMAL(10,2) DEFAULT 0.00,
    min_amount DECIMAL(10,2) DEFAULT 0.00,
    total_count INT DEFAULT 0,
    received_count INT DEFAULT 0,
    valid_from DATE NOT NULL,
    valid_to DATE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 7. 会员优惠券关联表（member_coupons）
CREATE TABLE IF NOT EXISTS member_coupons (
    id INT PRIMARY KEY AUTO_INCREMENT,
    member_id INT NOT NULL,
    coupon_id INT NOT NULL,
    status VARCHAR(20) DEFAULT 'unused',
    used_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
    FOREIGN KEY (coupon_id) REFERENCES coupons(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 8. 送物订单表（delivery_orders）
CREATE TABLE IF NOT EXISTS delivery_orders (
    id INT PRIMARY KEY AUTO_INCREMENT,
    order_no VARCHAR(50) NOT NULL UNIQUE,
    room_id INT NOT NULL,
    item_category VARCHAR(50) DEFAULT 'food',
    item_name VARCHAR(100) NOT NULL,
    quantity INT DEFAULT 1,
    note VARCHAR(255),
    status VARCHAR(20) DEFAULT 'pending',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    completed_at DATETIME,
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 9. 报修工单表（maintenance_tickets）
CREATE TABLE IF NOT EXISTS maintenance_tickets (
    id INT PRIMARY KEY AUTO_INCREMENT,
    ticket_no VARCHAR(50) NOT NULL UNIQUE,
    room_id INT NOT NULL,
    fault_type VARCHAR(50) DEFAULT 'other',
    fault_description TEXT,
    photos JSON,
    priority VARCHAR(20) DEFAULT 'medium',
    status VARCHAR(20) DEFAULT 'pending',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    completed_at DATETIME,
    repair_description TEXT,
    repair_cost DECIMAL(10,2) DEFAULT 0.00,
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 10. 服务评价表（reviews）
CREATE TABLE IF NOT EXISTS reviews (
    id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    order_type VARCHAR(20) DEFAULT 'booking',
    member_id INT,
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
    FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 10.1 评价申诉表（review_appeals）
CREATE TABLE IF NOT EXISTS review_appeals (
    id INT PRIMARY KEY AUTO_INCREMENT,
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 11. 设备表（devices）
CREATE TABLE IF NOT EXISTS devices (
    id INT PRIMARY KEY AUTO_INCREMENT,
    device_id VARCHAR(50) NOT NULL UNIQUE,
    device_type VARCHAR(20) NOT NULL DEFAULT 'main',
    device_name VARCHAR(50) NOT NULL,
    device_key VARCHAR(50) NOT NULL,
    device_status VARCHAR(20) DEFAULT 'offline',
    firmware_version VARCHAR(20),
    last_seen DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 12. 传感器数据表（sensor_data）
CREATE TABLE IF NOT EXISTS sensor_data (
    id INT PRIMARY KEY AUTO_INCREMENT,
    device_id VARCHAR(50) NOT NULL,
    sensor_type VARCHAR(20) NOT NULL,
    sensor_value VARCHAR(50) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_device_id (device_id),
    INDEX idx_sensor_type (sensor_type),
    INDEX idx_created_at (created_at),
    INDEX idx_device_sensor (device_id, sensor_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 13. 控制指令表（control_commands）
CREATE TABLE IF NOT EXISTS control_commands (
    id INT PRIMARY KEY AUTO_INCREMENT,
    device_id VARCHAR(50) NOT NULL,
    command_type VARCHAR(20) NOT NULL,
    command_value VARCHAR(50) NOT NULL,
    command_status VARCHAR(20) DEFAULT 'pending',
    created_by VARCHAR(50),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    executed_at DATETIME,
    INDEX idx_device_id (device_id),
    INDEX idx_created_at (created_at),
    INDEX idx_command_status (command_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 14. 用户表（users）
CREATE TABLE IF NOT EXISTS users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100),
    role VARCHAR(20) DEFAULT 'customer',
    permissions JSON,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 15. 安防事件表（security_events）
CREATE TABLE IF NOT EXISTS security_events (
    id INT PRIMARY KEY AUTO_INCREMENT,
    device_id VARCHAR(50) NOT NULL,
    event_type VARCHAR(20) NOT NULL,
    event_data TEXT,
    event_level VARCHAR(20) DEFAULT 'info',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_device_id (device_id),
    INDEX idx_created_at (created_at),
    INDEX idx_event_type (event_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 16. 设备认证表（device_auth）
CREATE TABLE IF NOT EXISTS device_auth (
    id INT PRIMARY KEY AUTO_INCREMENT,
    device_id VARCHAR(50) NOT NULL UNIQUE,
    token VARCHAR(255) NOT NULL,
    expires_at DATETIME NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_token (token),
    INDEX idx_expires_at (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 17. 系统日志表（system_logs）
CREATE TABLE IF NOT EXISTS system_logs (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT,
    device_id VARCHAR(50),
    operation VARCHAR(50) NOT NULL,
    operation_data TEXT,
    ip_address VARCHAR(45),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_device_id (device_id),
    INDEX idx_created_at (created_at),
    INDEX idx_operation (operation)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 18. 配网记录表（network_config）
CREATE TABLE IF NOT EXISTS network_config (
    id INT PRIMARY KEY AUTO_INCREMENT,
    device_id VARCHAR(50) NOT NULL,
    ssid VARCHAR(100) NOT NULL,
    signal_strength INT,
    config_method VARCHAR(20) NOT NULL,
    config_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'success',
    INDEX idx_device_id (device_id),
    INDEX idx_config_time (config_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 插入初始数据

-- 插入默认酒店信息
INSERT INTO hotels (hotel_name, hotel_address, hotel_phone, hotel_star, total_rooms, occupied_rooms, occupancy_rate) 
VALUES ('智联酒店', '北京市朝阳区XX路XX号', '010-12345678', 4, 100, 45, 45.00);

-- 插入默认房间
INSERT INTO rooms (room_number, room_type, room_name, room_price, room_status, floor, area, bed_type, max_guests, description, facilities) 
VALUES 
('101', 'standard', '标准单人房', 299.00, 'available', 1, 25.5, 'single', 1, '舒适的标准单人房', '["WiFi","电视","空调","电话"]'),
('102', 'standard', '标准双人房', 399.00, 'available', 1, 35.0, 'double', 2, '舒适的标准双人房', '["WiFi","电视","空调","电话"]'),
('201', 'deluxe', '豪华单人房', 499.00, 'available', 2, 45.0, 'single', 1, '豪华单人房', '["WiFi","电视","空调","电话","迷你吧"]'),
('202', 'deluxe', '豪华双人房', 599.00, 'available', 2, 55.0, 'double', 2, '豪华双人房', '["WiFi","电视","空调","电话","迷你吧"]'),
('301', 'suite', '豪华套房', 899.00, 'available', 3, 80.0, 'king', 3, '豪华套房', '["WiFi","电视","空调","电话","迷你吧","浴缸"]');

-- 插入默认用户
INSERT INTO users (username, password, email, role, permissions) 
VALUES ('admin', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'admin@example.com', 'system_admin', '["read","write","delete"]');

-- 插入默认设备
INSERT INTO devices (device_id, device_type, device_name, device_key, device_status, firmware_version) 
VALUES 
('MAIN001', 'main', '前台管理端', 'key_main_001', 'online', 'v1.0.0'),
('SUB1001', 'sub1', '楼控设备1', 'key_sub1_001', 'online', 'v1.0.0'),
('SUB2001', 'sub2', '客房端设备1', 'key_sub2_001', 'online', 'v1.0.0');

-- 插入默认会员
INSERT INTO members (phone, password, name, id_number, member_level, points, balance, total_spent, total_stays) 
VALUES ('13800138000', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '张三', '110101199001011234', 'standard', 100, 50.00, 1000.00, 5);

-- 插入默认优惠券
INSERT INTO coupons (coupon_name, coupon_type, discount_value, min_amount, total_count, received_count, valid_from, valid_to) 
VALUES ('满200减50优惠券', 'discount', 50.00, 200.00, 1000, 500, '2024-01-18', '2024-02-18');
