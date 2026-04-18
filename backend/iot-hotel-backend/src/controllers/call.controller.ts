import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { v4 as uuidv4 } from 'uuid';
import { getWebSocketService } from '../services/websocket.service';
import { isSystemAdmin, isCustomer, isGuest, normalizeRole } from '../utils/role';

export const initiateCall = async (req: AuthRequest, res: Response) => {
  try {
    const { caller_type = 'room', caller_id, callee_type, callee_id, type = 'voice' } = req.body;

    if (!caller_id || !callee_type || !callee_id) {
      res.status(400).json(errorResponse('请求参数错误：缺少必要参数'));
      return;
    }

    const validCallerTypes = ['room', 'front_desk', 'ai', 'app'];
    if (!validCallerTypes.includes(caller_type)) {
      res.status(400).json(errorResponse(`无效的caller_type参数，支持的值: ${validCallerTypes.join(', ')}`));
      return;
    }

    if (!validCallerTypes.includes(callee_type)) {
      res.status(400).json(errorResponse(`无效的callee_type参数，支持的值: ${validCallerTypes.join(', ')}`));
      return;
    }

    const callId = `CALL${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${uuidv4().slice(0, 8).toUpperCase()}`;

    let calleeExists = false;
    let calleeInfo: any = null;
    const currentUser = req.user as any;

    switch (callee_type) {
      case 'room':
        const [room] = await pool.query<RowDataPacket[]>('SELECT id, room_number, hotel_id FROM rooms WHERE id = ? OR room_number = ?', [callee_id, callee_id]);
        if (room.length > 0) {
          calleeExists = true;
          calleeInfo = room[0];
          // 隔离：只能拨打本店房间
          if (!isSystemAdmin(currentUser.role) && calleeInfo.hotel_id !== currentUser.hotel_id) {
            res.status(403).json(errorResponse('权限不足：无法拨打其他酒店的房间'));
            return;
          }
        }
        break;
      case 'front_desk':
      case 'app':
        const [employee] = await pool.query<RowDataPacket[]>('SELECT id, hotel_id, role FROM users WHERE id = ? OR username = ?', [callee_id, callee_id]);
        if (employee.length > 0) {
          calleeExists = true;
          calleeInfo = employee[0];

          if (isCustomer(calleeInfo.role) || isGuest(calleeInfo.role)) {
            res.status(403).json(errorResponse('权限不足：无法直接拨打普通用户'));
            return;
          }

          if (!isSystemAdmin(currentUser.role) && calleeInfo.hotel_id !== currentUser.hotel_id) {
            res.status(403).json(errorResponse('权限不足：无法拨打其他酒店的员工'));
            return;
          }
        }
        break;
      case 'ai':
        calleeExists = true;
        break;
    }

    if (!calleeExists) {
      res.status(400).json(errorResponse('被叫方不存在'));
      return;
    }

    const [existingCall] = await pool.query<RowDataPacket[]>(
      'SELECT * FROM calls WHERE (callee_type = ? AND callee_id = ? OR caller_type = ? AND caller_id = ?) AND status IN (?, ?, ?, ?) LIMIT 1',
      [callee_type, callee_id, callee_type, callee_id, 'calling', 'outgoing', 'ringing', 'connected']
    );

    if (existingCall.length > 0) {
      res.status(409).json(errorResponse('该用户已有通话进行中'));
      return;
    }

    const [result] = await pool.query<ResultSetHeader>(
      `INSERT INTO calls (call_id, caller_type, caller_id, callee_type, callee_id, hotel_id, status, started_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [callId, caller_type, caller_id, callee_type, callee_id, currentUser.hotel_id, 'calling', new Date()]
    );

    res.json(successResponse({
      call_id: callId,
      caller_type,
      caller_id,
      callee_type,
      callee_id,
      status: 'calling',
      type,
      started_at: new Date().toISOString()
    }, '通话请求已发送'));
  } catch (error) {
    logger.error(`发起语音通话失败: ${error.message}`, { stack: error.stack });
    res.status(500).json(errorResponse(`发起语音通话失败: ${error.message}`));
  }
};

export const outboundCall = async (req: AuthRequest, res: Response) => {
  try {
    let { caller_type = 'front_desk', caller_id, callee_type, callee_id, type = 'voice' } = req.body;

    if (!caller_id || !callee_type || !callee_id) {
      res.status(400).json(errorResponse('请求参数错误：缺少必要参数'));
      return;
    }

    const validOutboundCallerTypes = ['room', 'front_desk', 'ai', 'app'];
    if (!validOutboundCallerTypes.includes(caller_type)) {
      res.status(400).json(errorResponse(`无效的caller_type参数，支持的值: ${validOutboundCallerTypes.join(', ')}`));
      return;
    }

    const validCalleeTypes = ['room', 'front_desk', 'ai', 'app'];
    if (!validCalleeTypes.includes(callee_type)) {
      res.status(400).json(errorResponse(`无效的callee_type参数，支持的值: ${validCalleeTypes.join(', ')}`));
      return;
    }

    if (caller_type === 'room') {
      const [roomRows] = await pool.query<RowDataPacket[]>(
        'SELECT id FROM rooms WHERE id = ? OR room_number = ?',
        [caller_id, caller_id]
      );
      if (roomRows.length > 0) {
        caller_id = String(roomRows[0].id);
      }
    }

    if (callee_type === 'room') {
      const [roomRows] = await pool.query<RowDataPacket[]>(
        'SELECT id FROM rooms WHERE id = ? OR room_number = ?',
        [callee_id, callee_id]
      );
      if (roomRows.length > 0) {
        callee_id = String(roomRows[0].id);
      }
    }

    const callId = `CALL${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${uuidv4().slice(0, 8).toUpperCase()}`;

    let calleeExists = false;
    let calleeInfo: any = null;
    const currentUser = req.user as any;

    switch (callee_type) {
      case 'room':
        const [room] = await pool.query<RowDataPacket[]>('SELECT id, room_number, hotel_id FROM rooms WHERE id = ? OR room_number = ?', [callee_id, callee_id]);
        if (room.length > 0) {
          calleeExists = true;
          calleeInfo = room[0];
          if (!isSystemAdmin(currentUser.role) && calleeInfo.hotel_id !== currentUser.hotel_id) {
            res.status(403).json(errorResponse('权限不足：无法拨打其他酒店的房间'));
            return;
          }
        }
        break;
      case 'front_desk':
        // 呼叫前台：查找当前酒店的前台/管理员用户
        const [frontDeskUsers] = await pool.query<RowDataPacket[]>(
          'SELECT id, hotel_id, role, username FROM users WHERE hotel_id = ? AND role IN (?, ?, ?) ORDER BY id LIMIT 1',
          [currentUser.hotel_id || 1, 'admin', 'receptionist', 'staff']
        );
        if (frontDeskUsers.length > 0) {
          calleeExists = true;
          calleeInfo = frontDeskUsers[0];
        } else {
          // 如果没有找到特定酒店的前台，查找任意前台用户
          const [anyFrontDesk] = await pool.query<RowDataPacket[]>(
            'SELECT id, hotel_id, role, username FROM users WHERE role IN (?, ?, ?) ORDER BY id LIMIT 1',
            ['admin', 'receptionist', 'staff']
          );
          if (anyFrontDesk.length > 0) {
            calleeExists = true;
            calleeInfo = anyFrontDesk[0];
          }
        }
        break;
      case 'app':
        const [employee] = await pool.query<RowDataPacket[]>('SELECT id, hotel_id, role FROM users WHERE id = ? OR username = ?', [callee_id, callee_id]);
        if (employee.length > 0) {
          calleeExists = true;
          calleeInfo = employee[0];

          if (isCustomer(calleeInfo.role) || isGuest(calleeInfo.role)) {
            res.status(403).json(errorResponse('权限不足：无法直接拨打普通用户'));
            return;
          }

          if (!isSystemAdmin(currentUser.role) && calleeInfo.hotel_id !== currentUser.hotel_id) {
            res.status(403).json(errorResponse('权限不足：无法拨打其他酒店的员工'));
            return;
          }
        }
        break;
      case 'ai':
        calleeExists = true;
        break;
    }

    if (!calleeExists) {
      res.status(400).json(errorResponse('被叫方不存在'));
      return;
    }

    const [existingCall] = await pool.query<RowDataPacket[]>(
      'SELECT * FROM calls WHERE caller_type = ? AND caller_id = ? AND callee_id = ? AND status IN (?, ?, ?) LIMIT 1',
      [caller_type, caller_id, callee_id, 'outgoing', 'ringing', 'connected']
    );

    if (existingCall.length > 0) {
      res.status(409).json(errorResponse('该通话已在进行中'));
      return;
    }

    const [result] = await pool.query<ResultSetHeader>(
      `INSERT INTO calls (call_id, caller_type, caller_id, callee_type, callee_id, hotel_id, status, started_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [callId, caller_type, caller_id, callee_type, callee_id, currentUser.hotel_id, 'outgoing', new Date()]
    );

    // 发送 WebSocket 事件通知被叫方
    const wsService = getWebSocketService();
    const io = wsService?.getIO();
    if (io) {
      // 获取主叫方的显示名称和酒店信息
    let callerDisplayName = caller_id;
    let callerHotelName = '';
    let hotelId = currentUser.hotel_id;

    if (caller_type === 'room') {
      const [roomRows] = await pool.query<RowDataPacket[]>(
        'SELECT id, room_number, hotel_id FROM rooms WHERE id = ? OR room_number = ?',
        [caller_id, caller_id]
      );
      if (roomRows.length > 0) {
        const room = roomRows[0];
        callerDisplayName = `客房 ${room.room_number}`;
        hotelId = room.hotel_id;
      }
    }

    if (hotelId) {
      const [hotelRows] = await pool.query<RowDataPacket[]>(
        'SELECT hotel_name FROM hotels WHERE id = ?',
        [hotelId]
      );
      if (hotelRows.length > 0) {
        callerHotelName = hotelRows[0].hotel_name;
      }
    }

    const callData = {
      call_id: callId,
      caller_type,
      caller_id,
      caller_name: callerDisplayName,
      hotel_name: callerHotelName,
      callee_type,
      callee_id,
      status: 'calling',
      type,
      started_at: new Date().toISOString()
    };

      // 发起呼叫通知
    if (callee_type === 'front_desk') {
      // 门店隔离广播
      if (hotelId) {
        const hotelRoom = `front_desk_hotel_${hotelId}`;
        logger.info(`[CallController] 发送 incoming_call 到酒店前台房间: ${hotelRoom}`);
        io.to(hotelRoom).emit('incoming_call', callData);
      } else {
        // 出于安全考虑，如果完全没有酒店ID，只发送给特定 callee
        const targetRoom = `${callee_type}_${callee_id}`;
        io.to(targetRoom).emit('incoming_call', callData);
      }
    } else {
        // 只发送到定向房间
        const targetRoom = `${callee_type}_${callee_id}`;
        logger.info(`[HTTP API] 发送 incoming_call 到房间: ${targetRoom}`);
        io.to(targetRoom).emit('incoming_call', callData);
      }
    }

    res.json(successResponse({
      call_id: callId,
      caller_type,
      caller_id,
      callee_type,
      callee_id,
      status: 'outgoing',
      type,
      started_at: new Date().toISOString()
    }, '通话已发起'));
  } catch (error) {
    logger.error(`发起外呼失败: ${error.message}`, { stack: error.stack });
    res.status(500).json(errorResponse(`发起外呼失败: ${error.message}`));
  }
};

export const answerCall = async (req: AuthRequest, res: Response) => {
  try {
    const { call_id } = req.params;

    const [call] = await pool.query<RowDataPacket[]>('SELECT * FROM calls WHERE call_id = ?', [call_id]);
    if (call.length === 0) {
      res.status(404).json(errorResponse('通话不存在'));
      return;
    }

    const callData = call[0];

    if (['ended', 'rejected'].includes(callData.status)) {
      res.status(409).json(errorResponse('通话已结束或已拒接'));
      return;
    }

    const [result] = await pool.query<ResultSetHeader>(
      `UPDATE calls SET status = ?, answered_at = ? WHERE call_id = ?`,
      ['connected', new Date(), call_id]
    );

    // 发送 WebSocket 事件通知双方
    const wsService = getWebSocketService();
    const io = wsService?.getIO();
    if (io) {
      let normalizedCallerId = String(callData.caller_id);
      let normalizedCalleeId = String(callData.callee_id);

      if (callData.caller_type === 'room') {
        const [roomRows] = await pool.query<RowDataPacket[]>(
          'SELECT id FROM rooms WHERE id = ? OR room_number = ?',
          [callData.caller_id, callData.caller_id]
        );
        if (roomRows.length > 0) {
          normalizedCallerId = String(roomRows[0].id);
        }
      }

      if (callData.callee_type === 'room') {
        const [roomRows] = await pool.query<RowDataPacket[]>(
          'SELECT id FROM rooms WHERE id = ? OR room_number = ?',
          [callData.callee_id, callData.callee_id]
        );
        if (roomRows.length > 0) {
          normalizedCalleeId = String(roomRows[0].id);
        }
      }

      const answeredData = {
        call_id,
        caller_type: callData.caller_type,
        caller_id: callData.caller_id,
        callee_type: callData.callee_type,
        callee_id: callData.callee_id,
        status: 'connected',
        answered_at: new Date().toISOString()
      };

      // 1. 通知主叫方（使用标准化ID）
      const callerRoom = `${callData.caller_type}_${normalizedCallerId}`;
      logger.info(`[HTTP API] 发送 call_answered 到主叫方房间: ${callerRoom} (原始caller_id: ${callData.caller_id}), call_id: ${call_id}`);
      io.to(callerRoom).emit('call_answered', answeredData);

      // 2. 通知被叫方（使用标准化ID）
      const calleeRoom = `${callData.callee_type}_${normalizedCalleeId}`;
      logger.info(`[HTTP API] 发送 call_answered 到被叫方房间: ${calleeRoom} (原始callee_id: ${callData.callee_id}), call_id: ${call_id}`);
      io.to(calleeRoom).emit('call_answered', answeredData);

      // 3. 通知该门店的所有前台（同步状态）
      if (callData.hotel_id) {
        const hotelRoom = `front_desk_hotel_${callData.hotel_id}`;
        logger.info(`[HTTP API] 发送 call_answered 到酒店前台房间: ${hotelRoom}`);
        io.to(hotelRoom).emit('call_answered', answeredData);
      }
    } else {
      logger.error(`[HTTP API] WebSocket服务不可用，无法发送call_answered事件`);
    }

    res.json(successResponse({
      call_id,
      status: 'connected',
      answered_at: new Date().toISOString()
    }, '通话已接听'));
  } catch (error) {
    logger.error(`接听语音通话失败: ${error.message}`, { stack: error.stack });
    res.status(500).json(errorResponse(`接听语音通话失败: ${error.message}`));
  }
};

export const rejectCall = async (req: AuthRequest, res: Response) => {
  try {
    const { call_id } = req.params;

    const [call] = await pool.query<RowDataPacket[]>('SELECT * FROM calls WHERE call_id = ?', [call_id]);
    if (call.length === 0) {
      res.status(404).json(errorResponse('通话不存在'));
      return;
    }

    const callData = call[0];

    if (callData.status === 'ended') {
      res.status(409).json(errorResponse('通话已结束'));
      return;
    }

    const [result] = await pool.query<ResultSetHeader>(
      `UPDATE calls SET status = ?, ended_at = ? WHERE call_id = ?`,
      ['rejected', new Date(), call_id]
    );

    // 发送 WebSocket 事件通知对方
    const wsService = getWebSocketService();
    const io = wsService?.getIO();
    if (io) {
      let normalizedCallerId = String(callData.caller_id);
      let normalizedCalleeId = String(callData.callee_id);

      if (callData.caller_type === 'room') {
        const [roomRows] = await pool.query<RowDataPacket[]>(
          'SELECT id FROM rooms WHERE id = ? OR room_number = ?',
          [callData.caller_id, callData.caller_id]
        );
        if (roomRows.length > 0) {
          normalizedCallerId = String(roomRows[0].id);
        }
      }

      if (callData.callee_type === 'room') {
        const [roomRows] = await pool.query<RowDataPacket[]>(
          'SELECT id FROM rooms WHERE id = ? OR room_number = ?',
          [callData.callee_id, callData.callee_id]
        );
        if (roomRows.length > 0) {
          normalizedCalleeId = String(roomRows[0].id);
        }
      }

      const callerRoom = `${callData.caller_type}_${normalizedCallerId}`;
      const calleeRoom = `${callData.callee_type}_${normalizedCalleeId}`;
      io.to(callerRoom).emit('call_rejected', { call_id });
      io.to(calleeRoom).emit('call_rejected', { call_id });
      logger.info(`[HTTP API] 发送 call_rejected 到双方房间 (caller: ${callerRoom}, callee: ${calleeRoom})`);

      if (callData.hotel_id) {
        const hotelRoom = `front_desk_hotel_${callData.hotel_id}`;
        io.to(hotelRoom).emit('call_rejected', { call_id });
        logger.info(`[HTTP API] 发送 call_rejected 到酒店前台房间: ${hotelRoom}`);
      }
    }

    res.json(successResponse({
      call_id,
      status: 'rejected',
      ended_at: new Date().toISOString()
    }, '通话已拒接'));
  } catch (error) {
    logger.error('拒接语音通话失败:', error.message);
    res.status(500).json(errorResponse('拒接语音通话失败'));
  }
};

export const hangupCall = async (req: AuthRequest, res: Response) => {
  try {
    const { call_id } = req.params;

    const [call] = await pool.query<RowDataPacket[]>('SELECT * FROM calls WHERE call_id = ?', [call_id]);
    if (call.length === 0) {
      res.status(404).json(errorResponse('通话不存在'));
      return;
    }

    const callData = call[0];

    if (callData.status === 'ended') {
      res.status(409).json(errorResponse('通话已结束'));
      return;
    }

    const endedAt = new Date();
    let durationSec = 0;
    if (callData.answered_at) {
      const answeredAt = new Date(callData.answered_at);
      if (!isNaN(answeredAt.getTime())) {
        durationSec = Math.max(0, Math.floor((endedAt.getTime() - answeredAt.getTime()) / 1000));
      }
    }

    const [result] = await pool.query<ResultSetHeader>(
      `UPDATE calls SET status = ?, ended_at = ?, duration_sec = ? WHERE call_id = ?`,
      ['ended', endedAt, durationSec, call_id]
    );

    // 发送 WebSocket 事件通知对方
    const wsService = getWebSocketService();
    const io = wsService?.getIO();
    if (io) {
      let normalizedCallerId = String(callData.caller_id);
      let normalizedCalleeId = String(callData.callee_id);

      if (callData.caller_type === 'room') {
        const [roomRows] = await pool.query<RowDataPacket[]>(
          'SELECT id FROM rooms WHERE id = ? OR room_number = ?',
          [callData.caller_id, callData.caller_id]
        );
        if (roomRows.length > 0) {
          normalizedCallerId = String(roomRows[0].id);
        }
      }

      if (callData.callee_type === 'room') {
        const [roomRows] = await pool.query<RowDataPacket[]>(
          'SELECT id FROM rooms WHERE id = ? OR room_number = ?',
          [callData.callee_id, callData.callee_id]
        );
        if (roomRows.length > 0) {
          normalizedCalleeId = String(roomRows[0].id);
        }
      }

      const callerRoom = `${callData.caller_type}_${normalizedCallerId}`;
      const calleeRoom = `${callData.callee_type}_${normalizedCalleeId}`;
      io.to(callerRoom).emit('call_hungup', { call_id });
      io.to(calleeRoom).emit('call_hungup', { call_id });
      logger.info(`[HTTP API] 发送 call_hungup 到双方房间 (caller: ${callerRoom}, callee: ${calleeRoom})`);

      if (callData.hotel_id) {
        const hotelRoom = `front_desk_hotel_${callData.hotel_id}`;
        io.to(hotelRoom).emit('call_hungup', { call_id });
        logger.info(`[HTTP API] 发送 call_hungup 到酒店前台房间: ${hotelRoom}`);
      }
    }

    res.json(successResponse({
      call_id,
      status: 'ended',
      ended_at: endedAt.toISOString(),
      duration_sec: durationSec
    }, '通话已挂断'));
  } catch (error) {
    logger.error('挂断语音通话失败:', error.message);
    res.status(500).json(errorResponse('挂断语音通话失败'));
  }
};

export const getCallStatus = async (req: AuthRequest, res: Response) => {
  try {
    const { call_id } = req.params;

    const [call] = await pool.query<RowDataPacket[]>('SELECT * FROM calls WHERE call_id = ?', [call_id]);
    if (call.length === 0) {
      res.status(404).json(errorResponse('通话不存在'));
      return;
    }

    res.json(successResponse(call[0], '查询通话状态成功'));
  } catch (error) {
    logger.error('查询通话状态失败:', error.message);
    res.status(500).json(errorResponse('查询通话状态失败'));
  }
};

export const getActiveCalls = async (req: AuthRequest, res: Response) => {
  try {
    const [rows] = await pool.query<RowDataPacket[]>(
      'SELECT * FROM calls WHERE status IN (?, ?, ?, ?) ORDER BY started_at DESC',
      ['calling', 'outgoing', 'connected', 'ringing']
    );

    res.json(successResponse({ items: rows }, '获取活跃通话列表成功'));
  } catch (error) {
    logger.error('获取活跃通话列表失败:', error.message);
    res.status(500).json(errorResponse('获取活跃通话列表失败'));
  }
};

export const getCallHistory = async (req: AuthRequest, res: Response) => {
  try {
    const { page = 1, limit = 10, room_id, start_time, end_time } = req.query;
    const offset = (Number(page) - 1) * Number(limit);

    let whereClause = 'WHERE 1=1';
    const params: any[] = [];

    if (room_id) {
      whereClause += ' AND (caller_id = ? OR callee_id = ?)';
      params.push(room_id, room_id);
    }

    if (start_time) {
      whereClause += ' AND started_at >= ?';
      params.push(start_time);
    }

    if (end_time) {
      whereClause += ' AND started_at <= ?';
      params.push(end_time);
    }

    const [totalRows] = await pool.query<RowDataPacket[]>(`SELECT COUNT(*) as total FROM calls ${whereClause}`, params);
    const total = (totalRows[0] as any).total;

    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT * FROM calls ${whereClause} ORDER BY started_at DESC LIMIT ? OFFSET ?`,
      [...params, Number(limit), offset]
    );

    res.json(successResponse({
      total,
      page: Number(page),
      limit: Number(limit),
      items: rows
    }, '获取通话记录成功'));
  } catch (error) {
    logger.error('获取通话记录失败:', error.message);
    res.status(500).json(errorResponse('获取通话记录失败'));
  }
};

export const getCallStats = async (req: AuthRequest, res: Response) => {
  try {
    const { start_time, end_time, room_id } = req.query;

    let whereClause = 'WHERE status = ?';
    const params: any[] = ['ended'];

    if (start_time) {
      whereClause += ' AND started_at >= ?';
      params.push(start_time);
    }

    if (end_time) {
      whereClause += ' AND started_at <= ?';
      params.push(end_time);
    }

    if (room_id) {
      whereClause += ' AND (caller_id = ? OR callee_id = ?)';
      params.push(room_id, room_id);
    }

    const [statsRows] = await pool.query<RowDataPacket[]>(
      `SELECT
        COUNT(*) as total_calls,
        COALESCE(SUM(duration_sec), 0) as total_duration_sec,
        SUM(CASE WHEN answered_at IS NOT NULL THEN 1 ELSE 0 END) as answered_calls,
        SUM(CASE WHEN status = 'missed' THEN 1 ELSE 0 END) as missed_calls,
        SUM(CASE WHEN status = 'rejected' THEN 1 ELSE 0 END) as rejected_calls,
        COALESCE(AVG(CASE WHEN answered_at IS NOT NULL THEN duration_sec ELSE NULL END), 0) as avg_duration_sec
      FROM calls ${whereClause}`,
      params
    );

    const stats = statsRows[0];
    const totalCalls = stats.total_calls || 0;
    const answeredCalls = stats.answered_calls || 0;

    res.json(successResponse({
      total_calls: totalCalls,
      total_duration_sec: stats.total_duration_sec || 0,
      answered_calls: answeredCalls,
      missed_calls: stats.missed_calls || 0,
      rejected_calls: stats.rejected_calls || 0,
      avg_duration_sec: Math.round(stats.avg_duration_sec || 0),
      answer_rate: totalCalls > 0 ? parseFloat((answeredCalls / totalCalls).toFixed(2)) : 0
    }, '获取通话统计成功'));
  } catch (error) {
    logger.error('获取通话统计失败:', error.message);
    res.status(500).json(errorResponse('获取通话统计失败'));
  }
};
