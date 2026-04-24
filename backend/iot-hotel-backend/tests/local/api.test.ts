import request from 'supertest';
import app from '../../src/app';

/**
 * API 集成测试
 *
 * 傻瓜教程：
 * 这个文件测试基础API接口，包括：
 * 1. 健康检查
 * 2. 认证接口
 * 3. 受保护接口
 * 4. 限流测试
 * 5. 404处理
 */
describe('API 集成测试', () => {
  describe('健康检查接口', () => {
    it('GET / 应该返回系统信息', async () => {
      const response = await request(app)
        .get('/')
        .expect(200);

      expect(response.body.code).toBe(200);
      expect(response.body.message).toContain('慧宿智联');
      expect(response.body.version).toBeDefined();
      expect(response.body.timestamp).toBeDefined();
    });

    it('GET /api/v1/health 应该返回健康状态', async () => {
      const response = await request(app)
        .get('/api/v1/health')
        .expect(200);

      expect(response.body.code).toBe(200);
      expect(response.body.message).toContain('服务正常');
    });
  });

  describe('认证接口', () => {
    it('POST /api/v1/auth/login 应该验证登录凭证', async () => {
      const response = await request(app)
        .post('/api/v1/auth/login')
        .send({
          username: 'testuser',
          password: 'wrongpassword'
        });

      // 后端返回400表示请求参数错误
      expect(response.status).toBe(400);
      expect(response.body.code).toBe(400);
    });

    it('POST /api/v1/auth/login 应该拒绝无效请求体', async () => {
      const response = await request(app)
        .post('/api/v1/auth/login')
        .send({})
        .expect(400);

      expect(response.body.code).toBe(400);
    });
  });

  describe('受保护接口', () => {
    it('访问需要认证的接口应该返回 401', async () => {
      const response = await request(app)
        .get('/api/v1/users')
        .expect(401);

      expect(response.body.code).toBe(401);
      // 实际返回的是"未提供认证令牌"
      expect(response.body.message).toContain('未提供');
    });

    it('使用无效 Token 应该返回 401', async () => {
      const response = await request(app)
        .get('/api/v1/users')
        .set('Authorization', 'Bearer invalid_token')
        .expect(401);

      expect(response.body.code).toBe(401);
    });
  });

  describe('限流测试', () => {
    it('正常请求不应该被限流', async () => {
      const response = await request(app)
        .get('/')
        .expect(200);

      expect(response.status).toBe(200);
    });
  });

  describe('404 处理', () => {
    it('访问不存在的路由应该返回 404', async () => {
      const response = await request(app)
        .get('/api/v1/nonexistent')
        .expect(404);

      expect(response.body.code).toBe(404);
    });
  });
});
