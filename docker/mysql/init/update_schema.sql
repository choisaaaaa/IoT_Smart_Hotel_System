-- 智慧酒店物联网控制系统 - 数据库更新脚本
-- 版本: v2.1.0
-- 更新内容：添加预订和住客关联字段、语音通话表、传感器数据分区

USE iot_hotel_system;

-- 1. 添加住客表（guests）
CREATE TABLE IF NOT EXISTS guests (
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
    FOREIGN KEY (room_id) REFERENCES rooms(id) ON DELETE CASCADE,
    INDEX idx_booking_id (booking_id),
    INDEX idx_room_id (room_id),
    INDEX idx_check_in_time (check_in_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. 更新送物订单表（delivery_orders）：添加预订和住客关联字段
ALTER TABLE delivery_orders 
ADD COLUMN booking_id INT NULL COMMENT '预订ID（关联bookings表，用于退房结算）' AFTER order_no,
ADD COLUMN guest_id INT NULL COMMENT '住客ID（关联guests表，用于服务归属）' AFTER booking_id;

-- 添加索引
ALTER TABLE delivery_orders 
ADD INDEX idx_booking_id (booking_id),
ADD INDEX idx_guest_id (guest_id);

-- 3. 更新报修工单表（maintenance_tickets）：添加预订和住客关联字段
ALTER TABLE maintenance_tickets 
ADD COLUMN booking_id INT NULL COMMENT '预订ID（关联bookings表，用于退房结算）' AFTER ticket_no,
ADD COLUMN guest_id INT NULL COMMENT '住客ID（关联guests表，用于服务归属）' AFTER booking_id;

-- 添加索引
ALTER TABLE maintenance_tickets 
ADD INDEX idx_booking_id (booking_id),
ADD INDEX idx_guest_id (guest_id);

-- 4. 创建语音通话表（calls）
CREATE TABLE IF NOT EXISTS calls (
    id INT PRIMARY KEY AUTO_INCREMENT,
    call_id VARCHAR(64) NOT NULL UNIQUE COMMENT '唯一通话ID (UUID)',
    caller_type ENUM('room','front_desk') NOT NULL COMMENT '主叫方类型',
    caller_id VARCHAR(64) NOT NULL COMMENT '主叫标识(房间号/员工ID)',
    callee_type ENUM('room','front_desk') NOT NULL COMMENT '被叫方类型',
    callee_id VARCHAR(64) NOT NULL COMMENT '被叫标识',
    status ENUM('calling','outgoing','ringing','connected','ended','rejected','missed','busy') DEFAULT 'calling' COMMENT '通话状态',
    started_at DATETIME NOT NULL COMMENT '通话开始时间',
    answered_at DATETIME NULL COMMENT '接听时间',
    ended_at DATETIME NULL COMMENT '结束时间',
    duration_sec INT DEFAULT 0 COMMENT '通话时长(秒)',
    recording_url VARCHAR(512) NULL COMMENT '录音文件URL(可选)',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    INDEX idx_caller (caller_type, caller_id),
    INDEX idx_callee (callee_type, callee_id),
    INDEX idx_status (status),
    INDEX idx_started_at (started_at),
    INDEX idx_caller_time (caller_type, caller_id, started_at),
    INDEX idx_callee_time (callee_type, callee_id, started_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 5. 添加默认索引
CREATE INDEX idx_rooms_status ON rooms(room_status);
CREATE INDEX idx_rooms_type ON rooms(room_type);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_date ON bookings(check_in_date, check_out_date);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_members_level ON members(member_level);
