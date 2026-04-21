import request from 'supertest';
import app from '../../../app';

// 设备分组管理测试
// 傻瓜教程：这个文件测试设备分组相关的所有接口

describe('设备分组管理 API', () => {
  let authToken: string;
  let testGroupId: number;

  // 测试前登录获取token
  beforeAll(async () => {
    // 这里应该调用登录接口获取token
    // 实际测试时需要替换为真实的登录信息
    const loginRes = await request(app)
      .post('/api/v1/auth/login')
      .send({
        phone: '13800138000',
        password: 'password123'
      });
    authToken = loginRes.body.data?.token || 'test-token';
  });

  describe('POST /api/v1/device-groups - 创建设备分组', () => {
    it('应该成功创建一个新的设备分组', async () => {
      const res = await request(app)
        .post('/api/v1/device-groups')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          group_name: '测试分组',
          group_type: 'floor',
          description: '这是一个测试分组'
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('id');
      testGroupId = res.body.data.id;
    });

    it('缺少分组名称时应该返回400错误', async () => {
      const res = await request(app)
        .post('/api/v1/device-groups')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          group_type: 'floor'
        });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });
  });

  describe('GET /api/v1/device-groups - 获取分组列表', () => {
    it('应该返回分组列表', async () => {
      const res = await request(app)
        .get('/api/v1/device-groups')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(Array.isArray(res.body.data)).toBe(true);
    });

    it('应该支持按类型筛选', async () => {
      const res = await request(app)
        .get('/api/v1/device-groups?group_type=floor')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  describe('PUT /api/v1/device-groups/:id - 更新分组', () => {
    it('应该成功更新分组信息', async () => {
      const res = await request(app)
        .put(`/api/v1/device-groups/${testGroupId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          group_name: '更新后的分组名称',
          description: '更新后的描述'
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  describe('POST /api/v1/device-groups/:id/devices - 添加设备到分组', () => {
    it('应该成功添加设备到分组', async () => {
      const res = await request(app)
        .post(`/api/v1/device-groups/${testGroupId}/devices`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          device_ids: ['device001', 'device002']
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  describe('POST /api/v1/device-groups/:id/command - 批量控制分组设备', () => {
    it('应该成功发送批量控制指令', async () => {
      const res = await request(app)
        .post(`/api/v1/device-groups/${testGroupId}/command`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          command_type: 'relay_on',
          command_value: 'on'
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  describe('DELETE /api/v1/device-groups/:id - 删除分组', () => {
    it('应该成功删除分组', async () => {
      const res = await request(app)
        .delete(`/api/v1/device-groups/${testGroupId}`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });
});
