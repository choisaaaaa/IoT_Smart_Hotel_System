-- 为 guest01 办理 101 房间入住
-- 先检查房间101是否存在
SELECT id, room_number, room_status FROM rooms WHERE room_number = '101';

-- 插入预订记录（已入住状态）
INSERT INTO bookings (
    booking_number,
    hotel_id,
    room_id,
    guest_name,
    guest_phone,
    guest_id_number,
    check_in_date,
    check_out_date,
    guest_count,
    special_requests,
    payment_method,
    total_price,
    deposit,
    status,
    check_in_time
) VALUES (
    CONCAT('BK', DATE_FORMAT(CURDATE(), '%Y%m%d'), UPPER(SUBSTRING(MD5(RAND()), 1, 8))),
    1,
    (SELECT id FROM rooms WHERE room_number = '101' LIMIT 1),
    'guest01',
    '13800138001',
    '110101199001011234',
    CURDATE(),
    DATE_ADD(CURDATE(), INTERVAL 1 DAY),
    1,
    NULL,
    'balance',
    299.00,
    0.00,
    'checked_in',
    NOW()
);

-- 更新房间状态为 occupied
UPDATE rooms SET room_status = 'occupied' WHERE room_number = '101';

-- 验证插入结果
SELECT b.*, r.room_number 
FROM bookings b 
JOIN rooms r ON b.room_id = r.id 
WHERE b.guest_name = 'guest01' 
AND r.room_number = '101'
ORDER BY b.id DESC 
LIMIT 1;
