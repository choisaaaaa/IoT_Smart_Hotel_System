import { Request, Response } from 'express';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { isSystemAdmin } from '../utils/role';

class DeviceGroupController {
  /**
   * 获取设备分组列表
   */
  async getAll(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id ? parseInt(req.query.hotel_id as string) : hotelId;
      }
      if (!hotelId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const { group_type } = req.query;

      let sql = 'SELECT * FROM device_groups WHERE hotel_id = ?';
      const params: any[] = [hotelId];

      if (group_type) {
        sql += ' AND group_type = ?';
        params.push(group_type);
      }

      sql += ' ORDER BY created_at DESC';

      const [rows] = await pool.query<RowDataPacket[]>(sql, params);

      // 获取每个分组的设备数量
      for (const group of rows) {
        const [countResult] = await pool.query<RowDataPacket[]>(
          'SELECT COUNT(*) as count FROM device_group_members WHERE group_id = ?',
          [group.id]
        );
        group.device_count = countResult[0]?.count || 0;
      }

      res.json({
        success: true,
        data: rows
      });
    } catch (error) {
      logger.error('Get device groups error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 创建设备分组
   */
  async create(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.body.hotel_id || hotelId;
      }
      if (!hotelId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const { group_name, group_type, description, device_ids } = req.body;

      if (!group_name || !group_type) {
        return res.status(400).json({ success: false, message: 'Group name and type are required' });
      }

      // 创建分组
      const [result] = await pool.query<ResultSetHeader>(
        'INSERT INTO device_groups (hotel_id, group_name, group_type, description, created_by) VALUES (?, ?, ?, ?, ?)',
        [hotelId, group_name, group_type, description || null, user?.id]
      );

      const groupId = result.insertId;

      // 添加设备到分组
      if (device_ids && Array.isArray(device_ids) && device_ids.length > 0) {
        const values = device_ids.map((deviceId: string) => [groupId, deviceId]);
        await pool.query(
          'INSERT INTO device_group_members (group_id, device_id) VALUES ?',
          [values]
        );
      }

      res.json({
        success: true,
        message: 'Device group created successfully',
        data: { id: groupId }
      });
    } catch (error) {
      logger.error('Create device group error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 更新分组信息
   */
  async update(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.body.hotel_id || hotelId;
      }
      if (!hotelId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const groupId = parseInt(req.params.id);
      const { group_name, description } = req.body;

      // 验证分组是否属于该酒店
      const [groups] = await pool.query<RowDataPacket[]>(
        'SELECT id FROM device_groups WHERE id = ? AND hotel_id = ?',
        [groupId, hotelId]
      );

      if (groups.length === 0) {
        return res.status(404).json({ success: false, message: 'Group not found' });
      }

      await pool.query(
        'UPDATE device_groups SET group_name = ?, description = ? WHERE id = ?',
        [group_name, description || null, groupId]
      );

      res.json({
        success: true,
        message: 'Device group updated successfully'
      });
    } catch (error) {
      logger.error('Update device group error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 删除分组
   */
  async delete(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id || hotelId;
      }
      if (!hotelId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const groupId = parseInt(req.params.id);

      // 验证分组是否属于该酒店
      const [groups] = await pool.query<RowDataPacket[]>(
        'SELECT id FROM device_groups WHERE id = ? AND hotel_id = ?',
        [groupId, hotelId]
      );

      if (groups.length === 0) {
        return res.status(404).json({ success: false, message: 'Group not found' });
      }

      // 删除分组关联的设备
      await pool.query('DELETE FROM device_group_members WHERE group_id = ?', [groupId]);

      // 删除分组
      await pool.query('DELETE FROM device_groups WHERE id = ?', [groupId]);

      res.json({
        success: true,
        message: 'Device group deleted successfully'
      });
    } catch (error) {
      logger.error('Delete device group error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 添加设备到分组
   */
  async addDevices(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.body.hotel_id || hotelId;
      }
      if (!hotelId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const groupId = parseInt(req.params.id);
      const { device_ids } = req.body;

      if (!device_ids || !Array.isArray(device_ids) || device_ids.length === 0) {
        return res.status(400).json({ success: false, message: 'Device IDs are required' });
      }

      // 验证分组是否属于该酒店
      const [groups] = await pool.query<RowDataPacket[]>(
        'SELECT id FROM device_groups WHERE id = ? AND hotel_id = ?',
        [groupId, hotelId]
      );

      if (groups.length === 0) {
        return res.status(404).json({ success: false, message: 'Group not found' });
      }

      // 插入设备关联
      const values = device_ids.map((deviceId: string) => [groupId, deviceId]);
      await pool.query(
        'INSERT IGNORE INTO device_group_members (group_id, device_id) VALUES ?',
        [values]
      );

      res.json({
        success: true,
        message: 'Devices added to group successfully'
      });
    } catch (error) {
      logger.error('Add devices to group error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 从分组移除设备
   */
  async removeDevice(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id || hotelId;
      }
      if (!hotelId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const groupId = parseInt(req.params.id);
      const deviceId = req.params.device_id;

      // 验证分组是否属于该酒店
      const [groups] = await pool.query<RowDataPacket[]>(
        'SELECT id FROM device_groups WHERE id = ? AND hotel_id = ?',
        [groupId, hotelId]
      );

      if (groups.length === 0) {
        return res.status(404).json({ success: false, message: 'Group not found' });
      }

      await pool.query(
        'DELETE FROM device_group_members WHERE group_id = ? AND device_id = ?',
        [groupId, deviceId]
      );

      res.json({
        success: true,
        message: 'Device removed from group successfully'
      });
    } catch (error) {
      logger.error('Remove device from group error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 批量控制分组内设备
   */
  async sendCommand(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.body.hotel_id || hotelId;
      }
      if (!hotelId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const groupId = parseInt(req.params.id);
      const { command_type, command_value } = req.body;

      if (!command_type) {
        return res.status(400).json({ success: false, message: 'Command type is required' });
      }

      // 验证分组是否属于该酒店
      const [groups] = await pool.query<RowDataPacket[]>(
        'SELECT id FROM device_groups WHERE id = ? AND hotel_id = ?',
        [groupId, hotelId]
      );

      if (groups.length === 0) {
        return res.status(404).json({ success: false, message: 'Group not found' });
      }

      // 获取分组内所有设备
      const [devices] = await pool.query<RowDataPacket[]>(       `SELECT d.device_id FROM devices d
         JOIN device_group_members dgm ON d.device_id = dgm.device_id
         WHERE dgm.group_id = ? AND d.hotel_id = ? AND d.audit_status = 'approved'`,
        [groupId, hotelId]
      );

      if (devices.length === 0) {
        return res.status(404).json({ success: false, message: 'No devices found in group' });
      }

      // 发送指令到所有设备
      const mqttService = require('../services/mqtt.service').default;
      const commandIds = [];

      for (const device of devices) {
        const commandId = await mqttService.sendDeviceCommand(
          device.device_id,
          command_type,
          command_value,
          user?.username || 'admin'
        );
        if (commandId) {
          commandIds.push({ device_id: device.device_id, command_id: commandId });
        }
      }

      res.json({
        success: true,
        message: `Command sent to ${commandIds.length} devices`,
        data: { command_ids: commandIds }
      });
    } catch (error) {
      logger.error('Send command to group error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }
}

export default new DeviceGroupController();
