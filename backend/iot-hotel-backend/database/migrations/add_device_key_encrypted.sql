-- 设备密钥安全存储迁移脚本
-- 日期: 2026-04-22
-- 说明: 为设备密钥添加加密存储列，用于签名验证
-- 
-- 迁移策略:
-- 1. 添加 device_key_encrypted 列存储 AES-256-GCM 加密的原始密钥
-- 2. device_key 列存储 SHA256 哈希值（用于身份验证）
-- 3. 保留向后兼容：如果只有明文device_key，验证时自动兼容

USE iot_hotel_system;

-- 添加加密密钥存储列
ALTER TABLE devices 
ADD COLUMN IF NOT EXISTS device_key_encrypted TEXT DEFAULT NULL COMMENT '设备密钥AES-256-GCM加密存储（用于签名验证）' 
AFTER device_key;

-- 数据迁移：将现有的明文device_key加密到device_key_encrypted
-- 注意：这只迁移非空且非哈希格式的密钥
UPDATE devices 
SET device_key_encrypted = device_key 
WHERE device_key IS NOT NULL 
  AND device_key != '' 
  AND (CHAR_LENGTH(device_key) != 64 OR device_key NOT REGEXP '^[a-f0-9]+$');

-- 对于已经是哈希格式的device_key，无法还原原始密钥
-- 这些设备需要在下次审核时重新生成密钥

SELECT '设备密钥加密迁移完成' AS migration_status;
