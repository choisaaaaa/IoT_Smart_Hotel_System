# 慧宿智联 · 云边端一体化智能酒店物联网系统

## 📋 项目简介

**慧宿智联**是一套完整的云边端一体化智能酒店物联网解决方案，涵盖从云端管理平台到边缘设备终端的全栈技术架构。系统采用现代化的技术栈，支持酒店客房智能化管理、设备远程控制、环境监测、语音交互、AI管家服务等功能。

### 核心特性

- ☁️ **云端管理**: 基于微服务架构的云端管理平台，支持多酒店管理
- 🔗 **边缘计算**: 楼层控制器实现本地智能决策，降低云端依赖
- 📱 **多端接入**: Web管理端、移动App、客房终端、前台终端
- 🏨 **智能客房**: 环境监测、设备控制、语音交互、场景联动
- 🔐 **安全可靠**: JWT认证、设备密钥管理、TLS加密通信
- 🌐 **物联网协议**: 基于MQTT的物联网通信协议，支持设备影子

***

## 🏗️ 系统架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              云端层 (Cloud)                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Web前端   │  │  后端API    │  │  MySQL      │  │  Redis缓存/MQTT     │ │
│  │  (Vue3)     │  │  (Node.js)  │  │  数据库     │  │  消息队列           │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              边缘层 (Edge)                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    楼层控制器 (Floor Controller)                     │   │
│  │  • 走廊灯控制  • 环境监测(DHT11/MQ2/LDR/NTC)  • 毫米波雷达检测        │   │
│  │  • 消防报警  • MQTT本地桥接  • 离线缓存                              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              设备层 (Device)                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌────────────────┐  │
│  │  客房终端    │  │  前台终端    │  │  消防节点    │  │   仿真器       │  │
│  │  ESP32-S3    │  │  ESP32-S3    │  │  ESP8266     │  │  (Python)      │  │
│  │  • 触摸屏    │  │  • 语音通话  │  │  • 烟雾检测  │  │  • 设备模拟    │  │
│  │  • 语音交互  │  │  • RFID读卡  │  │  • 温度监测  │  │  • 场景测试    │  │
│  │  • 红外控制  │  │  • 入住办理  │  │  • 紧急报警  │  │                │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  └────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

***

## 📁 项目结构

```
IoT_Smart_Hotel_System/
├── 📂 backend/                    # 后端服务
│   └── iot-hotel-backend/         # Node.js + TypeScript + Express
│       ├── src/
│       │   ├── controllers/       # API控制器
│       │   ├── services/          # 业务逻辑服务
│       │   ├── models/            # 数据模型
│       │   ├── routes/            # 路由定义
│       │   ├── middleware/        # 中间件(认证/错误处理)
│       │   ├── utils/             # 工具函数
│       │   └── config/            # 配置文件
│       ├── tests/                 # 测试用例
│       └── Dockerfile             # 容器化配置
│
├── 📂 frontend/                   # 前端应用
│   └── iot-hotel-web/             # Vue3 + TypeScript + Vite
│       ├── src/
│       │   ├── views/             # 页面视图
│       │   │   ├── admin/         # 系统管理员视图
│       │   │   ├── reception/     # 前台管理视图
│       │   │   ├── guest/         # 住客视图
│       │   │   └── system/        # 超级管理员视图
│       │   ├── components/        # 公共组件
│       │   ├── api/               # API接口封装
│       │   ├── stores/            # Pinia状态管理
│       │   └── router/            # 路由配置
│       └── package.json
│
├── 📂 mobile/                     # 移动端应用
│   └── iot_hotel_app/             # Flutter跨平台App
│       ├── android/               # Android配置
│       ├── ios/                   # iOS配置
│       └── assets/                # 静态资源
│
├── 📂 hardware/                   # 硬件固件
│   ├── common_components/         # 公共组件库
│   │   ├── drivers/               # 设备驱动
│   │   ├── hal/                   # 硬件抽象层
│   │   └── services/              # 服务层(MQTT/网络/认证)
│   ├── room_terminal/             # 客房终端固件 (ESP32-S3)
│   ├── front_desk_terminal/       # 前台终端固件 (ESP32-S3)
│   ├── floor_controller/          # 楼层控制器固件 (ESP32-C3)
│   └── esp8266_room_fire_node/    # 消防节点固件 (ESP8266)
│
├── 📂 emulator/                   # 设备仿真器
│   ├── common/                    # 公共模块
│   ├── room_terminal/             # 客房终端仿真
│   ├── front_desk/                # 前台终端仿真
│   └── floor_controller/          # 楼层控制器仿真
│
└── 📂 docker/                     # Docker部署配置
    ├── docker-compose.yml         # 服务编排
    ├── nginx/                     # Nginx配置
    ├── mqtt/                      # MQTT Broker配置
    └── redis/                     # Redis配置
```

***

## 🚀 快速开始

### 环境要求

| 组件          | 版本要求                  |
| ----------- | --------------------- |
| Node.js     | >= 20.x               |
| Python      | >= 3.8                |
| MySQL       | >= 8.0                |
| Redis       | >= 7.0                |
| MQTT Broker | Eclipse Mosquitto 2.0 |
| Flutter     | >= 3.x (移动端)          |
| ESP-IDF     | >= 5.x (硬件开发)         |

### 1. 克隆项目

```bash
git clone <repository-url>
cd IoT_Smart_Hotel_System
```

### 2. 后端服务启动

```bash
cd backend/iot-hotel-backend

# 安装依赖
npm install

# 配置环境变量
cp .env.example .env
# 编辑 .env 文件配置数据库连接信息

# 启动开发服务器
npm run dev
```

### 3. 前端应用启动

```bash
cd frontend/iot-hotel-web

# 安装依赖
npm install

# 启动开发服务器
npm run dev
```

### 4. Docker 一键部署

```bash
cd docker

# 启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f
```

### 5. 设备仿真器启动

```bash
cd emulator

# 安装依赖
pip install -r requirements.txt

# 启动客房终端仿真
python room_terminal/main.py

# 启动前台终端仿真
python front_desk/main.py

# 启动楼层控制器仿真
python floor_controller/main.py
```

***

## 💻 技术栈

### 后端技术栈

| 技术                    | 用途              |
| --------------------- | --------------- |
| **Node.js + Express** | Web服务框架         |
| **TypeScript**        | 类型安全的JavaScript |
| **MySQL2**            | 关系型数据库          |
| **Redis**             | 缓存与会话存储         |
| **MQTT.js**           | 物联网消息通信         |
| **Socket.io**         | 实时双向通信          |
| **JWT**               | 身份认证            |
| **Winston**           | 日志记录            |
| **Jest**              | 单元测试            |

### 前端技术栈

| 技术                   | 用途              |
| -------------------- | --------------- |
| **Vue 3**            | 渐进式JavaScript框架 |
| **TypeScript**       | 类型系统            |
| **Vite**             | 构建工具            |
| **Ant Design Vue**   | UI组件库           |
| **Pinia**            | 状态管理            |
| **Vue Router**       | 路由管理            |
| **ECharts**          | 数据可视化           |
| **Axios**            | HTTP客户端         |
| **Socket.io-client** | 实时通信            |

### 移动端技术栈

| 技术          | 用途        |
| ----------- | --------- |
| **Flutter** | 跨平台移动开发框架 |
| **Dart**    | 编程语言      |

### 硬件技术栈

| 技术           | 用途            |
| ------------ | ------------- |
| **ESP-IDF**  | Espressif开发框架 |
| **FreeRTOS** | 实时操作系统        |
| **C/C++**    | 嵌入式开发         |
| **MQTT**     | 设备通信协议        |

***

## 📱 功能模块

### 系统管理员功能

- 🏨 酒店管理：酒店信息配置、房型管理、楼层管理
- 👥 用户管理：系统用户、权限分配、角色管理
- 📊 数据报表：入住率统计、设备状态、能耗分析
- 💰 价格日历：动态定价、促销策略
- 🎫 优惠券管理：发放策略、使用统计
- 📚 知识库管理：AI管家知识库配置

### 前台管理功能

- 📝 预订管理：在线预订、订单处理
- 🔔 入住/退房：快速办理、房卡管理
- 📞 语音通话：客房呼叫转接
- 🔔 送物服务：物品配送跟踪
- 🔧 工单管理：维修工单派发
- 💳 账单管理：费用结算、发票管理

### 住客功能

- 🤖 AI管家：智能问答、客房控制
- 🌡️ 环境控制：温度、灯光、窗帘
- 📺 设备控制：电视、空调、场景模式
- 📞 客房服务：呼叫服务、送物请求
- ⭐ 评价反馈：入住体验评价

### 物联网功能

- 📡 设备管理：设备注册、状态监控、远程控制
- 🌡️ 环境监测：温度、湿度、烟雾、光照
- 🔥 消防报警：烟雾检测、温度异常报警
- 🎙️ 语音交互：语音控制、语音通话
- 📶 场景联动：自动化场景、定时任务

***

## 🔧 硬件设备规格

### 客房终端 (ESP32-S3)

| 组件   | 规格                                 |
| ---- | ---------------------------------- |
| 主控   | ESP32-S3-N16R8                     |
| 显示屏  | 3.5寸 TFT LCD (320x480)             |
| 触摸屏  | 电容式触摸                              |
| 音频输入 | INMP441 MEMS麦克风                    |
| 音频输出 | NS4168 I2S功放                       |
| 传感器  | DHT11(温湿度)、MQ2(烟雾)、LDR(光照)、NTC(温度) |
| 通信   | WiFi、MQTT                          |
| 控制   | 红外发射、继电器                           |

### 前台终端 (ESP32-S3)

| 组件   | 规格        |
| ---- | --------- |
| 主控   | ESP32-S3  |
| RFID | RC522 读卡器 |
| 音频   | 麦克风 + 扬声器 |
| 通信   | WiFi、MQTT |

### 楼层控制器 (ESP32-C3)

| 组件  | 规格                             |
| --- | ------------------------------ |
| 主控  | ESP32-C3                       |
| 控制  | 继电器 x4                         |
| 传感器 | DHT11、MQ2、LDR、NTC、RD-03(毫米波雷达) |
| 通信  | WiFi、MQTT                      |

***

## 📡 MQTT 主题规范

```
# 设备上报
hotel/{hotel_id}/device/{device_id}/telemetry    # 遥测数据
hotel/{hotel_id}/device/{device_id}/status       # 设备状态
hotel/{hotel_id}/device/{device_id}/alarm        # 报警信息

# 云端下发
hotel/{hotel_id}/device/{device_id}/command      # 控制命令
hotel/{hotel_id}/device/{device_id}/config       # 配置更新

# 广播主题
hotel/{hotel_id}/broadcast/announcement          # 系统公告
hotel/{hotel_id}/broadcast/emergency             # 紧急广播
```

***

## 🧪 测试

### 后端测试

```bash
cd backend/iot-hotel-backend

# 运行单元测试
npm test

# 运行测试覆盖率
npm run test:coverage

# 运行本地API测试
node tests/detailed-api-test.js
```

### 前端测试

```bash
cd frontend/iot-hotel-web

# 运行单元测试
npm run test

# 运行类型检查
npm run type-check
```

### 硬件测试

```bash
cd hardware/test/mqtt_simulator

# 安装依赖
npm install

# 运行楼层控制器测试
node test_floor_03.js

# 运行前台终端测试
node test_front_desk_01.js
```

***

## 📝 API 文档

启动后端服务后，访问 Swagger UI 查看完整 API 文档：

```
http://localhost:3000/api-docs
```

***

## 🔐 安全说明

- 所有 API 接口均使用 JWT 认证
- 设备通信采用 TLS 加密
- 数据库连接使用独立账号，最小权限原则
- 敏感信息（密码、密钥）禁止硬编码
- 定期更新依赖包以修复安全漏洞

***

## 🤝 贡献指南

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

***

## 📄 许可证

本项目基于 [MIT](LICENSE) 许可证开源。

***

