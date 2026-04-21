import request from 'supertest';
import app from '../../../app';

// RFID门禁管理测试
// 傻瓜教程：这个文件测试RFID房卡和门禁记录相关的所有接口

describe('RFID门禁管理 API', () => {
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

  describe('GET /api/v1/rfid-access/logs - 获取门禁记录', () => {
    it('应该返回门禁记录列表', async () => {
      const res = await request(app)
        .get('/api/v1/rfid-access/logs')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('list');
      expect(res.body.data).toHaveProperty('pagination');
    });

    it('应该支持按卡号筛选', async () => {
      const res = await request(app)
        .get('/api/v1/rfid-access/logs?card_uid=ABC123')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    it('应该支持按时间范围筛选', async () => {
      const res = await request(app)
        .get('/api/v1/rfid-access/logs?start_date=2024-01-01&end_date=2024-12-31')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  describe('GET /api/v1/rfid-access/logs/stats - 获取门禁统计', () => {
    it('应该返回门禁统计数据', async () => {
      const res = await request(app)
        .get('/api/v1/rfid-access/logs/stats')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('total_access');
      expect(res.body.data).toHaveProperty('success_count');
      expect(res.body.data).toHaveProperty('failed_count');
    });
  });

  describe('POST /api/v1/rfid-access/logs - 上报门禁记录（设备端）', () => {
    it('应该成功记录门禁刷卡', async () => {
      const res = await request(app)
        .post('/api/v1/rfid-access/logs')
        .send({
          card_uid: 'TEST123456',
          room_id: 101,
          device_id: 'room_terminal_001',
          access_type: 'entry',
          access_result: 'success'
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    it('应该记录失败的刷卡', async () => {
      const res = await request(app)
        .post('/api/v1/rfid-access/logs')
        .send({
          card_uid: 'INVALID_CARD',
          room_id: 101,
          device_id: 'room_terminal_001',
          access_type: 'entry',
          access_result: 'failed',
          fail_reason: 'Card not authorized'
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  describe('POST /api/v1/rfid-access/verify - 验证房卡权限（设备端）', () => {
    it('应该验证有效房卡', async () => {
      const res = await request(app)
        .post('/api/v1/rfid-access/verify')
        .send({
          card_uid: 'VALID_CARD_001',
          room_id: 101,
          device_id: 'room_terminal_001',
          device_key: 'device_secret_key'
        });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('valid');
    });

    it('应该拒绝无效房卡', async () => {
      const res = await request(app)
        .post('/api/v1/rfid-access/verify')
        .send({
          card_uid: 'INVALID_CARD',
          room_id: 101,
          device_id: 'room_terminal_001',
          device_key: 'device_secret_key'
        });

      expect(res.status).toBe(200);
      expect(res.body.valid).toBe(false);
    });
  });
});
