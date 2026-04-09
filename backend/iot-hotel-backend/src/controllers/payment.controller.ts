import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import { PaymentService } from '../services/payment.service';
import logger from '../utils/logger';

export const get = async (req: AuthRequest, res: Response) => {
  try {
    const { page = 1, pageSize = 10, status, order_type } = req.query;
    const data = await PaymentService.getPayments({
      page: Number(page),
      pageSize: Number(pageSize),
      status: status as string,
      order_type: order_type as string,
      hotelId: req.user?.hotel_id || 0
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
    const payment = await PaymentService.getPaymentById(Number(id), req.user?.hotel_id || 0);
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
    const result = await PaymentService.createPayment({
      hotel_id: req.user?.hotel_id || 0,
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
    const success = await PaymentService.payPayment(Number(id), req.user?.hotel_id || 0, transaction_no || 'T' + Date.now());
    if (!success) {
      return res.status(404).json(errorResponse('支付失败或支付记录不存在'));
    }
    res.json(successResponse(null, '支付成功'));
  } catch (error) {
    logger.error('支付失败:', error);
    res.status(500).json(errorResponse('支付失败'));
  }
};