import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';

export interface RFIDCard {
  id: number;
  card_uid: string;
  hotel_id: number;
  booking_id?: number;
  room_id?: number;
  member_id?: number;
  status: 'active' | 'inactive' | 'lost';
  issued_at: Date;
  expires_at?: Date;
}

class RFIDService {
  /**
   * 注册/发卡
   */
  async issueCard(data: Partial<RFIDCard>) {
    const { card_uid, hotel_id, booking_id, room_id, member_id, expires_at } = data;
    try {
      const [result] = await pool.query<ResultSetHeader>(
        `INSERT INTO rfid_cards (card_uid, hotel_id, booking_id, room_id, member_id, expires_at, status, issued_at)
         VALUES (?, ?, ?, ?, ?, ?, 'active', NOW())
         ON DUPLICATE KEY UPDATE 
           hotel_id = VALUES(hotel_id),
           booking_id = VALUES(booking_id),
           room_id = VALUES(room_id),
           member_id = VALUES(member_id),
           expires_at = VALUES(expires_at),
           status = 'active',
           issued_at = NOW()`,
        [card_uid, hotel_id, booking_id || null, room_id || null, member_id || null, expires_at || null]
      );
      return result.insertId;
    } catch (error) {
      logger.error('Issue RFID card error:', error.message);
      throw error;
    }
  }

  /**
   * 验证卡片权限
   */
  async verifyCard(card_uid: string, room_id: number) {
    try {
      const [rows] = await pool.query<RowDataPacket[]>(
        `SELECT * FROM rfid_cards 
         WHERE card_uid = ? AND (room_id = ? OR room_id IS NULL) 
         AND status = 'active' 
         AND (expires_at IS NULL OR expires_at > NOW())`,
        [card_uid, room_id]
      );
      return rows.length > 0;
    } catch (error) {
      logger.error('Verify RFID card error:', error.message);
      throw error;
    }
  }

  /**
   * 获取所有卡片
   */
  async getAllCards(hotelId: number) {
    try {
      const [rows] = await pool.query<RowDataPacket[]>(
        `SELECT c.*, r.room_number, m.name as member_name 
         FROM rfid_cards c
         LEFT JOIN rooms r ON c.room_id = r.id
         LEFT JOIN members m ON c.member_id = m.id
         WHERE c.hotel_id = ?`,
        [hotelId]
      );
      return rows;
    } catch (error) {
      logger.error('Get all RFID cards error:', error.message);
      throw error;
    }
  }

  /**
   * 注销/挂失卡片
   */
  async updateCardStatus(card_uid: string, status: 'inactive' | 'lost') {
    try {
      const [result] = await pool.query<ResultSetHeader>(
        'UPDATE rfid_cards SET status = ? WHERE card_uid = ?',
        [status, card_uid]
      );
      return result.affectedRows > 0;
    } catch (error) {
      logger.error('Update RFID card status error:', error.message);
      throw error;
    }
  }
}

export default new RFIDService();
