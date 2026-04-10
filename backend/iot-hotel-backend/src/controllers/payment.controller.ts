import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import { PaymentService } from '../services/payment.service';
import logger from '../utils/logger';

export const get = async (req: AuthRequest, res: Response) => {
  try {
    const { page = 1, pageSize = 10, status, order_type } = req.query;
    
    // 普通用户只能看到自己的支付（通过关联的预订）
    const userId = req.user?.role === 'user' ? req.user.id : undefined;
    
    const data = await PaymentService.getPayments({
      page: Number(page),
      pageSize: Number(pageSize),
      status: status as string,
      order_type: order_type as string,
      hotelId: req.user?.hotel_id || 1,
      userId: userId
    });
    res.json(successResponse(data, '获取支付列表成功'));
  } catch (error) {
    logger.error('获取支付列表失败:', error);
    res.status(500).json(errorResponse('获取支付列表失败'));
  }
};

export const getById = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    
    // 普通用户只能看到自己的支付
    const userId = req.user?.role === 'user' ? req.user.id : undefined;
    
    const payment = await PaymentService.getPaymentById(Number(id), req.user?.hotel_id || 1, userId);
    if (!payment) {
      return res.status(404).json(errorResponse('支付记录不存在'));
    }
    res.json(successResponse(payment, '获取支付详情成功'));
  } catch (error) {
    logger.error('获取支付详情失败:', error);
    res.status(500).json(errorResponse('获取支付详情失败'));
  }
};

export const create = async (req: AuthRequest, res: Response) => {
  try {
    const { order_type, order_id, amount, payment_method, description } = req.body;
    let hotel_id = req.user?.hotel_id || 0;

    if (!hotel_id && order_type === 'booking' && order_id) {
      const pool = (await import('../config/database')).default;
      const [rows] = await pool.query('SELECT hotel_id FROM bookings WHERE id = ?', [Number(order_id)]);
      if (Array.isArray(rows) && rows.length > 0) {
        hotel_id = (rows[0] as any).hotel_id || 1;
      }
    }

    if (!hotel_id) hotel_id = 1;

    const result = await PaymentService.createPayment({
      hotel_id,
      order_type,
      order_id: Number(order_id),
      amount: Number(amount),
      payment_method,
      description
    });
    res.json(successResponse(result, '创建支付订单成功'));
  } catch (error) {
    logger.error('创建支付订单失败:', error);
    res.status(500).json(errorResponse('创建支付订单失败'));
  }
};

export const pay = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { transaction_no } = req.body;
    let hotelId = req.user?.hotel_id || 0;

    if (!hotelId) {
      const pool = (await import('../config/database')).default;
      const [rows] = await pool.query('SELECT hotel_id FROM payments WHERE id = ?', [Number(id)]);
      if (Array.isArray(rows) && rows.length > 0) {
        hotelId = (rows[0] as any).hotel_id || 1;
      }
    }

    const success = await PaymentService.payPayment(Number(id), hotelId || 1, transaction_no || 'T' + Date.now());
    if (!success) {
      return res.status(404).json(errorResponse('支付失败或支付记录不存在'));
    }
    res.json(successResponse(null, '支付成功'));
  } catch (error) {
    logger.error('支付失败:', error);
    res.status(500).json(errorResponse('支付失败'));
  }
};