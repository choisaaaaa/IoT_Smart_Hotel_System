-- AI管家知识库表 - 用于存储各门店的实际服务信息
-- 由各门店经理维护，AI管家只能回复知识库内的实质内容

CREATE TABLE IF NOT EXISTS ai_knowledge_base (
  id INT AUTO_INCREMENT PRIMARY KEY,
  hotel_id INT NOT NULL COMMENT '关联的酒店ID',
  category VARCHAR(50) NOT NULL COMMENT '知识分类：restaurant/gym/wifi/nearby/checkout/breakfast/room_service/policy/other',
  title VARCHAR(200) NOT NULL COMMENT '知识标题',
  content TEXT NOT NULL COMMENT '知识详细内容（支持Markdown格式）',
  keywords VARCHAR(500) DEFAULT NULL COMMENT '关键词（逗号分隔，用于AI检索匹配）',
  is_active TINYINT(1) DEFAULT 1 COMMENT '是否启用：1=启用，0=禁用',
  sort_order INT DEFAULT 0 COMMENT '排序权重，数字越大越优先',
  created_by INT DEFAULT NULL COMMENT '创建人ID',
  updated_by INT DEFAULT NULL COMMENT '最后更新人ID',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_hotel_category (hotel_id, category),
  INDEX idx_hotel_id (hotel_id),
  INDEX idx_category (category),
  CONSTRAINT fk_kb_hotel FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='AI管家知识库 - 存储各门店的实际服务信息';