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
    userId?: number;
  }): Promise<PaymentListResponse> {
    try {
      const { page = 1, pageSize = 10, status, order_type, hotelId, userId } = params;
      const offset = (Number(page) - 1) * Number(pageSize);

      let whereClause = 'WHERE p.hotel_id = ?';
      const paramsArray: any[] = [hotelId];

      // 如果指定了userId，只返回该用户的支付（通过关联的预订）
      if (userId) {
        whereClause += ' AND b.user_id = ?';
        paramsArray.push(userId);
      }

      if (status) {
        whereClause += ' AND p.status = ?';
        paramsArray.push(status);
      }

      if (order_type) {
        whereClause += ' AND p.order_type = ?';
        paramsArray.push(order_type);
      }
      
      // COUNT查询也需要JOIN bookings表（如果有userId条件）
      let countQuery = `SELECT COUNT(*) as total FROM payments p`;
      if (userId) {
        countQuery += ` LEFT JOIN bookings b ON p.order_type = 'booking' AND p.order_id = b.id`;
      }
      countQuery += ` ${whereClause}`;
      
      const [totalRows] = await pool.query<RowDataPacket[]>(countQuery, paramsArray);
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
      logger.error('获取支付列表失败:', error.message);
      throw new Error('获取支付列表失败');
    }
  }

  static async getPaymentById(id: number, hotelId: number, userId?: number): Promise<Payment | null> {
    try {
      let query = 'SELECT p.* FROM payments p';
      const params: any[] = [id, hotelId];
      
      // 如果指定了userId，需要关联bookings表验证权限
      if (userId) {
        query += ' LEFT JOIN bookings b ON p.order_type = \'booking\' AND p.order_id = b.id WHERE p.id = ? AND p.hotel_id = ? AND b.user_id = ?';
        params.push(userId);
      } else {
        query += ' WHERE p.id = ? AND p.hotel_id = ?';
      }
      
      const [rows] = await pool.query<RowDataPacket[]>(query, params);
      return (rows[0] as Payment) || null;
    } catch (error) {
      logger.error('获取支付详情失败:', error.message);
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
      logger.error('创建支付订单失败:', error.message);
      throw new Error('创建支付订单失败');
    }
  }

  static async payPayment(id: number, hotelId: number, transaction_no: string, payerPhone?: string): Promise<boolean> {
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

      // 3. 如果是余额支付，扣除会员余额
      if (payment.payment_method === 'balance') {
        // 使用支付者手机号（当前登录用户），而不是入住人手机号
        let deductPhone: string | null = payerPhone || null;

        // 如果没有提供支付者手机号，则尝试从预订关联的用户获取
        if (!deductPhone && (payment.order_type === 'booking' || payment.order_type === 'booking_extend')) {
          const [bookingRows] = await connection.query<RowDataPacket[]>(
            `SELECT b.user_id, u.phone as user_phone, b.guest_phone 
             FROM bookings b 
             LEFT JOIN users u ON b.user_id = u.id 
             WHERE b.id = ?`,
            [payment.order_id]
          );
          if (bookingRows.length > 0) {
            // 优先使用预订关联的用户手机号，而不是入住人手机号
            deductPhone = (bookingRows[0] as any).user_phone || (bookingRows[0] as any).guest_phone;
          }
        } else if (!deductPhone && payment.order_type === 'delivery') {
          const [deliveryRows] = await connection.query<RowDataPacket[]>(
            `SELECT u.phone as user_phone, b.guest_phone 
             FROM delivery_orders d 
             LEFT JOIN bookings b ON d.booking_id = b.id 
             LEFT JOIN users u ON b.user_id = u.id 
             WHERE d.id = ?`,
            [payment.order_id]
          );
          if (deliveryRows.length > 0) {
            deductPhone = (deliveryRows[0] as any).user_phone || (deliveryRows[0] as any).guest_phone;
          }
        }

        if (deductPhone) {
          const [memberRows] = await connection.query<RowDataPacket[]>(
            'SELECT id, balance FROM members WHERE phone = ?',
            [deductPhone]
          );
          if (memberRows.length > 0) {
            const member = memberRows[0] as any;
            if (Number(member.balance) < Number(payment.amount)) {
              await connection.rollback();
              throw new Error(`余额不足，当前余额 ¥${member.balance}，需支付 ¥${payment.amount}`);
            }
            const [updateResult] = await connection.query(
              'UPDATE members SET balance = balance - ? WHERE id = ? AND balance >= ?',
              [payment.amount, member.id, payment.amount]
            );
            if ((updateResult as any).affectedRows === 0) {
              await connection.rollback();
              throw new Error(`余额扣款失败，可能余额不足或并发操作冲突，当前余额 ¥${member.balance}，需支付 ¥${payment.amount}`);
            }
            logger.info(`余额支付扣款成功: 手机号=${deductPhone}, 扣款=${payment.amount}`);
          } else {
            await connection.rollback();
            throw new Error(`会员不存在: 手机号 ${deductPhone}，无法使用余额支付`);
          }
        } else {
          await connection.rollback();
          throw new Error('无法确定支付者手机号，余额支付失败');
        }
      }

      // 4. 处理预订相关的积分和优惠券扣除（仅在支付成功时执行）
      if (payment.order_type === 'booking' || payment.order_type === 'booking_extend') {
        // 获取预订信息（包含优惠券和积分信息）
        const [bookingRows] = await connection.query<RowDataPacket[]>(
          `SELECT b.coupon_id, b.used_points, b.guest_phone, b.user_id, u.phone as user_phone
           FROM bookings b
           LEFT JOIN users u ON b.user_id = u.id
           WHERE b.id = ?`,
          [payment.order_id]
        );
        
        if (bookingRows.length > 0) {
          const booking = bookingRows[0] as any;
          
          // 确定权益扣除对象：使用 guest_phone（与价格计算时一致）
          const pointsDeductPhone = booking.guest_phone;
          
          // 4.1 扣除积分（如果有，仅 booking 类型需要在此扣减；booking_extend 已在 extendStay 中扣减）
          if (payment.order_type === 'booking' && booking.used_points > 0 && pointsDeductPhone) {
            const [memberRows] = await connection.query<RowDataPacket[]>(
              'SELECT id, points FROM members WHERE phone = ?',
              [pointsDeductPhone]
            );
            if (memberRows.length > 0) {
              const member = memberRows[0] as any;
              if (Number(member.points) >= Number(booking.used_points)) {
                const [updateResult] = await connection.query(
                  'UPDATE members SET points = points - ? WHERE id = ? AND points >= ?',
                  [booking.used_points, member.id, booking.used_points]
                );
                if ((updateResult as any).affectedRows === 0) {
                  logger.warn(`积分扣减并发冲突: 手机号=${pointsDeductPhone}, 积分=${booking.used_points}`);
                } else {
                  logger.info(`支付时扣除积分: 手机号=${pointsDeductPhone}, 积分=${booking.used_points}`);
                }
              } else {
                logger.warn(`积分不足: 手机号=${pointsDeductPhone}, 可用=${member.points}, 需要=${booking.used_points}`);
              }
            }
          }
          
          // 4.2 标记优惠券为已使用（如果有，仅 booking 类型需要在此标记；booking_extend 已在 extendStay 中标记）
          if (payment.order_type === 'booking' && booking.coupon_id) {
            // 验证优惠券是否属于该会员
            const [couponRows] = await connection.query<RowDataPacket[]>(
              `SELECT mc.id FROM member_coupons mc
               JOIN members m ON mc.member_id = m.id
               WHERE mc.id = ? AND m.phone = ? AND mc.status = 'unused'`,
              [booking.coupon_id, pointsDeductPhone]
            );
            if (couponRows.length > 0) {
              await connection.query(
                'UPDATE member_coupons SET status = "used", used_at = CURRENT_TIMESTAMP WHERE id = ?',
                [booking.coupon_id]
              );
              logger.info(`支付时使用优惠券: coupon_id=${booking.coupon_id}, 手机号=${pointsDeductPhone}`);
            } else {
              logger.warn(`优惠券不可用: coupon_id=${booking.coupon_id}, 手机号=${pointsDeductPhone}`);
            }
          }
        }
        
        // 4.3 更新预订状态
        if (payment.order_type === 'booking') {
          await connection.query('UPDATE bookings SET status = ? WHERE id = ?', ['confirmed', payment.order_id]);

          const [roomRows] = await connection.query<RowDataPacket[]>(
            'SELECT room_id FROM bookings WHERE id = ?',
            [payment.order_id]
          );
          if (roomRows.length > 0) {
            const roomId = (roomRows[0] as any).room_id;
            if (roomId) {
              await connection.query('UPDATE rooms SET room_status = ? WHERE id = ?', ['reserved', roomId]);
            }
          }
        }
      } else if (payment.order_type === 'delivery') {
        await connection.query('UPDATE delivery_orders SET status = ? WHERE id = ?', ['paid', payment.order_id]);
      } else if (payment.order_type === 'maintenance') {
        await connection.query('UPDATE maintenance_tickets SET status = ? WHERE id = ?', ['paid', payment.order_id]);
      }

      await connection.commit();
      return true;
    } catch (error) {
      await connection.rollback();
      logger.error('支付失败:', error.message);
      if (error.message?.includes('余额不足')) {
        throw error;
      }
      throw new Error('支付失败');
    } finally {
      connection.release();
    }
  }
}
