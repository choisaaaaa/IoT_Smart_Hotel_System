import request from 'supertest';
import app from '../../src/app';

/**
 * 场景模式管理测试
 *
 * 傻瓜教程：
 * 这个文件测试场景模式相关的所有接口，包括：
 * 1. 场景配置的增删改查
 * 2. 场景执行
 * 3. 执行历史查询
 *
 * 什么是场景模式？
 * - 欢迎模式：客人入住时自动开灯、开空调
 * - 睡眠模式：自动关灯、关窗帘、调空调到睡眠温度
 * - 离家模式：关闭所有电器
 * - 节能模式：降低空调温度设定
 */
describe('场景模式管理 API', () => {
  let authToken: string;
  let testSceneId: number;

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
   * 测试：创建场景
   *
   * 使用场景：
   * - 管理员创建"欢迎模式"
   * - 配置多个设备的联动操作
   */
  describe('POST /api/v1/scenes - 创建场景', () => {
    it('应该成功创建场景', async () => {
      const res = await request(app)
        .post('/api/v1/scenes')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          scene_name: '测试欢迎模式',
          commands: [
            {
              device_id: 'relay_1',
              command_type: 'relay_on',
              command_value: 'on',
              delay: 0
            },
            {
              device_id: 'ac',
              command_type: 'set_temperature',
              command_value: '24',
              delay: 500
            }
          ],
          is_active: true
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('id');
      testSceneId = res.body.data.id;
    });

    it('缺少场景名称时应该返回400', async () => {
      const res = await request(app)
        .post('/api/v1/scenes')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          commands: []
        });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });
  });

  /**
   * 测试：获取场景列表
   */
  describe('GET /api/v1/scenes - 获取场景列表', () => {
    it('应该返回场景列表', async () => {
      const res = await request(app)
        .get('/api/v1/scenes')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('list');
    });
  });

  /**
   * 测试：执行场景
   *
   * 使用场景：
   * - 客人入住时触发"欢迎模式"
   * - 一键控制多个设备
   */
  describe('POST /api/v1/scenes/:id/execute - 执行场景', () => {
    it('应该成功执行场景', async () => {
      const res = await request(app)
        .post(`/api/v1/scenes/${testSceneId}/execute`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          room_id: 101
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('execution_id');
      expect(res.body.data).toHaveProperty('status');
    });
  });

  /**
   * 测试：获取执行历史
   */
  describe('GET /api/v1/scenes/executions - 获取场景执行历史', () => {
    it('应该返回执行历史列表', async () => {
      const res = await request(app)
        .get('/api/v1/scenes/executions')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('list');
    });
  });

  /**
   * 测试：初始化默认场景
   *
   * 使用场景：
   * - 新酒店开业时快速配置默认场景
   * - 一键创建欢迎/睡眠/离家/节能模式
   */
  describe('POST /api/v1/scenes/init-default - 初始化默认场景', () => {
    it('应该成功创建默认场景', async () => {
      const res = await request(app)
        .post('/api/v1/scenes/init-default')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          hotel_id: 1
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('count');
    });
  });

  /**
   * 测试：删除场景
   */
  describe('DELETE /api/v1/scenes/:id - 删除场景', () => {
    it('应该成功删除场景', async () => {
      const res = await request(app)
        .delete(`/api/v1/scenes/${testSceneId}`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });
});
