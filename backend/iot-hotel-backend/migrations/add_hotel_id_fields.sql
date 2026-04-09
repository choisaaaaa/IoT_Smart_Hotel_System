-- ============================================
-- HotelID 门店数据隔离 - 数据库迁移脚本
-- 执行日期: 2026-04-10
-- 说明: 为所有核心业务表添加 hotel_id 字段
-- ============================================

-- 1. 房间表 (rooms)
ALTER TABLE rooms ADD COLUMN hotel_id INT NOT NULL DEFAULT 1 COMMENT '酒店ID-关联hotels表';
ALTER TABLE rooms ADD INDEX idx_hotel_id (hotel_id);

-- 2. 预订表 (bookings)
ALTER TABLE bookings ADD COLUMN hotel_id INT NOT NULL DEFAULT 1 COMMENT '酒店ID-关联hotels表';
ALTER TABLE bookings ADD INDEX idx_hotel_id (hotel_id);

-- 3. 支付表 (payments)
ALTER TABLE payments ADD COLUMN hotel_id INT NOT NULL DEFAULT 1 COMMENT '酒店ID-关联hotels表';
ALTER TABLE payments ADD INDEX idx_hotel_id (hotel_id);

-- 4. 配送订单表 (delivery_orders)
ALTER TABLE delivery_orders ADD COLUMN hotel_id INT NOT NULL DEFAULT 1 COMMENT '酒店ID-关联hotels表';
ALTER TABLE delivery_orders ADD INDEX idx_hotel_id (hotel_id);

-- 5. 维修工单表 (maintenance_tickets)
ALTER TABLE maintenance_tickets ADD COLUMN hotel_id INT NOT NULL DEFAULT 1 COMMENT '酒店ID-关联hotels表';
ALTER TABLE maintenance_tickets ADD INDEX idx_hotel_id (hotel_id);

-- 6. 评价表 (reviews)
ALTER TABLE reviews ADD COLUMN hotel_id INT NOT NULL DEFAULT 1 COMMENT '酒店ID-关联hotels表';
ALTER TABLE reviews ADD INDEX idx_hotel_id (hotel_id);

-- 7. 呼叫记录表 (calls)
ALTER TABLE calls ADD COLUMN hotel_id INT NOT NULL DEFAULT 1 COMMENT '酒店ID-关联hotels表';
ALTER TABLE calls ADD INDEX idx_hotel_id (hotel_id);

-- 8. 优惠券表 (coupons)
ALTER TABLE coupons ADD COLUMN hotel_id INT NOT NULL DEFAULT 1 COMMENT '酒店ID-关联hotels表(Null表示全局优惠券)';
ALTER TABLE coupons ADD INDEX idx_hotel_id (hotel_id);

-- ============================================
-- 数据迁移说明:
-- ============================================
-- 1. 默认值设为1, 表示将现有数据归属到ID为1的默认酒店
-- 2. 如果需要分配到其他酒店, 请执行UPDATE语句:
--    UPDATE rooms SET hotel_id = <目标酒店ID> WHERE <条件>;
-- 3. 已为所有新字段创建索引以优化查询性能
-- 4. 建议在业务低峰期执行此脚本
-- ============================================

-- 验证语句（执行后可运行以下命令验证）
-- SHOW COLUMNS FROM rooms LIKE 'hotel_id';
-- SELECT COUNT(*) FROM rooms WHERE hotel_id = 1;
