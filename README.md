# 智联酒店 - 智慧酒店物联网控制系统

**管理端 · 前台端 · 客户端** 三端协同 | AI 客房管家 | IoT 设备实时监控 | 三层硬件架构

[功能介绍](#-系统架构) · [快速开始](#-快速开始) · [开发指南](#-开发指南) · [部署文档](#-部署文档)


---

## 系统架构

### 🏗️ 整体架构（软硬一体）

```
┌─────────────────────────────────────────────────────────────┐
│                    📱 应用层（三端协同）                       │
│   客户端(Guest) │ 前台端(Reception) │ 管理端(Admin)         │
│   预订/入住/AI管家 │ 入住退房/工单/送物 │ 设备监控/报表      │
├───────────────────┬───────────────────┬─────────────────────┤
│     前端 (Vue3)    │                   │                     │
│   TypeScript+Vite  │    HTTP/WebSocket │    后端 (Node.js)   │
│   Pinia+ECharts   │ ───────────────►  │  Express+TypeScript │
│                    │                   │  MySQL+MQTT+Redis   │
└────────────────────┴───────────────────┴─────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
     ┌────────────────┐ ┌──────────┐ ┌──────────────┐
     │  🖥️ 前台管理端   │ │ 🏠 楼控  │ │ 🛏️ 客房端     │
     │  (USB外设模式)  │ │ (环境监测)│ │ (设备控制)    │
     │  ESP32-S2/STM32 │ │ ESP32    │ │ ESP32        │
     │  RFID/RGB/SOS   │ │ 温湿度等  │ │ 灯光/空调/窗帘 │
     └────────────────┘ └──────────┘ └──────────────┘
                              │
                    ┌─────────┴─────────┐
                    │   Docker Compose   │
                    │  MySQL(3307)       │
                    │  Mosquitto(1883)   │
                    └───────────────────┘
```

### 🔧 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| **前端** | Vue 3 + TypeScript + Vite、Ant Design Vue 4、Pinia、ECharts、Socket.io-client | 三端协同界面 |
| **后端** | Node.js 20 + Express + TypeScript、MySQL 2/promise、JWT 认证 | RESTful API + WebSocket |
| **实时通信** | MQTT（Mosquitto）、WebSocket（Socket.io）| IoT设备通信 |
| **数据库** | MySQL 8.0、Redis（可选）| 数据持久化 |
| **容器化** | Docker Compose（MySQL + MQTT）| 开发环境 |
| **硬件层** | ESP32系列、RFID-RC522、传感器模块、RS485/UART | IoT设备控制 |

---

## 🎯 核心特性

### 💻 软件系统特性

#### ✨ 最新更新 (2026-04-07)

1. **📦 送物订单增强**
   - ✅ 新增 `booking_id` 字段：关联预订信息，支持按预订查询送物记录
   - ✅ 新增 `guest_id` 字段：关联住客信息，精确追踪服务对象
   - ✅ API完全兼容：可选参数设计，不影响现有调用

2. **🔧 报修工单增强**
   - ✅ 新增 `booking_id` 字段：关联预订，便于统计分析
   - ✅ 新增 `guest_id` 字段：关联报修人，提升服务质量追踪
   - ✅ 支持多维度筛选：可按预订、住客、房间查询工单

3. **👥 住客管理系统（全新）**
   - ✅ 完整CRUD：创建、查询、更新、删除住客记录
   - ✅ 预订关联：自动关联booking信息，支持按预订查看住客列表
   - ✅ 身份验证：支持身份证件类型和号码存储
   - ✅ 状态管理：入住中(in)/已退房(out)状态跟踪
   - ✅ RESTful API：`GET/POST /api/v1/guests`

4. **📞 语音通话系统（已完善）**
   - ✅ 多方通话：支持房间、前台、AI、APP四种角色
   - ✅ 通话状态机：calling → ringing → connected → ended
   - ✅ 历史记录：完整通话记录和统计功能
   - ✅ 并发控制：检测重复通话，避免冲突

#### 🌟 三端协同功能

| 功能模块 | 管理端 | 前台端 | 客户端 |
|---------|--------|--------|--------|
| **仪表盘总览** | ✅ 设备在线率、房间状态 | ✅ 今日入住/退房统计 | ❌ |
| **设备监控** | ✅ IoT设备卡片、指令发送 | ❌ | ✅ 客房设备控制 |
| **房间管理** | ✅ CRUD、房型配置 | ✅ 余量查看、楼层图 | ✅ 预订选房 |
| **预订管理** | ❌ | ✅ 列表、确认、入住、取消 | ✅ 在线预订 |
| **入住退房** | ❌ | ✅ 线下办理、退房结算 | ✅ 在线办理入住 |
| **工单处理** | ❌ | ✅ 维修/清洁/服务工单 | ✅ 提交报修请求 |
| **客房送物** | ❌ | ✅ 订单创建与配送跟踪 | ✅ 请求送物服务 |
| **账单报表** | ✅ 收入统计、导出打印 | ✅ 营收统计、收款 | ❌ |
| **AI管家** | ❌ | ❌ | ✅ 聊天、语音交互 |
| **联系前台** | ❌ | ❌ | ✅ 通话、消息 |

### 🎛️ 硬件系统特性

#### 三层硬件架构

本项目采用创新的"**前台管理端 - 楼控 - 客房端**"三层架构：

```
┌─────────────────────────────────────────────────────────┐
│  🖥️ 第一层：前台管理端（酒店级协调）                      │
│  ├─ 定位：USB外设模式（轻硬重软）                         │
│  ├─ 主控：ESP32-S2 / STM32                               │
│  ├─ 外设：RFID-RC522、RGB灯带、SOS按键、蜂鸣器            │
│  ├─ 接口：USB Type-C（供电+通信）、RS485、UART            │
│  └─ 特点：成本降低48%（¥150→¥84），软件功能由电脑承担      │
├─────────────────────────────────────────────────────────┤
│  🏠 第二层：楼控（环境监测）                              │
│  ├─ 主控：ESP32                                          │
│  ├─ 传感器：温湿度、空气质量、光照、噪音                   │
│  ├─ 通信：WiFi/MQTT → 云端服务器                          │
│  └─ 功能：环境数据采集、异常报警                           │
├─────────────────────────────────────────────────────────┤
│  🛏️ 第三层：客房端（智能控制）                            │
│  ├─ 主控：ESP32                                          │
│  ├─ 控制：灯光、空调、窗帘、电视、门锁                     │
│  ├─ 交互：触摸屏/按键、语音助手                           │
│  └─ 通信：WiFi/MQTT ↔ 楼控 ↔ 前台                       │
└─────────────────────────────────────────────────────────┘
```

#### 硬件模块清单

| 模块 | 目录 | 主要组件 | 功能描述 |
|------|------|---------|---------|
| **主控系统** | `hardware/maincontroller/` | ESP32-S2/STM32 | 前台管理端核心控制 |
| **环境监测** | `hardware/environmental/` | DHT11/BME280、光照传感器 | 温湿度、空气质量监测 |
| **安防系统** | `hardware/security/` | 门磁、红外、烟雾传感器 | 安全防护、入侵检测 |

#### 硬件通信协议

- **内部通信**：UART、I2C、SPI（模块间）
- **楼层通信**：RS485（楼控 ↔ 客房端）
- **云端通信**：MQTT over WiFi（所有层级 → 云服务器）
- **前台通信**：USB Serial（前台管理端 ↔ 前台电脑）

---

## 快速开始

### 📋 环境要求

#### 软件开发环境
- **Node.js** >= 18.x（推荐 20.x）
- **npm** >= 9.x 或 **pnpm** >= 8.x
- **Docker & Docker Compose**（用于 MySQL + MQTT）
- **Git**

#### 硬件开发环境（可选）
- **PlatformIO / Arduino IDE**（ESP32固件开发）
- **USB-TTL转换器**（硬件调试）
- **ESP32开发板** × N（根据部署规模）

### 第一步：克隆项目

```bash
git clone https://github.com/choisaaaaa/IoT_Smart_Hotel_System.git
cd IoT_Smart_Hotel_System
```

### 第二步：启动基础设施（Docker）

```bash
cd docker
docker-compose up -d
```

启动后：
- **MySQL**: `localhost:3307`（root / IotHotel2026）
- **MQTT Broker**: `localhost:1883`（无需认证）

数据库将自动执行：
1. `docker/mysql/init/schema.sql` - 初始化表结构
2. `docker/mysql/init/update_schema.sql` - 更新schema（新增字段和表）

### 第三步：配置并启动后端

```bash
cd backend/iot-hotel-backend

# 复制环境变量模板
cp .env.example .env

# 安装依赖
npm install

# 类型检查（可选，确认无 TS 错误）
npx tsc --noEmit

# 启动开发服务器
npm run dev
```

后端运行在 **http://localhost:9000**，API 前缀为 `/api/v1`。

> ⚠️ **注意**：端口号已从3000改为9000，请确保使用正确的端口。

### 第四步：启动前端

```bash
cd frontend/iot-hotel-web

# 安装依赖
npm install

# 启动开发服务器
npm run dev
```

前端运行在 **http://localhost:5173**（端口可能因占用自动递增）。

### 第五步：验证

浏览器打开前端地址，默认跳转至**管理端仪表盘**。侧边栏底部可切换三端：

| 入口 | 地址 | 说明 |
|------|------|------|
| 管理端 | `/admin/dashboard` | 设备监控、信息编辑、账单报表 |
| 前台端 | `/reception/dashboard` | 入住退房、工单、送物、预订等 |
| 客户端 | `/guest/booking` | 预订入住、AI管家、客房服务 |

### 第六步：（可选）硬件开发

```bash
# 进入硬件目录
cd hardware/maincontroller/  # 或 environmental/ security/

# 使用PlatformIO打开项目
pio project open .

# 编译并上传固件
pio run -t upload
```

---

## 开发指南

### 📁 项目目录结构

```
IoT_Smart_Hotel_System/
│
├── 💻 backend/iot-hotel-backend/      # 后端服务（Node.js + Express）
│   ├── src/
│   │   ├── controllers/               # 控制层（路由处理）
│   │   │   ├── delivery.controller.ts # 送物订单（含booking_id, guest_id）
│   │   │   ├── maintenance.controller.ts  # 报修工单（含booking_id, guest_id）
│   │   │   ├── guest.controller.ts     # 住客管理（新增）
│   │   │   └── call.controller.ts      # 语音通话系统
│   │   ├── services/                  # 业务逻辑层
│   │   ├── models/                    # 数据模型
│   │   ├── routes/v1/                 # RESTful API 路由
│   │   │   ├── guests.ts              # 住客管理路由（新增）
│   │   │   ├── delivery.ts            # 送物订单路由
│   │   │   ├── maintenance.ts         # 报修工单路由
│   │   │   └── calls.ts               # 语音通话路由
│   │   ├── middleware/                # 中间件（JWT/CORS/日志）
│   │   ├── config/                    # 配置（DB/MQTT/Redis）
│   │   ├── types/                     # TypeScript 类型定义
│   │   └── utils/                     # 工具函数
│   ├── database/init.sql              # 数据库初始化脚本
│   └── docker-compose.yml             # 本地开发用 Docker 服务
│
├── 🎨 frontend/iot-hotel-web/        # 前端应用（Vue3 + Vite）
│   ├── src/
│   │   ├── api/                       # Axios API 封装
│   │   ├── components/layout/         # 三端布局组件
│   │   ├── views/admin/               # 管理端页面（5个）
│   │   ├── views/reception/           # 前台端页面（7个）
│   │   ├── views/guest/               # 客户端页面（3个）
│   │   ├── stores/                    # Pinia 状态管理
│   │   └── router/                    # Vue Router 三端路由
│   └── vite.config.ts                 # Vite 配置（含代理）
│
├── 🔌 hardware/                       # ESP32 硬件固件
│   ├── maincontroller/                # 前台管理端主控
│   │   └── .主控                      # ESP32-S2/STM32固件
│   ├── environmental/                 # 楼控-环境监测
│   │   └── .环境监测                  # 温湿度、空气质量传感器
│   └── security/                      # 安防系统
│       └── .安防                      # 门磁、红外、烟雾传感器
│
├── 🐳 docker/                         # Docker配置
│   ├── mysql/init/                    # 数据库脚本
│   │   ├── schema.sql                 # 初始化schema
│   │   └── update_schema.sql          # schema更新（新增字段和表）
│   └── mqtt/                          # MQTT Broker配置
│
├── 📚 docs/                           # 项目文档
│   ├── 01-系统架构/                    # 需求说明、架构设计
│   ├── 02-硬件设计/                    # 三层架构硬件设计
│   ├── 03-软件设计/                    # API文档、数据库设计
│   ├── 04-部署运维/                    # 部署指南、Docker配置
│   └── 05-项目管理/                    # 开发分工、采购清单
│
├── .editorconfig                      # 统一编码风格
├── .gitignore                         # Git 忽略规则
└── README.md                          # 本文件
```

### 编码规范

项目已配置 `.editorconfig`，所有团队成员安装 EditorConfig 插件即可自动生效：

| 规则 | 值 |
|------|-----|
| 缩进 | 2 空格 |
| 字符集 | UTF-8 |
| 换行符 | LF |
| 文件末尾 | 自动换行 |

### 分支策略

```
main ← develop ← feature/* ← 你的分支
```

- **main**: 生产分支，受保护
- **develop**: 日常开发主分支
- **feature/xxx**: 功能分支，完成后提 PR 合并

### Git 提交规范

```
<type>(<scope>): <subject>

type: feat | fix | docs | style | refactor | chore
scope: backend | frontend | admin | reception | guest | config | docs
```

### 详细协作文档

→ 查看 [协同开发指南](./docs/05-项目管理/协同开发指南.md)

---

## 部署文档

### 本地开发部署

→ 查看 [跨平台开发环境配置指南](./docs/04-部署运维/跨平台开发环境配置指南.md)

### 云服务器部署（Ubuntu）

→ 查看 [Ubuntu云服务器部署指南](./docs/04-部署运维/Ubuntu云服务器部署指南.md)

### Docker 一键部署

→ 查看 [Docker部署和访问指南](./docs/04-部署运维/Docker部署和访问指南.md)

### 后端详细文档

| 文档 | 路径 |
|------|------|
| 项目结构说明 | `backend/iot-hotel-backend/docs/项目结构说明.md` |
| 启动指南 | `backend/iot-hotel-backend/docs/启动指南.md` |
| 完整部署指南 | `backend/iot-hotel-backend/docs/完整部署指南.md` |
| Docker 配置说明 | `backend/iot-hotel-backend/docs/Docker配置说明.md` |
| 数据库设计 | `docs/03-软件设计/数据库设计文档.md` |
| API 接口文档 | `docs/03-软件设计/API接口文档.md` |

---

## 核心功能清单

### 管理端 (`/admin`)
- 总览仪表盘 — 设备在线率、房间状态、酒店信息概览
- 设备监控 — IoT 设备卡片列表、在线/离线状态、发送指令
- 房间信息管理 — 房间 CRUD、房型配置
- 酒店信息编辑 — 名称、星级、地址等编辑
- 账单报表 — 收入统计、账单明细、导出打印

### 前台端 (`/reception`)
- 前台总览 — 今日入住/退房、在住客人、待处理事项
- 入住退房 — 线下办理入住表单、退房结算列表
- 预订管理 — 预订列表、确认/入住/取消操作
- 客房余量 — 表格视图 + 楼层平面图双模式
- 工单处理 — 维修/清洁/服务工单、优先级、状态流转
- 客房送物 — 送物订单创建与配送跟踪
- 账单报表 — 营收统计、账单明细、收款

### 客户端 (`/guest`)
- 客房预订 — 预订表单 + 热门房型推荐
- 在线办理入住 — 四步流程（验证 → 填信息 → 确认 → 完成）
- 客房服务 — AI 管家聊天 / 送物请求 / 联系前台 / 更多服务

---

## ✅ API接口测试结果（2026-04-07）

所有新增API接口已通过测试验证：

### 📦 送物订单测试
```bash
# 创建送物订单（含新字段）
POST /api/v1/delivery
{
  "room_id": 1,
  "booking_id": 1,          # 新增：预订关联
  "guest_id": 1,            # 新增：住客关联
  "item_category": "bathroom",
  "item_name": "毛巾",
  "quantity": 2,
  "note": "测试订单"
}

# 响应：✅ 成功 (200)
{
  "code": 200,
  "message": "创建送物订单成功",
  "data": {
    "id": 1,
    "order_no": "DEL20260407F854D393"
  }
}
```

### 🔧 报修工单测试
```bash
# 创建报修工单（含新字段）
POST /api/v1/maintenance
{
  "room_id": 1,
  "booking_id": 1,          # 新增：预订关联
  "guest_id": 1,            # 新增：住客关联
  "fault_type": "electrical",
  "fault_description":灯不亮",
  "priority": "high"
}

# 响应：✅ 成功 (200)
{
  "code": 200,
  "message": "创建报修工单成功",
  "data": {
    "id": 1,
    "ticket_no": "MT20260407EAB3187F"
  }
}
```

### 👥 住客管理测试
```bash
# 获取住客列表
GET /api/v1/guests

# 响应：✅ 成功 (200)
{
  "code": 200,
  "message": "获取住客列表成功",
  "data": {
    "list": [],
    "total": 0,
    "page": 1,
    "pageSize": 10
  }
}

# 创建住客记录
POST /api/v1/guests
{
  "booking_id": 1,
  "name": "张三",
  "phone": "13800138000",
  "id_type": "身份证",
  "id_number": "110101199001011234"
}

# 响应：⚠️ 预订不存在 (500) - 需要先创建预订
```

### 📊 数据验证

查询送物订单详情确认新字段已正确存储：
```json
{
  "id": 1,
  "order_no": "DEL20260407F854D393",
  "booking_id": 1,           // ✅ 新字段已存储
  "guest_id": 1,             // ✅ 新字段已存储
  "room_id": 1,
  "item_category": "bathroom",
  "status": "pending",
  "room_number": "101"
}
```

---

## 常见问题

### Q: 前端页面报 "Failed to fetch dynamically imported module"
A: 检查 `.vue` 文件的模板闭合标签是否正确（应为 `</template>` 而非 `</a-template>`），或重启 Vite 开发服务器。

### Q: 后端 IDE 显示大量类型错误
A: 执行 **"TypeScript: Restart TS Server"**（Ctrl+Shift+P），确保 `node_modules/@types/` 已被索引。

### Q: MySQL 端口冲突（3306 被占用）
A: Docker Compose 已将 MySQL 映射到 **3307** 端口，`.env` 中需设置 `DB_PORT=3307`。

### Q: 前端代理不生效
A: Vite 代理在 `vite.config.ts` 中配置，仅对 `dev` 模式生效。生产环境需使用 Nginx 反向代理。

### Q: 移植到别的电脑上密码会变吗？
A: **不会变。** 密码写死在配置文件中，跟电脑无关。迁移步骤：

```bash
# 1. 拷贝整个项目文件夹到新电脑
# 2. 启动 Docker Desktop
# 3. 启动服务
cd backend/iot-hotel-backend
docker-compose up -d
```

MySQL 自动以相同密码创建，本地开发默认凭证：

| 配置项 | 值 | 文件 |
|--------|-----|------|
| 用户名 | `root` | `.env` |
| 密码 | `IotHotel2026` | `.env` |
| 端口 | `3307`（映射） | `.env` + `docker-compose.yml` |
| 数据库 | `iot_hotel_system` | `.env` |

> ⚠️ 若新电脑 **3307 端口被占用**，修改 `.env` 的 `DB_PORT` 和 `docker-compose.yml` 的端口映射即可，密码不受影响。

---

## 📈 版本信息

| 项目 | 版本 | 更新内容 |
|------|------|---------|
| **后端** | v2.1.0 | ✅ 新增住客管理API、送物/报修工单增强字段 |
| **前端** | v1.0.0 | 稳定版本 |
| **数据库** | v2.1.0 | ✅ 新增guests表、calls表、booking_id/guest_id字段 |
| **硬件** | v1.0.0 | 三层架构设计完成 |
| **更新日期** | 2026-04-07 | API接口测试通过 |

### 📋 更新日志

#### v2.2.0 (2026-04-13)
- **🎉 新功能**：
  - ✅ 证件类型标准化：支持中国居民身份证/外国人永久居留身份证/港澳台居民居住证（合称 idcard 类别）、港澳居民来往内地通行证、台湾居民来往大陆通行证、外国护照、其他。
  - ✅ 数据库增强：为 `bookings` 和 `guests` 表新增 `id_type` 字段，并放宽 `frequent_guests` 表证件类型限制。
  - ✅ 前端适配：在办理入住、在线入住、酒店预订、常用联系人等模块同步更新证件选择逻辑。

#### v2.1.0 (2026-04-07)
- **🎉 新功能**：
  - ✅ 住客管理系统（guests CRUD API）
  - ✅ 送物订单支持预订和住客关联（booking_id, guest_id）
  - ✅ 报修工单支持预订和住客关联
- **🔧 数据库更新**：
  - 新增 `guests` 表（住客信息）
  - 新增 `calls` 表（语音通话记录）
  - `delivery_orders` 表新增 `booking_id`, `guest_id` 字段
  - `maintenance_tickets` 表新增 `booking_id`, `guest_id` 字段
- **📝 文档更新**：
  - README.md 增加软硬件系统完整说明
  - API接口文档同步更新
- **✅ 测试验证**：
  - 所有新增API接口测试通过
  - 数据库字段正确存储和查询

#### v2.0.0 (2026-04-04)
- 初始版本发布
- 三端协同基础功能
- IoT设备监控框架

---

## 🔗 相关链接

### 📚 文档中心
- [系统需求说明](./docs/01-系统架构/README.md) - 软硬件整体需求
- [三层硬件架构设计](./docs/02-硬件设计/三层硬件架构设计说明.md) - 详细硬件方案
- [API接口文档](./docs/03-软件设计/API接口文档.md) - 完整API参考
- [数据库设计文档](./docs/03-软件设计/数据库设计文档.md) - ER图和表结构
- [部署运维指南](./docs/04-部署运维/README.md) - Docker/云服务器部署
- [项目管理文档](./docs/05-项目管理/README.md) - 分工、采购、协同

### 🛠️ 开发工具
- **后端IDE**: VS Code + TypeScript插件
- **前端IDE**: VS Code + Volar插件
- **硬件IDE**: PlatformIO (VS Code扩展)
- **API测试**: Postman / curl
- **数据库管理**: MySQL Workbench / DBeaver

---

## 👥 贡献指南

欢迎提交Issue和Pull Request！

### 开发流程
1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 提交Pull Request

### 代码规范
- 遵循现有代码风格
- 添加必要的注释
- 确保类型安全（TypeScript）
- 编写单元测试（如适用）

---

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

---

## 🙏 致谢

感谢所有为本项目做出贡献的开发者！

**特别感谢**：
- IoT技术社区的支持
- ESP32开源生态
- Vue.js和Node.js社区

---

**⭐ 如果这个项目对你有帮助，请给一个Star！**

**📧 联系我们**: [项目Issues](../../issues) | [讨论区](../../discussions)
