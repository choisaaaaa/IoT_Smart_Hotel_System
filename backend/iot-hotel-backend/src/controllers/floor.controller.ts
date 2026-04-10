import { Request, Response } from 'express';
import { FloorService } from '../services/floor.service';
import { successResponse, errorResponse } from '../types';
import logger from '../utils/logger';

export class FloorController {
  static async getFloors(req: Request, res: Response) {
    try {
      const list = await FloorService.getFloors();
      res.json(successResponse(list, '获取楼层列表成功'));
    } catch (error: any) {
      logger.error('获取楼层列表失败:', error);
      res.status(error.status || 500).json(errorResponse(error.message || '获取楼层列表失败'));
    }
  }

  static async getFloorById(req: Request, res: Response) {
    try {
      const id = Number(req.params.id);
      const floor = await FloorService.getFloorById(id);
      if (floor) {
        res.json(successResponse(floor, '获取楼层详情成功'));
      } else {
        res.status(404).json(errorResponse('楼层不存在'));
      }
    } catch (error: any) {
      logger.error('获取楼层详情失败:', error);
      res.status(error.status || 500).json(errorResponse(error.message || '获取楼层详情失败'));
    }
  }

  static async createFloor(req: Request, res: Response) {
    try {
      const id = await FloorService.createFloor(req.body);
      res.status(201).json(successResponse({ id }, '创建楼层成功'));
    } catch (error: any) {
      logger.error('创建楼层失败:', error);
      res.status(error.status || 500).json(errorResponse(error.message || '创建楼层失败'));
    }
  }

  static async updateFloor(req: Request, res: Response) {
    try {
      const id = Number(req.params.id);
      const success = await FloorService.updateFloor(id, req.body);
      if (success) {
        res.json(successResponse(null, '更新楼层成功'));
      } else {
        res.status(404).json(errorResponse('楼层不存在'));
      }
    } catch (error: any) {
      logger.error('更新楼层失败:', error);
      res.status(error.status || 500).json(errorResponse(error.message || '更新楼层失败'));
    }
  }

  static async deleteFloor(req: Request, res: Response) {
    try {
      const id = Number(req.params.id);
      const success = await FloorService.deleteFloor(id);
      if (success) {
        res.json(successResponse(null, '删除楼层成功'));
      } else {
        res.status(404).json(errorResponse('楼层不存在'));
      }
    } catch (error: any) {
      logger.error('删除楼层失败:', error);
      res.status(error.status || 500).json(errorResponse(error.message || '删除楼层失败'));
    }
  }
}
