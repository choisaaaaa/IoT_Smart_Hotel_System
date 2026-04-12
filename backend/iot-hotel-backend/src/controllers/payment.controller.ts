import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import { PaymentService } from '../services/payment.service';
import logger from '../utils/logger';
import pool from '../config/database';
import { isCustomer } from '../utils/role';

export const get = async (req: AuthRequest, res: Response) => {
  try {
    const { page = 1, pageSize = 10, status, order_type } = req.query;
    
    // 普通用户只能看到自己的支付（通过关联的预订）
    const userId = isCustomer(req.user?.role) ? req.user.id : undefined;
    
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
    logger.error('获取支付列表失败:', error.message);
    res.status(500).json(errorResponse('获取支付列表失败'));
  }
};

export const getById = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    
    // 普通用户只能看到自己的支付
    const userId = isCustomer(req.user?.role) ? req.user.id : undefined;
    
    const payment = await PaymentService.getPaymentById(Number(id), req.user?.hotel_id || 1, userId);
    if (!payment) {
      return res.status(404).json(errorResponse('支付记录不存在'));
    }
    res.json(successResponse(payment, '获取支付详情成功'));
  } catch (error) {
    logger.error('获取支付详情失败:', error.message);
    res.status(500).json(errorResponse('获取支付详情失败'));
  }
};

export const create = async (req: AuthRequest, res: Response) => {
  try {
    const { order_type, order_id, amount, payment_method, description } = req.body;
    let hotel_id = 0;

    logger.info(`[Payment Create] Request body: ${JSON.stringify(req.body)}, user hotel_id: ${req.user?.hotel_id}`);

    if (order_type === 'booking' && order_id) {
      const numericOrderId = Number(order_id);
      logger.info(`[Payment Create] Looking up booking with id: ${numericOrderId}`);
      const [rows] = await pool.query('SELECT hotel_id FROM bookings WHERE id = ?', [numericOrderId]);
      logger.info(`[Payment Create] Booking lookup result: ${JSON.stringify(rows)}`);
      if (Array.isArray(rows) && rows.length > 0) {
        hotel_id = (rows[0] as any).hotel_id || 1;
      }
    } else if (order_type === 'delivery' && order_id) {
      const [rows] = await pool.query('SELECT hotel_id FROM delivery_orders WHERE id = ?', [Number(order_id)]);
      if (Array.isArray(rows) && rows.length > 0) {
        hotel_id = (rows[0] as any).hotel_id || 1;
      }
    } else if (order_type === 'maintenance' && order_id) {
      const [rows] = await pool.query('SELECT hotel_id FROM maintenance_tickets WHERE id = ?', [Number(order_id)]);
      if (Array.isArray(rows) && rows.length > 0) {
        hotel_id = (rows[0] as any).hotel_id || 1;
      }
    }

    if (!hotel_id) hotel_id = req.user?.hotel_id || 1;

    logger.info(`[Payment Create] Creating payment with hotel_id: ${hotel_id}, order_id: ${Number(order_id)}`);
    const result = await PaymentService.createPayment({
      hotel_id,
      order_type,
      order_id: Number(order_id),
      amount: Number(amount),
      payment_method,
      description
    });
    logger.info(`[Payment Create] Payment created: ${JSON.stringify(result)}`);
    res.json(successResponse(result, '创建支付订单成功'));
  } catch (error) {
    logger.error('创建支付订单失败:', error.message);
    res.status(500).json(errorResponse('创建支付订单失败'));
  }
};

export const pay = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { transaction_no } = req.body;

    logger.info(`[Payment Pay] Request params: ${JSON.stringify(req.params)}, body: ${JSON.stringify(req.body)}, user hotel_id: ${req.user?.hotel_id}`);

    const numericId = Number(id);
    logger.info(`[Payment Pay] Looking up payment with id: ${numericId}`);
    const [rows] = await pool.query('SELECT hotel_id FROM payments WHERE id = ?', [numericId]);
    logger.info(`[Payment Pay] Payment lookup result: ${JSON.stringify(rows)}`);
    
    let hotelId = 0;
    if (Array.isArray(rows) && rows.length > 0) {
      hotelId = (rows[0] as any).hotel_id || 1;
    }
    if (!hotelId) hotelId = req.user?.hotel_id || 1;

    logger.info(`[Payment Pay] Processing payment with id: ${numericId}, hotelId: ${hotelId}`);
    const success = await PaymentService.payPayment(numericId, hotelId, transaction_no || 'T' + Date.now());
    logger.info(`[Payment Pay] Payment result: ${success}`);
    if (!success) {
      return res.status(404).json(errorResponse('支付失败或支付记录不存在'));
    }
    res.json(successResponse(null, '支付成功'));
  } catch (error) {
    logger.error('支付失败:', error.message);
    res.status(500).json(errorResponse('支付失败'));
  }
};
