# 测试包使用教程（傻瓜版）

## 📚 目录

1. [测试架构说明](#测试架构说明)
2. [本地测试（HTTP API）](#本地测试http-api)
3. [云端测试（MQTT）](#云端测试mqtt)
4. [常见问题](#常见问题)

---

## 测试架构说明

本项目测试分为两套，分别运行在不同环境：

```
tests/
├── local/                     # 【本地测试】HTTP API
│   ├── api.test.ts           # 基础API测试
│   ├── auth.test.ts          # 认证测试
│   ├── booking.test.ts       # 预订测试
│   └── utils.test.ts         # 工具函数测试
├── cloud/                     # 【云端测试】MQTT
│   ├── mqtt-connection.test.ts  # MQTT连接测试
│   └── device-control.test.ts   # 设备控制测试
└── README.md                  # 本教程
```

| 测试类型 | 运行环境 | 测试内容 | 是否需要云端 |
|---------|---------|---------|-------------|
| **Local** | 本地开发机 | HTTP API接口 | ❌ 不需要 |
| **Cloud** | 云端服务器 | MQTT通信、设备控制 | ✅ 需要 |

---

## 本地测试（HTTP API）

### 适用场景
- 开发阶段快速验证API接口
- 本地数据库操作测试
- 无需连接云端MQTT

### 运行方式

```bash
# 进入后端目录
cd backend/iot-hotel-backend

# 安装依赖
npm install

# 配置数据库（确保本地MySQL已启动）
# 修改 src/__tests__/setup.ts 中的数据库配置

# 运行所有本地测试
npm test -- tests/local

# 运行特定测试文件
npm test -- tests/local/api.test.ts
npm test -- tests/local/auth.test.ts
npm test -- tests/local/booking.test.ts
npm test -- tests/local/utils.test.ts

# 生成覆盖率报告
npm run test:coverage -- tests/local
```

### 测试内容

| 文件 | 测试范围 |
|------|---------|
| api.test.ts | 健康检查、认证接口、404处理 |
| auth.test.ts | JWT工具函数测试 |
| booking.test.ts | 预订CRUD操作 |
| utils.test.ts | 通用工具函数 |

---

## 云端测试（MQTT）

### 适用场景
- 验证MQTT连接是否正常
- 测试设备控制指令下发
- 测试传感器数据接收
- 部署到云端后验证物联网功能

### 运行环境要求

**方式1：在云端服务器运行（推荐）**
```bash
# SSH连接到云端服务器
ssh root@8.134.166.69

# 进入项目目录
cd /path/to/iot-hotel-backend

# 运行云端测试
npm test -- tests/cloud
```

**方式2：本地运行（需要网络连接）**
```bash
# 确保能访问云端MQTT端口（1883）
telnet 8.134.166.69 1883

# 运行测试
npm test -- tests/cloud
```

**方式3：跳过云端测试（本地开发时）**
```bash
# 设置环境变量跳过MQTT测试
SKIP_MQTT_TESTS=true npm test
```

### 运行方式

```bash
# 运行所有云端测试
npm test -- tests/cloud

# 运行特定测试文件
npm test -- tests/cloud/mqtt-connection.test.ts
npm test -- tests/cloud/device-control.test.ts

# 使用本地MQTT Broker测试（开发调试）
# 修改测试文件中的 MQTT_CONFIG.host 为 'mqtt://localhost:1883'
```

### 测试内容

| 文件 | 测试范围 |
|------|---------|
| mqtt-connection.test.ts | MQTT连接、订阅、发布、消息接收 |
| device-control.test.ts | 灯光控制、空调控制、窗帘控制、传感器数据 |

### MQTT配置

```typescript
const MQTT_CONFIG = {
  host: 'mqtt://8.134.166.69:1883',  // 云端MQTT地址
  username: 'hotel_device',
  password: 'device_secret',
  keepalive: 60,
};
```

---

## 完整测试流程

### 本地开发阶段
```bash
# 1. 启动本地MySQL
# 2. 启动后端服务
npm run dev

# 3. 运行本地API测试
npm test -- tests/local
```

### 部署到云端后
```bash
# 1. SSH登录云端服务器
ssh root@8.134.166.69

# 2. 进入项目目录
cd /path/to/project/backend/iot-hotel-backend

# 3. 运行云端MQTT测试
npm test -- tests/cloud

# 4. 运行完整测试套件
npm test
```

---

## 常见问题

### Q1: 本地运行云端测试报错 "Connection refused"

**原因**：本地无法连接到云端的MQTT Broker（端口1883可能被防火墙阻挡）

**解决方案**：
1. 在云端服务器上运行测试
2. 配置VPN连接到云端内网
3. 本地搭建MQTT Broker进行测试
4. 设置 `SKIP_MQTT_TESTS=true` 跳过MQTT测试

### Q2: 如何只运行本地测试？

```bash
npm test -- tests/local
```

### Q3: 如何只运行云端测试？

```bash
npm test -- tests/cloud
```

### Q4: 如何在CI/CD中配置测试？

```yaml
# .github/workflows/test.yml
jobs:
  local-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Local Tests
        run: npm test -- tests/local
  
  cloud-tests:
    runs-on: self-hosted  # 使用云端runner
    steps:
      - uses: actions/checkout@v2
      - name: Run Cloud Tests
        run: npm test -- tests/cloud
```

### Q5: 本地如何模拟MQTT测试？

**安装本地MQTT Broker：**
```bash
# Windows
# 下载 mosquitto: https://mosquitto.org/download/
# 启动服务: mosquitto -p 1883

# Mac
brew install mosquitto
brew services start mosquitto

# Linux
sudo apt install mosquitto
sudo systemctl start mosquitto
```

**修改测试配置：**
```typescript
// 在测试文件中临时修改
const MQTT_CONFIG = {
  host: 'mqtt://localhost:1883',  // 改为本地地址
  // ...
};
```

---

## 测试编写规范

### 本地测试示例
```typescript
describe('API接口测试', () => {
  it('应该返回健康状态', async () => {
    const res = await request(app).get('/api/v1/health');
    expect(res.status).toBe(200);
    expect(res.body.code).toBe(200);
  });
});
```

### 云端测试示例
```typescript
describe('MQTT测试', () => {
  const shouldSkip = process.env.SKIP_MQTT_TESTS === 'true';
  
  (shouldSkip ? describe.skip : describe)('连接测试', () => {
    it('应该连接到MQTT', (done) => {
      // MQTT测试代码
    });
  });
});
```

---

## 联系支持

如有问题，请联系开发团队或提交 Issue。

**Happy Testing! 🧪**
