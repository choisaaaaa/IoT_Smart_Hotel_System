import { Response } from 'express';
import { AuthRequest, sendSuccess, sendError, serverError, badRequest } from '../types';
import mqttService from '../services/mqtt.service';
import logger from '../utils/logger';

export class MQTTController {
  /**
   * 获取MQTT通信日志
   */
  static async getLogs(req: AuthRequest, res: Response) {
    try {
      const hotelId = req.user?.hotel_id || 0;
      const deviceId = req.query.device_id as string;
      const limit = parseInt(req.query.limit as string) || 50;
      const offset = parseInt(req.query.offset as string) || 0;

      const logs = await mqttService.getCommunicationLogs(hotelId, deviceId, limit, offset);
      return sendSuccess(res, logs);
    } catch (error: any) {
      logger.error('获取MQTT日志失败:', error.message);
      return sendError(res, serverError('获取日志失败'));
    }
  }

  /**
   * 手动发送MQTT消息
   */
  static async sendMessage(req: AuthRequest, res: Response) {
    try {
      const { topic, payload, qos, retain } = req.body;

      if (!topic || !payload) {
        return sendError(res, badRequest('主题和内容不能为空'));
      }

      const success = await mqttService.publish(topic, payload, qos || 0, retain || false);

      if (success) {
        return sendSuccess(res, null, '消息已发送');
      } else {
        return sendError(res, serverError('发送失败，MQTT可能未连接'));
      }
    } catch (error: any) {
      logger.error('手动发送MQTT消息失败:', error.message);
      return sendError(res, serverError('发送失败'));
    }
  }

  /**
   * 获取MQTT服务状态
   */
  static async getStatus(req: AuthRequest, res: Response) {
    return sendSuccess(res, {
      connected: mqttService.isConnected(),
      broker: process.env.MQTT_HOST || 'localhost'
    });
  }
}
