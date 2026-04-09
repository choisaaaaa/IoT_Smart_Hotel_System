# 智联酒店 Flutter App 开发更新日志

> **更新日期**: 2026-04-09
> **当前版本**: v2.1.0 (Build 3)
> **开发分支**: `APP`
> **Flutter 版本**: 3.41.6 (Stable) | Dart 3.11.4

---

## 一、开发进度总览

| 阶段 | 状态 | 说明 |
|------|:----:|------|
| 项目初始化与架构搭建 | ✅ 完成 | Flutter 项目创建、依赖配置、目录结构 |
| 核心基础层开发 | ✅ 完成 | 网络层、存储层、MQTT服务、路由系统 |
| 数据模型层 (Models) | ✅ 完成 | User, Hotel, Room, Device, Booking |
| 认证模块 (Auth) | ✅ 完成 | 登录页面 + JWT Token 管理 + 角色路由守卫 |
| Service层 (17个) | ✅ 完成 | Auth/Booking/Device/Member/Room/Hotel/Maintenance/Delivery/Payment/Review/User/Upload/Message/Floor/RoomType/Coupon |
| 管理端 (Admin) | ✅ 完成 | 5个Tab：仪表盘/设备监控/客房管理/酒店编辑/报表 |
| 前台端 (Reception) | ✅ 完成 | 7个Tab：总览/入住退房/预订/房态/工单/配送/账单 |
| 客人端 (Guest) | ✅ 完成 | 5个Tab：首页/预订/客房服务/会员/我的 |
| API路径对齐 | ✅ 完成 | 所有Service路径与后端实际路由完全对齐 |
| **Android 端** | ✅ **编译通过** | emulator-5554 可运行 |
| Web 端 | ✅ 调试通过 | Edge 浏览器可正常运行 |

---

## 二、v2.1.0 更新详情 (2026-04-09)

### 2.1 核心API字段对齐修复（关键修复）

后端实际返回的字段名与APP端使用的不一致，导致数据无法正确显示：

| 修复项 | APP原使用字段 | 后端实际字段 | 影响 |
|--------|-------------|------------|------|
| 酒店名称 | `name` | `hotel_name` | 酒店详情页名称显示为空 |
| 酒店地址 | `location` | `hotel_address` | 地址显示为空 |
| 酒店星级 | `star` | `hotel_star` | 星级显示异常 |
| 酒店图片 | `image` | `logo` | 图片无法加载 |
| 房间状态 | `status` | `room_status` | 客房状态全部显示为空闲 |
| 房间设施 | `facilities`(数组) | `facilities`(JSON字符串) | `List<dynamic>`不是`String`报错 |
| 房间图片 | `images`(数组) | `images`(JSON字符串) | 图片无法加载 |
| 预订编号 | `booking_no` | `booking_number` | 在线入住查询不到预订 |
| 入住日期 | `check_in` | `check_in_date` | lookupForGuest返回不同字段名 |

### 2.2 酒店详情页修复

- **修复 `List<dynamic>` 不是 `String` 报错**：`facilities` 和 `images` 字段后端返回JSON字符串，添加 `jsonDecode()` 解析
- **修复酒店信息字段映射**：`hotel_name→name`, `hotel_address→location`, `hotel_star→star`, `logo→image`
- **修复房间图片解析**：`images` 字段支持JSON字符串和数组两种格式
- **修复返回键失效**：`context.pop()` 改为 `context.canPop() ? context.pop() : context.go('/')`
- **新增收藏功能**：右上角爱心图标可收藏酒店，数据存储在SharedPreferences

### 2.3 订单列表修复

- **修复订单无数据**：`getBookings()` 返回 `{ list, total, page, pageSize }`，正确提取 `data['list']`
- **修复返回键失效**：同酒店详情页修复
- **修复预订编号字段**：`booking_number` 优先于 `booking_no`

### 2.4 在线办理入住（新功能）

- **新建 OnlineCheckinPage**：4步向导流程（验证预订→填写信息→确认提交→办理完成）
- **参考Web端实现**：`/bookings/lookup?keyword=xxx` 查询预订 + `/bookings/:id/checkin-online` 劯理入住
- **字段名兼容**：`lookupForGuest` 返回 `check_in/check_out/booking_no`，自动映射为 `check_in_date/check_out_date/booking_number`
- **支付后跳转**：预订支付成功后显示预订编号 + "在线办理入住"按钮

### 2.5 会员签到功能（新功能）

- **每日签到**：签到获得10经验，周日额外+20
- **连续签到奖励**：每7天连续签到获得满200减30优惠券
- **签到日历**：显示本周7天签到状态
- **本地存储**：使用SharedPreferences记录签到日期和连续天数

### 2.6 前台端修复

- **总览页真实数据**：4个统计卡片接入 `getDashboardStats()` 解析后的数据
- **工单去硬编码**：工单列表从API获取，不再显示不存在的444号房间
- **客房状态修复**：使用 `room_status` 字段替代 `status`，正确显示空闲/已住/已预订
- **客房改查功能**：点击房间弹出详情，可修改状态（空闲/入住/预定/清洁中/维修中）
- **客房唯一性**：已预订/已入住房间显示"不可分配"标签，释放需二次确认
- **账单详情弹窗**：点击账单弹出详情窗口，显示姓名/电话/金额/交易号/备注等
- **支付状态修复**：`paid` 状态显示"已支付"而非"待支付"

### 2.7 管理端修复

- **数据概览真实数据**：使用 `getDashboardStats()` 替代 `getStatistics()`，正确解析 `{ rooms: [...], bookings: [...] }` 格式
- **统计卡片可点击**：4个统计卡片点击跳转到对应Tab页
- **"查看全部"可点击**：最近活动区域点击跳转到报表页
- **酒店编辑页修复**：使用正确的后端字段名 `hotel_name/hotel_address/hotel_phone/hotel_star`

### 2.8 首页快捷功能

- **会员签到**：点击跳转会员中心
- **企业预订/华住商城**：点击显示"即将上线"提示
- **收藏/足迹**：点击跳转我收藏的页面

### 2.9 Service层修复

| Service | 修复内容 |
|---------|---------|
| HotelService | `getHotelById` 改用 `GET /hotel`；`getRoomAvailability` 改用 `GET /rooms`；`getDashboardStats` 解析statistics原始数据 |
| BookingService | `lookupBooking` 改用 `GET /bookings/lookup?keyword=`；新增 `checkinOnline` 方法 |
| RoomService | `getRooms` 使用 `room_status` 查询参数；`getRoomStatusDistribution` 从房间列表计算 |
| MemberService | 新增 `checkin()` 签到方法 + `CheckinResult` 类 |
| VoiceCallService | 移除 `flutter_webrtc` 依赖，改为stub实现避免编译错误 |

---

## 三、v2.0.0 更新详情 (2026-04-09)

### 2.1 API路径对齐修复（关键修复）

| 修复项 | 原路径(幽灵接口) | 修正后路径(后端实际) |
|--------|-----------------|-------------------|
| 设备控制 | `POST /devices/control` | `POST /devices/:id/command` |
| 送物完成 | `PUT /delivery/:id/status` | `PUT /delivery/:id/complete` |
| 工单分配 | `PUT /maintenance/:id/status` | `PUT /maintenance/:id/assign` |
| 工单完成 | 同上 | `PUT /maintenance/:id/complete` |
| 酒店评价 | `GET /reviews/hotel/:hotelId` | `GET /reviews?hotel_id=` |
| 支付详情 | `GET /payments/:id/status` | `GET /payments/:id` |
| 退款功能 | `POST /payments/:id/refund` | `PUT /bookings/:id/cancel` |
| 总览数据 | `GET /hotel/dashboard` | `GET /hotel/statistics` |
| 今日到店 | `GET /hotel/arrivals/today` | `GET /bookings?status=confirmed` |
| 月度报表 | `GET /hotel/reports/monthly` | `GET /hotel/statistics` |
| 酒店信息 | `GET /hotels/:id` | `GET /hotel` |
| 送物品类 | `GET /delivery/items` | 前端硬编码品类目录 |
| 房间状态分布 | `GET /rooms/status/distribution` | 从 `GET /rooms` 列表计算 |

### 2.2 新增Service模块

| Service | 对接后端模块 | API端点 |
|---------|------------|---------|
| FloorService | `/api/v1/floors` | GET/POST/PUT/DELETE 楼层管理 |
| RoomTypeService | `/api/v1/room-types` | GET/POST/PUT/DELETE 房型管理 |
| CouponService | `/api/v1/coupons` | GET/POST 领取优惠券 |

### 2.3 顾客端(Guest)功能完善

| 功能 | 说明 |
|------|------|
| 酒店搜索 | 修复搜索按钮无响应，添加键盘回车搜索+清除按钮 |
| 订单详情页 | 新建 OrderDetailPage，展示完整订单信息+支付/取消操作 |
| 酒店评价 | 调用 ReviewService 展示评价列表，支持分页加载 |
| 优惠券选择 | 预订流程中弹出优惠券选择器，支持抵扣计算 |
| 房间设备 | 移除Mock数据，空状态友好提示 |
| 会员类型修复 | 修复 dynamic 类型错误，正确使用 User/ApiResult 类型 |

### 2.4 前台端(Reception)功能完善

| 功能 | 说明 |
|------|------|
| 总览页 | 统计卡片+工单列表均接入API真实数据 |
| 入住退房 | Tab切换(待入住/待退房) + 办理入住/退房API调用 |
| 预订管理 | 6种状态筛选 + 预订列表 + 状态标签 |
| 客房余量 | 5种状态筛选 + 网格展示 + 状态色块 |
| 工单处理 | 工单列表 + 加急标记 + 接单/完成操作 |
| 送物服务 | 订单列表 + 接单/送达操作 |
| 账单报表 | 支付记录列表 + 金额/状态展示 |

### 2.5 管理员端(Admin)功能完善

| 功能 | 说明 |
|------|------|
| 总览页 | 统计卡片+饼图均接入API真实数据，支持下拉刷新 |
| 设备监控 | 状态筛选+远程控制，调用 `devices/:id/command` |
| 房间管理 | CRUD完整实现，添加房间时选择房型+楼层(下拉) |
| 酒店编辑 | 调用 `GET /hotel` 加载 + `PUT /hotel` 保存 |
| 报表页 | 接入 HotelService.getStatistics()，月度趋势图+收入构成 |

### 2.6 登录页修复

- 移除快捷登录按钮（管理员/前台/住客一键填充）
- 保留账号密码登录 + 注册入口

### 2.7 路由角色守卫

- 登录后根据 `user.role` 自动跳转：admin→/admin, staff→/reception, guest→/
- 401响应自动清除token并跳转登录页

### 2.8 API地址配置

- 默认使用远程服务器 `8.134.166.69:9000`
- Android模拟器使用 `10.0.2.2:9000`
- 支持运行时动态切换 `ApiConstants.setBaseUrl()`

---

## 三、技术架构

```
mobile/iot_hotel_app/
├── lib/
│   ├── main.dart                    # 入口，GoogleFonts 初始化
│   ├── app.dart                     # MaterialApp.router + NavigatorKey
│   ├── core/
│   │   ├── constants/               # API/MQTT/应用常量
│   │   ├── network/                 # DioClient + AuthInterceptor(401跳转)
│   │   ├── storage/                 # SharedPreferences 本地存储
│   │   ├── mqtt/                    # MQTT 客户端服务
│   │   ├── logic/                   # MemberLevel业务逻辑
│   │   ├── auth/                    # AuthStateNotifier
│   │   └── theme/                   # 主题配色 + GoogleFonts 字体
│   ├── models/                      # User, Device, Booking 数据模型
│   ├── services/                    # 17个Service模块
│   │   ├── auth_service.dart        # 认证(login/register/logout/me)
│   │   ├── booking_service.dart     # 预订(CRUD+checkin/checkout/cancel)
│   │   ├── device_service.dart      # 设备(list+command)
│   │   ├── member_service.dart      # 会员(assets/coupons)
│   │   ├── room_service.dart        # 房间(CRUD)
│   │   ├── hotel_service.dart       # 酒店(info/statistics)
│   │   ├── maintenance_service.dart # 工单(list+assign+complete)
│   │   ├── delivery_service.dart    # 送物(list+create+complete)
│   │   ├── payment_service.dart     # 支付(create+pay+refund)
│   │   ├── review_service.dart      # 评价(list+create)
│   │   ├── user_service.dart        # 用户管理(CRUD)
│   │   ├── upload_service.dart      # 文件上传
│   │   ├── message_service.dart     # 消息通知
│   │   ├── floor_service.dart       # 楼层管理
│   │   ├── room_type_service.dart   # 房型管理
│   │   └── coupon_service.dart      # 优惠券
│   ├── routes/                      # GoRouter(角色守卫+401跳转)
│   └── pages/
│       ├── auth/                    # 登录/注册
│       ├── admin/                   # 管理端 5-Tab
│       ├── reception/               # 前台端 7-Tab
│       └── guest/                   # 顾客端 5-Tab + 订单详情
```

---

## 四、后端API对接状态

### 已正确对接的后端API (约40个)

| 模块 | 已对接端点 |
|------|-----------|
| auth | login, register, logout, me |
| bookings | list, detail, create, confirm, checkin, checkout, cancel |
| devices | list, command |
| members | list, assets |
| rooms | list, detail, create, update, delete |
| hotel | get, update, statistics |
| maintenance | list, detail, create, assign, complete |
| delivery | list, create, complete |
| payments | list, create, pay |
| reviews | list, create |
| users | list, detail, create, update |
| upload | image |
| floors | list, create, update, delete |
| room-types | list, create, update, delete |
| coupons | list, receive |

### 后端有但APP暂未对接的API (低优先级)

| 模块 | 未对接端点 | 原因 |
|------|-----------|------|
| calls | 全部9个端点 | APP使用WebSocket+WebRTC实现语音通话 |
| frequent-guests | 全部4个端点 | 常住客人功能优先级低 |
| guests | 全部6个端点 | 客人管理由booking模块间接覆盖 |
| auth | generate-token, scan-login | 扫码登录功能暂不需要 |
| coupons | create, update, delete | 管理端优惠券管理暂不需要 |
| devices | register, audit, delete | 硬件设备注册由MQTT模块处理 |
| members | login, create, update | 会员管理由注册流程覆盖 |

---

## 五、已知问题 & 后续计划

### 待完善功能

| 功能 | 优先级 | 说明 |
|------|--------|------|
| MQTT断线重连 | 中 | 当前无重连机制，硬件就绪后实现 |
| 语音通话REST API对接 | 低 | 当前使用WebSocket信令 |
| 常住客人管理 | 低 | 后端已支持，APP端未实现 |
| 扫码登录 | 低 | 后端已支持generate-token/scan-login |
| 离线缓存 | 低 | 网络断开时缓存关键操作 |

### 测试环境

| 环境 | 命令 | 状态 |
|------|------|------|
| Android模拟器 | `flutter run -d emulator-5554` | ✅ 编译通过 |
| Edge浏览器 | `flutter run -d edge --web-port=8080` | ✅ 运行中 |
| 后端API | `http://localhost:9000` 或 `http://8.134.166.69:9000` | ✅ 运行中 |

---

## 六、环境配置说明

### 必需的环境变量

```powershell
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:ANDROID_HOME = "G:\Projects\IoT\IoT_Smart_Hotel_System\mobile\iot_hotel_app\android-sdk"
```

### 启动命令

```powershell
# 后端
cd G:\Projects\IoT\IoT_Smart_Hotel_System\backend\iot-hotel-backend; npm run dev

# Flutter Web
cd G:\Projects\IoT\IoT_Smart_Hotel_System\mobile\iot_hotel_app; flutter run -d edge --web-port=8080

# Flutter Android
cd G:\Projects\IoT\IoT_Smart_Hotel_System\mobile\iot_hotel_app; flutter run -d emulator-5554
```
