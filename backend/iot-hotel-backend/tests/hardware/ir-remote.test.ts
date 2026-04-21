import request from 'supertest';
import app from '../../src/app';

/**
 * 红外遥控管理测试
 *
 * 傻瓜教程：
 * 这个文件测试红外遥控相关的所有接口，包括：
 * 1. 红外码的增删改查
 * 2. 红外码库管理
 * 3. 红外指令发送
 *
 * 测试前准备：
 * - 确保数据库中有测试用的红外码数据
 * - 确保有已注册的红外发射设备
 */
describe('红外遥控管理 API', () => {
  let authToken: string;
  let testCodeId: number;

  // 测试前登录获取token
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
   * 测试：获取红外码列表
   *
   * 使用场景：
   * - 管理员查看已配置的红外码
   * - 按设备类型筛选（空调/电视等）
   * - 按品牌筛选
   */
  describe('GET /api/v1/ir-remote/codes - 获取红外码列表', () => {
    it('应该返回红外码列表', async () => {
      const res = await request(app)
        .get('/api/v1/ir-remote/codes')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('list');
      expect(res.body.data).toHaveProperty('pagination');
    });

    it('应该支持按设备类型筛选', async () => {
      const res = await request(app)
        .get('/api/v1/ir-remote/codes?device_type=ac')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    it('应该支持按品牌筛选', async () => {
      const res = await request(app)
        .get('/api/v1/ir-remote/codes?brand=格力')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  /**
   * 测试：添加红外码
   *
   * 使用场景：
   * - 管理员添加新的红外码
   * - 学习模式保存红外码
   */
  describe('POST /api/v1/ir-remote/codes - 添加红外码', () => {
    it('应该成功添加红外码', async () => {
      const res = await request(app)
        .post('/api/v1/ir-remote/codes')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          device_type: 'ac',
          brand: '格力',
          model: 'KFR-35GW',
          function_name: 'power_on',
          ir_code: '0x1234567890ABCDEF',
          protocol: 'NEC',
          is_default: true
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('id');
      testCodeId = res.body.data.id;
    });

    it('缺少必要参数时应该返回400', async () => {
      const res = await request(app)
        .post('/api/v1/ir-remote/codes')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          device_type: 'ac'
        });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });
  });

  /**
   * 测试：发送红外指令
   *
   * 使用场景：
   * - 控制房间空调开关
   * - 调节温度
   * - 切换电视频道
   */
  describe('POST /api/v1/ir-remote/send - 发送红外指令', () => {
    it('应该成功发送红外指令', async () => {
      const res = await request(app)
        .post('/api/v1/ir-remote/send')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          room_id: 101,
          device_type: 'ac',
          function_name: 'power_on'
        });

      // 注意：实际测试时需要确保房间有红外设备
      expect([200, 404]).toContain(res.status);
    });
  });

  /**
   * 测试：获取品牌列表
   *
   * 使用场景：
   * - 前台选择空调品牌
   * - 配置红外码时选择品牌
   */
  describe('GET /api/v1/ir-remote/brands - 获取品牌列表', () => {
    it('应该返回品牌列表', async () => {
      const res = await request(app)
        .get('/api/v1/ir-remote/brands')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(Array.isArray(res.body.data)).toBe(true);
    });

    it('应该支持按设备类型筛选品牌', async () => {
      const res = await request(app)
        .get('/api/v1/ir-remote/brands?device_type=tv')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  /**
   * 测试：删除红外码
   */
  describe('DELETE /api/v1/ir-remote/codes/:id - 删除红外码', () => {
    it('应该成功删除红外码', async () => {
      const res = await request(app)
        .delete(`/api/v1/ir-remote/codes/${testCodeId}`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });
});
