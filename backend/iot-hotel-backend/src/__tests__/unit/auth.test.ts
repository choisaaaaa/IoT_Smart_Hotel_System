import { hashPassword, comparePassword } from '../../utils/password';
import { generateToken, verifyToken } from '../../utils/jwt';
import { normalizeRole, isSystemAdmin, isHotelAdmin, isStaff, isCustomer, isGuest } from '../../utils/role';

describe('认证工具测试', () => {
  describe('密码工具', () => {
    it('应该能正确哈希和验证密码', async () => {
      const password = 'testPassword123';
      const hashed = await hashPassword(password);

      expect(hashed).not.toBe(password);
      expect(await comparePassword(password, hashed)).toBe(true);
      expect(await comparePassword('wrongPassword', hashed)).toBe(false);
    });

    it('应该为相同密码生成不同的哈希值', async () => {
      const password = 'samePassword';
      const hash1 = await hashPassword(password);
      const hash2 = await hashPassword(password);

      expect(hash1).not.toBe(hash2);
      expect(await comparePassword(password, hash1)).toBe(true);
      expect(await comparePassword(password, hash2)).toBe(true);
    });
  });

  describe('JWT Token 工具', () => {
    it('应该能正确生成和验证 Token', () => {
      const payload = { id: 1, role: 'admin', hotel_id: 1 };
      const token = generateToken(payload);

      expect(token).toBeDefined();
      expect(typeof token).toBe('string');

      const decoded = verifyToken(token);
      expect(decoded.id).toBe(payload.id);
      expect(decoded.role).toBe(payload.role);
      expect(decoded.hotel_id).toBe(payload.hotel_id);
    });

    it('应该拒绝无效的 Token', () => {
      expect(() => verifyToken('invalid.token.here')).toThrow();
    });
  });

  describe('角色工具', () => {
    it('应该正确标准化角色名称', () => {
      expect(normalizeRole('system')).toBe('system');
      expect(normalizeRole('admin')).toBe('hotel_admin');
      expect(normalizeRole('hotel_admin')).toBe('hotel_admin');
      expect(normalizeRole('receptionist')).toBe('staff');
      expect(normalizeRole('staff')).toBe('staff');
      expect(normalizeRole('customer')).toBe('customer');
      expect(normalizeRole('user')).toBe('customer');
      expect(normalizeRole('guest')).toBe('guest');
    });

    it('应该正确识别系统管理员', () => {
      expect(isSystemAdmin('system')).toBe(true);
      expect(isSystemAdmin('admin')).toBe(false);
      expect(isSystemAdmin('hotel_admin')).toBe(false);
    });

    it('应该正确识别酒店管理员', () => {
      expect(isHotelAdmin('admin')).toBe(true);
      expect(isHotelAdmin('hotel_admin')).toBe(true);
      expect(isHotelAdmin('system')).toBe(false);
      expect(isHotelAdmin('staff')).toBe(false);
    });

    it('应该正确识别员工', () => {
      expect(isStaff('receptionist')).toBe(true);
      expect(isStaff('staff')).toBe(true);
      expect(isStaff('admin')).toBe(false);
      expect(isStaff('customer')).toBe(false);
    });

    it('应该正确识别客户', () => {
      expect(isCustomer('customer')).toBe(true);
      expect(isCustomer('user')).toBe(true);
      expect(isCustomer('guest')).toBe(false);
      expect(isCustomer('admin')).toBe(false);
    });

    it('应该正确识别住客', () => {
      expect(isGuest('guest')).toBe(true);
      expect(isGuest('customer')).toBe(false);
      expect(isGuest('admin')).toBe(false);
    });
  });
});
