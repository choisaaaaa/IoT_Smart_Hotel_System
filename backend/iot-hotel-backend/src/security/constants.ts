/**
 * 安全相关常量
 */

// JWT配置
export const JWT_CONFIG = {
  MIN_SECRET_LENGTH: 32,
  DEFAULT_EXPIRES_IN: '24h',
  ISSUER: 'iot-hotel-system',
  AUDIENCE: 'iot-hotel-users',
  ALGORITHM: 'HS256' as const
};

// 禁止的弱密钥列表
export const FORBIDDEN_SECRETS = [
  'your_jwt_secret_key_here',
  'your_super_secret_key_change_me',
  'secret',
  'jwt_secret',
  '123456',
  'password',
  'admin',
  'test',
  'default',
  'changeme',
  'iot_hotel',
  'hotel_system'
];

// 密码策略
export const PASSWORD_POLICY = {
  MIN_LENGTH: 6,
  MAX_LENGTH: 128,
  REQUIRE_LETTER: true,
  REQUIRE_NUMBER: true,
  REQUIRE_SPECIAL: false,
  SALT_ROUNDS: 10
};

// 文件上传限制
export const UPLOAD_LIMITS = {
  MAX_FILE_SIZE: 5 * 1024 * 1024, // 5MB
  MAX_FILES: 5,
  ALLOWED_MIME_TYPES: [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp'
  ],
  ALLOWED_EXTENSIONS: ['.jpg', '.jpeg', '.png', '.gif', '.webp']
};

// 速率限制配置
export const RATE_LIMITS = {
  GLOBAL: {
    WINDOW_MS: 60 * 1000, // 1分钟
    MAX_REQUESTS: 1000
  },
  AUTH: {
    WINDOW_MS: 15 * 60 * 1000, // 15分钟
    MAX_REQUESTS: 10
  },
  DEVICE_REGISTER: {
    WINDOW_MS: 60 * 60 * 1000, // 1小时
    MAX_REQUESTS: 50
  }
};

// 设备认证
export const DEVICE_AUTH = {
  TIMESTAMP_TOLERANCE: 5 * 60 * 1000, // 5分钟
  HEADER_DEVICE_ID: 'x-device-id',
  HEADER_DEVICE_KEY: 'x-device-key',
  HEADER_TIMESTAMP: 'x-timestamp',
  HEADER_SIGNATURE: 'x-signature'
};

// CORS配置
export const CORS_CONFIG = {
  ALLOWED_METHODS: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  ALLOWED_HEADERS: [
    'Content-Type',
    'Authorization',
    'X-Device-Id',
    'X-Device-Key',
    'X-Timestamp',
    'X-Signature',
    'X-Request-Id'
  ],
  EXPOSED_HEADERS: ['X-Request-Id'],
  MAX_AGE: 86400 // 24小时
};

// 输入验证限制
export const VALIDATION_LIMITS = {
  MAX_STRING_LENGTH: 65535,
  MAX_ARRAY_LENGTH: 1000,
  MAX_PAGE_SIZE: 100,
  MAX_SEARCH_KEYWORD_LENGTH: 100
};

// 安全头配置
export const SECURITY_HEADERS = {
  HSTS_MAX_AGE: 31536000, // 1年
  CONTENT_SECURITY_POLICY: {
    defaultSrc: ["'self'"],
    styleSrc: ["'self'", "'unsafe-inline'"],
    scriptSrc: ["'self'"],
    imgSrc: ["'self'", "data:", "blob:"],
    connectSrc: ["'self'"],
    fontSrc: ["'self'"],
    objectSrc: ["'none'"],
    mediaSrc: ["'self'"],
    frameSrc: ["'none'"]
  }
};

// MQTT安全配置
export const MQTT_SECURITY = {
  DEFAULT_PORT: 1883,
  TLS_PORT: 8883,
  RECONNECT_ATTEMPTS: 10,
  RECONNECT_DELAY_BASE: 1000,
  KEEPALIVE: 60,
  CONNECT_TIMEOUT: 10000
};

// 会话配置
export const SESSION_CONFIG = {
  TOKEN_EXPIRES_IN: '24h',
  SESSION_EXPIRES_IN: '7d',
  REFRESH_TOKEN_EXPIRES_IN: '30d'
};

// 角色定义
export const ROLES = {
  SYSTEM_ADMIN: 'system_admin',
  HOTEL_ADMIN: 'hotel_admin',
  STAFF: 'staff',
  CUSTOMER: 'customer',
  GUEST: 'guest'
} as const;

// 权限定义
export const PERMISSIONS = {
  // 酒店管理
  HOTEL_CREATE: 'hotel:create',
  HOTEL_READ: 'hotel:read',
  HOTEL_UPDATE: 'hotel:update',
  HOTEL_DELETE: 'hotel:delete',
  
  // 房间管理
  ROOM_CREATE: 'room:create',
  ROOM_READ: 'room:read',
  ROOM_UPDATE: 'room:update',
  ROOM_DELETE: 'room:delete',
  
  // 预订管理
  BOOKING_CREATE: 'booking:create',
  BOOKING_READ: 'booking:read',
  BOOKING_UPDATE: 'booking:update',
  BOOKING_DELETE: 'booking:delete',
  
  // 设备管理
  DEVICE_CREATE: 'device:create',
  DEVICE_READ: 'device:read',
  DEVICE_UPDATE: 'device:update',
  DEVICE_DELETE: 'device:delete',
  DEVICE_CONTROL: 'device:control',
  
  // 用户管理
  USER_CREATE: 'user:create',
  USER_READ: 'user:read',
  USER_UPDATE: 'user:update',
  USER_DELETE: 'user:delete',
  
  // 系统管理
  SYSTEM_CONFIG: 'system:config',
  SYSTEM_LOGS: 'system:logs',
  SYSTEM_BACKUP: 'system:backup'
} as const;

// 角色权限映射
export const ROLE_PERMISSIONS: Record<string, string[]> = {
  [ROLES.SYSTEM_ADMIN]: Object.values(PERMISSIONS),
  [ROLES.HOTEL_ADMIN]: [
    PERMISSIONS.HOTEL_READ,
    PERMISSIONS.HOTEL_UPDATE,
    PERMISSIONS.ROOM_CREATE,
    PERMISSIONS.ROOM_READ,
    PERMISSIONS.ROOM_UPDATE,
    PERMISSIONS.ROOM_DELETE,
    PERMISSIONS.BOOKING_CREATE,
    PERMISSIONS.BOOKING_READ,
    PERMISSIONS.BOOKING_UPDATE,
    PERMISSIONS.DEVICE_CREATE,
    PERMISSIONS.DEVICE_READ,
    PERMISSIONS.DEVICE_UPDATE,
    PERMISSIONS.DEVICE_DELETE,
    PERMISSIONS.DEVICE_CONTROL,
    PERMISSIONS.USER_CREATE,
    PERMISSIONS.USER_READ,
    PERMISSIONS.USER_UPDATE
  ],
  [ROLES.STAFF]: [
    PERMISSIONS.ROOM_READ,
    PERMISSIONS.BOOKING_CREATE,
    PERMISSIONS.BOOKING_READ,
    PERMISSIONS.BOOKING_UPDATE,
    PERMISSIONS.DEVICE_READ,
    PERMISSIONS.DEVICE_CONTROL
  ],
  [ROLES.CUSTOMER]: [
    PERMISSIONS.BOOKING_CREATE,
    PERMISSIONS.BOOKING_READ,
    PERMISSIONS.ROOM_READ
  ],
  [ROLES.GUEST]: [
    PERMISSIONS.BOOKING_READ,
    PERMISSIONS.ROOM_READ
  ]
};
