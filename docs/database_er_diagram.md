# 智慧酒店物联网控制系统 - 数据库 E-R 图设计

> 版本: v1.0.0
> 更新日期: 2026-04-16
> 适用范围: 后端服务、Web前端、App端、硬件接口

---

## 一、核心实体分类总览

系统采用 **6大模块** 设计，共 **28张核心表**：

| 模块 | 表数量 | 核心功能 |
|------|--------|----------|
| 用户与权限 | 4 | 四角色模型、多对多关联 |
| 酒店与房间 | 6 | 酒店管理、房型、动态价格 |
| 预订与入住 | 3 | 预订、入住、支付 |
| 会员与营销 | 5 | 会员体系、优惠券、评价 |
| IoT物联网 | 4 | 设备控制、传感器、通话 |
| 客房服务 | 3 | 送物、维修工单 |

---

## 二、E-R 关系总图

```mermaid
erDiagram
    USERS ||--o{ USER_ROLES : "拥有"
    USERS ||--o{ USER_HOTELS : "属于"
    USER_ROLES }o--|| ROLES : "分配给"
    USER_HOTELS }o--|| HOTELS : "管理"
    HOTELS ||--o{ FLOORS : "包含"
    HOTELS ||--o{ ROOMS : "拥有"
    HOTELS ||--o{ ROOM_TYPES : "定义"
    HOTELS ||--o{ REVIEWS : "接收"
    ROOMS ||--o{ BOOKINGS : "被预订"
    ROOMS ||--o{ ROOM_PRICES : "定价"
    ROOMS ||--o{ DELIVERY_ORDERS : "接收"
    ROOMS ||--o{ MAINTENANCE_TICKETS : "报修"
    ROOM_TYPES ||--o{ ROOMS : "分类"
    BOOKINGS }o--|| USERS : "创建"
    BOOKINGS }o--|| GUESTS : "入住"
    BOOKINGS ||--o{ PAYMENTS : "支付"
    BOOKINGS }o--|| RATE_PLANS : "使用"
    GUESTS ||--o{ BOOKINGS : "入住"
    MEMBERS ||--o{ MEMBER_COUPONS : "领取"
    MEMBER_COUPONS }o--|| COUPONS : "包含"
    MEMBERS ||--o{ REVIEWS : "撰写"
    DEVICES ||--o{ SENSOR_DATA : "生成"
    DEVICES ||--o{ CONTROL_COMMANDS : "接收"
    DEVICES ||--o{ CALLS : "参与"
```

---

## 三、实体关系详细图

### 3.1 用户与权限模块

```mermaid
erDiagram
    USERS {
        int id PK
        varchar username
        varchar password
        varchar phone
        varchar email
        varchar role
        int hotel_id
    }
    ROLES {
        int id PK
        varchar role_name
        varchar role_description
    }
    USER_ROLES {
        int id PK
        int user_id FK
        int role_id FK
    }
    USER_HOTELS {
        int id PK
        int user_id FK
        int hotel_id FK
    }
    HOTELS {
        int id PK
        varchar hotel_name
        varchar hotel_address
    }
    USERS ||--o{ USER_ROLES : "拥有"
    USERS ||--o{ USER_HOTELS : "属于"
    USER_ROLES }o--|| ROLES : "分配给"
    USER_HOTELS }o--|| HOTELS : "管理"
```

| 表名 | 说明 | 主键 | 外键 |
|------|------|------|------|
| **users** | 用户信息 | id | - |
| **roles** | 角色定义 | id | - |
| **user_roles** | 用户-角色关联 | id | user_id, role_id |
| **user_hotels** | 用户-酒店关联 | id | user_id, hotel_id |

**角色定义**

| role_name | 中文名称 | hotel_id 规则 |
|-----------|----------|---------------|
| `system_admin` | 系统管理员 | `0` (不属于任何酒店) |
| `hotel_admin` | 酒店管理员 | `>0` (所属酒店ID) |
| `staff` | 前台员工 | `>0` (所属酒店ID) |
| `customer` | 顾客 | `NULL` 或 `0` |

---

### 3.2 酒店与房间模块

```mermaid
erDiagram
    HOTELS {
        int id PK
        varchar hotel_name
        varchar hotel_address
        varchar hotel_phone
        int star_rating
    }
    FLOORS {
        int id PK
        int hotel_id FK
        int floor_number
        varchar description
    }
    ROOM_TYPES {
        int id PK
        int hotel_id FK
        varchar name
        varchar code
        decimal base_price
    }
    ROOMS {
        int id PK
        int hotel_id FK
        int room_type_id FK
        varchar room_number
        varchar room_status
        decimal room_price
    }
    ROOM_PRICES {
        int id PK
        int room_id FK
        date price_date
        decimal price
    }
    BOOKINGS {
        int id PK
        int room_id FK
        date check_in_date
        date check_out_date
    }
    REVIEWS {
        int id PK
        int hotel_id FK
        int room_id FK
        decimal score
    }
    HOTELS ||--o{ FLOORS : "包含"
    HOTELS ||--o{ ROOM_TYPES : "定义"
    HOTELS ||--o{ ROOMS : "拥有"
    HOTELS ||--o{ REVIEWS : "接收"
    ROOM_TYPES ||--o{ ROOMS : "分类"
    ROOMS ||--o{ ROOM_PRICES : "定价"
    ROOMS ||--o{ BOOKINGS : "被预订"
    ROOMS ||--o{ REVIEWS : "接收"
```

| 表名 | 说明 | 主键 | 外键 |
|------|------|------|------|
| **hotels** | 酒店信息 | id | - |
| **floors** | 楼层信息 | id | hotel_id |
| **room_types** | 房型字典 | id | hotel_id |
| **rooms** | 房间信息 | id | hotel_id, room_type_id |
| **room_prices** | 动态价格日历 | id | room_id |
| **rate_plans** | 价格方案 | id | - |

---

### 3.3 预订与入住模块

```mermaid
erDiagram
    USERS {
        int id PK
        varchar username
        varchar phone
    }
    GUESTS {
        int id PK
        varchar name
        varchar phone
        varchar id_number
    }
    ROOMS {
        int id PK
        int hotel_id FK
        varchar room_number
        varchar room_status
    }
    BOOKINGS {
        int id PK
        varchar booking_number
        int user_id FK
        int room_id FK
        int guest_id FK
        date check_in_date
        date check_out_date
        varchar status
        decimal total_price
    }
    PAYMENTS {
        int id PK
        varchar payment_no
        varchar order_type
        int order_id
        decimal amount
        varchar status
    }
    RATE_PLANS {
        int id PK
        varchar plan_name
        decimal price
    }
    USERS ||--o{ BOOKINGS : "创建"
    GUESTS ||--o{ BOOKINGS : "入住"
    ROOMS ||--o{ BOOKINGS : "被预订"
    BOOKINGS ||--o{ PAYMENTS : "支付"
    BOOKINGS }o--|| RATE_PLANS : "使用"
```

---

### 3.4 会员与营销模块

```mermaid
erDiagram
    MEMBERS {
        int id PK
        varchar phone
        varchar name
        varchar member_level
        int points
        decimal balance
        decimal total_spent
    }
    COUPONS {
        int id PK
        varchar coupon_name
        varchar coupon_type
        decimal discount_value
        decimal min_amount
        date valid_from
        date valid_to
    }
    MEMBER_COUPONS {
        int id PK
        int member_id FK
        int coupon_id FK
        varchar status
    }
    REVIEWS {
        int id PK
        int member_id FK
        int hotel_id FK
        int room_id FK
        decimal score
        text content
    }
    MEMBERS ||--o{ MEMBER_COUPONS : "领取"
    MEMBER_COUPONS }o--|| COUPONS : "包含"
    MEMBERS ||--o{ REVIEWS : "撰写"
```

**会员等级**

| level | 中文名称 | 累计消费 |
|-------|----------|----------|
| `standard` | 普通会员 | 0 |
| `silver` | 银卡会员 | ≥1000 |
| `gold` | 金卡会员 | ≥5000 |
| `platinum` | 白金会员 | ≥10000 |

---

### 3.5 IoT 物联网模块

```mermaid
erDiagram
    DEVICES {
        int id PK
        varchar device_id
        varchar device_type
        varchar device_name
        varchar device_key
        varchar device_status
        datetime last_seen
    }
    SENSOR_DATA {
        int id PK
        varchar device_id
        varchar sensor_type
        varchar sensor_value
        datetime created_at
    }
    CONTROL_COMMANDS {
        int id PK
        varchar device_id
        varchar command_type
        varchar command_value
        varchar command_status
        varchar created_by
        datetime created_at
    }
    CALLS {
        int id PK
        varchar call_id
        varchar caller_type
        varchar caller_id
        varchar callee_type
        varchar callee_id
        varchar status
        datetime started_at
        datetime answered_at
        datetime ended_at
        int duration_sec
    }
    DEVICES ||--o{ SENSOR_DATA : "生成"
    DEVICES ||--o{ CONTROL_COMMANDS : "接收"
    DEVICES ||--o{ CALLS : "参与"
```

| device_type | 说明 |
|-------------|------|
| `main` | 前台管理端 |
| `sub1` | 楼控设备 |
| `sub2` | 客房端设备 |

| caller_type/callee_type | 说明 |
|--------------------------|------|
| `room` | 房间设备 |
| `front_desk` | 前台 |
| `ai` | AI助手 |
| `app` | 手机App |

---

### 3.6 客房服务模块

```mermaid
erDiagram
    ROOMS {
        int id PK
        int hotel_id FK
        varchar room_number
    }
    BOOKINGS {
        int id PK
        int room_id FK
        int guest_id FK
        varchar booking_number
    }
    GUESTS {
        int id PK
        varchar name
        varchar phone
    }
    DELIVERY_ORDERS {
        int id PK
        varchar order_no
        int booking_id FK
        int guest_id FK
        int room_id FK
        varchar item_name
        int quantity
        varchar status
    }
    MAINTENANCE_TICKETS {
        int id PK
        varchar ticket_no
        int booking_id FK
        int guest_id FK
        int room_id FK
        varchar fault_type
        varchar priority
        varchar status
        varchar repairer
    }
    ROOMS ||--o{ DELIVERY_ORDERS : "接收"
    ROOMS ||--o{ MAINTENANCE_TICKETS : "报修"
    BOOKINGS ||--o{ DELIVERY_ORDERS : "关联"
    BOOKINGS ||--o{ MAINTENANCE_TICKETS : "关联"
    GUESTS ||--o{ DELIVERY_ORDERS : "下单"
    GUESTS ||--o{ MAINTENANCE_TICKETS : "报修"
```

---

## 四、状态机流转图

### 4.1 房间状态流转

```mermaid
stateDiagram-v2
    [*] --> available: 初始
    available --> occupied: 客人入住
    occupied --> cleaning: 客人退房
    cleaning --> available: 清洁完成
    available --> reserved: 预订
    reserved --> occupied: 客人入住
    reserved --> maintenance: 故障报修
    maintenance --> available: 维修完成
```

### 4.2 预订状态流转

```mermaid
stateDiagram-v2
    [*] --> pending: 创建预订
    pending --> confirmed: 确认
    pending --> cancelled: 取消
    confirmed --> checked_in: 办理入住
    confirmed --> cancelled: 取消
    checked_in --> checked_out: 办理退房
    checked_in --> cancelled: 取消
```

### 4.3 送物订单状态流转

```mermaid
stateDiagram-v2
    [*] --> pending: 下单
    pending --> delivering: 开始配送
    pending --> cancelled: 取消
    delivering --> completed: 送达完成
    delivering --> cancelled: 取消
```

### 4.4 维修工单状态流转

```mermaid
stateDiagram-v2
    [*] --> pending: 报修
    pending --> assigned: 分配维修员
    pending --> cancelled: 取消
    assigned --> in_progress: 开始维修
    in_progress --> completed: 维修完成
    in_progress --> cancelled: 取消
```

### 4.5 支付状态流转

```mermaid
stateDiagram-v2
    [*] --> pending: 创建支付
    pending --> paid: 支付成功
    pending --> failed: 支付失败
    paid --> refunded: 退款
```

---

## 五、设计模式总结

### 5.1 多对多关联

通过中间表实现灵活的多对多关系：

```sql
-- 用户-角色
user_roles (user_id, role_id)

-- 用户-酒店
user_hotels (user_id, hotel_id)

-- 会员-优惠券
member_coupons (member_id, coupon_id)
```

### 5.2 外键约束

通过外键维护数据完整性：

```sql
-- 房间必须属于某个酒店
rooms.hotel_id → hotels.id

-- 预订必须关联某个房间
bookings.room_id → rooms.id

-- 房型可按酒店隔离
room_types.hotel_id → hotels.id
```

### 5.3 多态关联

通过 `order_type + order_id` 实现通用关联：

```sql
-- payments 表
payments (order_type ENUM('booking', 'delivery'), order_id INT)

-- reviews 表
reviews (order_type ENUM('booking'), order_id INT)
```

---

## 六、命名规范

### 6.1 表命名

- 小写蛇形命名法（snake_case）
- 使用复数形式：`users`, `rooms`, `bookings`
- 关联表使用双表名：`user_roles`, `user_hotels`

### 6.2 字段命名

| 前缀/后缀 | 用途 | 示例 |
|-----------|------|------|
| `_id` | 外键 | `user_id`, `hotel_id` |
| `_at` | 时间戳 | `created_at`, `updated_at` |
| `_date` | 日期 | `check_in_date` |
| `_count` | 计数 | `guest_count`, `review_count` |
| `_number` | 编号 | `booking_number`, `order_no` |
| `is_` | 布尔 | `is_active`, `is_deleted` |

### 6.3 索引命名

| 类型 | 前缀 | 示例 |
|------|------|------|
| 唯一索引 | `uk_` | `uk_booking_number` |
| 普通索引 | `idx_` | `idx_bookings_user_id` |
| 联合索引 | `idx_` | `idx_device_sensor` |

---

## 七、冗余字段与优化建议

| 表 | 冗余字段 | 建议处理 |
|----|----------|----------|
| hotels | `hotel_star` | 统一为 `star_rating` |
| hotels | `location` | 统一为 `hotel_address` |
| rooms | `room_type` (VARCHAR) | 统一使用 `room_type_id` |
| rooms | `image_url` | 统一使用 `images` (JSON) |

---

## 八、测试账号

| 账号 | 手机号 | 密码 | 角色 |
|------|--------|------|------|
| admin2 | 13800000003 | admin123 | system_admin |
| admin1 | 13800000005 | admin123 | hotel_admin |
| reception_01 | 13800000001 | reception123 | staff |
| reception_02 | 13800000002 | reception123 | staff |
| yyzzjj | 13800000004 | 123123 | customer |

---

## 九、版本历史

| 版本 | 日期 | 更新内容 |
|------|------|----------|
| v1.0.0 | 2026-04-16 | 初始文档，完整 E-R 图设计 |
