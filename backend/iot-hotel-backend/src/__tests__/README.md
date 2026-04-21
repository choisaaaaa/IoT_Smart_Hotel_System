# 测试包使用教程（傻瓜版）

## 📚 目录

1. [快速开始](#快速开始)
2. [测试结构说明](#测试结构说明)
3. [如何运行测试](#如何运行测试)
4. [硬件接口测试详解](#硬件接口测试详解)
5. [常见问题](#常见问题)

---

## 快速开始

### 1. 安装依赖

```bash
cd backend/iot-hotel-backend
npm install
```

### 2. 配置测试环境

确保 `src/__tests__/setup.ts` 中的数据库配置正确：

```typescript
process.env.DB_HOST = 'localhost';
process.env.DB_PORT = '3306';
process.env.DB_USER = 'your_username';
process.env.DB_PASSWORD = 'your_password';
process.env.DB_NAME = 'test_db';
```

### 3. 运行测试

```bash
# 运行所有测试
npm test

# 运行测试并监视文件变化
npm run test:watch

# 生成测试覆盖率报告
npm run test:coverage

# 只运行硬件相关测试
npm test -- hardware

# 只运行特定测试文件
npm test -- device-group.test.ts
```

---

## 测试结构说明

```
src/__tests__/
├── setup.ts                    # 测试环境配置
├── integration/                # 集成测试
│   ├── api.test.ts            # 基础API测试
│   ├── booking.test.ts        # 预订相关测试
│   └── hardware/              # 【新增】硬件接口测试
│       ├── device-group.test.ts      # 设备分组测试
│       ├── device-alarm.test.ts      # 设备告警测试
│       ├── rfid-access.test.ts       # RFID门禁测试
│       ├── ir-remote.test.ts         # 红外遥控测试
│       ├── scene.test.ts             # 场景模式测试
│       ├── energy.test.ts            # 能耗管理测试
│       └── firmware.test.ts          # 固件升级测试
└── unit/                       # 单元测试
    ├── auth.test.ts
    └── utils.test.ts
```

---

## 如何运行测试

### 运行全部测试

```bash
npm test
```

### 只运行硬件相关测试

```bash
# 方法1：使用测试名称匹配
npm test -- --testNamePattern="设备|硬件|RFID|红外|场景|能耗|固件"

# 方法2：使用文件路径匹配
npm test -- hardware/

# 方法3：运行特定文件
npm test -- device-group.test.ts
```

### 运行测试并生成报告

```bash
# 生成HTML覆盖率报告
npm run test:coverage

# 报告位置：coverage/lcov-report/index.html
```

---

## 硬件接口测试详解

### 1. 设备分组管理测试 (`device-group.test.ts`)

**测试内容：**
- ✅ 创建设备分组
- ✅ 获取分组列表
- ✅ 更新分组信息
- ✅ 添加设备到分组
- ✅ 批量控制分组设备
- ✅ 删除分组

**使用场景：**
```typescript
// 示例：将1楼所有设备分为一组
const group = {
  group_name: '1楼设备组',
  group_type: 'floor',
  description: '包含1楼所有客房设备'
};
```

**运行测试：**
```bash
npm test -- device-group.test.ts
```

---

### 2. 设备告警管理测试 (`device-alarm.test.ts`)

**测试内容：**
- ✅ 获取告警列表
- ✅ 告警统计查询
- ✅ 处理告警（标记为已解决/已忽略）
- ✅ 创建设备告警（设备端上报）

**告警类型说明：**
| 类型 | 说明 | 级别 |
|:---|:---|:---|
| `sos` | 紧急呼叫 | emergency |
| `offline` | 设备离线 | critical |
| `sensor_error` | 传感器异常 | warning |
| `fire` | 火警 | emergency |
| `intrusion` | 入侵检测 | critical |

**运行测试：**
```bash
npm test -- device-alarm.test.ts
```

---

### 3. RFID门禁测试 (`rfid-access.test.ts`)

**测试内容：**
- ✅ 获取门禁刷卡记录
- ✅ 门禁统计查询
- ✅ 上报门禁记录（设备端）
- ✅ 验证房卡权限（设备端）

**刷卡结果类型：**
- `success` - 刷卡成功
- `failed` - 刷卡失败
- `expired` - 卡片已过期
- `invalid` - 无效卡片

**运行测试：**
```bash
npm test -- rfid-access.test.ts
```

---

### 4. 红外遥控测试 (`ir-remote.test.ts`)

**测试内容：**
- ✅ 获取红外码列表
- ✅ 添加红外码
- ✅ 发送红外指令
- ✅ 获取品牌列表

**支持的设备类型：**
- `ac` - 空调
- `tv` - 电视
- `curtain` - 窗帘
- `light` - 灯光

**运行测试：**
```bash
npm test -- ir-remote.test.ts
```

---

### 5. 场景模式测试 (`scene.test.ts`)

**测试内容：**
- ✅ 创建场景
- ✅ 获取场景列表
- ✅ 执行场景
- ✅ 获取执行历史
- ✅ 初始化默认场景

**预设场景：**
| 场景 | 说明 |
|:---|:---|
| 欢迎模式 | 开灯、开空调24℃ |
| 睡眠模式 | 关灯、关窗帘、空调26℃ |
| 离家模式 | 关闭所有电器 |
| 节能模式 | 空调28℃、关闭部分灯光 |

**运行测试：**
```bash
npm test -- scene.test.ts
```

---

### 6. 能耗管理测试 (`energy.test.ts`)

**测试内容：**
- ✅ 获取能耗数据
- ✅ 上报能耗数据（设备端）
- ✅ 能耗统计
- ✅ 能耗排名
- ✅ 节能建议

**能耗类型：**
- `electricity` - 电能
- `water` - 水
- `gas` - 燃气

**运行测试：**
```bash
npm test -- energy.test.ts
```

---

### 7. 固件升级测试 (`firmware.test.ts`)

**测试内容：**
- ✅ 获取升级记录
- ✅ 发起固件升级
- ✅ 取消升级任务
- ✅ 上报升级进度（设备端）

**升级状态：**
- `pending` - 待升级
- `downloading` - 下载中
- `updating` - 升级中
- `success` - 升级成功
- `failed` - 升级失败
- `rolled_back` - 已回滚

**运行测试：**
```bash
npm test -- firmware.test.ts
```

---

## 常见问题

### Q1: 测试报错 "Cannot connect to database"

**解决方法：**
1. 检查数据库服务是否启动
2. 检查 `setup.ts` 中的数据库配置
3. 确保测试数据库存在

```bash
# 创建测试数据库
mysql -u root -p -e "CREATE DATABASE test_db CHARACTER SET utf8mb4;"
```

### Q2: 测试报错 "JWT Token invalid"

**解决方法：**
- 测试中的登录信息是示例，需要替换为真实的测试账号
- 修改测试文件中的登录信息：

```typescript
const loginRes = await request(app)
  .post('/api/v1/auth/login')
  .send({
    phone: '你的测试手机号',
    password: '你的测试密码'
  });
```

### Q3: 如何添加新的测试用例？

**步骤：**
1. 在对应的测试文件中添加 `it()` 测试块
2. 使用 `describe()` 组织相关测试
3. 运行测试验证

**示例：**
```typescript
describe('新功能测试', () => {
  it('应该成功执行某某操作', async () => {
    const res = await request(app)
      .post('/api/v1/xxx')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ /* 请求数据 */ });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});
```

### Q4: 如何跳过某些测试？

**方法：**
```typescript
// 跳过单个测试
it.skip('这个测试暂时跳过', async () => { ... });

// 跳过整个测试组
describe.skip('这组测试暂时跳过', () => { ... });

// 只运行特定测试
it.only('只运行这个测试', async () => { ... });
```

### Q5: 测试覆盖率不达标怎么办？

**查看覆盖率报告：**
```bash
npm run test:coverage
# 然后打开 coverage/lcov-report/index.html
```

**提升覆盖率的方法：**
1. 为未覆盖的代码添加测试用例
2. 检查是否有死代码需要删除
3. 确保所有分支都有测试

---

## 测试编写规范

### 命名规范
```typescript
// 好的命名
describe('POST /api/v1/device-groups - 创建设备分组', () => {
  it('应该成功创建一个新的设备分组', async () => { ... });
  it('缺少分组名称时应该返回400错误', async () => { ... });
});

// 不好的命名
describe('test1', () => {
  it('test', async () => { ... });
});
```

### 断言规范
```typescript
// 检查状态码
expect(res.status).toBe(200);

// 检查响应结构
expect(res.body.success).toBe(true);
expect(res.body.data).toHaveProperty('id');

// 检查数组
expect(Array.isArray(res.body.data.list)).toBe(true);

// 检查错误
expect(res.status).toBe(400);
expect(res.body.success).toBe(false);
```

---

## 联系支持

如有问题，请联系开发团队或提交 Issue。

**Happy Testing! 🧪**
