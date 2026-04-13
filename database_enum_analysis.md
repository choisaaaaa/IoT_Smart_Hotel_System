# 数据库 Enum 优化分析报告

> 数据库：`iot_hotel_system`  
> 分析日期：2026-04-13  
> 总表数：28 张

---

## 一、已经是 Enum 的字段（无需修改）

| 表名 | 字段 | 当前类型 |
|------|------|----------|
| calls | caller_type | `enum('room','front_desk','ai','app')` |
| calls | callee_type | `enum('room','front_desk','ai','app')` |
| calls | status | `enum('calling','outgoing','ringing','connected','ended','rejected','missed','busy')` |
| coupons | coupon_type | `enum('discount','cash')` |
| rate_plans | meal_plan | `enum('none','breakfast','half_board','full_board')` |
| rate_plans | cancellation_policy | `enum('free','no_cancel','restricted')` |
| rate_plans | payment_type | `enum('all','online_only','front_desk_only')` |

**共 7 个字段**

---

## 二、建议改成 Enum 的字段

### 2.1 api_tokens 表

| 字段 | 当前类型 | 建议 Enum 值 |
|------|----------|--------------|
| token_type | varchar(50) | `enum('login', 'reset_password', 'verify_email')` |

---

### 2.2 bookings 表

| 字段 | 当前类型 | 建议 Enum 值 |
|------|----------|--------------|
| id_type | varchar(20) | `enum('idcard', 'passport', 'driver_license', 'other')` |
| payment_method | varchar(20) | `enum('balance', 'wechat', 'alipay', 'card', 'cash')` |
| status | varchar(20) | `enum('pending', 'confirmed', 'checked_in', 'checked_out', 'cancelled')` |

---

### 2.3 control_commands 表

| 字段 | 当前类型 | 建议 Enum 值 |
|------|----------|--------------|
| command_type | varchar(20) | `enum('power', 'temperature', 'mode', 'brightness', 'color')` |
| command_status | varchar(20) | `enum('pending', 'executing', 'completed', 'failed', 'cancelled')` |

---

### 2.4 delivery_orders 表

| 字段 | 当前类型 | 建议 Enum 值 |
|------|----------|--------------|
| status | varchar(20) | `enum('pending', 'processing', 'delivering', 'completed', 'cancelled')` |

---

### 2.5 devices 表

| 字段 | 当前类型 | 建议 Enum 值 |
|------|----------|--------------|
| device_type | varchar(20) | `enum('light', 'ac', 'tv', 'curtain', 'lock', 'sensor', 'switch')` |
| audit_status | varchar(20) | `enum('pending', 'approved', 'rejected')` |
| device_status | varchar(20) | `enum('online', 'offline', 'error', 'maintenance')` |

---

### 2.6 frequent_guests 表

| 字段 | 当前类型 | 建议 Enum 值 |
|------|----------|--------------|
| id_type | varchar(50) | `enum('idcard', 'passport', 'driver_license', 'other')` |

---

### 2.7 guests 表

| 字段 | 当前类型 | 建议 Enum 值 |
|------|----------|--------------|
| id_type | varchar(20) | `enum('idcard', 'passport', 'driver_license', 'other')` |
| status | varchar(20) | `enum('confirmed', 'checked_in', 'checked_out', 'cancelled')` |

---

### 2.8 maintenance_tickets 表

| 字段 | 当前类型 | 建议 Enum 值 |
|------|----------|--------------|
| fault_type | varchar(50) | `enum('electrical', 'plumbing', 'hvac', 'furniture', 'appliance', 'other')` |
| priority | varchar(20) | `enum('low', 'medium', 'high', 'urgent')` |
| status | varchar(20) | `enum('pending', 'assigned', 'in_progress', 'completed', 'cancelled')` |

---

### 2.9 member_coupons 表

| 字段 | 当前类型 | 建议 Enum 值 |
|------|----------|--------------|
| status | varchar(20) | `enum('unused', 'used', 'expired')` |

---

### 2.10 members 表

| 字段 | 当前类型 | 建议 Enum 值 |
|------|----------|--------------|
| member_level | varchar(20) | `enum('standard', 'silver', 'gold', 'platinum', 'diamond')` |

---

### 2.11 payments 表

| 字段 | 当前类型 | 建议 Enum 值 |
|------|----------|--------------|
| order_type | varchar(20) | `enum('booking', 'service', 'deposit', 'fine')` |
| payment_method | varchar(20) | `enum('wechat', 'alipay', 'card', 'cash', 'balance')` |
| status | varchar(20) | `enum('pending', 'paid', 'failed', 'refunded', 'cancelled')` |

---

### 2.12 reviews 表

| 字段 | 当前类型 | 建议 Enum 值 |
|------|----------|--------------|
| order_type | varchar(50) | `enum('booking', 'service', 'product')` |

---

### 2.13 role_applications 表

| 字段 | 当前类型 | 建议 Enum 值 |
|------|----------|--------------|
| application_type | varchar(20) | `enum('hotel_admin', 'staff', 'manager')` |
| status | varchar(20) | `enum('pending', 'approved', 'rejected')` |

---

### 2.14 rooms 表

| 字段 | 当前类型 | 建议 Enum 值 |
|------|----------|--------------|
| room_type | varchar(20) | `enum('standard', 'deluxe', 'suite', 'presidential')` |
| room_status | varchar(20) | `enum('available', 'occupied', 'cleaning', 'maintenance', 'reserved')` |
| bed_type | varchar(20) | `enum('single', 'double', 'queen', 'king', 'twin', 'sofa')` |

---

### 2.15 room_types 表

| 字段 | 当前类型 | 建议 Enum 值 |
|------|----------|--------------|
| bed_type | varchar(20) | `enum('single', 'double', 'queen', 'king', 'twin', 'sofa')` |

---

### 2.16 sensor_data 表

| 字段 | 当前类型 | 建议 Enum 值 |
|------|----------|--------------|
| sensor_type | varchar(20) | `enum('temperature', 'humidity', 'motion', 'light', 'door', 'smoke', 'co2')` |

---

### 2.17 users 表

| 字段 | 当前类型 | 建议 Enum 值 |
|------|----------|--------------|
| role | varchar(20) | `enum('user', 'admin', 'hotel_admin', 'staff', 'manager', 'super_admin')` |

---

## 三、统计汇总

| 类别 | 数量 |
|------|------|
| 已经是 Enum | 7 个字段 |
| 建议改成 Enum | **35 个字段** |
| 涉及表数 | 17 张表 |

---

## 四、优先级建议

### 🔴 高优先级（状态类字段，值范围固定）

- `bookings.status`
- `payments.status`
- `rooms.room_status`
- `maintenance_tickets.status`
- `devices.device_status`

### 🟡 中优先级（类型类字段）

- `bookings.id_type` / `guests.id_type` / `frequent_guests.id_type`
- `devices.device_type`
- `sensor_data.sensor_type`
- `users.role`

### 🟢 低优先级（可能扩展的业务字段）

- `bookings.payment_method` / `payments.payment_method`
- `members.member_level`
- `rooms.bed_type` / `room_types.bed_type`

---

## 五、SQL 修改示例

```sql
-- 示例：修改 bookings 表的 status 字段
ALTER TABLE bookings 
MODIFY COLUMN status ENUM('pending', 'confirmed', 'checked_in', 'checked_out', 'cancelled') 
NOT NULL DEFAULT 'pending';

-- 示例：修改 rooms 表的 room_status 字段
ALTER TABLE rooms 
MODIFY COLUMN room_status ENUM('available', 'occupied', 'cleaning', 'maintenance', 'reserved') 
NOT NULL DEFAULT 'available';
```

---

## 六、注意事项

1. **备份数据**：修改字段类型前务必备份数据库
2. **检查现有数据**：确保现有数据都在 Enum 值范围内
3. **应用程序兼容性**：修改后需同步更新应用程序中的类型定义
4. **扩展性考虑**：Enum 值一旦定义，修改成本较高，需预留可能的扩展值
