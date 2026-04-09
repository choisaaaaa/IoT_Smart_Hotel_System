-- v4.0.0 Migration: Add phone, uid to users; add user_hotels table; add user_id to bookings

-- 1. Add phone and uid columns to users table
ALTER TABLE users ADD COLUMN phone VARCHAR(20) DEFAULT NULL AFTER password;
ALTER TABLE users ADD COLUMN uid VARCHAR(50) DEFAULT NULL AFTER phone;
ALTER TABLE users ADD UNIQUE KEY uk_phone (phone);
ALTER TABLE users ADD UNIQUE KEY uk_uid (uid);
ALTER TABLE users ADD INDEX idx_phone (phone);

-- 2. Add user_id column to bookings table
ALTER TABLE bookings ADD COLUMN user_id INT DEFAULT NULL AFTER room_id;
ALTER TABLE bookings ADD INDEX idx_user_id (user_id);

-- 3. Create user_hotels table (many-to-many)
CREATE TABLE IF NOT EXISTS user_hotels (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    hotel_id INT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_user_hotel (user_id, hotel_id),
    INDEX idx_user_id (user_id),
    INDEX idx_hotel_id (hotel_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Add manager role to roles table if not exists
INSERT IGNORE INTO roles (role_name, role_description, permissions) VALUES
('manager', '酒店经理，拥有酒店管理权限', '["read","write","delete","manage_bookings","manage_rooms","manage_orders","manage_staff","view_reports","manage_guests","system_config"]');

-- 5. Generate UID for existing users
UPDATE users SET uid = CONCAT('UID', UNIX_TIMESTAMP(created_at), SUBSTRING(MD5(RAND()), 1, 6)) WHERE uid IS NULL;

-- 6. Bind all staff/manager accounts to hotel_id=1 via user_hotels
INSERT IGNORE INTO user_hotels (user_id, hotel_id)
SELECT id, COALESCE(hotel_id, 1) FROM users WHERE role IN ('staff', 'receptionist', 'manager', 'admin', 'system');

-- 7. Ensure reception_01 and reception_02 both have hotel_id=1
UPDATE users SET hotel_id = 1 WHERE username IN ('reception_01', 'reception_02', 'staff01');

-- 8. Update existing bookings: set user_id from guest_name matching
UPDATE bookings b
INNER JOIN users u ON b.guest_name = u.username
SET b.user_id = u.id
WHERE b.user_id IS NULL;
