/**
 * 输入验证器
 * 提供各种输入数据的验证函数
 */

import validator from 'validator';

export interface ValidationResult {
  valid: boolean;
  error?: string;
}

/**
 * 验证手机号（中国大陆）
 */
export function validatePhone(phone: string): ValidationResult {
  if (!phone) {
    return { valid: false, error: '手机号不能为空' };
  }
  
  const phoneRegex = /^1[3-9]\d{9}$/;
  if (!phoneRegex.test(phone)) {
    return { valid: false, error: '手机号格式不正确' };
  }
  
  return { valid: true };
}

/**
 * 验证邮箱
 */
export function validateEmail(email: string): ValidationResult {
  if (!email) {
    return { valid: false, error: '邮箱不能为空' };
  }
  
  if (!validator.isEmail(email)) {
    return { valid: false, error: '邮箱格式不正确' };
  }
  
  return { valid: true };
}

/**
 * 验证密码强度
 */
export function validatePassword(password: string): ValidationResult {
  if (!password) {
    return { valid: false, error: '密码不能为空' };
  }
  
  if (password.length < 6) {
    return { valid: false, error: '密码长度至少6位' };
  }
  
  if (password.length > 128) {
    return { valid: false, error: '密码长度不能超过128位' };
  }
  
  // 检查密码复杂度（可选）
  const hasLetter = /[a-zA-Z]/.test(password);
  const hasNumber = /\d/.test(password);
  
  if (!hasLetter || !hasNumber) {
    return { valid: false, error: '密码必须包含字母和数字' };
  }
  
  return { valid: true };
}

/**
 * 验证用户名
 */
export function validateUsername(username: string): ValidationResult {
  if (!username) {
    return { valid: false, error: '用户名不能为空' };
  }
  
  if (username.length < 2 || username.length > 50) {
    return { valid: false, error: '用户名长度必须在2-50个字符之间' };
  }
  
  // 只允许字母、数字、中文、下划线
  const usernameRegex = /^[a-zA-Z0-9_\u4e00-\u9fa5]+$/;
  if (!usernameRegex.test(username)) {
    return { valid: false, error: '用户名只能包含字母、数字、中文和下划线' };
  }
  
  return { valid: true };
}

/**
 * 验证身份证号
 */
export function validateIdNumber(idNumber: string): ValidationResult {
  if (!idNumber) {
    return { valid: false, error: '身份证号不能为空' };
  }
  
  // 15位或18位身份证号
  const idRegex = /(^\d{15}$)|(^\d{18}$)|(^\d{17}(\d|X|x)$)/;
  if (!idRegex.test(idNumber)) {
    return { valid: false, error: '身份证号格式不正确' };
  }
  
  return { valid: true };
}

/**
 * 验证日期格式
 */
export function validateDate(date: string): ValidationResult {
  if (!date) {
    return { valid: false, error: '日期不能为空' };
  }
  
  if (!validator.isISO8601(date)) {
    return { valid: false, error: '日期格式不正确' };
  }
  
  return { valid: true };
}

/**
 * 验证整数
 */
export function validateInt(value: any, min?: number, max?: number): ValidationResult {
  if (value === null || value === undefined || value === '') {
    return { valid: false, error: '值不能为空' };
  }
  
  const num = parseInt(value);
  if (isNaN(num)) {
    return { valid: false, error: '必须是整数' };
  }
  
  if (min !== undefined && num < min) {
    return { valid: false, error: `不能小于${min}` };
  }
  
  if (max !== undefined && num > max) {
    return { valid: false, error: `不能大于${max}` };
  }
  
  return { valid: true };
}

/**
 * 验证金额
 */
export function validateAmount(amount: any): ValidationResult {
  if (amount === null || amount === undefined || amount === '') {
    return { valid: false, error: '金额不能为空' };
  }
  
  const num = parseFloat(amount);
  if (isNaN(num) || num < 0) {
    return { valid: false, error: '金额必须是非负数' };
  }
  
  // 最多2位小数
  const decimals = (amount.toString().split('.')[1] || '').length;
  if (decimals > 2) {
    return { valid: false, error: '金额最多保留2位小数' };
  }
  
  return { valid: true };
}

/**
 * 验证UUID
 */
export function validateUUID(uuid: string): ValidationResult {
  if (!uuid) {
    return { valid: false, error: 'UUID不能为空' };
  }
  
  if (!validator.isUUID(uuid)) {
    return { valid: false, error: 'UUID格式不正确' };
  }
  
  return { valid: true };
}

/**
 * 验证设备ID
 */
export function validateDeviceId(deviceId: string): ValidationResult {
  if (!deviceId) {
    return { valid: false, error: '设备ID不能为空' };
  }
  
  if (deviceId.length < 3 || deviceId.length > 64) {
    return { valid: false, error: '设备ID长度必须在3-64个字符之间' };
  }
  
  // 只允许字母、数字、下划线、连字符
  const deviceIdRegex = /^[a-zA-Z0-9_-]+$/;
  if (!deviceIdRegex.test(deviceId)) {
    return { valid: false, error: '设备ID只能包含字母、数字、下划线和连字符' };
  }
  
  return { valid: true };
}

/**
 * 验证酒店代码
 */
export function validateHotelCode(code: string): ValidationResult {
  if (!code) {
    return { valid: false, error: '酒店代码不能为空' };
  }
  
  if (code.length < 2 || code.length > 20) {
    return { valid: false, error: '酒店代码长度必须在2-20个字符之间' };
  }
  
  const codeRegex = /^[a-zA-Z0-9_-]+$/;
  if (!codeRegex.test(code)) {
    return { valid: false, error: '酒店代码只能包含字母、数字、下划线和连字符' };
  }
  
  return { valid: true };
}

/**
 * 验证房间号
 */
export function validateRoomNumber(roomNumber: string): ValidationResult {
  if (!roomNumber) {
    return { valid: false, error: '房间号不能为空' };
  }
  
  if (roomNumber.length < 1 || roomNumber.length > 10) {
    return { valid: false, error: '房间号长度必须在1-10个字符之间' };
  }
  
  // 允许字母、数字、连字符
  const roomRegex = /^[a-zA-Z0-9-]+$/;
  if (!roomRegex.test(roomNumber)) {
    return { valid: false, error: '房间号只能包含字母、数字和连字符' };
  }
  
  return { valid: true };
}

/**
 * 验证字符串长度
 */
export function validateLength(str: string, min: number, max: number, fieldName: string = '字段'): ValidationResult {
  if (!str) {
    return { valid: false, error: `${fieldName}不能为空` };
  }
  
  if (str.length < min) {
    return { valid: false, error: `${fieldName}长度不能少于${min}个字符` };
  }
  
  if (str.length > max) {
    return { valid: false, error: `${fieldName}长度不能超过${max}个字符` };
  }
  
  return { valid: true };
}

/**
 * 验证是否为SQL注入
 */
export function validateNoSQLInjection(input: string): ValidationResult {
  if (!input) {
    return { valid: true };
  }
  
  // 基本的SQL注入检测
  const sqlPattern = /(\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|EXECUTE|UNION|DECLARE|TRUNCATE)\b)|(--)|(\/\*)|(\*\/)/i;
  
  if (sqlPattern.test(input)) {
    return { valid: false, error: '输入包含非法字符' };
  }
  
  return { valid: true };
}

/**
 * 验证是否为XSS攻击
 */
export function validateNoXSS(input: string): ValidationResult {
  if (!input) {
    return { valid: true };
  }
  
  // 基本的XSS检测
  const xssPattern = /<script|<\/script|javascript:|onerror=|onload=|<iframe|<object|<embed/i;
  
  if (xssPattern.test(input)) {
    return { valid: false, error: '输入包含非法字符' };
  }
  
  return { valid: true };
}
