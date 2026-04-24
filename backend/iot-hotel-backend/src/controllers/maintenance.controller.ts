import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { v4 as uuidv4 } from 'uuid';
import { isCustomer, isGuest } from '../utils/role';
import mqttService from '../services/mqtt.service';

export const get = async (req: AuthRequest, res: Response) => {
  try {
    const { page = 1, pageSize = 10, status, fault_type, priority } = req.query;
    const offset = (Number(page) - 1) * Number(pageSize);
    const hotelId = req.user?.hotel_id;
    const userRole = req.user?.role;
    const userId = req.user?.id;
    
    let whereClause = 'WHERE 1=1';
    const params: any[] = [];
    
    // 如果是顾客/游客角色，只能查看自己房间的工单
    if (isCustomer(userRole) || isGuest(userRole)) {
      // 获取顾客当前入住的房间
      const [bookingRows] = await pool.query<RowDataPacket[]>(
        `SELECT room_id FROM bookings 
         WHERE user_id = ? AND status = 'checked_in'
         LIMIT 1`,
        [userId]
      );
      
      if (bookingRows.length === 0) {
        // 顾客没有入住，返回空列表
        return res.json(successResponse({
          list: [],
          total: 0,
          page: Number(page),
          pageSize: Number(pageSize),
          totalPages: 0
        }, '获取报修工单列表成功'));
      }
      
      const roomId = (bookingRows[0] as any).room_id;
      whereClause += ' AND m.room_id = ?';
      params.push(roomId);
    } else if (hotelId) {
      whereClause += ' AND r.hotel_id = ?';
      params.push(hotelId);
    }

    if (status) {
      whereClause += ' AND m.status = ?';
      params.push(status);
    }
    
    if (fault_type) {
      whereClause += ' AND m.fault_type = ?';
      params.push(fault_type);
    }
    
    if (priority) {
      whereClause += ' AND m.priority = ?';
      params.push(priority);
    }
    
    const [totalRows] = await pool.query<RowDataPacket[]>(
      `SELECT COUNT(*) as total FROM maintenance_tickets m LEFT JOIN rooms r ON m.room_id = r.id ${whereClause}`, 
      params
    );
    const total = (totalRows[0] as any).total;
    
    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT m.*, r.room_number FROM maintenance_tickets m LEFT JOIN rooms r ON m.room_id = r.id ${whereClause} ORDER BY m.id DESC LIMIT ? OFFSET ?`,
      [...params, Number(pageSize), offset]
    );
    
    res.json(successResponse({
      list: rows,
      total,
      page: Number(page),
      pageSize: Number(pageSize),
      totalPages: Math.ceil(total / Number(pageSize))
    }, '获取报修工单列表成功'));
  } catch (error) {
    logger.error('获取报修工单列表失败:', error.message);
    res.status(500).json(errorResponse('获取报修工单列表失败'));
  }
};

export const getById = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const hotelId = req.user?.hotel_id;
    const userRole = req.user?.role;
    const userId = req.user?.id;

    let query = 'SELECT m.*, r.room_number FROM maintenance_tickets m LEFT JOIN rooms r ON m.room_id = r.id WHERE m.id = ?';
    const params: any[] = [id];

    // 如果是顾客/游客角色，只能查看自己房间的工单
    if (isCustomer(userRole) || isGuest(userRole)) {
      const [bookingRows] = await pool.query<RowDataPacket[]>(
        `SELECT room_id FROM bookings 
         WHERE user_id = ? AND status = 'checked_in'
         LIMIT 1`,
        [userId]
      );
      
      if (bookingRows.length === 0) {
        res.status(403).json(errorResponse('您当前没有入住记录'));
        return;
      }
      
      const roomId = (bookingRows[0] as any).room_id;
      query += ' AND m.room_id = ?';
      params.push(roomId);
    } else if (hotelId) {
      query += ' AND r.hotel_id = ?';
      params.push(hotelId);
    }
    
    const [rows] = await pool.query<RowDataPacket[]>(query, params);
    
    if (rows.length === 0) {
      res.status(404).json(errorResponse('报修工单不存在或无权访问'));
      return;
    }
    
    res.json(successResponse(rows[0], '获取报修工单详情成功'));
  } catch (error) {
    logger.error('获取报修工单详情失败:', error.message);
    res.status(500).json(errorResponse('获取报修工单详情失败'));
  }
};

export const create = async (req: AuthRequest, res: Response) => {
  try {
    const { room_id, booking_id, guest_id, fault_type, fault_description, photos, priority } = req.body;
    
    if (!room_id) {
      res.status(400).json(errorResponse('缺少 room_id 参数'));
      return;
    }

    // 关键修复：客房服务只对前台已确认入住用户开放
    const [checkinRows] = await pool.query<RowDataPacket[]>(
      `SELECT id, status, hotel_id FROM bookings 
       WHERE room_id = ? AND status = 'checked_in'
       LIMIT 1`,
      [room_id]
    );

    if (checkinRows.length === 0) {
      const userRole = req.user?.role;
      if (userRole === 'customer' || userRole === 'guest') {
        res.status(400).json(errorResponse('该房间当前未办理入住，请先确认您的入住房间号'));
        return;
      }
    }

    const currentBooking = checkinRows[0] as any;

    const ticketNo = `MT${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${uuidv4().slice(0, 8).toUpperCase()}`;
    
    const [result] = await pool.query<ResultSetHeader>(
      'INSERT INTO maintenance_tickets (ticket_no, room_id, booking_id, guest_id, fault_type, fault_description, photos, priority, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [ticketNo, room_id, booking_id || currentBooking.id, guest_id || null, fault_type, fault_description, JSON.stringify(photos || []), priority, 'pending']
    );

    if (room_id) {
      await pool.query('UPDATE rooms SET room_status = ? WHERE id = ?', ['maintenance', room_id]);
    }

    // 获取房间号用于 MQTT 通知
    const [roomRows] = await pool.query<RowDataPacket[]>(
      'SELECT room_number, hotel_id FROM rooms WHERE id = ?',
      [room_id]
    );
    const roomNumber = (roomRows[0] as any)?.room_number || room_id;
    const hotelId = (roomRows[0] as any)?.hotel_id;

    // 构建 MQTT 通知消息
    const mqttMessage = {
      type: 'maintenance_ticket_created',
      ticket_id: result.insertId,
      ticket_no: ticketNo,
      room_id: room_id,
      room_number: roomNumber,
      hotel_id: hotelId,
      fault_type: fault_type,
      fault_description: fault_description,
      priority: priority,
      status: 'pending',
      created_at: new Date().toISOString(),
      message: `房间 ${roomNumber} 报修: ${fault_type} - ${fault_description?.substring(0, 30) || '无描述'}`,
      announce: true,
    };

    // 发送 MQTT 通知到前台
    const mqttTopic = `hotel/${hotelId}/reception/announce`;
    const mqttResult = await mqttService.publish(mqttTopic, mqttMessage);

    // 记录详细日志
    logger.info(`[维修工单] 创建成功 - 工单号: ${ticketNo}, 房间: ${roomNumber}, 类型: ${fault_type}`);
    logger.info(`[MQTT通知] 主题: ${mqttTopic}, 发送结果: ${mqttResult ? '成功' : '失败'}`);
    logger.info(`[MQTT消息内容] ${JSON.stringify(mqttMessage)}`);

    res.json(successResponse({ id: result.insertId, ticket_no: ticketNo }, '创建报修工单成功'));
  } catch (error) {
    logger.error('创建报修工单失败:', error.message);
    res.status(500).json(errorResponse('创建报修工单失败'));
  }
};

export const assign = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { repairer } = req.body;

    // BUG-046修复：校验工单当前状态，只有pending状态可分配
    const [ticketRows] = await pool.query<RowDataPacket[]>(
      'SELECT status FROM maintenance_tickets WHERE id = ?', [id]
    );
    if (ticketRows.length === 0) {
      return res.status(404).json(errorResponse('报修工单不存在'));
    }
    const currentStatus = (ticketRows[0] as any).status;
    if (currentStatus !== 'pending') {
      return res.status(400).json(errorResponse(`当前工单状态为"${currentStatus}"，只有"pending"状态可分配维修人员`));
    }
    if (!repairer) {
      return res.status(400).json(errorResponse('缺少维修人员参数(repairer)'));
    }
    
    const [result] = await pool.query<ResultSetHeader>(
      'UPDATE maintenance_tickets SET status = ?, repairer = ?, assigned_at = CURRENT_TIMESTAMP WHERE id = ?',
      ['assigned', repairer, id]
    );
    
    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('报修工单不存在'));
      return;
    }
    
    res.json(successResponse(null, '分配维修人员成功'));
  } catch (error) {
    logger.error('分配维修人员失败:', error.message);
    res.status(500).json(errorResponse('分配维修人员失败'));
  }
};

export const updateStatus = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    const hotelId = req.user?.hotel_id;

    if (!['pending', 'assigned', 'processing', 'completed'].includes(status)) {
      res.status(400).json(errorResponse('无效的工单状态'));
      return;
    }

    // BUG-046修复：校验工单状态转换合法性
    const validTransitions: Record<string, string[]> = {
      pending: ['assigned', 'processing', 'completed'],
      assigned: ['processing', 'completed'],
      processing: ['completed'],
      completed: []
    };
    const [currentTicketRows] = await pool.query<RowDataPacket[]>(
      'SELECT status FROM maintenance_tickets WHERE id = ?', [id]
    );
    if (currentTicketRows.length === 0) {
      return res.status(404).json(errorResponse('报修工单不存在'));
    }
    const currentStatus = (currentTicketRows[0] as any).status;
    const allowed = validTransitions[currentStatus] || [];
    if (!allowed.includes(status)) {
      return res.status(400).json(errorResponse(`不允许从"${currentStatus}"状态转换到"${status}"状态`));
    }

    // 权限检查
    let checkQuery = 'SELECT m.id FROM maintenance_tickets m LEFT JOIN rooms r ON m.room_id = r.id WHERE m.id = ?';
    const checkParams: any[] = [id];
    if (hotelId) {
      checkQuery += ' AND r.hotel_id = ?';
      checkParams.push(hotelId);
    }
    const [checkRows] = await pool.query<RowDataPacket[]>(checkQuery, checkParams);
    if (checkRows.length === 0) {
      res.status(404).json(errorResponse('报修工单不存在或无权访问'));
      return;
    }

    const [result] = await pool.query<ResultSetHeader>(
      'UPDATE maintenance_tickets SET status = ? WHERE id = ?',
      [status, id]
    );

    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('更新工单状态失败'));
      return;
    }

    // 获取工单详情用于 MQTT 通知
    const [ticketRows] = await pool.query<RowDataPacket[]>(
      `SELECT m.*, r.room_number, r.hotel_id 
       FROM maintenance_tickets m 
       LEFT JOIN rooms r ON m.room_id = r.id 
       WHERE m.id = ?`,
      [id]
    );

    if (ticketRows.length > 0) {
      const ticket = ticketRows[0] as any;
      const statusText = { pending: '待处理', assigned: '已分配', processing: '处理中', completed: '已完成' }[status] || status;

      // 构建 MQTT 通知消息
      const mqttMessage = {
        type: 'maintenance_ticket_updated',
        ticket_id: id,
        ticket_no: ticket.ticket_no,
        room_id: ticket.room_id,
        room_number: ticket.room_number,
        hotel_id: ticket.hotel_id,
        status: status,
        status_text: statusText,
        updated_at: new Date().toISOString(),
        message: `工单 ${ticket.ticket_no} 状态更新为: ${statusText}`,
        announce: status === 'completed',
      };

      // 发送 MQTT 通知
      const mqttTopic = `hotel/${ticket.hotel_id}/reception/announce`;
      await mqttService.publish(mqttTopic, mqttMessage);

      logger.info(`[维修工单] 状态更新 - 工单号: ${ticket.ticket_no}, 新状态: ${statusText}`);
    }

    res.json(successResponse(null, '更新工单状态成功'));
  } catch (error) {
    logger.error('更新工单状态失败:', error.message);
    res.status(500).json(errorResponse('更新工单状态失败'));
  }
};

export const complete = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { repair_description, repair_cost } = req.body;
    const hotelId = req.user?.hotel_id;

    let checkQuery = 'SELECT m.room_id, m.status FROM maintenance_tickets m LEFT JOIN rooms r ON m.room_id = r.id WHERE m.id = ?';
    const checkParams: any[] = [id];
    if (hotelId) {
      checkQuery += ' AND r.hotel_id = ?';
      checkParams.push(hotelId);
    }
    
    const [ticketRows] = await pool.query<RowDataPacket[]>(checkQuery, checkParams);

    if (ticketRows.length === 0) {
      res.status(404).json(errorResponse('报修工单不存在或无权访问'));
      return;
    }

    // BUG-046修复：校验工单状态，只有assigned/processing状态可完成
    const currentStatus = (ticketRows[0] as any).status;
    if (!['assigned', 'processing'].includes(currentStatus)) {
      return res.status(400).json(errorResponse(`当前工单状态为"${currentStatus}"，只有"assigned"或"processing"状态可标记完成`));
    }

    const roomId = (ticketRows[0] as any).room_id;
    
    const [result] = await pool.query<ResultSetHeader>(
      'UPDATE maintenance_tickets SET status = ?, repair_description = ?, repair_cost = ?, completed_at = CURRENT_TIMESTAMP WHERE id = ?',
      ['completed', repair_description, repair_cost, id]
    );
    
    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('报修工单不存在'));
      return;
    }

    if (roomId) {
      const [pendingTickets] = await pool.query<RowDataPacket[]>(
        'SELECT COUNT(*) as cnt FROM maintenance_tickets WHERE room_id = ? AND status IN (?, ?, ?)',
        [roomId, 'pending', 'assigned', 'processing']
      );
      if ((pendingTickets[0] as any).cnt === 0) {
        // 检查房间是否有正在入住的预订
        const [bookingRows] = await pool.query<RowDataPacket[]>(
          'SELECT id FROM bookings WHERE room_id = ? AND status = ? LIMIT 1',
          [roomId, 'checked_in']
        );
        // 如果有入住记录，恢复为occupied（入住中），否则变为available（空闲）
        const newStatus = bookingRows.length > 0 ? 'occupied' : 'available';
        await pool.query('UPDATE rooms SET room_status = ? WHERE id = ? AND room_status = ?', [newStatus, roomId, 'maintenance']);
      }
    }
    
    res.json(successResponse(null, '完成报修工单成功'));
  } catch (error) {
    logger.error('完成报修工单失败:', error.message);
    res.status(500).json(errorResponse('完成报修工单失败'));
  }
};

export const remove = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const hotelId = req.user?.hotel_id;

    // 先检查工单是否存在并校验权限
    let checkQuery = 'SELECT m.status FROM maintenance_tickets m LEFT JOIN rooms r ON m.room_id = r.id WHERE m.id = ?';
    const checkParams: any[] = [id];
    if (hotelId) {
      checkQuery += ' AND r.hotel_id = ?';
      checkParams.push(hotelId);
    }
    const [rows] = await pool.query<RowDataPacket[]>(checkQuery, checkParams);

    if (rows.length === 0) {
      res.status(404).json(errorResponse('报修工单不存在或无权访问'));
      return;
    }

    // 检查是否允许删除（只有pending或cancelled状态的工单可以删除）
    const ticketStatus = (rows[0] as any).status;
    if (!['pending', 'cancelled'].includes(ticketStatus)) {
      res.status(400).json(errorResponse(`当前状态(${ticketStatus})的工单不允许删除`));
      return;
    }

    const [result] = await pool.query<ResultSetHeader>(
      'DELETE FROM maintenance_tickets WHERE id = ?',
      [id]
    );

    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('报修工单不存在'));
      return;
    }

    res.json(successResponse(null, '删除报修工单成功'));
  } catch (error) {
    logger.error('删除报修工单失败:', error.message);
    res.status(500).json(errorResponse('删除报修工单失败'));
  }
};