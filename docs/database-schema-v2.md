# IoT Smart Hotel System - 数据库设计文档

## 📋 文档信息
- **版本**: v2.0 (2026-04-10 更新)
- **更新内容**: 添加 HotelID 门店数据隔离支持
- **数据库**: MySQL 8.0+

---

## 🏨 核心业务表结构

### 1. hotels (酒店主表)
| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | INT | PK, AUTO_INCREMENT | 酒店ID |
| hotel_name | VARCHAR(100) | NOT NULL | 酒店名称 |
| hotel_address | VARCHAR(255) | | 酒店地址 |
| hotel_phone | VARCHAR(20) | | 联系电话 |
| hotel_star | TINYINT | DEFAULT 0 | 星级 (1-5) |
| total_rooms | INT | DEFAULT 0 | 总房间数 |
| occupied_rooms | INT | DEFAULT 0 | 已入住房间数 |
| occupancy_rate | DECIMAL(5,2) | DEFAULT 0.00 | 入住率 |
| logo | VARCHAR(500) | | Logo URL |
| description | TEXT | | 酒店描述 |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | 创建时间 |
| updated_at | DATETIME | ON UPDATE CURRENT_TIMESTAMP | 更新时间 |

**索引**: PRIMARY KEY (id)

---

### 2. rooms (房间表) ✅ 已添加 hotel_id
| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | INT | PK, AUTO_INCREMENT | 房间ID |
| **hotel_id** | **INT** | **NOT NULL, FK** | **🆕 所属酒店ID** |
| room_number | VARCHAR(20) | NOT NULL, UNIQUE(hotel_id) | 房间号 |
| room_type_id | INT | FK → room_types.id | 房间类型ID |
| room_type | VARCHAR(50) | | 房间类型（兼容字段） |
| room_name | VARCHAR(100) | | 房间名称 |
| room_price | DECIMAL(10,2) | NOT NULL | 价格/晚 |
| room_status | ENUM | DEFAULT 'available' | 状态: available/cleaning/occupied/reserved/maintenance |
| floor | INT | DEFAULT 1 | 所在楼层 |
| area | DECIMAL(6,2) | | 面积(平方米) |
| bed_type | VARCHAR(50) | | 床型: single/double/king/twin |
| max_guests | TINYINT | DEFAULT 2 | 最大入住人数 |
| description | TEXT | | 房间描述 |
| facilities | JSON | | 设施列表 |
| images | JSON | | 图片URL列表 |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | 创建时间 |
| updated_at | DATETIME | ON UPDATE CURRENT_TIMESTAMP | 更新时间 |

**索引**:
- PRIMARY KEY (id)
- **INDEX idx_hotel_id (hotel_id)** 🆕
- UNIQUE INDEX uk_room_number (hotel_id, room_number)

---

### 3. bookings (预订表) ✅ 已添加 hotel_id
| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | INT | PK, AUTO_INCREMENT | 预订ID |
| **hotel_id** | **INT** | **NOT NULL, FK** | **🆕 所属酒店ID** |
| booking_number | VARCHAR(50) | NOT NULL, UNIQUE | 预订编号 |
| user_id | INT | FK → users.id | 用户ID（会员预订） |
| room_id | INT | NOT NULL, FK → rooms.id | 房间ID |
| guest_name | VARCHAR(100) | NOT NULL | 客人姓名 |
| guest_phone | VARCHAR(20) | NOT NULL | 客人手机号 |
| guest_id_number | VARCHAR(20) | | 身份证号 |
| check_in_date | DATE | NOT NULL | 入住日期 |
| check_out_date | DATE | NOT NULL | 退房日期 |
| guest_count | TINYINT | DEFAULT 1 | 入住人数 |
| special_requests | TEXT | | 特殊要求 |
| payment_method | ENUM | DEFAULT 'wechat' | 支付方式: wechat/alipay/cash/card |
| total_price | DECIMAL(10,2) | NOT NULL | 总金额 |
| deposit | DECIMAL(10,2) | DEFAULT 0 | 押金 |
| status | ENUM | DEFAULT 'pending' | 状态: pending/confirmed/checked_in/checked_out/cancelled |
| check_in_time | DATETIME | | 实际入住时间 |
| check_out_time | DATETIME | | 实际退房时间 |
| cancelled_at | DATETIME | | 取消时间 |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | 创建时间 |
| updated_at | DATETIME | ON UPDATE CURRENT_TIMESTAMP | 更新时间 |

**索引**:
- PRIMARY KEY (id)
- **INDEX idx_hotel_id (hotel_id)** 🆕
- INDEX idx_booking_number (booking_number)
- INDEX idx_room_id (room_id)
- INDEX idx_status (status)

---

### 4. payments (支付表) ✅ 已添加 hotel_id
| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | INT | PK, AUTO_INCREMENT | 支付ID |
| **hotel_id** | **INT** | **NOT NULL, FK** | **🆕 所属酒店ID** |
| payment_no | VARCHAR(50) | NOT NULL, UNIQUE | 支付编号 |
| order_type | ENUM | NOT NULL | 订单类型: booking/delivery/maintenance |
| order_id | INT | NOT NULL | 关联订单ID |
| amount | DECIMAL(10,2) | NOT NULL | 支付金额 |
| payment_method | ENUM | NOT NULL | 支付方式 |
| status | ENUM | DEFAULT 'pending' | 状态: pending/paid/failed/refunded |
| transaction_no | VARCHAR(100) | | 第三方交易号 |
| paid_at | DATETIME | | 支付完成时间 |
| description | VARCHAR(255) | | 备注 |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | 创建时间 |
| updated_at | DATETIME | ON UPDATE CURRENT_TIMESTAMP | 更新时间 |

**索引**:
- PRIMARY KEY (id)
- **INDEX idx_hotel_id (hotel_id)** 🆕
- INDEX idx_payment_no (payment_no)
- INDEX idx_order (order_type, order_id)

---

### 5. delivery_orders (配送订单表) ✅ 已添加 hotel_id
| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | INT | PK, AUTO_INCREMENT | 订单ID |
| **hotel_id** | **INT** | **NOT NULL, FK** | **🆕 所属酒店ID** |
| order_no | VARCHAR(50) | NOT NULL, UNIQUE | 订单编号 |
| room_id | INT | NOT NULL, FK → rooms.id | 房间ID |
| item_name | VARCHAR(100) | NOT NULL | 物品名称 |
| quantity | INT | DEFAULT 1 | 数量 |
| note | TEXT | | 备注 |
| status | ENUM | DEFAULT 'pending' | 状态: pending/delivering/completed/cancelled |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | 创建时间 |
| updated_at | DATETIME | ON UPDATE CURRENT_TIMESTAMP | 更新时间 |
| completed_at | DATETIME | | 完成时间 |

**索引**:
- PRIMARY KEY (id)
- **INDEX idx_hotel_id (hotel_id)** 🆕
- INDEX idx_order_no (order_no)
- INDEX idx_room_id (room_id)

---

### 6. maintenance_tickets (维修工单表) ✅ 已添加 hotel_id
| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | INT | PK, AUTO_INCREMENT | 工单ID |
| **hotel_id** | **INT** | **NOT NULL, FK** | **🆕 所属酒店ID** |
| ticket_no | VARCHAR(50) | NOT NULL, UNIQUE | 工单编号 |
| room_id | INT | NOT NULL, FK → rooms.id | 房间ID |
| fault_type | VARCHAR(50) | NOT NULL | 故障类型: electrical/plumbing/hvac/furniture/other |
| fault_description | TEXT | NOT NULL | 故障描述 |
| photos | JSON | | 故障照片URL列表 |
| priority | ENUM | DEFAULT 'normal' | 优先级: low/normal/high/urgent |
| status | ENUM | DEFAULT 'pending' | 状态: pending/assigned/in_progress/completed/cancelled |
| repairer | VARCHAR(50) | | 维修人员 |
| repair_description | TEXT | | 维修说明 |
| repair_cost | DECIMAL(10,2) | DEFAULT 0 | 维修费用 |
| assigned_at | DATETIME | | 分配时间 |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | 创建时间 |
| updated_at | DATETIME | ON UPDATE CURRENT_TIMESTAMP | 更新时间 |
| completed_at | DATETIME | | 完成时间 |

**索引**:
- PRIMARY KEY (id)
- **INDEX idx_hotel_id (hotel_id)** 🆕
- INDEX idx_ticket_no (ticket_no)
- INDEX idx_status (status)

---

### 7. reviews (评价表) ✅ 已添加 hotel_id
| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | INT | PK, AUTO_INCREMENT | 评价ID |
| **hotel_id** | **INT** | **NOT NULL, FK** | **🆕 所属酒店ID** |
| order_id | INT | NOT NULL | 关联订单ID |
| order_type | ENUM | NOT NULL | 订单类型: booking/delivery/maintenance |
| member_id | INT | FK → members.id | 会员ID |
| score | TINYINT | CHECK (1-5) | 评分 (1-5星) |
| content | TEXT | NOT NULL | 评价内容 |
| photos | JSON | | 评价图片URL列表 |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | 创建时间 |

**索引**:
- PRIMARY KEY (id)
- **INDEX idx_hotel_id (hotel_id)** 🆕
- INDEX idx_order (order_id, order_type)
- INDEX idx_member_id (member_id)

---

### 8. calls (呼叫记录表) ✅ 已添加 hotel_id
| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | INT | PK, AUTO_INCREMENT | 呼叫ID |
| **hotel_id** | **INT** | **NOT NULL, FK** | **🆕 所属酒店ID** |
| call_id | VARCHAR(50) | NOT NULL, UNIQUE | 呼叫唯一标识 |
| caller_type | ENUM | NOT NULL | 主叫类型: room/front_desk/ai/app |
| caller_id | VARCHAR(50) | NOT NULL | 主叫ID |
| callee_type | ENUM | NOT NULL | 被叫类型: room/front_desk/ai/app |
| callee_id | VARCHAR(50) | NOT NULL | 被叫ID |
| status | ENUM | DEFAULT 'calling' | 状态: calling/outgoing/ringing/connected/ended/rejected/missed/busy |
| started_at | DATETIME | NOT NULL | 开始时间 |
| answered_at | DATETIME | | 接听时间 |
| ended_at | DATETIME | | 结束时间 |
| duration_sec | INT | DEFAULT 0 | 通话时长(秒) |
| recording_url | VARCHAR(500) | | 录音文件URL |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | 创建时间 |

**索引**:
- PRIMARY KEY (id)
- **INDEX idx_hotel_id (hotel_id)** 🆕
- INDEX idx_call_id (call_id)
- INDEX idx_caller (caller_type, caller_id)

---

### 9. coupons (优惠券表) ✅ 已添加 hotel_id
| 字段名 | 类型 | 约束 | 说明 |
|--------|------|------|------|
| id | INT | PK, AUTO_INCREMENT | 优惠券ID |
| **hotel_id** | **INT** | **FK, Nullable** | **🆕 酒店ID(NULL=全局通用)** |
| coupon_name | VARCHAR(100) | NOT NULL | 优惠券名称 |
| coupon_type | ENUM | NOT NULL | 类型: percentage/fixed/free_shipping/gift |
| discount_value | DECIMAL(10,2) | NOT NULL | 优惠值 |
| min_amount | DECIMAL(10,2) | DEFAULT 0 | 最低使用金额 |
| total_count | INT | NOT NULL | 发行总量 |
| received_count | INT | DEFAULT 0 | 已领取数量 |
| valid_from | DATETIME | NOT NULL | 有效期开始 |
| valid_to | DATETIME | NOT NULL | 有效期结束 |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP | 创建时间 |
| updated_at | DATETIME | ON UPDATE CURRENT_TIMESTAMP | 更新时间 |

**索引**:
- PRIMARY KEY (id)
- **INDEX idx_hotel_id (hotel_id)** 🆕

---

## 🔗 表关系图

```
hotels (1)
  ├── rooms (∞) [hotel_id]
  │     ├── bookings (∞) [room_id]
  │     ├── delivery_orders (∞) [room_id]
  │     └── maintenance_tickets (∞) [room_id]
  ├── bookings (∞) [hotel_id] ← 直接关联
  ├── payments (∞) [hotel_id]
  ├── delivery_orders (∞) [hotel_id] ← 直接关联
  ├── maintenance_tickets (∞) [hotel_id] ← 直接关联
  ├── reviews (∞) [hotel_id]
  ├── calls (∞) [hotel_id]
  └── coupons (∞) [hotel_id]
```

---

## 📊 数据隔离策略

### 多租户架构
```
┌─────────────────────────────────────────────┐
│              Application Layer               │
├─────────────────────────────────────────────┤
│  Controller (从 JWT/User 获取 hotel_id)      │
│       ↓                                     │
│  Service (强制添加 WHERE hotel_id = ? 过滤)   │
│       ↓                                     │
│  Database (每张表都有 hotel_id 索引)          │
└─────────────────────────────────────────────┘
```

### 权限控制逻辑
1. **普通用户**: 只能访问自己绑定的 `hotel_id` 数据
2. **门店管理员**: 可通过查询参数切换管理的门店
3. **系统管理员**: 可查看所有门店数据，需显式指定 `hotel_id`

---

## 🔄 迁移指南

### 升级步骤
1. **备份数据库**
   ```bash
   mysqldump -u root -p iot_hotel > backup_$(date +%Y%m%d).sql
   ```

2. **执行迁移脚本**
   ```bash
   mysql -u root -p iot_hotel < migrations/add_hotel_id_fields.sql
   ```

3. **验证迁移结果**
   ```sql
   -- 检查字段是否添加成功
   SHOW COLUMNS FROM rooms LIKE 'hotel_id';
   SHOW COLUMNS FROM bookings LIKE 'hotel_id';

   -- 统计现有数据
   SELECT COUNT(*) FROM rooms WHERE hotel_id = 1;
   SELECT COUNT(*) FROM bookings WHERE hotel_id = 1;
   ```

4. **分配数据到正确门店**（如需要）
   ```sql
   -- 示例：将部分房间分配到酒店ID=2
   UPDATE rooms SET hotel_id = 2 WHERE id IN (SELECT id FROM rooms LIMIT 10);
   ```

---

## ⚠️ 注意事项

### 性能优化建议
1. ✅ 所有 `hotel_id` 字段已创建索引
2. ✅ 查询时始终包含 `WHERE hotel_id = ?` 条件
3. ✅ 考虑对高频查询的复合索引：`(hotel_id, status)`, `(hotel_id, created_at)`

### 数据一致性
1. 创建订单时自动继承房间的 `hotel_id`
2. 更新操作必须验证 `hotel_id` 匹配
3. 删除操作软删除优先，保留审计追踪

### 向后兼容
- 默认值设为 `1`，确保旧数据可正常访问
- API 参数中 `hotel_id` 为可选，后端会智能获取
- 前端 Store 自动注入当前酒店 ID

---

## 📝 版本历史

| 版本 | 日期 | 更新内容 |
|------|------|----------|
| v1.0 | 2026-01-01 | 初始版本 |
| **v2.0** | **2026-04-10** | **🆕 添加 HotelID 门店数据隔离支持** |

---

## 📚 相关文档
- [API 接口文档](../api-docs/)
- [部署指南](../deployment.md)
- [开发规范](../CONTRIBUTING.md)

---

**维护团队**: IoT Smart Hotel System Development Team
**最后更新**: 2026-04-10
