/**
 * K6 压力测试脚本
 * 用于测试系统极限负载能力
 * 
 * 运行方式: k6 run k6_stress_test.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

// 压力测试配置 - 逐步增加负载直到系统崩溃
export const options = {
  stages: [
    { duration: '1m', target: 100 },   // 快速 ramp up 到 100 用户
    { duration: '2m', target: 100 },   // 保持 100 用户
    { duration: '1m', target: 300 },   // 快速 ramp up 到 300 用户
    { duration: '2m', target: 300 },   // 保持 300 用户
    { duration: '1m', target: 500 },   // 快速 ramp up 到 500 用户
    { duration: '3m', target: 500 },   // 保持 500 用户 (目标 QPS)
    { duration: '1m', target: 800 },   // 超压测试: 800 用户
    { duration: '2m', target: 800 },   // 保持 800 用户
    { duration: '1m', target: 0 },     // 快速冷却
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 压力测试下 95% 请求 < 500ms
    http_req_failed: ['rate<0.05'],    // 错误率 < 5%
  },
};

const BASE_URL = __ENV.API_BASE_URL || 'http://localhost:3000';

export function setup() {
  console.log('🔥 压力测试开始 - 寻找系统极限');
  
  const loginRes = http.post(`${BASE_URL}/api/v1/auth/login`, JSON.stringify({
    username: 'admin',
    password: 'admin123',
  }), {
    headers: { 'Content-Type': 'application/json' },
  });

  const token = loginRes.json('data.token');
  return { token };
}

export default function (data) {
  const token = data.token;
  if (!token) return;

  const headers = {
    'Authorization': `Bearer ${token}`,
  };

  // 并发请求多个端点
  const responses = http.batch([
    ['GET', `${BASE_URL}/health`, null, { headers }],
    ['GET', `${BASE_URL}/api/v1/bookings?page=1&limit=5`, null, { headers }],
    ['GET', `${BASE_URL}/api/v1/rooms`, null, { headers }],
    ['GET', `${BASE_URL}/api/v1/devices`, null, { headers }],
  ]);

  responses.forEach((res, idx) => {
    const endpoints = ['health', 'bookings', 'rooms', 'devices'];
    const success = check(res, {
      [`${endpoints[idx]} 状态正常`]: (r) => r.status === 200,
    });
    errorRate.add(!success);
  });

  sleep(0.5);
}

export function teardown(data) {
  console.log('✅ 压力测试完成');
}
