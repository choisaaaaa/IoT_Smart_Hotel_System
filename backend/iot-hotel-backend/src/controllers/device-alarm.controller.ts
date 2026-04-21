import { Request, Response } from 'express';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { isSystemAdmin } from '../utils/role';

class DeviceAlarmController {
  /**
   * 获取设备告警列表
   */
  async getAll(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id ? parseInt(req.query.hotel_id as string) : undefined;
      }

      const { room_id, alarm_type, alarm_level, status, page = 1, pageSize = 20 } = req.query;

      let sql = 'SELECT * FROM device_alarms WHERE 1=1';
      const params: any[] = [];

      if (hotelId) {
        sql += ' AND hotel_id = ?';
        params.push(hotelId);
      }

      if (room_id) {
        sql += ' AND room_id = ?';
        params.push(parseInt(room_id as string));
      }

      if (alarm_type) {
        sql += ' AND alarm_type = ?';
        params.push(alarm_type);
      }

      if (alarm_level) {
        sql += ' AND alarm_level = ?';
        params.push(alarm_level);
      }

      if (status) {
        sql += ' AND status = ?';
        params.push(status);
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
      logger.error('Get device alarms error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 获取告警详情
   */
  async getById(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id || hotelId;
      }

      const alarmId = parseInt(req.params.id);

      let sql = 'SELECT * FROM device_alarms WHERE id = ?';
      const params: any[] = [alarmId];

      if (hotelId) {
        sql += ' AND hotel_id = ?';
        params.push(hotelId);
      }

      const [rows] = await pool.query<RowDataPacket[]>(sql, params);

      if (rows.length === 0) {
        return res.status(404).json({ success: false, message: 'Alarm not found' });
      }

      res.json({
        success: true,
        data: rows[0]
      });
    } catch (error) {
      logger.error('Get alarm by id error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 处理告警
   */
  async handle(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.body.hotel_id || hotelId;
      }
      if (!hotelId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const alarmId = parseInt(req.params.id);
      const { status, handle_remark } = req.body;

      if (!status || !['resolved', 'ignored'].includes(status)) {
        return res.status(400).json({ success: false, message: 'Invalid status' });
      }

      // 验证告警是否属于该酒店
      const [alarms] = await pool.query<RowDataPacket[]>(
        'SELECT id FROM device_alarms WHERE id = ? AND hotel_id = ?',
        [alarmId, hotelId]
      );

      if (alarms.length === 0) {
        return res.status(404).json({ success: false, message: 'Alarm not found' });
      }

      await pool.query(
        'UPDATE device_alarms SET status = ?, handled_by = ?, handled_at = NOW(), handle_remark = ? WHERE id = ?',
        [status, user?.id, handle_remark || null, alarmId]
      );

      res.json({
        success: true,
        message: 'Alarm handled successfully'
      });
    } catch (error) {
      logger.error('Handle alarm error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 获取告警统计
   */
  async getStats(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id ? parseInt(req.query.hotel_id as string) : undefined;
      }

      let whereClause = '';
      const params: any[] = [];

      if (hotelId) {
        whereClause = 'WHERE hotel_id = ?';
        params.push(hotelId);
      }

      // 总数统计
      const [totalResult] = await pool.query<RowDataPacket[]>(
        `SELECT COUNT(*) as total FROM device_alarms ${whereClause}`,
        params
      );

      // 待处理统计
      const [pendingResult] = await pool.query<RowDataPacket[]>(
        `SELECT COUNT(*) as pending FROM device_alarms ${whereClause} AND status = 'pending'`,
        params
      );

      // 按类型统计
      const [typeResult] = await pool.query<RowDataPacket[]>(
        `SELECT alarm_type, COUNT(*) as count FROM device_alarms ${whereClause} GROUP BY alarm_type`,
        params
      );

      // 按级别统计
      const [levelResult] = await pool.query<RowDataPacket[]>(
        `SELECT alarm_level, COUNT(*) as count FROM device_alarms ${whereClause} GROUP BY alarm_level`,
        params
      );

      const byType: Record<string, number> = {};
      typeResult.forEach((row: any) => {
        byType[row.alarm_type] = row.count;
      });

      const byLevel: Record<string, number> = {};
      levelResult.forEach((row: any) => {
        byLevel[row.alarm_level] = row.count;
      });

      res.json({
        success: true,
        data: {
          total_count: totalResult[0]?.total || 0,
          pending_count: pendingResult[0]?.pending || 0,
          by_type: byType,
          by_level: byLevel
        }
      });
    } catch (error) {
      logger.error('Get alarm stats error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 创建设备告警（设备端调用）
   */
  async create(req: Request, res: Response) {
    try {
      const { device_id, hotel_id, room_id, alarm_type, alarm_level, alarm_content } = req.body;

      if (!device_id || !hotel_id || !alarm_type) {
        return res.status(400).json({ success: false, message: 'Missing required parameters' });
      }

      const [result] = await pool.query<ResultSetHeader>(
        'INSERT INTO device_alarms (device_id, hotel_id, room_id, alarm_type, alarm_level, alarm_content) VALUES (?, ?, ?, ?, ?, ?)',
        [device_id, hotel_id, room_id || null, alarm_type, alarm_level || 'warning', alarm_content || null]
      );

      // 如果是紧急告警，触发WebSocket推送
      if (alarm_level === 'emergency') {
        const websocketService = require('../services/websocket.service').default;
        websocketService.broadcastToHotel(hotel_id, 'device_alarm', {
          alarm_id: result.insertId,
          device_id,
          room_id,
          alarm_type,
          alarm_level,
          alarm_content,
          timestamp: new Date().toISOString()
        });
      }

      res.json({
        success: true,
        message: 'Alarm created successfully',
        data: { id: result.insertId }
      });
    } catch (error) {
      logger.error('Create alarm error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }
}

export default new DeviceAlarmController();
