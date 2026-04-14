import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';

const PAYMENT_TIMEOUT_MINUTES = 15;
const POLL_INTERVAL_MS = 30 * 1000;

class OrderTimeoutService {
  private timer: NodeJS.Timeout | null = null;
  private isPolling: boolean = false;

  start() {
    logger.info(`[OrderTimeout] 启动订单超时轮询服务，间隔 ${POLL_INTERVAL_MS / 1000}s，超时 ${PAYMENT_TIMEOUT_MINUTES}min`);
    this.run();
  }

  private async run() {
    await this.pollExpiredOrders();
    this.timer = setTimeout(() => this.run(), POLL_INTERVAL_MS);
  }

  stop() {
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
      logger.info('[OrderTimeout] 停止订单超时轮询服务');
    }
  }

  async pollExpiredOrders() {
    if (this.isPolling) return;
    this.isPolling = true;
    try {
      const [expiredBookings] = await pool.query<RowDataPacket[]>(
        `SELECT id, booking_number, room_id, locked_by, guest_phone, coupon_id, used_points FROM bookings 
         WHERE status = 'pending' 
         AND payment_deadline IS NOT NULL 
         AND payment_deadline < NOW()`
      );

      if (expiredBookings.length === 0) return;

      logger.info(`[OrderTimeout] 发现 ${expiredBookings.length} 个超时未支付订单`);

      for (const booking of expiredBookings) {
        await this.cancelExpiredOrder(booking);
      }
    } catch (error) {
      logger.error('[OrderTimeout] 轮询超时订单失败:', error.message);
    } finally {
      this.isPolling = false;
    }
  }

  async cancelExpiredOrder(booking: any) {
    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();

      await connection.query(
        `UPDATE bookings SET status = 'cancelled', cancelled_at = NOW(), lock_version = lock_version + 1 
         WHERE id = ? AND status = 'pending'`,
        [booking.id]
      );

      await connection.query(
        `UPDATE rooms SET room_status = 'available', locked_by_booking = NULL, locked_at = NULL 
         WHERE id = ? AND locked_by_booking = ?`,
        [booking.room_id, booking.id]
      );

      await connection.query(
        `UPDATE payments SET status = 'expired', expired_at = NOW() 
         WHERE order_type = 'booking' AND order_id = ? AND status = 'pending'`,
        [booking.id]
      );

      // 注意：积分和优惠券现在只在支付成功后扣除
      // 超时取消的订单状态为 'pending'，尚未支付，所以不需要回退积分和优惠券

      await connection.query(
        `UPDATE guests SET check_out_time = NOW() WHERE booking_id = ? AND check_out_time IS NULL`,
        [booking.id]
      );

      await connection.commit();
      logger.info(`[OrderTimeout] 已取消超时订单: ${booking.booking_number}, 释放房间: ${booking.room_id}`);
    } catch (error) {
      await connection.rollback();
      logger.error(`[OrderTimeout] 取消超时订单失败: ${booking.booking_number} - ${error.message}`);
    } finally {
      connection.release();
    }
  }

  async lockRoom(roomId: number, bookingId: number, userId: number): Promise<boolean> {
    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();

      const [rooms] = await connection.query<RowDataPacket[]>(
        `SELECT id, room_status, locked_by_booking FROM rooms WHERE id = ? FOR UPDATE`,
        [roomId]
      );

      if (rooms.length === 0) {
        await connection.rollback();
        return false;
      }

      const room = rooms[0];
      if (room.room_status !== 'available' && room.room_status !== 'cleaning') {
        if (room.locked_by_booking && room.locked_by_booking === bookingId) {
          await connection.commit();
          return true;
        }
        await connection.rollback();
        return false;
      }

      await connection.query(
        `UPDATE rooms SET room_status = 'reserved', locked_by_booking = ?, locked_at = NOW() WHERE id = ?`,
        [bookingId, roomId]
      );

      await connection.commit();
      return true;
    } catch (error) {
      await connection.rollback();
      logger.error(`[OrderTimeout] 锁定房间失败: roomId=${roomId} - ${error.message}`);
      return false;
    } finally {
      connection.release();
    }
  }

  async unlockRoom(roomId: number, bookingId: number): Promise<boolean> {
    try {
      await pool.query(
        `UPDATE rooms SET room_status = 'available', locked_by_booking = NULL, locked_at = NULL 
         WHERE id = ? AND locked_by_booking = ?`,
        [roomId, bookingId]
      );
      return true;
    } catch (error) {
      logger.error(`[OrderTimeout] 解锁房间失败: roomId=${roomId} - ${error.message}`);
      return false;
    }
  }

  getPaymentDeadline(): Date {
    const deadline = new Date();
    deadline.setMinutes(deadline.getMinutes() + PAYMENT_TIMEOUT_MINUTES);
    return deadline;
  }

  calculateAutoCheckoutTime(checkOutDate: string): Date {
    const checkout = new Date(checkOutDate);
    checkout.setHours(12, 0, 0, 0);
    return checkout;
  }
}

export const orderTimeoutService = new OrderTimeoutService();
