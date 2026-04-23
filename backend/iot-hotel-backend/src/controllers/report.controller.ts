import { Response } from 'express';
import { AuthRequest } from '../types';
import { successResponse, errorResponse } from '../types';
import pool from '../config/database';
import logger from '../utils/logger';
import { normalizeRole, isSystemAdmin } from '../utils/role';

export const getReports = async (req: AuthRequest, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      return res.status(401).json(errorResponse('未授权'));
    }

    const userRole = normalizeRole(user.role);
    const hotelId = isSystemAdmin(userRole)
      ? (req.query.hotel_id ? parseInt(req.query.hotel_id as string) : null)
      : user.hotel_id;

    if (!hotelId && !isSystemAdmin(userRole)) {
      return res.status(400).json(errorResponse('未绑定酒店'));
    }

    const now = new Date();
    const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;

    const sevenDaysAgo = new Date(now);
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 6);
    const sevenDaysAgoStr = `${sevenDaysAgo.getFullYear()}-${String(sevenDaysAgo.getMonth() + 1).padStart(2, '0')}-${String(sevenDaysAgo.getDate()).padStart(2, '0')}`;

    const firstOfMonth = `${today.substring(0, 7)}-01`;

    const hf = hotelId ? 'AND hotel_id = ?' : '';
    const hfParams = hotelId ? [hotelId] : [];

    const [todayRevenue] = await pool.query<any>(
      `SELECT COALESCE(SUM(total_price), 0) as total FROM bookings WHERE DATE(check_in_time) = ? AND status != 'cancelled' ${hf}`,
      hotelId ? [today, hotelId] : [today]
    );

    const [monthRevenue] = await pool.query<any>(
      `SELECT COALESCE(SUM(total_price), 0) as total FROM bookings WHERE check_in_date >= ? AND status != 'cancelled' ${hf}`,
      hotelId ? [firstOfMonth, hotelId] : [firstOfMonth]
    );

    const [pendingBills] = await pool.query<any>(
      `SELECT COUNT(*) as count FROM bookings WHERE status = 'pending' ${hf}`,
      hfParams
    );

    const [revenueTrend] = await pool.query<any>(
      `SELECT DATE(check_in_time) as date, COALESCE(SUM(total_price), 0) as revenue
       FROM bookings 
       WHERE DATE(check_in_time) >= ? AND status != 'cancelled' ${hf}
       GROUP BY DATE(check_in_time) ORDER BY date`,
      hotelId ? [sevenDaysAgoStr, hotelId] : [sevenDaysAgoStr]
    );

    const trendMap = new Map<string, number>(revenueTrend.map((r: any) => [r.date as string, parseFloat(r.revenue) || 0]));
    const trendData: { date: string; revenue: number }[] = [];
    for (let i = 6; i >= 0; i--) {
      const d = new Date(now);
      d.setDate(d.getDate() - i);
      const dateStr = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
      trendData.push({ date: dateStr, revenue: trendMap.get(dateStr) ?? 0 });
    }

    const [incomeComposition] = await pool.query<any>(
      `SELECT payment_method, COALESCE(SUM(total_price), 0) as total 
       FROM bookings WHERE status != 'cancelled' ${hf}
       GROUP BY payment_method`,
      hfParams
    );

    const paymentMethodMap: Record<string, string> = {
      alipay: '支付宝', wechat: '微信支付', credit_card: '银行卡',
      cash: '现金', front_desk: '前台支付', online: '在线支付', balance: '余额支付'
    };
    const composition = (incomeComposition as any[]).map((item: any) => ({
      name: paymentMethodMap[item.payment_method] || item.payment_method || '其他',
      value: parseFloat(item.total) || 0
    }));

    const hfAlias = hotelId ? 'AND b.hotel_id = ?' : '';
    const hfAliasParams = hotelId ? [hotelId] : [];
    const [billList] = await pool.query<any>(
      `SELECT b.id, b.booking_number as bill_no, b.guest_name, r.room_number, 
              b.total_price as amount, b.payment_method as pay_method, b.status, 
              DATE_FORMAT(b.check_in_time, '%Y-%m-%d') as date
       FROM bookings b 
       LEFT JOIN rooms r ON b.room_id = r.id
       WHERE 1=1 ${hfAlias}
       ORDER BY b.id DESC LIMIT 50`,
      hfAliasParams
    );

    const statusMap: Record<string, string> = {
      pending: '待支付', confirmed: '已支付', checked_in: '已支付',
      checked_out: '已支付', cancelled: '已退款', paid: '已支付', refunded: '已退款'
    };
    const bills = (billList as any[]).map((item: any) => ({
      ...item,
      amount: parseFloat(item.amount) || 0,
      status: statusMap[item.status] || item.status,
      pay_method: paymentMethodMap[item.pay_method] || item.pay_method || '其他'
    }));

    res.json(successResponse({
      today_revenue: parseFloat(todayRevenue[0]?.total) || 0,
      month_revenue: parseFloat(monthRevenue[0]?.total) || 0,
      pending_bills: pendingBills[0]?.count || 0,
      revenue_trend: trendData,
      income_composition: composition,
      bills
    }));
  } catch (error: any) {
    logger.error('获取报表数据失败:', error.message || String(error));
    res.status(500).json(errorResponse('获取报表数据失败: ' + (error.message || String(error))));
  }
};
