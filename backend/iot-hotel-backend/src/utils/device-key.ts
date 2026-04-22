import crypto from 'crypto';

/**
 * 设备密钥安全服务
 * 
 * 功能:
 * 1. 设备密钥使用 SHA256 哈希存储，防止数据库泄露后密钥暴露
 * 2. 使用 AES-256-GCM 加密存储原始密钥（用于签名验证）
 * 3. 验证时使用哈希比较，防止时序攻击
 * 4. 签名验证时使用解密后的原始密钥
 * 5. 向后兼容旧明文密钥（用于数据迁移）
 */

// 设备密钥哈希算法配置
const DEVICE_KEY_HASH_ALGORITHM = 'sha256';

// AES-256-GCM 加密配置
const AES_ALGORITHM = 'aes-256-gcm';
const AES_IV_LENGTH = 16;
const AES_AUTH_TAG_LENGTH = 16;

/**
 * 获取加密密钥（从环境变量或默认值）
 * 生产环境必须设置 DEVICE_KEY_ENCRYPTION_KEY 环境变量
 */
function getEncryptionKey(): Buffer {
  const keyStr = process.env.DEVICE_KEY_ENCRYPTION_KEY || 'iot-hotel-device-key-encryption-key-2024-production-must-change';
  // 确保密钥长度为32字节（AES-256）
  return crypto.createHash('sha256').update(keyStr).digest();
}

/**
 * 对设备密钥进行哈希处理（用于安全比较）
 * @param deviceKey 原始设备密钥
 * @returns 哈希后的设备密钥（64位hex格式）
 */
export function hashDeviceKey(deviceKey: string): string {
  const salt = process.env.DEVICE_KEY_SALT || 'iot_hotel_default_salt_2024';
  const pepper = process.env.DEVICE_KEY_PEPPER || 'iot_hotel_pepper_secret';
  
  return crypto
    .createHash(DEVICE_KEY_HASH_ALGORITHM)
    .update(salt + deviceKey + pepper)
    .digest('hex');
}

/**
 * 验证设备密钥（支持哈希、加密、明文三种格式，向后兼容）
 * @param providedKey 设备提供的原始密钥
 * @param storedValue 数据库中存储的值（可能是哈希值、加密值或明文）
 * @returns 是否匹配
 */
export function verifyDeviceKey(providedKey: string, storedValue: string): boolean {
  if (!storedValue) return false;
  
  // 方案1: 如果是哈希格式（64位hex），使用哈希比较
  if (storedValue.length === 64 && /^[a-f0-9]+$/.test(storedValue)) {
    const computedHash = hashDeviceKey(providedKey);
    return crypto.timingSafeEqual(
      Buffer.from(computedHash),
      Buffer.from(storedValue)
    );
  }
  
  // 方案2: 如果是加密格式（包含IV+tag+密文），尝试解密后比较
  if (storedValue.length > 96) {
    try {
      const decrypted = decryptDeviceKey(storedValue);
      return crypto.timingSafeEqual(
        Buffer.from(providedKey),
        Buffer.from(decrypted)
      );
    } catch {
      // 解密失败，继续尝试明文比较
    }
  }
  
  // 方案3: 旧明文比较（向后兼容，用于数据迁移）
  return crypto.timingSafeEqual(
    Buffer.from(providedKey),
    Buffer.from(storedValue)
  );
}

/**
 * 加密原始设备密钥（用于存储）
 * @param rawKey 原始设备密钥
 * @returns hex编码的加密数据（包含IV、密文和认证标签）
 */
export function encryptDeviceKey(rawKey: string): string {
  const key = getEncryptionKey();
  const iv = crypto.randomBytes(AES_IV_LENGTH);
  
  const cipher = crypto.createCipheriv(AES_ALGORITHM, key, iv);
  let encrypted = cipher.update(rawKey, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  
  const authTag = cipher.getAuthTag();
  
  // 组合格式: iv(32位hex) + auth_tag(32位hex) + encrypted_data
  return iv.toString('hex') + authTag.toString('hex') + encrypted;
}

/**
 * 解密设备密钥（用于签名验证）
 * @param encryptedData hex编码的加密数据
 * @returns 原始设备密钥
 */
export function decryptDeviceKey(encryptedData: string): string {
  const key = getEncryptionKey();
  
  // 解析加密数据
  const iv = Buffer.from(encryptedData.slice(0, AES_IV_LENGTH * 2), 'hex');
  const authTag = Buffer.from(
    encryptedData.slice(AES_IV_LENGTH * 2, AES_IV_LENGTH * 2 + AES_AUTH_TAG_LENGTH * 2),
    'hex'
  );
  const encrypted = encryptedData.slice(AES_IV_LENGTH * 2 + AES_AUTH_TAG_LENGTH * 2);
  
  const decipher = crypto.createDecipheriv(AES_ALGORITHM, key, iv);
  decipher.setAuthTag(authTag);
  
  let decrypted = decipher.update(encrypted, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  
  return decrypted;
}

/**
 * 生成安全的设备密钥（用于设备注册时）
 * @returns 随机生成的设备密钥（64位hex，256位熵）
 */
export function generateSecureDeviceKey(): string {
  return crypto.randomBytes(32).toString('hex');
}

/**
 * 判断存储的密钥格式
 * @param storedValue 数据库中存储的值
 * @returns 'hashed' | 'encrypted' | 'plaintext' | 'empty'
 */
export function getKeyStorageFormat(storedValue: string): 'hashed' | 'encrypted' | 'plaintext' | 'empty' {
  if (!storedValue) return 'empty';
  
  // 哈希格式：64位十六进制字符
  if (storedValue.length === 64 && /^[a-f0-9]+$/.test(storedValue)) {
    return 'hashed';
  }
  
  // 加密格式：较长且包含hex字符
  if (storedValue.length > 96) {
    return 'encrypted';
  }
  
  // 旧明文格式
  return 'plaintext';
}

/**
 * 获取用于签名的原始密钥（根据存储格式自动处理）
 * @param storedValue 数据库中存储的值
 * @param providedKey 设备提供的原始密钥（用于哈希验证）
 * @returns 原始密钥（用于HMAC签名计算）
 */
export function getRawKeyForSigning(storedValue: string, providedKey: string): string | null {
  const format = getKeyStorageFormat(storedValue);
  
  switch (format) {
    case 'hashed':
      // 哈希存储模式下，无法还原原始密钥
      // 签名验证必须使用设备传来的原始密钥
      return providedKey;
    case 'encrypted':
      // 加密存储模式下，可以解密获取原始密钥
      try {
        return decryptDeviceKey(storedValue);
      } catch {
        return null;
      }
    case 'plaintext':
      // 明文存储模式（旧数据兼容）
      return storedValue;
    case 'empty':
    default:
      return null;
  }
}
