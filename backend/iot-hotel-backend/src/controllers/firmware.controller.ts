import { Request, Response } from 'express';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { isSystemAdmin } from '../utils/role';

class FirmwareController {
  /**
   * 获取固件升级记录
   */
  async getAll(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id ? parseInt(req.query.hotel_id as string) : undefined;
      }

      const { device_id, update_status, page = 1, pageSize = 20 } = req.query;

      let sql = 'SELECT * FROM firmware_updates WHERE 1=1';
      const params: any[] = [];

      if (hotelId) {
        sql += ' AND hotel_id = ?';
        params.push(hotelId);
      }

      if (device_id) {
        sql += ' AND device_id = ?';
        params.push(device_id);
      }

      if (update_status) {
        sql += ' AND update_status = ?';
        params.push(update_status);
      }

      // 获取总数
      const [countResult] = await pool.query<RowDataPacket[]>(
        sql.replace('SELECT *', 'SELECT COUNT(*) as total'),
        params
      );
      const total = countResult[0]?.total || 0;

      // 分页查询
      sql += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
      params.push(parseInt(pageSize as string), (parseInt(page as string) - 1) * parseInt(pageSize as string));

      const [rows] = await pool.query<RowDataPacket[]>(sql, params);

      res.json({
        success: true,
        data: {
          list: rows,
          pagination: {
            page: parseInt(page as string),
            pageSize: parseInt(pageSize as string),
            total
          }
        }
      });
    } catch (error) {
      logger.error('Get firmware updates error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 获取升级任务详情
   */
  async getById(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id || hotelId;
      }

      const updateId = parseInt(req.params.id);

      let sql = 'SELECT * FROM firmware_updates WHERE id = ?';
      const params: any[] = [updateId];

      if (hotelId) {
        sql += ' AND hotel_id = ?';
        params.push(hotelId);
      }

      const [rows] = await pool.query<RowDataPacket[]>(sql, params);

      if (rows.length === 0) {
        return res.status(404).json({ success: false, message: 'Firmware update not found' });
      }

      res.json({
        success: true,
        data: rows[0]
      });
    } catch (error) {
      logger.error('Get firmware update by id error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 发起固件升级
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

      const { device_ids, firmware_version, firmware_url, schedule_time } = req.body;

      if (!device_ids || !Array.isArray(device_ids) || device_ids.length === 0 || !firmware_version) {
        return res.status(400).json({ success: false, message: 'Device IDs and firmware version are required' });
      }

      const createdUpdates = [];

      for (const deviceId of device_ids) {
        // 验证设备是否属于该酒店
        const [devices] = await pool.query<RowDataPacket[]>(
          'SELECT device_id, firmware_version as current_version FROM devices WHERE device_id = ? AND hotel_id = ?',
          [deviceId, hotelId]
        );

        if (devices.length === 0) {
          continue;
        }

        const device = devices[0];

        // 创建升级记录
        const [result] = await pool.query<ResultSetHeader>(
          'INSERT INTO firmware_updates (device_id, hotel_id, old_version, new_version, firmware_url, update_status) VALUES (?, ?, ?, ?, ?, ?)',
          [deviceId, hotelId, device.current_version, firmware_version, firmware_url || null, 'pending']
        );

        createdUpdates.push({
          id: result.insertId,
          device_id: deviceId,
          old_version: device.current_version,
          new_version: firmware_version
        });

        // 如果设置了定时时间，这里可以加入定时任务队列
        if (!schedule_time) {
          // 立即发送升级指令
          const mqttService = require('../services/mqtt.service').default;
          await mqttService.sendDeviceCommand(
            deviceId,
            'firmware_update',
            JSON.stringify({
              firmware_url,
              version: firmware_version,
              update_id: result.insertId
            }),
            user?.username || 'admin'
          );

          // 更新状态为下载中
          await pool.query(
            'UPDATE firmware_updates SET update_status = ?, started_at = NOW() WHERE id = ?',
            ['downloading', result.insertId]
          );
        }
      }

      res.json({
        success: true,
        message: `Created ${createdUpdates.length} firmware update tasks`,
        data: { updates: createdUpdates }
      });
    } catch (error) {
      logger.error('Create firmware update error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 取消升级任务
   */
  async cancel(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.body.hotel_id || hotelId;
      }
      if (!hotelId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const updateId = parseInt(req.params.id);

      // 验证升级任务是否属于该酒店
      const [updates] = await pool.query<RowDataPacket[]>(
        'SELECT id, update_status FROM firmware_updates WHERE id = ? AND hotel_id = ?',
        [updateId, hotelId]
      );

      if (updates.length === 0) {
        return res.status(404).json({ success: false, message: 'Firmware update not found' });
      }

      const update = updates[0];

      // 只能取消待升级或下载中的任务
      if (!['pending', 'downloading'].includes(update.update_status)) {
        return res.status(400).json({ success: false, message: 'Cannot cancel update in current status' });
      }

      await pool.query(
        'UPDATE firmware_updates SET update_status = ? WHERE id = ?',
        ['cancelled', updateId]
      );

      res.json({
        success: true,
        message: 'Firmware update cancelled successfully'
      });
    } catch (error) {
      logger.error('Cancel firmware update error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 上报升级进度（设备端调用）
   */
  async reportProgress(req: Request, res: Response) {
    try {
      const { device_id, update_id, progress, status, error_message } = req.body;

      if (!device_id || !update_id || !status) {
        return res.status(400).json({ success: false, message: 'Missing required parameters' });
      }

      // 验证升级记录
      const [updates] = await pool.query<RowDataPacket[]>(
        'SELECT * FROM firmware_updates WHERE id = ? AND device_id = ?',
        [update_id, device_id]
      );

      if (updates.length === 0) {
        return res.status(404).json({ success: false, message: 'Firmware update not found' });
      }

      const update = updates[0];

      // 更新状态
      let updateSql = 'UPDATE firmware_updates SET update_status = ?';
      const params: any[] = [status];

      if (progress !== undefined) {
        // 可以添加进度字段，如果需要的话
      }

      if (error_message) {
        updateSql += ', error_message = ?';
        params.push(error_message);
      }

      if (status === 'success') {
        updateSql += ', completed_at = NOW()';
        // 更新设备固件版本
        await pool.query(
          'UPDATE devices SET firmware_version = ? WHERE device_id = ?',
          [update.new_version, device_id]
        );
      } else if (status === 'failed') {
        updateSql += ', completed_at = NOW()';
      }

      updateSql += ' WHERE id = ?';
      params.push(update_id);

      await pool.query(updateSql, params);

      // WebSocket推送升级进度
      const websocketService = require('../services/websocket.service').default;
      websocketService.broadcastToHotel(update.hotel_id, 'firmware_update_progress', {
        update_id,
        device_id,
        status,
        progress,
        timestamp: new Date().toISOString()
      });

      res.json({
        success: true,
        message: 'Progress reported successfully'
      });
    } catch (error) {
      logger.error('Report firmware progress error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }
}

export default new FirmwareController();
