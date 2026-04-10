-- ==========================================
-- 智慧酒店系统 - 完整测试数据
-- 创建时间: 2026-04-10
-- ==========================================

USE iot_hotel_system;

-- ==========================================
-- 1. 创建测试酒店数据
-- ==========================================
INSERT INTO hotels (hotel_name, hotel_address, hotel_phone, hotel_star, total_rooms, occupied_rooms, occupancy_rate, logo, description, city, location, star_rating, rating, review_count, image_url, promotion) VALUES
('智慧花园酒店', '广州市天河区珠江新城花城大道1号', '020-12345678', 5, 120, 85, 70.83, 'https://example.com/hotel3-logo.jpg', '位于珠江新城核心地段的五星级智能酒店，拥有完善的IoT智能客房系统，提供语音控制、智能灯光、环境监测等全方位智能服务', '广州市', '珠江新城花城大道1号', 5, 4.85, 328, '["https://example.com/hotel3-1.jpg", "https://example.com/hotel3-2.jpg"]', '新客首住8折优惠'),
('云端精品酒店', '深圳市南山区科技园南区2号', '0755-87654321', 4, 80, 52, 65.00, 'https://example.com/hotel4-logo.jpg', '科技园区的精品智能酒店，专为商务人士打造，提供高速网络、智能会议、自助入住等便捷服务', '深圳市', '南山区科技园南区2号', 4, 4.65, 186, '["https://example.com/hotel4-1.jpg"]', '连住3晚享7折'),
('山水度假村', '杭州市西湖区龙井路88号', '0571-88886666', 5, 200, 156, 78.00, 'https://example.com/hotel5-logo.jpg', '依山傍水的度假型智能酒店，融合自然景观与智能科技，提供温泉、SPA、智能客房等高端服务', '杭州市', '西湖区龙井路88号', 5, 4.92, 512, '["https://example.com/hotel5-1.jpg", "https://example.com/hotel5-2.jpg", "https://example.com/hotel5-3.jpg"]', '周末特惠套餐'),
('都市便捷酒店', '成都市锦江区春熙路168号', '028-66668888', 3, 150, 120, 80.00, 'https://example.com/hotel6-logo.jpg', '位于春熙路商圈的经济型智能酒店，性价比高，提供基础智能服务，适合商务出行和旅游住宿', '成都市', '锦江区春熙路168号', 3, 4.45, 892, '["https://example.com/hotel6-1.jpg"]', '会员专享价');

-- ==========================================
-- 2. 创建房间类型数据
-- ==========================================
INSERT INTO room_types (name, code, base_price, area, bed_type, max_guests, facilities, description, images, hotel_id) VALUES
('标准大床房', 'standard_king', 299.00, 28.00, 'king', 2, '["WiFi", "空调", "电视", "独立卫浴", "吹风机", "电热水壶"]', '舒适的标准大床房，配备1.8米大床，适合商务出行或情侣入住', '["https://example.com/room/std-king-1.jpg"]', 1),
('豪华双床房', 'deluxe_twin', 399.00, 35.00, 'twin', 2, '["WiFi", "空调", "电视", "独立卫浴", "迷你吧", "保险箱", "浴袍"]', '宽敞明亮的豪华双床房，配备两张1.2米单人床，适合朋友或家庭出行', '["https://example.com/room/dlx-twin-1.jpg"]', 1),
('商务套房', 'business_suite', 599.00, 55.00, 'king', 2, '["WiFi", "空调", "电视", "独立卫浴", "迷你吧", "保险箱", "浴袍", "会客区", "办公区"]', '专为商务人士设计的套房，配备独立会客区和办公区', '["https://example.com/room/biz-suite-1.jpg"]', 1),
('总统套房', 'presidential', 1999.00, 120.00, 'king', 4, '["WiFi", "空调", "电视", "独立卫浴", "迷你吧", "保险箱", "浴袍", "会客区", "餐厅", "厨房", "按摩浴缸", "桑拿房"]', '顶级奢华的总统套房，配备全套智能家居系统，享受尊贵体验', '["https://example.com/room/presidential-1.jpg"]', 1),
('标准大床房', 'standard_king', 259.00, 25.00, 'king', 2, '["WiFi", "空调", "电视", "独立卫浴"]', '经济实惠的标准大床房', '["https://example.com/room/std-king-2.jpg"]', 2),
('豪华大床房', 'deluxe_king', 359.00, 32.00, 'king', 2, '["WiFi", "空调", "电视", "独立卫浴", "迷你吧"]', '舒适的豪华大床房', '["https://example.com/room/dlx-king-2.jpg"]', 2),
('标准大床房', 'standard_king', 399.00, 30.00, 'king', 2, '["WiFi", "空调", "智能电视", "独立卫浴", "智能灯光", "语音控制"]', '配备全套IoT智能设备的标准房', '["https://example.com/room/std-king-3.jpg"]', 3),
('智能豪华房', 'smart_deluxe', 599.00, 40.00, 'king', 2, '["WiFi", "空调", "智能电视", "独立卫浴", "智能灯光", "语音控制", "智能窗帘", "环境监测"]', '全面升级的智能豪华房', '["https://example.com/room/smart-dlx-3.jpg"]', 3),
('景观套房', 'view_suite', 899.00, 70.00, 'king', 2, '["WiFi", "空调", "智能电视", "独立卫浴", "智能灯光", "语音控制", "智能窗帘", "环境监测", "观景阳台"]', '可欣赏城市景观的智能套房', '["https://example.com/room/view-suite-3.jpg"]', 3),
('山景别墅', 'villa_mountain', 2999.00, 200.00, 'king', 6, '["WiFi", "空调", "智能电视", "独立卫浴", "智能灯光", "语音控制", "私人泳池", "温泉", "花园"]', '独立山景别墅，极致私密与奢华', '["https://example.com/room/villa-5.jpg"]', 5),
('经济大床房', 'budget_king', 159.00, 20.00, 'king', 2, '["WiFi", "空调", "电视", "独立卫浴"]', '经济实惠的大床房', '["https://example.com/room/budget-6.jpg"]', 6),
('舒适双床房', 'comfort_twin', 189.00, 22.00, 'twin', 2, '["WiFi", "空调", "电视", "独立卫浴"]', '舒适的双床房', '["https://example.com/room/comfort-6.jpg"]', 6);

-- ==========================================
-- 3. 创建测试房间数据
-- ==========================================
INSERT INTO rooms (hotel_id, room_number, room_type, room_type_id, room_name, room_price, room_status, floor, area, bed_type, max_guests, description, facilities, images, image_url) VALUES
-- 酒店1 (智联酒店) 的房间
(1, '101', 'standard', 1, '标准大床房-101', 299.00, 'available', 1, 28.00, 'king', 2, '一楼标准大床房，靠近大堂，出入方便', '["WiFi", "空调", "电视", "独立卫浴"]', '["https://example.com/r101-1.jpg"]', 'https://example.com/r101-main.jpg'),
(1, '102', 'standard', 1, '标准大床房-102', 299.00, 'available', 1, 28.00, 'king', 2, '一楼标准大床房', '["WiFi", "空调", "电视", "独立卫浴"]', '["https://example.com/r102-1.jpg"]', 'https://example.com/r102-main.jpg'),
(1, '201', 'deluxe', 2, '豪华双床房-201', 399.00, 'available', 2, 35.00, 'twin', 2, '二楼豪华双床房，视野开阔', '["WiFi", "空调", "电视", "独立卫浴", "迷你吧"]', '["https://example.com/r201-1.jpg"]', 'https://example.com/r201-main.jpg'),
(1, '202', 'deluxe', 2, '豪华双床房-202', 399.00, 'occupied', 2, 35.00, 'twin', 2, '二楼豪华双床房', '["WiFi", "空调", "电视", "独立卫浴", "迷你吧"]', '["https://example.com/r202-1.jpg"]', 'https://example.com/r202-main.jpg'),
(1, '301', 'suite', 3, '商务套房-301', 599.00, 'available', 3, 55.00, 'king', 2, '三楼商务套房，配备办公区', '["WiFi", "空调", "电视", "独立卫浴", "迷你吧", "办公区"]', '["https://example.com/r301-1.jpg"]', 'https://example.com/r301-main.jpg'),
(1, '801', 'presidential', 4, '总统套房-801', 1999.00, 'available', 8, 120.00, 'king', 4, '八楼总统套房，顶级奢华', '["WiFi", "空调", "电视", "独立卫浴", "迷你吧", "会客区", "餐厅"]', '["https://example.com/r801-1.jpg"]', 'https://example.com/r801-main.jpg'),

-- 酒店3 (智慧花园酒店) 的房间
(3, 'A101', 'standard', 7, '智能标准房-A101', 399.00, 'available', 1, 30.00, 'king', 2, 'A栋一楼智能标准房', '["WiFi", "空调", "智能电视", "智能灯光", "语音控制"]', '["https://example.com/a101-1.jpg"]', 'https://example.com/a101-main.jpg'),
(3, 'A102', 'standard', 7, '智能标准房-A102', 399.00, 'available', 1, 30.00, 'king', 2, 'A栋一楼智能标准房', '["WiFi", "空调", "智能电视", "智能灯光", "语音控制"]', '["https://example.com/a102-1.jpg"]', 'https://example.com/a102-main.jpg'),
(3, 'A201', 'deluxe', 8, '智能豪华房-A201', 599.00, 'available', 2, 40.00, 'king', 2, 'A栋二楼智能豪华房', '["WiFi", "空调", "智能电视", "智能灯光", "语音控制", "智能窗帘"]', '["https://example.com/a201-1.jpg"]', 'https://example.com/a201-main.jpg'),
(3, 'A202', 'deluxe', 8, '智能豪华房-A202', 599.00, 'occupied', 2, 40.00, 'king', 2, 'A栋二楼智能豪华房', '["WiFi", "空调", "智能电视", "智能灯光", "语音控制", "智能窗帘"]', '["https://example.com/a202-1.jpg"]', 'https://example.com/a202-main.jpg'),
(3, 'B501', 'suite', 9, '景观套房-B501', 899.00, 'available', 5, 70.00, 'king', 2, 'B栋五楼景观套房，可欣赏珠江夜景', '["WiFi", "空调", "智能电视", "智能灯光", "语音控制", "观景阳台"]', '["https://example.com/b501-1.jpg"]', 'https://example.com/b501-main.jpg'),
(3, 'B502', 'suite', 9, '景观套房-B502', 899.00, 'available', 5, 70.00, 'king', 2, 'B栋五楼景观套房', '["WiFi", "空调", "智能电视", "智能灯光", "语音控制", "观景阳台"]', '["https://example.com/b502-1.jpg"]', 'https://example.com/b502-main.jpg'),

-- 酒店5 (山水度假村) 的房间
(5, 'V01', 'villa', 10, '山景别墅-V01', 2999.00, 'available', 1, 200.00, 'king', 6, '独立山景别墅，带私人泳池', '["WiFi", "空调", "智能电视", "私人泳池", "温泉", "花园"]', '["https://example.com/v01-1.jpg"]', 'https://example.com/v01-main.jpg'),
(5, 'V02', 'villa', 10, '山景别墅-V02', 2999.00, 'occupied', 1, 200.00, 'king', 6, '独立山景别墅', '["WiFi", "空调", "智能电视", "私人泳池", "温泉", "花园"]', '["https://example.com/v02-1.jpg"]', 'https://example.com/v02-main.jpg'),

-- 酒店6 (都市便捷酒店) 的房间
(6, '301', 'standard', 11, '经济大床房-301', 159.00, 'available', 3, 20.00, 'king', 2, '三楼经济大床房', '["WiFi", "空调", "电视", "独立卫浴"]', '["https://example.com/6301-1.jpg"]', 'https://example.com/6301-main.jpg'),
(6, '302', 'standard', 11, '经济大床房-302', 159.00, 'available', 3, 20.00, 'king', 2, '三楼经济大床房', '["WiFi", "空调", "电视", "独立卫浴"]', '["https://example.com/6302-1.jpg"]', 'https://example.com/6302-main.jpg'),
(6, '303', 'standard', 12, '舒适双床房-303', 189.00, 'available', 3, 22.00, 'twin', 2, '三楼舒适双床房', '["WiFi", "空调", "电视", "独立卫浴"]', '["https://example.com/6303-1.jpg"]', 'https://example.com/6303-main.jpg'),
(6, '401', 'standard', 11, '经济大床房-401', 159.00, 'cleaning', 4, 20.00, 'king', 2, '四楼经济大床房', '["WiFi", "空调", "电视", "独立卫浴"]', '["https://example.com/6401-1.jpg"]', 'https://example.com/6401-main.jpg');

-- ==========================================
-- 4. 创建测试会员数据
-- ==========================================
INSERT INTO members (phone, password, name, id_number, member_level, experience, last_checkin_date, points, balance, total_spent, total_stays) VALUES
('13800138001', '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', '张三', '110101199001011234', 'standard', 100, '2026-04-01', 500, 200.00, 1500.00, 3),
('13800138002', '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', '李四', '310101199002022345', 'gold', 2500, '2026-03-28', 3500, 500.00, 8500.00, 12),
('13800138003', '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', '王五', '440106199003033456', 'platinum', 8000, '2026-04-05', 12000, 1000.00, 25000.00, 28),
('13800138004', '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', '赵六', '500101199004044567', 'diamond', 15000, '2026-04-08', 25000, 2000.00, 50000.00, 45),
('13800138005', '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', '陈七', '330102199005055678', 'standard', 0, NULL, 100, 0.00, 0.00, 0),
('13800138006', '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', '刘八', '420106199006066789', 'gold', 1800, '2026-03-15', 2800, 300.00, 6800.00, 8),
('13800138007', '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', '周九', '510107199007077890', 'standard', 50, '2026-04-02', 200, 50.00, 800.00, 1),
('13800138008', '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', '吴十', '610104199008088901', 'platinum', 6000, '2026-03-20', 8500, 800.00, 18000.00, 20);

-- ==========================================
-- 5. 创建测试优惠券数据
-- ==========================================
INSERT INTO coupons (coupon_name, coupon_code, coupon_type, discount_value, min_amount, total_count, is_multiple_use, received_count, valid_from, valid_to, hotel_id) VALUES
('新客专享券', 'NEWBIE100', 'cash', 100.00, 300.00, 1000, 0, 156, '2026-01-01', '2026-12-31', 0),
('满减优惠券', 'DISCOUNT50', 'cash', 50.00, 200.00, 2000, 0, 423, '2026-01-01', '2026-06-30', 0),
('周末特惠券', 'WEEKEND80', 'cash', 80.00, 500.00, 500, 0, 89, '2026-04-01', '2026-12-31', 0),
('连住优惠', 'STAY3NIGHTS', 'cash', 150.00, 800.00, 300, 0, 45, '2026-04-01', '2026-09-30', 0),
('酒店1专享券', 'HOTEL1VIP', 'cash', 200.00, 600.00, 200, 0, 23, '2026-04-01', '2026-12-31', 1),
('酒店3新客券', 'HOTEL3NEW', 'cash', 120.00, 400.00, 300, 0, 67, '2026-04-01', '2026-08-31', 3),
('会员生日券', 'BIRTHDAY200', 'cash', 200.00, 0.00, 10000, 1, 523, '2026-01-01', '2026-12-31', 0),
('钻石会员专享', 'DIAMOND300', 'cash', 300.00, 1000.00, 100, 0, 12, '2026-04-01', '2026-12-31', 0);

-- ==========================================
-- 6. 创建会员优惠券关联数据
-- ==========================================
INSERT INTO member_coupons (member_id, coupon_id, status, used_at) VALUES
(4, 1, 'unused', NULL),
(4, 2, 'unused', NULL),
(4, 8, 'unused', NULL),
(3, 1, 'used', '2026-04-05 14:30:00'),
(3, 3, 'unused', NULL),
(2, 2, 'used', '2026-03-28 10:15:00'),
(2, 4, 'unused', NULL),
(6, 1, 'unused', NULL),
(6, 5, 'unused', NULL),
(7, 1, 'unused', NULL),
(8, 3, 'unused', NULL),
(8, 6, 'unused', NULL);

-- ==========================================
-- 7. 创建测试用户数据 (系统用户)
-- ==========================================
INSERT INTO users (username, password, phone, uid, email, avatar, role, hotel_id, permissions) VALUES
('admin_sys', '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', '13900001001', 'UID000001', 'admin@hotel.com', 'https://example.com/avatar/admin.jpg', 'admin', 0, '["all"]'),
('manager1', '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', '13900001002', 'UID000002', 'manager1@hotel.com', 'https://example.com/avatar/manager1.jpg', 'manager', 1, '["hotel:read", "hotel:write", "room:read", "room:write", "booking:read", "booking:write"]'),
('manager3', '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', '13900001003', 'UID000003', 'manager3@hotel.com', 'https://example.com/avatar/manager3.jpg', 'manager', 3, '["hotel:read", "hotel:write", "room:read", "room:write", "booking:read", "booking:write"]'),
('reception1', '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', '13900001004', 'UID000004', 'rec1@hotel.com', 'https://example.com/avatar/rec1.jpg', 'staff', 1, '["booking:read", "booking:write", "guest:read"]'),
('reception3', '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', '13900001005', 'UID000005', 'rec3@hotel.com', 'https://example.com/avatar/rec3.jpg', 'staff', 3, '["booking:read", "booking:write", "guest:read"]'),
('technician1', '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', '13900001006', 'UID000006', 'tech1@hotel.com', 'https://example.com/avatar/tech1.jpg', 'staff', 1, '["device:read", "device:write", "maintenance:read", "maintenance:write"]'),
('cleaner1', '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', '13900001007', 'UID000007', 'clean1@hotel.com', 'https://example.com/avatar/clean1.jpg', 'staff', 1, '["room:read", "room:cleaning"]'),
('finance1', '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', '13900001008', 'UID000008', 'finance1@hotel.com', 'https://example.com/avatar/finance1.jpg', 'staff', 1, '["payment:read", "report:read"]');

-- ==========================================
-- 8. 创建设备数据
-- ==========================================
INSERT INTO devices (device_id, device_type, device_name, device_key, device_status, firmware_version, last_seen) VALUES
('MAIN001', 'main', '前台管理端-主控', 'key_main_001', 'online', 'v2.1.0', NOW()),
('SUB101', 'sub1', '1楼环境监测器', 'key_sub1_001', 'online', 'v1.5.2', NOW()),
('SUB201', 'sub1', '2楼环境监测器', 'key_sub1_002', 'online', 'v1.5.2', NOW()),
('SUB301', 'sub1', '3楼环境监测器', 'key_sub1_003', 'online', 'v1.5.2', NOW()),
('ROOM101', 'sub2', '客房101控制器', 'key_room_101', 'online', 'v1.8.0', NOW()),
('ROOM102', 'sub2', '客房102控制器', 'key_room_102', 'online', 'v1.8.0', NOW()),
('ROOM201', 'sub2', '客房201控制器', 'key_room_201', 'online', 'v1.8.0', NOW()),
('ROOM202', 'sub2', '客房202控制器', 'key_room_202', 'offline', 'v1.8.0', DATE_SUB(NOW(), INTERVAL 2 DAY)),
('ROOM301', 'sub2', '客房301控制器', 'key_room_301', 'online', 'v1.8.0', NOW()),
('ROOM801', 'sub2', '总统套房801控制器', 'key_room_801', 'online', 'v2.0.0', NOW()),
('A101', 'sub2', 'A101智能客房', 'key_a101', 'online', 'v2.1.0', NOW()),
('A102', 'sub2', 'A102智能客房', 'key_a102', 'online', 'v2.1.0', NOW()),
('A201', 'sub2', 'A201智能客房', 'key_a201', 'online', 'v2.1.0', NOW()),
('A202', 'sub2', 'A202智能客房', 'key_a202', 'online', 'v2.1.0', NOW()),
('B501', 'sub2', 'B501景观套房', 'key_b501', 'online', 'v2.1.0', NOW()),
('V01', 'sub2', 'V01山景别墅', 'key_v01', 'online', 'v2.2.0', NOW());

-- ==========================================
-- 9. 创建常用入住人数据
-- ==========================================
INSERT INTO frequent_guests (user_id, name, phone, id_type, id_number) VALUES
(5, '张三家属', '13800138011', 'idcard', '110101199101011235'),
(5, '张三同事', '13800138012', 'idcard', '110101199201021236'),
(6, '李四配偶', '13800138021', 'idcard', '310101199102022346'),
(6, '李四孩子', '13800138022', 'idcard', '310101201501011234'),
(7, '王五朋友', '13800138031', 'passport', 'E12345678'),
(8, '赵六助理', '13800138041', 'idcard', '500101199104044568');

-- ==========================================
-- 10. 创建用户酒店关联数据
-- ==========================================
INSERT INTO user_hotels (user_id, hotel_id) VALUES
(2, 1),
(2, 3),
(4, 1),
(5, 3),
(6, 1),
(7, 1),
(8, 1);

SELECT '测试数据创建完成!' AS result;
