import { Request, Response } from 'express';
import { RoomTypeService } from '../services/room-type.service';
import logger from '../utils/logger';

type ControllerError = Error & { statusCode?: number };

export class RoomTypeController {
  static async getAllRoomTypes(req: Request, res: Response) {
    try {
      const list = await RoomTypeService.getAllRoomTypes();
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

  static async getRoomTypeById(req: Request, res: Response) {
    try {
      const id = Number(req.params.id);
      const detail = await RoomTypeService.getRoomTypeById(id);
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

  static async createRoomType(req: Request, res: Response) {
    try {
      const id = await RoomTypeService.createRoomType(req.body);
      res.status(201).json({ code: 201, message: '创建房型成功', data: { id } });
    } catch (error) {
      logger.error('创建房型失败:', error);
      const err = error as ControllerError;
      const statusCode = err.statusCode || 500;
      res.status(statusCode).json({ code: statusCode, message: err.message || '创建房型失败' });
    }
  }

  static async updateRoomType(req: Request, res: Response) {
    try {
      const id = Number(req.params.id);
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

  static async deleteRoomType(req: Request, res: Response) {
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
