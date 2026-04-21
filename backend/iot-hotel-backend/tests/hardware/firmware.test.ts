import request from 'supertest';
import app from '../../src/app';

/**
 * 固件升级管理测试
 *
 * 傻瓜教程：
 * 这个文件测试固件升级相关的所有接口，包括：
 * 1. 升级任务管理
 * 2. 升级进度查询
 * 3. 升级任务取消
 *
 * 为什么需要固件升级？
 * - 修复设备bug
 * - 添加新功能
 * - 提升设备性能
 * - 安全补丁更新
 */
describe('固件升级管理 API', () => {
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
   * 测试：获取升级记录
   */
  describe('GET /api/v1/firmware/updates - 获取升级记录', () => {
    it('应该返回升级记录列表', async () => {
      const res = await request(app)
        .get('/api/v1/firmware/updates')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('list');
      expect(res.body.data).toHaveProperty('pagination');
    });

    it('应该支持按设备筛选', async () => {
      const res = await request(app)
        .get('/api/v1/firmware/updates?device_id=device001')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    it('应该支持按状态筛选', async () => {
      const res = await request(app)
        .get('/api/v1/firmware/updates?update_status=success')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  /**
   * 测试：发起固件升级
   *
   * 使用场景：
   * - 管理员批量升级设备固件
   * - 定时升级任务
   */
  describe('POST /api/v1/firmware/updates - 发起固件升级', () => {
    it('应该成功创建升级任务', async () => {
      const res = await request(app)
        .post('/api/v1/firmware/updates')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          device_ids: ['device001', 'device002'],
          firmware_version: 'v2.1.0',
          firmware_url: 'https://example.com/firmware/v2.1.0.bin'
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('updates');
    });

    it('缺少必要参数时应该返回400', async () => {
      const res = await request(app)
        .post('/api/v1/firmware/updates')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          firmware_version: 'v2.1.0'
        });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });
  });

  /**
   * 测试：取消升级任务
   */
  describe('POST /api/v1/firmware/updates/:id/cancel - 取消升级任务', () => {
    it('应该成功取消待处理的升级任务', async () => {
      // 先创建一个升级任务
      const createRes = await request(app)
        .post('/api/v1/firmware/updates')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          device_ids: ['device003'],
          firmware_version: 'v2.1.0',
          firmware_url: 'https://example.com/firmware/v2.1.0.bin'
        });

      const updateId = createRes.body.data?.updates?.[0]?.id || 1;

      const res = await request(app)
        .post(`/api/v1/firmware/updates/${updateId}/cancel`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  /**
   * 测试：上报升级进度（设备端）
   *
   * 使用场景：
   * - 设备上报升级进度
   * - 设备上报升级结果
   */
  describe('POST /api/v1/firmware/progress - 上报升级进度', () => {
    it('应该成功上报升级进度', async () => {
      const res = await request(app)
        .post('/api/v1/firmware/progress')
        .send({
          device_id: 'device001',
          update_id: 1,
          progress: 50,
          status: 'updating'
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    it('应该成功上报升级完成', async () => {
      const res = await request(app)
        .post('/api/v1/firmware/progress')
        .send({
          device_id: 'device001',
          update_id: 1,
          status: 'success'
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    it('应该成功上报升级失败', async () => {
      const res = await request(app)
        .post('/api/v1/firmware/progress')
        .send({
          device_id: 'device001',
          update_id: 1,
          status: 'failed',
          error_message: 'Download timeout'
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });
});
