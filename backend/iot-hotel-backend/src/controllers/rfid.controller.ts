import { Request, Response } from 'express';
import rfidService from '../services/rfid.service';
import logger from '../utils/logger';
import { successResponse, errorResponse } from '../types';

class RFIDController {
  async issue(req: Request, res: Response) {
    try {
      const hotelId = (req as any).user?.hotel_id || req.body.hotel_id;
      if (!hotelId) {return res.status(401).json(errorResponse('Unauthorized'));}

      const id = await rfidService.issueCard({ ...req.body, hotel_id: hotelId });
      res.json(successResponse({ id }, '发卡成功'));
    } catch (error) {
      logger.error('Issue card controller error:', error.message);
      res.status(500).json(errorResponse('发卡失败'));
    }
  }

  async issuePrivilege(req: Request, res: Response) {
    try {
      const hotelId = (req as any).user?.hotel_id;
      const operatorId = (req as any).user?.id;
      if (!hotelId || !operatorId) {
        return res.status(401).json(errorResponse('Unauthorized'));
      }

      const result = await rfidService.issuePrivilegeCard(req.body, hotelId, operatorId);
      res.json(successResponse(result, '特权卡签发指令已下发'));
    } catch (error) {
      logger.error('Issue privilege card controller error:', error.message);
      res.status(500).json(errorResponse(error.message || '特权卡签发失败'));
    }
  }

  async getAll(req: Request, res: Response) {
    try {
      const hotelId = (req as any).user?.hotel_id;
      if (!hotelId) {return res.status(401).json(errorResponse('Unauthorized'));}

      const cards = await rfidService.getAllCards(hotelId);
      res.json(successResponse(cards, '获取卡片列表成功'));
    } catch (error) {
      logger.error('Get all cards controller error:', error.message);
      res.status(500).json(errorResponse('获取卡片列表失败'));
    }
  }

  async updateStatus(req: Request, res: Response) {
    try {
      const { card_uid, status } = req.body;
      if (!card_uid || !status) {return res.status(400).json(errorResponse('Missing parameters'));}

      const success = await rfidService.updateCardStatus(card_uid, status);
      if (success) {
        res.json(successResponse(null, '卡片状态更新成功'));
      } else {
        res.status(404).json(errorResponse('卡片不存在'));
      }
    } catch (error) {
      logger.error('Update card status controller error:', error.message);
      res.status(500).json(errorResponse('状态更新失败'));
    }
  }
}

export default new RFIDController();
