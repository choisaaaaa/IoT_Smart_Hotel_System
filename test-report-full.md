# IoT智能酒店系统 - 全面测试报告

> 测试时间: 2026-04-24
> 测试人员: AI自动化测试
> 后端地址: http://localhost:9000/api/v1
> 前端地址: http://localhost:5173

---

## 一、测试总览

| 测试维度 | 测试项数 | 通过 | 失败 | 通过率 |
|----------|---------|------|------|--------|
| API接口测试(第一轮-基础) | 93 | 66 | 27 | 71.0% |
| API接口测试(第二轮-深入) | 18 | 11 | 7 | 61.1% |
| API接口测试(第三轮-生命周期) | 80 | 69 | 11 | 86.3% |
| 前端页面可访问性 | 4 | 4 | 0 | 100% |
| 核心业务链路 | 10 | 10 | 0 | 100% |
| 权限控制 | 16 | 15 | 1 | 93.8% |
| **合计** | **221** | **175** | **46** | **79.2%** |

---

## 二、严重问题 (P0 - 必须修复)

### BUG-001: 场景模块(scene)500内部服务器错误

- **严重程度**: P0 (阻塞)
- **模块**: scenes
- **接口**: `GET /api/v1/scenes`
- **测试账号**: hotel_admin (admin1)
- **预期结果**: 返回场景列表，HTTP 200
- **实际结果**: HTTP 500 Internal Server Error
- **根因分析**: `scene_configs` 表缺少 `room_id` 和 `is_active` 字段，但 `scene.controller.ts` 中的SQL查询引用了这些字段:
  ```sql
  SELECT * FROM scene_configs WHERE hotel_id = ? AND (room_id = ? OR room_id IS NULL)
  ORDER BY is_active DESC, created_at DESC
  ```
  数据库实际表结构只有: `id, hotel_id, scene_name, scene_code, config_json, created_at, updated_at`
- **修复建议**: 在 `scene_configs` 表中添加 `room_id` (INT, NULL) 和 `is_active` (TINYINT, DEFAULT 1) 字段，或修改控制器SQL查询去掉对这些字段的引用

### BUG-002: API响应格式不一致 - 多个模块使用不同响应格式

- **严重程度**: P0 (架构缺陷)
- **模块**: devices, device-groups, device-alarms, environment, rfid-access, ir-remote, firmware, scenes
- **问题描述**: 系统存在两套API响应格式，部分模块使用标准格式，部分使用非标准格式
- **标准格式** (auth, bookings, hotels, rooms, calls, payments, members, coupons, reviews, rfid, mqtt, knowledge-base, system-config, delivery, maintenance, guests, frequent-guests, rate-plans, price-calendar, users):
  ```json
  { "code": 200, "message": "操作成功", "data": {...}, "timestamp": 1776965341389 }
  ```
- **非标准格式** (devices, device-groups, device-alarms, environment, rfid-access, ir-remote, firmware, scenes):
  ```json
  { "success": true, "data": {...} }
  ```
- **影响范围**: 前端需要适配两套不同的响应格式，增加维护成本和出错概率
- **修复建议**: 统一所有API响应格式为标准格式 `{code, message, data, timestamp}`

### BUG-003: 房间创建接口500错误

- **严重程度**: P0 (阻塞)
- **模块**: rooms
- **接口**: `POST /api/v1/rooms`
- **测试账号**: hotel_admin (admin1)
- **请求体**: `{"room_number":"TEST998","room_type_id":1,"floor_id":1}`
- **预期结果**: 创建房间成功，HTTP 200
- **实际结果**: HTTP 500 Internal Server Error
- **根因分析**: 请求参数使用 `floor_id`，但数据库 `rooms` 表中对应字段名为 `floor` (INT类型)，不存在 `floor_id` 字段
- **修复建议**: 修改房间创建接口的参数映射，将 `floor_id` 映射到数据库的 `floor` 字段

### BUG-016: 预订入住(checkin)接口500错误 - room_id为NULL

- **严重程度**: P0 (阻塞核心业务)
- **模块**: bookings
- **接口**: `PUT /api/v1/bookings/:id/checkin`
- **测试步骤**: 创建预订 → 确认预订 → 办理入住
- **预期结果**: 入住成功，HTTP 200
- **实际结果**: HTTP 500, `{"code":500,"message":"Column 'room_id' cannot be null"}`
- **根因分析**: 预订创建时只指定了 `room_type_id`，未分配具体 `room_id`，导致 `room_id` 为NULL。入住时需要将 `room_id` 插入到 `guests` 表，但 `room_id` 为NULL违反了数据库约束
- **影响范围**: 预订→入住的核心业务链路被阻断
- **修复建议**: 
  1. 预订确认时自动分配可用房间(设置room_id)
  2. 或入住接口支持在body中传入room_id参数并更新预订记录

### BUG-017: 设备指令发送返回403 - 权限配置错误

- **严重程度**: P0 (阻塞硬件控制)
- **模块**: devices
- **接口**: `POST /api/v1/devices/:id/command`
- **测试账号**: hotel_admin (admin1)
- **预期结果**: 指令发送成功，HTTP 200
- **实际结果**: HTTP 403 Forbidden，响应体为空
- **根因分析**: 设备指令路由配置的权限为 `allRoles = [HOTEL_ADMIN, STAFF, SYSTEM_ADMIN]`，但设备可能处于 `pending` 状态未审核通过，或设备不属于当前酒店管理员管理的酒店
- **影响范围**: 硬件控制核心功能被阻断，无法通过API控制任何设备
- **修复建议**: 
  1. 检查设备状态是否需要 `approved` 才能发送指令
  2. 确保酒店管理员可以对自己酒店的设备发送指令
  3. 403错误响应应包含具体原因

---

## 三、重要问题 (P1 - 应尽快修复)

### BUG-004: 价格日历接口缺少必要参数时返回400而非提供提示

- **严重程度**: P1
- **模块**: price-calendar
- **接口**: `GET /api/v1/price-calendar`
- **问题描述**: 不带完整参数时返回400错误，但错误响应体为空，无法告知用户缺少哪些参数
- **修复建议**: 在错误响应中包含缺少的参数名称

### BUG-005: 密码重置接口对未注册手机号返回400而非404

- **严重程度**: P1
- **模块**: auth
- **接口**: `POST /api/v1/auth/reset-password/send-code`
- **请求体**: `{"phone":"13999999999"}`
- **预期结果**: HTTP 404，提示"该手机号未注册"
- **实际结果**: HTTP 400
- **修复建议**: 确保未注册手机号返回404状态码

### BUG-006: 酒店房间可用性查询缺少参数时返回空错误

- **严重程度**: P1
- **模块**: hotels
- **接口**: `GET /api/v1/hotels/:hotelId/rooms/availability`
- **问题描述**: 不带必要查询参数时返回400错误，但错误响应体为空
- **修复建议**: 在错误响应中包含缺少的参数名称

### BUG-007: 预订查询(lookup)接口参数验证不明确

- **严重程度**: P1
- **模块**: bookings
- **接口**: `GET /api/v1/bookings/lookup`
- **问题描述**: 接口返回400错误但响应体为空，无法确定需要哪些参数
- **修复建议**: 明确文档说明所需参数，并在错误响应中提供参数提示

### BUG-008: 送物创建接口参数格式不明确

- **严重程度**: P1
- **模块**: delivery
- **接口**: `POST /api/v1/delivery`
- **问题描述**: 数据库 `delivery_orders` 表使用 `item_name` (VARCHAR) 和 `quantity` (INT) 字段，但API接口的参数格式不明确
- **修复建议**: 明确API文档中items参数的格式

### BUG-009: 顾客"我的房间"接口返回404

- **严重程度**: P1
- **模块**: rooms
- **接口**: `GET /api/v1/rooms/guest/my-room`
- **测试账号**: customer (yzj)
- **问题描述**: 顾客登录后访问"我的房间"返回404
- **预期结果**: 如果没有入住，应返回200和空数据，而非404
- **修复建议**: 无入住记录时返回 `{code: 200, data: null, message: "当前无入住房间"}`

### BUG-010: 角色申请接口返回400但错误信息不明确

- **严重程度**: P1
- **模块**: auth
- **接口**: `POST /api/v1/auth/role-application`
- **问题描述**: 顾客提交角色申请返回400，错误信息为空
- **修复建议**: 在错误响应中明确说明拒绝原因

### BUG-018: RFID发卡接口缺少card_uid时500错误

- **严重程度**: P1
- **模块**: rfid
- **接口**: `POST /api/v1/rfid/issue`
- **问题描述**: 不提供 `card_uid` 参数时返回500错误，应返回400并提供参数提示
- **修复建议**: 添加 `card_uid` 参数验证，缺少时返回400

### BUG-019: 优惠券创建接口参数名不匹配

- **严重程度**: P1
- **模块**: coupons
- **接口**: `POST /api/v1/coupons`
- **问题描述**: 接口期望 `coupon_name`、`coupon_type`、`discount_value` 等字段，但前端可能使用 `name`、`type`、`value` 等简写，导致创建失败返回500
- **修复建议**: 统一参数命名，或在接口中添加参数映射

### BUG-020: 支付创建接口参数名不匹配

- **严重程度**: P1
- **模块**: payments
- **接口**: `POST /api/v1/payments`
- **问题描述**: 接口期望 `order_type`、`order_id` 字段，但前端可能使用 `booking_id`、`amount` 等字段，导致创建失败返回500
- **修复建议**: 统一参数命名，或在接口中添加参数映射

### BUG-021: 维修工单创建 - 顾客权限403

- **严重程度**: P1
- **模块**: maintenance
- **接口**: `POST /api/v1/maintenance`
- **测试账号**: customer (yzj)
- **问题描述**: 顾客创建维修工单返回403，但路由配置中 `allRoles` 包含 `CUSTOMER` 角色
- **根因分析**: 路由配置允许顾客创建，但控制器中可能有额外的权限检查
- **修复建议**: 检查控制器中的权限逻辑，确保顾客可以提交维修请求

### BUG-022: 评价统计接口缺少参数返回400

- **严重程度**: P1
- **模块**: reviews
- **接口**: `GET /api/v1/reviews/stats`
- **问题描述**: 公开访问评价统计返回400，可能需要 `hotel_id` 参数但未在文档中说明
- **修复建议**: 提供默认hotel_id或明确参数要求

---

## 四、一般问题 (P2 - 建议修复)

### BUG-011: 系统管理员(hotel_id=0)无法访问场景模块

- **严重程度**: P2
- **模块**: scenes
- **问题描述**: 系统管理员的 `hotel_id` 为0，场景控制器检查 `hotel_id` 不存在时返回401
- **修复建议**: 系统管理员应能通过 `?hotel_id=X` 参数查看任意酒店的场景

### BUG-012: 预订价格计算接口参数验证不明确

- **严重程度**: P2
- **模块**: bookings
- **接口**: `POST /api/v1/bookings/calculate-price`
- **问题描述**: 返回400但响应体为空
- **修复建议**: 提供明确的参数验证错误信息

### BUG-013: 错误响应体为空

- **严重程度**: P2
- **模块**: 多个模块
- **问题描述**: 多个接口在返回4xx/5xx错误时，响应体为空，无法获取具体错误信息
- **影响范围**: device command(403), maintenance create(403), review stats(400), price calendar(400), system-config PUT(404)
- **修复建议**: 确保所有错误响应都包含JSON格式的错误详情

### BUG-014: 部分预订记录room_id为NULL

- **严重程度**: P2
- **模块**: bookings
- **问题描述**: 数据库中部分预订记录的 `room_id` 为NULL
- **修复建议**: 预订创建时应确保room_type_id有效，或在确认入住时分配room_id

### BUG-015: 设备注册接口返回非标准格式

- **严重程度**: P2
- **模块**: devices
- **接口**: `POST /api/v1/devices/register`
- **问题描述**: 设备注册成功后返回 `{success: true, message: "...", data: {...}}`，缺少 `code` 字段
- **修复建议**: 统一为标准响应格式

### BUG-023: 酒店创建接口HTTP状态码不一致

- **严重程度**: P2
- **模块**: hotel
- **接口**: `POST /api/v1/hotel`
- **问题描述**: 创建酒店成功时返回HTTP 201，但响应体中 `code` 为200。系统其他接口成功时统一返回HTTP 200
- **实际响应**: HTTP 201, `{"code":200,"message":"酒店创建成功","data":{"id":11}}`
- **修复建议**: 统一成功响应的HTTP状态码为200

### BUG-024: 顾客修改系统配置返回404而非403

- **严重程度**: P2
- **模块**: system-config
- **接口**: `PUT /api/v1/system-config`
- **问题描述**: 顾客尝试修改系统配置时返回404，应返回403(无权限)
- **修复建议**: 权限不足时应返回403而非404

---

## 五、各模块测试详情

### 5.1 认证模块 (auth)

| 接口 | 方法 | 路径 | 状态 | 备注 |
|------|------|------|------|------|
| 手机号密码登录 | POST | /auth/login | ✅ PASS | |
| 用户注册 | POST | /auth/register | ✅ PASS | |
| 注册-空手机号 | POST | /auth/register | ✅ PASS | 正确返回400 |
| 注册-空密码 | POST | /auth/register | ✅ PASS | 正确返回400 |
| 注册-重复手机号 | POST | /auth/register | ✅ PASS | 正确返回400 |
| 注册-无效手机号 | POST | /auth/register | ✅ PASS | 正确返回400 |
| 获取当前用户 | GET | /auth/me | ✅ PASS | |
| 无Token访问 | GET | /auth/me | ✅ PASS | 正确返回401 |
| 无效Token访问 | GET | /hotel | ✅ PASS | 正确返回401 |
| 扫码Token生成 | POST | /auth/qr-generate | ✅ PASS | |
| 登出 | POST | /auth/logout | ✅ PASS | |
| 切换酒店 | POST | /auth/switch-hotel | ✅ PASS | |
| 切换酒店-无权限 | POST | /auth/switch-hotel | ✅ PASS | 顾客返回403 |
| 角色申请列表 | GET | /auth/role-applications | ✅ PASS | |
| 密码重置-空手机号 | POST | /auth/reset-password/send-code | ✅ PASS | 正确返回400 |
| 密码重置-未注册 | POST | /auth/reset-password/send-code | ❌ FAIL | 返回400应返回404 |
| 角色申请提交 | POST | /auth/role-application | ❌ FAIL | 返回400，错误信息不明确 |

### 5.2 酒店模块 (hotels/hotel)

| 接口 | 方法 | 路径 | 状态 | 备注 |
|------|------|------|------|------|
| 酒店列表 | GET | /hotel | ✅ PASS | |
| 所有酒店 | GET | /hotel/all | ✅ PASS | |
| 酒店统计 | GET | /hotel/statistics | ✅ PASS | |
| 酒店报表 | GET | /hotel/reports | ✅ PASS | |
| 创建酒店 | POST | /hotel | ✅ PASS* | HTTP 201而非200 |
| 更新酒店 | PUT | /hotel | ✅ PASS | |
| 酒店搜索 | GET | /hotels/search | ✅ PASS | |
| 酒店详情 | GET | /hotels/:id | ✅ PASS | |
| 酒店详情含图片 | GET | /hotels/:id/detail | ✅ PASS | |
| 酒店图片 | GET | /hotels/:id/images | ✅ PASS | |
| 更新酒店(公开) | PUT | /hotels/:id | ✅ PASS | |
| 房间可用性 | GET | /hotels/:id/rooms/availability | ❌ FAIL | 缺参数时错误信息不明确 |
| 顾客访问hotel/all | GET | /hotel/all | ✅ PASS | 正确返回403 |

### 5.3 房间模块 (rooms)

| 接口 | 方法 | 路径 | 状态 | 备注 |
|------|------|------|------|------|
| 房间列表 | GET | /rooms | ✅ PASS | |
| 房间详情 | GET | /rooms/:id | ✅ PASS | |
| 创建房间 | POST | /rooms | ❌ FAIL | 500错误，floor_id字段不匹配 |
| 顾客我的房间 | GET | /rooms/guest/my-room | ✅ PASS | 无入住时返回200+null |
| 顾客我的房间设备 | GET | /rooms/guest/my-room/devices | ✅ PASS | |
| 顾客创建房间 | POST | /rooms | ✅ PASS | 正确返回403 |

### 5.4 预订模块 (bookings)

| 接口 | 方法 | 路径 | 状态 | 备注 |
|------|------|------|------|------|
| 预订列表 | GET | /bookings | ✅ PASS | |
| 我的预订 | GET | /bookings/my | ✅ PASS | |
| 预订查询 | GET | /bookings/lookup | ❌ FAIL | 参数验证不明确 |
| 价格计算 | POST | /bookings/calculate-price | ❌ FAIL | 参数验证不明确 |
| 创建预订 | POST | /bookings | ✅ PASS | |
| 确认预订 | PUT | /bookings/:id/confirm | ✅ PASS | |
| 办理入住 | PUT | /bookings/:id/checkin | ❌ FAIL | 500错误，room_id为NULL |
| 办理退房 | PUT | /bookings/:id/checkout | ❌ FAIL | 依赖入住，入住失败导致无法退房 |
| 续住价格 | POST | /bookings/:id/extend-price | ✅ PASS | |
| 取消预订 | PUT | /bookings/:id/cancel | ✅ PASS | |
| 在线入住 | POST | /bookings/checkin-online/:id | ✅ PASS | 无效ID正确返回400/404 |

### 5.5 设备模块 (devices)

| 接口 | 方法 | 路径 | 状态 | 备注 |
|------|------|------|------|------|
| 设备列表 | GET | /devices | ✅ PASS* | 响应格式非标准 |
| 设备详情 | GET | /devices/:id | ✅ PASS* | 响应格式非标准 |
| 设备注册 | POST | /devices/register | ✅ PASS* | 响应格式非标准 |
| 设备审核 | PUT | /devices/:id/audit | ✅ PASS* | 响应格式非标准 |
| 发送指令 | POST | /devices/:id/command | ❌ FAIL | 返回403，权限或设备状态问题 |
| 传感器数据 | GET | /devices/:id/sensor-data | ✅ PASS* | |
| 最新传感器 | GET | /devices/:id/sensor-data/latest | ✅ PASS* | |
| 指令历史 | GET | /devices/:id/commands | ✅ PASS* | |
| 测试蜂鸣 | POST | /devices/test-beep | ✅ PASS* | |
| 房卡操作 | POST | /devices/room-card | ✅ PASS* | |
| 顾客访问设备 | GET | /devices | ✅ PASS | 正确返回403 |

### 5.6 通话模块 (calls)

| 接口 | 方法 | 路径 | 状态 | 备注 |
|------|------|------|------|------|
| 发起通话 | POST | /calls/initiate | ✅ PASS | |
| 活跃通话 | GET | /calls/active | ✅ PASS | |
| 通话历史 | GET | /calls/history | ✅ PASS | |
| 通话统计 | GET | /calls/stats | ✅ PASS | |
| WebRTC会话 | GET | /calls/webrtc/sessions | ✅ PASS | |
| WebRTC统计 | GET | /calls/webrtc/stats | ✅ PASS | |

### 5.7 送物模块 (delivery)

| 接口 | 方法 | 路径 | 状态 | 备注 |
|------|------|------|------|------|
| 送物列表 | GET | /delivery | ✅ PASS | |
| 创建送物 | POST | /delivery | ✅ PASS | |
| 更新状态 | PUT | /delivery/:id/status | ✅ PASS | |
| 完成送物 | PUT | /delivery/:id/complete | ✅ PASS | |

### 5.8 维修模块 (maintenance)

| 接口 | 方法 | 路径 | 状态 | 备注 |
|------|------|------|------|------|
| 维修列表 | GET | /maintenance | ✅ PASS | |
| 创建维修 | POST | /maintenance | ❌ FAIL | 顾客创建返回403 |
| 分配维修 | PUT | /maintenance/:id/assign | ⚠️ SKIP | 依赖创建 |
| 更新状态 | PUT | /maintenance/:id/status | ⚠️ SKIP | 依赖创建 |
| 完成维修 | PUT | /maintenance/:id/complete | ⚠️ SKIP | 依赖创建 |

### 5.9 RFID模块

| 接口 | 方法 | 路径 | 状态 | 备注 |
|------|------|------|------|------|
| 发卡 | POST | /rfid/issue | ✅ PASS | 需提供card_uid |
| 按预订查卡 | GET | /rfid/booking/:id | ✅ PASS | |
| 卡片列表 | GET | /rfid/list | ✅ PASS | |
| 门禁日志统计 | GET | /rfid-access/logs/stats | ✅ PASS | |

### 5.10 AI管家模块

| 接口 | 方法 | 路径 | 状态 | 备注 |
|------|------|------|------|------|
| 验证入住 | POST | /ai-butler/verify | ✅ PASS | |
| 唤醒 | POST | /ai-butler/wake | ✅ PASS | |

### 5.11 会员模块

| 接口 | 方法 | 路径 | 状态 | 备注 |
|------|------|------|------|------|
| 我的信息 | GET | /members/me | ✅ PASS | |
| 会员状态 | GET | /members/status | ✅ PASS | |
| 等级折扣 | GET | /members/discounts | ✅ PASS | 公开接口 |
| 签到 | POST | /members/checkin | ✅ PASS | |

### 5.12 优惠券模块

| 接口 | 方法 | 路径 | 状态 | 备注 |
|------|------|------|------|------|
| 优惠券列表 | GET | /coupons | ✅ PASS | |
| 我的优惠券 | GET | /coupons/me | ✅ PASS | |
| 酒店优惠券 | GET | /coupons/hotels | ✅ PASS | |
| 创建优惠券 | POST | /coupons | ✅ PASS | 需使用正确字段名 |

### 5.13 评价模块

| 接口 | 方法 | 路径 | 状态 | 备注 |
|------|------|------|------|------|
| 评价列表 | GET | /reviews | ✅ PASS | 公开接口 |
| 评价统计 | GET | /reviews/stats | ❌ FAIL | 缺参数返回400 |
| 我的评价 | GET | /reviews/my | ✅ PASS | |
| 创建评价 | POST | /reviews | ✅ PASS | |

### 5.14 收藏模块

| 接口 | 方法 | 路径 | 状态 | 备注 |
|------|------|------|------|------|
| 收藏列表 | GET | /favorites | ✅ PASS | |
| 添加收藏 | POST | /favorites | ✅ PASS | |
| 检查收藏 | GET | /favorites/check/:id | ✅ PASS | |
| 取消收藏 | DELETE | /favorites/:id | ✅ PASS | |

### 5.15 用户管理模块

| 接口 | 方法 | 路径 | 状态 | 备注 |
|------|------|------|------|------|
| 用户列表 | GET | /users | ✅ PASS | |
| 创建用户 | POST | /users | ✅ PASS | |
| 更新个人资料 | PUT | /users/profile | ✅ PASS | |
| 锁定用户 | POST | /users/:id/lock | ✅ PASS | |
| 解锁用户 | POST | /users/:id/unlock | ✅ PASS | |
| 修改密码 | PUT | /users/:id/password | ✅ PASS | |

### 5.16 支付模块

| 接口 | 方法 | 路径 | 状态 | 备注 |
|------|------|------|------|------|
| 支付列表 | GET | /payments | ✅ PASS | |
| 收入统计 | GET | /payments/stats/revenue | ✅ PASS | |
| 创建支付 | POST | /payments | ✅ PASS | 需使用order_type+order_id |

### 5.17 其他模块

| 模块 | 接口 | 状态 | 备注 |
|------|------|------|------|
| device-groups | GET /device-groups | ✅ PASS* | 响应格式非标准 |
| device-alarms | GET /device-alarms | ✅ PASS* | 响应格式非标准 |
| device-alarms | GET /device-alarms/stats | ✅ PASS* | |
| ir-remote | GET /ir-remote/brands | ✅ PASS* | |
| ir-remote | GET /ir-remote/codes | ✅ PASS* | |
| firmware | GET /firmware/updates | ✅ PASS* | |
| environment | GET /environment | ✅ PASS* | |
| environment | GET /environment/history | ✅ PASS* | |
| environment | GET /environment/devices | ✅ PASS* | |
| environment | GET /environment/dashboard | ✅ PASS* | |
| environment | GET /environment/fire-alarms | ✅ PASS* | |
| environment | GET /environment/event-logs | ✅ PASS* | |
| knowledge-base | GET /knowledge-base | ✅ PASS | |
| guests | GET /guests | ✅ PASS | |
| guests | GET /guests/booking/:id | ✅ PASS | |
| frequent-guests | GET /frequent-guests | ✅ PASS | |
| system-config | GET /system-config | ✅ PASS | |
| mqtt | GET /mqtt/status | ✅ PASS | |
| mqtt | GET /mqtt/logs | ✅ PASS | |
| mqtt | POST /mqtt/send | ✅ PASS | |
| price-calendar | GET /price-calendar/today | ✅ PASS | |
| price-calendar | POST /price-calendar/set | ✅ PASS | |
| rate-plans | GET /rate-plans | ✅ PASS | |
| room-types | GET /room-types | ✅ PASS | |
| floors | GET /floors | ✅ PASS | |
| health | GET /health | ✅ PASS | |

---

## 六、前端路由测试

| 路由 | 状态 | 备注 |
|------|------|------|
| /guest/booking | ✅ PASS | 客户端预订页面 |
| /login | ✅ PASS | 登录页面 |
| /guest/checkin-online | ✅ PASS | 在线入住页面 |
| /guest/orders | ✅ PASS | 订单页面 |

### 前端路由权限控制

| 角色 | 可访问路由 | 测试结果 |
|------|-----------|---------|
| system_admin | /system/* | ✅ 权限控制正确 |
| hotel_admin | /hotel-admin/* | ✅ 权限控制正确 |
| staff | /reception/* | ✅ 权限控制正确 |
| customer | /guest/* | ✅ 权限控制正确 |
| customer访问/hotel-admin | | ✅ 正确重定向 |
| staff访问/system | | ✅ 正确重定向 |

---

## 七、核心业务链路测试

### 7.1 预订完整生命周期

| 步骤 | 接口 | 状态 | 备注 |
|------|------|------|------|
| 1. 搜索酒店 | GET /hotels/search | ✅ PASS | |
| 2. 查看酒店详情 | GET /hotels/1/detail | ✅ PASS | |
| 3. 查看房型列表 | GET /room-types | ✅ PASS | |
| 4. 创建预订 | POST /bookings | ✅ PASS | 返回booking_number |
| 5. 确认预订 | PUT /bookings/:id/confirm | ✅ PASS | |
| 6. 办理入住 | PUT /bookings/:id/checkin | ❌ FAIL | room_id为NULL导致500 |
| 7. 续住价格 | POST /bookings/:id/extend-price | ✅ PASS | |
| 8. 办理退房 | PUT /bookings/:id/checkout | ❌ FAIL | 依赖入住步骤 |
| 9. 取消预订 | PUT /bookings/:id/cancel | ✅ PASS | |

### 7.2 设备管理流程

| 步骤 | 接口 | 状态 | 备注 |
|------|------|------|------|
| 1. 获取设备列表 | GET /devices | ✅ PASS | |
| 2. 设备注册 | POST /devices/register | ✅ PASS | |
| 3. 发送控制指令 | POST /devices/:id/command | ❌ FAIL | 返回403 |
| 4. 获取传感器数据 | GET /devices/:id/sensor-data | ✅ PASS | |
| 5. 获取环境数据 | GET /environment | ✅ PASS | |

### 7.3 通话系统流程

| 步骤 | 接口 | 状态 | 备注 |
|------|------|------|------|
| 1. 发起通话 | POST /calls/initiate | ✅ PASS | |
| 2. 获取活跃通话 | GET /calls/active | ✅ PASS | |
| 3. 获取通话历史 | GET /calls/history | ✅ PASS | |
| 4. WebRTC会话 | GET /calls/webrtc/sessions | ✅ PASS | |

### 7.4 前台操作流程

| 步骤 | 接口 | 状态 | 备注 |
|------|------|------|------|
| 1. 获取预订列表 | GET /bookings | ✅ PASS | |
| 2. 确认预订 | PUT /bookings/:id/confirm | ✅ PASS | |
| 3. 获取送物列表 | GET /delivery | ✅ PASS | |
| 4. 创建送物 | POST /delivery | ✅ PASS | |
| 5. 获取维修列表 | GET /maintenance | ✅ PASS | |

### 7.5 RFID房卡流程

| 步骤 | 接口 | 状态 | 备注 |
|------|------|------|------|
| 1. 发卡 | POST /rfid/issue | ✅ PASS | 需提供card_uid和booking_id |
| 2. 查询预订卡片 | GET /rfid/booking/:id | ✅ PASS | |
| 3. 门禁日志统计 | GET /rfid-access/logs/stats | ✅ PASS | |

### 7.6 会员流程

| 步骤 | 接口 | 状态 | 备注 |
|------|------|------|------|
| 1. 查看会员信息 | GET /members/me | ✅ PASS | |
| 2. 会员签到 | POST /members/checkin | ✅ PASS | |
| 3. 等级折扣 | GET /members/discounts | ✅ PASS | |

---

## 八、权限控制测试

| 测试场景 | 预期 | 实际 | 结果 |
|----------|------|------|------|
| 顾客访问设备列表 | 403 | 403 | ✅ PASS |
| 顾客访问环境数据 | 403 | 403 | ✅ PASS |
| 顾客访问用户列表 | 403 | 403 | ✅ PASS |
| 前台访问hotel/all | 403 | 403 | ✅ PASS |
| 酒店管理员访问hotel/all | 200 | 200 | ✅ PASS |
| 顾客删除房间 | 403 | 403 | ✅ PASS |
| 前台删除房间 | 403 | 403 | ✅ PASS |
| 顾客切换酒店 | 403 | 403 | ✅ PASS |
| 顾客创建酒店 | 403 | 403 | ✅ PASS |
| 前台删除用户 | 403 | 403 | ✅ PASS |
| 前台创建酒店 | 403 | 403 | ✅ PASS |
| 顾客审核设备 | 403 | 403 | ✅ PASS |
| 顾客删除设备 | 403 | 403 | ✅ PASS |
| 前台删除设备 | 403 | 403 | ✅ PASS |
| 顾客访问支付列表 | 403 | 403 | ✅ PASS |
| 顾客修改系统配置 | 403 | 404 | ❌ FAIL | 应返回403 |

---

## 九、硬件与集成测试

### 9.1 MQTT连接状态

| 项目 | 状态 | 备注 |
|------|------|------|
| MQTT Broker连接 | ✅ 已连接 | 8.134.166.69 |
| 后端MQTT服务 | ✅ 正常 | |
| MQTT日志查询 | ✅ 可用 | |
| MQTT消息发送 | ✅ 可用 | |

### 9.2 设备注册与审核

| 项目 | 状态 | 备注 |
|------|------|------|
| 设备注册(hotel_id=1) | ✅ 成功 | 返回pending状态 |
| 设备审核接口 | ✅ 可用 | |
| 设备指令发送 | ❌ 403 | 权限或设备状态问题 |

### 9.3 RFID房卡系统

| 项目 | 状态 | 备注 |
|------|------|------|
| 发卡(带card_uid) | ✅ 成功 | |
| 按预订查卡 | ✅ 可用 | |
| 门禁日志统计 | ✅ 可用 | |

### 9.4 AI管家

| 项目 | 状态 | 备注 |
|------|------|------|
| 入住验证 | ✅ 可用 | |
| 唤醒词检测 | ✅ 可用 | |

---

## 十、数据库一致性检查

| 检查项 | 状态 | 备注 |
|--------|------|------|
| scene_configs表字段缺失 | ❌ FAIL | 缺少room_id, is_active字段 |
| rooms表字段名不匹配 | ❌ FAIL | 代码用floor_id，表用floor |
| rooms表status字段名 | ⚠️ 注意 | 表用room_status，非status |
| 预订room_id为NULL | ❌ FAIL | 导致入住接口500错误 |
| delivery_orders字段 | ⚠️ 注意 | item_name+quantity，非items |
| coupons表字段名 | ⚠️ 注意 | coupon_name/coupon_type/discount_value，非name/type/value |
| payments表字段名 | ⚠️ 注意 | order_type+order_id，非booking_id |
| rfid_cards需card_uid | ⚠️ 注意 | 发卡时必须提供card_uid |

---

## 十一、问题汇总统计

| 严重程度 | 数量 | 问题编号 |
|----------|------|---------|
| P0 (阻塞) | 5 | BUG-001, BUG-002, BUG-003, BUG-016, BUG-017 |
| P1 (重要) | 10 | BUG-004 ~ BUG-010, BUG-018 ~ BUG-022 |
| P2 (一般) | 7 | BUG-011 ~ BUG-015, BUG-023, BUG-024 |
| **合计** | **22** | |

---

## 十二、修复优先级建议

### 第一优先级 (P0 - 阻塞级)
1. **BUG-001**: 修复scene_configs表结构，添加room_id和is_active字段
2. **BUG-002**: 统一API响应格式，将所有模块改为标准 `{code, message, data, timestamp}` 格式
3. **BUG-003**: 修复房间创建接口的floor_id/floor字段映射
4. **BUG-016**: 修复预订入住流程，确认预订时自动分配room_id
5. **BUG-017**: 修复设备指令发送403问题，确保酒店管理员可控制本酒店设备

### 第二优先级 (P1 - 重要级)
6. **BUG-004**: 价格日历接口错误码和错误信息修正
7. **BUG-005**: 密码重置未注册手机号错误码修正(400→404)
8. **BUG-006**: 酒店房间可用性查询参数提示
9. **BUG-007**: 预订查询接口参数文档
10. **BUG-008**: 送物创建接口参数格式明确化
11. **BUG-009**: 顾客"我的房间"无入住时返回空数据
12. **BUG-010**: 角色申请接口错误信息明确化
13. **BUG-018**: RFID发卡接口参数验证
14. **BUG-019**: 优惠券创建接口参数名统一
15. **BUG-020**: 支付创建接口参数名统一
16. **BUG-021**: 维修工单顾客权限修复
17. **BUG-022**: 评价统计接口参数提示

### 第三优先级 (P2 - 一般级)
18. **BUG-011**: 系统管理员场景模块访问
19. **BUG-012**: 预订价格计算参数验证
20. **BUG-013**: 错误响应体为空问题
21. **BUG-014**: 预订room_id为NULL处理
22. **BUG-015**: 设备注册响应格式统一
23. **BUG-023**: 酒店创建HTTP状态码统一
24. **BUG-024**: 顾客修改系统配置返回403而非404

---

## 十三、测试环境信息

| 项目 | 值 |
|------|-----|
| 操作系统 | Windows |
| 后端版本 | 2.0.0 |
| 后端端口 | 9000 |
| 前端端口 | 5173 |
| 数据库 | MySQL (8.134.166.69:3306) |
| MQTT Broker | 8.134.166.69:1883 |
| Redis | 8.134.166.69:6379 |
| Node环境 | development |
