-- 智慧酒店物联网控制系统 - 数据库维护脚本 (v3.1.2)
-- 修复 rooms 表中 room_type_id 缺失的问题，确保选房功能正常

USE iot_hotel_system;

-- -----------------------------------------------------------------------------
-- 1. 修复 rooms 表的 room_type_id
-- -----------------------------------------------------------------------------
-- 根据 room_type (code) 匹配 room_types 表并回填 room_type_id
UPDATE rooms r
JOIN room_types rt ON r.room_type = rt.code AND (rt.hotel_id = r.hotel_id OR rt.hotel_id = 0)
SET r.room_type_id = rt.id
WHERE r.room_type_id IS NULL;

-- -----------------------------------------------------------------------------
-- 2. 修复 bookings 表中缺失的 room_type_id (针对旧订单)
-- -----------------------------------------------------------------------------
-- 情况A：已分配房间的订单，从 rooms 表获取 room_type_id
UPDATE bookings b
JOIN rooms r ON b.room_id = r.id
SET b.room_type_id = r.room_type_id
WHERE b.room_type_id IS NULL AND b.room_id IS NOT NULL;

-- 情况B：未分配房间的订单，从 rate_plans 获取 room_type_id
UPDATE bookings b
JOIN rate_plans rp ON b.rate_plan_id = rp.id
SET b.room_type_id = rp.room_type_id
WHERE b.room_type_id IS NULL AND b.rate_plan_id IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 3. 维护完毕
-- -----------------------------------------------------------------------------
