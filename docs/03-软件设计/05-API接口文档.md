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
  - **安全特性**：支持登录安全保护，连续5次密码错误将锁定账户15分钟
  - **登录锁定响应**：返回429状态码，提示剩余锁定时间
- `GET /auth/me`: 获取当前登录用户信息及权限。
- `POST /auth/register`: 新用户注册（默认角色为customer）。
- `POST /auth/logout`: 登出系统，注销会话。
- `POST /auth/switch-hotel`: 切换当前管理的酒店（仅system_admin可用）。
  - 请求体：`{ hotel_id: number }`
  - hotel_id为0时切换到集团总部视图
- `POST /auth/reset-password/send-code`: 发送密码重置验证码。
  - 请求体：`{ phone: string }`
  - 业务逻辑：发送短信验证码，有效期5分钟
- `POST /auth/reset-password`: 重置密码（需短信验证）。
  - 请求体：`{ phone, new_password, verification_code }`
- `POST /auth/role-application`: 提交角色升级申请。
  - 请求体：`{ application_type: 'create_hotel'|'bind_employee', hotel_id?, hotel_name?, hotel_address?, reason? }`
  - create_hotel：申请创建新酒店（需提供hotel_name, hotel_address）
  - bind_employee：申请绑定到已有酒店（需提供hotel_id）
- `GET /auth/role-applications`: 获取角色申请列表。
  - 酒店管理员仅能看到bind_employee类型且绑定到本酒店的申请
  - 顾客/住客仅能看到自己的申请
  - 查询参数：`status`（pending/approved/rejected）
- `PUT /auth/role-applications/:id/review`: 审核角色申请。
  - 请求体：`{ status: 'approved'|'rejected', review_note? }`
  - approved+create_hotel：自动创建酒店并升级用户为hotel_admin
  - approved+bind_employee：自动绑定用户到酒店并升级为staff
- `POST /users/authorize-manager`: 经理授权校验 (用于现场打折等特权操作)。
  - 请求体：`{ manager_id: number, password: string }`
  - 业务逻辑：校验经理是否存在、角色是否有权、所属酒店是否匹配、密码是否正确。
- `POST /auth/qr-generate`: 生成扫码登录二维码Token（无需认证）。
  - 业务逻辑：生成64位随机Token，存入api_tokens表（token_type=qr_login, status=pending），有效期5分钟。
  - 返回：`{ token: string, expiresAt: string }`
- `POST /auth/qr-confirm`: APP确认扫码登录（需JWT认证）。
  - 请求体：`{ token: string }`（二维码中包含的Token）
  - 业务逻辑：验证Token有效且状态为pending，将Token关联到APP用户，状态改为confirmed。
  - 返回：`{ message: "扫码确认成功" }`
- `GET /auth/qr-status`: Web端轮询扫码状态（无需认证）。
  - 查询参数：`token`（二维码Token）
  - 业务逻辑：查询Token状态。pending返回等待中；confirmed时生成JWT、创建会话、标记Token已使用，返回JWT和用户信息；expired返回已过期。
  - 返回（pending）：`{ status: "pending" }`
  - 返回（confirmed）：`{ status: "confirmed", token: JWT, sessionToken: string, user: UserInfo }`
  - 返回（expired）：`{ status: "expired" }`
- `POST /auth/generate-token`: 生成API Token（用于扫码登录）。
  - 请求体：`{ phone, password }`
  - 返回：`{ token, expiresAt, message }`
- `POST /auth/scan-login`: 使用API Token扫码登录。
  - 请求体：`{ token }`
  - 业务逻辑：验证Token有效且未使用，生成JWT，创建会话

### 2. 酒店资源管理 (`/hotels`, `/rooms`, `/room-types`, `/price-calendar`)
#### 2.1 酒店搜索与详情 (`/hotels`)
- `GET /hotels/search`: 根据目的地和日期搜索酒店。
  - 查询参数：`city`, `check_in_date?`, `check_out_date?`, `guest_count?`, `page?`, `pageSize?`
- `GET /hotels/:id`: 获取酒店详情。
- `GET /hotels/:hotelId/detail`: 获取酒店详情（含图片）。
- `GET /hotels/:hotelId/images`: 获取酒店图片列表。
- `POST /hotels/:hotelId/images`: 添加酒店图片（需hotel_admin/system_admin权限）。
  - 请求体：`{ image_url, sort_order? }`
- `PUT /hotels/:hotelId/images/:imageId`: 更新酒店图片（需hotel_admin/system_admin权限）。
- `DELETE /hotels/:hotelId/images/:imageId`: 删除酒店图片（需hotel_admin/system_admin权限）。
- `PUT /hotels/:hotelId`: 更新酒店信息（需hotel_admin/system_admin权限）。
- `GET /hotels/:id/rooms/availability`: 查询指定酒店的房型余量及价格。

#### 2.2 房间管理 (`/rooms`)
- `GET /rooms`: 获取房间列表 (支持分页及状态、房型 ID、楼层等筛选)。
  - 查询参数：`page`, `pageSize`, `status?`, `type?` (房型代码), `room_type_id?`, `floor?`, `hotel_id?`, `groupBy?` (如 'floor')
- `GET /rooms/:id`: 获取房间详情。
- `POST /rooms`: 创建房间（仅system_admin/hotel_admin）。
  - 请求体：`{ room_number, floor, room_type_id, status?, hotel_id }`
- `PUT /rooms/:id`: 更新房间信息（仅system_admin/hotel_admin）。
- `PATCH /rooms/:id/status`: 更新房间状态 (空闲/在住/清洁等)。
- `PUT /rooms/:id/status`: 更新房间状态（PATCH的别名）。
- `DELETE /rooms/:id`: 删除房间（仅system_admin/hotel_admin）。
- `GET /rooms/guest/my-room`: 获取顾客当前入住房间信息（需customer/guest角色，通过user_id或guest_phone匹配入住记录）。
- `GET /rooms/guest/:id/devices`: 获取顾客入住房间的设备列表（需customer/guest角色）。
- `GET /rooms/guest/my-room/devices`: 获取当前用户入住房间的设备列表。

#### 2.3 房型管理 (`/room-types`)
- `GET /room-types`: 获取所有房型定义及基础价格（按酒店过滤，需登录）。
- `GET /room-types/:id`: 获取房型详情。
- `POST /room-types`: 创建房型（仅hotel_admin/system_admin）。
- `PUT /room-types/:id`: 更新房型信息（仅hotel_admin/system_admin）。
- `DELETE /room-types/:id`: 删除房型（仅hotel_admin/system_admin）。

#### 2.4 楼层管理 (`/floors`)
- `GET /floors`: 获取楼层列表及平面图（支持hotel_admin/staff/system_admin/customer角色）。

#### 2.5 价格日历 (`/price-calendar`)
- `GET /price-calendar/today`: 获取今日各房型、各方案的可售余量与挂牌价格（需登录）。
- `POST /price-calendar/today/update`: 实时更新今日房型余量与价格（仅hotel_admin/system_admin）。
  - 请求体：`{ updates: [{ room_type_id, rate_plan_id, price, inventory }] }`

#### 2.6 价格方案 (`/rate-plans`)
> **权限要求**：`hotel_admin`（门店经理）、`staff`（前台）、`system_admin`（系统管理员）
- `GET /rate-plans`: 获取价格方案列表。
- `POST /rate-plans`: 创建价格方案。
  - 请求体：`{ plan_name, room_type_id, base_price, breakfast_included?, extra_bed_price?, cancellation_policy? }`
- `PUT /rate-plans/:id`: 更新价格方案。
- `DELETE /rate-plans/:id`: 删除价格方案（仅hotel_admin/system_admin）。

#### 2.7 酒店报表 (`/hotel/reports`)
- `GET /hotel/reports`: 获取酒店账单报表数据（需hotel_admin/system_admin/staff权限）。
  - 返回字段：`today_revenue`(今日营收)、`month_revenue`(本月累计)、`pending_bills`(待结算账单数)、`revenue_trend`(近7日营收趋势)、`income_composition`(收入构成)、`bills`(账单明细列表)。
  - 系统管理员可通过`hotel_id`查询参数指定酒店。

#### 2.8 酒店统计 (`/hotel/statistics`)
- `GET /hotel/statistics`: 获取集团/酒店运营统计数据（需system_admin/hotel_admin/staff权限）。
  - 返回字段：`hotel_count`(酒店数)、`member_count`(会员数)、`device_count`(设备数)、`total_revenue`(总营收)、`total_orders`(总订单数)、`monthly_revenue`(月度营收趋势)、`hotel_revenue_ranking`(酒店营收排名)。
  - 系统管理员返回全集团数据，酒店管理员/员工仅返回所属酒店数据。

#### 2.9 酒店列表 (`/hotel/all`)
- `GET /hotel/all`: 获取酒店列表（需system_admin/hotel_admin权限）。
  - 系统管理员返回所有酒店列表。
  - 酒店管理员仅返回自己管理的酒店信息。

#### 2.10 酒店增删改 (`/hotel`)
- `GET /hotel`: 获取酒店列表（需认证）。
- `POST /hotel`: 创建酒店（仅system_admin）。
- `PUT /hotel`: 更新酒店信息（需hotel_admin/system_admin）。
- `DELETE /hotel/:id`: 删除酒店（仅system_admin）。

### 3. 物联网设备控制 (`/devices`)
> **权限要求**：`hotel_admin`（门店经理）、`staff`（前台）、`system_admin`（系统管理员）、`customer`（顾客）
>
> **业务说明**：管理酒店物联网设备，包括客房端、楼控、前台管理端等硬件设备，支持设备控制、状态监控、固件升级等功能。

#### 3.1 设备基础管理
- `POST /devices/register`: 注册新设备（支持设备Token认证和管理员认证两种方式）。
  - 请求体（设备Token认证）：`{ device_id, device_type, device_key, hotel_id?, room_id? }`
  - 请求体（管理员认证）：`{ device_id, device_type, device_name, device_key, hotel_id, room_id? }`
  - **H-01安全加固**：新设备使用预注册Token认证，老设备需管理员手动注册审核
- `POST /devices/room-card`: 处理房间卡片设备绑定（需staff权限）。
  - 请求体：`{ device_id, room_id, action: 'bind'|'unbind' }`
- `GET /devices`: 获取设备列表及在线状态（支持hotel_admin/staff/system_admin/customer角色，顾客仅可查看自己入住房间的设备）。
  - 查询参数：`page`, `pageSize`, `hotel_id?`, `room_id?`, `device_type?`, `device_status?`, `group_id?`
  - 支持按设备分组筛选
- `GET /devices/:id`: 获取设备详情（支持hotel_admin/staff/system_admin/customer角色，顾客仅可查看自己入住房间的设备）。
  - 返回字段包含：设备基本信息、当前状态、最近传感器数据、固件版本等
- `PUT /devices/:id/audit`: 审核设备（仅system_admin/hotel_admin）。
  - 请求体：`{ audit_status: 'approved'|'rejected', audit_remark? }`
- `DELETE /devices/:id`: 移除设备（仅system_admin/hotel_admin，需先审核通过）。

#### 3.2 设备控制与指令
- `POST /devices/:id/command`: 发送控制指令，指令通过 MQTT 转发至硬件（支持 hotel_admin/staff/system_admin/customer 角色，顾客仅可控制自己入住房间的设备）。
  - 请求体：`{ command_type, command_value, timeout? }`
  - 指令类型：`relay_on`/`relay_off`/`set_brightness`/`set_temperature`/`scene_mode`/`ir_send` 等
  - 返回：`{ command_id, status, estimated_execution_time }`
- `GET /devices/:id/commands`: 查询设备指令执行历史。
  - 查询参数：`page`, `pageSize`, `command_type?`, `status?`, `start_date?`, `end_date?`

#### 3.3 传感器数据
- `GET /devices/:id/sensor-data`: 查询设备的传感器历史数据。
  - 查询参数：`sensor_type?`, `start_time?`, `end_time?`, `page`, `pageSize`
  - 传感器类型：`temperature`/`humidity`/`air_quality`/`light`/`power` 等
- `GET /devices/:id/sensor-data/latest`: 获取设备最新传感器数据。

#### 3.4 设备分组管理 (`/device-groups`)
- `GET /device-groups`: 获取设备分组列表。
  - 查询参数：`hotel_id`, `group_type?`
- `POST /device-groups`: 创建设备分组。
  - 请求体：`{ group_name, group_type, description?, device_ids? }`
- `PUT /device-groups/:id`: 更新分组信息。
- `DELETE /device-groups/:id`: 删除分组。
- `POST /device-groups/:id/devices`: 添加设备到分组。
  - 请求体：`{ device_ids: string[] }`
- `DELETE /device-groups/:id/devices/:device_id`: 从分组移除设备。
- `POST /device-groups/:id/command`: 批量控制分组内设备。
  - 请求体：`{ command_type, command_value }`

#### 3.5 设备告警管理 (`/device-alarms`)
- `GET /device-alarms`: 获取设备告警列表。
  - 查询参数：`hotel_id?`, `room_id?`, `alarm_type?`, `alarm_level?`, `status?`, `page`, `pageSize`
- `GET /device-alarms/:id`: 获取告警详情。
- `PUT /device-alarms/:id/handle`: 处理告警。
  - 请求体：`{ status: 'resolved'|'ignored', handle_remark? }`
- `GET /device-alarms/stats`: 获取告警统计。
  - 返回：`{ total_count, pending_count, by_type: {}, by_level: {} }`

#### 3.6 固件管理 (`/firmware`)
- `GET /firmware/updates`: 获取固件升级记录。
  - 查询参数：`device_id?`, `hotel_id?`, `update_status?`
- `POST /firmware/updates`: 发起固件升级（仅 system_admin/hotel_admin）。
  - 请求体：`{ device_ids: string[], firmware_version, firmware_url, schedule_time? }`
- `GET /firmware/updates/:id`: 获取升级任务详情。
- `POST /firmware/updates/:id/cancel`: 取消升级任务。

---

### 3.7 RFID房卡管理 (`/rfid`)
> **权限要求**：`hotel_admin`（门店经理）、`staff`（前台）、`system_admin`（系统管理员）
>
> **业务说明**：管理房卡的生命周期，包括发卡、挂失、注销等操作，以及门禁记录查询。

#### 3.7.1 房卡基础管理
- `GET /rfid/cards`: 获取房卡列表。
  - 查询参数：`hotel_id?`, `room_id?`, `booking_id?`, `status?`, `page`, `pageSize`
  - 返回字段：`id`, `card_uid`, `room_id`, `room_number`, `booking_id`, `status`, `issued_at`, `expires_at`
- `GET /rfid/cards/:id`: 获取房卡详情。
- `POST /rfid/cards/issue`: 发卡操作。
  - 请求体：`{ card_uid, booking_id, room_id, expires_at? }`
  - 业务逻辑：校验订单状态、房间状态，写入房卡信息到数据库
  - 返回：`{ card_id, issued_at, expires_at }`
- `POST /rfid/cards/batch-issue`: 批量发卡（用于团队入住）。
  - 请求体：`{ booking_id, room_ids: number[], card_uids: string[], expires_at? }`
- `PUT /rfid/cards/:id/status`: 更新房卡状态。
  - 请求体：`{ status: 'active'|'inactive'|'lost' }`
  - 状态说明：`active`(正常)/`inactive`(注销)/`lost`(挂失)
- `PUT /rfid/cards/:id/extend`: 延长房卡有效期（续住时使用）。
  - 请求体：`{ new_expires_at }`

#### 3.7.2 门禁记录
- `GET /rfid/access-logs`: 获取门禁刷卡记录。
  - 查询参数：`hotel_id?`, `room_id?`, `card_uid?`, `access_type?`, `access_result?`, `start_date?`, `end_date?`, `page`, `pageSize`
  - 返回字段：`id`, `card_uid`, `room_id`, `access_type`, `access_result`, `fail_reason`, `created_at`
- `GET /rfid/access-logs/stats`: 获取门禁统计。
  - 查询参数：`hotel_id`, `room_id?`, `start_date?`, `end_date?`
  - 返回：`{ total_access, success_count, failed_count, by_room: {} }`
- `POST /rfid/access-logs`: 上报门禁记录（设备端调用）。
  - 请求体：`{ card_uid, room_id, device_id, access_type, access_result, fail_reason? }`
  - 认证：使用设备密钥认证

#### 3.7.3 房卡验证（设备端调用）
- `POST /rfid/verify`: 验证房卡权限（设备端调用）。
  - 请求体：`{ card_uid, room_id, device_id, device_key }`
  - 返回：`{ valid: boolean, card_status, expires_at?, message? }`
  - 业务逻辑：验证卡号是否存在、状态是否正常、是否在有效期内、是否有权限进入该房间

---

### 3.8 红外遥控管理 (`/ir-remote`)
> **权限要求**：`hotel_admin`（门店经理）、`staff`（前台）、`system_admin`（系统管理员）
>
> **业务说明**：管理空调、电视等设备的红外遥控码，支持品牌通用码和房间自定义学习码。

#### 3.8.1 红外码管理
- `GET /ir-remote/codes`: 获取红外遥控码列表。
  - 查询参数：`hotel_id`, `device_type?`, `brand?`, `room_id?`, `is_default?`, `page`, `pageSize`
- `GET /ir-remote/codes/:id`: 获取红外码详情。
- `POST /ir-remote/codes`: 添加红外遥控码。
  - 请求体：`{ device_type, brand?, model?, function_name, ir_code, protocol?, room_id?, is_default?, is_custom? }`
- `PUT /ir-remote/codes/:id`: 更新红外码。
- `DELETE /ir-remote/codes/:id`: 删除红外码。

#### 3.8.2 红外学习
- `POST /ir-remote/learn/start`: 开始红外学习（设备端调用）。
  - 请求体：`{ device_id, device_key, room_id }`
  - 返回：`{ learn_session_id, timeout_seconds: 30 }`
- `POST /ir-remote/learn/complete`: 完成红外学习（设备端调用）。
  - 请求体：`{ learn_session_id, ir_code, protocol? }`
  - 业务逻辑：将学习到的红外码保存到数据库

#### 3.8.3 红外发送
- `POST /ir-remote/send`: 发送红外指令。
  - 请求体：`{ room_id, device_type, function_name }`
  - 业务逻辑：查找对应的红外码，通过MQTT发送给客房端设备执行

#### 3.8.4 品牌码库
- `GET /ir-remote/brands`: 获取支持的品牌列表。
  - 查询参数：`device_type`
- `GET /ir-remote/brands/:brand/functions`: 获取品牌的预设功能列表。
  - 返回：`{ brand, device_type, functions: [{ function_name, display_name }] }`

---

### 3.9 场景模式管理 (`/scenes`)
> **权限要求**：`hotel_admin`（门店经理）、`staff`（前台）、`system_admin`（系统管理员）、`customer`（顾客，仅执行）
>
> **业务说明**：管理客房场景模式，如欢迎模式、睡眠模式、节能模式等，支持一键执行多个设备控制指令。

#### 3.9.1 场景配置
- `GET /scenes`: 获取场景列表。
  - 查询参数：`hotel_id`, `room_id?`, `page`, `pageSize`
- `GET /scenes/:id`: 获取场景详情。
  - 返回字段：`id`, `scene_name`, `hotel_id`, `room_id`, `commands: [{ device_id, command_type, command_value, delay? }]`, `is_active`
- `POST /scenes`: 创建场景（仅 hotel_admin/system_admin）。
  - 请求体：`{ scene_name, hotel_id, room_id?, commands: [...], is_active? }`
- `PUT /scenes/:id`: 更新场景。
- `DELETE /scenes/:id`: 删除场景。
- `PATCH /scenes/:id/toggle`: 启用/禁用场景。

#### 3.9.2 场景执行
- `POST /scenes/:id/execute`: 执行场景。
  - 请求体：`{ room_id? }`（如场景未绑定房间，需传入）
  - 返回：`{ execution_id, status, estimated_duration }`
- `GET /scenes/executions`: 获取场景执行历史。
  - 查询参数：`scene_id?`, `hotel_id?`, `room_id?`, `execution_result?`, `page`, `pageSize`
- `GET /scenes/executions/:id`: 获取执行详情。
  - 返回字段：`id`, `scene_id`, `scene_name`, `trigger_type`, `execution_result`, `execution_detail`, `created_at`

#### 3.9.3 预设场景
- `POST /scenes/init-default`: 初始化默认场景（仅 hotel_admin/system_admin）。
  - 请求体：`{ hotel_id, room_type? }`
  - 默认场景：`welcome`(欢迎模式)/`sleep`(睡眠模式)/`away`(离家模式)/`energy_save`(节能模式)

---

### 3.10 能耗管理 (`/energy`)
> **权限要求**：`hotel_admin`（门店经理）、`staff`（前台）、`system_admin`（系统管理员）
>
> **业务说明**：管理酒店能耗数据，支持按房间、设备、时间维度统计，用于能耗分析和节能优化。

#### 3.10.1 能耗数据
- `GET /energy/consumption`: 获取能耗数据。
  - 查询参数：`hotel_id`, `room_id?`, `device_id?`, `consumption_type?`, `start_date`, `end_date`, `group_by?` (day/hour/room)
  - 返回：`{ total_consumption, unit, data: [{ date/device_id, consumption_value }] }`
- `POST /energy/consumption`: 上报能耗数据（设备端调用）。
  - 请求体：`{ device_id, room_id, consumption_type, consumption_value, unit, record_date, record_hour? }`
  - 认证：使用设备密钥认证

#### 3.10.2 能耗统计
- `GET /energy/stats`: 获取能耗统计。
  - 查询参数：`hotel_id`, `start_date`, `end_date`, `group_by?` (room/type/time)
  - 返回：`{ total, by_room: {}, by_type: {}, trend: [], comparison: { vs_last_period, vs_same_period_last_year } }`
- `GET /energy/ranking`: 获取能耗排名。
  - 查询参数：`hotel_id`, `date_range`, `order?` (asc/desc), `limit?`
  - 返回：`{ ranking: [{ room_id, room_number, consumption_value, rank }] }`

#### 3.10.3 节能建议
- `GET /energy/suggestions`: 获取节能建议。
  - 查询参数：`hotel_id`, `room_id?`
  - 返回：`{ suggestions: [{ type, title, description, potential_savings }] }`

---

### 3.11 语音通话管理 (`/voice-calls`)
> **权限要求**：`hotel_admin`（门店经理）、`staff`（前台）、`system_admin`（系统管理员）、`customer`（顾客）
>
> **业务说明**：管理客房端与前台之间的语音通话，支持一键呼叫、通话质量监控等功能。

#### 3.11.1 通话管理
- `GET /voice-calls`: 获取通话记录列表。
  - 查询参数：`hotel_id?`, `room_id?`, `call_type?`, `start_date?`, `end_date?`, `page`, `pageSize`
- `GET /voice-calls/:id`: 获取通话详情。
- `GET /voice-calls/active`: 获取当前正在进行的通话。
  - 返回：`{ active_calls: [{ call_id, room_id, caller_type, started_at, duration }] }`

#### 3.11.2 通话质量
- `GET /voice-calls/:id/quality`: 获取通话质量数据。
  - 返回：`{ packet_loss_rate, latency_ms, jitter_ms, audio_quality_score, network_type }`
- `GET /voice-calls/quality-stats`: 获取通话质量统计。
  - 查询参数：`hotel_id`, `start_date`, `end_date`
  - 返回：`{ avg_latency, avg_packet_loss, avg_quality_score, total_calls, failed_calls }`

#### 3.11.3 通话控制（WebSocket信令）
- WebSocket 事件：
  - `call_initiate`: 发起通话
  - `call_accept`: 接听通话
  - `call_reject`: 拒绝通话
  - `call_end`: 结束通话
  - `call_quality_report`: 通话质量上报

### 4. 业务订单系统 (`/bookings`, `/payments`)
#### 4.1 订单管理 (`/bookings`)
- `POST /bookings`: 创建客房预订。
  - **业务逻辑**：自动关联用户账号，通过手机号匹配user_id；自动设置auto_checkout_at为退房日期中午12:00。
  - **解耦逻辑**：支持仅传`room_type_id`进行房型预订（不绑定具体房间）。
  - **支持手动优惠**：`manual_discount`(折扣率，如0.8), `manual_reduce`(直减金额)。需经理授权后由前端调用。
  - 请求体：`{ room_id?, room_type_id, check_in_date, check_out_date, guest_name, guest_phone, guest_count?, manual_discount?, manual_reduce?, notes? }`
- `GET /bookings/lookup`: 顾客查询预订（用于在线入住前验证）。
  - **业务逻辑**：仅返回状态为`pending`或`confirmed`且**退房日期未过期**的订单。
- `GET /bookings/my`: 获取当前用户的订单列表。
- `GET /bookings/calculate-price`: 预计算订单总价(考虑优惠券、会员折扣及手动打折)。
  - 查询参数：`room_id?`, `room_type_id?`, `check_in_date`, `check_out_date`, `guest_phone?`, `coupon_id?`, `manual_discount?`, `manual_reduce?`
  - **同时支持POST方法**：请求体参数相同
- `POST /bookings/calculate-price`: 预计算订单总价（POST方式）。
  - 请求体：`{ room_id?, room_type_id?, check_in_date, check_out_date, guest_phone?, coupon_id?, manual_discount?, manual_reduce? }`
- `GET /bookings/:id`: 获取订单详情。
- `PUT /bookings/:id/confirm`: 确认订单（仅staff角色）。
- `PUT /bookings/:id/checkin`: 办理入住，激活房卡。
  - **业务逻辑**：自动通过手机号关联用户账号，设置auto_checkout_at。
  - **支持同步更新价格**：支持在办理入住时动态传入`manual_discount`, `manual_reduce`, `total_price`更新订单最终价。
  - 请求体：`{ room_id?, manual_discount?, manual_reduce?, total_price?, check_in_date?, check_out_date? }`
- `POST /bookings/:id/checkin-online`: 顾客在线办理入住（支持两种路由格式）。
  - **业务逻辑**：将状态改为`pre_checked_in`（预入住），需校验退房日期未过期。
  - **选房绑定**：支持传入`room_id`进行物理房间绑定，并将房间状态改为`reserved`。
- `POST /bookings/checkin-online/:id`: 顾客在线办理入住（别名路由）。
- `PUT /bookings/:id/reject-pre-checkin`: 拒绝预入住（仅staff角色）。
  - 请求体：`{ reason? }`
- `PUT /bookings/:id/checkout`: 办理退房，结清账单。
- `PUT /bookings/:id/cancel`: 取消预订。
- `PATCH /bookings/:id/status`: 更新订单状态（仅staff角色）。
  - 请求体：`{ status }`
- `POST /bookings/:id/extend-price`: 计算续住价格（需登录，支持优惠券和积分抵扣参数）。
  - 请求体：`{ new_check_out_date: string, coupon_id?: number, used_points?: number }`
  - 返回：`{ base_price, discount_rate, member_discount, coupon_discount, points_discount, used_points, total_price, extend_nights }`
- `PUT /bookings/:id/extend`: 提交续住申请（需登录，自动处理优惠券核销、积分扣减、支付记录创建）。
  - 请求体：`{ new_check_out_date: string, coupon_id?: number, used_points?: number, payment_method?: string }`
  - 返回：`{ booking_id, new_check_out_date, extend_nights, additional_price, new_total_price, need_payment, payment_id, coupon_used }`
  - 业务逻辑：校验预订状态（checked_in/confirmed）→ 检查日期冲突 → 计算续住价格 → 核销优惠券 → 扣减积分 → 更新退房日期和总价 → 创建支付记录 → 更新自动退房时间

#### 4.2 支付管理 (`/payments`)
- `POST /payments`: 发起支付请求（需登录）。
  - 请求体：`{ booking_id, amount, payment_method: 'wechat'|'alipay'|'card'|'cash' }`
- `PUT /payments/:id/pay`: 支付订单。
  - 请求体：`{ payment_details? }`
- `GET /payments/stats/revenue`: 获取营收统计（仅staff角色）。
  - 查询参数：`start_date?`, `end_date?`, `group_by?` (day/month/hotel)
- `GET /payments`: 获取支付记录列表（仅staff角色）。
- `GET /payments/:id`: 获取支付记录详情。

### 5. 客房服务与通信 (`/delivery`, `/maintenance`, `/calls`)

#### 5.1 配送服务 (`/delivery`)
> **权限要求**：所有角色（hotel_admin/staff/system_admin/customer/guest）
- `GET /delivery`: 获取配送服务列表。
- `GET /delivery/:id`: 获取配送服务详情。
- `POST /delivery`: 下单送物服务。
  - 请求体：`{ booking_id?, room_id, room_number, items: [{ name, quantity, note? }], contact_phone?, note? }`
- `PUT /delivery/:id/status`: 更新配送状态（仅staff角色）。
  - 请求体：`{ status: 'preparing'|'picking'|'delivering'|'cancelled' }`
- `PUT /delivery/:id/complete`: 完成配送（仅staff角色）。

#### 5.2 维护工单 (`/maintenance`)
> **权限要求**：所有角色（hotel_admin/staff/system_admin/customer/guest）
- `GET /maintenance`: 获取维护工单列表。
- `GET /maintenance/:id`: 获取维护工单详情。
- `POST /maintenance`: 提交报修工单。
  - 请求体：`{ room_id, room_number, category, description, contact_phone?, images? }`
  - category枚举：plumbing/electrical/hvac/furniture/other
- `PUT /maintenance/:id/assign`: 分配维修人员（仅staff角色）。
  - 请求体：`{ assigned_to, estimated_time? }`
- `PUT /maintenance/:id/status`: 更新工单状态（仅staff角色）。
  - 请求体：`{ status: 'assigned'|'in_progress'|'completed'|'cancelled' }`
- `PUT /maintenance/:id/complete`: 完成维修（仅staff角色）。
  - 请求体：`{ solution?, actual_time? }`
- `DELETE /maintenance/:id`: 删除工单（仅admin角色）。

#### 5.3 语音通话管理 (`/calls`)
> **权限要求**：`hotel_admin`（门店经理）、`staff`（前台）、`system_admin`（系统管理员）、`customer`（顾客）
>
> **业务说明**：管理客房端与前台之间的语音通话，支持一键呼叫、WebRTC双向通话等功能。

##### 5.3.1 基础通话管理
- `POST /calls/initiate`: 发起呼叫请求（客房端呼叫前台）。
  - 请求体：`{ room_id, call_type: 'emergency'|'service' }`
- `POST /calls/outbound`: 前台主动外呼（外呼到客房）。
  - 请求体：`{ room_id, room_number? }`
- `POST /calls/:call_id/answer`: 接听来电（前台端）。
- `POST /calls/:call_id/reject`: 拒绝来电。
- `POST /calls/:call_id/hangup`: 挂断通话。
- `GET /calls/:call_id/status`: 获取通话状态。
- `GET /calls/active`: 获取当前正在进行的通话（仅staff角色）。
  - 返回：`{ active_calls: [{ call_id, room_id, caller_type, started_at, duration }] }`
- `GET /calls/history`: 获取通话历史记录（仅staff角色）。
  - 查询参数：`page`, `pageSize`, `room_id?`, `start_date?`, `end_date?`
- `GET /calls/stats`: 获取通话统计（仅staff角色）。

##### 5.3.2 WebRTC语音通话（双通道兼容）
- `POST /calls/webrtc/session`: 创建WebRTC语音会话。
  - 请求体：`{ call_id, room_id?, room_number? }`
  - 返回：`{ session_id, call_id, device_id, room_number, state, created_at }`
  - 用于前端浏览器与房间硬件设备建立WebRTC语音通话
- `POST /calls/webrtc/:session_id/sdp-offer`: 发送SDP Offer到语音网关。
  - 请求体：`{ sdp: { type: 'offer', sdp: string } }`
- `POST /calls/webrtc/:session_id/ice-candidate`: 发送ICE Candidate到语音网关。
  - 请求体：`{ candidate: ICE_Candidate }`
- `POST /calls/webrtc/:session_id/terminate`: 终止WebRTC会话。
  - 请求体：`{ reason?: 'user_hangup'|'device_busy'|'network_error' }`
- `GET /calls/webrtc/sessions`: 获取活跃WebRTC会话列表（管理用）。
- `GET /calls/webrtc/stats`: 获取WebRTC语音网关统计。

### 6. AI 智能管家 (`/ai-butler`)
- `POST /ai-butler/chat`: 发送文本/语音指令，获取AI响应及Function Calling结果。
  - 请求体：`{ message, session_id?, context? }`
- `GET /ai-butler/config`: 获取AI管家的个性化配置。

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

### 9. 环境监测管理 (`/environment`)
> **权限要求**：`hotel_admin`（门店经理）、`staff`（前台）、`system_admin`（系统管理员）
>
> **业务说明**：管理酒店环境监测数据，包括温湿度、空气质量、火灾报警等，支持实时监控和历史数据分析。

#### 9.1 环境数据
- `GET /environment`: 获取环境数据（最新传感器读数）。
  - 返回：各房间的温度、湿度、空气质量等实时数据
- `GET /environment/history`: 获取环境历史数据。
  - 查询参数：`start_time?`, `end_time?`, `room_id?`, `page?`, `pageSize?`

#### 9.2 火灾报警
- `GET /environment/fire-alarms`: 获取火灾报警列表。
  - 查询参数：`status?`（pending/acknowledged/resolved）, `hotel_id?`, `room_id?`
- `PUT /environment/fire-alarms/:id/acknowledge`: 确认报警（收到报警后确认处理）。
- `PUT /environment/fire-alarms/:id/resolve`: 解决报警（处理完毕后标记为已解决）。

#### 9.3 设备环境控制
- `GET /environment/devices`: 获取房间设备列表（用于环境控制）。
- `POST /environment/devices/:id/control`: 控制环境设备。
  - 请求体：`{ command_type: 'power'|'mode'|'temperature'|'fan_speed', command_value }`

#### 9.4 事件日志与统计
- `GET /environment/event-logs`: 获取环境事件日志。
  - 查询参数：`event_type?`, `room_id?`, `start_date?`, `end_date?`, `page?`, `pageSize?`
- `GET /environment/dashboard`: 获取环境监测仪表板统计数据。
  - 返回：各楼层/房间的环境状态汇总、异常告警统计等

### 10. 收藏管理 (`/favorites`)
> **权限要求**：需登录（所有角色）
>
> **业务说明**：用户收藏酒店功能，方便快速查看和管理常住的酒店。

#### 10.1 收藏列表
- `GET /favorites`: 获取当前用户的收藏酒店列表。
  - 返回字段：`id`, `hotel_id`, `hotel_name`, `hotel_address`, `rating`, `image_url`, `favorited_at`

#### 10.2 添加收藏
- `POST /favorites`: 添加酒店到收藏。
  - 请求体：`{ hotel_id }`
  - 返回：`{ id, hotel_id, message }`

#### 10.3 取消收藏
- `DELETE /favorites/:hotelId`: 取消收藏指定酒店。
  - 返回：`{ message }`

#### 10.4 查询收藏状态
- `GET /favorites/check/:hotelId`: 查询指定酒店是否已收藏（公开接口，游客也可访问）。
  - 返回：`{ is_favorite: boolean }`

### 11. 常旅客管理 (`/frequent-guests`)
> **权限要求**：所有角色（hotel_admin/staff/system_admin/customer/guest）
>
> **业务说明**：管理常旅客信息，记录旅客偏好和历史入住记录，提供个性化服务。

#### 11.1 常旅客列表
- `GET /frequent-guests`: 获取常旅客列表。
  - 查询参数：`hotel_id?`, `page?`, `pageSize?`

#### 11.2 创建常旅客
- `POST /frequent-guests`: 创建常旅客信息。
  - 请求体：`{ name, phone, email?, preferences?, visit_count?, total_stay_days? }`

#### 11.3 更新常旅客
- `PUT /frequent-guests/:id`: 更新常旅客信息。

#### 11.4 删除常旅客
- `DELETE /frequent-guests/:id`: 删除常旅客记录。

### 12. MQTT管理 (`/mqtt`)
> **权限要求**：`system_admin`（系统管理员）、`hotel_admin`（酒店管理员）
>
> **业务说明**：MQTT消息管理接口，用于监控MQTT消息日志、发送MQTT消息、查看MQTT连接状态。

#### 12.1 MQTT日志
- `GET /mqtt/logs`: 获取MQTT消息日志。
  - 查询参数：`topic?`, `action?`, `start_date?`, `end_date?`, `page?`, `pageSize?`

#### 12.2 发送MQTT消息
- `POST /mqtt/send`: 发送MQTT消息到指定主题。
  - 请求体：`{ topic, payload, qos?: 0|1|2 }`

#### 12.3 MQTT状态
- `GET /mqtt/status`: 获取MQTT连接状态。
  - 返回：`{ connected: boolean, uptime, message_count, client_count }`

### 13. 住客管理 (`/guests`)
> **权限要求**：`hotel_admin`（门店经理）、`staff`（前台）、`system_admin`（系统管理员）
>
> **业务说明**：管理在住客人信息，记录客人详细资料和特殊需求。

#### 13.1 住客列表
- `GET /guests`: 获取住客列表。
  - 查询参数：`hotel_id?`, `booking_id?`, `page?`, `pageSize?`

#### 13.2 住客详情
- `GET /guests/:id`: 获取住客详细信息。
- `GET /guests/booking/:booking_id`: 根据订单获取住客信息。

#### 13.3 住客增删改
- `POST /guests`: 创建住客信息。
- `PUT /guests/:id`: 更新住客信息。
- `DELETE /guests/:id`: 删除住客记录。

### 14. 健康检查 (`/health`)
> **权限要求**：公开接口（无需认证）
>
> **业务说明**：服务健康检查接口，用于监控后端服务状态。

#### 14.1 健康检查
- `GET /health`: 获取服务健康状态。
  - 返回：`{ code: 200, message: "服务正常", timestamp, version: "2.0.0" }`

### 15. 用户管理 (`/users`)
> **权限要求**：管理员接口需 `hotel_admin/system_admin`，部分接口需认证

#### 15.1 用户列表与详情
- `POST /users/send-code`: 发送验证码（用于用户验证等场景）。
  - 请求体：`{ phone, type: 'login'|'register'|'password_reset' }`
- `GET /users/`: 获取用户列表（仅hotel_admin/system_admin/staff）。
  - 查询参数：`page?`, `pageSize?`, `role?`, `hotel_id?`
- `GET /users/:id`: 获取用户详情（仅hotel_admin/system_admin/staff）。
- `POST /users/`: 创建用户（仅hotel_admin/system_admin）。
- `PUT /users/:id`: 更新用户信息（仅hotel_admin/system_admin）。
- `DELETE /users/:id`: 删除用户（仅system_admin）。
- `PUT /users/profile`: 更新个人资料（需认证）。
  - 请求体：`{ username?, email?, avatar? }`
- `PUT /users/:id/password`: 修改用户密码（仅hotel_admin/system_admin）。
  - 请求体：`{ new_password }`
- `POST /users/:id/lock`: 锁定用户账户（仅system_admin）。
- `POST /users/:id/unlock`: 解锁用户账户（需hotel_admin/system_admin）。
- `POST /users/authorize-manager`: 经理授权校验（用于特权操作验证）。
  - 请求体：`{ manager_id, password }`

### 16. 优惠券管理 (`/coupons`)
> **权限要求**：所有角色可查看和领取，核销和发放仅staff/admin

#### 16.1 优惠券列表
- `GET /coupons`: 获取优惠券列表（需登录）。
  - 查询参数：`hotel_id?`, `status?`, `type?`, `page?`, `pageSize?`
- `GET /coupons/hotels`: 获取支持优惠券的酒店列表。
- `GET /coupons/me`: 获取当前用户的优惠券列表。
- `GET /coupons/:id`: 获取优惠券详情。

#### 16.2 优惠券领取与核销
- `POST /coupons/:id/receive`: 领取优惠券。
- `POST /coupons/:id/redeem`: 核销使用优惠券（仅staff角色）。
  - 请求体：`{ coupon_code }`
- `POST /coupons/redeem`: 通过优惠码核销（仅staff角色）。
  - 请求体：`{ coupon_code }`

#### 16.3 优惠券管理（管理员）
- `POST /coupons/import`: 批量导入优惠券（仅admin）。
  - 请求体：`{ coupons: [...] }`
- `POST /coupons/issue-to-user`: 发放优惠券给指定用户（仅admin）。
  - 请求体：`{ user_id, coupon_template_id, quantity? }`
- `POST /coupons`: 创建优惠券模板（仅admin）。
  - 请求体：`{ name, type, discount_value, min_amount?, valid_from, valid_until, quantity_limit? }`
- `PUT /coupons/:id`: 更新优惠券模板（仅admin）。
- `DELETE /coupons/:id`: 删除优惠券模板（仅admin）。

### 17. 会员管理 (`/members`)
> **权限要求**：查看会员信息需认证，部分管理操作需admin

#### 17.1 会员信息
- `GET /members`: 获取会员列表（仅hotel_admin/staff/system_admin）。
  - 查询参数：`page?`, `pageSize?`, `level?`, `hotel_id?`
- `GET /members/me`: 获取当前用户的会员信息。
- `GET /members/status`: 获取会员状态（公开接口）。
  - 返回：`{ is_member, level, points, discount_rate }`
- `GET /members/discounts`: 获取会员等级折扣信息（公开接口）。
  - 返回：`{ levels: [{ name, discount_rate, points_threshold }] }`
- `GET /members/:id`: 获取会员详情（仅hotel_admin/staff/system_admin）。

#### 17.2 会员操作
- `POST /members/recharge`: 会员余额充值。
  - 请求体：`{ amount, payment_method }`
- `POST /members/checkin`: 会员入住签到。
  - 请求体：`{ booking_id }`
- `POST /members`: 创建会员（仅admin）。
- `PUT /members/:id`: 更新会员信息（仅admin）。
- `PUT /members/discounts`: 更新会员等级折扣配置（仅system_admin）。
  - 请求体：`{ discounts: [{ level, discount_rate }] }`
- `POST /members/fix-schema`: 修复会员数据表结构（仅system_admin）。
- `POST /members/login`: 会员登录（手机号+密码）。

### 18. 文件上传 (`/upload`)
> **权限要求**：需认证

#### 18.1 图片上传
- `POST /upload/image`: 上传图片文件。
  - 请求格式：multipart/form-data
  - 字段：`image`（图片文件）
  - 返回：`{ url, filename, size }`

### 19. 评价与申诉系统 (`/reviews`)
> **权限要求**：部分接口需登录，申诉处理仅 `system_admin`

#### 9.1 获取评价列表
- **接口**：`GET /reviews`
- **参数**：`hotel_id`(可选), `user_id`(可选), `page`, `pageSize`
- **说明**：获取评价列表，支持按酒店和用户过滤，排除已软删除的评价

#### 9.2 获取评价详情
- **接口**：`GET /reviews/:id`
- **说明**：获取单条评价详情，包含酒店名称和房型名称

#### 9.3 获取我的评价
- **接口**：`GET /reviews/my`
- **权限**：需登录
- **说明**：获取当前登录用户的所有评价，支持分页

#### 9.4 获取评价统计
- **接口**：`GET /reviews/stats`
- **参数**：`hotel_id`(必填)
- **返回数据**：`{ total_reviews, avg_score, avg_environment, avg_facility, avg_comfort, good_count, medium_count, bad_count, distribution }`

#### 9.5 创建评价
- **接口**：`POST /reviews`
- **权限**：需登录（顾客）
- **请求体**：`{ order_id, hotel_id?, room_type_id?, score, environment_rating, facility_rating, comfort_rating, content, photos? }`
- **业务约束**：订单必须已退房、只能评价自己的订单、不可重复评价

#### 9.6 修改评价
- **接口**：`PUT /reviews/:id`
- **权限**：评价本人或系统管理员
- **请求体**：`{ score?, environment_rating?, facility_rating?, comfort_rating?, content?, photos? }`

#### 9.7 删除评价
- **接口**：`DELETE /reviews/:id`
- **权限**：评价本人或系统管理员
- **说明**：软删除，删除后自动更新酒店评分

#### 9.8 回复评价
- **接口**：`POST /reviews/:id/reply`
- **权限**：酒店管理员、前台、系统管理员
- **请求体**：`{ reply }`

#### 9.9 获取申诉列表
- **接口**：`GET /reviews/appeals`
- **权限**：需登录
- **参数**：`hotel_id`(可选), `status`(可选), `page`, `pageSize`
- **说明**：酒店管理员只能查看本酒店的申诉，系统管理员可查看所有

#### 9.10 创建申诉
- **接口**：`POST /reviews/appeals`
- **权限**：酒店管理员或前台
- **请求体**：`{ review_id, appeal_reason }`
- **业务约束**：同一评价不能重复提交待处理的申诉

#### 9.11 处理申诉
- **接口**：`PUT /reviews/appeals/:id`
- **权限**：仅系统管理员
- **请求体**：`{ action: 'approved'|'rejected', handle_reason? }`
- **说明**：approved 通过后评价自动软删除

---

## 📡 实时推送 (WebSocket)

### 连接方式
- **WebSocket URL**: `wss://api.example.com/ws`
- **认证方式**: 连接时携带 `Authorization: Bearer <token>`

### 事件列表

#### 设备相关事件
| 事件名 | 方向 | 说明 | 数据格式 |
|:---:|:---:|:---|:---|
| `device_status_change` | 服务端→客户端 | 设备在线/离线或状态变更提醒 | `{ device_id, room_id, old_status, new_status, timestamp }` |
| `device_sensor_data` | 服务端→客户端 | 传感器数据实时推送 | `{ device_id, sensor_type, value, unit, timestamp }` |
| `device_alarm` | 服务端→客户端 | 设备告警推送 | `{ alarm_id, device_id, room_id, alarm_type, alarm_level, content, timestamp }` |
| `device_command_result` | 服务端→客户端 | 设备指令执行结果 | `{ command_id, device_id, status, result, executed_at }` |

#### 房卡相关事件
| 事件名 | 方向 | 说明 | 数据格式 |
|:---:|:---:|:---|:---|
| `rfid_access_event` | 服务端→客户端 | 门禁刷卡事件 | `{ card_uid, room_id, access_type, access_result, timestamp }` |
| `rfid_card_status_change` | 服务端→客户端 | 房卡状态变更 | `{ card_id, old_status, new_status, changed_by }` |

#### 语音通话事件
| 事件名 | 方向 | 说明 | 数据格式 |
|:---:|:---:|:---|:---|
| `voice_call_incoming` | 服务端→客户端 | 来电通知 | `{ call_id, room_id, caller_type, timestamp }` |
| `voice_call_signal` | 双向 | 语音通话信令交换 | `{ type: 'offer'|'answer'|'ice-candidate', data }` |
| `voice_call_ended` | 服务端→客户端 | 通话结束通知 | `{ call_id, duration, end_reason }` |
| `voice_call_quality` | 客户端→服务端 | 通话质量上报 | `{ call_id, packet_loss, latency, timestamp }` |

#### 场景执行事件
| 事件名 | 方向 | 说明 | 数据格式 |
|:---:|:---:|:---|:---|
| `scene_execution_start` | 服务端→客户端 | 场景开始执行 | `{ execution_id, scene_id, scene_name, room_id }` |
| `scene_execution_progress` | 服务端→客户端 | 场景执行进度 | `{ execution_id, progress_percent, current_step }` |
| `scene_execution_complete` | 服务端→客户端 | 场景执行完成 | `{ execution_id, result, completed_at }` |

#### 业务相关事件
| 事件名 | 方向 | 说明 | 数据格式 |
|:---:|:---:|:---|:---|
| `new_order_notice` | 服务端→客户端 | 收到新的预订或服务订单 | `{ order_id, order_type, room_id, timestamp }` |
| `emergency_alarm` | 服务端→客户端 | SOS 报警信息实时推送 | `{ alarm_id, room_id, alarm_type, timestamp }` |
| `firmware_update_progress` | 服务端→客户端 | 固件升级进度 | `{ device_id, progress_percent, status }` |

### 客户端订阅示例
```javascript
const ws = new WebSocket('wss://api.example.com/ws');
ws.onopen = () => {
  // 订阅设备状态变更
  ws.send(JSON.stringify({
    action: 'subscribe',
    channels: ['device_status_change', 'device_alarm', 'rfid_access_event']
  }));
};

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  switch(data.event) {
    case 'device_status_change':
      console.log('设备状态变更:', data);
      break;
    case 'device_alarm':
      console.log('设备告警:', data);
      // 紧急告警时播放提示音
      if (data.alarm_level === 'emergency') {
        playEmergencyAlert();
      }
      break;
    case 'rfid_access_event':
      console.log('门禁事件:', data);
      break;
  }
};
```

---

## 🛠️ 错误处理

| 状态码 | 说明 | 处理建议 |
|:---:|:---|:---|
| `400` | 参数错误 | 检查请求体字段及格式 |
| `401` | 未授权 | 重新登录获取 Token |
| `403` | 权限不足 | 检查当前角色是否有权访问该接口 |
| `404` | 资源不存在 | 确认 URL 或资源 ID 正确 |
| `409` | 资源冲突 | 如：设备离线、房卡已挂失、房间已被占用 |
| `422` | 业务逻辑错误 | 如：房卡已过期、指令执行超时 |
| `429` | 请求过于频繁 | 降低请求频率，稍后重试 |
| `500` | 服务器内部错误 | 联系后端管理员排查日志 |
| `503` | 服务暂不可用 | MQTT服务或设备通信异常，稍后重试 |

### 硬件相关错误码
| 错误码 | 说明 | 处理建议 |
|:---:|:---|:---|
| `DEVICE_OFFLINE` | 设备离线 | 检查设备网络连接，稍后重试 |
| `DEVICE_TIMEOUT` | 设备响应超时 | 检查设备状态，可能需要重启设备 |
| `COMMAND_FAILED` | 指令执行失败 | 查看错误详情，检查设备状态 |
| `RFID_CARD_INVALID` | 房卡无效 | 检查房卡是否已挂失或过期 |
| `RFID_CARD_EXPIRED` | 房卡已过期 | 续住后延长房卡有效期 |
| `IR_CODE_NOT_FOUND` | 红外码不存在 | 先进行红外学习或添加红外码 |
| `SCENE_EXECUTION_FAILED` | 场景执行失败 | 检查场景配置和各设备状态 |
| `FIRMWARE_UPDATE_FAILED` | 固件升级失败 | 检查设备网络，可尝试重新升级 |
