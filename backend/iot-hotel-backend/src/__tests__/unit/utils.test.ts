import { generateSignature, verifySignature } from '../../utils/signature';
import logger from '../../utils/logger';

describe('工具函数测试', () => {
  describe('签名工具', () => {
    it('应该能正确生成和验证签名', () => {
      const params = { a: '1', b: '2', c: '3' };
      const secret = 'testSecret';
      const signature = generateSignature(params, secret);

      expect(signature).toBeDefined();
      expect(typeof signature).toBe('string');
      expect(signature.length).toBeGreaterThan(0);

      // 验证相同参数生成相同签名
      const signature2 = generateSignature(params, secret);
      expect(signature).toBe(signature2);

      // 不同参数生成不同签名
      const differentParams = { a: '1', b: '2', c: '4' };
      const differentSignature = generateSignature(differentParams, secret);
      expect(signature).not.toBe(differentSignature);
    });

    it('应该能正确验证签名', () => {
      const params = { deviceId: '123', timestamp: Date.now().toString() };
      const secret = 'deviceSecret';
      const signature = generateSignature(params, secret);

      expect(verifySignature(params, signature, secret)).toBe(true);
      expect(verifySignature(params, 'wrongSignature', secret)).toBe(false);
    });
  });

  describe('日志工具', () => {
    it('应该正确导出 logger 实例', () => {
      expect(logger).toBeDefined();
      expect(typeof logger.info).toBe('function');
      expect(typeof logger.error).toBe('function');
      expect(typeof logger.warn).toBe('function');
      expect(typeof logger.debug).toBe('function');
    });
  });
});
