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
   * 获取卡片详细信息 (用于模拟器同步或管理)
   */
  async getCardInfo(cardUid: string, hotelId: number) {
    let query = `
      SELECT c.*, r.room_number, r.room_name, b.booking_number
      FROM rfid_cards c
      LEFT JOIN rooms r ON c.room_id = r.id
      LEFT JOIN bookings b ON c.booking_id = b.id
      WHERE c.card_uid = ?`;
    const params: any[] = [cardUid];

    if (hotelId && hotelId !== 0) {
      query += ' AND c.hotel_id = ?';
      params.push(hotelId);
    }

    const [cards] = await pool.query<any[]>(query, params);

    if (cards.length === 0) return null;
    return cards[0];
  }

  /**
   * 更新卡片状态 (作废/挂失/恢复)
   */
  async updateCardStatus(cardUid: string, hotelId: number, status: string, operatorId: number, reason: string) {
    let query = 'UPDATE rfid_cards SET status = ? WHERE card_uid = ?';
    const params: any[] = [status, cardUid];

    if (hotelId && hotelId !== 0) {
      query += ' AND hotel_id = ?';
      params.push(hotelId);
    }

    const [result] = await pool.query<ResultSetHeader>(query, params);

    if (result.affectedRows > 0) {
      // 这里的 hotelId 如果是 0，我们尝试查出实际的 hotel_id 用于日志
      let actualHotelId = hotelId;
      if (!actualHotelId || actualHotelId === 0) {
        const [card] = await pool.query<any[]>('SELECT hotel_id FROM rfid_cards WHERE card_uid = ?', [cardUid]);
        if (card.length > 0) actualHotelId = card[0].hotel_id;
      }

      await pool.query(
        'INSERT INTO card_lifecycle_logs (card_uid, hotel_id, action_type, operator_id, notes) VALUES (?, ?, ?, ?, ?)',
        [cardUid, actualHotelId, 'status_change', operatorId, `变更状态为 ${status}: ${reason}`]
      );
      return true;
    }
    return false;
  }

  /**
   * 修改有效期
   */
  async updateCardExpiry(cardUid: string, hotelId: number, expiryDate: string, operatorId: number) {
    const formattedDate = expiryDate.replace('T', ' ').replace(/\..+/, '');
    let query = 'UPDATE rfid_cards SET expires_at = ? WHERE card_uid = ?';
    const params: any[] = [formattedDate, cardUid];

    if (hotelId && hotelId !== 0) {
      query += ' AND hotel_id = ?';
      params.push(hotelId);
    }

    const [result] = await pool.query<ResultSetHeader>(query, params);

    if (result.affectedRows > 0) {
      let actualHotelId = hotelId;
      if (!actualHotelId || actualHotelId === 0) {
        const [card] = await pool.query<any[]>('SELECT hotel_id FROM rfid_cards WHERE card_uid = ?', [cardUid]);
        if (card.length > 0) actualHotelId = card[0].hotel_id;
      }

      await pool.query(
        'INSERT INTO card_lifecycle_logs (card_uid, hotel_id, action_type, operator_id, notes) VALUES (?, ?, ?, ?, ?)',
        [cardUid, actualHotelId, 'update_expiry', operatorId, `修改有效期至: ${formattedDate}`]
      );
      return true;
    }
    return false;
  }

  /**
   * 分页获取酒店卡片列表
   */
  async getHotelCards(hotelId: number, query: any) {
    const { page = 1, limit = 10, card_type, status, search } = query;
    const offset = (page - 1) * limit;
    
    let where = 'WHERE 1=1';
    const params: any[] = [];

    if (hotelId && hotelId !== 0) {
      where += ' AND c.hotel_id = ?';
      params.push(hotelId);
    }

    if (card_type) {
      where += ' AND c.card_type = ?';
      params.push(card_type);
    }
    if (status) {
      where += ' AND c.status = ?';
      params.push(status);
    }
    if (search) {
      where += ' AND (c.card_uid LIKE ? OR r.room_number LIKE ?)';
      params.push(`%${search}%`, `%${search}%`);
    }

    const [rows] = await pool.query<any[]>(
      `SELECT c.*, r.room_number, r.room_name, b.booking_number, m.name as member_name
       FROM rfid_cards c
       LEFT JOIN rooms r ON c.room_id = r.id
       LEFT JOIN bookings b ON c.booking_id = b.id
       LEFT JOIN members m ON c.member_id = m.id
       ${where}
       ORDER BY c.issued_at DESC
       LIMIT ? OFFSET ?`,
      [...params, Number(limit), Number(offset)]
    );

    const [total] = await pool.query<any[]>(
      `SELECT COUNT(*) as count FROM rfid_cards c LEFT JOIN rooms r ON c.room_id = r.id ${where}`,
      params
    );

    return {
      list: rows,
      total: total[0].count,
      page: Number(page),
      limit: Number(limit)
    };
  }
  async issuePrivilegeCard(data: any, hotelId: number, operatorId: number) {
    const { card_type, holder_name, holder_id, floors, rooms, expiry_date, remark, encoder_id, card_uid } = data;
    const CacheService = require('./cache.service').default;
    const mqttService = require('./mqtt.service').default;
    
    // 确保日期格式兼容 MySQL
    const formattedExpiryDate = expiry_date ? expiry_date.replace('T', ' ').replace(/\..+/, '') : null;
    
    try {
      // 如果前端没有传 UID，说明需要从硬件实时读取
      if (!card_uid) {
        // 将签发信息暂存到缓存，等待硬件返回真实 UID 后再写入数据库
        const cacheKey = `pending_privilege_issue:${encoder_id}`;
        await CacheService.set(cacheKey, {
          card_type,
          holder_name,
          holder_id,
          floors,
          rooms,
          expires_at: formattedExpiryDate,
          remark,
          hotel_id: hotelId,
          operator_id: operatorId,
          timestamp: Date.now()
        }, 300); // 5分钟有效期

        logger.info(`[RFID] 特权卡签发信息已暂存，等待硬件 ${encoder_id} 反馈...`);

        // 发送 MQTT 指令给发卡器
        await mqttService.sendDeviceCommand(
          encoder_id,
          'room_card_op',
          JSON.stringify({
            action: 'issue',
            card_type: card_type,
            holder_name: holder_name,
            expiry_date: formattedExpiryDate
          }),
          `operator_${operatorId}`
        );

        return { success: true, status: 'pending_hardware', message: '请在设备上放置卡片' };
      }

      // 如果前端已经传了物理 UID（例如之前感应到的），则直接写入
      const finalCardUid = card_uid;
      
      // 1. 发送 MQTT 指令给发卡器 (触发蜂鸣器)
      await mqttService.sendDeviceCommand(
        encoder_id,
        'room_card_op',
        JSON.stringify({
          action: 'issue',
          card_type: card_type,
          holder_name: holder_name,
          expiry_date: formattedExpiryDate
        }),
        `operator_${operatorId}`
      );
      
      // 2. 记录到 rfid_cards 表
      await pool.query<ResultSetHeader>(
        `INSERT INTO rfid_cards (card_uid, hotel_id, card_type, expires_at, status, issued_at, holder_name, holder_id, remark)
         VALUES (?, ?, ?, ?, 'active', NOW(), ?, ?, ?)
         ON DUPLICATE KEY UPDATE 
           card_type = VALUES(card_type),
           expires_at = VALUES(expires_at),
           status = 'active',
           holder_name = VALUES(holder_name),
           holder_id = VALUES(holder_id),
           remark = VALUES(remark)`,
        [finalCardUid, hotelId, card_type, formattedExpiryDate, holder_name, holder_id, remark]
      );

      // 3. 记录到生命周期日志
      await pool.query(
        `INSERT INTO card_lifecycle_logs (card_uid, hotel_id, action_type, operator_id, target_user_id, notes)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [finalCardUid, hotelId, 'issue', operatorId, null, `签发特权卡: ${card_type}, 持卡人: ${holder_name}, 备注: ${remark}`]
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

      return { success: true, card_uid: finalCardUid };
    } catch (error) {
      logger.error('Issue privilege card service error:', error.message);
      // 将具体的错误抛出，以便控制器捕获
      throw new Error(error.message || '签发失败');
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
}

export default new RFIDService();
