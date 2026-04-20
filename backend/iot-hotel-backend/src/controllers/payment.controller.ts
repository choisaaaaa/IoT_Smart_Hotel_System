import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import { PaymentService } from '../services/payment.service';
import logger from '../utils/logger';
import pool from '../config/database';
import { isCustomer, isGuest } from '../utils/role';

export const get = async (req: AuthRequest, res: Response) => {
  try {
    const { page = 1, pageSize = 10, status, order_type } = req.query;
    
    // 普通用户只能看到自己的支付（通过关联的预订）
    const userId = (isCustomer(req.user?.role) || isGuest(req.user?.role)) ? req.user.id : undefined;
    
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
    const userId = (isCustomer(req.user?.role) || isGuest(req.user?.role)) ? req.user.id : undefined;
    
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

    if (!hotel_id) {hotel_id = req.user?.hotel_id || 1;}

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
    if (!hotelId) {hotelId = req.user?.hotel_id || 1;}

    logger.info(`[Payment Pay] Processing payment with id: ${numericId}, hotelId: ${hotelId}, payerPhone: ${req.user?.phone}`);
    // 传递当前登录用户的手机号作为支付者手机号
    const payerPhone = req.user?.phone || req.user?.username;
    const success = await PaymentService.payPayment(numericId, hotelId, transaction_no || 'T' + Date.now(), payerPhone);
    logger.info(`[Payment Pay] Payment result: ${success}`);
    if (!success) {
      return res.status(404).json(errorResponse('支付失败或支付记录不存在'));
    }
    res.json(successResponse(null, '支付成功'));
  } catch (error) {
    logger.error('支付失败:', error.message);
    const businessErrors = ['余额不足', '支付记录不存在'];
    const isBusinessError = businessErrors.some(e => error.message?.includes(e));
    if (isBusinessError) {
      res.status(400).json(errorResponse(error.message));
    } else {
      res.status(500).json(errorResponse('支付失败'));
    }
  }
};

export const getRevenueStats = async (req: AuthRequest, res: Response) => {
  try {
    const hotelId = req.user?.hotel_id || 1;

    const [todayRows]: any = await pool.query(
      `SELECT COALESCE(SUM(amount), 0) as today_revenue
       FROM payments
       WHERE hotel_id = ? AND status = 'paid'
       AND DATE(paid_at) = CURDATE()`,
      [hotelId]
    );

    const [monthRows]: any = await pool.query(
      `SELECT COALESCE(SUM(amount), 0) as month_revenue
       FROM payments
       WHERE hotel_id = ? AND status = 'paid'
       AND YEAR(paid_at) = YEAR(CURDATE()) AND MONTH(paid_at) = MONTH(CURDATE())`,
      [hotelId]
    );

    const [pendingRows]: any = await pool.query(
      `SELECT COUNT(*) as pending_bills
       FROM payments
       WHERE hotel_id = ? AND status = 'pending'`,
      [hotelId]
    );

    const [trendRows]: any = await pool.query(
      `SELECT DATE(paid_at) as date, COALESCE(SUM(amount), 0) as revenue
       FROM payments
       WHERE hotel_id = ? AND status = 'paid'
       AND paid_at >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
       GROUP BY DATE(paid_at)
       ORDER BY date ASC`,
      [hotelId]
    );

    const [breakdownRows]: any = await pool.query(
      `SELECT order_type, COALESCE(SUM(amount), 0) as amount
       FROM payments
       WHERE hotel_id = ? AND status = 'paid'
       AND YEAR(paid_at) = YEAR(CURDATE()) AND MONTH(paid_at) = MONTH(CURDATE())
       GROUP BY order_type`,
      [hotelId]
    );

    const incomeBreakdown: Record<string, number> = {};
    for (const row of breakdownRows) {
      incomeBreakdown[row.order_type || 'other'] = Number(row.amount);
    }

    const revenueTrend = Array.isArray(trendRows)
      ? trendRows.map((row: any) => ({ date: row.date, revenue: Number(row.revenue) }))
      : [];

    res.json(successResponse({
      today_revenue: Number(todayRows[0]?.today_revenue || 0),
      month_revenue: Number(monthRows[0]?.month_revenue || 0),
      pending_bills: Number(pendingRows[0]?.pending_bills || 0),
      revenue_trend: revenueTrend,
      income_breakdown: incomeBreakdown,
    }, '获取营收统计成功'));
  } catch (error) {
    logger.error('获取营收统计失败:', error.message);
    res.status(500).json(errorResponse('获取营收统计失败'));
  }
};
