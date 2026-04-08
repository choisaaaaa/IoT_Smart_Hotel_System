CREATE TABLE IF NOT EXISTS roles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE COMMENT '角色名称 (admin/staff/user)',
    role_description VARCHAR(255) DEFAULT NULL COMMENT '角色描述',
    permissions JSON DEFAULT NULL COMMENT '权限列表',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='角色表';

CREATE TABLE IF NOT EXISTS user_roles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL COMMENT '用户 ID',
    role_id INT NOT NULL COMMENT '角色 ID',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_user_role (user_id, role_id),
    INDEX idx_user_id (user_id),
    INDEX idx_role_id (role_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户角色关联表';

CREATE TABLE IF NOT EXISTS api_tokens (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL COMMENT '用户 ID',
    token VARCHAR(255) NOT NULL UNIQUE COMMENT 'API Token',
    token_type VARCHAR(50) DEFAULT 'login' COMMENT 'Token 类型 (login/api/refresh)',
    expires_at DATETIME NOT NULL COMMENT '过期时间',
    is_used TINYINT(1) DEFAULT 0 COMMENT '是否已使用',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    used_at DATETIME DEFAULT NULL COMMENT '使用时间',
    INDEX idx_token (token),
    INDEX idx_user_id (user_id),
    INDEX idx_expires_at (expires_at),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='API Token 表';

CREATE TABLE IF NOT EXISTS login_sessions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL COMMENT '用户 ID',
    session_token VARCHAR(255) NOT NULL UNIQUE COMMENT '会话 Token',
    device_info VARCHAR(255) DEFAULT NULL COMMENT '设备信息',
    ip_address VARCHAR(50) DEFAULT NULL COMMENT 'IP 地址',
    expires_at DATETIME NOT NULL COMMENT '过期时间',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_active_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '最后活跃时间',
    INDEX idx_session_token (session_token),
    INDEX idx_user_id (user_id),
    INDEX idx_expires_at (expires_at),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='登录会话表';

-- 初始化角色数据
INSERT INTO roles (role_name, role_description, permissions) VALUES
('admin', '系统管理员，拥有所有权限', '["read","write","delete","manage_users","manage_roles","manage_devices","view_reports","system_config"]'),
('staff', '酒店员工，拥有业务操作权限', '["read","write","manage_bookings","manage_rooms","manage_orders","view_reports","manage_guests"]'),
('user', '普通用户，拥有基础权限', '["read","manage_own_bookings","manage_own_profile","use_services"]');

-- 更新现有用户的角色关联
INSERT INTO user_roles (user_id, role_id) 
SELECT u.id, r.id 
FROM users u 
CROSS JOIN roles r 
WHERE (u.username = 'admin' AND r.role_name = 'admin')
   OR (u.username = 'staff01' AND r.role_name = 'staff');

-- 更新 users 表的权限字段 (保留向后兼容)
UPDATE users u
JOIN user_roles ur ON u.id = ur.user_id
JOIN roles r ON ur.role_id = r.id
SET u.role = r.role_name,
    u.permissions = r.permissions
WHERE u.id = ur.user_id;
