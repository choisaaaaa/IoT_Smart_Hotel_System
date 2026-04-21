/**
 * K6 性能测试脚本
 * 用于测试慧宿智联系统在高并发下的性能表现
 * 
 * 运行方式:
 * 1. 安装 K6: https://k6.io/docs/get-started/installation/
 * 2. 运行测试: k6 run k6_load_test.js
 * 3. 带参数运行: k6 run --vus 100 --duration 5m k6_load_test.js
 */

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// 自定义指标
const errorRate = new Rate('errors');
const apiResponseTime = new Trend('api_response_time');
const successCounter = new Counter('successful_requests');

// 测试配置
export const options = {
  stages: [
    { duration: '2m', target: 50 },   // 预热阶段: 2分钟 ramp up 到 50 用户
    { duration: '5m', target: 50 },   // 稳定阶段: 5分钟保持 50 用户
    { duration: '2m', target: 100 },  // 加压阶段: 2分钟 ramp up 到 100 用户
    { duration: '5m', target: 100 },  // 峰值阶段: 5分钟保持 100 用户
    { duration: '2m', target: 200 },  // 压力测试: 2分钟 ramp up 到 200 用户
    { duration: '3m', target: 200 },  // 压力保持: 3分钟保持 200 用户
    { duration: '2m', target: 0 },    // 冷却阶段: 2分钟 ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<300'],  // 95% 的请求响应时间 < 300ms
    http_req_failed: ['rate<0.01'],    // 错误率 < 1%
    errors: ['rate<0.05'],             // 自定义错误率 < 5%
  },
};

// 基础 URL
const BASE_URL = __ENV.API_BASE_URL || 'http://localhost:3000';

// 测试数据
const testData = {
  username: 'admin',
  password: 'admin123',
  guestPhone: '13800138000',
};

// 设置函数 - 每个 VU 执行一次
export function setup() {
  console.log('🚀 性能测试开始');
  console.log(`📍 目标服务器: ${BASE_URL}`);
  
  // 登录获取 token
  const loginRes = http.post(`${BASE_URL}/api/v1/auth/login`, JSON.stringify({
    username: testData.username,
    password: testData.password,
  }), {
    headers: { 'Content-Type': 'application/json' },
  });

  const loginSuccess = check(loginRes, {
    '登录成功': (r) => r.status === 200,
    '获取到 token': (r) => r.json('data.token') !== undefined,
  });

  if (!loginSuccess) {
    console.error('❌ 登录失败，测试终止');
    return { token: null };
  }

  const token = loginRes.json('data.token');
  console.log('✅ 登录成功，获取到 token');

  return { token };
}

// 主测试函数 - 每个 VU 循环执行
export default function (data) {
  const token = data.token;
  
  if (!token) {
    console.error('Token 无效，跳过测试');
    return;
  }

  const headers = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`,
  };

  group('核心链路测试', () => {
    // 1. 系统健康检查
    group('健康检查', () => {
      const res = http.get(`${BASE_URL}/health`);
      const success = check(res, {
        '健康检查状态 200': (r) => r.status === 200,
        '服务状态健康': (r) => r.json('status') === 'healthy',
      });
      errorRate.add(!success);
      apiResponseTime.add(res.timings.duration);
      if (success) successCounter.add(1);
    });

    sleep(1);

    // 2. 获取预订列表
    group('预订列表查询', () => {
      const res = http.get(`${BASE_URL}/api/v1/bookings?page=1&limit=10`, {
        headers: headers,
      });
      const success = check(res, {
        '预订列表状态 200': (r) => r.status === 200,
        '返回列表数据': (r) => r.json('data.list') !== undefined,
      });
      errorRate.add(!success);
      apiResponseTime.add(res.timings.duration);
      if (success) successCounter.add(1);
    });

    sleep(1);

    // 3. 获取房间列表
    group('房间列表查询', () => {
      const res = http.get(`${BASE_URL}/api/v1/rooms`, {
        headers: headers,
      });
      const success = check(res, {
        '房间列表状态 200': (r) => r.status === 200,
        '返回房间数据': (r) => Array.isArray(r.json('data')),
      });
      errorRate.add(!success);
      apiResponseTime.add(res.timings.duration);
      if (success) successCounter.add(1);
    });

    sleep(1);

    // 4. 获取设备列表
    group('设备列表查询', () => {
      const res = http.get(`${BASE_URL}/api/v1/devices`, {
        headers: headers,
      });
      const success = check(res, {
        '设备列表状态 200': (r) => r.status === 200,
        '返回设备数据': (r) => Array.isArray(r.json('data')),
      });
      errorRate.add(!success);
      apiResponseTime.add(res.timings.duration);
      if (success) successCounter.add(1);
    });

    sleep(1);

    // 5. 获取用户信息
    group('用户信息查询', () => {
      const res = http.get(`${BASE_URL}/api/v1/users?page=1&limit=10`, {
        headers: headers,
      });
      const success = check(res, {
        '用户列表状态 200': (r) => r.status === 200,
        '返回用户数据': (r) => r.json('data.users') !== undefined,
      });
      errorRate.add(!success);
      apiResponseTime.add(res.timings.duration);
      if (success) successCounter.add(1);
    });
  });

  sleep(2);
}

// 清理函数 - 测试结束后执行
export function teardown(data) {
  console.log('🏁 性能测试结束');
  console.log('');
  console.log('📊 测试指标说明:');
  console.log('  - http_req_duration: HTTP 请求响应时间');
  console.log('  - http_req_failed: HTTP 请求失败率');
  console.log('  - api_response_time: API 平均响应时间');
  console.log('  - errors: 自定义错误率');
  console.log('  - successful_requests: 成功请求计数');
}
