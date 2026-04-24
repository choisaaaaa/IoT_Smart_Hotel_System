import { Request, Response } from 'express';
import deviceService from '../services/device.service';
import pool, { RowDataPacket } from '../config/database';
import logger from '../utils/logger';
import { isSystemAdmin, isCustomer, isGuest } from '../utils/role';

class DeviceController {
  /**
   * 硬件上报注册 (需包含 hotel_id)
   */
  async register(req: Request, res: Response) {
    try {
      const data = req.body;
      if (!data.hotel_id) {
        return res.status(400).json({ success: false, message: 'Hotel ID is required for registration' });
      }
      const result = await deviceService.registerDevice(data);
      res.json({
        success: true,
        message: 'Device registration info received',
        data: result
      });
    } catch (error) {
      logger.error('Register device error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 管理员审核设备 (需管理员权限)
   */
  async audit(req: Request, res: Response) {
    try {
      let hotelId = (req as any).user?.hotel_id;
      if (isSystemAdmin((req as any).user?.role)) {
        hotelId = req.body.hotel_id || hotelId || 1;
      }
      if (hotelId === undefined || hotelId === null) {return res.status(401).json({ success: false, message: 'Unauthorized' });}

      const id = parseInt(req.params.id);
      const { status, room_id, area, device_name } = req.body;

      if (!id || !['approved', 'rejected'].includes(status)) {
        return res.status(400).json({ success: false, message: 'Invalid parameters' });
      }

      // 验证设备是否属于该酒店
      const device = await deviceService.getDeviceById(id, hotelId);
      if (!device) {
        return res.status(404).json({ success: false, message: 'Device not found' });
      }

      const result = await deviceService.auditDevice(id, status, { room_id, area, device_name });
      res.json({
        success: true,
        message: `Device ${status} successfully`,
        data: result
      });
    } catch (error) {
      logger.error('Audit device error:', error);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 获取所有设备 (管理端显示)
   */
  async getAll(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      const { status, audit_status, room_id, hotel_id } = req.query;

      let targetHotelId: number | undefined;
      let customerRoomId: number | undefined;

      if (isSystemAdmin(user?.role)) {
        targetHotelId = hotel_id ? parseInt(hotel_id as string) : undefined;
      } else if (isCustomer(user?.role) || isGuest(user?.role)) {
        const [bookings]: any = await pool.query(
          `SELECT room_id FROM bookings WHERE (user_id = ? OR guest_phone = ?) AND status = 'checked_in' ORDER BY id DESC LIMIT 1`,
          [user?.id, user?.phone]
        );
        if (bookings.length > 0) {
          customerRoomId = bookings[0].room_id;
        } else {
          res.json({ success: true, data: [] });
          return;
        }
      } else {
        targetHotelId = user?.hotel_id;
      }

      const filters = {
        status: status as string,
        audit_status: audit_status as string,
        room_id: customerRoomId || (room_id ? parseInt(room_id as string) : undefined)
      };

      const result = await deviceService.getAllDevices(targetHotelId, filters);
      res.json({
        success: true,
        data: result
      });
    } catch (error) {
      logger.error('Get all devices error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 获取单个设备详情
   */
  async getById(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id || hotelId || 1;
      }

      if (isCustomer(user?.role) || isGuest(user?.role)) {
        const [bookings]: any = await pool.query(
          `SELECT r.hotel_id FROM bookings b JOIN rooms r ON b.room_id = r.id WHERE (b.user_id = ? OR b.guest_phone = ?) AND b.status = 'checked_in' ORDER BY b.id DESC LIMIT 1`,
          [user?.id, user?.phone]
        );
        if (bookings.length === 0) {
          return res.status(403).json({ success: false, message: 'No active check-in found' });
        }
        hotelId = bookings[0].hotel_id;
      } else {
        if (hotelId === undefined || hotelId === null) {return res.status(401).json({ success: false, message: 'Unauthorized' });}
      }

      const id = parseInt(req.params.id);
      const result = await deviceService.getDeviceById(id, hotelId);
      if (!result) {
        return res.status(404).json({ success: false, message: 'Device not found' });
      }
      res.json({
        success: true,
        data: result
      });
    } catch (error) {
      logger.error('Get device by id error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 删除设备
   */
  async delete(req: Request, res: Response) {
    try {
      let hotelId = (req as any).user?.hotel_id;
      if (isSystemAdmin((req as any).user?.role)) {
        hotelId = req.query.hotel_id || hotelId || 1;
      }
      if (hotelId === undefined || hotelId === null) {return res.status(401).json({ success: false, message: 'Unauthorized' });}

      const id = parseInt(req.params.id);
      await deviceService.deleteDevice(id, hotelId);
      res.json({
        success: true,
        message: 'Device deleted successfully'
      });
    } catch (error) {
      logger.error('Delete device error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 向设备发送指令 (需管理员/员工权限)
   */
  async sendCommand(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.body.hotel_id || hotelId || 1;
      }

      const id = parseInt(req.params.id);
      const { command_type, command_value } = req.body;

      if (!id || !command_type) {
        return res.status(400).json({ success: false, message: 'Invalid parameters' });
      }

      if (isCustomer(user?.role) || isGuest(user?.role)) {
        const [bookings]: any = await pool.query(
          `SELECT b.room_id, r.hotel_id FROM bookings b JOIN rooms r ON b.room_id = r.id WHERE (b.user_id = ? OR b.guest_phone = ?) AND b.status = 'checked_in' ORDER BY b.id DESC LIMIT 1`,
          [user?.id, user?.phone]
        );
        if (bookings.length === 0) {
          return res.status(403).json({ success: false, message: 'No active check-in found' });
        }
        hotelId = bookings[0].hotel_id;
        const customerRoomId = bookings[0].room_id;

        const device = await deviceService.getDeviceById(id, hotelId);
        if (!device || device.room_id !== customerRoomId) {
          return res.status(403).json({ success: false, message: 'Cannot control devices outside your room' });
        }
      } else {
        if (hotelId === undefined || hotelId === null) {return res.status(401).json({ success: false, message: 'Unauthorized' });}
      }

      const device = await deviceService.getDeviceById(id, hotelId);
      if (!device) {
        return res.status(404).json({ success: false, message: 'Device not found' });
      }

      if (device.audit_status !== 'approved') {
        return res.status(403).json({ success: false, message: 'Device is not approved' });
      }

      const mqttService = require('../services/mqtt.service').default;
      const commandId = await mqttService.sendDeviceCommand(
        device.device_id,
        command_type,
        command_value,
        user?.username || 'admin'
      );

      if (commandId) {
        res.json({
          success: true,
          message: 'Command sent successfully',
          data: { command_id: commandId }
        });
      } else {
        res.status(500).json({ success: false, message: 'Failed to send command via MQTT' });
      }
    } catch (error) {
      logger.error('Send command error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 测试设备通信并触发蜂鸣器
   */
  async testBeep(req: Request, res: Response) {
    try {
      const hotelId = (req as any).user?.hotel_id;
      const { device_id } = req.body;
      const user = (req as any).user;

      if (!device_id) {
        return res.status(400).json({ success: false, message: 'Missing device_id' });
      }

      // 验证设备是否存在且属于该门店
      const [devices] = await pool.query<RowDataPacket[]>(
        'SELECT device_id, hotel_id FROM devices WHERE device_id = ?',
        [device_id]
      );

      if (devices.length === 0) {
        return res.status(404).json({ success: false, message: 'Device not found' });
      }

      if (hotelId && devices[0].hotel_id !== hotelId && !isSystemAdmin(user?.role)) {
        return res.status(403).json({ success: false, message: 'Unauthorized' });
      }

      const mqttService = require('../services/mqtt.service').default;
      
      // 发送 beep 指令，count 为 1
      const commandId = await mqttService.sendDeviceCommand(
        device_id,
        'buzzer',
        JSON.stringify({ count: 1, sound_id: 'test' }),
        user?.username || 'admin'
      );

      res.json({
        success: true,
        message: 'Communication test command sent (Beep)',
        data: { command_id: commandId }
      });
    } catch (error) {
      logger.error('Test beep error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 发放/收回房卡 (前台发卡器专用)
   */
  async handleRoomCard(req: Request, res: Response) {
    try {
      let hotelId = (req as any).user?.hotel_id;
      if (isSystemAdmin((req as any).user?.role) && !hotelId) {hotelId = 1;}
      if (hotelId === undefined || hotelId === null) {return res.status(401).json({ success: false, message: 'Unauthorized' });}

      const { action, booking_id, id_last_four } = req.body;
      const user = (req as any).user;

      if (!action || !booking_id) {
        return res.status(400).json({ success: false, message: 'Missing parameters' });
      }

      // 1. 查找订单及住客信息用于验证 (优先从 guests 表查找，确保信息是最新的)
      const [guestRows] = await pool.query<RowDataPacket[]>(
        'SELECT guest_id_number FROM guests WHERE booking_id = ? AND check_out_time IS NULL',
        [booking_id]
      );

      const [bookingRows] = await pool.query<RowDataPacket[]>(
        'SELECT b.room_id, b.guest_id_number, r.room_number FROM bookings b JOIN rooms r ON b.room_id = r.id WHERE b.id = ? AND b.hotel_id = ?',
        [booking_id, hotelId]
      );

      if (bookingRows.length === 0) {
        return res.status(404).json({ success: false, message: 'Booking not found' });
      }

      const booking = bookingRows[0];
      const actualIdNumber = guestRows.length > 0 ? guestRows[0].guest_id_number : booking.guest_id_number;

      // 2. 发卡时验证证件后四位
      if (action === 'issue') {
        if (!id_last_four) {
          return res.status(400).json({ success: false, message: '请提供证件后四位进行验证' });
        }
        
        // 如果数据库中没有证件号，允许直接通过（某些测试数据可能为空）
        if (!actualIdNumber) {
          logger.warn(`[Device] 订单 ${booking_id} 无证件号记录，跳过校验直接签发`);
        } else {
          const actualId = String(actualIdNumber).trim();
          const providedId = String(id_last_four).trim();
          
          if (actualId.slice(-4) !== providedId && actualId !== providedId) {
            return res.status(403).json({ 
              success: false, 
              message: `证件验证失败：您输入的 [${providedId}] 与系统记录不符` 
            });
          }
        }
      }

      // 3. 查找该门店在线的前台发卡设备
      const [deviceRows] = await pool.query<RowDataPacket[]>(
        'SELECT device_id FROM devices WHERE hotel_id = ? AND device_type = "front_desk" AND device_status = "online" AND audit_status = "approved" LIMIT 1',
        [hotelId]
      );

      if (deviceRows.length === 0) {
        return res.status(404).json({ success: false, message: 'No online front desk device found' });
      }

      const deviceId = deviceRows[0].device_id;

      // 4. 获取订单详情用于设置卡片有效期
      const [bookingInfo] = await pool.query<RowDataPacket[]>(
        'SELECT check_out_date, room_id FROM bookings WHERE id = ?',
        [booking_id]
      );
      const expiresAt = bookingInfo.length > 0 ? bookingInfo[0].check_out_date : null;
      const roomTableId = bookingInfo.length > 0 ? bookingInfo[0].room_id : null;

      // 5. 尝试获取设备当前感应到的物理 UID
      const [deviceDetail] = await pool.query<RowDataPacket[]>(
        'SELECT last_card_uid FROM devices WHERE device_id = ?',
        [deviceId]
      );
      
      const realUid = deviceDetail[0]?.last_card_uid;
      const cardUid = realUid || `PRIV_${Date.now()}`;

      // 6. 创建或更新卡片记录
      const rfidService = require('../services/rfid.service').default;
      await rfidService.issueCard({
        card_uid: cardUid,
        hotel_id: hotelId,
        booking_id: booking_id,
        room_id: roomTableId,
        card_type: 'guest',
        expires_at: expiresAt,
        status: 'active'
      });

      // 7. 记录初始发卡日志
      await pool.query(
        'INSERT INTO card_lifecycle_logs (card_uid, hotel_id, action_type, operator_id, notes) VALUES (?, ?, ?, ?, ?)',
        [cardUid, hotelId, 'issue', user?.id || 0, `签发客房卡: 房间 ${booking.room_number}, UID=${cardUid}`]
      );

      // 8. 下发指令
      const mqttService = require('../services/mqtt.service').default;
      const commandValue = JSON.stringify({
        booking_id,
        room_number: booking.room_number,
        card_uid: cardUid, // 传回 UID 供硬件确认
        action: action // issue | revoke
      });

      const commandId = await mqttService.sendDeviceCommand(
        deviceId,
        'room_card_op',
        commandValue,
        user?.username || 'admin'
      );

      res.json({
        success: true,
        message: action === 'issue' ? `Card issuance command sent (UID: ${cardUid})` : 'Card revocation command sent',
        data: { command_id: commandId, card_uid: cardUid }
      });
    } catch (error) {
      logger.error('Handle room card error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 获取设备传感器历史数据
   */
  async getSensorData(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id || hotelId;
      }

      const deviceId = parseInt(req.params.id);
      const { sensor_type, start_time, end_time, page = 1, pageSize = 20 } = req.query;

      // 验证设备权限
      const [devices] = await pool.query<RowDataPacket[]>(
        'SELECT device_id, hotel_id FROM devices WHERE id = ?',
        [deviceId]
      );

      if (devices.length === 0) {
        return res.status(404).json({ success: false, message: 'Device not found' });
      }

      const device = devices[0];

      if (hotelId && device.hotel_id !== hotelId) {
        return res.status(403).json({ success: false, message: 'Unauthorized' });
      }

      let sql = 'SELECT * FROM sensor_data WHERE device_id = ?';
      const params: any[] = [device.device_id];

      if (sensor_type) {
        sql += ' AND sensor_type = ?';
        params.push(sensor_type);
      }

      if (start_time) {
        sql += ' AND created_at >= ?';
        params.push(start_time);
      }

      if (end_time) {
        sql += ' AND created_at <= ?';
        params.push(end_time);
      }

      // 获取总数
      const [countResult] = await pool.query<RowDataPacket[]>(
        sql.replace('SELECT *', 'SELECT COUNT(*) as total'),
        params
      );
      const total = countResult[0]?.total || 0;

      // 分页查询
      sql += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
      params.push(parseInt(pageSize as string), (parseInt(page as string) - 1) * parseInt(pageSize as string));

      const [rows] = await pool.query<RowDataPacket[]>(sql, params);

      res.json({
        success: true,
        data: {
          list: rows,
          pagination: {
            page: parseInt(page as string),
            pageSize: parseInt(pageSize as string),
            total
          }
        }
      });
    } catch (error) {
      logger.error('Get sensor data error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 获取设备最新传感器数据
   */
  async getLatestSensorData(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id || hotelId;
      }

      const deviceId = parseInt(req.params.id);

      // 验证设备权限
      const [devices] = await pool.query<RowDataPacket[]>(
        'SELECT device_id, hotel_id FROM devices WHERE id = ?',
        [deviceId]
      );

      if (devices.length === 0) {
        return res.status(404).json({ success: false, message: 'Device not found' });
      }

      const device = devices[0];

      if (hotelId && device.hotel_id !== hotelId) {
        return res.status(403).json({ success: false, message: 'Unauthorized' });
      }

      /* 只返回最近 24 小时内有更新过的 sensor_type。这样历史上由老固件遗留、
         但当前硬件已不再上报的类型（如客房的 smoke/light、楼控的 human_present/ntc_temp_c、
         或旧命名 light_adc/air_quality_adc）不会再污染"实时数据"弹窗，
         实际硬件一停发自然就会消失，不需要手动清库。 */
      const [rows] = await pool.query<RowDataPacket[]>(
        `SELECT s1.* FROM sensor_data s1
         INNER JOIN (
           SELECT sensor_type, MAX(created_at) as max_created_at
           FROM sensor_data
           WHERE device_id = ?
             AND created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
           GROUP BY sensor_type
         ) s2 ON s1.sensor_type = s2.sensor_type AND s1.created_at = s2.max_created_at
         WHERE s1.device_id = ?`,
        [device.device_id, device.device_id]
      );

      res.json({
        success: true,
        data: rows
      });
    } catch (error) {
      logger.error('Get latest sensor data error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 查询设备指令执行历史
   */
  async getCommandHistory(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id || hotelId;
      }

      const deviceId = parseInt(req.params.id);
      const { command_type, status, start_date, end_date, page = 1, pageSize = 20 } = req.query;

      // 验证设备权限
      const [devices] = await pool.query<RowDataPacket[]>(
        'SELECT device_id, hotel_id FROM devices WHERE id = ?',
        [deviceId]
      );

      if (devices.length === 0) {
        return res.status(404).json({ success: false, message: 'Device not found' });
      }

      const device = devices[0];

      if (hotelId && device.hotel_id !== hotelId) {
        return res.status(403).json({ success: false, message: 'Unauthorized' });
      }

      let sql = 'SELECT * FROM control_commands WHERE device_id = ?';
      const params: any[] = [device.device_id];

      if (command_type) {
        sql += ' AND command_type = ?';
        params.push(command_type);
      }

      if (status) {
        sql += ' AND command_status = ?';
        params.push(status);
      }

      if (start_date) {
        sql += ' AND created_at >= ?';
        params.push(start_date);
      }

      if (end_date) {
        sql += ' AND created_at <= ?';
        params.push(end_date + ' 23:59:59');
      }

      // 获取总数
      const [countResult] = await pool.query<RowDataPacket[]>(
        sql.replace('SELECT *', 'SELECT COUNT(*) as total'),
        params
      );
      const total = countResult[0]?.total || 0;

      // 分页查询
      sql += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
      params.push(parseInt(pageSize as string), (parseInt(page as string) - 1) * parseInt(pageSize as string));

      const [rows] = await pool.query<RowDataPacket[]>(sql, params);

      res.json({
        success: true,
        data: {
          list: rows,
          pagination: {
            page: parseInt(page as string),
            pageSize: parseInt(pageSize as string),
            total
          }
        }
      });
    } catch (error) {
      logger.error('Get command history error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }
}

export default new DeviceController();
