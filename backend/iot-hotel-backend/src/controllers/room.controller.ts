import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import { RoomService } from '../services/room.service';
import { HotelService } from '../services/hotel.service';
import logger from '../utils/logger';
import { isSystemRole } from '../utils/role';

export const get = async (req: AuthRequest, res: Response) => {
  try {
    let hotelId = req.user?.hotel_id;
    
    if (isSystemRole(req.user?.role)) {
      const queryHotelId = req.query.hotel_id;
      if (queryHotelId) {
        hotelId = parseInt(queryHotelId as string);
      } else if (!hotelId) {
        const hotels = await HotelService.getAllHotels();
        hotelId = hotels[0]?.id;
      }
    } else if (req.user?.role === 'staff' || req.user?.role === 'manager') {
      const [hotelRows]: any = await (await import('../config/database')).default.execute(
        'SELECT hotel_id FROM user_hotels WHERE user_id = ? LIMIT 1',
        [req.user?.id]
      );
      if (hotelRows.length > 0) {
        hotelId = hotelRows[0].hotel_id;
      }
      const queryHotelId = req.query.hotel_id;
      if (queryHotelId) {
        hotelId = parseInt(queryHotelId as string);
      }
    }

    if (!hotelId) {
      return res.status(401).json(errorResponse('未授权'));
    }

    const { page = 1, pageSize = 10, status, type, floor, groupBy } = req.query;
    
    if (groupBy === 'floor') {
      const data = await RoomService.getRoomsByFloor(hotelId);
      return res.json(successResponse(data, '按楼层获取房间成功'));
    }

    const data = await RoomService.getRooms({
      page: Number(page),
      pageSize: Number(pageSize),
      status: status as string,
      type: type as string,
      floor: floor ? Number(floor) : undefined,
      hotelId
    });
    
    res.json(successResponse(data, '获取房间列表成功'));
  } catch (error: any) {
    logger.error('获取房间列表失败:', error);
    res.status(500).json(errorResponse(error.message || '获取房间列表失败'));
  }
};

export const getById = async (req: AuthRequest, res: Response) => {
  try {
    let hotelId = req.user?.hotel_id;
    if (isSystemRole(req.user?.role)) {
      const queryHotelId = req.query.hotel_id || req.body.hotel_id;
      if (queryHotelId) {
        hotelId = parseInt(queryHotelId as string);
      }
    }
    if (!hotelId) {
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
    logger.error('获取房间详情失败:', error);
    res.status(500).json(errorResponse(error.message || '获取房间详情失败'));
  }
};

export const create = async (req: AuthRequest, res: Response) => {
  try {
    let hotelId = req.user?.hotel_id;
    if (isSystemRole(req.user?.role)) {
      hotelId = req.body.hotel_id;
    }
    if (!hotelId) {
      return res.status(401).json(errorResponse('未授权，必须提供酒店 ID'));
    }

    const id = await RoomService.createRoom({ ...req.body, hotel_id: hotelId });
    res.json(successResponse({ id }, '创建房间成功'));
  } catch (error: any) {
    logger.error('创建房间失败:', error);
    res.status(error.status || 500).json(errorResponse(error.message || '创建房间失败'));
  }
};

export const update = async (req: AuthRequest, res: Response) => {
  try {
    let hotelId = req.user?.hotel_id;
    if (isSystemRole(req.user?.role)) {
      hotelId = req.body.hotel_id || req.query.hotel_id;
    }
    if (!hotelId) {
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
    logger.error('更新房间失败:', error);
    res.status(500).json(errorResponse(error.message || '更新房间失败'));
  }
};

export const remove = async (req: AuthRequest, res: Response) => {
  try {
    let hotelId = req.user?.hotel_id;
    if (isSystemRole(req.user?.role)) {
      hotelId = req.query.hotel_id || req.body.hotel_id;
    }
    if (!hotelId) {
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
    logger.error('删除房间失败:', error);
    res.status(500).json(errorResponse(error.message || '删除房间失败'));
  }
};

export const updateStatus = async (req: AuthRequest, res: Response) => {
  try {
    let hotelId = req.user?.hotel_id;
    if (isSystemRole(req.user?.role)) {
      hotelId = req.body.hotel_id || req.query.hotel_id;
    }
    if (!hotelId) {
      return res.status(401).json(errorResponse('未授权'));
    }

    const id = Number(req.params.id);
    const { status } = req.body;
    
    if (!status) {
      return res.status(400).json(errorResponse('缺少状态参数'));
    }

    const success = await RoomService.updateRoom(id, hotelId, { room_status: status } as any);
    
    if (!success) {
      res.status(404).json(errorResponse('房间不存在'));
      return;
    }
    
    res.json(successResponse(null, '更新房间状态成功'));
  } catch (error: any) {
    logger.error('更新房间状态失败:', error);
    res.status(500).json(errorResponse(error.message || '更新房间状态失败'));
  }
};
