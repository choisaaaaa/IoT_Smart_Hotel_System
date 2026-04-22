import { Request, Response } from 'express';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { isSystemAdmin } from '../utils/role';
import { verifyDeviceKey } from '../utils/device-key';

class IrRemoteController {
  /**
   * 获取红外遥控码列表
   */
  async getAll(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id ? parseInt(req.query.hotel_id as string) : undefined;
      }
      if (!hotelId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const { device_type, brand, room_id, is_default, page = 1, pageSize = 20 } = req.query;

      let sql = 'SELECT * FROM ir_remote_codes WHERE hotel_id = ?';
      const params: any[] = [hotelId];

      if (device_type) {
        sql += ' AND device_type = ?';
        params.push(device_type);
      }

      if (brand) {
        sql += ' AND brand = ?';
        params.push(brand);
      }

      if (room_id) {
        sql += ' AND (room_id = ? OR room_id IS NULL)';
        params.push(parseInt(room_id as string));
      }

      if (is_default !== undefined) {
        sql += ' AND is_default = ?';
        params.push(is_default === '1' || is_default === 'true' ? 1 : 0);
      }

      // 获取总数
      const [countResult] = await pool.query<RowDataPacket[]>(
        sql.replace('SELECT *', 'SELECT COUNT(*) as total'),
        params
      );
      const total = countResult[0]?.total || 0;

      // 分页查询
      sql += ' ORDER BY is_default DESC, brand, function_name LIMIT ? OFFSET ?';
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
      logger.error('Get IR remote codes error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 获取红外码详情
   */
  async getById(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id || hotelId;
      }

      const codeId = parseInt(req.params.id);

      let sql = 'SELECT * FROM ir_remote_codes WHERE id = ?';
      const params: any[] = [codeId];

      if (hotelId) {
        sql += ' AND hotel_id = ?';
        params.push(hotelId);
      }

      const [rows] = await pool.query<RowDataPacket[]>(sql, params);

      if (rows.length === 0) {
        return res.status(404).json({ success: false, message: 'IR code not found' });
      }

      res.json({
        success: true,
        data: rows[0]
      });
    } catch (error) {
      logger.error('Get IR code by id error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 添加红外遥控码
   */
  async create(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.body.hotel_id || hotelId;
      }
      if (!hotelId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const {
        device_type,
        brand,
        model,
        function_name,
        ir_code,
        protocol = 'NEC',
        room_id,
        is_default = false,
        is_custom = false
      } = req.body;

      if (!device_type || !function_name || !ir_code) {
        return res.status(400).json({ success: false, message: 'Device type, function name and IR code are required' });
      }

      const [result] = await pool.query<ResultSetHeader>(
        `INSERT INTO ir_remote_codes 
         (hotel_id, room_id, device_type, brand, model, function_name, ir_code, protocol, is_default, is_custom, created_by) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [hotelId, room_id || null, device_type, brand || null, model || null, function_name, ir_code, protocol, is_default ? 1 : 0, is_custom ? 1 : 0, user?.id]
      );

      res.json({
        success: true,
        message: 'IR code added successfully',
        data: { id: result.insertId }
      });
    } catch (error) {
      logger.error('Create IR code error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 更新红外码
   */
  async update(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.body.hotel_id || hotelId;
      }
      if (!hotelId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const codeId = parseInt(req.params.id);
      const { function_name, ir_code, protocol } = req.body;

      // 验证红外码是否属于该酒店
      const [codes] = await pool.query<RowDataPacket[]>(
        'SELECT id FROM ir_remote_codes WHERE id = ? AND hotel_id = ?',
        [codeId, hotelId]
      );

      if (codes.length === 0) {
        return res.status(404).json({ success: false, message: 'IR code not found' });
      }

      await pool.query(
        'UPDATE ir_remote_codes SET function_name = ?, ir_code = ?, protocol = ? WHERE id = ?',
        [function_name, ir_code, protocol, codeId]
      );

      res.json({
        success: true,
        message: 'IR code updated successfully'
      });
    } catch (error) {
      logger.error('Update IR code error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 删除红外码
   */
  async delete(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id || hotelId;
      }
      if (!hotelId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const codeId = parseInt(req.params.id);

      // 验证红外码是否属于该酒店
      const [codes] = await pool.query<RowDataPacket[]>(
        'SELECT id FROM ir_remote_codes WHERE id = ? AND hotel_id = ?',
        [codeId, hotelId]
      );

      if (codes.length === 0) {
        return res.status(404).json({ success: false, message: 'IR code not found' });
      }

      await pool.query('DELETE FROM ir_remote_codes WHERE id = ?', [codeId]);

      res.json({
        success: true,
        message: 'IR code deleted successfully'
      });
    } catch (error) {
      logger.error('Delete IR code error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 发送红外指令
   */
  async send(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.body.hotel_id || hotelId;
      }
      if (!hotelId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const { room_id, device_type, function_name } = req.body;

      if (!room_id || !device_type || !function_name) {
        return res.status(400).json({ success: false, message: 'Room ID, device type and function name are required' });
      }

      // 查找红外码（优先查找房间特定码，然后是默认码）
      const [codes] = await pool.query<RowDataPacket[]>(
        `SELECT * FROM ir_remote_codes 
         WHERE hotel_id = ? AND device_type = ? AND function_name = ? 
         AND (room_id = ? OR room_id IS NULL)
         ORDER BY room_id DESC, is_default DESC LIMIT 1`,
        [hotelId, device_type, function_name, room_id]
      );

      if (codes.length === 0) {
        return res.status(404).json({ success: false, message: 'IR code not found' });
      }

      const irCode = codes[0];

      // 查找房间内的红外发射设备
      const [devices] = await pool.query<RowDataPacket[]>(
        `SELECT device_id FROM devices 
         WHERE room_id = ? AND hotel_id = ? AND device_type = 'room_terminal' AND audit_status = 'approved'`,
        [room_id, hotelId]
      );

      if (devices.length === 0) {
        return res.status(404).json({ success: false, message: 'No IR device found in room' });
      }

      // 发送红外指令
      const mqttService = require('../services/mqtt.service').default;
      const commandId = await mqttService.sendDeviceCommand(
        devices[0].device_id,
        'ir_send',
        JSON.stringify({
          ir_code: irCode.ir_code,
          protocol: irCode.protocol,
          device_type: irCode.device_type
        }),
        user?.username || 'admin'
      );

      if (commandId) {
        res.json({
          success: true,
          message: 'IR command sent successfully',
          data: { command_id: commandId }
        });
      } else {
        res.status(500).json({ success: false, message: 'Failed to send IR command' });
      }
    } catch (error) {
      logger.error('Send IR command error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 开始红外学习（设备端调用）
   */
  async startLearn(req: Request, res: Response) {
    try {
      const { device_id, device_key, room_id } = req.body;

      if (!device_id || !device_key || !room_id) {
        return res.status(400).json({ success: false, message: 'Missing required parameters' });
      }

      // 验证设备密钥
      const [devices] = await pool.query<RowDataPacket[]>(
        'SELECT id, device_key FROM devices WHERE device_id = ? AND room_id = ?',
        [device_id, room_id]
      );

      if (devices.length === 0 || !verifyDeviceKey(device_key, devices[0].device_key)) {
        return res.status(401).json({ success: false, message: 'Invalid device credentials' });
      }

      // 发送开始学习指令
      const mqttService = require('../services/mqtt.service').default;
      const commandId = await mqttService.sendDeviceCommand(
        device_id,
        'ir_learn_start',
        JSON.stringify({ timeout: 30 }),
        'system'
      );

      // 生成学习会话ID
      const learnSessionId = `learn_${Date.now()}_${device_id}`;

      res.json({
        success: true,
        message: 'IR learning started',
        data: {
          learn_session_id: learnSessionId,
          timeout_seconds: 30,
          command_id: commandId
        }
      });
    } catch (error) {
      logger.error('Start IR learn error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 完成红外学习（设备端调用）
   */
  async completeLearn(req: Request, res: Response) {
    try {
      const { learn_session_id, ir_code, protocol = 'NEC' } = req.body;

      if (!learn_session_id || !ir_code) {
        return res.status(400).json({ success: false, message: 'Learn session ID and IR code are required' });
      }

      // 这里可以将学习到的红外码临时存储，等待用户确认后保存
      // 实际实现中可以使用Redis等缓存

      res.json({
        success: true,
        message: 'IR learning completed',
        data: {
          learn_session_id,
          ir_code,
          protocol
        }
      });
    } catch (error) {
      logger.error('Complete IR learn error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 获取品牌列表
   */
  async getBrands(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id ? parseInt(req.query.hotel_id as string) : undefined;
      }

      const { device_type } = req.query;

      let sql = 'SELECT DISTINCT brand FROM ir_remote_codes WHERE hotel_id = ? AND brand IS NOT NULL';
      const params: any[] = [hotelId];

      if (device_type) {
        sql += ' AND device_type = ?';
        params.push(device_type);
      }

      sql += ' ORDER BY brand';

      const [rows] = await pool.query<RowDataPacket[]>(sql, params);

      res.json({
        success: true,
        data: rows.map((row: any) => row.brand)
      });
    } catch (error) {
      logger.error('Get brands error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 获取品牌预设功能列表
   */
  async getBrandFunctions(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id ? parseInt(req.query.hotel_id as string) : undefined;
      }

      const brand = req.params.brand;
      const { device_type } = req.query;

      if (!brand) {
        return res.status(400).json({ success: false, message: 'Brand is required' });
      }

      let sql = `SELECT function_name, display_name 
                 FROM ir_remote_codes 
                 WHERE hotel_id = ? AND brand = ? AND is_default = 1`;
      const params: any[] = [hotelId, brand];

      if (device_type) {
        sql += ' AND device_type = ?';
        params.push(device_type);
      }

      sql += ' ORDER BY function_name';

      const [rows] = await pool.query<RowDataPacket[]>(sql, params);

      res.json({
        success: true,
        data: {
          brand,
          device_type: device_type || 'all',
          functions: rows.map((row: any) => ({
            function_name: row.function_name,
            display_name: row.display_name || row.function_name
          }))
        }
      });
    } catch (error) {
      logger.error('Get brand functions error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }
}

export default new IrRemoteController();
