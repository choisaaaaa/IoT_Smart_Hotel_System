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
  card_type: 'guest' | 'master' | 'floor' | 'staff';
  issued_at: Date;
  expires_at?: Date;
}

class RFIDService {
  /**
   * 注册/发卡
   */
  async issueCard(data: Partial<RFIDCard>) {
    const { card_uid, hotel_id, booking_id, room_id, member_id, expires_at, card_type } = data;
    try {
      const [result] = await pool.query<ResultSetHeader>(
        `INSERT INTO rfid_cards (card_uid, hotel_id, booking_id, room_id, member_id, expires_at, status, card_type, issued_at)
         VALUES (?, ?, ?, ?, ?, ?, 'active', ?, NOW())
         ON DUPLICATE KEY UPDATE 
           hotel_id = VALUES(hotel_id),
           booking_id = VALUES(booking_id),
           room_id = VALUES(room_id),
           member_id = VALUES(member_id),
           expires_at = VALUES(expires_at),
           card_type = VALUES(card_type),
           status = 'active',
           issued_at = NOW()`,
        [card_uid, hotel_id, booking_id || null, room_id || null, member_id || null, expires_at || null, card_type || 'guest']
      );
      return result.insertId;
    } catch (error) {
      logger.error('Issue RFID card error:', error.message);
      throw error;
    }
  }

  /**
   * 签发特权卡 (万能卡、楼层卡、员工卡)
   */
  async issuePrivilegeCard(data: any, hotelId: number, operatorId: number) {
    const { card_type, holder_name, holder_id, floors, rooms, expiry_date, remark, encoder_id } = data;
    
    try {
      // 1. 发送 MQTT 指令给发卡器
      // 实际生产中这里需要通过 MQTT service 发送指令，等待硬件反馈 card_uid
      // 这里模拟下发指令过程
      const mockCardUid = `PRIV_${Date.now().toString(36).toUpperCase()}`;
      
      // 2. 记录到 rfid_cards 表
      await pool.query<ResultSetHeader>(
        `INSERT INTO rfid_cards (card_uid, hotel_id, card_type, expires_at, status, issued_at)
         VALUES (?, ?, ?, ?, 'active', NOW())`,
        [mockCardUid, hotelId, card_type, expiry_date]
      );

      // 3. 记录到生命周期日志 (使用之前迁移新增的表)
      await pool.query(
        `INSERT INTO card_lifecycle_logs (card_uid, hotel_id, action_type, operator_id, target_user_id, notes)
         VALUES (?, ?, 'issue', ?, ?, ?)`,
        [mockCardUid, hotelId, 'issue', operatorId, null, `签发特权卡: ${card_type}, 持卡人: ${holder_name}, 备注: ${remark}`]
      );

      // 4. 如果是楼层卡或员工卡，记录权限策略
      if (card_type === 'floor' || card_type === 'staff') {
        const scope = card_type === 'floor' ? 'floor' : 'room_list';
        const scopeValue = card_type === 'floor' ? JSON.stringify(floors) : JSON.stringify(rooms);
        
        await pool.query(
          `INSERT INTO staff_access_policies (hotel_id, user_id, access_scope, scope_value, is_active)
           VALUES (?, ?, ?, ?, 1)
           ON DUPLICATE KEY UPDATE 
             access_scope = VALUES(access_scope),
             scope_value = VALUES(scope_value),
             is_active = 1`,
          [hotelId, operatorId, scope, scopeValue]
        );
      }

      return { success: true, card_uid: mockCardUid };
    } catch (error) {
      logger.error('Issue privilege card service error:', error.message);
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
