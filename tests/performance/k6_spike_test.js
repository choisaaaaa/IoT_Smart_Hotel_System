/**
 * K6 尖峰测试脚本
 * 模拟突发流量场景
 * 
 * 运行方式: k6 run k6_spike_test.js
 */

import http from 'k6/http';
import { check } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 50 },    // 正常负载
    { duration: '10s', target: 500 },   // 突发流量 spike
    { duration: '1m', target: 500 },    // 保持 spike
    { duration: '10s', target: 50 },    // 快速恢复
    { duration: '2m', target: 50 },     // 观察恢复情况
  ],
  thresholds: {
    http_req_duration: ['p(99)<1000'],  // 99% 请求 < 1s (尖峰容忍)
    http_req_failed: ['rate<0.1'],      // 错误率 < 10%
  },
};

const BASE_URL = __ENV.API_BASE_URL || 'http://localhost:3000';

export default function () {
  // 模拟住客端高频操作
  const res = http.get(`${BASE_URL}/health`);
  
  check(res, {
    '服务可用': (r) => r.status === 200,
    '响应时间可接受': (r) => r.timings.duration < 1000,
  });
}
