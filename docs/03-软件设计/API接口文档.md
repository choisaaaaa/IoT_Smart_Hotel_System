# 智慧酒店物联网控制系统 - API接口文档

## 📋 文档概述

### 文档说明

本文档描述智慧酒店物联网控制系统的API接口设计，包括RESTful API、WebSocket API、MQTT API、认证方式、错误码等内容。

### 适用范围

- 后端API开发
- 前端API调用
- 嵌入式设备通信
- API测试
- API文档维护

### 文档版本

- **v2.2.0** - 2026年4月
  - 新增常用入住人管理接口（CRUD）
  - 新增住客管理接口（入住登记、退房管理）
  - 新增员工信息管理接口
  - 新增设备注册、审核、指令下发接口
  - 新增通话管理接口（发起、接听、挂断、查询）
  - 新增WebSocket实时通信接口
  - 新增MQTT设备通信接口
  - 优化系统架构设计

***

## 📡 API概览

### API基路径

```
/api/v1
```

### API版本

- **v1** - 第一版API

### 请求格式

- **Content-Type**: `application/json`
- **Accept**: `application/json`

### 响应格式

- **Content-Type**: `application/json`

### 认证方式

- **JWT Token**: JSON Web Token认证（用户认证）
- **设备认证**: 设备ID + 设备密钥（设备认证）

***

## 🔐 认证接口

### 1. 生成 API Token

**接口说明**：用户登录并生成一次性 API Token（用于扫码登录）

**请求方式**：`POST`

**请求路径**：`/auth/generate-token`

**请求头**：

```
Content-Type: application/json
```

**请求体**：

```json
{
  "username": "admin",
  "password": "password123"
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "Token 生成成功，请在 5 分钟内使用",
  "data": {
    "token": "a1b2c3d4e5f6...",
    "expiresAt": "2026-04-08T10:00:00.000Z"
  }
}
```

***

### 2. 扫码登录

**接口说明**：使用 API Token 进行登录，获取 JWT Token

**请求方式**：`POST`

**请求路径**：`/auth/scan-login`

**请求头**：

```
Content-Type: application/json
```

**请求体**：

```json
{
  "token": "a1b2c3d4e5f6..."
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "登录成功",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 1,
      "username": "admin",
      "role": "admin"
    }
  }
}
```

***

### 2. 用户登出

**接口说明**：用户登出，使Token失效

**请求方式**：`POST`

**请求路径**：`/auth/logout`

**请求头**：

```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：

```json
{}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "登出成功",
  "data": null
}
```

***

### 3. 获取常用入住人列表

**接口说明**：获取当前用户的常用入住人名册

**请求方式**：`GET`

**请求路径**：`/frequent-guests`

**请求头**：

```
Authorization: Bearer <token>
```

**响应示例**：

```json
{
  "code": 200,
  "message": "success",
  "data": {
    "guests": [
      {
        "id": 1,
        "name": "张三",
        "phone": "13800138000",
        "id_type": "idcard",
        "id_number": "110101199001011234"
      }
    ]
  }
}
```

***

### 4. 添加常用入住人

**接口说明**：添加新的入住人到名册

**请求方式**：`POST`

**请求路径**：`/frequent-guests`

**请求头**：

```
Authorization: Bearer <token>
Content-Type: application/json
```

**请求体**：

```json
{
  "name": "李四",
  "phone": "13900139000",
  "id_type": "idcard",
  "id_number": "110101199001015678"
}
```

***

### 3. 刷新Token

**接口说明**：刷新JWT Token

**请求方式**：`POST`

**请求路径**：`/auth/refresh`

**请求头**：

```
Content-Type: application/json
Authorization: Bearer <refresh_token>
```

**请求体**：

```json
{}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "刷新成功",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expires_in": 604800
  }
}
```

**错误码**：

- `401` - Token无效或已过期

***

### 4. 获取用户信息

**接口说明**：获取当前用户信息

**请求方式**：`GET`

**请求路径**：`/auth/profile`

**请求头**：

```
Authorization: Bearer <token>
```

**响应示例**：

```json
{
  "code": 200,
  "message": "获取成功",
  "data": {
    "id": 1,
    "username": "admin",
    "email": "admin@example.com",
    "role": "admin",
    "permissions": ["read", "write", "delete"],
    "created_at": "2024-01-01 00:00:00",
    "updated_at": "2024-01-18 00:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期

***

## 🏨 酒店管理接口

### 1. 获取酒店信息

**接口说明**：获取酒店基本信息

**请求方式**：`GET`

**请求路径**：`/hotels/info`

**请求头**：

```
Authorization: Bearer <token>
```

**响应示例**：

```json
{
  "code": 200,
  "message": "获取成功",
  "data": {
    "hotel_id": 1,
    "hotel_name": "智联酒店",
    "hotel_address": "北京市朝阳区XX路XX号",
    "hotel_phone": "010-12345678",
    "hotel_star": 4,
    "total_rooms": 100,
    "occupied_rooms": 45,
    "occupancy_rate": 45.0,
    "created_at": "2024-01-01 00:00:00",
    "updated_at": "2024-01-18 00:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期

***

### 2. 更新酒店信息

**接口说明**：更新酒店基本信息

**请求方式**：`PUT`

**请求路径**：`/hotels/info`

**请求头**：

```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：

```json
{
  "hotel_name": "智联酒店",
  "hotel_address": "北京市朝阳区XX路XX号",
  "hotel_phone": "010-12345678",
  "hotel_star": 4
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "更新成功",
  "data": {
    "hotel_id": 1,
    "hotel_name": "智联酒店",
    "hotel_address": "北京市朝阳区XX路XX号",
    "hotel_phone": "010-12345678",
    "hotel_star": 4,
    "updated_at": "2024-01-18 10:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `400` - 请求参数错误

***

## 🚪 房间管理接口

### 1. 获取房间列表

**接口说明**：获取所有房间列表

**请求方式**：`GET`

**请求路径**：`/rooms`

**请求头**：

```
Authorization: Bearer <token>
```

**查询参数**：

```
?page=1&limit=10&status=available&type=standard
```

**响应示例**：

```json
{
  "code": 200,
  "message": "获取成功",
  "data": {
    "total": 100,
    "page": 1,
    "limit": 10,
    "items": [
      {
        "room_id": 1,
        "room_number": "101",
        "room_type": "standard",
        "room_name": "标准单人房",
        "room_price": 299.00,
        "room_status": "available",
        "floor": 1,
        "area": 25.5,
        "bed_type": "single",
        "max_guests": 1,
        "description": "舒适的标准单人房",
        "created_at": "2024-01-01 00:00:00",
        "updated_at": "2024-01-18 00:00:00"
      },
      {
        "room_id": 2,
        "room_number": "102",
        "room_type": "deluxe",
        "room_name": "豪华双人房",
        "room_price": 499.00,
        "room_status": "occupied",
        "floor": 1,
        "area": 35.0,
        "bed_type": "double",
        "max_guests": 2,
        "description": "宽敞的豪华双人房",
        "created_at": "2024-01-01 00:00:00",
        "updated_at": "2024-01-18 00:00:00"
      }
    ]
  }
}
```

**错误码**：

- `401` - Token无效或已过期

***

### 2. 获取房间详情

**接口说明**：获取指定房间详情

**请求方式**：`GET`

**请求路径**：`/rooms/:room_id`

**请求头**：

```
Authorization: Bearer <token>
```

**响应示例**：

```json
{
  "code": 200,
  "message": "获取成功",
  "data": {
    "room_id": 1,
    "room_number": "101",
    "room_type": "standard",
    "room_name": "标准单人房",
    "room_price": 299.00,
    "room_status": "available",
    "floor": 1,
    "area": 25.5,
    "bed_type": "single",
    "max_guests": 1,
    "description": "舒适的标准单人房",
    "facilities": ["WiFi", "电视", "空调", "电话"],
    "images": ["http://example.com/image1.jpg", "http://example.com/image2.jpg"],
    "created_at": "2024-01-01 00:00:00",
    "updated_at": "2024-01-18 00:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `404` - 房间不存在

***

### 3. 创建房间

**接口说明**：创建新房间

**请求方式**：`POST`

**请求路径**：`/rooms`

**请求头**：

```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：

```json
{
  "room_number": "103",
  "room_type": "standard",
  "room_name": "标准单人房",
  "room_price": 299.00,
  "floor": 1,
  "area": 25.5,
  "bed_type": "single",
  "max_guests": 1,
  "description": "舒适的标准单人房",
  "facilities": ["WiFi", "电视", "空调", "电话"]
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "创建成功",
  "data": {
    "room_id": 3,
    "room_number": "103",
    "room_type": "standard",
    "room_name": "标准单人房",
    "room_price": 299.00,
    "room_status": "available",
    "floor": 1,
    "area": 25.5,
    "bed_type": "single",
    "max_guests": 1,
    "description": "舒适的标准单人房",
    "created_at": "2024-01-18 10:00:00",
    "updated_at": "2024-01-18 10:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `400` - 请求参数错误
- `409` - 房间号已存在

***

### 4. 更新房间信息

**接口说明**：更新房间信息

**请求方式**：`PUT`

**请求路径**：`/rooms/:room_id`

**请求头**：

```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：

```json
{
  "room_price": 329.00,
  "description": "升级后的标准单人房",
  "facilities": ["WiFi", "电视", "空调", "电话", "迷你吧"]
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "更新成功",
  "data": {
    "room_id": 1,
    "room_price": 329.00,
    "description": "升级后的标准单人房",
    "facilities": ["WiFi", "电视", "空调", "电话", "迷你吧"],
    "updated_at": "2024-01-18 10:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `404` - 房间不存在
- `400` - 请求参数错误

***

### 5. 删除房间

**接口说明**：删除指定房间

**请求方式**：`DELETE`

**请求路径**：`/rooms/:room_id`

**请求头**：

```
Authorization: Bearer <token>
```

**响应示例**：

```json
{
  "code": 200,
  "message": "删除成功",
  "data": null
}
```

**错误码**：

- `401` - Token无效或已过期
- `404` - 房间不存在
- `400` - 房间有未完成订单，不能删除

***

### 6. 更新房间状态

**接口说明**：更新房间状态（空闲/入住/维修/清洁中）

**请求方式**：`PATCH`

**请求路径**：`/rooms/:room_id/status`

**请求头**：

```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：

```json
{
  "status": "occupied",
  "reason": "客人入住",
  "guest_id": 1
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "状态更新成功",
  "data": {
    "room_id": 1,
    "room_status": "occupied",
    "updated_at": "2024-01-18 10:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `404` - 房间不存在
- `400` - 请求参数错误

***

### 7. 批量更新房间状态

**接口说明**：批量更新房间状态（如全楼清洁中）

**请求方式**：`PATCH`

**请求路径**：`/rooms/batch/status`

**请求头**：

```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：

```json
{
  "room_ids": [1, 2, 3, 4, 5],
  "status": "cleaning",
  "reason": "日常清洁"
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "批量更新成功",
  "data": {
    "updated_count": 5,
    "updated_rooms": [1, 2, 3, 4, 5]
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `400` - 请求参数错误

***

## 📅 预订管理接口

### 1. 创建预订

**接口说明**：创建新预订

**请求方式**：`POST`

**请求路径**：`/bookings`

**请求头**：

```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：

```json
{
  "room_id": 1,
  "guest_name": "张三",
  "guest_phone": "13800138000",
  "guest_id_number": "110101199001011234",
  "check_in_date": "2024-01-20",
  "check_out_date": "2024-01-22",
  "guest_count": 2,
  "special_requests": "需要安静的房间",
  "payment_method": "balance"
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "预订成功",
  "data": {
    "booking_id": 1,
    "booking_number": "BK20240118001",
    "room_id": 1,
    "room_number": "101",
    "guest_name": "张三",
    "guest_phone": "13800138000",
    "guest_id_number": "110101199001011234",
    "check_in_date": "2024-01-20",
    "check_out_date": "2024-01-22",
    "guest_count": 2,
    "special_requests": "需要安静的房间",
    "payment_method": "balance",
    "total_price": 598.00,
    "deposit": 0.00,
    "status": "confirmed",
    "created_at": "2024-01-18 10:00:00",
    "updated_at": "2024-01-18 10:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `400` - 请求参数错误
- `409` - 房间已被预订

***

### 2. 获取预订列表

**接口说明**：获取预订列表

**请求方式**：`GET`

**请求路径**：`/bookings`

**请求头**：

```
Authorization: Bearer <token>
```

**查询参数**：

```
?page=1&limit=10&status=confirmed&check_in_date=2024-01-20
```

**响应示例**：

```json
{
  "code": 200,
  "message": "获取成功",
  "data": {
    "total": 5,
    "page": 1,
    "limit": 10,
    "items": [
      {
        "booking_id": 1,
        "booking_number": "BK20240118001",
        "room_id": 1,
        "room_number": "101",
        "guest_name": "张三",
        "guest_phone": "13800138000",
        "check_in_date": "2024-01-20",
        "check_out_date": "2024-01-22",
        "guest_count": 2,
        "total_price": 598.00,
        "status": "confirmed",
        "created_at": "2024-01-18 10:00:00"
      },
      {
        "booking_id": 2,
        "booking_number": "BK20240118002",
        "room_id": 2,
        "room_number": "102",
        "guest_name": "李四",
        "guest_phone": "13900139000",
        "check_in_date": "2024-01-21",
        "check_out_date": "2024-01-23",
        "guest_count": 1,
        "total_price": 998.00,
        "status": "pending",
        "created_at": "2024-01-18 11:00:00"
      }
    ]
  }
}
```

**错误码**：

- `401` - Token无效或已过期

***

### 3. 获取预订详情

**接口说明**：获取指定预订详情

**请求方式**：`GET`

**请求路径**：`/bookings/:booking_id`

**请求头**：

```
Authorization: Bearer <token>
```

**响应示例**：

```json
{
  "code": 200,
  "message": "获取成功",
  "data": {
    "booking_id": 1,
    "booking_number": "BK20240118001",
    "room_id": 1,
    "room_number": "101",
    "room_type": "standard",
    "room_name": "标准单人房",
    "guest_name": "张三",
    "guest_phone": "13800138000",
    "guest_id_number": "110101199001011234",
    "check_in_date": "2024-01-20",
    "check_out_date": "2024-01-22",
    "guest_count": 2,
    "special_requests": "需要安静的房间",
    "payment_method": "balance",
    "total_price": 598.00,
    "deposit": 0.00,
    "status": "confirmed",
    "created_at": "2024-01-18 10:00:00",
    "updated_at": "2024-01-18 10:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `404` - 预订不存在

***

### 4. 更新预订

**接口说明**：更新预订信息

**请求方式**：`PUT`

**请求路径**：`/bookings/:booking_id`

**请求头**：

```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：

```json
{
  "check_out_date": "2024-01-23",
  "special_requests": "需要延迟退房"
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "更新成功",
  "data": {
    "booking_id": 1,
    "check_out_date": "2024-01-23",
    "special_requests": "需要延迟退房",
    "total_price": 627.00,
    "updated_at": "2024-01-18 11:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `404` - 预订不存在
- `400` - 请求参数错误

***

### 5. 取消预订

**接口说明**：取消预订

**请求方式**：`DELETE`

**请求路径**：`/bookings/:booking_id`

**请求头**：

```
Authorization: Bearer <token>
```

**响应示例**：

```json
{
  "code": 200,
  "message": "取消成功",
  "data": {
    "booking_id": 1,
    "status": "cancelled",
    "cancelled_at": "2024-01-18 12:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `404` - 预订不存在
- `400` - 预订已入住，不能取消

***

### 6. 入住登记

**接口说明**：办理入住登记

**请求方式**：`POST`

**请求路径**：`/bookings/:booking_id/check-in`

**请求头**：

```
Authorization: Bearer <token>
```

**响应示例**：

```json
{
  "code": 200,
  "message": "入住成功",
  "data": {
    "booking_id": 1,
    "status": "checked_in",
    "check_in_time": "2024-01-20 14:00:00",
    "room_status": "occupied"
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `404` - 预订不存在
- `400` - 预订未确认或已入住

***

### 7. 退房结账

**接口说明**：办理退房结账

**请求方式**：`POST`

**请求路径**：`/bookings/:booking_id/check-out`

**请求头**：

```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：

```json
{
  "extra_charges": 50.00,
  "extra_charges_description": "迷你吧消费"
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "退房成功",
  "data": {
    "booking_id": 1,
    "status": "checked_out",
    "check_out_time": "2024-01-22 12:00:00",
    "room_status": "cleaning",
    "total_amount": 677.00,
    "paid_amount": 677.00,
    "refund_amount": 0.00
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `404` - 预订不存在
- `400` - 预订未入住或已退房

***

## 💳 支付管理接口

### 1. 创建支付订单

**接口说明**：创建支付订单

**请求方式**：`POST`

**请求路径**：`/payments`

**请求头**：

```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：

```json
{
  "order_type": "booking",
  "order_id": 1,
  "amount": 598.00,
  "payment_method": "wechat",
  "description": "预订101房支付"
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "创建成功",
  "data": {
    "payment_id": 1,
    "payment_no": "PAY20240118001",
    "order_type": "booking",
    "order_id": 1,
    "amount": 598.00,
    "payment_method": "wechat",
    "status": "pending",
    "description": "预订101房支付",
    "created_at": "2024-01-18 10:00:00",
    "updated_at": "2024-01-18 10:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `400` - 请求参数错误

***

### 2. 查询支付订单

**接口说明**：查询支付订单状态

**请求方式**：`GET`

**请求路径**：`/payments/:payment_id`

**请求头**：

```
Authorization: Bearer <token>
```

**响应示例**：

```json
{
  "code": 200,
  "message": "查询成功",
  "data": {
    "payment_id": 1,
    "payment_no": "PAY20240118001",
    "order_type": "booking",
    "order_id": 1,
    "amount": 598.00,
    "payment_method": "wechat",
    "status": "paid",
    "transaction_no": "100000000020240118123456",
    "paid_at": "2024-01-18 10:05:00",
    "created_at": "2024-01-18 10:00:00",
    "updated_at": "2024-01-18 10:05:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `404` - 支付订单不存在

***

### 3. 微信支付回调

**接口说明**：微信支付回调接口（异步）

**请求方式**：`POST`

**请求路径**：`/payments/wechat/callback`

**请求头**：

```
Content-Type: application/xml
```

**请求体**：

```xml
<xml>
  <appid><![CDATA[wx1234567890abcdef]]></appid>
  <mch_id><![CDATA[1234567890]]></mch_id>
  <nonce_str><![CDATA[5K8264ILTKCH16CQ2502SI8ZNMTM67VS]]></nonce_str>
  <sign><![CDATA[C380BEC2BFD727A4B6845133519F3AD6]]></sign>
  <result_code><![CDATA[SUCCESS]]></result_code>
  <openid><![CDATA[oUpF8uN95-P234567890abcdef]]></openid>
  <trade_type><![CDATA[NATIVE]]></trade_type>
  <bank_type><![CDATA[CCB_CREDIT]]></bank_type>
  <total_fee>1</total_fee>
  <fee_type><![CDATA[CNY]]></fee_type>
  <transaction_id><![CDATA[1000000000202401181234567890]]></transaction_id>
  <out_trade_no><![CDATA[PAY20240118001]]></out_trade_no>
  <attach><![CDATA[booking_1]]></attach>
  <time_end><![CDATA[20240118100500]]></time_end>
</xml>
```

**响应示例**：

```xml
<xml>
  <return_code><![CDATA[SUCCESS]]></return_code>
  <return_msg><![CDATA[OK]]></return_msg>
</xml>
```

**错误码**：

- `400` - 签名验证失败
- `400` - 订单不存在
- `400` - 订单已支付

***

### 4. 支付宝支付回调

**接口说明**：支付宝支付回调接口（异步）

**请求方式**：`POST`

**请求路径**：`/payments/alipay/callback`

**请求头**：

```
Content-Type: application/x-www-form-urlencoded
```

**请求体**：

```
app_id=2021000123456789&charset=utf-8&method=alipay.trade.app.pay.return&format=json&sign=xxx&...
```

**响应示例**：

```
success
```

**错误码**：

- `400` - 签名验证失败
- `400` - 订单不存在
- `400` - 订单已支付

***

## 👥 会员管理接口

### 1. 会员注册

**接口说明**：会员注册

**请求方式**：`POST`

**请求路径**：`/members/register`

**请求头**：

```
Content-Type: application/json
```

**请求体**：

```json
{
  "phone": "13800138000",
  "password": "password123",
  "name": "张三",
  "id_number": "110101199001011234"
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "注册成功",
  "data": {
    "member_id": 1,
    "phone": "13800138000",
    "name": "张三",
    "id_number": "110101199001011234",
    "member_level": "standard",
    "points": 0,
    "balance": 0.00,
    "created_at": "2024-01-18 10:00:00"
  }
}
```

**错误码**：

- `400` - 手机号已注册
- `400` - 请求参数错误

***

### 2. 会员登录

**接口说明**：会员登录

**请求方式**：`POST`

**请求路径**：`/members/login`

**请求头**：

```
Content-Type: application/json
```

**请求体**：

```json
{
  "phone": "13800138000",
  "password": "password123"
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "登录成功",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expires_in": 604800,
    "member": {
      "member_id": 1,
      "phone": "13800138000",
      "name": "张三",
      "member_level": "standard",
      "points": 100,
      "balance": 50.00
    }
  }
}
```

**错误码**：

- `401` - 手机号或密码错误
- `404` - 会员不存在

***

### 3. 获取会员信息

**接口说明**：获取会员信息

**请求方式**：`GET`

**请求路径**：`/members/profile`

**请求头**：

```
Authorization: Bearer <token>
```

**响应示例**：

```json
{
  "code": 200,
  "message": "获取成功",
  "data": {
    "member_id": 1,
    "phone": "13800138000",
    "name": "张三",
    "id_number": "110101199001011234",
    "member_level": "standard",
    "points": 100,
    "balance": 50.00,
    "total_spent": 1000.00,
    "total_stays": 5,
    "created_at": "2024-01-01 00:00:00",
    "updated_at": "2024-01-18 00:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期

***

### 4. 升级会员等级

**接口说明**：升级会员等级

**请求方式**：`POST`

**请求路径**：`/members/upgrade`

**请求头**：

```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：

```json
{
  "upgrade_type": "payment",
  "amount": 1000.00
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "升级成功",
  "data": {
    "member_id": 1,
    "old_level": "standard",
    "new_level": "gold",
    "points": 1100,
    "updated_at": "2024-01-18 10:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `400` - 不满足升级条件

***

### 5. 积分兑换

**接口说明**：积分兑换

**请求方式**：`POST`

**请求路径**：`/members/exchange-points`

**请求头**：

```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：

```json
{
  "exchange_type": "cash",
  "points": 100,
  "cash_amount": 10.00
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "兑换成功",
  "data": {
    "member_id": 1,
    "points_before": 100,
    "points_after": 0,
    "cash_amount": 10.00,
    "created_at": "2024-01-18 10:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `400` - 积分不足

***

## 🎫 优惠券管理接口

### 1. 领取优惠券

**接口说明**：领取优惠券

**请求方式**：`POST`

**请求路径**：`/coupons/receive`

**请求头**：

```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：

```json
{
  "coupon_id": 1
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "领取成功",
  "data": {
    "user_coupon_id": 1,
    "coupon_id": 1,
    "coupon_name": "满200减50优惠券",
    "coupon_type": "discount",
    "discount_value": 50.00,
    "min_amount": 200.00,
    "valid_from": "2024-01-18",
    "valid_to": "2024-02-18",
    "status": "unused",
    "created_at": "2024-01-18 10:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `400` - 优惠券已领完
- `400` - 优惠券已过期

***

### 2. 获取会员优惠券列表

**接口说明**：获取会员优惠券列表

**请求方式**：`GET`

**请求路径**：`/coupons`

**请求头**：

```
Authorization: Bearer <token>
```

**查询参数**：

```
?status=unused&valid_to=2024-02-18
```

**响应示例**：

```json
{
  "code": 200,
  "message": "获取成功",
  "data": {
    "total": 3,
    "page": 1,
    "limit": 10,
    "items": [
      {
        "user_coupon_id": 1,
        "coupon_id": 1,
        "coupon_name": "满200减50优惠券",
        "coupon_type": "discount",
        "discount_value": 50.00,
        "min_amount": 200.00,
        "valid_from": "2024-01-18",
        "valid_to": "2024-02-18",
        "status": "unused",
        "created_at": "2024-01-18 10:00:00"
      },
      {
        "user_coupon_id": 2,
        "coupon_id": 2,
        "coupon_name": "8折优惠券",
        "coupon_type": "percentage",
        "discount_value": 20.00,
        "min_amount": 100.00,
        "valid_from": "2024-01-01",
        "valid_to": "2024-12-31",
        "status": "used",
        "used_at": "2024-01-15 10:00:00"
      }
    ]
  }
}
```

**错误码**：

- `401` - Token无效或已过期

***

### 3. 使用优惠券

**接口说明**：使用优惠券

**请求方式**：`POST`

**请求路径**：`/coupons/:user_coupon_id/use`

**请求头**：

```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：

```json
{
  "order_id": 1,
  "order_type": "booking"
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "使用成功",
  "data": {
    "user_coupon_id": 1,
    "status": "used",
    "used_at": "2024-01-18 10:00:00",
    "discount_amount": 50.00
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `400` - 优惠券已使用
- `400` - 不满足使用条件

***

## 📦 送物订单接口

### 1. 创建送物订单

**接口说明**：创建送物订单（住客端）

**请求方式**：`POST`

**请求路径**：`/delivery-orders`

**请求头**：

```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：

```json
{
  "room_id": 1,
  "item_category": "food",
  "item_name": "矿泉水",
  "quantity": 2,
  "note": "请送到房间"
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "创建成功",
  "data": {
    "order_id": 1,
    "order_no": "DLV20240118001",
    "room_id": 1,
    "room_number": "101",
    "item_category": "food",
    "item_name": "矿泉水",
    "quantity": 2,
    "note": "请送到房间",
    "status": "pending",
    "created_at": "2024-01-18 10:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `400` - 请求参数错误

***

### 2. 获取送物订单列表

**接口说明**：获取送物订单列表

**请求方式**：`GET`

**请求路径**：`/delivery-orders`

**请求头**：

```
Authorization: Bearer <token>
```

**查询参数**：

```
?page=1&limit=10&status=pending&room_id=1
```

**响应示例**：

```json
{
  "code": 200,
  "message": "获取成功",
  "data": {
    "total": 5,
    "page": 1,
    "limit": 10,
    "items": [
      {
        "order_id": 1,
        "order_no": "DLV20240118001",
        "room_id": 1,
        "room_number": "101",
        "item_category": "food",
        "item_name": "矿泉水",
        "quantity": 2,
        "status": "pending",
        "created_at": "2024-01-18 10:00:00"
      },
      {
        "order_id": 2,
        "order_no": "DLV20240118002",
        "room_id": 2,
        "room_number": "102",
        "item_category": "towel",
        "item_name": "毛巾",
        "quantity": 3,
        "status": "processing",
        "created_at": "2024-01-18 11:00:00"
      }
    ]
  }
}
```

**错误码**：

- `401` - Token无效或已过期

***

### 3. 更新送物订单状态

**接口说明**：更新送物订单状态（服务员端）

**请求方式**：`PATCH`

**请求路径**：`/delivery-orders/:order_id/status`

**请求头**：

```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：

```json
{
  "status": "completed",
  "completed_at": "2024-01-18 10:30:00"
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "更新成功",
  "data": {
    "order_id": 1,
    "status": "completed",
    "completed_at": "2024-01-18 10:30:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `404` - 订单不存在
- `400` - 状态转换错误

***

## 🔧 报修工单接口

### 1. 创建报修工单

**接口说明**：创建报修工单

**请求方式**：`POST`

**请求路径**：`/maintenance-tickets`

**请求头**：

```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：

```json
{
  "room_id": 1,
  "fault_type": "air_conditioner",
  "fault_description": "空调不制冷",
  "photos": ["http://example.com/photo1.jpg"],
  "priority": "high"
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "创建成功",
  "data": {
    "ticket_id": 1,
    "ticket_no": "MT20240118001",
    "room_id": 1,
    "room_number": "101",
    "fault_type": "air_conditioner",
    "fault_description": "空调不制冷",
    "photos": ["http://example.com/photo1.jpg"],
    "priority": "high",
    "status": "pending",
    "created_at": "2024-01-18 10:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `400` - 请求参数错误

***

### 2. 获取报修工单列表

**接口说明**：获取报修工单列表

**请求方式**：`GET`

**请求路径**：`/maintenance-tickets`

**请求头**：

```
Authorization: Bearer <token>
```

**查询参数**：

```
?page=1&limit=10&status=pending&priority=high
```

**响应示例**：

```json
{
  "code": 200,
  "message": "获取成功",
  "data": {
    "total": 5,
    "page": 1,
    "limit": 10,
    "items": [
      {
        "ticket_id": 1,
        "ticket_no": "MT20240118001",
        "room_id": 1,
        "room_number": "101",
        "fault_type": "air_conditioner",
        "fault_description": "空调不制冷",
        "priority": "high",
        "status": "pending",
        "created_at": "2024-01-18 10:00:00"
      },
      {
        "ticket_id": 2,
        "ticket_no": "MT20240118002",
        "room_id": 2,
        "room_number": "102",
        "fault_type": "lighting",
        "fault_description": "灯光不亮",
        "priority": "medium",
        "status": "processing",
        "created_at": "2024-01-18 11:00:00"
      }
    ]
  }
}
```

**错误码**：

- `401` - Token无效或已过期

***

### 3. 更新报修工单状态

**接口说明**：更新报修工单状态（维修工端）

**请求方式**：`PATCH`

**请求路径**：`/maintenance-tickets/:ticket_id/status`

**请求头**：

```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：

```json
{
  "status": "completed",
  "completed_at": "2024-01-18 10:30:00",
  "repair_description": "更换空调压缩机",
  "repair_cost": 500.00
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "更新成功",
  "data": {
    "ticket_id": 1,
    "status": "completed",
    "completed_at": "2024-01-18 10:30:00",
    "repair_description": "更换空调压缩机",
    "repair_cost": 500.00
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `404` - 工单不存在
- `400` - 状态转换错误

***

## 📞 语音通话接口

### 1. 发起语音通话请求

**接口说明**：支持住客、前台、AI管家、手机App发起语音通话请求

**请求方式**：`POST`

**请求路径**：`/calls/initiate`

**请求头**：
```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：
```json
{
  "caller_type": "room",
  "caller_id": "301",
  "callee_type": "front_desk",
  "callee_id": "FD001",
  "type": "voice"
}
```

**请求参数说明**：

| 参数名 | 类型 | 必填 | 说明 | 示例值 |
|--------|------|------|------|--------|
| caller_type | string | 是 | 主叫方类型：`room`(客房) \| `front_desk`(前台) \| `ai`(AI管家) \| `app`(手机App) | `room` |
| caller_id | string | 是 | 主叫方ID（房间号/员工ID/AI标识/App用户ID） | `301` |
| callee_type | string | 是 | 被叫方类型：`room` \| `front_desk` \| `ai` \| `app` | `front_desk` |
| callee_id | string | 是 | 被叫方ID | `FD001` |
| type | string | 否 | 通话类型：`voice`(语音) \| `video`(视频) | `voice` |

**响应示例**：
```json
{
  "code": 200,
  "message": "通话请求已发送",
  "data": {
    "call_id": "CALL20260404001",
    "caller_type": "room",
    "caller_id": "301",
    "callee_type": "front_desk",
    "callee_id": "FD001",
    "status": "calling",
    "started_at": "2026-04-04 15:30:00"
  }
}
```

**错误码**：
- `401` - Token无效或已过期
- `400` - 请求参数错误
- `409` - 已有通话进行中

**示例场景**：

**场景1：客房发起通话**
```json
{
  "caller_type": "room",
  "caller_id": "301",
  "callee_type": "front_desk",
  "callee_id": "FD001",
  "type": "voice"
}
```

**场景2：前台发起通话**
```json
{
  "caller_type": "front_desk",
  "caller_id": "FD001",
  "callee_type": "room",
  "callee_id": "301",
  "type": "voice"
}
```

**场景3：AI管家发起通话**
```json
{
  "caller_type": "ai",
  "caller_id": "AI001",
  "callee_type": "room",
  "callee_id": "301",
  "type": "voice"
}
```

**场景4：手机App发起通话**
```json
{
  "caller_type": "app",
  "caller_id": "USER123",
  "callee_type": "front_desk",
  "callee_id": "FD001",
  "type": "voice"
}
```

***

### 2. 主动发起语音通话

**接口说明**：前台、AI管家、手机App主动呼叫指定房间或其他终端

**请求方式**：`POST`

**请求路径**：`/calls/outbound`

**请求头**：
```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：
```json
{
  "caller_type": "front_desk",
  "caller_id": "FD001",
  "callee_type": "room",
  "callee_id": "301",
  "type": "voice"
}
```

**请求参数说明**：

| 参数名 | 类型 | 必填 | 说明 | 示例值 |
|--------|------|------|------|--------|
| caller_type | string | 是 | 主叫方类型：`front_desk`(前台) \| `ai`(AI管家) \| `app`(手机App) | `front_desk` |
| caller_id | string | 是 | 主叫方ID（员工ID/AI标识/App用户ID） | `FD001` |
| callee_type | string | 是 | 被叫方类型：`room` \| `front_desk` \| `ai` \| `app` | `room` |
| callee_id | string | 是 | 被叫方ID | `301` |
| type | string | 否 | 通话类型：`voice`(语音) \| `video`(视频) | `voice` |

**响应示例**：
```json
{
  "code": 200,
  "message": "通话已发起",
  "data": {
    "call_id": "CALL20260404002",
    "caller_type": "front_desk",
    "caller_id": "FD001",
    "callee_type": "room",
    "callee_id": "301",
    "status": "outgoing",
    "started_at": "2026-04-04 15:30:00"
  }
}
```

**错误码**：
- `401` - Token无效或已过期
- `400` - 请求参数错误
- `409` - 通话已在进行中

**示例场景**：

**场景1：前台发起通话**
```json
{
  "caller_type": "front_desk",
  "caller_id": "FD001",
  "callee_type": "room",
  "callee_id": "301",
  "type": "voice"
}
```

**场景2：AI管家发起通话**
```json
{
  "caller_type": "ai",
  "caller_id": "AI001",
  "callee_type": "room",
  "callee_id": "301",
  "type": "voice"
}
```

**场景3：手机App发起通话**
```json
{
  "caller_type": "app",
  "caller_id": "USER123",
  "callee_type": "front_desk",
  "callee_id": "FD001",
  "type": "voice"
}
```

***

### 3. 接听语音通话

**接口说明**：接听语音通话（任一方）

**请求方式**：`POST`

**请求路径**：`/calls/:call_id/answer`

**请求头**：
```
Content-Type: application/json
Authorization: Bearer <token>
```

**响应示例**：
```json
{
  "code": 200,
  "message": "通话已接听",
  "data": {
    "call_id": "CALL20260404001",
    "status": "connected",
    "answered_at": "2026-04-04 15:30:05"
  }
}
```

**错误码**：
- `401` - Token无效或已过期
- `404` - 通话不存在
- `409` - 通话已结束或已拒接

***

### 4. 拒接语音通话

**接口说明**：拒接语音通话（被叫方）

**请求方式**：`POST`

**请求路径**：`/calls/:call_id/reject`

**请求头**：
```
Content-Type: application/json
Authorization: Bearer <token>
```

**响应示例**：
```json
{
  "code": 200,
  "message": "通话已拒接",
  "data": {
    "call_id": "CALL20260404001",
    "status": "rejected",
    "ended_at": "2026-04-04 15:30:10"
  }
}
```

**错误码**：
- `401` - Token无效或已过期
- `404` - 通话不存在
- `409` - 通话已结束

***

### 5. 挂断语音通话

**接口说明**：挂断语音通话（任一方）

**请求方式**：`POST`

**请求路径**：`/calls/:call_id/hangup`

**请求头**：
```
Content-Type: application/json
Authorization: Bearer <token>
```

**响应示例**：
```json
{
  "code": 200,
  "message": "通话已挂断",
  "data": {
    "call_id": "CALL20260404001",
    "status": "ended",
    "ended_at": "2026-04-04 15:35:00",
    "duration_sec": 300
  }
}
```

**错误码**：
- `401` - Token无效或已过期
- `404` - 通话不存在
- `409` - 通话已结束

***

### 6. 查询通话状态

**接口说明**：查询通话状态

**请求方式**：`GET`

**请求路径**：`/calls/:call_id/status`

**请求头**：
```
Authorization: Bearer <token>
```

**响应示例**：
```json
{
  "code": 200,
  "message": "查询成功",
  "data": {
    "call_id": "CALL20260404001",
    "caller_type": "room",
    "caller_id": "301",
    "callee_type": "front_desk",
    "callee_id": "FD001",
    "status": "connected",
    "started_at": "2026-04-04 15:30:00",
    "answered_at": "2026-04-04 15:30:05",
    "duration_sec": 300,
    "ended_at": null
  }
}
```

**错误码**：
- `401` - Token无效或已过期
- `404` - 通话不存在

***

### 7. 获取当前活跃通话列表

**接口说明**：获取当前活跃通话列表

**请求方式**：`GET`

**请求路径**：`/calls/active`

**请求头**：
```
Authorization: Bearer <token>
```

**响应示例**：
```json
{
  "code": 200,
  "message": "查询成功",
  "data": {
    "items": [
      {
        "call_id": "CALL20260404001",
        "caller_type": "room",
        "caller_id": "301",
        "callee_type": "front_desk",
        "callee_id": "FD001",
        "status": "connected",
        "started_at": "2026-04-04 15:30:00",
        "answered_at": "2026-04-04 15:30:05",
        "duration_sec": 300
      }
    ]
  }
}
```

**错误码**：
- `401` - Token无效或已过期

***

### 8. 获取通话记录

**接口说明**：获取通话记录（分页查询）

**请求方式**：`GET`

**请求路径**：`/calls/history`

**请求头**：
```
Authorization: Bearer <token>
```

**查询参数**：
```
?page=1&limit=10&room_id=301&start_time=2026-04-01&end_time=2026-04-30
```

**响应示例**：
```json
{
  "code": 200,
  "message": "查询成功",
  "data": {
    "total": 10,
    "page": 1,
    "limit": 10,
    "items": [
      {
        "call_id": "CALL20260404001",
        "caller_type": "room",
        "caller_id": "301",
        "callee_type": "front_desk",
        "callee_id": "FD001",
        "status": "ended",
        "started_at": "2026-04-04 15:30:00",
        "answered_at": "2026-04-04 15:30:05",
        "ended_at": "2026-04-04 15:35:00",
        "duration_sec": 300
      }
    ]
  }
}
```

**错误码**：
- `401` - Token无效或已过期

***

### 9. 获取通话统计

**接口说明**：获取通话统计（时长/次数/接听率）

**请求方式**：`GET`

**请求路径**：`/calls/stats`

**请求头**：
```
Authorization: Bearer <token>
```

**查询参数**：
```
?start_time=2026-04-01&end_time=2026-04-30&room_id=301
```

**响应示例**：
```json
{
  "code": 200,
  "message": "查询成功",
  "data": {
    "total_calls": 50,
    "total_duration_sec": 15000,
    "answered_calls": 45,
    "missed_calls": 3,
    "rejected_calls": 2,
    "avg_duration_sec": 300,
    "answer_rate": 0.9
  }
}
```

**错误码**：
- `401` - Token无效或已过期

***

## 📊 服务评价接口

### 1. 创建服务评价

**接口说明**：创建服务评价

**请求方式**：`POST`

**请求路径**：`/reviews`

**请求头**：

```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：

```json
{
  "order_id": 1,
  "order_type": "booking",
  "score": 5,
  "content": "房间很干净，服务很好",
  "photos": ["http://example.com/photo1.jpg"]
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "评价成功",
  "data": {
    "review_id": 1,
    "order_id": 1,
    "order_type": "booking",
    "score": 5,
    "content": "房间很干净，服务很好",
    "photos": ["http://example.com/photo1.jpg"],
    "created_at": "2024-01-18 10:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `400` - 订单已评价
- `400` - 请求参数错误

***

### 2. 获取房间评价列表

**接口说明**：获取房间评价列表

**请求方式**：`GET`

**请求路径**：`/rooms/:room_id/reviews`

**请求头**：

```
Authorization: Bearer <token>
```

**查询参数**：

```
?page=1&limit=10&score=5
```

**响应示例**：

```json
{
  "code": 200,
  "message": "获取成功",
  "data": {
    "total": 10,
    "page": 1,
    "limit": 10,
    "items": [
      {
        "review_id": 1,
        "order_id": 1,
        "score": 5,
        "content": "房间很干净，服务很好",
        "photos": ["http://example.com/photo1.jpg"],
        "created_at": "2024-01-18 10:00:00",
        "guest_name": "张三"
      },
      {
        "review_id": 2,
        "order_id": 2,
        "score": 4,
        "content": "房间不错，就是WiFi有点慢",
        "created_at": "2024-01-17 10:00:00",
        "guest_name": "李四"
      }
    ]
  }
}
```

**错误码**：

- `401` - Token无效或已过期

***

## 📱 用户管理接口

### 1. 获取用户信息

**接口说明**：获取当前用户信息

**请求方式**：`GET`

**请求路径**：`/users/profile`

**请求头**：

```
Authorization: Bearer <token>
```

**响应示例**：

```json
{
  "code": 200,
  "message": "获取成功",
  "data": {
    "id": 1,
    "username": "admin",
    "email": "admin@example.com",
    "role": "admin",
    "permissions": ["read", "write", "delete"],
    "created_at": "2024-01-01 00:00:00",
    "updated_at": "2024-01-18 00:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期

***

### 2. 更新用户信息

**接口说明**：更新当前用户信息

**请求方式**：`PUT`

**请求路径**：`/users/profile`

**请求头**：

```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：

```json
{
  "email": "newemail@example.com"
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "更新成功",
  "data": {
    "id": 1,
    "username": "admin",
    "email": "newemail@example.com",
    "role": "admin",
    "created_at": "2024-01-01 00:00:00",
    "updated_at": "2024-01-18 00:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `400` - 请求参数错误

***

### 3. 修改密码

**接口说明**：修改当前用户密码

**请求方式**：`PUT`

**请求路径**：`/users/password`

**请求头**：

```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：

```json
{
  "old_password": "password123",
  "new_password": "newpassword123"
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "密码修改成功",
  "data": null
}
```

**错误码**：

- `401` - Token无效或已过期
- `400` - 旧密码错误
- `400` - 新密码不符合要求

***

## 📡 设备管理接口

### 1. 获取设备列表

**接口说明**：获取所有设备列表

**请求方式**：`GET`

**请求路径**：`/devices`

**请求头**：

```
Authorization: Bearer <token>
```

**查询参数**：

```
?page=1&limit=10&type=main
```

**响应示例**：

```json
{
  "code": 200,
  "message": "获取成功",
  "data": {
    "total": 3,
    "page": 1,
    "limit": 10,
    "items": [
      {
        "id": 1,
        "device_id": "MAIN001",
        "device_type": "main",
        "device_name": "前台管理端",
        "device_status": "online",
        "firmware_version": "v1.0.0",
        "last_seen": "2024-01-18 10:00:00",
        "created_at": "2024-01-01 00:00:00",
        "updated_at": "2024-01-18 10:00:00"
      },
      {
        "id": 2,
        "device_id": "SUB1001",
        "device_type": "sub1",
        "device_name": "楼控1",
        "device_status": "online",
        "firmware_version": "v1.0.0",
        "last_seen": "2024-01-18 10:00:00",
        "created_at": "2024-01-01 00:00:00",
        "updated_at": "2024-01-18 10:00:00"
      },
      {
        "id": 3,
        "device_id": "SUB2001",
        "device_type": "sub2",
        "device_name": "客房端1",
        "device_status": "offline",
        "firmware_version": "v1.0.0",
        "last_seen": "2024-01-17 10:00:00",
        "created_at": "2024-01-01 00:00:00",
        "updated_at": "2024-01-17 10:00:00"
      }
    ]
  }
}
```

**错误码**：

- `401` - Token无效或已过期

***

### 2. 获取设备详情

**接口说明**：获取指定设备详情

**请求方式**：`GET`

**请求路径**：`/devices/:id`

**请求头**：

```
Authorization: Bearer <token>
```

**响应示例**：

```json
{
  "code": 200,
  "message": "获取成功",
  "data": {
    "id": 1,
    "device_id": "MAIN001",
    "device_type": "main",
    "device_name": "前台管理端",
    "device_key": "key_main_001",
    "device_status": "online",
    "firmware_version": "v1.0.0",
    "last_seen": "2024-01-18 10:00:00",
    "created_at": "2024-01-01 00:00:00",
    "updated_at": "2024-01-18 10:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `404` - 设备不存在

***

### 3. 控制设备

**接口说明**：向设备发送控制指令

**请求方式**：`POST`

**请求路径**：`/devices/:id/control`

**请求头**：

```
Content-Type: application/json
Authorization: Bearer <token>
```

**请求体**：

```json
{
  "command_type": "light_on",
  "command_value": "1"
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "指令下发成功",
  "data": {
    "id": 1,
    "device_id": "MAIN001",
    "command_type": "light_on",
    "command_value": "1",
    "command_status": "pending",
    "created_by": "admin",
    "created_at": "2024-01-18 10:00:00",
    "executed_at": null
  }
}
```

**错误码**：

- `401` - Token无效或已过期
- `404` - 设备不存在
- `400` - 请求参数错误

***

### 4. 注册设备

**接口说明**：设备注册到系统

**请求方式**：`POST`

**请求路径**：`/devices/register`

**请求头**：

```
Content-Type: application/json
```

**请求体**：

```json
{
  "device_id": "MAIN001",
  "device_type": "main",
  "device_name": "前台管理端",
  "device_key": "key_main_001",
  "firmware_version": "v1.0.0"
}
```

**响应示例**：

```json
{
  "code": 200,
  "message": "注册成功",
  "data": {
    "id": 1,
    "device_id": "MAIN001",
    "device_type": "main",
    "device_name": "前台管理端",
    "device_status": "offline",
    "firmware_version": "v1.0.0",
    "created_at": "2024-01-18 10:00:00",
    "updated_at": "2024-01-18 10:00:00"
  }
}
```

**错误码**：

- `400` - 设备ID已存在
- `400` - 请求参数错误

***

### 5. 删除设备

**接口说明**：删除指定设备

**请求方式**：`DELETE`

**请求路径**：`/devices/:id`

**请求头**：

```
Authorization: Bearer <token>
```

**响应示例**：

```json
{
  "code": 200,
  "message": "删除成功",
  "data": null
}
```

**错误码**：

- `401` - Token无效或已过期
- `404` - 设备不存在

***

## 📊 传感器数据接口

### 1. 获取传感器数据

**接口说明**：获取传感器数据

**请求方式**：`GET`

**请求路径**：`/sensors/data`

**请求头**：

```
Authorization: Bearer <token>
```

**查询参数**：

```
?device_id=SUB1001&sensor_type=temperature&start_time=2024-01-18%2000:00:00&end_time=2024-01-18%2023:59:59&page=1&limit=100
```

**响应示例**：

```json
{
  "code": 200,
  "message": "获取成功",
  "data": {
    "total": 10,
    "page": 1,
    "limit": 100,
    "items": [
      {
        "id": 1,
        "device_id": "SUB1001",
        "sensor_type": "temperature",
        "sensor_value": "25.5",
        "created_at": "2024-01-18 10:00:00"
      },
      {
        "id": 2,
        "device_id": "SUB1001",
        "sensor_type": "humidity",
        "sensor_value": "65",
        "created_at": "2024-01-18 10:00:00"
      }
    ]
  }
}
```

**错误码**：

- `401` - Token无效或已过期

***

### 2. 获取最新传感器数据

**接口说明**：获取最新传感器数据

**请求方式**：`GET`

**请求路径**：`/sensors/data/latest`

**请求头**：

```
Authorization: Bearer <token>
```

**查询参数**：

```
?device_id=SUB1001
```

**响应示例**：

```json
{
  "code": 200,
  "message": "获取成功",
  "data": {
    "device_id": "SUB1001",
    "data": [
      {
        "sensor_type": "temperature",
        "sensor_value": "25.5",
        "created_at": "2024-01-18 10:00:00"
      },
      {
        "sensor_type": "humidity",
        "sensor_value": "65",
        "created_at": "2024-01-18 10:00:00"
      }
    ]
  }
}
```

**错误码**：

- `401` - Token无效或已过期

***

### 3. 获取传感器历史数据

**接口说明**：获取传感器历史数据

**请求方式**：`GET`

**请求路径**：`/sensors/data/history`

**请求头**：

```
Authorization: Bearer <token>
```

**查询参数**：

```
?device_id=SUB1001&sensor_type=temperature&start_time=2024-01-18%2000:00:00&end_time=2024-01-18%2023:59:59
```

**响应示例**：

```json
{
  "code": 200,
  "message": "获取成功",
  "data": {
    "device_id": "SUB1001",
    "sensor_type": "temperature",
    "data": [
      {
        "sensor_value": "25.5",
        "created_at": "2024-01-18 10:00:00"
      },
      {
        "sensor_value": "26.0",
        "created_at": "2024-01-18 11:00:00"
      }
    ]
  }
}
```

**错误码**：

- `401` - Token无效或已过期

***

## 🛡️ 安防管理接口

### 1. 获取安防状态

**接口说明**：获取安防系统状态

**请求方式**：`GET`

**请求路径**：`/security/status`

**请求头**：

```
Authorization: Bearer <token>
```

**响应示例**：

```json
{
  "code": 200,
  "message": "获取成功",
  "data": {
    "armed": false,
    "last_arm_time": null,
    "last_disarm_time": "2024-01-18 10:00:00",
    "devices": [
      {
        "device_id": "SUB2001",
        "device_name": "客房端1",
        "status": "online"
      }
    ]
  }
}
```

**错误码**：

- `401` - Token无效或已过期

***

### 2. 启动布防

**接口说明**：启动安防布防

**请求方式**：`POST`

**请求路径**：`/security/arm`

**请求头**：

```
Authorization: Bearer <token>
```

**响应示例**：

```json
{
  "code": 200,
  "message": "布防成功",
  "data": {
    "armed": true,
    "arm_time": "2024-01-18 10:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期

***

### 3. 解除布防

**接口说明**：解除安防布防

**请求方式**：`POST`

**请求路径**：`/security/disarm`

**请求头**：

```
Authorization: Bearer <token>
```

**响应示例**：

```json
{
  "code": 200,
  "message": "解除布防成功",
  "data": {
    "armed": false,
    "disarm_time": "2024-01-18 10:00:00"
  }
}
```

**错误码**：

- `401` - Token无效或已过期

***

### 4. 获取安防事件

**接口说明**：获取安防事件列表

**请求方式**：`GET`

**请求路径**：`/security/events`

**请求头**：

```
Authorization: Bearer <token>
```

**查询参数**：

```
?page=1&limit=10&level=critical
```

**响应示例**：

```json
{
  "code": 200,
  "message": "获取成功",
  "data": {
    "total": 5,
    "page": 1,
    "limit": 10,
    "items": [
      {
        "id": 1,
        "device_id": "SUB2001",
        "event_type": "intrusion",
        "event_data": {"sensor": "motion", "location": "living room", "timestamp": "2024-01-18 10:00:00"},
        "level": "critical",
        "status": "unhandled",
        "created_at": "2024-01-18 10:00:00"
      }
    ]
  }
}
```

**错误码**：

- `401` - Token无效或已过期

***

## 📡 WebSocket API

### 1. 连接WebSocket

**接口说明**：建立WebSocket连接

**连接地址**：
```
ws://localhost:3000/api/v1/ws?token=<jwt_token>
```

**连接参数**：

| 参数名 | 类型 | 必填 | 说明 | 示例值 |
|--------|------|------|------|--------|
| token | string | 是 | JWT Token | `eyJhbGci...` |

**响应示例**（连接成功）：
```json
{
  "event": "connected",
  "data": {
    "connection_id": "conn_123456",
    "timestamp": "2026-04-04 15:30:00"
  }
}
```

***

### 2. 通话事件

**接口说明**：实时推送通话状态变化

**事件列表**：

| 事件名 | 说明 | 触发方 |
|--------|------|--------|
| `call_initiated` | 通话请求已发起 | 主叫方 |
| `call_ringing` | 通话振铃 | 被叫方 |
| `call_answered` | 通话已接听 | 被叫方 |
| `call_rejected` | 通话已拒接 | 被叫方 |
| `call_hungup` | 通话已挂断 | 任一方 |
| `call_ended` | 通话已结束 | 系统 |
| `call_busy` | 对方忙线 | 被叫方 |
| `call_missed` | 通话未接听 | 被叫方 |

**事件格式**：

```json
{
  "event": "call_initiated",
  "data": {
    "call_id": "CALL20260404001",
    "caller_type": "room",
    "caller_id": "301",
    "callee_type": "front_desk",
    "callee_id": "FD001",
    "status": "calling",
    "started_at": "2026-04-04 15:30:00"
  }
}
```

**事件参数说明**：

| 参数名 | 类型 | 说明 | 示例值 |
|--------|------|------|--------|
| event | string | 事件名称 | `call_initiated` |
| data.call_id | string | 通话ID | `CALL20260404001` |
| data.caller_type | string | 主叫方类型：`room` \| `front_desk` \| `ai` \| `app` | `room` |
| data.caller_id | string | 主叫方ID | `301` |
| data.callee_type | string | 被叫方类型：`room` \| `front_desk` \| `ai` \| `app` | `front_desk` |
| data.callee_id | string | 被叫方ID | `FD001` |
| data.status | string | 通话状态 | `calling` |
| data.started_at | string | 开始时间 | `2026-04-04 15:30:00` |

**示例场景**：

**场景1：客房发起通话**
```json
{
  "event": "call_initiated",
  "data": {
    "call_id": "CALL20260404001",
    "caller_type": "room",
    "caller_id": "301",
    "callee_type": "front_desk",
    "callee_id": "FD001",
    "status": "calling",
    "started_at": "2026-04-04 15:30:00"
  }
}
```

**场景2：前台发起通话**
```json
{
  "event": "call_initiated",
  "data": {
    "call_id": "CALL20260404002",
    "caller_type": "front_desk",
    "caller_id": "FD001",
    "callee_type": "room",
    "callee_id": "301",
    "status": "outgoing",
    "started_at": "2026-04-04 15:30:00"
  }
}
```

**场景3：AI管家发起通话**
```json
{
  "event": "call_initiated",
  "data": {
    "call_id": "CALL20260404003",
    "caller_type": "ai",
    "caller_id": "AI001",
    "callee_type": "room",
    "callee_id": "301",
    "status": "calling",
    "started_at": "2026-04-04 15:30:00"
  }
}
```

**场景4：手机App发起通话**
```json
{
  "event": "call_initiated",
  "data": {
    "call_id": "CALL20260404004",
    "caller_type": "app",
    "caller_id": "USER123",
    "callee_type": "front_desk",
    "callee_id": "FD001",
    "status": "calling",
    "started_at": "2026-04-04 15:30:00"
  }
}
```

**场景5：通话振铃**
```json
{
  "event": "call_ringing",
  "data": {
    "call_id": "CALL20260404001",
    "caller_type": "room",
    "caller_id": "301",
    "callee_type": "front_desk",
    "callee_id": "FD001",
    "status": "ringing",
    "ringing_at": "2026-04-04 15:30:01"
  }
}
```

**场景6：通话已接听**
```json
{
  "event": "call_answered",
  "data": {
    "call_id": "CALL20260404001",
    "caller_type": "room",
    "caller_id": "301",
    "callee_type": "front_desk",
    "callee_id": "FD001",
    "status": "connected",
    "answered_at": "2026-04-04 15:30:05"
  }
}
```

**场景7：通话已挂断**
```json
{
  "event": "call_hungup",
  "data": {
    "call_id": "CALL20260404001",
    "caller_type": "room",
    "caller_id": "301",
    "callee_type": "front_desk",
    "callee_id": "FD001",
    "status": "ended",
    "ended_at": "2026-04-04 15:35:00",
    "duration_sec": 300
  }
}
```

***

### 3. 心跳保持

**接口说明**：定期发送心跳保持连接

**发送格式**：
```json
{
  "event": "ping",
  "data": {
    "timestamp": "2026-04-04 15:30:00"
  }
}
```

**响应格式**：
```json
{
  "event": "pong",
  "data": {
    "timestamp": "2026-04-04 15:30:00"
  }
}
```

***

### 4. 错误处理

**接口说明**：WebSocket连接错误处理

**错误事件**：

| 错误码 | 说明 | 解决方案 |
|--------|------|----------|
| `auth_failed` | 认证失败 | 检查Token是否有效 |
| `connection_timeout` | 连接超时 | 重连WebSocket |
| `server_error` | 服务器错误 | 稍后重试 |
| `invalid_event` | 无效事件 | 检查事件格式 |

**错误示例**：
```json
{
  "event": "error",
  "data": {
    "code": "auth_failed",
    "message": "Token无效或已过期",
    "timestamp": "2026-04-04 15:30:00"
  }
}
```

***

## 📡 MQTT API

### 1. 设备连接

**接口说明**：设备通过MQTT连接到服务器

**连接地址**：
```
mqtt://localhost:1883
```

**连接参数**：

| 参数名 | 类型 | 必填 | 说明 | 示例值 |
|--------|------|------|------|--------|
| client_id | string | 是 | 设备ID | `room_301` |
| username | string | 是 | 设备类型 | `room` |
| password | string | 是 | 设备密钥 | `device_secret` |

**连接主题**：
```
hotel/device/{device_id}/status
```

***

### 2. 通话MQTT主题

**接口说明**：语音通话相关的MQTT主题

**主题列表**：

| 主题 | 方向 | 说明 |
|------|------|------|
| `hotel/room/{room_id}/call/incoming` | 推送 | 客房接收呼入通话 |
| `hotel/room/{room_id}/call/outgoing` | 推送 | 客房接收呼出通话 |
| `hotel/room/{room_id}/call/status` | 双向 | 客房发送通话状态 |
| `hotel/front_desk/call/incoming` | 推送 | 前台接收呼入通话 |
| `hotel/front_desk/call/status` | 双向 | 前台发送通话状态 |
| `hotel/ai/call/incoming` | 推送 | AI管家接收呼入通话 |
| `hotel/ai/call/status` | 双向 | AI管家发送通话状态 |
| `hotel/app/call/incoming` | 推送 | 手机App接收呼入通话 |
| `hotel/app/call/status` | 双向 | 手机App发送通话状态 |

**主题示例**：

**客房接收呼入通话**：
```json
{
  "topic": "hotel/room/301/call/incoming",
  "payload": {
    "call_id": "CALL20260404001",
    "caller_type": "front_desk",
    "caller_id": "FD001",
    "callee_type": "room",
    "callee_id": "301",
    "status": "incoming",
    "timestamp": "2026-04-04 15:30:00"
  }
}
```

**客房发送通话状态**：
```json
{
  "topic": "hotel/room/301/call/status",
  "payload": {
    "call_id": "CALL20260404001",
    "status": "connected",
    "answered_at": "2026-04-04 15:30:05"
  }
}
```

**AI管家接收呼入通话**：
```json
{
  "topic": "hotel/ai/call/incoming",
  "payload": {
    "call_id": "CALL20260404003",
    "caller_type": "room",
    "caller_id": "301",
    "callee_type": "ai",
    "callee_id": "AI001",
    "status": "incoming",
    "timestamp": "2026-04-04 15:30:00"
  }
}
```

**手机App接收呼入通话**：
```json
{
  "topic": "hotel/app/call/incoming",
  "payload": {
    "call_id": "CALL20260404004",
    "caller_type": "room",
    "caller_id": "301",
    "callee_type": "app",
    "callee_id": "USER123",
    "status": "incoming",
    "timestamp": "2026-04-04 15:30:00"
  }
}
```

***

## 🔐 错误码

### 通用错误码

| 错误码 | 说明 |
|--------|------|
| 200 | 请求成功 |
| 400 | 请求参数错误 |
| 401 | 未授权 |
| 403 | 禁止访问 |
| 404 | 资源不存在 |
| 405 | 方法不允许 |
| 409 | 冲突 |
| 429 | 请求过多 |
| 500 | 服务器内部错误 |
| 502 | 网关错误 |
| 503 | 服务不可用 |

***

## 📝 版本历史

### v2.2.0 - 2026年4月

- 新增常用入住人管理接口（CRUD）
- 新增住客管理接口（入住登记、退房管理）
- 新增员工信息管理接口
- 新增设备注册、审核、指令下发接口
- 新增通话管理接口（发起、接听、挂断、查询）
- 新增WebSocket实时通信接口
- 新增MQTT设备通信接口
- 优化系统架构设计

### v2.0.0 - 2026年4月

- 重构为智慧酒店三层架构
- 新增预订系统、支付接口、会员机制、优惠券机制
- 新增酒店房间管理、送物订单、报修工单接口
- 优化系统架构设计
- 新增语音通话接口（支持双向通话）
- 新增WebSocket实时通信接口
- 新增MQTT设备通信接口

***

**文档结束**

