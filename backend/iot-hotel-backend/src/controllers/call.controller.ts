import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { v4 as uuidv4 } from 'uuid';

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
    
    switch (callee_type) {
      case 'room':
        const [room] = await pool.query<RowDataPacket[]>('SELECT id, room_number FROM rooms WHERE id = ? OR room_number = ?', [callee_id, callee_id]);
        calleeExists = room.length > 0;
        break;
      case 'front_desk':
        const [employee] = await pool.query<RowDataPacket[]>('SELECT id FROM users WHERE id = ? OR username = ?', [callee_id, callee_id]);
        calleeExists = employee.length > 0;
        break;
      case 'ai':
        calleeExists = true;
        break;
      case 'app':
        const [user] = await pool.query<RowDataPacket[]>('SELECT id FROM users WHERE id = ?', [callee_id]);
        calleeExists = user.length > 0;
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
      `INSERT INTO calls (call_id, caller_type, caller_id, callee_type, callee_id, status, started_at) 
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [callId, caller_type, caller_id, callee_type, callee_id, 'calling', new Date()]
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
    logger.error('发起语音通话失败:', error);
    res.status(500).json(errorResponse('发起语音通话失败'));
  }
};

export const outboundCall = async (req: AuthRequest, res: Response) => {
  try {
    const { caller_type = 'front_desk', caller_id, callee_type, callee_id, type = 'voice' } = req.body;
    
    if (!caller_id || !callee_type || !callee_id) {
      res.status(400).json(errorResponse('请求参数错误：缺少必要参数'));
      return;
    }
    
    const validOutboundCallerTypes = ['front_desk', 'ai', 'app'];
    if (!validOutboundCallerTypes.includes(caller_type)) {
      res.status(400).json(errorResponse(`无效的caller_type参数，支持的值: ${validOutboundCallerTypes.join(', ')}`));
      return;
    }
    
    const validCalleeTypes = ['room', 'front_desk', 'ai', 'app'];
    if (!validCalleeTypes.includes(callee_type)) {
      res.status(400).json(errorResponse(`无效的callee_type参数，支持的值: ${validCalleeTypes.join(', ')}`));
      return;
    }
    
    const callId = `CALL${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${uuidv4().slice(0, 8).toUpperCase()}`;
    
    let calleeExists = false;
    
    switch (callee_type) {
      case 'room':
        const [room] = await pool.query<RowDataPacket[]>('SELECT id, room_number FROM rooms WHERE id = ? OR room_number = ?', [callee_id, callee_id]);
        calleeExists = room.length > 0;
        break;
      case 'front_desk':
        const [employee] = await pool.query<RowDataPacket[]>('SELECT id FROM users WHERE id = ? OR username = ?', [callee_id, callee_id]);
        calleeExists = employee.length > 0;
        break;
      case 'ai':
        calleeExists = true;
        break;
      case 'app':
        const [user] = await pool.query<RowDataPacket[]>('SELECT id FROM users WHERE id = ?', [callee_id]);
        calleeExists = user.length > 0;
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
      `INSERT INTO calls (call_id, caller_type, caller_id, callee_type, callee_id, status, started_at) 
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [callId, caller_type, caller_id, callee_type, callee_id, 'outgoing', new Date()]
    );
    
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
    logger.error('发起语音通话失败:', error);
    res.status(500).json(errorResponse('发起语音通话失败'));
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
    
    res.json(successResponse({
      call_id,
      status: 'connected',
      answered_at: new Date().toISOString()
    }, '通话已接听'));
  } catch (error) {
    logger.error('接听语音通话失败:', error);
    res.status(500).json(errorResponse('接听语音通话失败'));
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
    
    res.json(successResponse({
      call_id,
      status: 'rejected',
      ended_at: new Date().toISOString()
    }, '通话已拒接'));
  } catch (error) {
    logger.error('拒接语音通话失败:', error);
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
    const durationSec = callData.answered_at 
      ? Math.floor((endedAt.getTime() - new Date(callData.answered_at).getTime()) / 1000)
      : 0;
    
    const [result] = await pool.query<ResultSetHeader>(
      `UPDATE calls SET status = ?, ended_at = ?, duration_sec = ? WHERE call_id = ?`,
      ['ended', endedAt, durationSec, call_id]
    );
    
    res.json(successResponse({
      call_id,
      status: 'ended',
      ended_at: endedAt.toISOString(),
      duration_sec: durationSec
    }, '通话已挂断'));
  } catch (error) {
    logger.error('挂断语音通话失败:', error);
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
    logger.error('查询通话状态失败:', error);
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
    logger.error('获取活跃通话列表失败:', error);
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
    logger.error('获取通话记录失败:', error);
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
    logger.error('获取通话统计失败:', error);
    res.status(500).json(errorResponse('获取通话统计失败'));
  }
};
