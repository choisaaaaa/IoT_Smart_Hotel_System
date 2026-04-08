import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import { RoomService } from '../services/room.service';
import logger from '../utils/logger';

export const get = async (req: AuthRequest, res: Response) => {
  try {
    let hotelId = req.user?.hotel_id;
    
    // 如果是 system 角色且没有 hotel_id，默认查看第一个酒店的数据或全部
    if (req.user?.role === 'system' && !hotelId) {
      hotelId = 1; 
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
    if (req.user?.role === 'system' && !hotelId) {
      hotelId = 1;
    }
    if (!hotelId) return res.status(401).json(errorResponse('未授权'));

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
    if (req.user?.role === 'system' && !hotelId) {
      hotelId = req.body.hotel_id || 1;
    }
    if (!hotelId) return res.status(401).json(errorResponse('未授权'));

    const id = await RoomService.createRoom({ ...req.body, hotel_id: hotelId });
    res.json(successResponse({ id }, '创建房间成功'));
  } catch (error: any) {
    logger.error('创建房间失败:', error);
    res.status(500).json(errorResponse(error.message || '创建房间失败'));
  }
};

export const update = async (req: AuthRequest, res: Response) => {
  try {
    let hotelId = req.user?.hotel_id;
    if (req.user?.role === 'system' && !hotelId) {
      hotelId = req.body.hotel_id || 1;
    }
    if (!hotelId) return res.status(401).json(errorResponse('未授权'));

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
    if (req.user?.role === 'system' && !hotelId) {
      hotelId = 1; // 这是一个简化的处理，实际应从查询参数或上下文获取
    }
    if (!hotelId) return res.status(401).json(errorResponse('未授权'));

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
