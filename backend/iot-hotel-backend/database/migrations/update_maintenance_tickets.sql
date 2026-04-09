-- 智慧酒店物联网控制系统 - 报修管理更新脚本
-- 版本: v2.5.2
-- 更新内容：添加维修分配相关的字段

USE iot_hotel_system;

-- 1. 为 maintenance_tickets 表添加 repairer 和 assigned_at 字段
ALTER TABLE maintenance_tickets 
ADD COLUMN repairer VARCHAR(50) DEFAULT NULL COMMENT '维修人员' AFTER status,
ADD COLUMN assigned_at DATETIME DEFAULT NULL COMMENT '分配时间' AFTER repairer;
