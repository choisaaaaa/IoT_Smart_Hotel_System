# IoT 智慧酒店系统 - 移动端(App)开发规范文档

> 版本: v1.0 | 更新日期: 2026-04-12 | 维护人: Yzj 主负责人:Yzj

***

## 1. 技术栈

| 技术       | 版本   | 用途     |
| -------- | ---- | ------ |
| Flutter  | 3.x  | 跨平台框架  |
| Dart     | 3.x  | 编程语言   |
| Riverpod | 2.x  | 状态管理   |
| GoRouter | 14.x | 路由管理   |
| Dio      | 5.x  | HTTP请求 |
| MQTT     | 5.x  | IoT通信  |

***

## 2. 项目结构

```
lib/
├── core/                    # 核心模块
│   ├── auth/                # 认证状态
│   │   └── auth_state_notifier.dart
│   ├── constants/           # 常量定义
│   │   ├── api_constants.dart
│   │   ├── app_constants.dart
│   │   └── mqtt_constants.dart
│   ├── logic/               # 业务逻辑
│   │   └── member_logic.dart
│   ├── mqtt/                # MQTT服务
│   │   └── mqtt_service.dart
│   ├── network/             # 网络层
│   │   ├── api_interceptor.dart
│   │   ├── api_result.dart
│   │   └── dio_client.dart
│   ├── storage/             # 本地存储
│   │   └── local_storage.dart
│   └── theme/               # 主题
│       ├── app_colors.dart
│       └── app_theme.dart
├── models/                  # 数据模型
│   ├── booking.dart
│   ├── device.dart
│   ├── hotel.dart
│   ├── room.dart
│   └── user.dart
├── pages/                   # 页面
│   ├── admin/               # 管理员页面
│   ├── auth/                # 登录注册
│   ├── guest/               # 顾客页面
│   ├── reception/           # 前台页面
│   └── system/              # 系统管理
├── routes/                  # 路由配置
│   ├── app_router.dart
│   └── route_observer.dart
├── services/                # 服务层
│   ├── auth_service.dart
│   ├── booking_service.dart
│   ├── device_service.dart
│   ├── delivery_service.dart
│   ├── payment_service.dart
│   ├── voice_call_service.dart
│   └── ...
├── app.dart
└── main.dart
```

***

## 3. 开发规范

### 3.1 import 路径规范

**核心规则：根据文件所在目录层级确定相对路径**

| 文件位置                   | 引用 core/      | 引用 services/      | 引用 models/      |
| ---------------------- | ------------- | ----------------- | --------------- |
| `lib/pages/guest/`     | `../../core/` | `../../services/` | `../../models/` |
| `lib/pages/reception/` | `../../core/` | `../../services/` | `../../models/` |
| `lib/pages/admin/`     | `../../core/` | `../../services/` | `../../models/` |
| `lib/pages/auth/`      | `../../core/` | `../../services/` | `../../models/` |
| `lib/services/`        | `../core/`    | -                 | `../models/`    |

**常见错误**：

```dart
// 错误 ❌ - 多了一层 ../
import '../../../core/theme/app_colors.dart';
import '../../../services/booking_service.dart';

// 正确 ✅ - pages/guest/ 到 lib/ 是两层
import '../../core/theme/app_colors.dart';
import '../../services/booking_service.dart';
```

### 3.2 服务层规范

#### 服务类结构

```dart
class BookingService {
  final DioClient _dioClient;

  BookingService(this._dioClient);

  Future<ApiResult<Map<String, dynamic>>> getBookings({
    int page = 1,
    int pageSize = 10,
    String? status,
    String? guestName,
    String? checkInDate,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiConstants.bookings,
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          'status': status,
          'guest_name': guestName,
          'check_in_date': checkInDate,
        }..removeWhere((key, value) => value == null),
      );
      return ApiResult.success(response);
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }
}
```

#### 服务Provider定义

```dart
final bookingServiceProvider = Provider<BookingService>((ref) {
  return BookingService(ref.read(dioClientProvider));
});
```

### 3.3 页面开发规范

#### 状态管理

使用 `ConsumerStatefulWidget` + Riverpod：

```dart
class DashboardPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  List<Map<String, dynamic>> _todayBookings = [];

  Future<void> _loadTodayBookings() async {
    final result = await ref.read(bookingServiceProvider).getBookings(
      pageSize: 50,
      checkInDate: 'today',
    );
    if (result.success && mounted) {
      final list = (result.data?['list'] as List<dynamic>?) ?? [];
      final filtered = list.where((b) =>
        ['pending', 'confirmed', 'pre_checked_in', 'checked_in'].contains(b['status'])
      ).toList();
      setState(() => _todayBookings = filtered);
    }
  }
}
```

#### 前台Dashboard日期过滤

```dart
// 正确 ✅ - 使用 checkInDate 过滤今日预订
final result = await ref.read(bookingServiceProvider).getBookings(
  pageSize: 50,
  checkInDate: 'today',
);

// 错误 ❌ - 不按日期过滤，显示所有预订
final result = await ref.read(bookingServiceProvider).getBookings(
  pageSize: 50,
);
```

### 3.4 API常量定义

所有API路径在 `api_constants.dart` 中统一定义：

```dart
class ApiConstants {
  static const String baseUrl = 'http://8.134.166.69:3000/api/v1';
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String bookings = '/bookings';
  static const String payments = '/payments';
  static const String rooms = '/rooms';
  static const String devices = '/devices';
  // ...
}
```

### 3.5 代码目录约束

**App代码只能在** **`mobile/`** **目录下**，禁止修改以下目录：

- `backend/` - 后端代码
- `frontend/` - Web端代码

如需修改后端或Web端，必须先提出开发建议并获得允许。

***

## 4. 页面角色对应

| 页面目录               | 角色            | 主要功能                 |
| ------------------ | ------------- | -------------------- |
| `pages/auth/`      | 公开            | 登录、注册                |
| `pages/guest/`     | customer      | 预订、入住、客房服务、订单、续住    |
| `pages/reception/` | staff         | 前台Dashboard、配送、工单、通话 |
| `pages/admin/`     | hotel\_admin  | 酒店管理、房型、设备、报表        |
| `pages/system/`    | system\_admin | 系统设置、用户管理            |

***

## 5. 编译与测试

### 5.1 编译检查

```bash
cd mobile/iot_hotel_app
flutter analyze --no-fatal-infos
```

### 5.2 运行

```bash
flutter run -d windows    # Windows桌面
flutter run -d chrome     # Web
flutter run -d <device>   # Android设备
```

