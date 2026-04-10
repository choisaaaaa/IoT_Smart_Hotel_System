import { Response } from 'express';
import { AuthRequest } from '../types';
import { RoomTypeService } from '../services/room-type.service';
import logger from '../utils/logger';
import { isSystemRole } from '../utils/role';

type ControllerError = Error & { statusCode?: number };

export class RoomTypeController {
  static async getRoomTypes(req: AuthRequest, res: Response) {
    try {
      let hotelId = req.user?.hotel_id;
      if (isSystemRole(req.user?.role)) {
        const queryHotelId = req.query.hotel_id;
        if (queryHotelId) {
          hotelId = parseInt(queryHotelId as string);
        }
      }
      const list = await RoomTypeService.getRoomTypes(hotelId);
      res.json({
        code: 200,
        message: '获取房型列表成功',
        data: list
      });
    } catch (error) {
      logger.error('获取房型列表失败:', error);
      res.status(500).json({ code: 500, message: '获取房型列表失败' });
    }
  }

  static async getRoomTypeById(req: AuthRequest, res: Response) {
    try {
      const id = Number(req.params.id);
      const hotelId = req.user?.hotel_id;
      const detail = await RoomTypeService.getRoomTypeById(id, hotelId);
      if (detail) {
        res.json({ code: 200, message: '获取房型详情成功', data: detail });
      } else {
        res.status(404).json({ code: 404, message: '房型不存在' });
      }
    } catch (error) {
      logger.error('获取房型详情失败:', error);
      res.status(500).json({ code: 500, message: '获取房型详情失败' });
    }
  }

  static async createRoomType(req: AuthRequest, res: Response) {
    try {
      const hotelId = req.user?.hotel_id;
      const id = await RoomTypeService.createRoomType({ ...req.body, hotel_id: hotelId });
      res.status(201).json({ code: 201, message: '创建房型成功', data: { id } });
    } catch (error) {
      logger.error('创建房型失败:', error);
      const err = error as ControllerError;
      const statusCode = err.statusCode || 500;
      res.status(statusCode).json({ code: statusCode, message: err.message || '创建房型失败' });
    }
  }

  static async updateRoomType(req: AuthRequest, res: Response) {
    try {
      const id = Number(req.params.id);
      const hotelId = req.user?.hotel_id;
      const success = await RoomTypeService.updateRoomType(id, req.body);
      if (success) {
        res.json({ code: 200, message: '更新房型成功' });
      } else {
        res.status(404).json({ code: 404, message: '房型不存在' });
      }
    } catch (error) {
      logger.error('更新房型失败:', error);
      const err = error as ControllerError;
      const statusCode = err.statusCode || 500;
      res.status(statusCode).json({ code: statusCode, message: err.message || '更新房型失败' });
    }
  }

  static async deleteRoomType(req: AuthRequest, res: Response) {
    try {
      const id = Number(req.params.id);
      const success = await RoomTypeService.deleteRoomType(id);
      if (success) {
        res.json({ code: 200, message: '删除房型成功' });
      } else {
        res.status(404).json({ code: 404, message: '房型不存在' });
      }
    } catch (error) {
      logger.error('删除房型失败:', error);
      res.status(500).json({ code: 500, message: '删除房型失败' });
    }
  }
}
