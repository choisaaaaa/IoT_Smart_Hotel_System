# 智联酒店 Flutter App 开发更新日志

> **更新日期**: 2026-04-08
> **当前版本**: v1.0.0 (Build 1)
> **开发分支**: `APP`
> **Flutter 版本**: 3.41.6 (Stable) | Dart 3.11.4

---

## 一、开发进度总览

| 阶段 | 状态 | 说明 |
|------|:----:|------|
| 项目初始化与架构搭建 | ✅ 完成 | Flutter 项目创建、依赖配置、目录结构 |
| 核心基础层开发 | ✅ 完成 | 网络层、存储层、MQTT服务、路由系统 |
| 数据模型层 (Models) | ✅ 完成 | User, Hotel, Room, Device, Booking |
| 认证模块 (Auth) | ✅ 完成 | 登录页面 + JWT Token 管理 |
| 管理端 (Admin) | ✅ 基础完成 | 5个Tab：仪表盘/设备监控/客房管理/酒店编辑/报表 |
| 前台端 (Reception) | ✅ 基础完成 | 7个Tab：首页/入住退房/预订/房态/工单/配送/账单 |
| 客人端 (Guest) | ✅ 基础完成 | 3个页面：在线预订/入住办理/客房服务 |
| **Windows 桌面端** | ✅ **编译通过** | 可运行原生 Windows 桌面应用 |
| Web 端 | ✅ 调试通过 | Edge 浏览器可正常运行 |
| **Android 端** | 🔄 **环境就绪** | SDK 36 已安装，待调试 |

---

## 二、已完成工作详情

### 2.1 技术架构

```
mobile/iot_hotel_app/
├── lib/
│   ├── main.dart                    # 入口，GoogleFonts 初始化
│   ├── app.dart                     # ConsumerStatefulWidget 应用入口
│   ├── core/
│   │   ├── constants/               # API/MQTT/应用常量
│   │   ├── network/                 # Dio HTTP客户端 + JWT拦截器
│   │   ├── storage/                 # SharedPreferences 本地存储（单例）
│   │   ├── mqtt/                    # MQTT 客户端服务
│   │   └── theme/                   # 主题配色 + GoogleFonts 字体
│   ├── models/                      # 数据模型（手动JSON序列化）
│   ├── services/                    # AuthService 认证服务
│   ├── routes/                      # GoRouter 路由（角色重定向守卫）
│   └── pages/
│       ├── auth/login_page.dart     # 登录页（角色快捷选择）
│       ├── admin/                   # 管理端 5-Tab Dashboard
│       ├── reception/               # 前台端 7-Tab Dashboard
│       └── guest/                   # 客人端 3 页面
├── android-sdk/                     # Android SDK (G盘安装)
│   ├── platforms/android-36/
│   ├── build-tools/36.0.0/
│   └── platform-tools/
├── android/                         # Android 原生工程
├── windows/                         # Windows 桌面端工程
├── web/                             # Web 端工程
└── pubspec.yaml                     # 依赖配置
```

### 2.2 依赖清单

| 包名 | 版本 | 用途 |
|------|------|------|
| flutter_riverpod | ^2.6.1 | 状态管理（Provider模式） |
| go_router | ^14.6.2 | 声明式路由 + 角色守卫 |
| dio | ^5.7.0 | HTTP 客户端 |
| mqtt_client | ^10.3.0 | MQTT 物联网通信 |
| fl_chart | ^0.70.2 | 图表库（仪表盘数据可视化） |
| google_fonts | ^6.2.1 | Google 字体 |
| shared_preferences | ^2.5.2 | 本地键值存储 |
| flutter_spinkit | ^5.2.1 | 加载动画 |
| intl | ^0.19.0 | 国际化/日期格式化 |
| json_annotation | ^4.9.0 | JSON 注解 |

### 2.3 关键技术决策

1. **纯 Dart 存储方案**: 因 Windows symlink 问题移除 `flutter_secure_storage`，改用 `shared_preferences`
2. **手动 JSON 序列化**: 移除 `json_serializable` 代码生成，避免构建复杂度
3. **角色路由守卫**: GoRouter redirect 中根据 token + role 自动跳转对应仪表盘
4. **Tab 导航修复**: `_pages` 使用 `late final` 在 `initState()` 中初始化，解决 const 列表嵌套类问题
5. **Android SDK 安装在 G 盘**: 路径为项目目录下 `android-sdk/`，避免沙箱权限限制

### 2.4 本地调试环境

| 服务 | 地址 | 状态 |
|------|------|:----:|
| Node.js 后端 | http://localhost:9000 | ✅ 运行中 |
| Vue 前端 (原版) | http://localhost:5173 | ✅ 运行中 |
| Flutter Web | Edge 浏览器 | ✅ 运行中 |
| Flutter Windows 桌面 | 原生窗口 | ✅ 编译通过 |

---

## 三、下一步计划

### Phase 2: 功能实现（优先级高）

#### 管理端 (Admin)
- [ ] 设备监控页：实时 MQTT 设备状态展示
- [ ] 客房管理页：CRUD 操作对接后端 API
- [ ] 酒店信息编辑页：表单提交 + 图片上传
- [ ] 报表页：fl_chart 数据图表渲染
- [ ] 仪表盘：真实数据统计卡片

#### 前台端 (Reception)
- [ ] 入住/退房：完整流程表单
- [ ] 预订管理：列表 + 筛选 + 详情
- [ ] 房态看板：实时房间状态网格
- [ ] 工单处理：创建/分配/完成流转
- [ ] 配送订单：状态跟踪
- [ ] 账单管理：费用明细展示

#### 客人端 (Guest)
- [ ] 在线预订：酒店/房型选择 + 日期
- [ ] 在线办理入住：身份证信息录入
- [ ] 客房服务：服务类型选择 + 下单

#### 通用功能
- [ ] 下拉刷新 + 上拉加载更多
- [ ] 全局错误处理 + Toast 提示
- [ ] Loading 状态管理（flutter_spinkit）
- [ ] 网络断网检测与提示
- [ ] MQTT 消息实时推送 UI 展示

### Phase 3: Android 端调试（进行中）

- [x] Android SDK 36 安装完成（G盘）
- [x] ANDROID_HOME 环境变量配置
- [x] Flutter Doctor 通过
- [ ] NDK 下载问题修复（当前构建失败原因）
- [ ] Android APK Debug 构建
- [ ] Android 模拟器/真机测试
- [ ] 权限适配（网络/存储等）
- [ ] 屏幕适配 + 多分辨率测试

### Phase 4: 打包发布
- [ ] Release 签名配置
- [ ] APK/AAB 打包
- [ ] 应用图标 + 启动页设计
- [ ] 性能优化 + 包体积缩减

---

## 四、环境配置说明

### 必需的环境变量

```powershell
# Flutter 中文镜像
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:PUB_CACHE = "G:\flutter\.pub-cache"

# Android SDK (G盘安装)
$env:ANDROID_HOME = "G:\Projects\IoT\IoT_Smart_Hotel_System\mobile\iot_hotel_app\android-sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
```

### 后端本地调试

后端 `.env` 配置（已修改用于本地调试）：
```
APP_HOST=localhost
APP_PORT=9000
DB_HOST=localhost
DB_NAME=iot_hotel_system
MQTT_HOST=localhost
```

认证接口已添加 Mock 用户数据库支持本地登录测试。

---

## 五、已知问题 & 解决方案

| 问题 | 状态 | 解决方案 |
|------|:----:|----------|
| Windows symlink 创建失败 | ✅ 已解决 | 移除所有原生插件，使用纯 Dart 替代 |
| shared_preferences Windows 兼容 | ✅ 已解决 | Developer Mode + Junction 链接 |
| Tab 导航不切换 | ✅ 已解决 | late final + initState() 延迟初始化 |
| NDK 下载损坏导致 Android 构建失败 | 🔄 待修复 | 删除 ndk 目录重新下载 |
| pub.dev 连接超时 | ✅ 已解决 | 配置中文镜像源 |

---

## 六、Git 提交记录

本次提交包含：

**新增文件** (`mobile/` - 整个 Flutter App 工程):
- 完整的 Flutter 跨平台应用代码
- Android SDK 工具链（android-sdk/）
- 平台工程（android/, windows/, web/, ios/, linux/）

**修改文件**:
- `backend/iot-hotel-backend/src/routes/v1/auth.ts`: 添加 Mock 登录支持本地调试
- `DEPLOYMENT.md`: 更新部署文档
