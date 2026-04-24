import { Request, Response } from 'express';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { isSystemAdmin } from '../utils/role';

class SceneController {
  /**
   * 获取场景列表
   */
  async getAll(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id ? parseInt(req.query.hotel_id as string) : undefined;
      }
      if (!hotelId) {
        if (isSystemAdmin(user?.role)) {
          hotelId = 1;
        } else {
          return res.status(401).json({ success: false, message: 'Unauthorized' });
        }
      }

      const { room_id, page = 1, pageSize = 20 } = req.query;

      let sql = 'SELECT * FROM scene_configs WHERE hotel_id = ?';
      const params: any[] = [hotelId];

      if (room_id) {
        sql += ' AND (room_id = ? OR room_id IS NULL)';
        params.push(parseInt(room_id as string));
      }

      // 获取总数
      const [countResult] = await pool.query<RowDataPacket[]>(
        sql.replace('SELECT *', 'SELECT COUNT(*) as total'),
        params
      );
      const total = countResult[0]?.total || 0;

      // 分页查询
      sql += ' ORDER BY is_active DESC, created_at DESC LIMIT ? OFFSET ?';
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
      logger.error('Get scenes error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 获取场景详情
   */
  async getById(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id || hotelId;
      }

      const sceneId = parseInt(req.params.id);

      let sql = 'SELECT * FROM scene_configs WHERE id = ?';
      const params: any[] = [sceneId];

      if (hotelId) {
        sql += ' AND hotel_id = ?';
        params.push(hotelId);
      }

      const [rows] = await pool.query<RowDataPacket[]>(sql, params);

      if (rows.length === 0) {
        return res.status(404).json({ success: false, message: 'Scene not found' });
      }

      // 解析commands JSON
      const scene = rows[0];
      if (scene.commands && typeof scene.commands === 'string') {
        scene.commands = JSON.parse(scene.commands);
      }

      res.json({
        success: true,
        data: scene
      });
    } catch (error) {
      logger.error('Get scene by id error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 创建场景
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

      const { scene_name, room_id, commands, is_active = true } = req.body;

      if (!scene_name || !commands || !Array.isArray(commands)) {
        return res.status(400).json({ success: false, message: 'Scene name and commands are required' });
      }

      const [result] = await pool.query<ResultSetHeader>(
        'INSERT INTO scene_configs (scene_name, hotel_id, room_id, commands, is_active, created_by) VALUES (?, ?, ?, ?, ?, ?)',
        [scene_name, hotelId, room_id || null, JSON.stringify(commands), is_active ? 1 : 0, user?.id]
      );

      res.json({
        success: true,
        message: 'Scene created successfully',
        data: { id: result.insertId }
      });
    } catch (error) {
      logger.error('Create scene error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 更新场景
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

      const sceneId = parseInt(req.params.id);
      const { scene_name, room_id, commands, is_active } = req.body;

      // 验证场景是否属于该酒店
      const [scenes] = await pool.query<RowDataPacket[]>(
        'SELECT id FROM scene_configs WHERE id = ? AND hotel_id = ?',
        [sceneId, hotelId]
      );

      if (scenes.length === 0) {
        return res.status(404).json({ success: false, message: 'Scene not found' });
      }

      const updates: string[] = [];
      const params: any[] = [];

      if (scene_name !== undefined) {
        updates.push('scene_name = ?');
        params.push(scene_name);
      }
      if (room_id !== undefined) {
        updates.push('room_id = ?');
        params.push(room_id);
      }
      if (commands !== undefined) {
        updates.push('commands = ?');
        params.push(JSON.stringify(commands));
      }
      if (is_active !== undefined) {
        updates.push('is_active = ?');
        params.push(is_active ? 1 : 0);
      }

      if (updates.length === 0) {
        return res.status(400).json({ success: false, message: 'No fields to update' });
      }

      params.push(sceneId);

      await pool.query(
        `UPDATE scene_configs SET ${updates.join(', ')} WHERE id = ?`,
        params
      );

      res.json({
        success: true,
        message: 'Scene updated successfully'
      });
    } catch (error) {
      logger.error('Update scene error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 删除场景
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

      const sceneId = parseInt(req.params.id);

      // 验证场景是否属于该酒店
      const [scenes] = await pool.query<RowDataPacket[]>(
        'SELECT id FROM scene_configs WHERE id = ? AND hotel_id = ?',
        [sceneId, hotelId]
      );

      if (scenes.length === 0) {
        return res.status(404).json({ success: false, message: 'Scene not found' });
      }

      await pool.query('DELETE FROM scene_configs WHERE id = ?', [sceneId]);

      res.json({
        success: true,
        message: 'Scene deleted successfully'
      });
    } catch (error) {
      logger.error('Delete scene error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 启用/禁用场景
   */
  async toggle(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.body.hotel_id || hotelId;
      }
      if (!hotelId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const sceneId = parseInt(req.params.id);

      // 验证场景是否属于该酒店
      const [scenes] = await pool.query<RowDataPacket[]>(
        'SELECT is_active FROM scene_configs WHERE id = ? AND hotel_id = ?',
        [sceneId, hotelId]
      );

      if (scenes.length === 0) {
        return res.status(404).json({ success: false, message: 'Scene not found' });
      }

      const newStatus = scenes[0].is_active ? 0 : 1;

      await pool.query(
        'UPDATE scene_configs SET is_active = ? WHERE id = ?',
        [newStatus, sceneId]
      );

      res.json({
        success: true,
        message: 'Scene status updated successfully',
        data: { is_active: newStatus === 1 }
      });
    } catch (error) {
      logger.error('Toggle scene error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 执行场景
   */
  async execute(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.body.hotel_id || hotelId;
      }

      const sceneId = parseInt(req.params.id);
      const { room_id: targetRoomId } = req.body;

      // 获取场景配置
      let sql = 'SELECT * FROM scene_configs WHERE id = ?';
      const params: any[] = [sceneId];

      if (hotelId) {
        sql += ' AND hotel_id = ?';
        params.push(hotelId);
      }

      const [scenes] = await pool.query<RowDataPacket[]>(sql, params);

      if (scenes.length === 0) {
        return res.status(404).json({ success: false, message: 'Scene not found' });
      }

      const scene = scenes[0];

      if (!scene.is_active) {
        return res.status(400).json({ success: false, message: 'Scene is not active' });
      }

      // 解析commands
      let commands = scene.commands;
      if (typeof commands === 'string') {
        commands = JSON.parse(commands);
      }

      // 确定目标房间
      const roomId = targetRoomId || scene.room_id;
      if (!roomId) {
        return res.status(400).json({ success: false, message: 'Room ID is required' });
      }

      // 获取房间内的设备
      const [devices] = await pool.query<RowDataPacket[]>(
        'SELECT device_id FROM devices WHERE room_id = ? AND hotel_id = ? AND audit_status = "approved"',
        [roomId, scene.hotel_id]
      );

      if (devices.length === 0) {
        return res.status(404).json({ success: false, message: 'No devices found in room' });
      }

      const deviceMap = new Map(devices.map((d: any) => [d.device_id, d]));

      // 发送指令
      const mqttService = require('../services/mqtt.service').default;
      const executionResults = [];
      let successCount = 0;
      let failCount = 0;

      for (const command of commands) {
        const deviceId = command.device_id;
        if (!deviceMap.has(deviceId)) {
          executionResults.push({
            device_id: deviceId,
            status: 'skipped',
            reason: 'Device not found in room'
          });
          failCount++;
          continue;
        }

        const commandId = await mqttService.sendDeviceCommand(
          deviceId,
          command.command_type,
          command.command_value,
          user?.username || 'system'
        );

        if (commandId) {
          executionResults.push({
            device_id: deviceId,
            command_type: command.command_type,
            status: 'sent',
            command_id: commandId
          });
          successCount++;
        } else {
          executionResults.push({
            device_id: deviceId,
            command_type: command.command_type,
            status: 'failed',
            reason: 'Failed to send command'
          });
          failCount++;
        }

        // 如果有延迟配置，等待指定时间
        if (command.delay && command.delay > 0) {
          await new Promise(resolve => setTimeout(resolve, command.delay));
        }
      }

      // 确定执行结果
      let executionResult: string;
      if (failCount === 0) {
        executionResult = 'success';
      } else if (successCount === 0) {
        executionResult = 'failed';
      } else {
        executionResult = 'partial';
      }

      // 记录执行日志
      const [logResult] = await pool.query<ResultSetHeader>(
        `INSERT INTO scene_execution_logs 
         (scene_id, hotel_id, room_id, scene_name, trigger_type, triggered_by, execution_result, execution_detail) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          sceneId,
          scene.hotel_id,
          roomId,
          scene.scene_name,
          user ? 'manual' : 'auto',
          user?.id || null,
          executionResult,
          JSON.stringify(executionResults)
        ]
      );

      res.json({
        success: true,
        message: `Scene executed with ${successCount} success, ${failCount} failed`,
        data: {
          execution_id: logResult.insertId,
          status: executionResult,
          results: executionResults
        }
      });
    } catch (error) {
      logger.error('Execute scene error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 获取场景执行历史
   */
  async getExecutions(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id ? parseInt(req.query.hotel_id as string) : undefined;
      }

      const { scene_id, room_id, execution_result, page = 1, pageSize = 20 } = req.query;

      let sql = 'SELECT * FROM scene_execution_logs WHERE 1=1';
      const params: any[] = [];

      if (hotelId) {
        sql += ' AND hotel_id = ?';
        params.push(hotelId);
      }

      if (scene_id) {
        sql += ' AND scene_id = ?';
        params.push(parseInt(scene_id as string));
      }

      if (room_id) {
        sql += ' AND room_id = ?';
        params.push(parseInt(room_id as string));
      }

      if (execution_result) {
        sql += ' AND execution_result = ?';
        params.push(execution_result);
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

      // 解析execution_detail JSON
      rows.forEach((row: any) => {
        if (row.execution_detail && typeof row.execution_detail === 'string') {
          try {
            row.execution_detail = JSON.parse(row.execution_detail);
          } catch (e) {
            // 保持原样
          }
        }
      });

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
      logger.error('Get scene executions error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 获取执行详情
   */
  async getExecutionById(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id || hotelId;
      }

      const executionId = parseInt(req.params.id);

      let sql = 'SELECT * FROM scene_execution_logs WHERE id = ?';
      const params: any[] = [executionId];

      if (hotelId) {
        sql += ' AND hotel_id = ?';
        params.push(hotelId);
      }

      const [rows] = await pool.query<RowDataPacket[]>(sql, params);

      if (rows.length === 0) {
        return res.status(404).json({ success: false, message: 'Execution not found' });
      }

      const execution = rows[0];
      if (execution.execution_detail && typeof execution.execution_detail === 'string') {
        try {
          execution.execution_detail = JSON.parse(execution.execution_detail);
        } catch (e) {
          // 保持原样
        }
      }

      res.json({
        success: true,
        data: execution
      });
    } catch (error) {
      logger.error('Get execution by id error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 初始化默认场景
   */
  async initDefault(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.body.hotel_id || hotelId;
      }
      if (!hotelId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const { room_type } = req.body;

      // 默认场景配置
      const defaultScenes = [
        {
          scene_name: '欢迎模式',
          commands: [
            { device_id: 'relay_1', command_type: 'relay_on', command_value: 'on', delay: 0 },
            { device_id: 'relay_2', command_type: 'relay_on', command_value: 'on', delay: 500 },
            { device_id: 'ac', command_type: 'set_temperature', command_value: '24', delay: 1000 }
          ]
        },
        {
          scene_name: '睡眠模式',
          commands: [
            { device_id: 'relay_1', command_type: 'relay_off', command_value: 'off', delay: 0 },
            { device_id: 'relay_2', command_type: 'relay_off', command_value: 'off', delay: 500 },
            { device_id: 'ac', command_type: 'set_temperature', command_value: '26', delay: 1000 },
            { device_id: 'curtain', command_type: 'close', command_value: 'close', delay: 1500 }
          ]
        },
        {
          scene_name: '离家模式',
          commands: [
            { device_id: 'relay_1', command_type: 'relay_off', command_value: 'off', delay: 0 },
            { device_id: 'relay_2', command_type: 'relay_off', command_value: 'off', delay: 0 },
            { device_id: 'relay_3', command_type: 'relay_off', command_value: 'off', delay: 0 },
            { device_id: 'relay_4', command_type: 'relay_off', command_value: 'off', delay: 0 },
            { device_id: 'ac', command_type: 'power_off', command_value: 'off', delay: 500 },
            { device_id: 'tv', command_type: 'power_off', command_value: 'off', delay: 500 }
          ]
        },
        {
          scene_name: '节能模式',
          commands: [
            { device_id: 'ac', command_type: 'set_temperature', command_value: '28', delay: 0 },
            { device_id: 'relay_1', command_type: 'relay_off', command_value: 'off', delay: 500 },
            { device_id: 'relay_2', command_type: 'relay_off', command_value: 'off', delay: 500 }
          ]
        }
      ];

      const createdScenes = [];

      for (const scene of defaultScenes) {
        // 检查是否已存在同名场景
        const [existing] = await pool.query<RowDataPacket[]>(
          'SELECT id FROM scene_configs WHERE hotel_id = ? AND scene_name = ? AND room_id IS NULL',
          [hotelId, scene.scene_name]
        );

        if (existing.length === 0) {
          const [result] = await pool.query<ResultSetHeader>(
            'INSERT INTO scene_configs (scene_name, hotel_id, room_id, commands, is_active, created_by) VALUES (?, ?, ?, ?, ?, ?)',
            [scene.scene_name, hotelId, null, JSON.stringify(scene.commands), 1, user?.id]
          );
          createdScenes.push({ id: result.insertId, scene_name: scene.scene_name });
        }
      }

      res.json({
        success: true,
        message: `Initialized ${createdScenes.length} default scenes`,
        data: { count: createdScenes.length, scenes: createdScenes }
      });
    } catch (error) {
      logger.error('Init default scenes error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }
}

export default new SceneController();
