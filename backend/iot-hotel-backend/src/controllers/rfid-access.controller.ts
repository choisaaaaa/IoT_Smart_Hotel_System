import { Request, Response } from 'express';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { isSystemAdmin } from '../utils/role';
import { isRfidGuestCardNotExpired } from '../services/rfid.service';

class RfidAccessController {
  /**
   * 获取门禁刷卡记录列表
   */
  async getAll(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id ? parseInt(req.query.hotel_id as string) : undefined;
      }

      const { room_id, card_uid, access_type, access_result, start_date, end_date, page = 1, pageSize = 20 } = req.query;

      let sql = 'SELECT * FROM rfid_access_logs WHERE 1=1';
      const params: any[] = [];

      if (hotelId) {
        sql += ' AND hotel_id = ?';
        params.push(hotelId);
      }

      if (room_id) {
        sql += ' AND room_id = ?';
        params.push(parseInt(room_id as string));
      }

      if (card_uid) {
        sql += ' AND card_uid = ?';
        params.push(card_uid);
      }

      if (access_type) {
        sql += ' AND access_type = ?';
        params.push(access_type);
      }

      if (access_result) {
        sql += ' AND access_result = ?';
        params.push(access_result);
      }

      if (start_date) {
        sql += ' AND created_at >= ?';
        params.push(start_date);
      }

      if (end_date) {
        sql += ' AND created_at <= ?';
        params.push(end_date + ' 23:59:59');
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
      logger.error('Get RFID access logs error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 获取门禁统计
   */
  async getStats(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id ? parseInt(req.query.hotel_id as string) : undefined;
      }
      if (!hotelId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const { room_id, start_date, end_date } = req.query;

      let whereClause = 'WHERE hotel_id = ?';
      const params: any[] = [hotelId];

      if (room_id) {
        whereClause += ' AND room_id = ?';
        params.push(parseInt(room_id as string));
      }

      if (start_date) {
        whereClause += ' AND created_at >= ?';
        params.push(start_date);
      }

      if (end_date) {
        whereClause += ' AND created_at <= ?';
        params.push(end_date + ' 23:59:59');
      }

      // 总刷卡次数
      const [totalResult] = await pool.query<RowDataPacket[]>(
        `SELECT COUNT(*) as total FROM rfid_access_logs ${whereClause}`,
        params
      );

      // 成功次数
      const [successResult] = await pool.query<RowDataPacket[]>(
        `SELECT COUNT(*) as success FROM rfid_access_logs ${whereClause} AND access_result = 'success'`,
        params
      );

      // 失败次数
      const [failedResult] = await pool.query<RowDataPacket[]>(
        `SELECT COUNT(*) as failed FROM rfid_access_logs ${whereClause} AND access_result != 'success'`,
        params
      );

      // 按房间统计
      const [roomResult] = await pool.query<RowDataPacket[]>(
        `SELECT room_id, COUNT(*) as count FROM rfid_access_logs ${whereClause} GROUP BY room_id`,
        params
      );

      const byRoom: Record<string, number> = {};
      roomResult.forEach((row: any) => {
        byRoom[row.room_id] = row.count;
      });

      res.json({
        success: true,
        data: {
          total_access: totalResult[0]?.total || 0,
          success_count: successResult[0]?.success || 0,
          failed_count: failedResult[0]?.failed || 0,
          by_room: byRoom
        }
      });
    } catch (error) {
      logger.error('Get RFID access stats error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 上报门禁记录（设备端调用）
   */
  async create(req: Request, res: Response) {
    try {
      const { card_uid, room_id, device_id, access_type, access_result, fail_reason } = req.body;

      if (!card_uid || !room_id || !device_id || !access_type || !access_result) {
        return res.status(400).json({ success: false, message: 'Missing required parameters' });
      }

      // 获取酒店ID
      const [devices] = await pool.query<RowDataPacket[]>(
        'SELECT hotel_id FROM devices WHERE device_id = ?',
        [device_id]
      );

      if (devices.length === 0) {
        return res.status(404).json({ success: false, message: 'Device not found' });
      }

      const hotelId = devices[0].hotel_id;

      const [result] = await pool.query<ResultSetHeader>(
        'INSERT INTO rfid_access_logs (card_uid, room_id, hotel_id, access_type, access_result, fail_reason, device_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [card_uid, room_id, hotelId, access_type, access_result, fail_reason || null, device_id]
      );

      // WebSocket推送门禁事件
      const websocketService = require('../services/websocket.service').default;
      websocketService.broadcastToHotel(hotelId, 'rfid_access_event', {
        log_id: result.insertId,
        card_uid,
        room_id,
        access_type,
        access_result,
        timestamp: new Date().toISOString()
      });

      res.json({
        success: true,
        message: 'Access log created successfully',
        data: { id: result.insertId }
      });
    } catch (error) {
      logger.error('Create RFID access log error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 验证房卡权限（设备端调用）
   * 设备身份由 deviceAuthMiddleware（x-device-id / x-device-key）校验；请求体仅需 card_uid，
   * 以及 room_id（rooms 表主键）或 room_number（如 "301"）之一以校验是否可开该房门。
   */
  async verify(req: Request, res: Response) {
    try {
      const device = (req as any).device as { deviceId: string; hotelId: number } | undefined;
      if (!device?.hotelId) {
        return res.status(401).json({ success: false, message: 'Device not authenticated' });
      }

      const { card_uid, room_id, room_number } = req.body;

      if (!card_uid) {
        return res.status(400).json({ success: false, message: 'Missing card_uid' });
      }

      const cardUidNorm = String(card_uid).trim().toUpperCase();

      const hotelId = device.hotelId;
      let resolvedRoomDbId: number | null = null;

      if (room_id !== undefined && room_id !== null && String(room_id).trim() !== '') {
        const parsed = parseInt(String(room_id), 10);
        if (Number.isFinite(parsed) && parsed > 0) {
          resolvedRoomDbId = parsed;
        }
      }

      if (resolvedRoomDbId === null && room_number !== undefined && room_number !== null && String(room_number).trim() !== '') {
        const [roomRows] = await pool.query<RowDataPacket[]>(
          'SELECT id FROM rooms WHERE room_number = ? AND hotel_id = ? LIMIT 1',
          [String(room_number).trim(), hotelId]
        );
        if (roomRows.length === 0) {
          return res.json({
            valid: false,
            card_status: 'unknown',
            message: 'Room not found for this hotel'
          });
        }
        resolvedRoomDbId = roomRows[0].id as number;
      }

      if (resolvedRoomDbId === null) {
        return res.status(400).json({ success: false, message: 'Missing room_id or room_number' });
      }

      // 查询房卡信息
      const [cards] = await pool.query<RowDataPacket[]>(
        `SELECT rc.*, r.room_number 
         FROM rfid_cards rc
         LEFT JOIN rooms r ON rc.room_id = r.id
         WHERE UPPER(TRIM(rc.card_uid)) = ? AND rc.hotel_id = ?`,
        [cardUidNorm, hotelId]
      );

      if (cards.length === 0) {
        return res.json({
          valid: false,
          card_status: 'invalid',
          message: 'Card not found'
        });
      }

      const card = cards[0];

      // 检查卡状态
      if (card.status === 'lost') {
        return res.json({
          valid: false,
          card_status: 'lost',
          message: 'Card has been reported lost'
        });
      }

      if (card.status === 'inactive') {
        return res.json({
          valid: false,
          card_status: 'inactive',
          message: 'Card is inactive'
        });
      }

      // 检查有效期（退房日按自然日有效，与 MQTT 自动开锁一致）
      if (card.expires_at && !isRfidGuestCardNotExpired(card.expires_at)) {
        return res.json({
          valid: false,
          card_status: 'expired',
          expires_at: card.expires_at,
          message: 'Card has expired'
        });
      }

      // 检查房间权限
      if (card.room_id && card.room_id !== resolvedRoomDbId) {
        return res.json({
          valid: false,
          card_status: card.status,
          authorized_room: card.room_id,
          requested_room: resolvedRoomDbId,
          message: 'Card not authorized for this room'
        });
      }

      res.json({
        valid: true,
        card_status: card.status,
        room_id: card.room_id,
        room_number: card.room_number,
        expires_at: card.expires_at,
        message: 'Card is valid'
      });
    } catch (error) {
      logger.error('Verify RFID card error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }
}

export default new RfidAccessController();
