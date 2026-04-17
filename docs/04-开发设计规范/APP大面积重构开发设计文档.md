# 智联酒店APP大面积重构开发设计文档

> 文档版本：v1.0  
> 编制日期：2026-04-13  
> 编制依据：全栈代码质量分析报告 + Web/App/后端/数据库四端全量对比测试  
> 重构范围：mobile/iot_hotel_app 全部代码

---

## 目录

- [一、重构背景与目标](#一重构背景与目标)
- [二、五端全量功能对比矩阵](#二五端全量功能对比矩阵)
  - [2.1 顾客端功能对比（重点）](#21-顾客端功能对比重点)
  - [2.2 系统管理员端功能对比](#22-系统管理员端功能对比)
  - [2.3 酒店管理员端功能对比](#23-酒店管理员端功能对比)
  - [2.4 前台员工端功能对比](#24-前台员工端功能对比)
- [三、数据库字段冗余与不一致问题](#三数据库字段冗余与不一致问题)
- [四、接口字段名不一致问题](#四接口字段名不一致问题)
- [五、APP端设计缺陷详细分析](#五app端设计缺陷详细分析)
  - [5.1 顾客端缺陷](#51-顾客端缺陷)
  - [5.2 管理端缺陷](#52-管理端缺陷)
  - [5.3 架构级缺陷](#53-架构级缺陷)
- [六、重构架构设计](#六重构架构设计)
- [七、数据模型层重构](#七数据模型层重构)
- [八、服务层重构](#八服务层重构)
- [九、页面层重构](#九页面层重构)
- [十、重构实施路线图](#十重构实施路线图)

---

## 一、重构背景与目标

### 1.1 背景

经过对Web端、App端、后端API、数据库四端的全面对比测试，发现APP端存在以下系统性问题：

1. **数据模型层严重缺失**：APP端大量使用 `Map<String, dynamic>` 代替强类型Model，导致字段名拼写错误无法在编译期发现
2. **接口字段名不一致**：后端API返回的字段名在不同接口间不统一（如 `check_in` vs `check_in_date`），APP端被迫在每个页面做字段兼容转换
3. **收藏功能本地存储**：酒店收藏使用 SharedPreferences 本地存储，无法跨设备同步
4. **页面职责混乱**：部分页面承担了过多逻辑（如 `room_service_page.dart` 包含5个Tab的完整实现），单文件超过500行
5. **状态管理不统一**：部分使用 Riverpod Provider，部分使用 setState + FutureBuilder，数据流混乱
6. **MQTT连接管理缺陷**：MQTT连接生命周期管理不完善，切换用户时可能残留连接
7. **错误处理不统一**：各页面自行处理错误，无统一的错误展示和重试机制

### 1.2 重构目标

| 目标 | 描述 | 优先级 |
|------|------|--------|
| 数据安全 | 消除所有 `Map<String, dynamic>` 使用，全部替换为强类型Model | P0 |
| 接口一致 | 统一后端API字段命名，消除前端兼容转换代码 | P0 |
| 功能对齐 | App端顾客功能与Web端完全对齐，补齐缺失功能 | P0 |
| 架构清晰 | 分层架构（Model → Service → ViewModel → Page），职责明确 | P1 |
| 状态统一 | 全部使用 Riverpod + AsyncNotifier 管理状态 | P1 |
| 体验优化 | 统一错误处理、加载状态、空状态展示 | P1 |
| 收藏云端化 | 收藏数据迁移至后端API，支持跨设备同步 | P2 |
| 性能优化 | 减少冗余API调用，优化列表加载和图片缓存 | P2 |

---

## 二、五端全量功能对比矩阵

### 2.1 顾客端功能对比（重点）

| 功能模块 | Web端 | App端 | 差异说明 | 重构优先级 |
|----------|-------|-------|----------|-----------|
| **酒店搜索/列表** | Booking.vue 多步骤OTA式搜索 | hotel_list_page.dart 城市筛选+搜索 | Web端搜索更丰富（目的地/日期/人数），App端日期固定为今天/明天 | P0 |
| **酒店详情** | Booking.vue 内嵌 | hotel_detail_page.dart 独立页面 | App端有评价列表、收藏功能；Web端内嵌在预订流程中 | P1 |
| **房型余量查询** | Booking.vue Step 1 | hotel_detail_page.dart | App端独立查询，Web端集成在搜索中 | P1 |
| **预订流程** | Booking.vue 多步骤（搜索→选房→确认） | booking_flow_page.dart | App端有优惠券选择、积分抵扣、房间选择器；Web端更简洁 | P1 |
| **订单列表** | MyOrders.vue | order_list_page.dart | Web端状态更全（6种），App端仅4种Tab（缺少已入住、已取消独立Tab） | P0 |
| **订单详情** | MyOrders.vue 内嵌 | order_detail_page.dart 独立页面 | App端有独立详情页，Web端在列表中展示 | P1 |
| **在线入住** | OnlineCheckIn.vue | online_checkin_page.dart | 功能基本一致，但App端字段兼容代码多 | P1 |
| **AI管家** | AIButler.vue + GuestRoom.vue内嵌 | room_service_page.dart Tab | Web端有语音输入、打字机效果、转接前台动画；App端功能简化 | P0 |
| **设备控制** | GuestRoom.vue 无独立Tab | room_service_page.dart Tab | App端有独立设备控制Tab；Web端集成在AI管家中 | P1 |
| **客房送物** | GuestRoom.vue Tab | room_service_page.dart Tab | 功能一致 | - |
| **联系前台** | GuestRoom.vue Tab | room_service_page.dart Tab | Web端有常用服务热线列表；App端简化 | P2 |
| **更多服务** | GuestRoom.vue Tab | room_service_page.dart Tab | Web端有保洁、维修、续住等服务入口 | P2 |
| **自助退房** | ❌ 无 | checkout_page.dart | App端独有，含发票信息 | P1 |
| **续住申请** | MyOrders.vue 续住按钮 | extend_stay_page.dart | Web端和App端均已实现，含优惠券/积分抵扣/支付 | P1 |
| **评价提交** | ❌ 无独立页面 | review_submit_page.dart | App端独有，含多维度评分+图片上传 | P0 |
| **会员中心** | Profile.vue 内嵌 | member_page.dart 独立页面 | 功能基本一致 | P1 |
| **钱包/充值** | ❌ 无 | wallet_page.dart | App端独有 | P2 |
| **优惠券中心** | Profile.vue 内嵌 | coupon_center_page.dart 独立页面 | App端有兑换码功能 | P1 |
| **通知中心** | ❌ 无 | notification_center_page.dart | App端独有 | P1 |
| **收藏酒店** | ❌ 无 | favorites_page.dart | App端独有，但使用本地存储（⚠️缺陷） | P0 |
| **常旅客管理** | Profile.vue 内嵌 | frequent_guest_page.dart 独立页面 | 功能基本一致 | P2 |
| **个人信息编辑** | Profile.vue 内嵌 | personal_info_page.dart 独立页面 | App端有角色申请/酒店绑定功能 | P1 |
| **模式切换** | ❌ 无（路由级隔离） | profile_page.dart 内嵌 | App端独有，允许同一账号切换不同角色视图 | P1 |
| **首页** | ❌ 无（直接进入Booking） | home_page.dart | App端有独立首页，含会员等级、快捷入口 | P1 |

### 2.2 系统管理员端功能对比

| 功能模块 | Web端 | App端 | 差异说明 | 重构优先级 | 实现状态 |
|----------|-------|-------|----------|-----------|---------|
| **集团总览** | GlobalDashboard.vue（ECharts图表） | _OverviewTab（fl_chart图表） | Web端有营收趋势图、酒店排行、房态饼图；App端已实现营收趋势折线图、预订概况柱状图、设备在线率饼图、酒店排行 | P1 | ✅ 已实现 |
| **酒店管理** | HotelManagement.vue（完整CRUD） | _HotelsTab（完整CRUD） | Web端有Logo上传、星级选择、城市筛选；App端已实现创建/编辑/删除酒店、星级下拉选择、城市筛选、搜索 | P1 | ✅ 已实现 |
| **全局设备** | SystemDeviceManagement.vue | _DevicesTab（增强版） | Web端有设备分类管理；App端已实现设备状态/类型筛选、搜索、在线/离线统计 | P2 | ✅ 已实现 |
| **账户管理** | UserManagement.vue（完整CRUD+角色筛选） | _UsersTab（增强版） | Web端有角色筛选、酒店绑定；App端已实现角色筛选、用户编辑、角色修改、启用/禁用 | P1 | ✅ 已实现 |
| **酒店审核** | ❌ 无 | _ReviewTab（增强版） | App端独有审核功能，已实现详情展示、批量操作、审核备注 | P1 | ✅ 已实现 |
| **系统配置** | SystemSettings.vue | SystemSettingsPage | 功能基本一致 | P2 | ✅ 已有 |

### 2.3 酒店管理员端功能对比

| 功能模块 | Web端 | App端 | 差异说明 | 重构优先级 | 实现状态 |
|----------|-------|-------|----------|-----------|---------|
| **总览仪表盘** | Dashboard.vue（ECharts设备饼图） | _DashboardContent（fl_chart增强版） | Web端有设备在线饼图+房间状态表；App端已实现营收趋势图、房间状态饼图、设备在线饼图、今日动态列表 | P1 | ✅ 已实现 |
| **导航栏优化** | - | 4项分组导航 | 原来11项底部导航改为3+1分组（总览/设备/房间+更多弹窗） | P1 | ✅ 已实现 |
| **设备监控** | DeviceMonitor.vue（独立页面） | DeviceMonitorPage | 功能基本一致 | P2 | ✅ 已有 |
| **环境监测** | EnvironmentMonitor.vue | EnvironmentMonitorPage | 功能基本一致 | P2 | ✅ 已有 |
| **房间管理** | RoomEdit.vue | RoomManagePage | Web端有独立编辑页面；App端集成在列表中 | P1 | ✅ 已有 |
| **房型维护** | RoomTypeManage.vue | RoomTypeManagePage | App端已有独立房型管理页面 | P1 | ✅ 已有 |
| **楼层管理** | FloorManage.vue | FloorManagePage | 功能基本一致 | P2 | ✅ 已有 |
| **酒店信息编辑** | HotelInfoEdit.vue | HotelEditPage | 功能基本一致 | P2 | ✅ 已有 |
| **价格日历** | PriceCalendar.vue | PriceCalendarPage | 功能基本一致 | P2 | ✅ 已有 |
| **优惠券管理** | CouponManage.vue | CouponManagePage | 功能基本一致 | P2 | ✅ 已有 |
| **账单报表** | AdminReports.vue | ReportsPage（增强版） | Web端更详细；App端已增加入住率趋势图、房型收入对比柱状图、收入构成进度条 | P1 | ✅ 已实现 |
| **用户管理** | UserManagement.vue（共享页面） | UserManagePage | 功能基本一致 | P2 | ✅ 已有 |
| **审核功能** | ❌ 无 | _AdminReviewTab | App端独有 | P1 | ✅ 已有 |

### 2.4 前台员工端功能对比

| 功能模块 | Web端 | App端 | 差异说明 | 重构优先级 |
|----------|-------|-------|----------|-----------|
| **前台总览** | Dashboard.vue | _ReceptionHomeContent | Web端有今日入住/退房时间线+在住客人表；App端有统计卡片 | P1 |
| **入住退房** | CheckInOut.vue | CheckInOutPage | 功能基本一致 | P2 |
| **预订管理** | Bookings.vue | BookingsPage | 功能基本一致 | P2 |
| **客房余量** | RoomAvailability.vue | RoomAvailabilityPage | 功能基本一致 | P2 |
| **设备管理** | DeviceManagement.vue | DeviceManagementPage | 功能基本一致 | P2 |
| **工单处理** | WorkOrders.vue | WorkOrdersPage | 功能基本一致 | P2 |
| **客房送物** | DeliveryOrders.vue | DeliveryOrdersPage | 功能基本一致 | P2 |
| **语音通话** | VoiceCalls.vue | VoiceCallsPage | 功能基本一致 | P2 |
| **环境监测** | EnvironmentMonitor.vue | EnvironmentMonitorPage（共享） | 功能基本一致 | P2 |
| **房价设置** | PriceSettings.vue | PriceSettingsPage | 功能基本一致 | P2 |
| **价格日历** | PriceCalendar.vue（共享） | PriceCalendarPage（共享） | 功能基本一致 | P2 |
| **优惠券管理** | CouponManage.vue（共享） | CouponManagePage（共享） | 功能基本一致 | P2 |
| **账单报表** | Bills.vue | BillsPage | 功能基本一致 | P2 |

---

## 三、数据库字段冗余与不一致问题

### 3.1 已验证的数据库问题

| 问题 | 数据库现状 | 影响范围 | 严重程度 |
|------|-----------|----------|---------|
| `hotel_star` vs `star_rating` | 实测：hotel_star=5, star_rating=3（数据不一致） | 后端、Web、App三端均需兼容取值 | 🔴 严重 |
| `hotel_address` vs `location` vs `city` | 实测：hotel_address为空但location有值 | 搜索、展示均受影响 | 🔴 严重 |
| `room_type` vs `room_type_id` | 实测：两者同时存在且需保持同步 | App端同时提交两个字段 | 🔴 严重 |
| `users.role` vs `user_roles` 表 | 双重角色系统，users.role为主，user_roles几乎未使用 | 角色判断逻辑混乱 | 🟡 中等 |
| `hotel_id`/`hotel_code` 冗余 | 实测：全部为NULL，从未被读取 | 无效写入 | 🟢 低 |
| `rating`/`review_count` 缓存字段 | 默认值4.50/0，与reviews表数据不同步 | 展示评分不准确 | 🟡 中等 |
| `image_url`/`promotion` | 实测：全部为NULL，promotion无代码引用 | 死字段 | 🟢 低 |

### 3.2 字段映射混乱追踪

以下是App端为兼容后端不一致字段名而编写的转换代码清单：

| 文件 | 转换代码 | 原因 |
|------|---------|------|
| `hotel_detail_page.dart:119-123` | `normalized['name'] = normalized['hotel_name']` | 酒店名称字段不统一 |
| `hotel_detail_page.dart:120` | `normalized['location'] = normalized['hotel_address']` | 地址字段不统一 |
| `hotel_detail_page.dart:122` | `normalized['star'] = normalized['hotel_star']` | 星级字段不统一 |
| `hotel_detail_page.dart:123` | `normalized['image'] = normalized['logo']` | 图片字段不统一 |
| `online_checkin_page.dart:70-71` | `booking['room_type'] = booking['room_name']` | 房型字段不统一 |
| `online_checkin_page.dart:68-69` | `booking['check_in_date'] = booking['check_in']` | 日期字段不统一 |
| `online_checkin_page.dart:72` | `booking['booking_number'] = booking['booking_no']` | 订单号字段不统一 |
| `hotel_edit_page.dart:34` | `data['hotel_address'] ?? data['address']` | 地址字段历史兼容 |
| `hotel_edit_page.dart:36` | `data['hotel_star'] ?? data['star_rating']` | 星级字段双重兼容 |
| `room_availability_page.dart:425` | `room['room_name'] ?? room['room_type']` | 房型名称兼容 |

---

## 四、接口字段名不一致问题

### 4.1 后端API字段名不一致清单

| 接口 | 字段A | 字段B | 说明 |
|------|-------|-------|------|
| `GET /hotels/:id` | `hotel_name` | `name` | 酒店详情返回`hotel_name`，搜索返回`name` |
| `GET /hotels/search` | `hotel_address` | `location` | 搜索结果用`location`，详情用`hotel_address` |
| `GET /hotels/:id` | `hotel_star` | `star` | 搜索结果用`star`，详情用`hotel_star` |
| `GET /hotels/:id` | `logo` | `image` | 详情返回`logo`，前端期望`image` |
| `GET /bookings/:id` | `check_in_date` | `check_in` | 不同接口返回不同字段名 |
| `GET /bookings/:id` | `check_out_date` | `check_out` | 不同接口返回不同字段名 |
| `GET /bookings/:id` | `booking_number` | `booking_no` | 订单号字段名不统一 |
| `GET /bookings/lookup` | `room_name` | `room_type` | 房型名称字段不统一 |
| `GET /rooms` | `room_type` (varchar) | `room_type_id` (FK) | 双重房型表达 |

### 4.2 App端因字段不一致导致的冗余代码

```dart
// hotel_detail_page.dart - 每次获取酒店详情都需要做字段归一化
if (!normalized.containsKey('name') && normalized.containsKey('hotel_name')) {
  normalized['name'] = normalized['hotel_name'];
}
if (!normalized.containsKey('location') && normalized.containsKey('hotel_address')) {
  normalized['location'] = normalized['hotel_address'];
}
if (!normalized.containsKey('star') && normalized.containsKey('hotel_star')) {
  normalized['star'] = normalized['hotel_star'];
}
if (!normalized.containsKey('image') && normalized.containsKey('logo')) {
  normalized['image'] = normalized['logo'];
}

// online_checkin_page.dart - 每次查询预订都需要做字段兼容
if (!booking.containsKey('check_in_date') && booking.containsKey('check_in')) {
  booking['check_in_date'] = booking['check_in'];
}
if (!booking.containsKey('check_out_date') && booking.containsKey('check_out')) {
  booking['check_out_date'] = booking['check_out'];
}
if (!booking.containsKey('booking_number') && booking.containsKey('booking_no')) {
  booking['booking_number'] = booking['booking_no'];
}
if (!booking.containsKey('room_type') && booking.containsKey('room_name')) {
  booking['room_type'] = booking['room_name'];
}
```

**结论**：后端API应在响应层统一字段命名，前端不应承担字段兼容责任。

---

## 五、APP端设计缺陷详细分析

### 5.1 顾客端缺陷

#### 缺陷1：收藏功能使用本地存储（P0）

**现状**：`favorites_page.dart` 和 `hotel_detail_page.dart` 使用 `SharedPreferences` 存储收藏数据

```dart
// hotel_detail_page.dart
String get _favKey {
  final userId = ref.read(authStateProvider).userId ?? 'guest';
  return '${AppConstants.favoriteHotelsKey}_$userId';
}
```

**问题**：
- 收藏数据无法跨设备同步
- 卸载App后收藏丢失
- 无法在Web端查看App端收藏
- 多设备登录时收藏不一致

**重构方案**：新增后端收藏API（`POST/GET/DELETE /api/v1/favorites`），App端调用API存储

#### 缺陷2：订单状态Tab不完整（P0）

**现状**：`order_list_page.dart` 仅有4个Tab：全部、待付款、已支付、待确认

**缺失状态**：
- 已入住（`checked_in`）— 当前入住中的订单无独立Tab
- 已取消（`cancelled`）— 取消的订单无法快速查看

**Web端**：`MyOrders.vue` 有6种状态筛选

**重构方案**：增加"已入住"和"已取消/全部历史"Tab

#### 缺陷3：AI管家功能简化（P0）

**现状**：`room_service_page.dart` 中的AI管家Tab功能简化，缺少：
- 语音输入功能
- 打字机效果
- 智能建议（suggestions）
- 转接前台动画
- 语音播放（TTS）

**Web端**：`AIButler.vue` 有完整的语音交互、打字机效果、转接动画

**重构方案**：将AI管家从 `room_service_page.dart` 中独立出来，作为独立页面，实现与Web端对齐的交互体验

#### 缺陷4：首页日期固定（P1）

**现状**：`home_page.dart` 入住日期固定为"今天"，离店日期固定为"明天"

```dart
DateTime? _checkInDate = DateTime.now();
DateTime? _checkOutDate = DateTime.now().add(const Duration(days: 1));
```

**问题**：用户无法在首页选择其他日期，必须进入酒店列表后才能修改

**重构方案**：首页搜索卡片支持日期选择器

#### 缺陷5：酒店列表日期固定（P1）

**现状**：`hotel_list_page.dart` 日期显示为硬编码 `"04.08 - 04.09"`

```dart
const Text('04.08 - 04.09', style: TextStyle(...))
```

**问题**：日期不随实际选择变化，影响房型余量查询准确性

**重构方案**：日期与搜索参数联动

#### 缺陷6：预订流程roomId传递问题（P1）

**现状**：`booking_flow_page.dart` 中，`_loadAvailableRooms()` 通过房型名称字符串匹配过滤房间

```dart
final filtered = rooms.where((r) {
  final type = r['room_name'] ?? r['room_type'] ?? '';
  return type.toString().contains(widget.roomType);
}).toList();
```

**问题**：
- 字符串包含匹配不精确（如"大床房"会匹配"豪华大床房"）
- 依赖 `room_type` 字符串而非 `room_type_id` 外键
- 后端报错"房间不存在"时无优雅降级

**重构方案**：使用 `room_type_id` 精确匹配，后端提供按房型查可用房间的专用API

#### 缺陷7：MQTT连接生命周期管理不完善（P1）

**现状**：`room_service_page.dart` 中MQTT连接管理存在以下问题：
- `didChangeDependencies` 中检测用户切换，但仅重置状态未确保旧连接完全断开
- `didChangeAppLifecycleState` 中 `resumed` 时重新检测入住状态但未重连MQTT
- 无MQTT连接状态的全局监听和自动重连机制

**重构方案**：将MQTT连接管理提升为全局Service，使用Riverpod Provider管理连接状态

### 5.2 管理端缺陷

#### 缺陷8：系统管理端缺少图表（P1）

**现状**：`system/dashboard_page.dart` 的概览Tab仅有数字统计卡片，无图表

**Web端**：`GlobalDashboard.vue` 使用ECharts展示营收趋势、房态分布、预订概况

**重构方案**：使用 `fl_chart` 或 `syncfusion_flutter_charts` 实现图表

#### 缺陷9：酒店管理端缺少独立房型管理（P1）

**现状**：App端酒店管理员没有独立的房型管理页面（`RoomTypeManage.vue` 的对应页面缺失）

**重构方案**：新增 `room_type_manage_page.dart`

#### 缺陷10：管理端导航栏项目过多（P2）

**现状**：`admin/dashboard_page.dart` 底部导航栏有11个项目，`reception/dashboard_page.dart` 有13个Tab

**问题**：
- 底部导航栏11个项目在小屏手机上显示拥挤
- 13个Tab在顶部TabBar中需要滚动，用户体验差

**重构方案**：采用分组导航（如Drawer + 底部导航栏组合），将功能按频率分组

### 5.3 架构级缺陷

#### 缺陷11：全量使用Map代替强类型Model（P0）

**现状**：App端几乎所有Service返回 `ApiResult<Map<String, dynamic>>` 或 `ApiResult<List<dynamic>>`

**问题**：
- 字段名拼写错误无法在编译期发现
- IDE无法提供自动补全
- 类型转换错误在运行时才暴露
- 代码可读性差

**影响文件**（部分）：
- `booking_service.dart` — 返回 `Map<String, dynamic>`
- `hotel_service.dart` — 返回 `Map<String, dynamic>` / `List<dynamic>`
- `member_service.dart` — 返回 `Map<String, dynamic>`
- `device_service.dart` — 返回 `List<dynamic>`
- 所有页面文件 — 使用 `order['status']`、`hotel['hotel_name']` 等动态访问

**重构方案**：为所有数据实体创建强类型Model类，使用 `json_serializable` 自动生成序列化代码

#### 缺陷12：状态管理不统一（P1）

**现状**：
- 部分页面使用 `Riverpod Provider` + `AsyncNotifier`（如 `member_page.dart`）
- 部分页面使用 `setState` + `FutureBuilder`（如 `home_page.dart`、`hotel_list_page.dart`）
- 部分页面混合使用两种方式

**问题**：
- 数据流不统一，难以追踪状态变化
- 相同数据在不同页面重复请求
- 页面间数据不同步

**重构方案**：统一使用 Riverpod AsyncNotifier 模式，将业务逻辑从Page层提取到ViewModel层

#### 缺陷13：错误处理不统一（P1）

**现状**：每个页面自行处理错误，方式不一致：
- 有的用 `ScaffoldMessenger.of(context).showSnackBar`
- 有的用 `debugPrint` 静默忽略
- 有的用 `AlertDialog` 弹窗
- 无统一的网络错误、超时、401等处理

**重构方案**：创建统一的错误处理中间件，在DioClient层拦截并统一处理常见错误

#### 缺陷14：页面文件过大（P2）

**现状**：
- `room_service_page.dart` — 包含5个Tab的完整实现，单文件超过500行
- `reception/dashboard_page.dart` — 包含13个Tab，单文件超过800行
- `admin/dashboard_page.dart` — 包含11个导航项，单文件超过600行
- `hotel_detail_page.dart` — 包含详情+评价+收藏+预订，单文件超过500行

**重构方案**：将每个Tab/子功能拆分为独立Widget文件

---

## 六、重构架构设计

### 6.1 整体分层架构

```
┌─────────────────────────────────────────────────┐
│                   Page Layer                     │
│  (纯UI层，只负责展示和用户交互)                    │
│  pages/guest/  pages/admin/  pages/reception/    │
├─────────────────────────────────────────────────┤
│                 ViewModel Layer                   │
│  (业务逻辑层，使用Riverpod AsyncNotifier)          │
│  viewmodels/guest/  viewmodels/admin/            │
├─────────────────────────────────────────────────┤
│                  Service Layer                    │
│  (API调用层，只负责网络请求和数据转换)              │
│  services/  (返回强类型Model而非Map)               │
├─────────────────────────────────────────────────┤
│                   Model Layer                     │
│  (数据模型层，使用json_serializable)               │
│  models/  (Hotel, Room, Booking, User等)         │
├─────────────────────────────────────────────────┤
│                  Core Layer                       │
│  (基础设施层)                                     │
│  core/network/  core/theme/  core/mqtt/          │
│  core/auth/  core/constants/                      │
└─────────────────────────────────────────────────┘
```

### 6.2 目录结构重构

```
lib/
├── core/
│   ├── auth/              # 认证状态管理
│   │   └── auth_state_notifier.dart
│   ├── constants/         # 常量定义
│   │   ├── api_constants.dart
│   │   └── app_constants.dart
│   ├── mqtt/              # MQTT全局服务
│   │   └── mqtt_service.dart
│   ├── network/           # 网络层
│   │   ├── dio_client.dart
│   │   ├── api_result.dart
│   │   └── api_interceptor.dart  # 新增：统一拦截器
│   └── theme/
│       └── app_colors.dart
├── models/                # 强类型数据模型（新增/重构）
│   ├── hotel.dart
│   ├── room.dart
│   ├── room_type.dart
│   ├── booking.dart
│   ├── user.dart
│   ├── member.dart
│   ├── coupon.dart
│   ├── device.dart
│   ├── review.dart
│   ├── payment.dart
│   ├── delivery_order.dart
│   ├── maintenance_ticket.dart
│   └── notification.dart
├── services/              # API服务层（重构返回类型）
│   ├── auth_service.dart
│   ├── hotel_service.dart
│   ├── booking_service.dart
│   ├── member_service.dart
│   ├── device_service.dart
│   ├── review_service.dart
│   ├── coupon_service.dart
│   ├── payment_service.dart
│   ├── delivery_service.dart
│   ├── maintenance_service.dart
│   ├── environment_service.dart
│   ├── favorite_service.dart    # 新增：云端收藏
│   ├── message_service.dart
│   └── upload_service.dart
├── viewmodels/            # ViewModel层（新增）
│   ├── guest/
│   │   ├── home_viewmodel.dart
│   │   ├── hotel_list_viewmodel.dart
│   │   ├── hotel_detail_viewmodel.dart
│   │   ├── booking_viewmodel.dart
│   │   ├── order_list_viewmodel.dart
│   │   ├── room_service_viewmodel.dart
│   │   ├── ai_butler_viewmodel.dart
│   │   └── member_viewmodel.dart
│   ├── admin/
│   │   ├── dashboard_viewmodel.dart
│   │   ├── device_viewmodel.dart
│   │   ├── room_viewmodel.dart
│   │   └── report_viewmodel.dart
│   └── reception/
│       ├── dashboard_viewmodel.dart
│       ├── checkin_viewmodel.dart
│       └── work_order_viewmodel.dart
├── pages/                 # Page层（纯UI，逻辑移至ViewModel）
│   ├── guest/
│   │   ├── home_page.dart
│   │   ├── hotel_list_page.dart
│   │   ├── hotel_detail_page.dart
│   │   ├── booking_flow_page.dart
│   │   ├── order_list_page.dart
│   │   ├── order_detail_page.dart
│   │   ├── online_checkin_page.dart
│   │   ├── room_service_page.dart
│   │   ├── ai_butler_page.dart      # 新增：独立AI管家页面
│   │   ├── device_control_page.dart  # 新增：独立设备控制页面
│   │   ├── checkout_page.dart
│   │   ├── extend_stay_page.dart
│   │   ├── review_submit_page.dart
│   │   ├── member_page.dart
│   │   ├── wallet_page.dart
│   │   ├── coupon_center_page.dart
│   │   ├── notification_center_page.dart
│   │   ├── favorites_page.dart
│   │   ├── frequent_guest_page.dart
│   │   ├── personal_info_page.dart
│   │   └── profile_page.dart
│   ├── admin/
│   │   ├── dashboard_page.dart
│   │   ├── device_monitor_page.dart
│   │   ├── room_manage_page.dart
│   │   ├── room_type_manage_page.dart  # 新增
│   │   ├── hotel_edit_page.dart
│   │   ├── environment_monitor_page.dart
│   │   ├── floor_manage_page.dart
│   │   ├── price_calendar_page.dart
│   │   ├── coupon_manage_page.dart
│   │   ├── reports_page.dart
│   │   └── user_manage_page.dart
│   ├── reception/
│   │   ├── dashboard_page.dart
│   │   ├── checkin_out_page.dart
│   │   ├── bookings_page.dart
│   │   ├── room_availability_page.dart
│   │   ├── device_management_page.dart
│   │   ├── work_orders_page.dart
│   │   ├── delivery_orders_page.dart
│   │   ├── voice_calls_page.dart
│   │   ├── bills_page.dart
│   │   └── price_settings_page.dart
│   ├── system/
│   │   ├── dashboard_page.dart
│   │   └── system_settings_page.dart
│   └── auth/
│       ├── login_page.dart
│       ├── register_page.dart
│       └── qr_scanner_page.dart
├── widgets/               # 共享组件（新增）
│   ├── loading_widget.dart
│   ├── error_widget.dart
│   ├── empty_state_widget.dart
│   ├── stat_card.dart
│   └── pull_to_refresh.dart
└── main.dart
```

---

## 七、数据模型层重构

### 7.1 Model定义规范

所有Model必须遵循以下规范：

1. 使用 `json_serializable` 自动生成 `fromJson`/`toJson`
2. 使用 `@JsonKey` 映射后端字段名（统一在Model层处理字段名差异）
3. 提供计算属性（如 `displayName`、`formattedDate`）
4. 不可变对象（使用 `const` 构造函数 + `copyWith`）

### 7.2 核心Model定义

#### Hotel Model

```dart
@immutable
@JsonSerializable()
class Hotel {
  final int id;
  
  @JsonKey(name: 'hotel_name')
  final String name;
  
  @JsonKey(name: 'hotel_address')
  final String? address;
  
  @JsonKey(name: 'hotel_star')
  final int star;
  
  @JsonKey(name: 'hotel_phone')
  final String? phone;
  
  final String? logo;
  final String? city;
  final String? description;
  final int? totalRooms;
  final double? occupancyRate;
  final double? rating;
  final int? reviewCount;
  final List<String>? images;
  final List<String>? facilities;

  const Hotel({
    required this.id,
    required this.name,
    this.address,
    this.star = 3,
    this.phone,
    this.logo,
    this.city,
    this.description,
    this.totalRooms,
    this.occupancyRate,
    this.rating,
    this.reviewCount,
    this.images,
    this.facilities,
  });

  String get displayAddress => address ?? city ?? '暂无地址';
  String get displayImage => logo ?? images?.firstOrNull ?? '';
  
  factory Hotel.fromJson(Map<String, dynamic> json) => _$HotelFromJson(json);
  Map<String, dynamic> toJson() => _$HotelToJson(this);
}
```

#### Booking Model

```dart
@immutable
@JsonSerializable()
class Booking {
  final int id;
  
  @JsonKey(name: 'booking_number')
  final String bookingNumber;
  
  final int? userId;
  final int roomId;
  final int hotelId;
  
  @JsonKey(name: 'guest_name')
  final String guestName;
  
  @JsonKey(name: 'guest_phone')
  final String guestPhone;
  
  @JsonKey(name: 'check_in_date')
  final String checkInDate;
  
  @JsonKey(name: 'check_out_date')
  final String checkOutDate;
  
  @JsonKey(name: 'guest_count')
  final int guestCount;
  
  @JsonKey(name: 'total_price')
  final double totalPrice;
  
  final String status;
  final String? roomType;
  final String? roomNumber;
  final String? hotelName;
  final int? couponId;
  final int? usedPoints;
  final String? paymentMethod;
  final String? specialRequests;
  
  const Booking({
    required this.id,
    required this.bookingNumber,
    this.userId,
    required this.roomId,
    required this.hotelId,
    required this.guestName,
    required this.guestPhone,
    required this.checkInDate,
    required this.checkOutDate,
    this.guestCount = 1,
    required this.totalPrice,
    required this.status,
    this.roomType,
    this.roomNumber,
    this.hotelName,
    this.couponId,
    this.usedPoints,
    this.paymentMethod,
    this.specialRequests,
  });

  int get nights {
    try {
      return DateTime.parse(checkOutDate)
          .difference(DateTime.parse(checkInDate))
          .inDays;
    } catch (_) {
      return 1;
    }
  }

  String get statusText {
    switch (status) {
      case 'pending': return '待付款';
      case 'confirmed': return '已支付';
      case 'pre_checked_in': return '待确认';
      case 'checked_in': return '已入住';
      case 'checked_out': return '已完成';
      case 'cancelled': return '已取消';
      default: return '未知';
    }
  }

  factory Booking.fromJson(Map<String, dynamic> json) => _$BookingFromJson(json);
  Map<String, dynamic> toJson() => _$BookingToJson(this);
}
```

### 7.3 字段映射统一策略

在Model的 `fromJson` 工厂方法中统一处理字段名差异，而非在页面层做兼容转换：

```dart
// 在Model层统一处理，而非在每个页面中重复
factory Hotel.fromJson(Map<String, dynamic> json) {
  // 统一字段名映射
  final normalized = Map<String, dynamic>.from(json);
  
  // 处理后端返回的不一致字段名
  normalized['hotel_name'] ??= normalized['name'];
  normalized['hotel_address'] ??= normalized['location'] ??= normalized['address'];
  normalized['hotel_star'] ??= normalized['star_rating'] ??= normalized['star'];
  normalized['logo'] ??= normalized['image_url'] ??= normalized['image'];
  
  return _$HotelFromJson(normalized);
}
```

---

## 八、服务层重构

### 8.1 Service返回类型规范

所有Service方法必须返回强类型Model，禁止返回 `Map<String, dynamic>`：

```dart
// ❌ 重构前
Future<ApiResult<Map<String, dynamic>>> getHotelById(int id);

// ✅ 重构后
Future<ApiResult<Hotel>> getHotelById(int id);
```

### 8.2 统一错误处理拦截器

```dart
class ApiInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        // 统一超时处理
        handler.next(DioException(
          requestOptions: err.requestOptions,
          error: '网络连接超时，请检查网络设置',
          type: err.type,
        ));
        break;
      case DioExceptionType.unauthorized:
        // 401统一跳转登录
        _navigateToLogin();
        break;
      default:
        handler.next(err);
    }
  }
}
```

### 8.3 新增收藏API服务

```dart
class FavoriteService {
  final DioClient _dioClient = DioClient();

  Future<ApiResult<List<Hotel>>> getFavorites() async {
    final response = await _dioClient.get('/favorites');
    // 解析为强类型Hotel列表
  }

  Future<ApiResult<void>> addFavorite(int hotelId) async {
    final response = await _dioClient.post('/favorites', data: {'hotel_id': hotelId});
  }

  Future<ApiResult<void>> removeFavorite(int hotelId) async {
    final response = await _dioClient.delete('/favorites/$hotelId');
  }
}
```

### 8.4 MQTT全局服务重构

```dart
@riverpod
class MqttConnection extends _$MqttConnection {
  @override
  MqttConnectionState build() => MqttConnectionState.disconnected;

  Future<void> connect() async { /* ... */ }
  void disconnect() { /* ... */ }
  void subscribe(String topic) { /* ... */ }
  void publish(String topic, String message) { /* ... */ }
}

enum MqttConnectionState { disconnected, connecting, connected, error }
```

---

## 九、页面层重构

### 9.1 顾客端页面重构要点

#### home_page.dart 重构

| 项目 | 重构前 | 重构后 |
|------|--------|--------|
| 日期选择 | 固定今天/明天 | 支持日期选择器 |
| 会员信息 | FutureBuilder内联 | HomeViewModel管理 |
| 搜索跳转 | 直接push | 通过ViewModel协调 |

#### hotel_detail_page.dart 重构

| 项目 | 重构前 | 重构后 |
|------|--------|--------|
| 字段归一化 | 页面内if/else转换 | Model.fromJson统一处理 |
| 收藏功能 | SharedPreferences | FavoriteService云端API |
| 评价列表 | 页面内管理 | HotelDetailViewModel管理 |
| 日期选择 | 无 | 支持修改入住/离店日期 |

#### order_list_page.dart 重构

| 项目 | 重构前 | 重构后 |
|------|--------|--------|
| Tab数量 | 4个（全部/待付款/已支付/待确认） | 6个（+已入住/+已取消） |
| 数据类型 | `List<dynamic>` | `List<Booking>` |
| 状态文本 | 页面内switch | Booking.statusText计算属性 |

#### room_service_page.dart 拆分

将当前5个Tab的巨型页面拆分为：

| 独立页面 | 对应Tab | 说明 |
|----------|---------|------|
| `ai_butler_page.dart` | AI管家 | 独立页面，实现语音输入、打字机效果、智能建议 |
| `device_control_page.dart` | 设备控制 | 独立页面，MQTT设备实时控制 |
| `room_service_inner_page.dart` | 客房送物 | 保留在TabBar中 |
| `front_desk_page.dart` | 联系前台 | 保留在TabBar中 |
| `more_services_page.dart` | 更多服务 | 保留在TabBar中 |

`room_service_page.dart` 改为TabBar容器，仅负责Tab切换和入住状态检测。

### 9.2 管理端页面重构要点

#### 系统管理端

| 页面 | 重构内容 |
|------|---------|
| `system/dashboard_page.dart` | 概览Tab增加fl_chart图表（营收趋势、房态分布） |
| 新增 `system/hotel_review_page.dart` | 酒店审核独立页面 |

#### 酒店管理端

| 页面 | 重构内容 |
|------|---------|
| 新增 `admin/room_type_manage_page.dart` | 房型管理独立页面（对齐Web端RoomTypeManage.vue） |
| `admin/dashboard_page.dart` | 导航栏分组：常用（总览/设备/房间）+ 更多（酒店/报表/环境/楼层/价格/优惠券/用户） |

#### 前台端

| 页面 | 重构内容 |
|------|---------|
| `reception/dashboard_page.dart` | TabBar改为Drawer+底部导航组合，减少Tab数量 |

### 9.3 共享组件提取

从各页面中提取通用组件到 `widgets/` 目录：

| 组件 | 来源页面 | 说明 |
|------|---------|------|
| `StatCard` | system/admin/reception dashboard | 统计卡片 |
| `LoadingWidget` | 所有页面 | 统一加载动画 |
| `ErrorRetryWidget` | 所有页面 | 统一错误+重试 |
| `EmptyStateWidget` | 所有列表页面 | 统一空状态 |
| `DateRangePicker` | home/hotel_list/booking | 日期范围选择 |
| `PriceTag` | hotel_detail/booking_flow | 价格展示 |
| `StatusTag` | order_list/room_availability | 状态标签 |
| `MemberCard` | profile/member | 会员卡片 |

---

## 十、重构实施路线图

### Phase 1：基础架构重构（1-2周）

| 任务 | 优先级 | 说明 |
|------|--------|------|
| 创建所有Model类 | P0 | Hotel, Booking, Room, RoomType, User, Member, Coupon, Device, Review, Payment, DeliveryOrder, MaintenanceTicket, Notification |
| 配置json_serializable | P0 | 添加依赖，配置build_runner |
| 重构DioClient | P0 | 添加统一拦截器、错误处理 |
| 重构Service返回类型 | P0 | 所有Service方法返回强类型Model |
| 删除页面层字段兼容代码 | P0 | 所有归一化逻辑移至Model.fromJson |

### Phase 2：顾客端核心功能重构（2-3周）

| 任务 | 优先级 | 说明 |
|------|--------|------|
| 新增收藏API + 重构favorites_page | P0 | 云端化收藏功能 |
| 重构order_list_page | P0 | 增加"已入住""已取消"Tab |
| 新增ai_butler_page | P0 | 独立AI管家页面，对齐Web端功能 |
| 拆分room_service_page | P1 | 拆分为5个独立页面/组件 |
| 重构home_page | P1 | 支持日期选择 |
| 重构hotel_list_page | P1 | 修复硬编码日期 |
| 重构booking_flow_page | P1 | 使用room_type_id精确匹配 |
| 新增ViewModel层 | P1 | 提取业务逻辑到ViewModel |

### Phase 3：管理端功能补齐（1-2周）

| 任务 | 优先级 | 说明 |
|------|--------|------|
| 新增room_type_manage_page | P1 | 房型管理独立页面 |
| 系统管理端增加图表 | P1 | fl_chart营收趋势、房态分布 |
| 管理端导航优化 | P2 | 分组导航，减少底部导航项 |
| 前台端导航优化 | P2 | Drawer+底部导航组合 |

### Phase 4：状态管理统一与优化（1-2周）

| 任务 | 优先级 | 说明 |
|------|--------|------|
| 统一Riverpod AsyncNotifier | P1 | 所有页面使用ViewModel模式 |
| MQTT全局服务重构 | P1 | 提升为Riverpod管理的全局Service |
| 共享组件提取 | P2 | StatCard, LoadingWidget, ErrorRetryWidget等 |
| 图片缓存优化 | P2 | cached_network_image统一管理 |
| 列表分页优化 | P2 | 统一分页加载逻辑 |

### Phase 5：后端API字段统一（需与后端协调）

| 任务 | 优先级 | 说明 |
|------|--------|------|
| 统一酒店相关字段 | P0 | name→hotel_name, location→hotel_address, star→hotel_star |
| 统一预订相关字段 | P0 | check_in→check_in_date, booking_no→booking_number |
| 统一房型字段 | P0 | 废弃room_type(varchar)，统一使用room_type_id(FK) |
| 新增收藏API | P0 | POST/GET/DELETE /api/v1/favorites |
| 清理冗余字段 | P2 | 删除hotel_id, hotel_code, promotion等死字段 |

---

## 附录A：后端API字段统一建议

### 需要后端修改的接口

| 接口 | 当前返回 | 建议统一为 | 影响端 |
|------|---------|-----------|--------|
| `GET /hotels/search` | `name`, `location`, `star` | `hotel_name`, `hotel_address`, `hotel_star` | Web, App |
| `GET /hotels/:id` | `hotel_name`, `hotel_address`, `hotel_star` | 保持不变 | Web, App |
| `GET /bookings` | `check_in`, `check_out`, `booking_no` | `check_in_date`, `check_out_date`, `booking_number` | Web, App |
| `GET /bookings/:id` | `check_in_date`, `check_out_date`, `booking_number` | 保持不变 | Web, App |
| `GET /bookings/lookup` | `check_in`, `room_name` | `check_in_date`, `room_type` | App |

### 建议新增的API

| API | 方法 | 说明 |
|-----|------|------|
| `/api/v1/favorites` | GET | 获取用户收藏列表 |
| `/api/v1/favorites` | POST | 添加收藏 `{hotel_id}` |
| `/api/v1/favorites/:hotelId` | DELETE | 取消收藏 |
| `/api/v1/rooms/available-by-type` | GET | 按房型查可用房间 `{room_type_id, check_in, check_out}` |

---

## 附录B：数据库清理建议

### 需要清理的字段

| 表 | 字段 | 操作 | 说明 |
|----|------|------|------|
| hotels | `star_rating` | 删除 | 统一使用 `hotel_star` |
| hotels | `location` | 删除 | 统一使用 `hotel_address` |
| hotels | `hotel_id` | 删除 | 从未使用 |
| hotels | `hotel_code` | 评估 | 如需编码则保留并启用，否则删除 |
| hotels | `rating` | 保留 | 但需从reviews表实时计算更新 |
| hotels | `review_count` | 保留 | 但需从reviews表实时计算更新 |
| hotels | `image_url` | 删除 | 与 `logo` 功能重叠 |
| hotels | `promotion` | 删除 | 无代码引用 |
| rooms | `room_type` | 评估 | 长期应废弃，统一使用 `room_type_id` |

### 数据修复SQL

```sql
-- 修复hotel_star和star_rating不一致
UPDATE hotels SET star_rating = hotel_star WHERE star_rating != hotel_star;

-- 修复hotel_address和location不一致
UPDATE hotels SET hotel_address = location WHERE hotel_address IS NULL AND location IS NOT NULL;

-- 修复room_type和room_type_id不一致
UPDATE rooms r 
JOIN room_types rt ON r.room_type = rt.code 
SET r.room_type_id = rt.id 
WHERE r.room_type_id IS NULL;
```

---

## 附录C：重构前后代码对比示例

### 示例1：酒店详情页字段归一化

**重构前**（hotel_detail_page.dart）：
```dart
final normalized = <String, dynamic>{};
hotelData.forEach((key, value) {
  normalized[key] = value;
});
if (!normalized.containsKey('name') && normalized.containsKey('hotel_name')) {
  normalized['name'] = normalized['hotel_name'];
}
if (!normalized.containsKey('location') && normalized.containsKey('hotel_address')) {
  normalized['location'] = normalized['hotel_address'];
}
if (!normalized.containsKey('star') && normalized.containsKey('hotel_star')) {
  normalized['star'] = normalized['hotel_star'];
}
if (!normalized.containsKey('image') && normalized.containsKey('logo')) {
  normalized['image'] = normalized['logo'];
}
```

**重构后**：
```dart
final hotel = Hotel.fromJson(response.data);
// 直接使用 hotel.name, hotel.address, hotel.star, hotel.displayImage
```

### 示例2：订单列表状态展示

**重构前**（order_list_page.dart）：
```dart
String _getStatusText(String? status) {
  switch (status?.toLowerCase()) {
    case 'pending': return '待付款';
    case 'confirmed': return '已支付';
    case 'pre_checked_in': return '待确认';
    case 'checked_in': return '已入住';
    case 'checked_out': return '已完成';
    case 'cancelled': return '已取消';
    default: return '未知状态';
  }
}
// 使用: _getStatusText(order['status']?.toString() ?? '')
```

**重构后**：
```dart
// 使用: booking.statusText
// 状态文本逻辑封装在Booking Model的计算属性中
```

### 示例3：收藏功能

**重构前**（hotel_detail_page.dart）：
```dart
String get _favKey {
  final userId = ref.read(authStateProvider).userId ?? 'guest';
  return '${AppConstants.favoriteHotelsKey}_$userId';
}

Future<List<Map<String, dynamic>>> _getFavoritesList() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_favKey) ?? '[]';
  final List<dynamic> decoded = jsonDecode(raw);
  return decoded.cast<Map<String, dynamic>>().toList();
}

void _toggleFavorite() async {
  final prefs = await SharedPreferences.getInstance();
  // ... 大量本地存储操作
}
```

**重构后**：
```dart
// 在ViewModel中
Future<void> toggleFavorite() async {
  if (isFavorited) {
    await ref.read(favoriteServiceProvider).removeFavorite(hotel.id);
  } else {
    await ref.read(favoriteServiceProvider).addFavorite(hotel.id);
  }
  isFavorited = !isFavorited;
}

// 在页面中
IconButton(
  icon: Icon(isFavorited ? Icons.favorite : Icons.favorite_border),
  onPressed: viewModel.toggleFavorite,
)
```

---

## 附录D：顾客端测试记录（2026-04-16）

### D.1 测试概览

| 测试类型 | 测试结果 | 详情 |
|---------|---------|------|
| API接口测试 | 23/23 通过 | 覆盖15个核心API |
| 端到端测试 | 通过 | 登录→浏览→预订→支付→入住→退房 |
| 数据流转测试 | 通过 | 前后端数据一致性验证 |
| 功能测试 | 10/10 模块通过 | 覆盖所有顾客端功能模块 |

### D.2 修复记录

#### 模型层修复

| 文件 | 修复内容 |
|------|---------|
| room.dart | 添加 `_toDouble()`/`_toInt()` 安全类型转换，修复 `room_price`/`hotel_id`/`floor`/`max_guests` 等字段类型不安全问题 |
| room_type.dart | 添加 `_toDouble()`/`_toInt()` 安全类型转换，添加 `normalized['id'] ??= normalized['room_type_id']` 映射，修复 `base_price`/`hotel_id`/`total_count`/`available_count` 类型问题 |
| coupon.dart | 添加 `_toDouble()` 安全类型转换，修复 `name` 字段添加 `coupon_name` 回退，`expireDate` 添加 `valid_to` 回退，`isAvailable` 状态检查添加 `unused` |
| booking.dart | 修复 `parseDate()` 处理UTC时区偏移，`DateTime.parse` 含 `T` 和 `Z` 时自动 `toLocal()` |
| review.dart | 添加 `_parseInt()` 安全类型转换，修复 `environment_rating`/`facility_rating`/`comfort_rating` 字段 |
| frequent_guest.dart | 修复 `maskedIdNumber` 的 `substring(14)` 越界崩溃 |

#### 服务层修复

| 文件 | 修复内容 |
|------|---------|
| room_service.dart | `getRooms()` 添加 `hotelId` 和 `type` 参数 |
| booking_service.dart | `calculatePrice()` 从 POST 改为 GET + queryParameters |
| hotel_service.dart | 添加 `getRoomAvailabilityRaw()` 方法返回原始 Map 数据 |
| message_service.dart | 修复 `data` 为 null 时安全访问 `['list']` |

#### 页面层修复

| 文件 | 修复内容 |
|------|---------|
| booking_flow_page.dart | 重写 `_loadAvailableRooms()`：优先 `getRoomAvailabilityRaw` + fallback `getRooms(hotelId, type)`；修复 `_calculatePrice()` 不使用 `widget.roomId`；修复 `_buildBottomPayBar()` 价格显示安全类型转换；修复提交预订添加 `user_id` |
| home_page.dart | 修复 `Expanded` 在无界高度约束中的 RenderFlex 错误，改为 `mainAxisSize: MainAxisSize.min` |
| hotel_detail_page.dart | 修复 `_reviewStats` 中 num 值传入 String 参数的类型转换 |
| hotel_reviews_page.dart | 添加 `_safeToDouble()` 辅助方法，修复 `double.tryParse()` 接收非 String 类型崩溃，修复 `_buildDimensionBar` 参数类型不匹配 |
| online_checkin_page.dart | 修复 `DropdownButtonFormField` 的 `initialValue` 改为 `value` |
| extend_stay_page.dart | 修复 `_buildPriceSummary()` 价格显示安全类型转换 |
| order_list_page.dart | 修复 `paymentId` 空指针安全，添加类型转换 |
| coupon_center_page.dart | 修复 API 路径 `/coupons/redeem` → `${ApiConstants.coupons}/redeem`；修复未使用过滤条件 `status == 'active'` → `status == 'active' || status == 'unused'`；添加 `ApiConstants` 导入 |
| frequent_guest_page.dart | 修复 `DropdownButtonFormField` 的 `initialValue` 改为 `value`（2处） |
| personal_info_page.dart | 修复 `DropdownButtonFormField` 的 `initialValue` 改为 `value`；修复 `substring(0, 10)` 可能越界（2处） |

### D.3 后端问题记录（需后端修复）

| 编号 | 严重程度 | 问题描述 | 影响 |
|------|---------|---------|------|
| BUG-07 | Critical | `GET /rooms` 的 `room_status=available` 筛选无效，返回所有状态房间 | 顾客可能预订到不可用房间 |
| BUG-14 | Critical | `POST /bookings` 创建预订后 `user_id` 为 null | 订单未关联用户，可能无法查看 |
| BUG-16 | Critical | `GET /bookings` 返回其他用户的隐私数据（手机号、身份证号） | 安全漏洞 |
| BUG-04 | High | `GET /hotels/{id}/rooms/availability` 返回 `total_price` 格式异常（"0529.00"） | 前端显示错误 |
| BUG-18 | High | 日期时区偏移，返回 `"2026-04-16T16:00:00.000Z"` 而非 `"2026-04-17"` | 显示日期偏移一天 |
| BUG-01 | Medium | 多个接口数值字段返回字符串（rating/price/balance/score等） | 前端需额外类型转换 |
| BUG-15 | Medium | 中文编码乱码，总统套房显示为"????" | 编码处理错误 |
| BUG-12 | Medium | 生产环境暴露 debug 信息 | 安全风险 |
| BUG-08 | Low | 房间关键字段为 null（bed_type/max_guests/facilities/images） | 数据不完整 |
| BUG-03 | Low | 酒店详情缺少 price/availableRooms/description 字段 | 信息不完整 |
| BUG-06 | Low | 房型图片数组为空 | 无法展示房型图片 |
| BUG-20 | Low | 评价缺少 room_type_name 字段 | 无法关联房型 |

---

## 附录E：跨平台数据流通测试记录（2026-04-16）

### E.1 测试概览

| 测试类型 | 结果 | 详情 |
|---------|------|------|
| APP端预定→Web端验证 | ✅ 通过 | 订单/金额/入住信息完全一致 |
| Web端预定→APP端查询 | ✅ 通过 | 顾客端可见管理员代客预定，入住办理成功 |
| 接口对齐检查 | ⚠️ 发现问题 | 10类接口中发现多处不一致 |
| 功能对齐检查 | ⚠️ 发现差异 | APP端缺失部分Web端功能 |

### E.2 跨平台数据一致性验证

| 数据项 | APP端→Web端 | Web端→APP端 | 一致性 |
|--------|------------|------------|--------|
| 订单ID/订单号 | 一致 | 一致 | ✅ |
| 客人姓名/手机号 | 一致 | 一致 | ✅ |
| 房间号/房型 | 一致 | 一致 | ✅ |
| 入住/退房日期 | 一致 | 一致 | ✅ |
| 总金额 | 一致 | 一致 | ✅ |
| 支付方式/状态 | 一致 | 一致 | ✅ |
| 入住办理 | 成功 | 成功 | ✅ |

### E.3 接口对齐问题汇总

#### 严重问题

| 编号 | 问题 | 影响 | 修复建议 |
|------|------|------|---------|
| H1 | 后端 `/hotels/search` 返回字段名(name/location/star/image)与数据库(hotel_name/hotel_address/hotel_star/logo)不一致 | 搜索结果字段映射混乱 | 修改后端统一字段名 |
| N1 | 后端完全没有消息/通知路由和数据库表 | APP端消息中心不可用 | 新增后端消息模块 |
| B2 | Web端缺少确认预订/退房/取消/拒绝预入住接口调用 | Web端前台无法执行关键操作 | 补充Web端API |

#### 中等问题

| 编号 | 问题 | 修复建议 |
|------|------|---------|
| R1 | APP端房间列表使用 `room_status` 参数名，后端使用 `status` | ✅ 已修复APP端 |
| P1 | APP端调用 `payments/stats/revenue` 接口，后端无此路由 | 新增后端接口 |
| C2 | APP端 `coupons/redeem` 路由不存在，后端只有 `coupons/:id/redeem` | 新增后端路由或修改APP端 |
| H2 | APP端缺少酒店详情带图片接口 | 补充APP端接口 |

#### 字段名不一致汇总

| 接口 | 后端返回 | Web端使用 | APP端使用 | 建议统一为 |
|------|---------|---------|---------|-----------|
| 酒店搜索-名称 | `name` | `name` | `hotel_name`(兼容) | `hotel_name` |
| 酒店搜索-地址 | `location` | `location` | `hotel_address`(兼容) | `hotel_address` |
| 酒店搜索-星级 | `star` | `star` | `hotel_star`(兼容) | `hotel_star` |
| 酒店搜索-图片 | `image` | `image` | `logo`(兼容) | `logo` |
| 预订-编号 | `booking_number` | `booking_number` | `booking_number`(兼容) | `booking_number` |
| 房间-状态参数 | `status` | `status` | `room_status`→已修复为`status` | `status` |

### E.4 功能对齐差异

#### APP酒店管理员端缺失功能

| 功能 | 优先级 | 说明 |
|------|-------|------|
| AI知识库管理 | 高 | AI管家核心配置，9个分类知识库管理 |
| MQTT通信管理 | 中 | IoT设备通信管理 |

#### APP系统管理员端缺失功能

| 功能 | 优先级 | 说明 |
|------|-------|------|
| 分店快速进入 | 高 | 系统管理员核心功能，快速切换管理不同分店 |
| 会员方案配置 | 高 | APP端系统设置与Web端完全不同，缺少会员等级/积分规则配置 |
| MQTT服务管理 | 中 | IoT系统核心管理 |
| 优惠券管理 | 中 | 系统管理员可管理全局优惠券 |

#### Web端缺失功能

| 功能 | 优先级 | 说明 |
|------|-------|------|
| 审核管理(酒店管理员) | 中 | APP端有角色申请审核功能 |
| 审核管理(系统管理员) | 高 | APP端有角色申请审核+批量审核 |
| 评价管理(系统管理员) | 中 | APP端有评价删除/申诉处理 |
| 房价设置(前台) | 低 | APP端前台有基础房价设置 |
