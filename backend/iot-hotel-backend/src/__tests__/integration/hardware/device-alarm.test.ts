import request from 'supertest';
import app from '../../../app';

// 设备告警管理测试
// 傻瓜教程：这个文件测试设备告警相关的所有接口

describe('设备告警管理 API', () => {
  let authToken: string;

  beforeAll(async () => {
    const loginRes = await request(app)
      .post('/api/v1/auth/login')
      .send({
        phone: '13800138000',
        password: 'password123'
      });
    authToken = loginRes.body.data?.token || 'test-token';
  });

  describe('GET /api/v1/device-alarms - 获取告警列表', () => {
    it('应该返回告警列表', async () => {
      const res = await request(app)
        .get('/api/v1/device-alarms')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('list');
      expect(res.body.data).toHaveProperty('pagination');
    });

    it('应该支持按告警类型筛选', async () => {
      const res = await request(app)
        .get('/api/v1/device-alarms?alarm_type=sos')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    it('应该支持按告警级别筛选', async () => {
      const res = await request(app)
        .get('/api/v1/device-alarms?alarm_level=emergency')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  describe('GET /api/v1/device-alarms/stats - 获取告警统计', () => {
    it('应该返回告警统计数据', async () => {
      const res = await request(app)
        .get('/api/v1/device-alarms/stats')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('total_count');
      expect(res.body.data).toHaveProperty('pending_count');
      expect(res.body.data).toHaveProperty('by_type');
      expect(res.body.data).toHaveProperty('by_level');
    });
  });

  describe('PUT /api/v1/device-alarms/:id/handle - 处理告警', () => {
    it('应该成功处理告警为已解决', async () => {
      // 先创建一个测试告警
      const createRes = await request(app)
        .post('/api/v1/device-alarms')
        .send({
          device_id: 'test-device',
          hotel_id: 1,
          room_id: 1,
          alarm_type: 'sensor_error',
          alarm_level: 'warning',
          alarm_content: '测试告警'
        });

      const alarmId = createRes.body.data?.id || 1;

      const res = await request(app)
        .put(`/api/v1/device-alarms/${alarmId}/handle`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          status: 'resolved',
          handle_remark: '已修复传感器'
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  describe('POST /api/v1/device-alarms - 创建设备告警（设备端）', () => {
    it('应该成功创建告警', async () => {
      const res = await request(app)
        .post('/api/v1/device-alarms')
        .send({
          device_id: 'test-device-001',
          hotel_id: 1,
          room_id: 101,
          alarm_type: 'offline',
          alarm_level: 'critical',
          alarm_content: '设备离线超过5分钟'
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('id');
    });

    it('缺少必要参数时应该返回400', async () => {
      const res = await request(app)
        .post('/api/v1/device-alarms')
        .send({
          device_id: 'test-device'
        });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });
  });
});
