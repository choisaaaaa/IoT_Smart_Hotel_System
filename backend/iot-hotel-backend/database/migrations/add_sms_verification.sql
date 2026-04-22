-- 添加短信验证码相关表结构

-- 创建短信验证码表
CREATE TABLE IF NOT EXISTS sms_verifications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    phone VARCHAR(20) NOT NULL COMMENT '手机号',
    verification_code VARCHAR(10) NOT NULL COMMENT '验证码',
    verification_type VARCHAR(50) NOT NULL COMMENT '验证类型（password_reset, login, register等）',
    expires_at DATETIME NOT NULL COMMENT '过期时间',
    used TINYINT(1) DEFAULT 0 COMMENT '是否已使用（0:未使用，1:已使用）',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_phone_type (phone, verification_type),
    INDEX idx_expires_at (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='短信验证码表';

-- 添加系统设置项
INSERT INTO system_settings (config_key, config_value, description) VALUES
('sms_verification_enabled', 'true', '是否启用短信验证'),
('sms_verification_expire_minutes', '10', '短信验证码过期时间（分钟）'),
('sms_verification_resend_interval', '60', '重新发送短信验证码间隔（秒）'),
('sms_verification_max_attempts', '5', '短信验证码最大尝试次数');

-- 添加密码重置相关的系统设置
INSERT INTO system_settings (config_key, config_value, description) VALUES
('password_reset_require_sms', 'true', '密码重置是否需要短信验证'),
('password_reset_token_expire_hours', '24', '密码重置令牌过期时间（小时）');