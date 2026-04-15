-- 智慧酒店物联网控制系统 - 数据库更新脚本 (v3.0.0)
-- 适配客房余量解耦与预入住选房逻辑

USE iot_hotel_system;

-- -----------------------------------------------------------------------------
-- 1. 更新预订表 (Bookings) - 使房间ID可选
-- -----------------------------------------------------------------------------
ALTER TABLE bookings MODIFY room_id INT NULL COMMENT '预订时不绑定房间，入住前选房';
ALTER TABLE bookings ADD COLUMN room_type_id INT NULL COMMENT '预订时的房型ID' AFTER room_id;

-- -----------------------------------------------------------------------------
-- 2. 更新价格日历表 (Room Prices) - 增加方案关联与余量控制
-- -----------------------------------------------------------------------------
-- 增加房价方案关联字段
ALTER TABLE room_prices ADD COLUMN rate_plan_id INT NULL AFTER room_type_id;

-- 更新唯一索引，支持同一房型不同方案的每日价格与余量
ALTER TABLE room_prices DROP INDEX uk_room_type_date;
ALTER TABLE room_prices ADD UNIQUE KEY uk_room_type_plan_date (room_type_id, rate_plan_id, price_date);

-- 增加余量与售出字段
ALTER TABLE room_prices ADD COLUMN inventory_count INT DEFAULT 0 COMMENT '当日该方案可售余量' AFTER final_price;-- 增加已售数量
ALTER TABLE room_prices ADD COLUMN sold_count INT DEFAULT 0 COMMENT '当日该方案已售数量' AFTER inventory_count;

-- -----------------------------------------------------------------------------
-- 3. 更新房价方案表 (Rate Plans) - 增加默认余量
-- -----------------------------------------------------------------------------
ALTER TABLE rate_plans ADD COLUMN default_inventory INT DEFAULT 10 COMMENT '该方案默认每日可售余量';

-- -----------------------------------------------------------------------------
-- 4. 数据库说明更新完毕
-- -----------------------------------------------------------------------------
