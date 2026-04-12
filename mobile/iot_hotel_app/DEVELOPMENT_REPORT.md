# IoT智慧酒店系统 - App端与Web端功能差异及全栈代码质量分析报告

> 生成日期: 2026-04-11
> 分析范围: Web前端(Vue3) / App端(Flutter) / 后端(Node.js+Express) / 数据库(MySQL)

---

## 目录

1. [功能差异对比总览](#1-功能差异对比总览)
2. [各角色功能差异详细分析](#2-各角色功能差异详细分析)
3. [App端功能实现完整性分析](#3-app端功能实现完整性分析)
4. [App端代码质量问题清单](#4-app端代码质量问题清单)
5. [后端API问题与安全风险](#5-后端api问题与安全风险)
6. [Service层未使用API方法统计](#6-service层未使用api方法统计)
7. [开发优先级与任务规划](#7-开发优先级与任务规划)

---

## 1. 功能差异对比总览

### 1.1 功能覆盖统计

| 角色 | Web端页面数 | App端页面数 | App端覆盖率 | 差异项数 |
|------|-----------|-----------|-----------|---------|
| 系统管理员 | 5 | 2 | 40% | 3 |
| 酒店管理员 | 11 | 11 | 100% | 0 (页面有，功能有差异) |
| 前台员工 | 12 | 13 | 108% | 0 (App已补齐) |
| 顾客 | 5+1 | 17 | 283% | 0 (App更丰富) |
| **合计** | **33+1** | **43** | - | **3** |

> 注: App端页面数多于Web端是因为App端将部分功能拆分为独立页面(如钱包、优惠券中心等)

### 1.2 App端缺失的Web端功能

| # | 角色 | 缺失功能 | Web端路由 | 严重程度 |
|---|------|---------|----------|---------|
| 1 | 系统管理员 | 酒店管理(完整CRUD) | `/system/hotels` | 🔴 高 |
| 2 | 系统管理员 | 全局设备管理 | `/system/devices` | 🔴 高 |
| 3 | 系统管理员 | 系统配置对接 | `/system/settings` | 🟡 中 |

---

## 2. 各角色功能差异详细分析

### 2.1 系统管理员 (System Admin)

| 功能 | Web端 | App端 | 差异说明 |
|------|-------|-------|---------|
| 集团运营总览 | ✅ ECharts图表(营收趋势/酒店排名/房间分布/预订分布) | ⚠️ 简单统计卡片，无图表 | App缺少趋势图和排名列表 |
| 酒店管理 | ✅ 完整CRUD(名称/编码/城市/地址/电话/星级/Logo/描述) | ❌ 仅有新增对话框(占位符) | **App完全缺失酒店管理页面** |
| 全局设备管理 | ✅ 搜索/筛选/详情/删除 | ❌ 无 | **App完全缺失全局设备页面** |
| 账户管理 | ✅ 分页/搜索/筛选/CRUD/角色选择/酒店绑定 | ⚠️ 基础CRUD | App缺少角色更新、启禁用功能 |
| 系统配置 | ✅ 对接system-config API | ❌ 全部硬编码模拟数据 | App设置页完成度仅15% |

### 2.2 酒店管理员 (Hotel Admin)

| 功能 | Web端 | App端 | 差异说明 |
|------|-------|-------|---------|
| 总览仪表盘 | ✅ 设备在线率饼图/房间状态表 | ✅ 收入趋势图/到达列表 | 基本对齐 |
| 设备监控 | ✅ 双Tab(活跃+待审核)/审核弹窗/指令发送 | ⚠️ 仅设备列表 | **App用了错误API(getMyRoomDevices)**，缺少审核和指令功能 |
| 环境监测 | ✅ 6个子Tab(总览/环境数据/消防报警/设备管理/能耗统计/事件日志) | ⚠️ 4个子Tab(概览/火警/事件日志/环境数据) | App缺少设备管理和能耗统计Tab |
| 房间管理 | ✅ 楼层分组Tab/CRUD/图片上传 | ✅ 基础CRUD | App缺少图片上传 |
| 房型管理 | ✅ CRUD/图片上传 | ✅ CRUD | App缺少图片上传 |
| 楼层管理 | ✅ CRUD/楼层平面图上传 | ✅ CRUD | App缺少平面图上传 |
| 酒店信息编辑 | ✅ 完整表单(星级/时间/Logo等) | ⚠️ 基础信息编辑 | App缺少图片上传、星级评分 |
| 价格日历 | ✅ 日历视图+价格方案管理+会员折扣 | ⚠️ 日历视图+基础定价 | App缺少价格方案和会员折扣 |
| 优惠券管理 | ✅ CRUD+发放+核销 | ⚠️ 创建+删除+分发 | App缺少编辑和统计 |
| 账单报表 | ✅ ECharts图表+账单明细 | ✅ 收入趋势图 | 基本对齐 |
| 用户管理 | ✅ 完整CRUD+角色选择+酒店绑定 | ⚠️ 基础CRUD | App缺少角色更新和启禁用 |

### 2.3 前台员工 (Reception)

| 功能 | Web端 | App端 | 差异说明 |
|------|-------|-------|---------|
| 前台总览 | ✅ 今日入住/退房/可用房间/工单/时间线/住客表 | ✅ 统计卡片+到达列表 | 基本对齐 |
| 接待中心 | ✅ 入住(房间网格/同行人/优惠券/发房卡)+退房(批量) | ⚠️ 基础入住退房 | **App缺少房卡操作、优惠券发放、同行人管理** |
| 设备管理 | ✅ 已审核设备列表+通信测试 | ✅ 设备控制 | 功能侧重不同 |
| 预订管理 | ✅ 搜索/创建/确认/取消/退房 | ✅ 基础预订管理 | 基本对齐 |
| 客房余量 | ✅ 双视图(网格+表格)+房间详情抽屉 | ✅ 房态看板+饼图 | 基本对齐 |
| 工单处理 | ✅ 维修+保洁双Tab/创建/分配/完成 | ⚠️ 维修+保洁/创建/状态更新 | App缺少工单分配功能 |
| 客房送物 | ✅ 创建/配送/完成/取消 | ✅ 创建/状态更新 | 基本对齐 |
| 语音通话 | ✅ WebSocket+WebRTC/在线状态/呼叫/来电/通话计时 | ⚠️ WebRTC基础通话 | **App通话历史不持久化、缺少统计** |
| 环境监测 | ✅ 实时数据+自动刷新+楼层筛选 | ✅ 复用管理端页面 | 已对齐 |
| 价格日历 | ✅ 共享管理端组件 | ✅ 复用管理端页面 | 已对齐 |
| 优惠券管理 | ✅ 共享管理端组件 | ✅ 复用管理端页面 | 已对齐 |
| 账单报表 | ✅ 统计+列表+详情抽屉+收款 | ⚠️ 统计+列表 | App缺少账单详情和收款操作 |

### 2.4 顾客端 (Guest)

| 功能 | Web端 | App端 | 差异说明 |
|------|-------|-------|---------|
| 客房预订 | ✅ 5步OTA式流程/支付/优惠券/积分 | ✅ 完整预订流程 | 基本对齐 |
| 在线入住 | ✅ 4步流程 | ✅ 4步流程 | 已对齐 |
| 客房服务 | ✅ AI管家+送物+联系前台+更多服务 | ✅ AI管家+设备控制+送物+联系前台+更多 | App更丰富(含设备控制) |
| 我的订单 | ✅ 订单列表+操作 | ✅ 4Tab订单列表 | 基本对齐 |
| 个人中心 | ✅ 会员卡+资产+优惠券+钱包+常旅客+账号管理 | ✅ 会员+钱包+优惠券+常旅客 | App拆分更细 |
| AI管家(全屏) | ✅ WebRTC语音+语音输入+AI播放 | ⚠️ 仅在客房服务Tab中 | App缺少独立全屏AI管家页面 |

---

## 3. App端功能实现完整性分析

### 3.1 各页面完成度评估

#### 认证模块

| 页面 | 完成度 | 缺失功能 |
|------|--------|---------|
| login_page.dart | 75% | 验证码登录、忘记密码(按钮存在但无功能)、未使用的控制器 |
| register_page.dart | 70% | 手机验证码验证、服务协议确认 |

#### 系统管理模块

| 页面 | 完成度 | 缺失功能 |
|------|--------|---------|
| dashboard_page.dart | 65% | 趋势图表、数据导出、统计卡片点击无响应 |
| system_settings_page.dart | 15% | **全部硬编码模拟数据**，未对接任何后端API |

#### 酒店管理模块

| 页面 | 完成度 | 缺失功能 |
|------|--------|---------|
| dashboard_page.dart | 85% | - |
| device_monitor_page.dart | 40% | **使用了错误API**、缺少审核和指令功能 |
| environment_monitor_page.dart | 65% | 缺少设备管理Tab和能耗统计Tab |
| hotel_edit_page.dart | 55% | 图片上传为占位符、DropdownButton Bug |
| coupon_manage_page.dart | 70% | 缺少编辑和统计、DropdownButton Bug |
| price_calendar_page.dart | 70% | 缺少价格方案和会员折扣、DropdownButton Bug |
| reports_page.dart | 70% | 缺少自定义日期范围、导出 |
| room_manage_page.dart | 70% | DropdownButton Bug |
| room_type_manage_page.dart | 85% | - |
| floor_manage_page.dart | 85% | - |
| user_manage_page.dart | 60% | 缺少角色更新、启禁用、DropdownButton Bug |

#### 前台模块

| 页面 | 完成度 | 缺失功能 |
|------|--------|---------|
| dashboard_page.dart | 80% | - |
| bills_page.dart | 65% | 缺少账单详情、收款操作 |
| delivery_orders_page.dart | 70% | DropdownButton Bug |
| device_management_page.dart | 75% | - |
| room_availability_page.dart | 80% | - |
| work_orders_page.dart | 65% | 缺少工单分配、DropdownButton Bug |
| voice_calls_page.dart | 70% | 通话历史不持久化、缺少统计 |

#### 顾客模块

| 页面 | 完成度 | 缺失功能 |
|------|--------|---------|
| home_page.dart | 55% | 硬编码图片/评分/城市、"联系客服"/"使用帮助"占位符 |
| hotel_list_page.dart | 50% | 筛选栏纯UI、地图按钮无功能、硬编码日期/评分 |
| hotel_detail_page.dart | 65% | 分享按钮无功能、收藏仅本地、硬编码评分 |
| booking_flow_page.dart | 85% | "保存到常用入住人"无功能 |
| order_list_page.dart | 70% | 排序按钮纯UI、重复请求问题 |
| order_detail_page.dart | 60% | **取消订单未调用API**、**入住跳转错误** |
| favorites_page.dart | 50% | 仅本地存储、无后端同步 |
| online_checkin_page.dart | 75% | DropdownButton Bug |
| notification_center_page.dart | 40% | **MessageService.getUnreadCount()返回硬编码0** |
| coupon_center_page.dart | 65% | "去使用"仅提示不跳转 |
| wallet_page.dart | 55% | 二维码支付为模拟、缺少交易明细 |
| member_page.dart | 80% | - |
| room_service_page.dart | 70% | 更多服务6项为占位符、文字消息回复硬编码 |
| profile_page.dart | 55% | "在线客服"无功能、订单快捷入口无响应、硬编码数字 |
| personal_info_page.dart | 65% | **绕过Service层直接用DioClient**、DropdownButton Bug |
| frequent_guest_page.dart | 75% | DropdownButton Bug |
| checkout_page.dart | 90% | - |
| extend_stay_page.dart | 80% | 续住费用为前端简单计算 |
| review_submit_page.dart | 85% | 图片串行上传 |

### 3.2 完成度分布图

```
90%+ ████████████████████ checkout_page.dart
85%+ ██████████████████ dashboard(admin), room_type, floor, booking_flow, review_submit
80%+ █████████████████ dashboard(reception), room_availability, member, extend_stay, main_shell
75%+ ████████████████ login, online_checkin, device_management, frequent_guest
70%+ ███████████████ register, coupon_manage, price_calendar, reports, room_manage, delivery, voice_calls, order_list
65%+ ██████████████ dashboard(system), environment_monitor, hotel_detail, bills, work_orders, personal_info, coupon_center
60%+ █████████████ user_manage, order_detail
55%+ ████████████ home_page, hotel_edit, wallet, profile_page, favorites
50%+ ██████████ hotel_list_page
40%+ ████████ device_monitor, notification_center
15%+ ███ system_settings_page
```

---

## 4. App端代码质量问题清单

### 4.1 🔴 严重Bug (影响功能正确性)

| # | Bug | 影响文件 | 说明 |
|---|-----|---------|------|
| B1 | **DropdownButtonFormField.initialValue** | 9+个文件 | Flutter中不存在`initialValue`属性，应为`value`。导致下拉框初始值不生效，影响所有表单的选择功能 |
| B2 | **MessageService.getUnreadCount()返回硬编码0** | message_service.dart | API实现被注释掉，消息未读数永远为0 |
| B3 | **OrderDetailPage._handleCancel()未调用API** | order_detail_page.dart | 用户点击取消订单但订单不会被真正取消 |
| B4 | **OrderDetailPage._handleCheckIn()跳转错误** | order_detail_page.dart | 应跳转/online-checkin但跳转了/room-service |
| B5 | **device_monitor_page使用错误API** | device_monitor_page.dart | 管理端使用了getMyRoomDevices(顾客端接口)而非getAllDevices |

**DropdownButtonFormField.initialValue 影响的完整文件列表:**
1. `coupon_manage_page.dart`
2. `hotel_edit_page.dart`
3. `price_calendar_page.dart`
4. `delivery_orders_page.dart`
5. `user_manage_page.dart`
6. `room_manage_page.dart`
7. `work_orders_page.dart`
8. `online_checkin_page.dart`
9. `frequent_guest_page.dart`
10. `personal_info_page.dart`

### 4.2 🟡 架构问题

| # | 问题 | 说明 |
|---|------|------|
| A1 | personal_info_page绕过Service层 | 直接使用DioClient调用API，违反分层架构 |
| A2 | VoiceCallService使用单例而非Provider | 不符合Riverpod依赖注入模式 |
| A3 | authStateNotifier全局实例 | 不通过Provider管理，不符合Riverpod最佳实践 |
| A4 | 收藏功能仅本地存储 | 无后端API同步，跨设备不同步 |
| A5 | API响应格式不一致 | 多个页面需要大量字段名规范化代码 |

### 4.3 🟡 硬编码问题

| # | 硬编码内容 | 出现位置 |
|---|-----------|---------|
| H1 | Unsplash图片URL | home_page, hotel_list_page, hotel_detail_page, booking_flow_page, order_list_page, favorites_page |
| H2 | 评分"4.8" | home_page, hotel_list_page, hotel_detail_page |
| H3 | 城市"珠海"/城市列表 | home_page, hotel_list_page |
| H4 | 日期"04.08 - 04.09" | hotel_list_page |
| H5 | "我看过的 19" | profile_page |
| H6 | 配送商品目录(8项) | DeliveryService.deliveryItemCatalog |
| H7 | 服务器IP地址 | api_constants.dart |

### 4.4 🟢 占位符/未实现功能

| # | 功能 | 位置 | 状态 |
|---|------|------|------|
| P1 | 联系客服 | home_page, profile_page | "功能即将上线" |
| P2 | 使用帮助 | home_page | "功能即将上线" |
| P3 | 图片上传 | hotel_edit_page | 占位符 |
| P4 | 系统设置 | system_settings_page | 全部模拟数据 |
| P5 | 筛选栏 | hotel_list_page | 纯UI |
| P6 | 地图功能 | hotel_list_page | 按钮无功能 |
| P7 | 分享功能 | hotel_detail_page | 按钮无功能 |
| P8 | 更多服务(6项) | room_service_page | 仅SnackBar |
| P9 | 订单快捷入口 | profile_page | 点击无响应 |
| P10 | 文字消息回复 | room_service_page | 硬编码模拟 |

---

## 5. 后端API问题与安全风险

### 5.1 🔴 严重安全问题

| # | 问题 | 端点 | 风险等级 |
|---|------|------|---------|
| S1 | **重置密码无身份验证** | `POST /auth/reset-password` | 🔴 极高 - 任何人可重置他人密码 |
| S2 | **住客模块完全无认证** | `/api/v1/guests` 全部端点 | 🔴 极高 - 住客信息完全暴露 |
| S3 | **任意DDL执行** | `POST /members/fix-schema` | 🔴 极高 - 可修改数据库结构 |
| S4 | **预订查询无认证** | `GET /bookings/lookup` | 🟠 高 - 可查询他人预订信息 |
| S5 | **在线入住无认证** | `POST /bookings/checkin-online/:id` | 🟠 高 - 可替他人办理入住 |
| S6 | **角色申请审核无权限校验** | `PUT /auth/role-applications/:id/review` | 🟠 高 - 任何用户可审核申请 |

### 5.2 🟡 验证缺失问题

| # | 问题 | 端点 |
|---|------|------|
| V1 | express-validator形同虚设 | `/ai-butler/*` (未调用validationResult) |
| V2 | 创建接口缺少必填字段校验 | coupons.create, maintenance.create, payments.create, reviews.create |
| V3 | 预订状态无白名单校验 | `PATCH /bookings/:id/status` |
| V4 | 验证码仅为模拟 | `POST /users/send-code` |

### 5.3 🟡 设计一致性问题

| # | 问题 | 说明 |
|---|------|------|
| D1 | 响应格式不统一 | RoomTypeController用`{code,message,data}`，其他用`successResponse()` |
| D2 | 认证方式不统一 | auth路由手动解析JWT，其他用authenticate中间件 |
| D3 | 路由别名冗余 | checkin-online两个路径指向同一方法 |
| D4 | 生产环境残留测试端点 | `POST /bookings/test` |
| D5 | 环境监控全部Mock数据 | Environment模块10个端点均返回硬编码数据 |

---

## 6. Service层未使用API方法统计

> App端Service层中已定义但从未被任何页面调用的API方法，共35+个

| Service | 未使用方法 | 对应后端端点 | 建议用途 |
|---------|-----------|-------------|---------|
| **AuthService** | getMe, refreshCurrentUser, getUserRole | GET /auth/me | 启动时恢复登录态 |
| **BookingService** | confirmBooking | PUT /bookings/:id/confirm | 前台确认预订 |
| **PaymentService** | getPaymentStatus, refundPayment | GET /payments/:id | 支付状态查询、退款 |
| **CouponService** | receiveCoupon, redeemCouponByImport, updateCoupon, getCouponStats | POST /coupons/:id/receive, PUT /coupons/:id | 领券中心、编辑优惠券、统计 |
| **ReviewService** | getMyReviews, getReviewStats | GET /reviews | 我的评价、评价统计 |
| **DeliveryService** | updateDeliveryStatus, getDeliveryItems | PUT /delivery/:id/status | 配送状态更新、商品目录 |
| **EnvironmentService** | getEnvironmentData, getEnvironmentHistory, getEnergyConsumption | GET /environment, /environment/history, /environment/energy | 环境详情、历史趋势、能耗 |
| **MaintenanceService** | getWorkOrderById, deleteWorkOrder | GET /maintenance/:id, DELETE /maintenance/:id | 工单详情、删除工单 |
| **MessageService** | getMessagesByRoom, sendMessage | GET /messages/room | 按房间查消息、发送消息 |
| **PriceCalendarService** | deletePriceForDate, getMemberDiscounts | DELETE /price-calendar, GET /members/discounts | 删除价格、会员折扣 |
| **RoomTypeService** | getRoomTypeById | GET /room-types/:id | 单个房型查询 |
| **UploadService** | uploadImage, uploadImages, deleteImage | POST /upload/image | **全部未使用**(图片上传) |
| **UserService** | getUserById, updateUserRole, disableUser, enableUser | GET/PUT /users/:id | 用户详情、角色管理、启禁用 |
| **CallApiService** | getStatus, getActive, getHistory, getStats | GET /calls/* | 通话状态、历史、统计 |

---

## 7. 开发优先级与任务规划

### P0 - 紧急修复 (影响功能正确性)

| # | 任务 | 类型 | 预估影响 |
|---|------|------|---------|
| P0-1 | **修复DropdownButtonFormField.initialValue Bug** | Bug修复 | 9+个文件，所有表单下拉框初始值不生效 |
| P0-2 | **修复MessageService.getUnreadCount()硬编码** | Bug修复 | 消息未读数永远为0 |
| P0-3 | **修复OrderDetailPage取消订单未调用API** | Bug修复 | 用户取消订单无效 |
| P0-4 | **修复OrderDetailPage入住跳转错误** | Bug修复 | 入住跳转到错误页面 |
| P0-5 | **修复device_monitor_page使用错误API** | Bug修复 | 管理端看不到所有设备 |

### P1 - 功能补全 (Web端有但App端缺失或不完整)

| # | 任务 | 类型 | 预估工作量 |
|---|------|------|-----------|
| P1-1 | **创建系统管理员酒店管理页面** | 新页面 | Web端有完整CRUD参考 |
| P1-2 | **创建系统管理员全局设备管理页面** | 新页面 | Web端有搜索/筛选/详情参考 |
| P1-3 | **对接system_settings_page到后端API** | 功能完善 | 替换全部硬编码数据 |
| P1-4 | **完善管理端设备监控(审核+指令)** | 功能完善 | 使用正确API，添加审核和指令功能 |
| P1-5 | **完善环境监测(设备管理+能耗统计Tab)** | 功能完善 | 使用EnvironmentService未用方法 |
| P1-6 | **完善前台接待中心(房卡+优惠券发放+同行人)** | 功能完善 | 参考Web端CheckInOut.vue |
| P1-7 | **对接图片上传功能** | 功能完善 | UploadService全部未使用 |
| P1-8 | **完善优惠券管理(编辑+统计)** | 功能完善 | 使用updateCoupon和getCouponStats |

### P2 - 体验优化 (提升用户体验和代码质量)

| # | 任务 | 类型 | 预估工作量 |
|---|------|------|-----------|
| P2-1 | **消除硬编码数据** | 代码优化 | 评分/城市/日期/图片等使用API数据 |
| P2-2 | **完善酒店列表筛选功能** | 功能完善 | 筛选栏从纯UI变为可用 |
| P2-3 | **完善个人中心功能** | 功能完善 | 在线客服、订单快捷入口 |
| P2-4 | **完善钱包功能** | 功能完善 | 交易明细、真实支付对接 |
| P2-5 | **完善语音通话** | 功能完善 | 通话历史持久化、统计 |
| P2-6 | **重构personal_info_page** | 架构优化 | 从DioClient迁移到Service层 |
| P2-7 | **重构VoiceCallService** | 架构优化 | 从单例迁移到Riverpod Provider |
| P2-8 | **收藏功能后端同步** | 功能完善 | 添加收藏API |
| P2-9 | **完善更多服务** | 功能完善 | 6项占位符功能实现 |
| P2-10 | **续住费用使用calculatePrice API** | 功能完善 | 替换前端简单计算 |

### P3 - 后端安全加固 (需协调后端开发)

| # | 任务 | 类型 | 严重程度 |
|---|------|------|---------|
| P3-1 | **重置密码添加身份验证** | 安全修复 | 🔴 极高 |
| P3-2 | **住客模块添加认证中间件** | 安全修复 | 🔴 极高 |
| P3-3 | **移除fix-schema端点** | 安全修复 | 🔴 极高 |
| P3-4 | **预订查询添加认证** | 安全修复 | 🟠 高 |
| P3-5 | **在线入住添加认证** | 安全修复 | 🟠 高 |
| P3-6 | **角色申请审核添加权限校验** | 安全修复 | 🟠 高 |
| P3-7 | **统一响应格式** | 代码规范 | 🟡 中 |
| P3-8 | **移除测试端点** | 代码规范 | 🟡 中 |
| P3-9 | **环境监控对接真实数据** | 功能完善 | 🟡 中 |

---

## 附录A: 技术栈对比

| 维度 | Web端 | App端 |
|------|-------|-------|
| 框架 | Vue 3 + Composition API | Flutter 3.x + Dart |
| UI库 | Ant Design Vue | Material Design 3 |
| 状态管理 | Pinia (3个Store) | Riverpod (20+个Provider) |
| 路由 | Vue Router (角色守卫) | GoRouter (认证守卫) |
| HTTP | Axios (Token拦截器) | Dio (AuthInterceptor) |
| 实时通信 | Socket.IO + WebRTC | WebRTC (手动信令) |
| 图表 | ECharts | fl_chart |
| 日期处理 | dayjs | intl |
| 本地存储 | localStorage | SharedPreferences |

## 附录B: Web端功能完整清单 (供参考)

### 系统管理员 (5页)
1. 集团运营总览 - ECharts(营收趋势/酒店排名/房间分布/预订分布)
2. 酒店管理 - CRUD(名称/编码/城市/地址/电话/星级/Logo/描述)
3. 全局设备管理 - 搜索/筛选/详情/删除
4. 账户管理 - 分页/搜索/筛选/CRUD/角色/酒店绑定
5. 系统配置 - system-config API读写

### 酒店管理员 (11页)
1. 总览仪表盘 - 设备在线率/房间状态
2. 设备监控 - 双Tab(活跃+待审核)/审核/指令
3. 环境监测 - 6个子Tab(总览/环境数据/消防/设备/能耗/事件)
4. 房间管理 - 楼层分组/CRUD/图片上传
5. 房型管理 - CRUD/图片上传
6. 楼层管理 - CRUD/平面图上传
7. 酒店信息编辑 - 完整表单
8. 价格日历 - 日历+方案+折扣
9. 优惠券管理 - CRUD+发放+核销
10. 账单报表 - ECharts+明细
11. 用户管理 - 共享系统管理员组件

### 前台员工 (12页)
1. 前台总览 - 统计/时间线/待办
2. 接待中心 - 入住(房间网格/同行人/优惠券/房卡)+退房(批量)
3. 设备管理 - 已审核设备+通信测试
4. 预订管理 - 搜索/创建/确认/取消
5. 客房余量 - 双视图+详情抽屉
6. 工单处理 - 维修+保洁/创建/分配/完成
7. 客房送物 - 创建/配送/完成/取消
8. 语音通话 - WebSocket+WebRTC/在线状态/呼叫/来电
9. 环境监测 - 实时数据+自动刷新
10. 账单报表 - 统计+详情+收款
11. 价格日历 - 共享管理端
12. 优惠券管理 - 共享管理端

### 顾客 (5+1页)
1. 客房预订 - 5步OTA流程/支付/优惠券/积分
2. 在线入住 - 4步流程
3. 客房服务 - AI管家+送物+前台+更多
4. 我的订单 - 列表+操作
5. 个人中心 - 会员卡+资产+优惠券+钱包+常旅客+账号
6. AI管家(全屏) - WebRTC+语音输入+AI播放

## 附录C: 后端API端点统计

| 模块 | 端点数 | 有认证 | 无认证 | 有验证 | Mock数据 |
|------|--------|--------|--------|--------|----------|
| Auth | 10 | 4 | 6 | 5 | 0 |
| Bookings | 16 | 13 | 3 | 8 | 0 |
| Calls | 9 | 9 | 0 | 4 | 0 |
| Coupons | 11 | 11 | 0 | 4 | 0 |
| Delivery | 5 | 5 | 0 | 2 | 0 |
| Devices | 7 | 6 | 1 | 3 | 0 |
| Environment | 10 | 10 | 0 | 0 | **10** |
| Floors | 5 | 5 | 0 | 0 | 0 |
| Frequent Guests | 4 | 4 | 0 | 2 | 0 |
| Guests | 6 | 0 | **6** | 2 | 0 |
| Hotel | 6 | 6 | 0 | 0 | 0 |
| Hotels | 3 | 1 | 2 | 1 | 0 |
| Maintenance | 6 | 6 | 0 | 1 | 0 |
| Members | 12 | 10 | 2 | 4 | 0 |
| Payments | 5 | 5 | 0 | 0 | 0 |
| Price Calendar | 2 | 2 | 0 | 2 | 0 |
| Rate Plans | 4 | 4 | 0 | 2 | 0 |
| Reviews | 3 | 1 | 2 | 0 | 0 |
| Room Types | 5 | 5 | 0 | 0 | 0 |
| Rooms | 9 | 9 | 0 | 1 | 0 |
| System Config | 3 | 1 | 2 | 0 | 0 |
| Upload | 1 | 1 | 0 | 1 | 0 |
| Users | 7 | 5 | 2 | 3 | 0 |
| AI Butler | 3 | 3 | 0 | 0 | 0 |
| **合计** | **153** | **121** | **32** | **42** | **10** |

> 无认证端点占比: 20.9%，存在较大安全风险
> 有验证端点占比: 27.5%，验证覆盖率过低
> Mock数据端点: Environment模块全部10个端点

---

*报告结束 - 建议按P0→P1→P2→P3优先级顺序推进开发*
