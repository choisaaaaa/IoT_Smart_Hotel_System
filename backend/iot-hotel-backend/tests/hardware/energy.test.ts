import request from 'supertest';
import app from '../../src/app';

/**
 * 能耗管理测试
 *
 * 傻瓜教程：
 * 这个文件测试能耗管理相关的所有接口，包括：
 * 1. 能耗数据查询
 * 2. 能耗统计
 * 3. 能耗排名
 * 4. 节能建议
 *
 * 为什么需要能耗管理？
 * - 监控酒店整体能耗
 * - 发现高能耗房间
 * - 制定节能策略
 * - 降低运营成本
 */
describe('能耗管理 API', () => {
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

  /**
   * 测试：获取能耗数据
   *
   * 使用场景：
   * - 查看某房间的用电量
   * - 按时间范围查询能耗
   */
  describe('GET /api/v1/energy/consumption - 获取能耗数据', () => {
    it('应该返回能耗数据', async () => {
      const res = await request(app)
        .get('/api/v1/energy/consumption?start_date=2024-01-01&end_date=2024-12-31')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('total_consumption');
      expect(res.body.data).toHaveProperty('unit');
    });

    it('应该支持按房间筛选', async () => {
      const res = await request(app)
        .get('/api/v1/energy/consumption?room_id=101&start_date=2024-01-01&end_date=2024-12-31')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    it('应该支持按能耗类型筛选', async () => {
      const res = await request(app)
        .get('/api/v1/energy/consumption?consumption_type=electricity&start_date=2024-01-01&end_date=2024-12-31')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  /**
   * 测试：上报能耗数据（设备端）
   *
   * 使用场景：
   * - 智能电表定时上报用电量
   * - 设备上报功耗数据
   */
  describe('POST /api/v1/energy/consumption - 上报能耗数据', () => {
    it('应该成功记录能耗数据', async () => {
      const res = await request(app)
        .post('/api/v1/energy/consumption')
        .send({
          device_id: 'smart_meter_001',
          room_id: 101,
          consumption_type: 'electricity',
          consumption_value: 25.5,
          unit: 'kwh',
          record_date: '2024-01-15',
          record_hour: 14
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  /**
   * 测试：获取能耗统计
   *
   * 使用场景：
   * - 生成能耗报表
   * - 分析能耗趋势
   */
  describe('GET /api/v1/energy/stats - 获取能耗统计', () => {
    it('应该返回能耗统计数据', async () => {
      const res = await request(app)
        .get('/api/v1/energy/stats?start_date=2024-01-01&end_date=2024-12-31')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('total');
      expect(res.body.data).toHaveProperty('by_type');
      expect(res.body.data).toHaveProperty('trend');
    });
  });

  /**
   * 测试：获取能耗排名
   *
   * 使用场景：
   * - 找出高能耗房间
   * - 能耗对比分析
   */
  describe('GET /api/v1/energy/ranking - 获取能耗排名', () => {
    it('应该返回能耗排名', async () => {
      const res = await request(app)
        .get('/api/v1/energy/ranking?date_range=7d')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('ranking');
    });

    it('应该支持正序和倒序排列', async () => {
      const resDesc = await request(app)
        .get('/api/v1/energy/ranking?order=desc')
        .set('Authorization', `Bearer ${authToken}`);

      const resAsc = await request(app)
        .get('/api/v1/energy/ranking?order=asc')
        .set('Authorization', `Bearer ${authToken}`);

      expect(resDesc.status).toBe(200);
      expect(resAsc.status).toBe(200);
    });
  });

  /**
   * 测试：获取节能建议
   *
   * 使用场景：
   * - 系统自动生成节能建议
   * - 指导酒店节能优化
   */
  describe('GET /api/v1/energy/suggestions - 获取节能建议', () => {
    it('应该返回节能建议', async () => {
      const res = await request(app)
        .get('/api/v1/energy/suggestions')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('suggestions');
      expect(Array.isArray(res.body.data.suggestions)).toBe(true);
    });

    it('应该支持按房间获取建议', async () => {
      const res = await request(app)
        .get('/api/v1/energy/suggestions?room_id=101')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });
});
