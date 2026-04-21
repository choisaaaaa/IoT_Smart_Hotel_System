/**
 * 输入净化器
 * 提供各种输入数据的净化和转义函数
 */

import validator from 'validator';

/**
 * 净化HTML标签
 */
export function sanitizeHtml(input: string): string {
  if (!input) return '';
  return validator.escape(input);
}

/**
 * 净化SQL输入
 * 注意：这只是辅助函数，主要防护应使用参数化查询
 */
export function sanitizeSql(input: string): string {
  if (!input) return '';
  // 移除或转义SQL特殊字符
  return input
    .replace(/'/g, "''")
    .replace(/\\/g, '\\\\')
    .replace(/;/g, '');
}

/**
 * 净化文件名
 */
export function sanitizeFilename(filename: string): string {
  if (!filename) return '';
  
  // 移除路径分隔符和非法字符
  return filename
    .replace(/[\\/:*?"<>|]/g, '')
    .replace(/\.{2,}/g, '.')
    .trim();
}

/**
 * 净化URL
 */
export function sanitizeUrl(url: string): string {
  if (!url) return '';
  
  // 只允许http和https协议
  const allowedProtocols = ['http:', 'https:'];
  try {
    const parsed = new URL(url);
    if (!allowedProtocols.includes(parsed.protocol)) {
      return '';
    }
    return url;
  } catch {
    return '';
  }
}

/**
 * 净化邮箱
 */
export function sanitizeEmail(email: string): string {
  if (!email) return '';
  return validator.normalizeEmail(email) || '';
}

/**
 * 净化手机号
 * 只保留数字
 */
export function sanitizePhone(phone: string): string {
  if (!phone) return '';
  return phone.replace(/\D/g, '');
}

/**
 * 净化文本（通用）
 */
export function sanitizeText(input: string): string {
  if (!input) return '';
  
  return input
    .trim()
    .replace(/[\x00-\x08\x0b-\x0c\x0e-\x1f\x7f]/g, ''); // 移除控制字符
}

/**
 * 净化搜索关键词
 */
export function sanitizeSearchKeyword(keyword: string): string {
  if (!keyword) return '';
  
  return keyword
    .trim()
    .replace(/[%_]/g, '') // 移除SQL通配符
    .substring(0, 100); // 限制长度
}

/**
 * 净化JSON字符串
 */
export function sanitizeJson(input: string): string {
  if (!input) return '';
  
  try {
    // 尝试解析并重新字符串化
    const parsed = JSON.parse(input);
    return JSON.stringify(parsed);
  } catch {
    return '';
  }
}

/**
 * 净化对象（递归）
 */
export function sanitizeObject<T extends Record<string, any>>(obj: T): T {
  if (!obj || typeof obj !== 'object') return obj;
  
  const sanitized: any = {};
  
  for (const [key, value] of Object.entries(obj)) {
    if (typeof value === 'string') {
      sanitized[key] = sanitizeText(value);
    } else if (typeof value === 'object' && value !== null) {
      sanitized[key] = sanitizeObject(value);
    } else {
      sanitized[key] = value;
    }
  }
  
  return sanitized;
}

/**
 * 截断字符串
 */
export function truncateString(str: string, maxLength: number, suffix: string = '...'): string {
  if (!str || str.length <= maxLength) return str;
  return str.substring(0, maxLength - suffix.length) + suffix;
}

/**
 * 移除所有HTML标签
 */
export function stripHtml(input: string): string {
  if (!input) return '';
  return input.replace(/<[^>]*>/g, '');
}

/**
 * 净化日志内容
 * 防止日志注入攻击
 */
export function sanitizeLog(input: string): string {
  if (!input) return '';
  
  return input
    .replace(/\n/g, '\\n')
    .replace(/\r/g, '\\r')
    .replace(/\t/g, '\\t')
    .substring(0, 1000); // 限制日志长度
}

/**
 * 净化ID参数
 */
export function sanitizeId(id: any): number | null {
  if (id === null || id === undefined) return null;
  
  const num = parseInt(String(id));
  if (isNaN(num) || num <= 0) return null;
  
  return num;
}

/**
 * 净化数组参数
 */
export function sanitizeArray<T>(arr: T[], maxLength: number = 100): T[] {
  if (!Array.isArray(arr)) return [];
  return arr.slice(0, maxLength);
}

/**
 * 净化分页参数
 */
export function sanitizePagination(page: any, pageSize: any): { page: number; pageSize: number } {
  let p = parseInt(String(page)) || 1;
  let ps = parseInt(String(pageSize)) || 10;
  
  // 限制范围
  p = Math.max(1, p);
  ps = Math.min(Math.max(1, ps), 100); // 每页最多100条
  
  return { page: p, pageSize: ps };
}

/**
 * 净化排序参数
 */
export function sanitizeSort(sortBy: string, allowedFields: string[]): { field: string; direction: 'ASC' | 'DESC' } {
  const field = allowedFields.includes(sortBy) ? sortBy : allowedFields[0];
  return { field, direction: 'DESC' };
}

/**
 * 净化布尔值
 */
export function sanitizeBoolean(value: any): boolean {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'string') {
    return value.toLowerCase() === 'true' || value === '1';
  }
  if (typeof value === 'number') {
    return value === 1;
  }
  return false;
}
