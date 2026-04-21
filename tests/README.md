# 慧宿智联测试套件

智能酒店物联网系统全面测试解决方案

## 📁 目录结构

```
tests/
├── api/                    # API 接口测试
│   ├── postman_collection.json    # Postman 测试集合
│   └── newman_runner.js           # Newman 自动化运行器
├── performance/            # 性能测试
│   ├── k6_load_test.js           # K6 负载测试
│   ├── k6_stress_test.js         # K6 压力测试
│   ├── k6_spike_test.js          # K6 尖峰测试
│   └── jmeter_test_plan.jmx      # JMeter 测试计划
├── e2e/                    # 端到端测试
│   ├── playwright.config.ts      # Playwright 配置
│   └── specs/                    # 测试用例
│       ├── auth.spec.ts          # 认证测试
│       ├── booking.spec.ts       # 预订流程测试
│       └── device.spec.ts        # 设备控制测试
├── scripts/                # 测试脚本
│   └── generate_test_report.js   # 报告生成器
├── reports/                # 测试报告输出目录
└── package.json           # 测试套件依赖
```

## 🚀 快速开始

### 1. 安装依赖

```bash
cd tests
npm install
```

### 2. 运行测试

#### 后端单元测试
```bash
npm run test:backend
```

#### 前端单元测试
```bash
npm run test:frontend
```

#### API 接口测试
```bash
npm run test:api
```

#### 性能测试 (需要安装 K6)
```bash
# 负载测试
npm run test:perf:load

# 压力测试
npm run test:perf:stress

# 尖峰测试
npm run test:perf:spike
```

#### E2E 测试 (需要安装 Playwright)
```bash
# 运行所有 E2E 测试
npm run test:e2e

# 交互式调试模式
npm run test:e2e:ui

# 查看测试报告
npm run test:e2e:report
```

### 3. 生成统一测试报告

```bash
npm run report:generate
```

报告将生成在 `tests/reports/unified_test_report.html`

## 📊 测试覆盖范围

### 功能测试
- ✅ 用户认证 (登录/权限控制)
- ✅ 预订管理 (创建/查询/入住/退房)
- ✅ 房间管理 (状态/价格/房型)
- ✅ 设备控制 (IoT 设备/场景模式)
- ✅ AI 管家 (语音交互/知识库)
- ✅ 会员系统 (积分/等级/优惠券)

### 性能测试
- ✅ API 响应时间 (< 150ms)
- ✅ 并发负载 (500 QPS)
- ✅ 压力测试 (800+ 并发用户)
- ✅ 尖峰流量测试

### 兼容性测试
- ✅ Node.js v20/v24
- ✅ Chrome, Edge, Safari, Firefox
- ✅ Android 12+, iOS 15+
- ✅ Docker 容器化部署

## 🛠️ 工具链

| 测试类型 | 工具 | 版本 |
|---------|------|------|
| 单元测试 | Jest | ^29.7.0 |
| 单元测试 | Vitest | ^1.0.0 |
| API 测试 | Postman/Newman | ^6.0.0 |
| 性能测试 | K6 | latest |
| 性能测试 | JMeter | 5.6+ |
| E2E 测试 | Playwright | ^1.40.0 |

## 📈 测试指标

### 覆盖率目标
- 语句覆盖率: ≥ 90%
- 分支覆盖率: ≥ 85%
- 函数覆盖率: ≥ 90%
- 行覆盖率: ≥ 90%

### 性能指标
- API 平均响应: < 150ms (本地) / < 300ms (远程)
- WebSocket 延迟: < 50ms
- 并发连接: 1000+
- 吞吐量: 500 QPS

## 🔧 环境配置

### 环境变量

```bash
# API 测试
export API_BASE_URL=http://localhost:3000

# 性能测试
export BASE_URL=http://localhost:3000

# E2E 测试
export BASE_URL=http://localhost:5173
```

### CI/CD 集成

```yaml
# .github/workflows/test.yml
- name: Run Tests
  run: |
    npm ci
    npm run test:backend
    npm run test:frontend
    npm run test:api
    npm run report:generate
```

## 📝 测试用例示例

### API 测试 (Postman/Newman)

```javascript
// 登录测试
pm.test('登录成功', function () {
    pm.response.to.have.status(200);
    var jsonData = pm.response.json();
    pm.expect(jsonData.data.token).to.exist;
    pm.environment.set('token', jsonData.data.token);
});

pm.test('响应时间小于 200ms', function () {
    pm.expect(pm.response.responseTime).to.be.below(200);
});
```

### 性能测试 (K6)

```javascript
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 100 },
    { duration: '5m', target: 100 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<300'],
  },
};

export default function () {
  const res = http.get('http://localhost:3000/health');
  check(res, {
    '状态 200': (r) => r.status === 200,
  });
}
```

### E2E 测试 (Playwright)

```typescript
import { test, expect } from '@playwright/test';

test('管理员登录', async ({ page }) => {
  await page.goto('/login');
  await page.fill('input[name="username"]', 'admin');
  await page.fill('input[name="password"]', 'admin123');
  await page.click('button[type="submit"]');
  await expect(page).toHaveURL(/.*admin.*/);
});
```

## 🤝 贡献指南

1. 添加新测试时遵循现有目录结构
2. 测试文件名使用 `.test.ts` 或 `.spec.ts` 后缀
3. 保持测试用例的独立性和可重复性
4. 添加适当的注释说明测试目的

## 📄 许可证

MIT License - 慧宿智联团队
