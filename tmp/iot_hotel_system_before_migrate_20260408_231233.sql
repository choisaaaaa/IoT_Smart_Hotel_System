-- MySQL dump 10.13  Distrib 8.0.45, for Linux (x86_64)
--
-- Host: localhost    Database: iot_hotel_system
-- ------------------------------------------------------
-- Server version	8.0.45

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Current Database: `iot_hotel_system`
--

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `iot_hotel_system` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;

USE `iot_hotel_system`;

--
-- Table structure for table `api_tokens`
--

DROP TABLE IF EXISTS `api_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `api_tokens` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL COMMENT '鐢ㄦ埛 ID',
  `token` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'API Token',
  `token_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'login' COMMENT 'Token 绫诲瀷 (login/api/refresh)',
  `expires_at` datetime NOT NULL COMMENT '杩囨湡鏃堕棿',
  `is_used` tinyint(1) DEFAULT '0' COMMENT '鏄惁宸蹭娇鐢?,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `used_at` datetime DEFAULT NULL COMMENT '浣跨敤鏃堕棿',
  PRIMARY KEY (`id`),
  UNIQUE KEY `token` (`token`),
  KEY `idx_token` (`token`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_expires_at` (`expires_at`),
  CONSTRAINT `api_tokens_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='API Token 琛?;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `api_tokens`
--

LOCK TABLES `api_tokens` WRITE;
/*!40000 ALTER TABLE `api_tokens` DISABLE KEYS */;
INSERT INTO `api_tokens` VALUES (1,1,'d7b758b3034599213ec6511ce98f2fe2fbc2b26179fe40f292353cc38429634d','login','2026-04-08 22:02:26',1,'2026-04-08 21:57:26','2026-04-08 21:57:29');
/*!40000 ALTER TABLE `api_tokens` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `bookings`
--

DROP TABLE IF EXISTS `bookings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `bookings` (
  `id` int NOT NULL AUTO_INCREMENT,
  `hotel_id` int NOT NULL,
  `booking_number` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `room_id` int NOT NULL,
  `guest_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `guest_phone` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `guest_id_number` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `check_in_date` date NOT NULL,
  `check_out_date` date NOT NULL,
  `guest_count` int DEFAULT '1',
  `special_requests` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `payment_method` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT 'balance',
  `total_price` decimal(10,2) NOT NULL DEFAULT '0.00',
  `deposit` decimal(10,2) DEFAULT '0.00',
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `check_in_time` datetime DEFAULT NULL,
  `check_out_time` datetime DEFAULT NULL,
  `cancelled_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_booking_number` (`booking_number`),
  KEY `idx_room_id` (`room_id`),
  KEY `idx_status` (`status`),
  KEY `idx_check_in_date` (`check_in_date`),
  KEY `idx_check_out_date` (`check_out_date`),
  KEY `idx_bookings_status` (`status`),
  KEY `idx_bookings_date` (`check_in_date`,`check_out_date`),
  KEY `idx_bookings_hotel_id` (`hotel_id`),
  CONSTRAINT `fk_bookings_hotel` FOREIGN KEY (`hotel_id`) REFERENCES `hotels` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `bookings`
--

LOCK TABLES `bookings` WRITE;
/*!40000 ALTER TABLE `bookings` DISABLE KEYS */;
INSERT INTO `bookings` VALUES (1,1,'BK20260408E316DB5E',4,'寮犱笁','123456',NULL,'2026-04-09','2026-04-11',1,'','balance',998.00,0.00,'pending','2026-04-08 22:25:41','2026-04-08 22:25:41',NULL,NULL,NULL);
/*!40000 ALTER TABLE `bookings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `calls`
--

DROP TABLE IF EXISTS `calls`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `calls` (
  `id` int NOT NULL AUTO_INCREMENT,
  `call_id` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `caller_type` enum('room','front_desk','ai','app') COLLATE utf8mb4_unicode_ci NOT NULL,
  `caller_id` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '涓诲彨鏍囪瘑(鎴块棿鍙?鍛樺伐ID/AI鏍囪瘑/App鐢ㄦ埛ID)',
  `callee_type` enum('room','front_desk','ai','app') COLLATE utf8mb4_unicode_ci NOT NULL,
  `callee_id` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '琚彨鏍囪瘑',
  `status` enum('calling','outgoing','ringing','connected','ended','rejected','missed','busy') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'calling' COMMENT '閫氳瘽鐘舵€?,
  `started_at` datetime NOT NULL COMMENT '閫氳瘽寮€濮嬫椂闂?,
  `answered_at` datetime DEFAULT NULL COMMENT '鎺ュ惉鏃堕棿',
  `ended_at` datetime DEFAULT NULL COMMENT '缁撴潫鏃堕棿',
  `duration_sec` int NOT NULL DEFAULT '0' COMMENT '閫氳瘽鏃堕暱(绉?',
  `recording_url` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '褰曢煶鏂囦欢URL(鍙€?',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_call_id` (`call_id`),
  KEY `idx_caller` (`caller_type`,`caller_id`),
  KEY `idx_callee` (`callee_type`,`callee_id`),
  KEY `idx_status` (`status`),
  KEY `idx_started_at` (`started_at`),
  KEY `idx_caller_time` (`caller_type`,`caller_id`,`started_at`),
  KEY `idx_callee_time` (`callee_type`,`callee_id`,`started_at`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='璇煶閫氳瘽璁板綍琛紙鏀寔鍙屽悜閫氳瘽锛?;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `calls`
--

LOCK TABLES `calls` WRITE;
/*!40000 ALTER TABLE `calls` DISABLE KEYS */;
INSERT INTO `calls` VALUES (1,'CALL20260401001','room','102','front_desk','FD001','ended','2026-04-01 10:30:00','2026-04-01 10:30:05','2026-04-01 10:35:00',295,NULL,'2026-04-05 00:11:06'),(2,'CALL20260402002','front_desk','FD002','room','201','ended','2026-04-02 14:20:00','2026-04-02 14:20:08','2026-04-02 14:25:30',322,NULL,'2026-04-05 00:11:06'),(3,'CALL20260404003','ai','AI001','room','301','connected','2026-04-05 00:11:06','2026-04-08 22:09:52',NULL,0,NULL,'2026-04-05 00:11:06'),(4,'CALL2026040535434586','room','301','front_desk','FD001','connected','2026-04-05 00:20:49','2026-04-08 22:09:51',NULL,0,NULL,'2026-04-05 00:20:48'),(5,'CALL202604058B1EF15D','ai','AI001','room','103','ended','2026-04-05 00:26:37','2026-04-05 00:27:17','2026-04-05 00:27:25',8,NULL,'2026-04-05 00:26:36'),(6,'CALL202604083E2C471A','front_desk','FD-01','room','102','ended','2026-04-08 22:26:33',NULL,'2026-04-08 22:26:37',0,NULL,'2026-04-08 22:26:33');
/*!40000 ALTER TABLE `calls` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `control_commands`
--

DROP TABLE IF EXISTS `control_commands`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `control_commands` (
  `id` int NOT NULL AUTO_INCREMENT,
  `device_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `command_type` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `command_value` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `command_status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `created_by` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `executed_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_device_id` (`device_id`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_command_status` (`command_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `control_commands`
--

LOCK TABLES `control_commands` WRITE;
/*!40000 ALTER TABLE `control_commands` DISABLE KEYS */;
/*!40000 ALTER TABLE `control_commands` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `coupons`
--

DROP TABLE IF EXISTS `coupons`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `coupons` (
  `id` int NOT NULL AUTO_INCREMENT,
  `coupon_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `coupon_type` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'discount',
  `discount_value` decimal(10,2) NOT NULL DEFAULT '0.00',
  `min_amount` decimal(10,2) DEFAULT '0.00',
  `total_count` int NOT NULL DEFAULT '0',
  `received_count` int NOT NULL DEFAULT '0',
  `valid_from` date NOT NULL,
  `valid_to` date NOT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_valid` (`valid_from`,`valid_to`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `coupons`
--

LOCK TABLES `coupons` WRITE;
/*!40000 ALTER TABLE `coupons` DISABLE KEYS */;
/*!40000 ALTER TABLE `coupons` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `delivery_orders`
--

DROP TABLE IF EXISTS `delivery_orders`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `delivery_orders` (
  `id` int NOT NULL AUTO_INCREMENT,
  `order_no` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `booking_id` int DEFAULT NULL COMMENT '茅垄鈥灻D茂录藛氓鈥β趁佲€漛ookings猫隆篓茂录艗莽鈥澛ぢ号矫┾偓鈧λ喡棵烩€溍€斆尖€?,
  `guest_id` int DEFAULT NULL COMMENT '盲陆聫氓庐垄ID茂录藛氓鈥β趁佲€漡uests猫隆篓茂录艗莽鈥澛ぢ号矫ε撀嵜ヅ犅∶ヂ解€櫭ヂ迸久尖€?,
  `room_id` int NOT NULL,
  `item_category` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'food',
  `item_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `quantity` int NOT NULL DEFAULT '1',
  `note` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `completed_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_order_no` (`order_no`),
  KEY `idx_room_id` (`room_id`),
  KEY `idx_status` (`status`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_booking_id` (`booking_id`),
  KEY `idx_guest_id` (`guest_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `delivery_orders`
--

LOCK TABLES `delivery_orders` WRITE;
/*!40000 ALTER TABLE `delivery_orders` DISABLE KEYS */;
INSERT INTO `delivery_orders` VALUES (1,'DEL20260407F854D393',1,1,1,'bathroom','??',2,'????','pending','2026-04-07 00:27:25','2026-04-07 00:27:25',NULL);
/*!40000 ALTER TABLE `delivery_orders` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `devices`
--

DROP TABLE IF EXISTS `devices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `devices` (
  `id` int NOT NULL AUTO_INCREMENT,
  `hotel_id` int NOT NULL,
  `device_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `device_type` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `device_name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `device_key` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `device_status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'offline',
  `firmware_version` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_seen` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `audit_status` enum('pending','approved','rejected') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending' COMMENT '瀹℃牳鐘舵€?,
  `room_id` int DEFAULT NULL COMMENT '鍏宠仈鎴块棿ID',
  `area` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '鎵€灞炲尯鍩?,
  `ip_address` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '涓婃姤IP鍦板潃',
  `mac_address` varchar(17) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '璁惧MAC鍦板潃',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_device_id` (`device_id`),
  KEY `idx_device_type` (`device_type`),
  KEY `idx_device_status` (`device_status`),
  KEY `idx_audit_status` (`audit_status`),
  KEY `idx_room_id` (`room_id`),
  KEY `idx_mac_address` (`mac_address`),
  KEY `idx_devices_hotel_id` (`hotel_id`),
  CONSTRAINT `fk_device_room` FOREIGN KEY (`room_id`) REFERENCES `rooms` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_devices_hotel` FOREIGN KEY (`hotel_id`) REFERENCES `hotels` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `devices`
--

LOCK TABLES `devices` WRITE;
/*!40000 ALTER TABLE `devices` DISABLE KEYS */;
/*!40000 ALTER TABLE `devices` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `employees`
--

DROP TABLE IF EXISTS `employees`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `employees` (
  `id` int NOT NULL AUTO_INCREMENT,
  `hotel_id` int NOT NULL,
  `employee_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '鍛樺伐宸ュ彿',
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '鍛樺伐濮撳悕',
  `phone` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '鑱旂郴鐢佃瘽',
  `position` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'staff' COMMENT '鑱屼綅(front_desk/manager/tech)',
  `department` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'front_desk' COMMENT '閮ㄩ棬',
  `status` enum('active','inactive','on_leave') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'active' COMMENT '鐘舵€?,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `employee_id` (`employee_id`),
  KEY `idx_employee_id` (`employee_id`),
  KEY `idx_position` (`position`),
  KEY `idx_status` (`status`),
  KEY `idx_employees_hotel_id` (`hotel_id`),
  CONSTRAINT `fk_employees_hotel` FOREIGN KEY (`hotel_id`) REFERENCES `hotels` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='鍛樺伐淇℃伅琛?;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `employees`
--

LOCK TABLES `employees` WRITE;
/*!40000 ALTER TABLE `employees` DISABLE KEYS */;
INSERT INTO `employees` VALUES (1,1,'FD001','氓录聽氓鈥奥嵜ヂ徛?,'13800001001','front_desk','front_desk','active','2026-04-05 00:19:23','2026-04-08 19:00:18'),(2,1,'FD002','忙聺沤莽禄聫莽聬鈥?,'13800001002','manager','front_desk','active','2026-04-05 00:19:23','2026-04-08 19:00:18'),(3,1,'FD003','莽沤鈥姑ヂ⒚ε撀?,'13800001003','staff','front_desk','active','2026-04-05 00:19:23','2026-04-08 19:00:18');
/*!40000 ALTER TABLE `employees` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `floors`
--

DROP TABLE IF EXISTS `floors`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `floors` (
  `id` int NOT NULL AUTO_INCREMENT,
  `hotel_id` int NOT NULL,
  `floor_number` int NOT NULL COMMENT '妤煎眰鍙?,
  `floor_name` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '妤煎眰鍚嶇О',
  `floor_plan_image` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '妤煎眰骞抽潰鍥?,
  `description` text COLLATE utf8mb4_unicode_ci COMMENT '妤煎眰鎻忚堪',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `floor_number` (`floor_number`),
  KEY `idx_floors_hotel_id` (`hotel_id`),
  CONSTRAINT `fk_floors_hotel` FOREIGN KEY (`hotel_id`) REFERENCES `hotels` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `floors`
--

LOCK TABLES `floors` WRITE;
/*!40000 ALTER TABLE `floors` DISABLE KEYS */;
INSERT INTO `floors` VALUES (1,1,1,'1灞?,'/uploads/a298dd30-76a4-4a2e-b045-506f11c086dc.jpg',NULL,'2026-04-08 18:54:14','2026-04-08 21:37:22'),(2,1,2,'2灞?,NULL,NULL,'2026-04-08 18:54:14','2026-04-08 19:00:18'),(3,1,3,'3灞?,NULL,NULL,'2026-04-08 18:54:14','2026-04-08 19:00:18');
/*!40000 ALTER TABLE `floors` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `frequent_guests`
--

DROP TABLE IF EXISTS `frequent_guests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `frequent_guests` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `phone` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `id_type` enum('idcard','passport') COLLATE utf8mb4_unicode_ci DEFAULT 'idcard',
  `id_number` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `frequent_guests`
--

LOCK TABLES `frequent_guests` WRITE;
/*!40000 ALTER TABLE `frequent_guests` DISABLE KEYS */;
INSERT INTO `frequent_guests` VALUES (2,2,'寮犱笁','4516','idcard','156','2026-04-08 11:36:14','2026-04-08 11:36:14');
/*!40000 ALTER TABLE `frequent_guests` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `guests`
--

DROP TABLE IF EXISTS `guests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `guests` (
  `id` int NOT NULL AUTO_INCREMENT,
  `booking_id` int NOT NULL,
  `guest_name` varchar(100) NOT NULL,
  `guest_phone` varchar(20) NOT NULL,
  `guest_id_number` varchar(50) DEFAULT NULL,
  `room_id` int NOT NULL,
  `check_in_time` datetime NOT NULL,
  `check_out_time` datetime DEFAULT NULL,
  `guest_count` int DEFAULT '1',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_booking_id` (`booking_id`),
  KEY `idx_room_id` (`room_id`),
  KEY `idx_check_in_time` (`check_in_time`),
  CONSTRAINT `guests_ibfk_1` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE,
  CONSTRAINT `guests_ibfk_2` FOREIGN KEY (`room_id`) REFERENCES `rooms` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `guests`
--

LOCK TABLES `guests` WRITE;
/*!40000 ALTER TABLE `guests` DISABLE KEYS */;
/*!40000 ALTER TABLE `guests` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `hotels`
--

DROP TABLE IF EXISTS `hotels`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hotels` (
  `id` int NOT NULL AUTO_INCREMENT,
  `hotel_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `hotel_code` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `hotel_address` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `city` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `hotel_phone` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `hotel_star` int DEFAULT '3',
  `total_rooms` int DEFAULT '0',
  `occupied_rooms` int DEFAULT '0',
  `occupancy_rate` decimal(5,2) DEFAULT '0.00',
  `logo` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_hotel_name` (`hotel_name`),
  UNIQUE KEY `hotel_code` (`hotel_code`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `hotels`
--

LOCK TABLES `hotels` WRITE;
/*!40000 ALTER TABLE `hotels` DISABLE KEYS */;
INSERT INTO `hotels` VALUES (1,'鍒樼儴澶╁爞閰掑簵','H001',NULL,'鍖椾含','114514',5,0,0,0.00,'/uploads/8bb31a9a-c418-4ac7-a5a4-2e0769a5a7fa.jpg','鍏ㄥ満鏅墿鑱旂綉鏅烘収閰掑簵','2026-04-08 19:00:17','2026-04-08 21:37:32');
/*!40000 ALTER TABLE `hotels` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `login_sessions`
--

DROP TABLE IF EXISTS `login_sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `login_sessions` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL COMMENT '鐢ㄦ埛 ID',
  `session_token` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '浼氳瘽 Token',
  `device_info` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '璁惧淇℃伅',
  `ip_address` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'IP 鍦板潃',
  `expires_at` datetime NOT NULL COMMENT '杩囨湡鏃堕棿',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `last_active_at` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '鏈€鍚庢椿璺冩椂闂?,
  PRIMARY KEY (`id`),
  UNIQUE KEY `session_token` (`session_token`),
  KEY `idx_session_token` (`session_token`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_expires_at` (`expires_at`),
  CONSTRAINT `login_sessions_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=48 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='鐧诲綍浼氳瘽琛?;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `login_sessions`
--

LOCK TABLES `login_sessions` WRITE;
/*!40000 ALTER TABLE `login_sessions` DISABLE KEYS */;
INSERT INTO `login_sessions` VALUES (1,2,'884fc7887b4b539d697c8d1c9efadb07cd2440955e2f90bc84b766c635707dec','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 11:34:49','2026-04-08 11:34:48','2026-04-08 11:34:48'),(2,2,'a307e82e5d815a9589711d7524e60b3d15c6e67ca3650f41400ed63a81bd71f8','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 11:34:54','2026-04-08 11:34:53','2026-04-08 11:34:53'),(3,2,'b2e2f9f6d8bf82e89dcd9effed00fcbc8f50c53df5d70287d761112be4dcde8f','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 11:35:49','2026-04-08 11:35:48','2026-04-08 11:35:48'),(4,1,'ead5d3fe92980c39f1db3b06babe388bf6bfad518967b26345b6ee01563ce1c9','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 11:39:49','2026-04-08 11:39:48','2026-04-08 11:39:48'),(5,1,'27c9b12b26a8597d5bc26d404513f1d1541393014feb4c5458c64da9c2f7513a','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 18:37:20','2026-04-08 18:37:19','2026-04-08 18:37:19'),(6,1,'5be0258e032f47cbf09cf4bcbe7471eed0fbcf166f6ecbf459eb9d5d631957a1','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 18:45:32','2026-04-08 18:45:31','2026-04-08 18:45:31'),(7,4,'80d118ddba80e6a0c04de1f0a6cefa0c5eb898b62c9759c6e71f528e477ade26','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:24:30','2026-04-08 19:24:29','2026-04-08 19:24:29'),(8,4,'17583ab90e3e059f8df2bc202b9dee45ec2931f46c1c197823cef978fdb41f60','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:30:10','2026-04-08 19:30:10','2026-04-08 19:30:10'),(9,1,'cba619a7bc59fc5916682dc8c7835a72cb692af9b3d9083f4b4d5c40aa8f7139','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:30:38','2026-04-08 19:30:38','2026-04-08 19:30:38'),(10,1,'cca1f7a93a6104a07f0cf5cc3e760ae9b142fd3344464b4c762a55b0e5971d88','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:30:47','2026-04-08 19:30:46','2026-04-08 19:30:46'),(11,1,'f2af87fdb03a0e25cf37e4858711bba7eb1a84ddeb7d5860b2750b4a64c0bcc7','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:30:49','2026-04-08 19:30:48','2026-04-08 19:30:48'),(12,1,'5e04c17f1ed74f1ab1b9c2d89250b96ea4d0f22da4d880a90aac5636ac39d6ed','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:30:52','2026-04-08 19:30:52','2026-04-08 19:30:52'),(13,2,'4829a21c3deee25fdeea6699c376408db39b635e3d463c0b30d947edb022abb0','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:31:12','2026-04-08 19:31:12','2026-04-08 19:31:12'),(14,4,'ec8b840d80cca64c552b6504c9f39a0765714703667e4c9ed5d21b45fc65bd03','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:34:27','2026-04-08 19:34:26','2026-04-08 19:34:26'),(15,4,'7ed5e8609dd4c648f789603748e7fce2613d769b287016129f31a973de05ebc1','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:37:03','2026-04-08 19:37:02','2026-04-08 19:37:02'),(16,4,'5df4f2e8d074d73a81d4dc980fa37576b082435cce601ce58b90d095603710d6','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:37:04','2026-04-08 19:37:04','2026-04-08 19:37:04'),(17,4,'e5eab2b4007cb01167d2af1b1a7925627c59b471a1dc56c0c59f8eef60abde55','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:37:05','2026-04-08 19:37:05','2026-04-08 19:37:05'),(18,4,'89d69c4bb7b754c96fb18c8ff9670f69778d59c03b29e7c8b310821f151836f4','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:37:06','2026-04-08 19:37:05','2026-04-08 19:37:05'),(19,4,'1fd3043d9e4f459a0161c223b7ee7a951d93873fe2829a47274f1d8312785cb1','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:37:06','2026-04-08 19:37:06','2026-04-08 19:37:06'),(20,4,'89487eaf5df3d2cea2ef2984bf8d77239612dd44198a5fe330765972126aedd2','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:37:07','2026-04-08 19:37:06','2026-04-08 19:37:06'),(21,4,'4fc648444a3968870de7a3a8dfc0582054a5a82de702030efc25a46b8befbd99','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:37:08','2026-04-08 19:37:07','2026-04-08 19:37:07'),(22,4,'5de60091983095079f22300013eb0fb6e5bf4b21d0f9b6445d30b8ce50aa4525','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:37:08','2026-04-08 19:37:08','2026-04-08 19:37:08'),(23,4,'44d13512542239ff4fcf1c0fdacddf230bc6ae5e6ae650520ab9d3fef0eb6149','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:37:09','2026-04-08 19:37:09','2026-04-08 19:37:09'),(24,4,'4db2961708dde91fad411025211c9d023edb57d719eb61115647068e474fb29e','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:37:10','2026-04-08 19:37:09','2026-04-08 19:37:09'),(25,4,'789f6caa94be80301231ece87d160439d3e20977df010f68f528c19f22a0f054','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:38:56','2026-04-08 19:38:56','2026-04-08 19:38:56'),(26,4,'071ae9ab790299e2abb4028d21484a6dd7a3ab594c4e4ce133a13c9f41600ad3','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:44:47','2026-04-08 19:44:47','2026-04-08 19:44:47'),(27,4,'72a55f132ecb946b4305a1387558d1e11b44060eeeef5df5f43a7899c39ca9ae','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:44:50','2026-04-08 19:44:49','2026-04-08 19:44:49'),(28,4,'84895134a9d0f61e7af83d3d4b897bf7ab9c8707ef9b4d580c1c950e9309c70d','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:45:17','2026-04-08 19:45:16','2026-04-08 19:45:16'),(29,4,'e1fcfc90de1cbab38cd6f1ffa35c0afe42df393f8dab26b3ec1027fe6934640f','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:47:10','2026-04-08 19:47:09','2026-04-08 19:47:09'),(30,4,'828bd17c44ab41a9d53f5b52034e381ae00c3ae205b6feaf610310aa9278d3e9','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:47:11','2026-04-08 19:47:11','2026-04-08 19:47:11'),(31,4,'61ddb16ffcb9675bdd1ac9a5613e5b6b8e6b4048dcd54279aec89bb460eb44e6','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:47:12','2026-04-08 19:47:12','2026-04-08 19:47:12'),(32,4,'30a6ec8dd397bd04689618f39cadfd0a08990eec5e735e8890cb5ad62288e3a2','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:47:19','2026-04-08 19:47:18','2026-04-08 19:47:18'),(33,4,'a633cfb86a2508b3922631036132f47b28e247750b84d7a278f6ec1d266d725f','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:47:29','2026-04-08 19:47:28','2026-04-08 19:47:28'),(34,4,'9259e155131f4aaaa04fd889daf2c8dc2e55bab65996b23b3fec0dc9e3d6b414','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:47:45','2026-04-08 19:47:45','2026-04-08 19:47:45'),(35,4,'3a3ae92a5ec98aacc51c1cf568b8a1569a255fe49870ab3dd0f82dc721cbc883','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:49:52','2026-04-08 19:49:51','2026-04-08 19:49:51'),(36,4,'c58d6ff9bee762e6a52608a97818079f2975a2a8e906cc858a4bdc8f7de7bc4d','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 19:53:27','2026-04-08 19:53:27','2026-04-08 19:53:27'),(37,4,'68a960dbeb121e79cd8804cfaacad028ddd32f1205d68036f597c5c2f50e1d55','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 20:57:16','2026-04-08 20:57:16','2026-04-08 20:57:16'),(38,1,'7272c35ee783a8c4cf0d95142079e213e8266abba1b6da7ca924bee7dff0689b','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 21:09:24','2026-04-08 21:09:24','2026-04-08 21:09:24'),(39,4,'07a06b5d48761e19409b8f17f533b889c14227b8006bb41839b58822ecaa5695','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 21:26:59','2026-04-08 21:26:58','2026-04-08 21:26:58'),(40,5,'c125de6ff274445a64623c1bdfedc53313a0474b5a746040b32ded19d2bd1b76','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 21:27:28','2026-04-08 21:27:27','2026-04-08 21:27:27'),(41,1,'b6e3f575214502d686dc485e0dca261e50a18b202ecc4bd544124dd23ec3c125','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 21:27:44','2026-04-08 21:27:44','2026-04-08 21:27:44'),(42,1,'fffc313a8b458e9f479de0fa0f9d665dc5d09a0aa0370a51770de7a031993163','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 21:56:25','2026-04-08 21:56:24','2026-04-08 21:56:24'),(43,1,'5248047325baf0bfe9defdddbc38629a0c2ffe4939f0a720409b4d250930cb0b',NULL,NULL,'2026-04-09 21:57:29','2026-04-08 21:57:29','2026-04-08 21:57:29'),(44,5,'14d46183398b8cc59cdbc95f006d0d26fce02d5b4906afa130dfd3fdee18b56a','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 21:57:45','2026-04-08 21:57:44','2026-04-08 21:57:44'),(45,4,'4025f23e4a2a60c081ddbb90e44b0286969755cf5386b7e11102632703a82e3c','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 21:58:09','2026-04-08 21:58:08','2026-04-08 21:58:08'),(46,5,'cc6e9e5a409dd7ce0a30d775188b403cefbe48802d6bbf4b99caea37eeb6f36d','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 22:09:19','2026-04-08 22:09:18','2026-04-08 22:09:18'),(47,1,'c42493a4898d0ec91c041bdd6f46a2711bc7ceed6091f21b46d06fd7466ebc14','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36','::1','2026-04-09 22:10:33','2026-04-08 22:10:33','2026-04-08 22:10:33');
/*!40000 ALTER TABLE `login_sessions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `maintenance_tickets`
--

DROP TABLE IF EXISTS `maintenance_tickets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `maintenance_tickets` (
  `id` int NOT NULL AUTO_INCREMENT,
  `ticket_no` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `booking_id` int DEFAULT NULL COMMENT '茅垄鈥灻D茂录藛氓鈥β趁佲€漛ookings猫隆篓茂录艗莽鈥澛ぢ号矫┾偓鈧λ喡棵烩€溍€斆尖€?,
  `guest_id` int DEFAULT NULL COMMENT '盲陆聫氓庐垄ID茂录藛氓鈥β趁佲€漡uests猫隆篓茂录艗莽鈥澛ぢ号矫ε撀嵜ヅ犅∶ヂ解€櫭ヂ迸久尖€?,
  `room_id` int NOT NULL,
  `fault_type` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'other',
  `fault_description` text COLLATE utf8mb4_unicode_ci,
  `photos` json DEFAULT NULL,
  `priority` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'medium',
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `completed_at` datetime DEFAULT NULL,
  `repair_description` text COLLATE utf8mb4_unicode_ci,
  `repair_cost` decimal(10,2) DEFAULT '0.00',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ticket_no` (`ticket_no`),
  KEY `idx_room_id` (`room_id`),
  KEY `idx_status` (`status`),
  KEY `idx_priority` (`priority`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_booking_id` (`booking_id`),
  KEY `idx_guest_id` (`guest_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `maintenance_tickets`
--

LOCK TABLES `maintenance_tickets` WRITE;
/*!40000 ALTER TABLE `maintenance_tickets` DISABLE KEYS */;
INSERT INTO `maintenance_tickets` VALUES (1,'MT20260407EAB3187F',1,1,1,'electrical','???','[]','high','pending','2026-04-07 00:27:46','2026-04-07 00:27:46',NULL,NULL,0.00);
/*!40000 ALTER TABLE `maintenance_tickets` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `member_coupons`
--

DROP TABLE IF EXISTS `member_coupons`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `member_coupons` (
  `id` int NOT NULL AUTO_INCREMENT,
  `member_id` int NOT NULL,
  `coupon_id` int NOT NULL,
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'unused',
  `used_at` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_member` (`member_id`),
  KEY `idx_coupon` (`coupon_id`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `member_coupons`
--

LOCK TABLES `member_coupons` WRITE;
/*!40000 ALTER TABLE `member_coupons` DISABLE KEYS */;
/*!40000 ALTER TABLE `member_coupons` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `members`
--

DROP TABLE IF EXISTS `members`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `members` (
  `id` int NOT NULL AUTO_INCREMENT,
  `phone` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `id_number` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `member_level` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'standard',
  `points` int NOT NULL DEFAULT '0',
  `balance` decimal(10,2) NOT NULL DEFAULT '0.00',
  `total_spent` decimal(12,2) NOT NULL DEFAULT '0.00',
  `total_stays` int NOT NULL DEFAULT '0',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_phone` (`phone`),
  KEY `idx_member_level` (`member_level`),
  KEY `idx_members_level` (`member_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `members`
--

LOCK TABLES `members` WRITE;
/*!40000 ALTER TABLE `members` DISABLE KEYS */;
/*!40000 ALTER TABLE `members` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `payments`
--

DROP TABLE IF EXISTS `payments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `payments` (
  `id` int NOT NULL AUTO_INCREMENT,
  `payment_no` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `order_type` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'booking',
  `order_id` int NOT NULL,
  `amount` decimal(10,2) NOT NULL DEFAULT '0.00',
  `payment_method` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'wechat',
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `transaction_no` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `paid_at` datetime DEFAULT NULL,
  `description` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_payment_no` (`payment_no`),
  KEY `idx_order` (`order_type`,`order_id`),
  KEY `idx_status` (`status`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_payments_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `payments`
--

LOCK TABLES `payments` WRITE;
/*!40000 ALTER TABLE `payments` DISABLE KEYS */;
/*!40000 ALTER TABLE `payments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reviews`
--

DROP TABLE IF EXISTS `reviews`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reviews` (
  `id` int NOT NULL AUTO_INCREMENT,
  `order_id` int NOT NULL,
  `order_type` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'booking',
  `member_id` int DEFAULT NULL,
  `score` int NOT NULL DEFAULT '5',
  `content` text COLLATE utf8mb4_unicode_ci,
  `photos` json DEFAULT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_order` (`order_id`,`order_type`),
  KEY `idx_member_id` (`member_id`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `reviews`
--

LOCK TABLES `reviews` WRITE;
/*!40000 ALTER TABLE `reviews` DISABLE KEYS */;
/*!40000 ALTER TABLE `reviews` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `roles`
--

DROP TABLE IF EXISTS `roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `roles` (
  `id` int NOT NULL AUTO_INCREMENT,
  `role_name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '瑙掕壊鍚嶇О (admin/staff/user)',
  `role_description` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '瑙掕壊鎻忚堪',
  `permissions` json DEFAULT NULL COMMENT '鏉冮檺鍒楄〃',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `role_name` (`role_name`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='瑙掕壊琛?;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `roles`
--

LOCK TABLES `roles` WRITE;
/*!40000 ALTER TABLE `roles` DISABLE KEYS */;
INSERT INTO `roles` VALUES (1,'admin','绯荤粺绠＄悊鍛橈紝鎷ユ湁鎵€鏈夋潈闄?,'[\"read\", \"write\", \"delete\", \"manage_users\", \"manage_roles\", \"manage_devices\", \"view_reports\", \"system_config\"]','2026-04-08 08:41:33','2026-04-08 08:41:33'),(2,'staff','閰掑簵鍛樺伐锛屾嫢鏈変笟鍔℃搷浣滄潈闄?,'[\"read\", \"write\", \"manage_bookings\", \"manage_rooms\", \"manage_orders\", \"view_reports\", \"manage_guests\"]','2026-04-08 08:41:33','2026-04-08 08:41:33'),(3,'user','鏅€氱敤鎴凤紝鎷ユ湁鍩虹鏉冮檺','[\"read\", \"manage_own_bookings\", \"manage_own_profile\", \"use_services\"]','2026-04-08 08:41:33','2026-04-08 08:41:33');
/*!40000 ALTER TABLE `roles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `room_types`
--

DROP TABLE IF EXISTS `room_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `room_types` (
  `id` int NOT NULL AUTO_INCREMENT,
  `hotel_id` int NOT NULL,
  `name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `code` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `base_price` decimal(10,2) NOT NULL DEFAULT '0.00',
  `area` decimal(6,2) DEFAULT NULL,
  `bed_type` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT 'single',
  `max_guests` int DEFAULT '1',
  `facilities` json DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `images` json DEFAULT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`),
  UNIQUE KEY `code` (`code`),
  KEY `idx_room_types_hotel_id` (`hotel_id`),
  CONSTRAINT `fk_room_types_hotel` FOREIGN KEY (`hotel_id`) REFERENCES `hotels` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `room_types`
--

LOCK TABLES `room_types` WRITE;
/*!40000 ALTER TABLE `room_types` DISABLE KEYS */;
INSERT INTO `room_types` VALUES (1,1,'standard','standard',299.00,25.00,'single',1,NULL,NULL,NULL,'2026-04-08 18:47:16','2026-04-08 19:00:18'),(2,1,'deluxe','deluxe',499.00,35.00,'king',2,NULL,NULL,NULL,'2026-04-08 18:47:16','2026-04-08 19:00:18'),(3,1,'suite','suite',899.00,55.00,'king',3,NULL,NULL,NULL,'2026-04-08 18:47:16','2026-04-08 19:00:18'),(4,1,'presidential','presidential',2999.00,120.00,'king',4,NULL,NULL,NULL,'2026-04-08 18:47:16','2026-04-08 19:00:18');
/*!40000 ALTER TABLE `room_types` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `rooms`
--

DROP TABLE IF EXISTS `rooms`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `rooms` (
  `id` int NOT NULL AUTO_INCREMENT,
  `hotel_id` int NOT NULL,
  `room_number` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `room_type` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'standard',
  `room_type_id` int DEFAULT NULL,
  `room_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `room_price` decimal(10,2) NOT NULL DEFAULT '0.00',
  `room_status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'available',
  `floor` int DEFAULT '1',
  `area` decimal(6,2) DEFAULT NULL,
  `bed_type` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT 'single',
  `max_guests` int DEFAULT '1',
  `description` text COLLATE utf8mb4_unicode_ci,
  `facilities` json DEFAULT NULL,
  `images` json DEFAULT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_room_number` (`room_number`),
  KEY `idx_room_status` (`room_status`),
  KEY `idx_room_type` (`room_type`),
  KEY `idx_rooms_status` (`room_status`),
  KEY `idx_rooms_type` (`room_type`),
  KEY `fk_room_type` (`room_type_id`),
  KEY `idx_room_floor` (`floor`),
  KEY `idx_rooms_hotel_id` (`hotel_id`),
  CONSTRAINT `fk_room_type` FOREIGN KEY (`room_type_id`) REFERENCES `room_types` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_rooms_hotel` FOREIGN KEY (`hotel_id`) REFERENCES `hotels` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `rooms`
--

LOCK TABLES `rooms` WRITE;
/*!40000 ALTER TABLE `rooms` DISABLE KEYS */;
INSERT INTO `rooms` VALUES (1,1,'101','standard',1,'忙聽鈥∶モ€♀€犆ヂ嶁€⒚ぢ郝好λ喡緼',299.00,'available',1,25.00,'single',1,NULL,NULL,NULL,'2026-04-05 00:26:17','2026-04-08 19:00:18'),(2,1,'102','standard',1,'忙聽鈥∶モ€♀€犆ヂ嶁€⒚ぢ郝好λ喡緽',299.00,'occupied',1,25.00,'single',1,NULL,NULL,NULL,'2026-04-05 00:26:17','2026-04-08 19:00:18'),(3,1,'103','deluxe',2,'猫卤陋氓聧沤氓陇搂氓潞艩忙藛驴A',499.00,'available',1,35.00,'king',2,NULL,NULL,NULL,'2026-04-05 00:26:17','2026-04-08 19:00:18'),(4,1,'201','deluxe',2,'猫卤陋氓聧沤氓陇搂氓潞艩忙藛驴B',499.00,'available',2,38.00,'king',2,NULL,NULL,NULL,'2026-04-05 00:26:17','2026-04-08 19:00:18'),(5,1,'202','suite',3,'猫隆艗忙鈥澛棵ヂモ€斆λ喡緼',899.00,'cleaning',2,55.00,'king',3,NULL,NULL,NULL,'2026-04-05 00:26:17','2026-04-08 19:00:18'),(6,1,'203','suite',3,'猫隆艗忙鈥澛棵ヂモ€斆λ喡緽',999.00,'available',2,60.00,'twin',3,NULL,NULL,NULL,'2026-04-05 00:26:17','2026-04-08 19:00:18'),(7,1,'301','presidential',4,'忙鈧幻慌该ヂモ€斆λ喡?,2999.00,'reserved',3,120.00,'king',4,NULL,NULL,NULL,'2026-04-05 00:26:17','2026-04-08 19:00:18'),(8,1,'302','standard',1,'忙聽鈥∶モ€♀€犆ヂ徟捗ぢ郝好λ喡緼',399.00,'available',3,28.00,'double',2,NULL,NULL,NULL,'2026-04-05 00:26:17','2026-04-08 19:00:18'),(9,1,'303','standard',1,'忙聽鈥∶モ€♀€犆ヂ徟捗ぢ郝好λ喡緽',399.00,'maintenance',3,28.00,'double',2,NULL,NULL,NULL,'2026-04-05 00:26:17','2026-04-08 19:00:18');
/*!40000 ALTER TABLE `rooms` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `security_events`
--

DROP TABLE IF EXISTS `security_events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `security_events` (
  `id` int NOT NULL AUTO_INCREMENT,
  `device_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `event_type` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `event_data` text COLLATE utf8mb4_unicode_ci,
  `event_level` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'info',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_device_id` (`device_id`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_event_type` (`event_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `security_events`
--

LOCK TABLES `security_events` WRITE;
/*!40000 ALTER TABLE `security_events` DISABLE KEYS */;
/*!40000 ALTER TABLE `security_events` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `sensor_data`
--

DROP TABLE IF EXISTS `sensor_data`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sensor_data` (
  `id` int NOT NULL AUTO_INCREMENT,
  `device_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `sensor_type` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `sensor_value` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_device_id` (`device_id`),
  KEY `idx_sensor_type` (`sensor_type`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_device_sensor` (`device_id`,`sensor_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `sensor_data`
--

LOCK TABLES `sensor_data` WRITE;
/*!40000 ALTER TABLE `sensor_data` DISABLE KEYS */;
/*!40000 ALTER TABLE `sensor_data` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_roles`
--

DROP TABLE IF EXISTS `user_roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_roles` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL COMMENT '鐢ㄦ埛 ID',
  `role_id` int NOT NULL COMMENT '瑙掕壊 ID',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_role` (`user_id`,`role_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_role_id` (`role_id`),
  CONSTRAINT `user_roles_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `user_roles_ibfk_2` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='鐢ㄦ埛瑙掕壊鍏宠仈琛?;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_roles`
--

LOCK TABLES `user_roles` WRITE;
/*!40000 ALTER TABLE `user_roles` DISABLE KEYS */;
INSERT INTO `user_roles` VALUES (1,1,1,'2026-04-08 11:18:13'),(2,2,3,'2026-04-08 11:18:13');
/*!40000 ALTER TABLE `user_roles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `hotel_id` int NOT NULL,
  `username` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `role` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'user',
  `permissions` json DEFAULT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_username` (`username`),
  KEY `idx_username` (`username`),
  KEY `idx_users_hotel_id` (`hotel_id`),
  CONSTRAINT `fk_users_hotel` FOREIGN KEY (`hotel_id`) REFERENCES `hotels` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,1,'admin','$2a$10$BL5b4ZpzEepxkPGNAlzSheBPkNelEhI7H0JRrjDlC9KJIHU8bNliG','admin@example.com','admin',NULL,'2026-04-08 11:18:13','2026-04-08 19:00:17'),(2,1,'user','$2a$10$/vhxRGZaWp3H/rGSNmAWzOUOeypzRTMV7rTTmVrf2iP8Q4zOI33O.','user@example.com','user',NULL,'2026-04-08 11:18:13','2026-04-08 19:00:17'),(4,1,'system_admin','$2a$10$FsanJ7q7jXnpeYdbtp2mNupLXqW0COInNGbqvRtE/5Ju0UP0mS8Na','system@iot-hotel.com','system',NULL,'2026-04-08 19:14:07','2026-04-08 21:27:05'),(5,1,'employee','$2a$10$F6fs6/8.dVBGVpjNdoynte3k8M489PLo6AAOI.SH6QUdrkJWXjQKq',NULL,'staff',NULL,'2026-04-08 21:27:20','2026-04-08 21:27:20');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-04-08 23:12:34
