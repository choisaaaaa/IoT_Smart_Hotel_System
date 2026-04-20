import { describe, it, expect } from 'vitest';
import { getImageUrl, buildQueryString, parseQueryString } from '../url';

describe('URL 工具函数测试', () => {
  describe('getImageUrl', () => {
    it('应该正确处理完整 URL', () => {
      const fullUrl = 'https://example.com/image.jpg';
      expect(getImageUrl(fullUrl)).toBe(fullUrl);
    });

    it('应该正确处理相对路径', () => {
      const relativePath = '/uploads/image.jpg';
      const result = getImageUrl(relativePath);
      expect(result).toContain('/uploads/image.jpg');
    });

    it('应该处理空值', () => {
      expect(getImageUrl('')).toBe('');
      expect(getImageUrl(null as any)).toBe('');
    });
  });

  describe('buildQueryString', () => {
    it('应该正确构建查询字符串', () => {
      const params = { a: '1', b: '2', c: '3' };
      const result = buildQueryString(params);
      expect(result).toBe('?a=1&b=2&c=3');
    });

    it('应该处理空对象', () => {
      expect(buildQueryString({})).toBe('');
    });

    it('应该编码特殊字符', () => {
      const params = { key: 'value with spaces' };
      const result = buildQueryString(params);
      expect(result).toContain('value%20with%20spaces');
    });
  });

  describe('parseQueryString', () => {
    it('应该正确解析查询字符串', () => {
      const query = '?a=1&b=2&c=3';
      const result = parseQueryString(query);
      expect(result).toEqual({ a: '1', b: '2', c: '3' });
    });

    it('应该处理空字符串', () => {
      expect(parseQueryString('')).toEqual({});
    });

    it('应该解码编码字符', () => {
      const query = '?key=value%20with%20spaces';
      const result = parseQueryString(query);
      expect(result.key).toBe('value with spaces');
    });
  });
});
