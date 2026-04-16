import crypto from 'crypto';

/**
 * 计算 HMAC-SHA256 签名
 * @param data 要签名的数据（字符串或对象）
 * @param secret 密钥
 * @returns 签名字符串（hex）
 */
export function calculateSignature(data: any, secret: string): string {
  const payload = typeof data === 'string' ? data : JSON.stringify(data);
  return crypto.createHmac('sha256', secret).update(payload).digest('hex');
}

/**
 * 验证签名
 * @param data 原始数据
 * @param signature 提供的签名
 * @param secret 密钥
 * @returns 是否验证通过
 */
export function verifySignature(data: any, signature: string, secret: string): boolean {
  if (!signature || !secret) {return false;}
  const calculated = calculateSignature(data, secret);
  return calculated === signature;
}
