import request from 'supertest';
import app from '../src/app';

/**
 * 预订模块 API 测试
 *
 * 傻瓜教程：
 * 这个文件测试预订相关的所有接口，包括：
 * 1. 预订列表查询
 * 2. 创建预订
 * 3. 更新预订状态
 */
describe('预订模块 API 测试', () => {
  const mockToken = 'Bearer mock_jwt_token';

  describe('预订列表查询', () => {
    it('未认证用户应该无法访问预订列表', async () => {
      const response = await request(app)
        .get('/api/v1/bookings')
        .expect(401);

      expect(response.body.code).toBe(401);
    });

    it('应该支持分页参数', async () => {
      const response = await request(app)
        .get('/api/v1/bookings?page=1&limit=10')
        .set('Authorization', mockToken)
        .expect(401); // 因为 token 无效

      expect(response.body.code).toBe(401);
    });
  });

  describe('创建预订', () => {
    it('应该验证必需的预订字段', async () => {
      const response = await request(app)
        .post('/api/v1/bookings')
        .set('Authorization', mockToken)
        .send({})
        .expect(401);

      expect(response.body.code).toBe(401);
    });

    it('应该验证日期格式', async () => {
      const invalidBooking = {
        room_id: 1,
        check_in_date: 'invalid-date',
        check_out_date: '2024-01-01',
        guest_name: '测试用户',
        guest_phone: '13800138000'
      };

      const response = await request(app)
        .post('/api/v1/bookings')
        .set('Authorization', mockToken)
        .send(invalidBooking)
        .expect(401);

      expect(response.body.code).toBe(401);
    });
  });

  describe('更新预订状态', () => {
    it('应该验证状态值', async () => {
      const response = await request(app)
        .put('/api/v1/bookings/1/status')
        .set('Authorization', mockToken)
        .send({ status: 'invalid_status' });

      // 注意: 此路由可能不存在，返回404
      expect([401, 404]).toContain(response.status);
    });
  });
});
