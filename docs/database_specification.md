# 智慧酒店物联网控制系统 - 数据库规范文档

> 版本: v3.0.0\
> 更新日期: 2026-04-12\
> 适用范围: 后端服务、Web前端、App端、硬件接口

***

## 一、角色标识规范

### 1.1 标准角色定义

系统采用 **四角色模型**，所有代码和数据库中必须使用以下标准标识符：

| 标准标识符          | 中文名称  | 说明               | hotel\_id 规则  |
| -------------- | ----- | ---------------- | ------------- |
| `system_admin` | 系统管理员 | 管理所有酒店，审核申请，系统配置 | `0` (不属于任何酒店) |
| `hotel_admin`  | 酒店管理员 | 管理所属酒店的业务和员工     | `>0` (所属酒店ID) |
| `staff`        | 前台员工  | 处理日常前台业务操作       | `>0` (所属酒店ID) |
| `customer`     | 顾客    | 预订房间、使用服务        | `NULL` 或 `0`  |

### 1.2 废弃角色标识映射表

以下旧标识已全部迁移至标准标识，**禁止在新代码中使用**：

| 废弃标识             | 映射到            | 出现位置            |
| ---------------- | -------------- | --------------- |
| `system`         | `system_admin` | 旧init.sql       |
| `sys_admin`      | `system_admin` | 旧seed脚本         |
| `super_admin`    | `system_admin` | 旧代码             |
| `platform_admin` | `system_admin` | 旧代码             |
| `admin`          | `hotel_admin`  | 旧init.sql, 旧角色表 |
| `manager`        | `hotel_admin`  | 旧代码             |
| `hotel_manager`  | `hotel_admin`  | 旧代码             |
| `hoteladmin`     | `hotel_admin`  | 旧代码             |
| `receptionist`   | `staff`        | 旧代码             |
| `reception`      | `staff`        | 旧代码             |
| `front_desk`     | `staff`        | 旧代码             |
| `frontdesk`      | `staff`        | 旧代码             |
| `user`           | `customer`     | 旧默认值            |
| `guest`          | `customer`     | 旧代码             |

### 1.3 角色规范化工具

各端均提供了角色规范化工具函数，确保旧标识自动映射到标准标识：

- **后端**: `src/utils/role.ts` → `normalizeRole()`, `isSystemAdmin()`, `isHotelAdmin()`, `isStaff()`, `isCustomer()`
- **Web前端**: `src/api/auth.ts` → `normalizeRole()`, `isSystemAdmin()`, `isHotelAdmin()`, `isStaff()`, `isCustomer()`
- **App端**: `lib/core/auth/auth_state_notifier.dart` → `AppRoles.normalize()`, `AppRoles.displayName()`

***

## 二、数据库表结构规范

### 2.1 核心表一览

| 序号 | 表名                    | 说明       | 核心字段数 |
| -- | --------------------- | -------- | ----- |
| 1  | `users`               | 用户信息     | 12    |
| 2  | `roles`               | 角色定义     | 5     |
| 3  | `user_roles`          | 用户-角色关联  | 3     |
| 4  | `user_hotels`         | 用户-酒店关联  | 3     |
| 5  | `hotels`              | 酒店信息     | 19    |
| 6  | `room_types`          | 房型定义     | 13    |
| 7  | `rooms`               | 房间信息     | 18    |
| 8  | `room_prices`         | 动态价格日历   | 9     |
| 9  | `rate_plans`          | 价格方案     | 15    |
| 10 | `bookings`            | 预订记录     | 24    |
| 11 | `guests`              | 入住宾客     | 10    |
| 12 | `payments`            | 支付记录     | 13    |
| 13 | `members`             | 会员信息     | 13    |
| 14 | `coupons`             | 优惠券      | 13    |
| 15 | `member_coupons`      | 会员-优惠券关联 | 6     |
| 16 | `reviews`             | 评价       | 9     |
| 17 | `delivery_orders`     | 客房送物     | 12    |
| 18 | `maintenance_tickets` | 维修工单     | 14    |
| 19 | `calls`               | 语音通话记录   | 13    |
| 20 | `devices`             | IoT设备    | 10    |
| 21 | `sensor_data`         | 传感器数据    | 4     |
| 22 | `control_commands`    | 控制指令     | 7     |
| 23 | `floors`              | 楼层信息     | 7     |
| 24 | `frequent_guests`     | 常住客信息    | 8     |
| 25 | `role_applications`   | 角色申请     | 13    |
| 26 | `api_tokens`          | API令牌    | 8     |
| 27 | `login_sessions`      | 登录会话     | 7     |
| 28 | `system_settings`     | 系统配置     | 5     |

### 2.2 用户与角色

#### users 表

```sql
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL,           -- 唯一用户名
    password VARCHAR(255) NOT NULL,           -- bcrypt加密密码
    phone VARCHAR(20) DEFAULT NULL,           -- 手机号(唯一)
    uid VARCHAR(50) DEFAULT NULL,             -- 第三方UID(唯一)
    email VARCHAR(100) DEFAULT NULL,          -- 邮箱
    avatar VARCHAR(255) DEFAULT NULL,         -- 头像URL
    role VARCHAR(20) NOT NULL DEFAULT 'customer',  -- ⚠️ 标准角色标识
    hotel_id INT DEFAULT 0,                   -- 所属酒店ID (0=系统管理员)
    permissions JSON DEFAULT NULL,            -- 权限JSON
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_username (username),
    UNIQUE KEY uk_phone (phone),
    UNIQUE KEY uk_uid (uid),
    INDEX idx_hotel_id (hotel_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**规范要求**:

- `role` 字段只能取值: `system_admin`, `hotel_admin`, `staff`, `customer`
- 默认值为 `customer`（非 `user`）
- `hotel_id` 为 0 表示系统管理员，大于 0 表示所属酒店

#### roles 表

```sql
CREATE TABLE roles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE,    -- 标准角色标识
    role_description VARCHAR(255) DEFAULT NULL,
    permissions JSON DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**初始化数据**:

| id | role\_name     | role\_description | permissions |
| -- | -------------- | ----------------- | ----------- |
| 1  | `system_admin` | 系统管理员             | 全部权限        |
| 2  | `hotel_admin`  | 酒店管理员             | 酒店管理权限      |
| 3  | `staff`        | 前台员工              | 业务操作权限      |
| 4  | `customer`     | 顾客                | 基本服务权限      |

#### user\_roles 关联表

```sql
CREATE TABLE user_roles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    role_id INT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_user_role (user_id, role_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 2.3 酒店与房间

#### hotels 表

```sql
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
    UNIQUE KEY uk_hotel_name (hotel_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**已知冗余字段**:

- `hotel_star` vs `star_rating` — 同为星级评分，建议统一为 `star_rating`
- `hotel_address` vs `location` — 同为地址，建议统一为 `hotel_address`
- `hotel_id` — 兼容旧字段，建议移除

#### rooms 表

```sql
CREATE TABLE rooms (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hotel_id INT DEFAULT NULL,
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
    room_id INT DEFAULT NULL,
    locked_by_booking INT DEFAULT NULL,
    locked_at DATETIME DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_hotel_room (hotel_id, room_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**已知冗余字段**:

- `room_type` (VARCHAR) vs `room_type_id` (INT FK) — 建议统一使用 `room_type_id` 外键
- `image_url` vs `images` (JSON) — 建议统一使用 `images`
- `room_id` — 兼容旧字段，建议移除

#### room\_types 表

```sql
CREATE TABLE room_types (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hotel_id INT DEFAULT 0,
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
    UNIQUE KEY uk_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 2.4 预订与入住

#### bookings 表

```sql
CREATE TABLE bookings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    booking_number VARCHAR(50) NOT NULL,
    user_id INT DEFAULT NULL,
    room_id INT NOT NULL,
    rate_plan_id INT DEFAULT NULL,
    hotel_id INT DEFAULT NULL,
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
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    check_in_time DATETIME DEFAULT NULL,
    check_out_time DATETIME DEFAULT NULL,
    cancelled_at DATETIME DEFAULT NULL,
    pre_checkin_time DATETIME DEFAULT NULL,
    lock_version INT DEFAULT 0,
    locked_at DATETIME DEFAULT NULL,
    locked_by INT DEFAULT NULL,
    payment_deadline DATETIME DEFAULT NULL,
    auto_checkout_at DATETIME DEFAULT NULL,
    room_number VARCHAR(20) DEFAULT NULL,
    UNIQUE KEY uk_booking_number (booking_number),
    INDEX idx_bookings_user_id (user_id),
    INDEX idx_status (status),
    INDEX idx_date (check_in_date, check_out_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**预订状态流转**:

```
pending → confirmed → checked_in → checked_out
   ↓          ↓           ↓
cancelled  cancelled   cancelled
```

| 状态值           | 中文名 | 说明       |
| ------------- | --- | -------- |
| `pending`     | 待确认 | 刚创建，等待确认 |
| `confirmed`   | 已确认 | 已确认预订    |
| `checked_in`  | 已入住 | 已办理入住    |
| `checked_out` | 已退房 | 已办理退房    |
| `cancelled`   | 已取消 | 已取消预订    |

### 2.5 IoT 设备与控制

#### devices 表

```sql
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
```

#### sensor\_data 表

```sql
CREATE TABLE sensor_data (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    sensor_type VARCHAR(20) NOT NULL,
    sensor_value VARCHAR(50) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_device_sensor (device_id, sensor_type),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

#### control\_commands 表

```sql
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
```

### 2.6 语音通话

#### calls 表

```sql
CREATE TABLE calls (
    id INT AUTO_INCREMENT PRIMARY KEY,
    call_id VARCHAR(64) NOT NULL,
    caller_type ENUM('room','front_desk','ai','app') NOT NULL,
    caller_id VARCHAR(64) NOT NULL,
    callee_type ENUM('room','front_desk','ai','app') NOT NULL,
    callee_id VARCHAR(64) NOT NULL,
    status ENUM('calling','outgoing','ringing','connected','ended','rejected','missed','busy') NOT NULL DEFAULT 'calling',
    started_at DATETIME NOT NULL,
    answered_at DATETIME DEFAULT NULL,
    ended_at DATETIME DEFAULT NULL,
    duration_sec INT NOT NULL DEFAULT 0,
    recording_url VARCHAR(512) DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_call_id (call_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 2.7 会员与优惠券

#### members 表

```sql
CREATE TABLE members (
    id INT AUTO_INCREMENT PRIMARY KEY,
    phone VARCHAR(20) NOT NULL,
    password VARCHAR(255) DEFAULT NULL,
    name VARCHAR(100) DEFAULT NULL,
    id_number VARCHAR(50) DEFAULT NULL,
    member_level VARCHAR(20) NOT NULL DEFAULT 'standard',
    experience INT DEFAULT 0,
    last_checkin_date DATE DEFAULT NULL,
    points INT NOT NULL DEFAULT 0,
    balance DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    total_spent DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total_stays INT NOT NULL DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_phone (phone)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**会员等级**:

| member\_level | 中文名  | 说明     |
| ------------- | ---- | ------ |
| `standard`    | 普通会员 | 默认等级   |
| `silver`      | 银卡会员 | 累计消费达标 |
| `gold`        | 金卡会员 | 累计消费达标 |
| `platinum`    | 白金会员 | 累计消费达标 |

### 2.8 客房服务

#### delivery\_orders 表

```sql
CREATE TABLE delivery_orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_no VARCHAR(50) NOT NULL,
    booking_id INT DEFAULT NULL,
    guest_id INT DEFAULT NULL,
    room_id INT NOT NULL,
    item_name VARCHAR(200) NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    note VARCHAR(255) DEFAULT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    started_delivering_at DATETIME DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    completed_at DATETIME DEFAULT NULL,
    UNIQUE KEY uk_order_no (order_no),
    INDEX idx_room_id (room_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**送物状态流转**: `pending` → `delivering` → `completed` / `cancelled`

#### maintenance\_tickets 表

```sql
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
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    completed_at DATETIME DEFAULT NULL,
    repair_description TEXT DEFAULT NULL,
    repair_cost DECIMAL(10,2) DEFAULT 0.00,
    UNIQUE KEY uk_ticket_no (ticket_no),
    INDEX idx_room_id (room_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 2.9 角色申请

#### role\_applications 表

```sql
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
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**申请类型**:

- `create_hotel` — 创建酒店申请 (审核通过后角色变为 `hotel_admin`)
- `bind_employee` — 绑定员工申请 (审核通过后角色变为 `staff`)

***

## 三、索引规范

### 3.1 索引命名规范

| 索引类型 | 命名规则             | 示例                     |
| ---- | ---------------- | ---------------------- |
| 唯一索引 | `uk_表名_字段名`      | `uk_booking_number`    |
| 普通索引 | `idx_表名_字段名`     | `idx_bookings_user_id` |
| 联合索引 | `idx_表名_字段1_字段2` | `idx_device_sensor`    |

### 3.2 必须建立索引的字段

- 所有外键字段
- 所有状态字段 (status)
- 所有时间范围查询字段 (created\_at, check\_in\_date 等)
- 所有唯一性约束字段

***

## 四、数据类型规范

| 数据类型                 | 使用场景  | 示例                                    |
| -------------------- | ----- | ------------------------------------- |
| `INT AUTO_INCREMENT` | 主键    | `id INT AUTO_INCREMENT PRIMARY KEY`   |
| `VARCHAR(n)`         | 短文本   | `username VARCHAR(50)`                |
| `TEXT`               | 长文本   | `description TEXT`                    |
| `JSON`               | 结构化数据 | `facilities JSON`, `permissions JSON` |
| `DECIMAL(m,n)`       | 金额    | `room_price DECIMAL(10,2)`            |
| `DATETIME`           | 时间戳   | `created_at DATETIME`                 |
| `DATE`               | 日期    | `check_in_date DATE`                  |
| `ENUM`               | 有限枚举  | `status ENUM('pending','confirmed')`  |
| `TINYINT(1)`         | 布尔值   | `is_used TINYINT(1)`                  |

***

## 五、命名规范

### 5.1 表命名

- 使用小写蛇形命名法 (snake\_case)
- 使用复数形式: `users`, `rooms`, `bookings`
- 关联表使用双表名: `user_roles`, `user_hotels`, `member_coupons`

### 5.2 字段命名

- 使用小写蛇形命名法 (snake\_case)
- 主键统一为 `id`
- 外键格式: `关联表名单数_id`，如 `user_id`, `hotel_id`, `room_id`
- 布尔字段以 `is_` 开头: `is_used`, `is_active`
- 时间字段以 `_at` 结尾: `created_at`, `updated_at`, `deleted_at`
- 日期字段以 `_date` 结尾: `check_in_date`, `check_out_date`
- 计数字段以 `_count` 结尾: `guest_count`, `review_count`
- 编号字段以 `_number` 或 `_no` 结尾: `booking_number`, `order_no`

### 5.3 状态字段规范

所有状态字段统一使用 VARCHAR 类型，不使用 ENUM（便于扩展），取值必须为小写蛇形：

| 表                    | 状态字段            | 合法值                                                      |
| -------------------- | --------------- | -------------------------------------------------------- |
| bookings             | status          | pending, confirmed, checked\_in, checked\_out, cancelled |
| rooms                | room\_status    | available, occupied, maintenance, cleaning, reserved     |
| payments             | status          | pending, paid, refunded, failed                          |
| delivery\_orders     | status          | pending, delivering, completed, cancelled                |
| maintenance\_tickets | status          | pending, assigned, in\_progress, completed, cancelled    |
| role\_applications   | status          | pending, approved, rejected                              |
| devices              | device\_status  | online, offline, error                                   |
| control\_commands    | command\_status | pending, executed, failed                                |

***

## 六、冗余字段与优化建议

### 6.1 已识别的冗余字段

| 表      | 冗余字段                  | 对应标准字段              | 建议                                |
| ------ | --------------------- | ------------------- | --------------------------------- |
| hotels | `hotel_star`          | `star_rating`       | 统一为 `star_rating`，移除 `hotel_star` |
| hotels | `location`            | `hotel_address`     | 统一为 `hotel_address`，移除 `location` |
| hotels | `hotel_id`            | 无                   | 兼容旧字段，建议移除                        |
| rooms  | `room_type` (VARCHAR) | `room_type_id` (FK) | 统一使用 `room_type_id` 外键            |
| rooms  | `image_url`           | `images` (JSON)     | 统一使用 `images`                     |
| rooms  | `room_id`             | 无                   | 兼容旧字段，建议移除                        |

### 6.2 优化建议

1. **移除兼容旧字段**: `hotels.hotel_id`, `rooms.room_id` 等兼容字段应在确认无引用后移除
2. **统一星级字段**: 将 `hotel_star` 和 `star_rating` 合并为一个
3. **统一地址字段**: 将 `location` 和 `hotel_address` 合并为一个
4. **房间类型外键化**: 将 `rooms.room_type` VARCHAR 改为只使用 `room_type_id` INT 外键
5. **图片字段统一**: 将 `image_url` 单图字段统一为 `images` JSON 多图字段

***

## 七、测试账号

| 账号            | 手机号         | 密码           | 角色            | 用途      |
| ------------- | ----------- | ------------ | ------------- | ------- |
| admin2        | 13800000003 | admin123     | system\_admin | 系统管理员测试 |
| admin1        | 13800000005 | admin123     | hotel\_admin  | 酒店管理员测试 |
| reception\_01 | 13800000001 | reception123 | staff         | 前台员工测试  |
| reception\_02 | 13800000002 | reception123 | staff         | 前台员工测试  |
| yyzzjj        | 13800000004 | 123123       | customer      | 顾客测试    |

***

## 八、连接信息

| 参数   | 值                    |
| ---- | -------------------- |
| 主机   | <br />               |
| 端口   | 3306                 |
| 用户名  | <br />               |
| 密码   | <br />               |
| 数据库  | <br />               |
| 字符集  | utf8mb4              |
| 排序规则 | utf8mb4\_unicode\_ci |

