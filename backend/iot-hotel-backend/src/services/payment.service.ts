import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { v4 as uuidv4 } from 'uuid';

export interface Payment extends RowDataPacket {
  id: number;
  payment_no: string;
  order_type: string;
  order_id: number;
  amount: number;
  payment_method: string;
  status: string;
  transaction_no: string;
  paid_at: Date;
  description: string;
  created_at: Date;
  updated_at: Date;
}

export interface PaymentListResponse {
  list: Payment[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

export class PaymentService {
  static async getPayments(params: {
    page?: number;
    pageSize?: number;
    status?: string;
    order_type?: string;
    hotelId: number;
  }): Promise<PaymentListResponse> {
    try {
      const { page = 1, pageSize = 10, status, order_type, hotelId } = params;
      const offset = (Number(page) - 1) * Number(pageSize);

      let whereClause = 'WHERE hotel_id = ?';
      const paramsArray: any[] = [hotelId];

      if (status) {
        whereClause += ' AND p.status = ?';
        paramsArray.push(status);
      }

      if (order_type) {
        whereClause += ' AND p.order_type = ?';
        paramsArray.push(order_type);
      }
      const [totalRows] = await pool.query<RowDataPacket[]>(`SELECT COUNT(*) as total FROM payments p ${whereClause}`, paramsArray);
      const total = (totalRows[0] as any).total;

      const [rows] = await pool.query<RowDataPacket[]>(
        `SELECT p.*, b.guest_name, b.guest_phone, b.room_id, r.room_number, r.room_type, r.room_name, h.hotel_name
         FROM payments p
         LEFT JOIN bookings b ON p.order_type = 'booking' AND p.order_id = b.id
         LEFT JOIN rooms r ON b.room_id = r.id
         LEFT JOIN hotels h ON b.hotel_id = h.id
         ${whereClause} 
         ORDER BY p.id DESC LIMIT ? OFFSET ?`,
        [...paramsArray, Number(pageSize), offset]
      );

      return {
        list: rows as Payment[],
        total,
        page: Number(page),
        pageSize: Number(pageSize),
        totalPages: Math.ceil(total / Number(pageSize))
      };
    } catch (error) {
      logger.error('获取支付列表失败:', error);
      throw new Error('获取支付列表失败');
    }
  }

  static async getPaymentById(id: number, hotelId: number): Promise<Payment | null> {
    try {
      const [rows] = await pool.query<RowDataPacket[]>('SELECT * FROM payments WHERE id = ? AND hotel_id = ?', [id, hotelId]);
      return (rows[0] as Payment) || null;
    } catch (error) {
      logger.error('获取支付详情失败:', error);
      throw new Error('获取支付详情失败');
    }
  }

  static async createPayment(data: {
    hotel_id: number;
    order_type: string;
    order_id: number;
    amount: number;
    payment_method: string;
    description: string;
  }): Promise<{ id: number; payment_no: string }> {
    try {
      const { hotel_id, order_type, order_id, amount, payment_method, description } = data;

      const paymentNo = `PAY${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${uuidv4().slice(0, 8).toUpperCase()}`;

      const [result] = await pool.query<ResultSetHeader>(
        'INSERT INTO payments (hotel_id, payment_no, order_type, order_id, amount, payment_method, status, description) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [hotel_id, paymentNo, order_type, order_id, amount, payment_method, 'pending', description]
      );

      return {
        id: result.insertId,
        payment_no: paymentNo
      };
    } catch (error) {
      logger.error('创建支付订单失败:', error);
      throw new Error('创建支付订单失败');
    }
  }

  static async payPayment(id: number, hotelId: number, transaction_no: string): Promise<boolean> {
    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();

      // 1. 获取支付记录以确定 order_type 和 order_id
      const [rows] = await connection.query<RowDataPacket[]>('SELECT * FROM payments WHERE id = ? AND hotel_id = ?', [id, hotelId]);
      if (rows.length === 0) {
        await connection.rollback();
        return false;
      }
      const payment = rows[0] as Payment;

      // 2. 更新支付状态
      const [result] = await connection.query<ResultSetHeader>(
        'UPDATE payments SET status = ?, transaction_no = ?, paid_at = CURRENT_TIMESTAMP WHERE id = ? AND hotel_id = ?',
        ['paid', transaction_no, id, hotelId]
      );

      if (result.affectedRows === 0) {
        await connection.rollback();
        return false;
      }

      // 3. 根据 order_type 更新关联表的状态
      if (payment.order_type === 'booking') {
        await connection.query('UPDATE bookings SET status = ? WHERE id = ? AND hotel_id = ?', ['confirmed', payment.order_id, hotelId]);

        const [bookingRows] = await connection.query<RowDataPacket[]>(
          'SELECT room_id FROM bookings WHERE id = ? AND hotel_id = ?',
          [payment.order_id, hotelId]
        );
        if (bookingRows.length > 0) {
          const roomId = (bookingRows[0] as any).room_id;
          if (roomId) {
            await connection.query('UPDATE rooms SET room_status = ? WHERE id = ?', ['reserved', roomId]);
          }
        }
      } else if (payment.order_type === 'delivery') {
        await connection.query('UPDATE delivery_orders SET status = ? WHERE id = ? AND hotel_id = ?', ['paid', payment.order_id, hotelId]);
      } else if (payment.order_type === 'maintenance') {
        await connection.query('UPDATE maintenance_tickets SET status = ? WHERE id = ? AND hotel_id = ?', ['paid', payment.order_id, hotelId]);
      }

      await connection.commit();
      return true;
    } catch (error) {
      await connection.rollback();
      logger.error('支付失败:', error);
      throw new Error('支付失败');
    } finally {
      connection.release();
    }
  }
}
