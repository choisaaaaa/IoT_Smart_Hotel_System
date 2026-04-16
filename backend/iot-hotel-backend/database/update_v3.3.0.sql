-- 智慧酒店物联网控制系统 - 数据库更新脚本 (v3.3.0)
-- 酒店门店照片管理功能

USE iot_hotel_system;

-- -----------------------------------------------------------------------------
-- 1. 创建酒店图片表 (Hotel Images)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hotel_images (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hotel_id INT NOT NULL COMMENT '酒店ID',
    image_url VARCHAR(500) NOT NULL COMMENT '图片URL',
    image_type VARCHAR(20) DEFAULT 'gallery' COMMENT '图片类型: cover-封面, gallery-相册, room-房型',
    sort_order INT DEFAULT 0 COMMENT '排序顺序',
    is_active TINYINT(1) DEFAULT 1 COMMENT '是否启用',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_hotel_id (hotel_id),
    INDEX idx_image_type (image_type),
    FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 2. 酒店信息表字段扩展说明
-- -----------------------------------------------------------------------------
-- 现有字段:
-- - logo: 酒店Logo，用于列表展示
-- - image_url: 酒店主图，用于封面展示
-- - description: 酒店简介
-- - promotion: 促销信息
--
-- 新增图片表支持:
-- - 支持上传多张门店照片
-- - 支持设置封面图
-- - 支持图片排序

-- -----------------------------------------------------------------------------
-- 3. 数据迁移说明 (可选)
-- -----------------------------------------------------------------------------
-- 如果已有酒店的 image_url 需要迁移到 hotel_images 表:
-- INSERT INTO hotel_images (hotel_id, image_url, image_type, sort_order)
-- SELECT id, image_url, 'cover', 0 FROM hotels WHERE image_url IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 4. 数据库文档更新完毕
-- -----------------------------------------------------------------------------
