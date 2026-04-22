import crypto from 'crypto';

/**
 * 将对象键进行排序，确保签名的一致性
 */
function sortObject(obj: any): any {
  if (obj === null || typeof obj !== 'object') {
    return obj;
  }
  if (Array.isArray(obj)) {
    return obj.map(sortObject);
  }
  const sortedKeys = Object.keys(obj).sort();
  const result: any = {};
  sortedKeys.forEach(key => {
    result[key] = sortObject(obj[key]);
  });
  return result;
}

/**
 * 计算 HMAC-SHA256 签名
 * @param data 要签名的数据（字符串或对象）
 * @param secret 密钥
 * @returns 签名字符串（hex）
 */
export function calculateSignature(data: any, secret: string): string {
  let payload: string;
  if (typeof data === 'string') {
    payload = data;
  } else {
    // 排序键以确保一致性
    const sortedData = sortObject(data);
    payload = JSON.stringify(sortedData);
  }
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
