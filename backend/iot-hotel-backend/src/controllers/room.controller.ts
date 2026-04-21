import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import { RoomService } from '../services/room.service';
import { HotelService } from '../services/hotel.service';
import logger from '../utils/logger';
import { isSystemAdmin, isStaff, isHotelAdmin, isCustomer, isGuest, CANONICAL_ROLES } from '../utils/role';
import websocketService from '../services/websocket.service';

export const get = async (req: AuthRequest, res: Response) => {
  try {
    // 统一获取 hotelId 的逻辑：优先使用 req.user 中的，如果是系统管理员或顾客则可从 query 覆盖
    let hotelId = req.user?.hotel_id;
    
    // 系统管理员和顾客可以从 query 指定 hotel_id
    if (isSystemAdmin(req.user?.role)) {
      const queryHotelId = req.query.hotel_id;
      if (queryHotelId) {
        hotelId = parseInt(queryHotelId as string);
      } else if (!hotelId || hotelId === 0) {
        hotelId = 1; // 默认指向主门店
      }
    } else if (isCustomer(req.user?.role) || isGuest(req.user?.role)) {
      const queryHotelId = req.query.hotel_id;
      if (queryHotelId) {
        hotelId = parseInt(queryHotelId as string);
      }
    }

    if (hotelId === undefined || hotelId === null || hotelId === 0) {
      if (isCustomer(req.user?.role) || isGuest(req.user?.role)) {
        return res.status(400).json(errorResponse('请提供酒店ID参数(hotel_id)'));
      }
      return res.status(401).json(errorResponse('未授权，无法获取有效的门店 ID'));
    }

    const { page = 1, pageSize = 10, status, type, room_type_id, floor, groupBy } = req.query;
    
    if (groupBy === 'floor') {
      const data = await RoomService.getRoomsByFloor(hotelId);
      return res.json(successResponse(data, '按楼层获取房间成功'));
    }

    const data = await RoomService.getRooms({
      page: Number(page),
      pageSize: Number(pageSize),
      status: status as string,
      type: type as string,
      room_type_id: room_type_id ? Number(room_type_id) : undefined,
      floor: floor ? Number(floor) : undefined,
      hotelId
    });
    
    res.json(successResponse(data, '获取房间列表成功'));
  } catch (error: any) {
    logger.error('获取房间列表失败:', error.message);
    res.status(500).json(errorResponse(error.message || '获取房间列表失败'));
  }
};

export const getById = async (req: AuthRequest, res: Response) => {
  try {
    let hotelId = req.user?.hotel_id;
    if (isSystemAdmin(req.user?.role)) {
      const queryHotelId = req.query.hotel_id || req.body.hotel_id;
      if (queryHotelId) {
        hotelId = parseInt(queryHotelId as string);
      } else if (!hotelId) {
        hotelId = 1;
      }
    } else if (isCustomer(req.user?.role) || isGuest(req.user?.role)) {
      const queryHotelId = req.query.hotel_id || req.body.hotel_id;
      if (queryHotelId) {
        hotelId = parseInt(queryHotelId as string);
      }
    }
    if (hotelId === undefined || hotelId === null) {
      if (isCustomer(req.user?.role) || isGuest(req.user?.role)) {
        return res.status(400).json(errorResponse('请提供酒店ID参数(hotel_id)'));
      }
      return res.status(401).json(errorResponse('未授权'));
    }

    const id = Number(req.params.id);
    const room = await RoomService.getRoomById(id, hotelId);
    
    if (!room) {
      res.status(404).json(errorResponse('房间不存在'));
      return;
    }
    
    res.json(successResponse(room, '获取房间详情成功'));
  } catch (error: any) {
    logger.error('获取房间详情失败:', error.message);
    res.status(500).json(errorResponse(error.message || '获取房间详情失败'));
  }
};

export const create = async (req: AuthRequest, res: Response) => {
  try {
    let hotelId = req.user?.hotel_id;
    if (isSystemAdmin(req.user?.role)) {
      hotelId = req.body.hotel_id || hotelId || 1;
    }
    if (hotelId === undefined || hotelId === null) {
      return res.status(401).json(errorResponse('未授权，必须提供酒店 ID'));
    }

    const id = await RoomService.createRoom({ ...req.body, hotel_id: hotelId });
    res.json(successResponse({ id }, '创建房间成功'));
  } catch (error: any) {
    logger.error('创建房间失败:', error.message);
    res.status(error.status || 500).json(errorResponse(error.message || '创建房间失败'));
  }
};

export const update = async (req: AuthRequest, res: Response) => {
  try {
    let hotelId = req.user?.hotel_id;
    if (isSystemAdmin(req.user?.role)) {
      hotelId = req.body.hotel_id || req.query.hotel_id || hotelId || 1;
    }
    if (hotelId === undefined || hotelId === null) {
      return res.status(401).json(errorResponse('未授权'));
    }

    const id = Number(req.params.id);
    const success = await RoomService.updateRoom(id, hotelId, req.body);
    
    if (!success) {
      res.status(404).json(errorResponse('房间不存在'));
      return;
    }
    
    res.json(successResponse(null, '更新房间成功'));
  } catch (error: any) {
    logger.error('更新房间失败:', error.message);
    res.status(500).json(errorResponse(error.message || '更新房间失败'));
  }
};

export const remove = async (req: AuthRequest, res: Response) => {
  try {
    let hotelId = req.user?.hotel_id;
    if (isSystemAdmin(req.user?.role)) {
      hotelId = req.query.hotel_id || req.body.hotel_id || hotelId || 1;
    }
    if (hotelId === undefined || hotelId === null) {
      return res.status(401).json(errorResponse('未授权'));
    }

    const id = Number(req.params.id);
    const success = await RoomService.deleteRoom(id, hotelId);
    
    if (!success) {
      res.status(404).json(errorResponse('房间不存在'));
      return;
    }
    
    res.json(successResponse(null, '删除房间成功'));
  } catch (error: any) {
    logger.error('删除房间失败:', error.message);
    res.status(500).json(errorResponse(error.message || '删除房间失败'));
  }
};

export const updateStatus = async (req: AuthRequest, res: Response) => {
  try {
    let hotelId = req.user?.hotel_id;
    if (isSystemAdmin(req.user?.role)) {
      hotelId = req.body.hotel_id || req.query.hotel_id || hotelId || 1;
    } else if (isStaff(req.user?.role) || isHotelAdmin(req.user?.role)) {
      const [hotelRows]: any = await (await import('../config/database')).default.execute(
        'SELECT hotel_id FROM user_hotels WHERE user_id = ? LIMIT 1',
        [req.user?.id]
      );
      if (hotelRows.length > 0) {
        hotelId = hotelRows[0].hotel_id;
      }
    }
    if (hotelId === undefined || hotelId === null) {
      return res.status(401).json(errorResponse('未授权'));
    }

    const id = Number(req.params.id);
    const { status } = req.body;
    
    if (!status) {
      return res.status(400).json(errorResponse('缺少状态参数'));
    }

    let success = await RoomService.updateRoomStatus(id, status, hotelId);

    if (!success) {
      success = await RoomService.updateRoomStatus(id, status);
    }
    
    if (!success) {
      res.status(404).json(errorResponse('房间不存在'));
      return;
    }
    
    // 广播房间状态变更给该酒店的所有前台客户端
    try {
      const io = websocketService.getIO();
      if (io) {
        const roomUpdateData = {
          room_id: id,
          room_status: status,
          hotel_id: hotelId,
          timestamp: new Date().toISOString()
        };
        // 发送到酒店前台房间
        io.to(`front_desk_hotel_${hotelId}`).emit('room_status_update', roomUpdateData);
        logger.info(`房间状态更新已广播: 房间ID=${id}, 状态=${status}, 酒店ID=${hotelId}`);
      }
    } catch (wsError) {
      logger.warn('WebSocket广播房间状态更新失败:', wsError.message);
    }
    
    res.json(successResponse({ room_id: id, room_status: status }, '更新房间状态成功'));
  } catch (error: any) {
    logger.error('更新房间状态失败:', error.message);
    res.status(500).json(errorResponse(error.message || '更新房间状态失败'));
  }
};

/**
 * 获取顾客当前入住的房间信息
 */
export const getGuestRoom = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.id;
    const userPhone = req.user?.phone;
    if (!userId) {
      return res.status(401).json(errorResponse('未授权'));
    }

    const pool = (await import('../config/database')).default;
    
    // 查询用户当前有效的入住记录（优先通过user_id，其次通过guest_phone）
    let bookings: any[] = [];
    
    if (userId) {
      const [rows]: any = await pool.execute(
        `SELECT b.id as booking_id, b.room_id, b.hotel_id, r.room_number, r.room_type, r.room_name, r.floor
         FROM bookings b
         JOIN rooms r ON b.room_id = r.id
         WHERE b.user_id = ? AND b.status IN ('checked_in', 'confirmed')
         AND b.check_in_date <= NOW() AND b.check_out_date >= NOW()
         ORDER BY b.check_in_date DESC
         LIMIT 1`,
        [userId]
      );
      bookings = rows;
    }

    if (bookings.length === 0 && userPhone) {
      const [rows]: any = await pool.execute(
        `SELECT b.id as booking_id, b.room_id, b.hotel_id, r.room_number, r.room_type, r.room_name, r.floor
         FROM bookings b
         JOIN rooms r ON b.room_id = r.id
         WHERE b.guest_phone = ? AND b.status IN ('checked_in', 'confirmed')
         AND b.check_in_date <= NOW() AND b.check_out_date >= NOW()
         ORDER BY b.check_in_date DESC
         LIMIT 1`,
        [userPhone]
      );
      bookings = rows;
    }

    if (bookings.length === 0) {
      return res.status(404).json(errorResponse('当前没有入住记录'));
    }

    res.json(successResponse(bookings[0], '获取房间信息成功'));
  } catch (error: any) {
    logger.error('获取顾客房间信息失败:', error.message);
    res.status(500).json(errorResponse(error.message || '获取房间信息失败'));
  }
};

/**
 * 获取顾客房间的设备列表
 */
export const getGuestRoomDevices = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.id;
    const userPhone = req.user?.phone;
    const roomId = req.params.id;
    logger.info(`[getGuestRoomDevices] 用户ID: ${userId}, 房间ID: ${roomId}`);
    
    if (!userId) {
      return res.status(401).json(errorResponse('未授权'));
    }

    const pool = (await import('../config/database')).default;
    
    // 验证该房间是否属于当前用户的有效入住（优先通过user_id，其次通过guest_phone）
    let bookings: any[] = [];
    
    if (userId) {
      const [rows]: any = await pool.execute(
        `SELECT b.id FROM bookings b
         WHERE b.user_id = ? AND b.room_id = ? 
         AND b.status IN ('checked_in', 'confirmed')
         AND b.check_in_date <= NOW() AND b.check_out_date >= NOW()
         LIMIT 1`,
        [userId, roomId]
      );
      bookings = rows;
    }

    if (bookings.length === 0 && userPhone) {
      const [rows]: any = await pool.execute(
        `SELECT b.id FROM bookings b
         WHERE b.guest_phone = ? AND b.room_id = ? 
         AND b.status IN ('checked_in', 'confirmed')
         AND b.check_in_date <= NOW() AND b.check_out_date >= NOW()
         LIMIT 1`,
        [userPhone, roomId]
      );
      bookings = rows;
    }

    if (bookings.length === 0) {
      return res.status(403).json(errorResponse('无权访问该房间的设备'));
    }

    // 查询房间设备
    const [devices]: any = await pool.execute(
      `SELECT d.id, d.device_id, d.device_name, d.device_type, d.device_status, d.firmware_version, d.last_seen
       FROM devices d
       INNER JOIN rooms r ON r.room_id = d.id
       WHERE r.id = ?`,
      [roomId]
    );

    res.json(successResponse(devices, '获取房间设备成功'));
  } catch (error: any) {
    logger.error('获取房间设备失败:', error.message);
    res.status(500).json(errorResponse(error.message || '获取房间设备失败'));
  }
};

/**
 * 获取顾客当前入住房间的设备列表
 */
export const getMyRoomDevices = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.id;
    const userPhone = req.user?.phone;
    logger.info(`[getMyRoomDevices] 用户ID: ${userId}, 手机号: ${userPhone}`);
    if (!userId) {
      return res.status(401).json(errorResponse('未授权'));
    }

    const pool = (await import('../config/database')).default;
    
    // 查询用户当前有效的入住记录（优先通过user_id，其次通过guest_phone）
    let bookings: any[] = [];
    
    if (userId) {
      const [rows]: any = await pool.execute(
        `SELECT b.id as booking_id, b.room_id, b.hotel_id, r.room_number, r.room_type, r.room_name, r.floor
         FROM bookings b
         JOIN rooms r ON b.room_id = r.id
         WHERE b.user_id = ? AND b.status IN ('checked_in', 'confirmed')
         AND b.check_in_date <= NOW() AND b.check_out_date >= NOW()
         ORDER BY b.check_in_date DESC
         LIMIT 1`,
        [userId]
      );
      bookings = rows;
    }

    if (bookings.length === 0 && userPhone) {
      const [rows]: any = await pool.execute(
        `SELECT b.id as booking_id, b.room_id, b.hotel_id, r.room_number, r.room_type, r.room_name, r.floor
         FROM bookings b
         JOIN rooms r ON b.room_id = r.id
         WHERE b.guest_phone = ? AND b.status IN ('checked_in', 'confirmed')
         AND b.check_in_date <= NOW() AND b.check_out_date >= NOW()
         ORDER BY b.check_in_date DESC
         LIMIT 1`,
        [userPhone]
      );
      bookings = rows;
    }

    if (bookings.length === 0) {
      return res.status(404).json(errorResponse('当前没有入住记录'));
    }

    const roomId = bookings[0].room_id;

    // 查询房间设备
    const [devices]: any = await pool.execute(
      `SELECT d.id, d.device_id, d.device_name, d.device_type, d.device_status, d.firmware_version, d.last_seen
       FROM devices d
       INNER JOIN rooms r ON r.room_id = d.id
       WHERE r.id = ?`,
      [roomId]
    );

    res.json(successResponse(devices, '获取房间设备成功'));
  } catch (error: any) {
    logger.error('获取房间设备失败:', error.message);
    res.status(500).json(errorResponse(error.message || '获取房间设备失败'));
  }
};
