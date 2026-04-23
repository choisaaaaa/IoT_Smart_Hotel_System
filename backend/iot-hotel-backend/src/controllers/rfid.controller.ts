import { Request, Response } from 'express';
import rfidService from '../services/rfid.service';
import pool from '../config/database';
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
      // 明确返回 200 状态码和成功响应
      return res.status(200).json(successResponse(result, '特权卡签发指令已下发'));
    } catch (error) {
      logger.error('Issue privilege card controller error:', error.message);
      // 如果是已知错误，返回 400，否则返回 500
      const statusCode = error.message.includes('Unauthorized') ? 401 : 400;
      return res.status(statusCode).json(errorResponse(error.message || '特权卡签发失败'));
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
      const user = (req as any).user;
      const hotelId = user?.hotel_id;
      const operatorId = user?.id;
      const role = user?.role;
      const { card_uid, status, reason } = req.body;
      
      if (!operatorId) return res.status(401).json(errorResponse('Unauthorized'));
      if (!card_uid || !status) return res.status(400).json(errorResponse('Missing parameters'));

      // 如果是系统管理员，允许跨酒店操作 (传递 hotel_id 为 0 或从 body 获取目标 hotel_id)
      // 这里简化逻辑：如果是系统管理员且 body 没传 hotel_id，则先查出卡片所属酒店
      let targetHotelId = hotelId;
      if (role === 'system_admin') {
        const [card] = await pool.query<any[]>('SELECT hotel_id FROM rfid_cards WHERE card_uid = ?', [card_uid]);
        if (card.length > 0) targetHotelId = card[0].hotel_id;
      }

      const success = await rfidService.updateCardStatus(card_uid, targetHotelId, status, operatorId, reason || '');
      if (success) {
        // 如果是作废操作且提供了设备ID，尝试下发硬件注销指令
        const encoder_id = req.body.encoder_id;
        if (status === 'inactive' && encoder_id) {
          const mqttService = require('../services/mqtt.service').default;
          await mqttService.sendDeviceCommand(
            encoder_id,
            'room_card_op',
            JSON.stringify({ action: 'deactivate', card_uid }),
            user?.username || 'admin'
          );
        }
        res.json(successResponse(null, '卡片状态更新成功'));
      } else {
        res.status(404).json(errorResponse('卡片不存在或无权操作'));
      }
    } catch (error) {
      logger.error('Update card status controller error:', error.message);
      res.status(500).json(errorResponse('状态更新失败'));
    }
  }

  async updateExpiry(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      const hotelId = user?.hotel_id;
      const operatorId = user?.id;
      const role = user?.role;
      const { card_uid, expiry_date } = req.body;
      
      if (!operatorId) return res.status(401).json(errorResponse('Unauthorized'));
      if (!card_uid || !expiry_date) return res.status(400).json(errorResponse('Missing parameters'));

      let targetHotelId = hotelId;
      if (role === 'system_admin') {
        const [card] = await pool.query<any[]>('SELECT hotel_id FROM rfid_cards WHERE card_uid = ?', [card_uid]);
        if (card.length > 0) targetHotelId = card[0].hotel_id;
      }

      const success = await rfidService.updateCardExpiry(card_uid, targetHotelId, expiry_date, operatorId);
      if (success) {
        res.json(successResponse(null, '有效期更新成功'));
      } else {
        res.status(404).json(errorResponse('卡片不存在或无权操作'));
      }
    } catch (error) {
      logger.error('Update card expiry controller error:', error.message);
      res.status(500).json(errorResponse('有效期更新失败'));
    }
  }

  async list(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      
      // 系统管理员可以查看指定酒店或所有卡片
      if (user?.role === 'system_admin' && req.query.hotel_id) {
        hotelId = Number(req.query.hotel_id);
      }

      if (!hotelId && user?.role !== 'system_admin') {
        return res.status(401).json(errorResponse('Unauthorized'));
      }

      const result = await rfidService.getHotelCards(hotelId, req.query);
      res.json(successResponse(result, '获取卡片列表成功'));
    } catch (error) {
      logger.error('List cards controller error:', error.message);
      res.status(500).json(errorResponse('获取列表失败'));
    }
  }

  async getInfo(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      const { card_uid } = req.query;

      if (!card_uid) return res.status(400).json(errorResponse('UID required'));

      // 如果是系统管理员且没传 hotel_id，先查出卡片所属酒店
      if (user?.role === 'system_admin' && (!hotelId || hotelId === 0)) {
        const [card] = await pool.query<any[]>('SELECT hotel_id FROM rfid_cards WHERE card_uid = ?', [card_uid]);
        if (card.length > 0) hotelId = card[0].hotel_id;
      }

      if (!hotelId && user?.role !== 'system_admin') return res.status(401).json(errorResponse('Unauthorized'));

      const info = await rfidService.getCardInfo(card_uid as string, hotelId);
      res.json(successResponse(info, '获取卡片信息成功'));
    } catch (error) {
      logger.error('Get card info controller error:', error.message);
      res.status(500).json(errorResponse('获取信息失败'));
    }
  }

  async getBookingCards(req: Request, res: Response) {
    try {
      const { booking_id } = req.params;
      const user = (req as any).user;
      const hotelId = user?.hotel_id;

      if (!booking_id) return res.status(400).json(errorResponse('Booking ID required'));

      let query = `
        SELECT c.*, r.room_number 
        FROM rfid_cards c
        LEFT JOIN rooms r ON c.room_id = r.id
        WHERE c.booking_id = ?
      `;
      const params: any[] = [booking_id];

      if (hotelId && hotelId !== 0) {
        query += ' AND c.hotel_id = ?';
        params.push(hotelId);
      }

      const [cards] = await pool.query<any[]>(query, params);
      res.json(successResponse(cards, '获取订单房卡列表成功'));
    } catch (error) {
      logger.error('Get booking cards error:', error.message);
      res.status(500).json(errorResponse('获取房卡列表失败'));
    }
  }
}

export default new RFIDController();
