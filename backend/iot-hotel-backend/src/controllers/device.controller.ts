import { Request, Response } from 'express';
import deviceService from '../services/device.service';
import logger from '../utils/logger';

class DeviceController {
  /**
   * 硬件上报注册 (需包含 hotel_id)
   */
  async register(req: Request, res: Response) {
    try {
      const data = req.body;
      if (!data.hotel_id) {
        return res.status(400).json({ success: false, message: 'Hotel ID is required for registration' });
      }
      const result = await deviceService.registerDevice(data);
      res.json({
        success: true,
        message: 'Device registration info received',
        data: result
      });
    } catch (error) {
      logger.error('Register device error:', error);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 管理员审核设备 (需管理员权限)
   */
  async audit(req: Request, res: Response) {
    try {
      const hotelId = (req as any).user?.hotel_id;
      if (!hotelId) return res.status(401).json({ success: false, message: 'Unauthorized' });

      const id = parseInt(req.params.id);
      const { status, room_id, area } = req.body;

      if (!id || !['approved', 'rejected'].includes(status)) {
        return res.status(400).json({ success: false, message: 'Invalid parameters' });
      }

      // 验证设备是否属于该酒店
      const device = await deviceService.getDeviceById(id, hotelId);
      if (!device) {
        return res.status(404).json({ success: false, message: 'Device not found' });
      }

      const result = await deviceService.auditDevice(id, status, { room_id, area });
      res.json({
        success: true,
        message: `Device ${status} successfully`,
        data: result
      });
    } catch (error) {
      logger.error('Audit device error:', error);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 获取所有设备 (管理端显示)
   */
  async getAll(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      const { status, audit_status, room_id, hotel_id } = req.query;
      
      let targetHotelId: number | undefined;
      
      if (user?.role === 'system') {
        // 系统角色可以查看所有或指定酒店
        targetHotelId = hotel_id ? parseInt(hotel_id as string) : undefined;
      } else {
        // 普通管理员只能查看自己酒店
        targetHotelId = user?.hotel_id;
      }

      const filters = {
        status: status as string,
        audit_status: audit_status as string,
        room_id: room_id ? parseInt(room_id as string) : undefined
      };
      
      const result = await deviceService.getAllDevices(targetHotelId, filters);
      res.json({
        success: true,
        data: result
      });
    } catch (error) {
      logger.error('Get all devices error:', error);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 获取单个设备详情
   */
  async getById(req: Request, res: Response) {
    try {
      const hotelId = (req as any).user?.hotel_id;
      if (!hotelId) return res.status(401).json({ success: false, message: 'Unauthorized' });

      const id = parseInt(req.params.id);
      const result = await deviceService.getDeviceById(id, hotelId);
      if (!result) {
        return res.status(404).json({ success: false, message: 'Device not found' });
      }
      res.json({
        success: true,
        data: result
      });
    } catch (error) {
      logger.error('Get device by id error:', error);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 删除设备
   */
  async delete(req: Request, res: Response) {
    try {
      const hotelId = (req as any).user?.hotel_id;
      if (!hotelId) return res.status(401).json({ success: false, message: 'Unauthorized' });

      const id = parseInt(req.params.id);
      await deviceService.deleteDevice(id, hotelId);
      res.json({
        success: true,
        message: 'Device deleted successfully'
      });
    } catch (error) {
      logger.error('Delete device error:', error);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 向设备发送指令 (需管理员/员工权限)
   */
  async sendCommand(req: Request, res: Response) {
    try {
      const hotelId = (req as any).user?.hotel_id;
      if (!hotelId) return res.status(401).json({ success: false, message: 'Unauthorized' });

      const id = parseInt(req.params.id);
      const { command_type, command_value } = req.body;
      const user = (req as any).user;

      if (!id || !command_type) {
        return res.status(400).json({ success: false, message: 'Invalid parameters' });
      }

      // 1. 获取设备详情以确认其 device_id 并校验所属酒店
      const device = await deviceService.getDeviceById(id, hotelId);
      if (!device) {
        return res.status(404).json({ success: false, message: 'Device not found' });
      }

      if (device.audit_status !== 'approved') {
        return res.status(403).json({ success: false, message: 'Device is not approved' });
      }

      // 2. 调用 MQTT 服务下发指令
      const mqttService = require('../services/mqtt.service').default;
      const commandId = await mqttService.sendDeviceCommand(
        device.device_id,
        command_type,
        command_value,
        user?.username || 'admin'
      );

      if (commandId) {
        res.json({
          success: true,
          message: 'Command sent successfully',
          data: { command_id: commandId }
        });
      } else {
        res.status(500).json({ success: false, message: 'Failed to send command via MQTT' });
      }
    } catch (error) {
      logger.error('Send command error:', error);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }
}

export default new DeviceController();
