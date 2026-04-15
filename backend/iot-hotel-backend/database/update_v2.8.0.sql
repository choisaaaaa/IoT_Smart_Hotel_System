-- 智慧酒店物联网控制系统 - 数据库更新脚本 (v2.8.0)
-- 适配前台端现场打折功能

USE iot_hotel_system;

-- -----------------------------------------------------------------------------
-- 1. 更新预订表 (Bookings)
-- -----------------------------------------------------------------------------
ALTER TABLE bookings ADD COLUMN manual_discount DECIMAL(3,2) DEFAULT 1.00 COMMENT '前台手动打折折扣率' AFTER points_discount;
ALTER TABLE bookings ADD COLUMN manual_reduce DECIMAL(10,2) DEFAULT 0.00 COMMENT '前台手动打折直减金额' AFTER manual_discount;

-- -----------------------------------------------------------------------------
-- 2. 数据库说明更新完毕
-- -----------------------------------------------------------------------------
