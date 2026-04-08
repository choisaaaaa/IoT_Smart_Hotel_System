USE iot_hotel_system;

ALTER TABLE hotels ADD COLUMN hotel_id INT NULL;
ALTER TABLE hotels ADD COLUMN hotel_code VARCHAR(50) NULL;
ALTER TABLE hotels ADD COLUMN city VARCHAR(100) NULL;
ALTER TABLE hotels ADD COLUMN location VARCHAR(255) NULL;
ALTER TABLE hotels ADD COLUMN star_rating INT DEFAULT 3;
ALTER TABLE hotels ADD COLUMN rating DECIMAL(3,2) DEFAULT 4.50;
ALTER TABLE hotels ADD COLUMN review_count INT DEFAULT 0;
ALTER TABLE hotels ADD COLUMN image_url VARCHAR(255) NULL;
ALTER TABLE hotels ADD COLUMN promotion VARCHAR(255) NULL;

UPDATE hotels
SET
  hotel_id = IFNULL(hotel_id, id),
  location = IFNULL(location, hotel_address),
  star_rating = IFNULL(star_rating, hotel_star);

ALTER TABLE rooms ADD COLUMN hotel_id INT NULL;
ALTER TABLE rooms ADD COLUMN room_id INT NULL;
ALTER TABLE rooms ADD COLUMN image_url VARCHAR(255) NULL;

UPDATE rooms
SET
  hotel_id = IFNULL(hotel_id, 1),
  room_id = IFNULL(room_id, id);

ALTER TABLE bookings ADD COLUMN hotel_id INT NULL AFTER booking_number;

UPDATE bookings b
LEFT JOIN rooms r ON b.room_id = r.id
SET b.hotel_id = IFNULL(b.hotel_id, r.hotel_id);

ALTER TABLE users ADD COLUMN hotel_id INT NULL;

UPDATE users
SET hotel_id = IFNULL(hotel_id, 1);

ALTER TABLE devices ADD COLUMN hotel_id INT NULL;

UPDATE devices d
LEFT JOIN rooms r ON d.room_id = r.id
SET d.hotel_id = IFNULL(d.hotel_id, IFNULL(r.hotel_id, 1));

SET @fk_room_hotel_exists = (
  SELECT COUNT(*)
  FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'rooms' AND CONSTRAINT_NAME = 'fk_rooms_hotel_id'
);
SET @sql_room_hotel_fk = IF(
  @fk_room_hotel_exists > 0,
  'SELECT 1',
  'ALTER TABLE rooms ADD CONSTRAINT fk_rooms_hotel_id FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE CASCADE'
);
PREPARE stmt_room_hotel_fk FROM @sql_room_hotel_fk;
EXECUTE stmt_room_hotel_fk;
DEALLOCATE PREPARE stmt_room_hotel_fk;

SET @fk_booking_hotel_exists = (
  SELECT COUNT(*)
  FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bookings' AND CONSTRAINT_NAME = 'fk_bookings_hotel_id'
);
SET @sql_booking_hotel_fk = IF(
  @fk_booking_hotel_exists > 0,
  'SELECT 1',
  'ALTER TABLE bookings ADD CONSTRAINT fk_bookings_hotel_id FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE SET NULL'
);
PREPARE stmt_booking_hotel_fk FROM @sql_booking_hotel_fk;
EXECUTE stmt_booking_hotel_fk;
DEALLOCATE PREPARE stmt_booking_hotel_fk;

SET @fk_users_hotel_exists = (
  SELECT COUNT(*)
  FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND CONSTRAINT_NAME = 'fk_users_hotel_id'
);
SET @sql_users_hotel_fk = IF(
  @fk_users_hotel_exists > 0,
  'SELECT 1',
  'ALTER TABLE users ADD CONSTRAINT fk_users_hotel_id FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE SET NULL'
);
PREPARE stmt_users_hotel_fk FROM @sql_users_hotel_fk;
EXECUTE stmt_users_hotel_fk;
DEALLOCATE PREPARE stmt_users_hotel_fk;

SET @fk_devices_hotel_exists = (
  SELECT COUNT(*)
  FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'devices' AND CONSTRAINT_NAME = 'fk_devices_hotel_id'
);
SET @sql_devices_hotel_fk = IF(
  @fk_devices_hotel_exists > 0,
  'SELECT 1',
  'ALTER TABLE devices ADD CONSTRAINT fk_devices_hotel_id FOREIGN KEY (hotel_id) REFERENCES hotels(id) ON DELETE SET NULL'
);
PREPARE stmt_devices_hotel_fk FROM @sql_devices_hotel_fk;
EXECUTE stmt_devices_hotel_fk;
DEALLOCATE PREPARE stmt_devices_hotel_fk;

SET @idx_hotels_hotel_id_exists = (
  SELECT COUNT(*)
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hotels' AND INDEX_NAME = 'idx_hotels_hotel_id'
);
SET @sql_idx_hotels_hotel_id = IF(
  @idx_hotels_hotel_id_exists > 0,
  'SELECT 1',
  'CREATE INDEX idx_hotels_hotel_id ON hotels(hotel_id)'
);
PREPARE stmt_idx_hotels_hotel_id FROM @sql_idx_hotels_hotel_id;
EXECUTE stmt_idx_hotels_hotel_id;
DEALLOCATE PREPARE stmt_idx_hotels_hotel_id;

SET @idx_rooms_hotel_id_exists = (
  SELECT COUNT(*)
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'rooms' AND INDEX_NAME = 'idx_rooms_hotel_id'
);
SET @sql_idx_rooms_hotel_id = IF(
  @idx_rooms_hotel_id_exists > 0,
  'SELECT 1',
  'CREATE INDEX idx_rooms_hotel_id ON rooms(hotel_id)'
);
PREPARE stmt_idx_rooms_hotel_id FROM @sql_idx_rooms_hotel_id;
EXECUTE stmt_idx_rooms_hotel_id;
DEALLOCATE PREPARE stmt_idx_rooms_hotel_id;

SET @idx_rooms_room_id_exists = (
  SELECT COUNT(*)
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'rooms' AND INDEX_NAME = 'idx_rooms_room_id'
);
SET @sql_idx_rooms_room_id = IF(
  @idx_rooms_room_id_exists > 0,
  'SELECT 1',
  'CREATE INDEX idx_rooms_room_id ON rooms(room_id)'
);
PREPARE stmt_idx_rooms_room_id FROM @sql_idx_rooms_room_id;
EXECUTE stmt_idx_rooms_room_id;
DEALLOCATE PREPARE stmt_idx_rooms_room_id;

SET @idx_bookings_hotel_id_exists = (
  SELECT COUNT(*)
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'bookings' AND INDEX_NAME = 'idx_bookings_hotel_id'
);
SET @sql_idx_bookings_hotel_id = IF(
  @idx_bookings_hotel_id_exists > 0,
  'SELECT 1',
  'CREATE INDEX idx_bookings_hotel_id ON bookings(hotel_id)'
);
PREPARE stmt_idx_bookings_hotel_id FROM @sql_idx_bookings_hotel_id;
EXECUTE stmt_idx_bookings_hotel_id;
DEALLOCATE PREPARE stmt_idx_bookings_hotel_id;

SET @idx_users_hotel_id_exists = (
  SELECT COUNT(*)
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND INDEX_NAME = 'idx_users_hotel_id'
);
SET @sql_idx_users_hotel_id = IF(
  @idx_users_hotel_id_exists > 0,
  'SELECT 1',
  'CREATE INDEX idx_users_hotel_id ON users(hotel_id)'
);
PREPARE stmt_idx_users_hotel_id FROM @sql_idx_users_hotel_id;
EXECUTE stmt_idx_users_hotel_id;
DEALLOCATE PREPARE stmt_idx_users_hotel_id;

SET @idx_devices_hotel_id_exists = (
  SELECT COUNT(*)
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'devices' AND INDEX_NAME = 'idx_devices_hotel_id'
);
SET @sql_idx_devices_hotel_id = IF(
  @idx_devices_hotel_id_exists > 0,
  'SELECT 1',
  'CREATE INDEX idx_devices_hotel_id ON devices(hotel_id)'
);
PREPARE stmt_idx_devices_hotel_id FROM @sql_idx_devices_hotel_id;
EXECUTE stmt_idx_devices_hotel_id;
DEALLOCATE PREPARE stmt_idx_devices_hotel_id;
