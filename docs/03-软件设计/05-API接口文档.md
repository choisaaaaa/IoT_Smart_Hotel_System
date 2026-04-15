# 智慧酒店物联网控制系统 - API 接口文档

## 📋 接口概述

本系统提供标准的 RESTful API 接口，所有请求均通过 HTTP/HTTPS 协议通信，数据交换格式统一为 `JSON`。

- **基准路径**：`/api/v1`
- **认证方式**：请求头携带 `Authorization: Bearer <token>`
- **成功响应格式**：
  ```json
  {
    "code": 200,
    "message": "success",
    "data": { ... }
  }
  ```

---

## 🏗️ 核心接口模块

### 1. 认证与账户 (`/auth`)
- `POST /auth/login`: 用户登录 (手机号/密码)，返回 JWT Token。
- `GET /auth/me`: 获取当前登录用户信息及权限。
- `POST /auth/register`: 新用户注册。
- `POST /auth/logout`: 登出系统，注销会话。

### 2. 酒店资源管理 (`/hotels`, `/rooms`, `/room-types`)
- `GET /hotels/search`: 根据目的地和日期搜索酒店。
- `GET /hotels/:id/rooms/availability`: 查询指定酒店的房型余量及价格。
- `GET /rooms`: 获取房间列表 (支持分页及状态筛选)。
- `PATCH /rooms/:id/status`: 更新房间状态 (空闲/在住/清洁等)。
- `GET /room-types`: 获取所有房型定义及基础价格（按酒店过滤）。
- `GET /rooms/guest/my-room`: 获取顾客当前入住房间信息（需 customer 角色，通过 user_id 或 guest_phone 匹配入住记录）。
- `GET /rooms/guest/:id/devices`: 获取顾客入住房间的设备列表（需 customer 角色）。

### 2.1 酒店报表 (`/hotel/reports`)
- `GET /hotel/reports`: 获取酒店账单报表数据（需 hotel_admin/system_admin/staff 权限）。
  - 返回字段：`today_revenue`(今日营收)、`month_revenue`(本月累计)、`pending_bills`(待结算账单数)、`revenue_trend`(近7日营收趋势)、`income_composition`(收入构成)、`bills`(账单明细列表)。
  - 系统管理员可通过 `hotel_id` 查询参数指定酒店。

### 2.2 酒店统计 (`/hotel/statistics`)
- `GET /hotel/statistics`: 获取集团/酒店运营统计数据（需 system_admin/hotel_admin/staff 权限）。
  - 返回字段：`hotel_count`(酒店数)、`member_count`(会员数)、`device_count`(设备数)、`total_revenue`(总营收)、`total_orders`(总订单数)、`monthly_revenue`(月度营收趋势)、`hotel_revenue_ranking`(酒店营收排名)。
  - 系统管理员返回全集团数据，酒店管理员/员工仅返回所属酒店数据。

### 2.3 酒店列表 (`/hotel/all`)
- `GET /hotel/all`: 获取酒店列表（需 system_admin/hotel_admin 权限）。
  - 系统管理员返回所有酒店列表。
  - 酒店管理员仅返回自己管理的酒店信息。

### 3. 物联网设备控制 (`/devices`)
- `GET /devices`: 获取设备列表及在线状态（支持 hotel_admin/staff/system_admin/customer 角色，顾客仅可查看自己入住房间的设备）。
- `GET /devices/:id`: 获取设备详情（支持 hotel_admin/staff/system_admin/customer 角色，顾客仅可查看自己入住房间的设备）。
- `POST /devices/:id/command`: 发送控制指令，指令通过 MQTT 转发至硬件（支持 hotel_admin/staff/system_admin/customer 角色，顾客仅可控制自己入住房间的设备）。
- `POST /devices/room-card`: 发卡/房卡操作（支持 hotel_admin/staff/system_admin 角色）。
- `GET /devices/:id/history`: 查询设备的传感器历史数据。
- `DELETE /devices/:id`: 移除设备。

### 4. 业务订单系统 (`/bookings`, `/payments`)
- `POST /bookings`: 创建客房预订（自动关联用户账号，通过手机号匹配 user_id；自动设置 auto_checkout_at 为退房日期中午12:00）。
- `GET /bookings/lookup`: 顾客查询预订（用于在线入住前验证）。
  - **业务逻辑**：仅返回状态为 `pending` 或 `confirmed` 且 **退房日期未过期** 的订单。
- `GET /bookings/calculate-price`: 预计算订单总价 (考虑优惠券及会员折扣)。
- `PUT /bookings/:id/checkin`: 办理入住，激活房卡（自动通过手机号关联用户账号，设置 auto_checkout_at）。
- `POST /bookings/:id/checkin-online`: 顾客在线办理入住。
  - **业务逻辑**：将状态改为 `pre_checked_in`（预入住），需校验退房日期未过期。
- `PUT /bookings/:id/checkout`: 办理退房，结清账单。
- `PUT /bookings/:id/cancel`: 取消预订。
- `POST /bookings/:id/extend-price`: 计算续住价格（需登录，支持优惠券和积分抵扣参数）。
  - 请求体：`{ new_check_out_date: string, coupon_id?: number, used_points?: number }`
  - 返回：`{ base_price, discount_rate, member_discount, coupon_discount, points_discount, used_points, total_price, extend_nights }`
- `PUT /bookings/:id/extend`: 提交续住申请（需登录，自动处理优惠券核销、积分扣减、支付记录创建）。
  - 请求体：`{ new_check_out_date: string, coupon_id?: number, used_points?: number, payment_method?: string }`
  - 返回：`{ booking_id, new_check_out_date, extend_nights, additional_price, new_total_price, need_payment, payment_id, coupon_used }`
  - 业务逻辑：校验预订状态（checked_in/confirmed）→ 检查日期冲突 → 计算续住价格 → 核销优惠券 → 扣减积分 → 更新退房日期和总价 → 创建支付记录 → 更新自动退房时间
- `POST /payments/create`: 发起支付请求。

### 5. 客房服务与通信 (`/delivery`, `/maintenance`, `/calls`)
- `POST /delivery`: 下单送物服务。
- `POST /maintenance`: 提交报修工单。
- `GET /calls/active`: 获取当前正在进行的语音通话。
- `POST /calls/initiate`: 发起呼叫请求。

### 6. AI 智能管家 (`/ai-butler`)
- `POST /ai-butler/chat`: 发送文本/语音指令，获取 AI 响应及 Function Calling 结果。
- `GET /ai-butler/config`: 获取 AI 管家的个性化配置。

### 7. AI知识库管理 (`/knowledge-base`)
> **权限要求**：`hotel_admin`（门店经理）、`system_admin`（系统管理员）
>
> **业务说明**：各门店经理通过此接口维护本店的知识库内容，AI管家回复时只能使用已启用的知识库数据，避免编造信息。

#### 7.1 获取知识库列表
- **接口**：`GET /knowledge-base`
- **说明**：获取当前登录用户所属酒店的所有知识库条目
- **查询参数**：
  - `category` (可选): 按分类筛选，枚举值：restaurant/gym/wifi/nearby/checkout/breakfast/room_service/policy/other
  - `is_active` (可选): 按启用状态筛选，0=禁用，1=启用
- **响应示例**：
  ```json
  {
    "code": 200,
    "message": "获取知识库列表成功",
    "data": [
      {
        "id": 1,
        "hotel_id": 1,
        "category": "restaurant",
        "title": "餐厅信息",
        "content": "🍽️ **餐厅营业时间**\n\n• **早餐**：07:00 - 10:00...",
        "keywords": "餐厅,早餐,午餐,晚餐,送餐",
        "is_active": 1,
        "sort_order": 100,
        "created_at": "2024-01-15T10:30:00Z",
        "updated_at": "2024-03-20T14:20:00Z"
      }
    ]
  }
  ```

#### 7.2 获取单个知识条目
- **接口**：`GET /knowledge-base/:id`
- **说明**：根据ID获取指定知识条目详情
- **路径参数**：
  - `id`: 知识条目ID

#### 7.3 创建/更新知识条目
- **接口**：`PUT /knowledge-base/:category`
- **说明**：创建或更新指定分类的知识条目（每个酒店每个分类只能有一条记录）
- **路径参数**：
  - `category`: 知识分类（restaurant/gym/wifi等）
- **请求体**：
  ```json
  {
    "title": "餐厅信息",
    "content": "🍽️ **餐厅营业时间**\n\n• **早餐**：07:00 - 10:00（1楼西餐厅）\n• **午餐**：11:30 - 14:00\n• **晚餐**：17:30 - 21:00\n\n**特色菜品**：\n- 本帮红烧肉（招牌菜）\n- 清蒸鲈鱼（时令海鲜）",
    "keywords": "餐厅,早餐,午餐,晚餐,美食,用餐时间",
    "is_active": true,
    "sort_order": 100
  }
  ```
- **响应示例**：
  ```json
  {
    "code": 200,
    "message": "知识条目更新成功",
    "data": {
      "id": 1,
      "hotel_id": 1,
      "category": "restaurant",
      "title": "餐厅信息",
      ...
    }
  }
  ```
- **特殊响应**：
  - 如果该分类下已有记录，则执行更新操作
  - 如果该分类下无记录，则执行创建操作

#### 7.4 切换知识条目启用状态
- **接口**：`PATCH /knowledge-base/:id/toggle`
- **说明**：切换指定知识条目的启用/禁用状态
- **路径参数**：
  - `id`: 知识条目ID
- **响应示例**：
  ```json
  {
    "code": 200,
    "message": "状态更新成功",
    "data": { "is_active": false }
  }
  ```

#### 7.5 删除知识条目
- **接口**：`DELETE /knowledge-base/:id`
- **说明**：删除指定的知识条目（仅系统管理员可删除）
- **路径参数**：
  - `id`: 知识条目ID
- **权限**：仅 `system_admin` 可调用

#### 7.6 批量初始化知识库（可选）
- **接口**：`POST /knowledge-base/init`
- **说明**：为当前酒店批量创建默认知识库模板（仅当知识库为空时可调用）
- **响应示例**：
  ```json
  {
    "code": 200,
    "message": "知识库初始化成功，已创建8个默认条目",
    "data": { "count": 8 }
  }
  ```

### 8. 系统全局配置 (`/system-config`)
> **权限要求**：`system_admin` (部分接口公开)

#### 8.1 获取所有系统配置
- **接口**：`GET /system-config`
- **说明**：获取所有系统全局配置项，包括会员方案、积分率等。
- **返回数据**：`{ member_program_name, member_scheme: [...], points_rate, points_redeem_rate }`

#### 8.2 获取单个配置项
- **接口**：`GET /system-config/:key`
- **说明**：获取指定键名的配置值（公开接口）。

#### 8.3 批量更新配置
- **接口**：`POST /system-config`
- **权限**：仅 `system_admin`
- **请求体**：`{ key: value, ... }` (支持嵌套 JSON 对象作为 value)

---

## 📡 实时推送 (WebSocket)

- **事件列表**：
  - `device_status_change`: 设备在线/离线或状态变更提醒。
  - `new_order_notice`: 收到新的预订或服务订单。
  - `emergency_alarm`: SOS 报警信息实时推送。
  - `voice_call_signal`: 语音通话信令交换。

---

## 🛠️ 错误处理

| 状态码 | 说明 | 处理建议 |
|:---:|:---|:---|
| `400` | 参数错误 | 检查请求体字段及格式 |
| `401` | 未授权 | 重新登录获取 Token |
| `403` | 权限不足 | 检查当前角色是否有权访问该接口 |
| `404` | 资源不存在 | 确认 URL 或资源 ID 正确 |
| `500` | 服务器内部错误 | 联系后端管理员排查日志 |
