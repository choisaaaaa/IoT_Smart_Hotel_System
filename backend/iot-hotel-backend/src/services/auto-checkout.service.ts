import pool, { RowDataPacket } from '../config/database';
import logger from '../utils/logger';

const CHECK_INTERVAL_MS = 60 * 1000;

class AutoCheckoutService {
  private timer: NodeJS.Timeout | null = null;
  private isPolling: boolean = false;

  start() {
    logger.info(`[AutoCheckout] 启动自动退房服务，间隔 ${CHECK_INTERVAL_MS / 1000}s`);
    this.run();
  }

  private async run() {
    await this.pollAutoCheckout();
    this.timer = setTimeout(() => this.run(), CHECK_INTERVAL_MS);
  }

  stop() {
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
      logger.info('[AutoCheckout] 停止自动退房服务');
    }
  }

  async pollAutoCheckout() {
    if (this.isPolling) {return;}
    this.isPolling = true;
    try {
      const [expiredBookings] = await pool.query<RowDataPacket[]>(
        `SELECT b.id, b.booking_number, b.room_id, b.user_id, b.guest_name, b.guest_phone,
                b.check_out_date, b.auto_checkout_at, r.room_number
         FROM bookings b
         LEFT JOIN rooms r ON b.room_id = r.id
         WHERE b.status = 'checked_in' 
         AND b.auto_checkout_at IS NOT NULL 
         AND b.auto_checkout_at < NOW()`
      );

      if (expiredBookings.length === 0) {return;}

      logger.info(`[AutoCheckout] 发现 ${expiredBookings.length} 个需要自动退房的订单`);

      for (const booking of expiredBookings) {
        await this.processAutoCheckout(booking);
      }
    } catch (error) {
      logger.error('[AutoCheckout] 轮询自动退房失败:', error.message);
    } finally {
      this.isPolling = false;
    }
  }

  async processAutoCheckout(booking: any) {
    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();

      await connection.query(
        `UPDATE bookings SET status = 'checked_out', check_out_time = NOW(), lock_version = lock_version + 1 
         WHERE id = ? AND status = 'checked_in'`,
        [booking.id]
      );

      await connection.query(
        `UPDATE guests SET check_out_time = NOW() WHERE booking_id = ? AND check_out_time IS NULL`,
        [booking.id]
      );

      await connection.query(
        `UPDATE rooms SET room_status = 'cleaning', locked_by_booking = NULL, locked_at = NULL 
         WHERE id = ?`,
        [booking.room_id]
      );

      await connection.commit();
      logger.info(`[AutoCheckout] 已自动退房: ${booking.booking_number}, 房间 ${booking.room_number} 进入待打扫状态`);
    } catch (error) {
      await connection.rollback();
      logger.error(`[AutoCheckout] 自动退房失败: ${booking.booking_number} - ${error.message}`);
    } finally {
      connection.release();
    }
  }
}

export const autoCheckoutService = new AutoCheckoutService();
