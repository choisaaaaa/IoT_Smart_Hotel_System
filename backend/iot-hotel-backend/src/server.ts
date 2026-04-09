import app from './app';
import config from './config';
import logger from './utils/logger';
import mqttService from './services/mqtt.service';
import websocketService from './services/websocket.service';
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
    } catch (cleanupError) {
      logger.warn('清理通话记录失败:', cleanupError);
    }

    const server = app.listen(PORT, async () => {
      logger.info(`服务器启动成功: http://127.0.0.1:${PORT}`);
      logger.info(`API前缀: ${config.app.apiPrefix}`);
      logger.info(`环境: ${config.app.env}`);

      try {
        websocketService.init(server);
        await mqttService.connect();
        await mqttService.subscribe('hotel/device/#');
      } catch (serviceError) {
        logger.warn(`服务初始化警告: ${(serviceError as Error).message}`);
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