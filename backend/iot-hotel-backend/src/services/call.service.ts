import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { v4 as uuidv4 } from 'uuid';
import { Call, CallInput, CallStatusUpdate, CallQuery, CallStats } from '../models/call.model';

export interface CallWithRoom extends Call {
  room_number?: string;
}

export interface CallListResponse {
  list: Call[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

export class CallService {
  static async initiateCall(data: CallInput): Promise<Call> {
    try {
      const callId = `CALL${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${uuidv4().slice(0, 8).toUpperCase()}`;
      
      let calleeExists = false;
      
      // 集体呼叫模式：callee_id 为 'all' 时跳过存在性检查
      if (data.callee_id !== 'all') {
        switch (data.callee_type) {
          case 'room':
            const [room] = await pool.query<RowDataPacket[]>('SELECT id, room_number FROM rooms WHERE id = ? OR room_number = ?', [data.callee_id, data.callee_id]);
            calleeExists = room.length > 0;
            break;
          case 'front_desk':
            const [employee] = await pool.query<RowDataPacket[]>('SELECT id, role FROM users WHERE id = ? OR username = ?', [data.callee_id, data.callee_id]);
            if (employee.length > 0) {
              const userRole = employee[0].role;
              if (userRole === 'customer') {
                throw new Error('被叫方权限不足：无法拨打普通用户');
              }
              calleeExists = true;
            }
            break;
          case 'ai':
            calleeExists = true;
            break;
          case 'app':
            const [user] = await pool.query<RowDataPacket[]>('SELECT id FROM users WHERE id = ?', [data.callee_id]);
            calleeExists = user.length > 0;
            break;
        }
        
        if (!calleeExists) {
          throw new Error('被叫方不存在');
        }
      } else {
        calleeExists = true; // 集体呼叫模式，始终存在
      }
      
      const [existingCall] = await pool.query<RowDataPacket[]>(
        'SELECT * FROM calls WHERE (callee_type = ? AND callee_id = ? OR caller_type = ? AND caller_id = ?) AND status IN (?, ?, ?, ?) LIMIT 1',
        [data.callee_type, data.callee_id, data.callee_type, data.callee_id, 'calling', 'outgoing', 'ringing', 'connected']
      );
      
      if (existingCall.length > 0) {
        throw new Error('该用户已有通话进行中');
      }
      
      const [result] = await pool.query<ResultSetHeader>(
        `INSERT INTO calls (hotel_id, call_id, caller_type, caller_id, callee_type, callee_id, status, started_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [data.hotel_id, callId, data.caller_type, data.caller_id, data.callee_type, data.callee_id, 'calling', new Date()]
      );

      return {
        id: result.insertId,
        hotel_id: data.hotel_id,
        call_id: callId,
        caller_type: data.caller_type,
        caller_id: data.caller_id,
        callee_type: data.callee_type,
        callee_id: data.callee_id,
        status: 'calling',
        started_at: new Date().toISOString(),
        answered_at: null,
        ended_at: null,
        duration_sec: 0,
        recording_url: null,
        created_at: new Date().toISOString()
      };
    } catch (error) {
      logger.error('发起语音通话失败:', error.message);
      throw error;
    }
  }

  static async outboundCall(data: CallInput): Promise<Call> {
    try {
      const callId = `CALL${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${uuidv4().slice(0, 8).toUpperCase()}`;
      
      let calleeExists = false;
      
      switch (data.callee_type) {
        case 'room':
          const [room] = await pool.query<RowDataPacket[]>('SELECT id, room_number FROM rooms WHERE id = ? OR room_number = ?', [data.callee_id, data.callee_id]);
          calleeExists = room.length > 0;
          break;
        case 'front_desk':
          const [employee] = await pool.query<RowDataPacket[]>('SELECT id FROM users WHERE id = ? OR username = ?', [data.callee_id, data.callee_id]);
          calleeExists = employee.length > 0;
          break;
        case 'ai':
          calleeExists = true;
          break;
        case 'app':
          const [user] = await pool.query<RowDataPacket[]>('SELECT id FROM users WHERE id = ?', [data.callee_id]);
          calleeExists = user.length > 0;
          break;
      }
      
      if (!calleeExists) {
        throw new Error('被叫方不存在');
      }
      
      const [existingCall] = await pool.query<RowDataPacket[]>(
        'SELECT * FROM calls WHERE caller_type = ? AND caller_id = ? AND callee_id = ? AND status IN (?, ?, ?) LIMIT 1',
        [data.caller_type, data.caller_id, data.callee_id, 'outgoing', 'ringing', 'connected']
      );
      
      if (existingCall.length > 0) {
        throw new Error('该通话已在进行中');
      }
      
      const [result] = await pool.query<ResultSetHeader>(
        `INSERT INTO calls (hotel_id, call_id, caller_type, caller_id, callee_type, callee_id, status, started_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [data.hotel_id, callId, data.caller_type, data.caller_id, data.callee_type, data.callee_id, 'outgoing', new Date()]
      );

      return {
        id: result.insertId,
        hotel_id: data.hotel_id,
        call_id: callId,
        caller_type: data.caller_type,
        caller_id: data.caller_id,
        callee_type: data.callee_type,
        callee_id: data.callee_id,
        status: 'outgoing',
        started_at: new Date().toISOString(),
        answered_at: null,
        ended_at: null,
        duration_sec: 0,
        recording_url: null,
        created_at: new Date().toISOString()
      };
    } catch (error) {
      logger.error('前台发起语音通话失败:', error.message);
      throw error;
    }
  }

  static async answerCall(callId: string): Promise<Call> {
    try {
      const [call] = await pool.query<RowDataPacket[]>('SELECT * FROM calls WHERE call_id = ?', [callId]);
      if (call.length === 0) {
        throw new Error('通话不存在');
      }
      
      const callData = call[0];
      
      if (['ended', 'rejected'].includes(callData.status)) {
        throw new Error('通话已结束或已拒接');
      }
      
      const [result] = await pool.query<ResultSetHeader>(
        `UPDATE calls SET status = ?, answered_at = ? WHERE call_id = ?`,
        ['connected', new Date(), callId]
      );
      
      return {
        ...(callData as Call),
        status: 'connected',
        answered_at: new Date().toISOString()
      };
    } catch (error) {
      logger.error('接听语音通话失败:', error.message);
      throw error;
    }
  }

  static async rejectCall(callId: string): Promise<Call> {
    try {
      const [call] = await pool.query<RowDataPacket[]>('SELECT * FROM calls WHERE call_id = ?', [callId]);
      if (call.length === 0) {
        throw new Error('通话不存在');
      }
      
      const callData = call[0];
      
      if (callData.status === 'ended') {
        throw new Error('通话已结束');
      }
      
      const [result] = await pool.query<ResultSetHeader>(
        `UPDATE calls SET status = ?, ended_at = ? WHERE call_id = ?`,
        ['rejected', new Date(), callId]
      );
      
      return {
        ...(callData as Call),
        status: 'rejected',
        ended_at: new Date().toISOString()
      };
    } catch (error) {
      logger.error('拒接语音通话失败:', error.message);
      throw error;
    }
  }

  static async hangupCall(callId: string): Promise<Call> {
    try {
      const [call] = await pool.query<RowDataPacket[]>('SELECT * FROM calls WHERE call_id = ?', [callId]);
      if (call.length === 0) {
        throw new Error('通话不存在');
      }
      
      const callData = call[0];
      
      if (callData.status === 'ended') {
        throw new Error('通话已结束');
      }
      
      const endedAt = new Date();
      const durationSec = callData.answered_at 
        ? Math.floor((endedAt.getTime() - new Date(callData.answered_at).getTime()) / 1000)
        : 0;
      
      const [result] = await pool.query<ResultSetHeader>(
        `UPDATE calls SET status = ?, ended_at = ?, duration_sec = ? WHERE call_id = ?`,
        ['ended', endedAt, durationSec, callId]
      );
      
      return {
        ...(callData as Call),
        status: 'ended',
        ended_at: endedAt.toISOString(),
        duration_sec: durationSec
      };
    } catch (error) {
      logger.error('挂断语音通话失败:', error.message);
      throw error;
    }
  }

  static async getCallStatus(callId: string): Promise<Call | null> {
    try {
      const [call] = await pool.query<RowDataPacket[]>('SELECT * FROM calls WHERE call_id = ?', [callId]);
      return (call[0] as Call) || null;
    } catch (error) {
      logger.error('查询通话状态失败:', error.message);
      throw error;
    }
  }

  static async getActiveCalls(): Promise<Call[]> {
    try {
      const [rows] = await pool.query<RowDataPacket[]>(
        'SELECT * FROM calls WHERE status IN (?, ?, ?, ?) ORDER BY started_at DESC',
        ['calling', 'outgoing', 'connected', 'ringing']
      );
      return rows as Call[];
    } catch (error) {
      logger.error('获取活跃通话列表失败:', error.message);
      throw error;
    }
  }

  static async getCallHistory(params: CallQuery): Promise<CallListResponse> {
    try {
      const { page = 1, pageSize = 10, room_id, start_time, end_time } = params;
      const offset = (Number(page) - 1) * Number(pageSize);
      
      let whereClause = 'WHERE 1=1';
      const paramsArray: any[] = [];
      
      if (room_id) {
        whereClause += ' AND (caller_id = ? OR callee_id = ?)';
        paramsArray.push(room_id, room_id);
      }
      
      if (start_time) {
        whereClause += ' AND started_at >= ?';
        paramsArray.push(start_time);
      }
      
      if (end_time) {
        whereClause += ' AND started_at <= ?';
        paramsArray.push(end_time);
      }
      
      const [totalRows] = await pool.query<RowDataPacket[]>(`SELECT COUNT(*) as total FROM calls ${whereClause}`, paramsArray);
      const total = (totalRows[0] as any).total;
      
      const [rows] = await pool.query<RowDataPacket[]>(
        `SELECT * FROM calls ${whereClause} ORDER BY started_at DESC LIMIT ? OFFSET ?`,
        [...paramsArray, Number(pageSize), offset]
      );
      
      return {
        list: rows as Call[],
        total,
        page: Number(page),
        pageSize: Number(pageSize),
        totalPages: Math.ceil(total / Number(pageSize))
      };
    } catch (error) {
      logger.error('获取通话记录失败:', error.message);
      throw error;
    }
  }

  static async getCallStats(params: { start_time?: string; end_time?: string; room_id?: string }): Promise<CallStats> {
    try {
      const { start_time, end_time, room_id } = params;
      
      let whereClause = 'WHERE status = ?';
      const paramsArray: any[] = ['ended'];
      
      if (start_time) {
        whereClause += ' AND started_at >= ?';
        paramsArray.push(start_time);
      }
      
      if (end_time) {
        whereClause += ' AND started_at <= ?';
        paramsArray.push(end_time);
      }
      
      if (room_id) {
        whereClause += ' AND (caller_id = ? OR callee_id = ?)';
        paramsArray.push(room_id, room_id);
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
        paramsArray
      );
      
      const stats = statsRows[0];
      const totalCalls = stats.total_calls || 0;
      const answeredCalls = stats.answered_calls || 0;
      
      return {
        total_calls: totalCalls,
        total_duration_sec: stats.total_duration_sec || 0,
        answered_calls: answeredCalls,
        missed_calls: stats.missed_calls || 0,
        rejected_calls: stats.rejected_calls || 0,
        avg_duration_sec: Math.round(stats.avg_duration_sec || 0),
        answer_rate: totalCalls > 0 ? parseFloat((answeredCalls / totalCalls).toFixed(2)) : 0
      };
    } catch (error) {
      logger.error('获取通话统计失败:', error.message);
      throw error;
    }
  }

  static validateCallerType(callerType: string): boolean {
    return ['room', 'front_desk', 'ai', 'app'].includes(callerType);
  }

  static validateCalleeType(calleeType: string): boolean {
    return ['room', 'front_desk', 'ai', 'app'].includes(calleeType);
  }

  static getValidOutboundCallerTypes(): string[] {
    return ['front_desk', 'ai', 'app'];
  }
}
