import app from './app';
import config from './config';
import logger from './utils/logger';
import mqttService from './services/mqtt.service';
import websocketService from './services/websocket.service';
import { orderTimeoutService } from './services/order-timeout.service';
import { autoCheckoutService } from './services/auto-checkout.service';
import pool from './config/database';

const PORT = config.app.port;
const HOST = config.app.host;

async function startServer() {
  try {
    // 清理进行中的通话记录（上次异常退出时遗留的）
    try {
      await pool.query(
        `UPDATE calls SET status = 'ended', ended_at = NOW() WHERE status IN ('calling', 'outgoing', 'ringing', 'connected')`
      );
      logger.info('已清理进行中的通话记录');

      // 自动修复 bookings 表 schema
      try {
        await pool.query('ALTER TABLE bookings ADD COLUMN used_points INT DEFAULT 0 AFTER coupon_id');
        await pool.query('ALTER TABLE bookings ADD COLUMN points_discount DECIMAL(10,2) DEFAULT 0.00 AFTER used_points');
        logger.info('数据库表 bookings 基础修复成功');
      } catch (schemaError: any) {
        if (schemaError.code !== 'ER_DUP_COLUMN_NAME' && schemaError.errno !== 1060) {
          logger.warn('修复数据库 bookings 基础 schema 失败:', schemaError.code, schemaError.message);
        }
      }

      // 子房价系统修复 (rate_plans)
      try {
        await pool.query(`
          CREATE TABLE IF NOT EXISTS rate_plans (
            id INT AUTO_INCREMENT PRIMARY KEY,
            hotel_id INT NOT NULL,
            room_type_id INT NOT NULL,
            plan_name VARCHAR(100) NOT NULL,
            base_price DECIMAL(10,2) DEFAULT 0.00,
            meal_plan ENUM('none', 'breakfast', 'half_board', 'full_board') DEFAULT 'none',
            breakfast_count INT DEFAULT 0,
            cancellation_policy ENUM('free', 'no_cancel', 'restricted') DEFAULT 'free',
            cancel_time_limit INT DEFAULT 0,
            payment_type ENUM('all', 'online_only', 'front_desk_only') DEFAULT 'all',
            is_guaranteed TINYINT(1) DEFAULT 0,
            prepayment_ratio DECIMAL(5,2) DEFAULT 0.00,
            is_active TINYINT(1) DEFAULT 1,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_hotel_room (hotel_id, room_type_id)
          )
        `);
        
        // 扩展字段
        const addColumns = [
          'ALTER TABLE rate_plans ADD COLUMN breakfast_count INT DEFAULT 0 AFTER meal_plan',
          'ALTER TABLE rate_plans ADD COLUMN cancel_time_limit INT DEFAULT 0 AFTER cancellation_policy',
          'ALTER TABLE rate_plans ADD COLUMN is_guaranteed TINYINT(1) DEFAULT 0 AFTER payment_type',
          'ALTER TABLE rate_plans ADD COLUMN prepayment_ratio DECIMAL(5,2) DEFAULT 0.00 AFTER is_guaranteed',
          'ALTER TABLE rate_plans ADD COLUMN base_price DECIMAL(10,2) DEFAULT 0.00 AFTER plan_name'
        ];

        for (const sql of addColumns) {
          try {
            await pool.query(sql);
            logger.info(`数据库列添加成功: ${sql.split(' ').slice(-1)[0]}`);
          } catch (e: any) { 
            // 同时检查 code 和 errno (1060 为 Duplicate column name)
            if (e.code !== 'ER_DUP_COLUMN_NAME' && e.errno !== 1060) {
              logger.warn(`列扩展失败 (${sql}):`, e.code, e.message);
            }
          }
        }

        // 为 room_prices 增加 rate_plan_id
        try {
          await pool.query('ALTER TABLE room_prices ADD COLUMN rate_plan_id INT DEFAULT NULL AFTER room_type_id');
        } catch (e: any) { if (e.code !== 'ER_DUP_COLUMN_NAME' && e.errno !== 1060) throw e; }

        // 为 bookings 增加 rate_plan_id
        try {
          await pool.query('ALTER TABLE bookings ADD COLUMN rate_plan_id INT DEFAULT NULL AFTER room_id');
        } catch (e: any) { if (e.code !== 'ER_DUP_COLUMN_NAME' && e.errno !== 1060) throw e; }

        // 为 bookings 增加 id_type
        try {
          await pool.query('ALTER TABLE bookings ADD COLUMN id_type VARCHAR(20) DEFAULT "idcard" AFTER guest_phone');
          logger.info('数据库列 bookings.id_type 添加成功');
        } catch (e: any) { if (e.code !== 'ER_DUP_COLUMN_NAME' && e.errno !== 1060) throw e; }

        // 为 guests 增加 id_type
        try {
          await pool.query('ALTER TABLE guests ADD COLUMN id_type VARCHAR(20) DEFAULT "idcard" AFTER guest_phone');
          logger.info('数据库列 guests.id_type 添加成功');
        } catch (e: any) { if (e.code !== 'ER_DUP_COLUMN_NAME' && e.errno !== 1060) throw e; }

        // 为 calls 增加 hotel_id
        try {
          await pool.query('ALTER TABLE calls ADD COLUMN hotel_id INT DEFAULT NULL AFTER callee_id');
          logger.info('数据库列 calls.hotel_id 添加成功');
        } catch (e: any) { if (e.code !== 'ER_DUP_COLUMN_NAME' && e.errno !== 1060) throw e; }

        // 修改 frequent_guests 的 id_type 枚举
        try {
          await pool.query('ALTER TABLE frequent_guests MODIFY COLUMN id_type VARCHAR(50) DEFAULT "idcard"');
          logger.info('数据库列 frequent_guests.id_type 类型修改成功');
        } catch (e: any) { throw e; }

        logger.info('子房价系统及证件类型数据库修复/升级成功');
      } catch (schemaError: any) {
        logger.error('子房价系统数据库修复失败:', schemaError.code, schemaError.message);
      }
    } catch (cleanupError) {
      logger.warn('清理通话记录失败:', cleanupError);
    }

    const server = app.listen(PORT, '0.0.0.0', async () => {
      logger.info(`服务器启动成功: http://0.0.0.0:${PORT}`);
      logger.info(`API前缀: ${config.app.apiPrefix}`);
      logger.info(`环境: ${config.app.env}`);

      try {
        websocketService.init(server);
        orderTimeoutService.start();
        autoCheckoutService.start();
      } catch (serviceError) {
        logger.warn(`服务初始化警告: ${(serviceError as Error).message}`);
      }

      try {
        await mqttService.connect();
        // subscribeAllTopics 已在 connect 中自动调用，无需在此处冗余订阅 #
      } catch (mqttError) {
        logger.warn(`MQTT连接警告: ${(mqttError as Error).message}`);
      }
    });

    server.on('error', (error: NodeJS.ErrnoException) => {
      if (error.code === 'EACCES') {
        logger.error(`端口 ${PORT} 权限不足，请尝试使用其他端口或以管理员身份运行`);
      } else if (error.code === 'EADDRINUSE') {
        logger.error(`端口 ${PORT} 已被占用，请检查是否有其他进程在使用该端口`);
      } else {
        logger.error(`服务器启动失败: ${error.message}`);
      }
      process.exit(1);
    });

    server.on('close', async () => {
      logger.info('服务器已关闭');
      orderTimeoutService.stop();
      autoCheckoutService.stop();
      await mqttService.disconnect();
      websocketService.close();
    });

    process.on('SIGINT', async () => {
      logger.info('收到SIGINT信号，正在关闭服务器...');
      await mqttService.disconnect();
      websocketService.close();
      server.close(() => {
        logger.info('服务器已关闭');
        process.exit(0);
      });
    });

    process.on('SIGTERM', async () => {
      logger.info('收到SIGTERM信号，正在关闭服务器...');
      await mqttService.disconnect();
      websocketService.close();
      server.close(() => {
        logger.info('服务器已关闭');
        process.exit(0);
      });
    });
  } catch (error) {
    logger.error(`服务器启动异常: ${error}`);
    process.exit(1);
  }
}

startServer();