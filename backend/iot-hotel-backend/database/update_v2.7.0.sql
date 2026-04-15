-- MQTT 通信记录表
CREATE TABLE IF NOT EXISTS mqtt_communication_logs (
    id INT PRIMARY KEY AUTO_INCREMENT,
    hotel_id INT DEFAULT 0,
    device_id VARCHAR(50),
    topic VARCHAR(255) NOT NULL,
    payload TEXT,
    direction ENUM('in', 'out') NOT NULL,
    qos INT DEFAULT 0,
    retain TINYINT(1) DEFAULT 0,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_topic (topic),
    INDEX idx_device_id (device_id),
    INDEX idx_timestamp (timestamp)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 扩展控制指令表 (如果不存在，或者增加更多字段)
-- 实际上 schema.sql 已经有 control_commands 了，这里确保它包含所需字段
ALTER TABLE control_commands ADD COLUMN IF NOT EXISTS hotel_id INT DEFAULT 0;
ALTER TABLE control_commands ADD INDEX IF NOT EXISTS idx_hotel_id (hotel_id);
