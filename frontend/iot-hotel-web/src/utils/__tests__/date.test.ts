import { describe, it, expect } from 'vitest';
import { formatDate, formatDateTime, getDaysDiff, isValidDate } from '../date';

describe('日期工具函数测试', () => {
  describe('formatDate', () => {
    it('应该正确格式化日期', () => {
      const date = new Date('2026-04-20');
      expect(formatDate(date)).toBe('2026-04-20');
    });

    it('应该处理字符串日期', () => {
      expect(formatDate('2026-04-20')).toBe('2026-04-20');
    });

    it('应该处理时间戳', () => {
      const timestamp = new Date('2026-04-20').getTime();
      expect(formatDate(timestamp)).toBe('2026-04-20');
    });
  });

  describe('formatDateTime', () => {
    it('应该正确格式化日期时间', () => {
      const date = new Date('2026-04-20 14:30:00');
      const result = formatDateTime(date);
      expect(result).toContain('2026');
      expect(result).toContain('04');
      expect(result).toContain('20');
    });
  });

  describe('getDaysDiff', () => {
    it('应该正确计算天数差', () => {
      const start = '2026-04-20';
      const end = '2026-04-25';
      expect(getDaysDiff(start, end)).toBe(5);
    });

    it('同一天应该返回 0', () => {
      const date = '2026-04-20';
      expect(getDaysDiff(date, date)).toBe(0);
    });

    it('负数差值应该正确处理', () => {
      const start = '2026-04-25';
      const end = '2026-04-20';
      expect(getDaysDiff(start, end)).toBe(-5);
    });
  });

  describe('isValidDate', () => {
    it('应该验证有效日期', () => {
      expect(isValidDate('2026-04-20')).toBe(true);
      expect(isValidDate('2026-02-28')).toBe(true);
    });

    it('应该拒绝无效日期', () => {
      expect(isValidDate('invalid')).toBe(false);
      expect(isValidDate('')).toBe(false);
      expect(isValidDate('2026-13-01')).toBe(false);
    });
  });
});
