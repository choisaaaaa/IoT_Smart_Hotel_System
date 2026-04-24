import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { getWebSocketService } from '../services/websocket.service';
import { isSystemAdmin, normalizeRole, CANONICAL_ROLES } from '../utils/role';

export const sendMessage = async (req: AuthRequest, res: Response) => {
  try {
    const { room_id, booking_id, guest_id, sender_type, sender_id, sender_name, content } = req.body;
    const currentUser = req.user as any;

    if (!room_id || !content || !sender_type) {
      res.status(400).json(errorResponse('缺少必要参数：room_id, content, sender_type'));
      return;
    }

    const validSenderTypes = ['guest', 'front_desk', 'system'];
    if (!validSenderTypes.includes(sender_type)) {
      res.status(400).json(errorResponse(`无效的sender_type，支持的值: ${validSenderTypes.join(', ')}`));
      return;
    }

    let hotelId = req.body.hotel_id;
    if (!hotelId && currentUser) {
      hotelId = currentUser.hotel_id;
    }

    const [room] = await pool.query<RowDataPacket[]>('SELECT id, room_number, hotel_id FROM rooms WHERE id = ?', [room_id]);
    if (room.length === 0) {
      res.status(404).json(errorResponse('房间不存在'));
      return;
    }

    if (!hotelId) {
      hotelId = room[0].hotel_id;
    }

    let finalSenderId = sender_id || null;
    let finalSenderName = sender_name || null;

    if (currentUser) {
      finalSenderId = currentUser.id;
      finalSenderName = currentUser.username || currentUser.phone || `用户${currentUser.id}`;
    }

    const [result] = await pool.query<ResultSetHeader>(
      `INSERT INTO room_messages (hotel_id, room_id, booking_id, guest_id, sender_type, sender_id, sender_name, content)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [hotelId, room_id, booking_id || null, guest_id || null, sender_type, finalSenderId, finalSenderName, content]
    );

    const [newMsg] = await pool.query<RowDataPacket[]>('SELECT * FROM room_messages WHERE id = ?', [result.insertId]);

    try {
      const ws = getWebSocketService();
      if (ws) {
        ws.broadcastToHotel(hotelId, 'new_room_message', {
          message: newMsg[0],
          room_id,
          room_number: room[0].room_number
        });

        if (sender_type === 'guest') {
          ws.broadcastToHotel(hotelId, 'front_desk_new_message', {
            message: newMsg[0],
            room_id,
            room_number: room[0].room_number,
            guest_name: finalSenderName
          });
        } else if (sender_type === 'front_desk') {
          ws.emitToRoom(`room_${room_id}`, 'guest_new_message', {
            message: newMsg[0],
            room_id
          });
        }
      }
    } catch (wsErr: any) {
      logger.warn(`WebSocket推送消息失败: ${wsErr.message}`);
    }

    res.json(successResponse(newMsg[0], '消息发送成功'));
  } catch (error: any) {
    logger.error(`发送消息失败: ${error.message}`, { stack: error.stack });
    res.status(500).json(errorResponse(`发送消息失败: ${error.message}`));
  }
};

export const getMessages = async (req: AuthRequest, res: Response) => {
  try {
    const currentUser = req.user as any;
    const { room_id, hotel_id, is_read, page = 1, pageSize = 50, before_id } = req.query;

    let query = 'SELECT m.*, r.room_number FROM room_messages m LEFT JOIN rooms r ON m.room_id = r.id WHERE 1=1';
    const params: any[] = [];

    if (room_id) {
      query += ' AND m.room_id = ?';
      params.push(Number(room_id));
    }

    if (hotel_id) {
      query += ' AND m.hotel_id = ?';
      params.push(Number(hotel_id));
    } else if (currentUser && !isSystemAdmin(currentUser.role)) {
      query += ' AND m.hotel_id = ?';
      params.push(currentUser.hotel_id);
    }

    if (is_read !== undefined && is_read !== '') {
      query += ' AND m.is_read = ?';
      params.push(Number(is_read));
    }

    if (before_id) {
      query += ' AND m.id < ?';
      params.push(Number(before_id));
    }

    query += ' ORDER BY m.created_at ASC';

    const pageNum = Math.max(1, Number(page));
    const size = Math.min(100, Math.max(1, Number(pageSize)));
    const offset = (pageNum - 1) * size;

    const countQuery = query.replace('SELECT m.*, r.room_number', 'SELECT COUNT(*) as total');
    const [countResult] = await pool.query<RowDataPacket[]>(countQuery.replace(' ORDER BY m.created_at ASC', ''), params);
    const total = countResult[0]?.total || 0;

    query += ` LIMIT ${size} OFFSET ${offset}`;

    const [messages] = await pool.query<RowDataPacket[]>(query, params);

    res.json(successResponse({
      list: messages,
      total,
      page: pageNum,
      pageSize: size
    }));
  } catch (error: any) {
    logger.error(`获取消息列表失败: ${error.message}`, { stack: error.stack });
    res.status(500).json(errorResponse(`获取消息列表失败: ${error.message}`));
  }
};

export const getUnreadCount = async (req: AuthRequest, res: Response) => {
  try {
    const currentUser = req.user as any;
    const { room_id, hotel_id } = req.query;

    let query = 'SELECT COUNT(*) as count FROM room_messages WHERE is_read = 0';
    const params: any[] = [];

    const role = normalizeRole(currentUser?.role);
    if (role === CANONICAL_ROLES.CUSTOMER || role === CANONICAL_ROLES.GUEST) {
      query += ' AND sender_type = ?';
      params.push('front_desk');
      if (room_id) {
        query += ' AND room_id = ?';
        params.push(Number(room_id));
      }
      if (currentUser?.id) {
        query += ' AND (guest_id = ? OR room_id IN (SELECT room_id FROM bookings WHERE user_id = ? AND status = ?))';
        params.push(currentUser.id, currentUser.id, 'checked_in');
      }
    } else {
      if (hotel_id) {
        query += ' AND hotel_id = ?';
        params.push(Number(hotel_id));
      } else if (currentUser?.hotel_id) {
        query += ' AND hotel_id = ?';
        params.push(currentUser.hotel_id);
      }
      query += ' AND sender_type = ?';
      params.push('guest');
    }

    const [result] = await pool.query<RowDataPacket[]>(query, params);
    res.json(successResponse({ count: result[0]?.count || 0 }));
  } catch (error: any) {
    logger.error(`获取未读数失败: ${error.message}`, { stack: error.stack });
    res.status(500).json(errorResponse(`获取未读数失败: ${error.message}`));
  }
};

export const markAsRead = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const currentUser = req.user as any;

    const [msg] = await pool.query<RowDataPacket[]>('SELECT * FROM room_messages WHERE id = ?', [id]);
    if (msg.length === 0) {
      res.status(404).json(errorResponse('消息不存在'));
      return;
    }

    await pool.query('UPDATE room_messages SET is_read = 1, read_at = NOW() WHERE id = ?', [id]);

    res.json(successResponse(null, '已标记为已读'));
  } catch (error: any) {
    logger.error(`标记已读失败: ${error.message}`, { stack: error.stack });
    res.status(500).json(errorResponse(`标记已读失败: ${error.message}`));
  }
};

export const markAllAsRead = async (req: AuthRequest, res: Response) => {
  try {
    const currentUser = req.user as any;
    const { room_id, hotel_id } = req.body;

    let query = 'UPDATE room_messages SET is_read = 1, read_at = NOW() WHERE is_read = 0';
    const params: any[] = [];

    const role = normalizeRole(currentUser?.role);
    if (role === CANONICAL_ROLES.CUSTOMER || role === CANONICAL_ROLES.GUEST) {
      query += ' AND sender_type = ?';
      params.push('front_desk');
      if (room_id) {
        query += ' AND room_id = ?';
        params.push(room_id);
      }
    } else {
      if (hotel_id) {
        query += ' AND hotel_id = ?';
        params.push(hotel_id);
      } else if (currentUser?.hotel_id) {
        query += ' AND hotel_id = ?';
        params.push(currentUser.hotel_id);
      }
      query += ' AND sender_type = ?';
      params.push('guest');
      if (room_id) {
        query += ' AND room_id = ?';
        params.push(room_id);
      }
    }

    const [result] = await pool.query<ResultSetHeader>(query, params);

    res.json(successResponse({ affected: result.affectedRows }, '全部标记已读成功'));
  } catch (error: any) {
    logger.error(`全部标记已读失败: ${error.message}`, { stack: error.stack });
    res.status(500).json(errorResponse(`全部标记已读失败: ${error.message}`));
  }
};

export const getRoomConversations = async (req: AuthRequest, res: Response) => {
  try {
    const currentUser = req.user as any;
    const { hotel_id } = req.query;

    let hotelId = hotel_id ? Number(hotel_id) : currentUser?.hotel_id;

    if (!hotelId) {
      res.status(400).json(errorResponse('缺少酒店ID'));
      return;
    }

    const [conversations] = await pool.query<RowDataPacket[]>(`
      SELECT 
        m.room_id,
        r.room_number,
        m.hotel_id,
        (SELECT content FROM room_messages WHERE room_id = m.room_id AND hotel_id = ? ORDER BY created_at DESC LIMIT 1) as last_message,
        (SELECT created_at FROM room_messages WHERE room_id = m.room_id AND hotel_id = ? ORDER BY created_at DESC LIMIT 1) as last_message_time,
        (SELECT COUNT(*) FROM room_messages WHERE room_id = m.room_id AND hotel_id = ? AND is_read = 0 AND sender_type = 'guest') as unread_count,
        (SELECT u.username FROM room_messages rm LEFT JOIN users u ON rm.guest_id = u.id WHERE rm.room_id = m.room_id AND rm.guest_id IS NOT NULL LIMIT 1) as guest_name
      FROM room_messages m
      LEFT JOIN rooms r ON m.room_id = r.id
      WHERE m.hotel_id = ?
      GROUP BY m.room_id, r.room_number, m.hotel_id
      ORDER BY last_message_time DESC
    `, [hotelId, hotelId, hotelId, hotelId]);

    res.json(successResponse(conversations));
  } catch (error: any) {
    logger.error(`获取房间会话列表失败: ${error.message}`, { stack: error.stack });
    res.status(500).json(errorResponse(`获取房间会话列表失败: ${error.message}`));
  }
};

export const deleteMessage = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const currentUser = req.user as any;

    const [msg] = await pool.query<RowDataPacket[]>('SELECT * FROM room_messages WHERE id = ?', [id]);
    if (msg.length === 0) {
      res.status(404).json(errorResponse('消息不存在'));
      return;
    }

    await pool.query('DELETE FROM room_messages WHERE id = ?', [id]);

    res.json(successResponse(null, '消息已删除'));
  } catch (error: any) {
    logger.error(`删除消息失败: ${error.message}`, { stack: error.stack });
    res.status(500).json(errorResponse(`删除消息失败: ${error.message}`));
  }
};

export const deleteRoomMessages = async (req: AuthRequest, res: Response) => {
  try {
    const { room_id } = req.params;
    const currentUser = req.user as any;

    const [result] = await pool.query<ResultSetHeader>('DELETE FROM room_messages WHERE room_id = ?', [Number(room_id)]);

    res.json(successResponse({ affected: result.affectedRows }, '房间消息已清空'));
  } catch (error: any) {
    logger.error(`清空房间消息失败: ${error.message}`, { stack: error.stack });
    res.status(500).json(errorResponse(`清空房间消息失败: ${error.message}`));
  }
};
