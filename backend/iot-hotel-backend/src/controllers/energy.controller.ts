import { Request, Response } from 'express';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { isSystemAdmin } from '../utils/role';

class EnergyController {
  /**
   * 获取能耗数据
   */
  async getConsumption(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id ? parseInt(req.query.hotel_id as string) : undefined;
      }
      if (!hotelId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const { room_id, device_id, consumption_type = 'electricity', start_date, end_date, group_by = 'day' } = req.query;

      let sql = 'SELECT * FROM energy_consumption WHERE hotel_id = ?';
      const params: any[] = [hotelId];

      if (room_id) {
        sql += ' AND room_id = ?';
        params.push(parseInt(room_id as string));
      }

      if (device_id) {
        sql += ' AND device_id = ?';
        params.push(device_id);
      }

      if (consumption_type) {
        sql += ' AND consumption_type = ?';
        params.push(consumption_type);
      }

      if (start_date) {
        sql += ' AND record_date >= ?';
        params.push(start_date);
      }

      if (end_date) {
        sql += ' AND record_date <= ?';
        params.push(end_date);
      }

      // 根据分组方式调整查询
      if (group_by === 'day') {
        sql += ' ORDER BY record_date ASC';
      } else if (group_by === 'hour' && room_id) {
        sql += ' ORDER BY record_date ASC, record_hour ASC';
      }

      const [rows] = await pool.query<RowDataPacket[]>(sql, params);

      // 计算总消耗
      const totalConsumption = rows.reduce((sum: number, row: any) => sum + parseFloat(row.consumption_value), 0);

      res.json({
        success: true,
        data: {
          total_consumption: totalConsumption,
          unit: rows[0]?.unit || 'kwh',
          data: rows
        }
      });
    } catch (error) {
      logger.error('Get energy consumption error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 上报能耗数据（设备端调用）
   */
  async create(req: Request, res: Response) {
    try {
      const { device_id, room_id, consumption_type, consumption_value, unit, record_date, record_hour } = req.body;

      if (!device_id || !consumption_type || consumption_value === undefined || !record_date) {
        return res.status(400).json({ success: false, message: 'Missing required parameters' });
      }

      // 获取酒店ID
      const [devices] = await pool.query<RowDataPacket[]>(
        'SELECT hotel_id FROM devices WHERE device_id = ?',
        [device_id]
      );

      if (devices.length === 0) {
        return res.status(404).json({ success: false, message: 'Device not found' });
      }

      const hotelId = devices[0].hotel_id;

      const [result] = await pool.query<ResultSetHeader>(
        'INSERT INTO energy_consumption (hotel_id, room_id, device_id, consumption_type, consumption_value, unit, record_date, record_hour) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [hotelId, room_id || null, device_id, consumption_type, consumption_value, unit || 'kwh', record_date, record_hour || null]
      );

      res.json({
        success: true,
        message: 'Energy consumption recorded successfully',
        data: { id: result.insertId }
      });
    } catch (error) {
      logger.error('Create energy consumption error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 获取能耗统计
   */
  async getStats(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id ? parseInt(req.query.hotel_id as string) : undefined;
      }
      if (!hotelId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const { start_date, end_date, group_by = 'room' } = req.query;

      let whereClause = 'WHERE hotel_id = ?';
      const params: any[] = [hotelId];

      if (start_date) {
        whereClause += ' AND record_date >= ?';
        params.push(start_date);
      }

      if (end_date) {
        whereClause += ' AND record_date <= ?';
        params.push(end_date);
      }

      // 总能耗
      const [totalResult] = await pool.query<RowDataPacket[]>(
        `SELECT SUM(consumption_value) as total FROM energy_consumption ${whereClause}`,
        params
      );

      let byRoom: Record<string, number> = {};
      let byType: Record<string, number> = {};
      let trend: any[] = [];

      if (group_by === 'room') {
        const [roomResult] = await pool.query<RowDataPacket[]>(
          `SELECT room_id, SUM(consumption_value) as total FROM energy_consumption ${whereClause} GROUP BY room_id`,
          params
        );
        roomResult.forEach((row: any) => {
          byRoom[row.room_id] = parseFloat(row.total);
        });
      }

      // 按类型统计
      const [typeResult] = await pool.query<RowDataPacket[]>(
        `SELECT consumption_type, SUM(consumption_value) as total FROM energy_consumption ${whereClause} GROUP BY consumption_type`,
        params
      );
      typeResult.forEach((row: any) => {
        byType[row.consumption_type] = parseFloat(row.total);
      });

      // 趋势数据（按天）
      const [trendResult] = await pool.query<RowDataPacket[]>(
        `SELECT record_date, SUM(consumption_value) as total FROM energy_consumption ${whereClause} GROUP BY record_date ORDER BY record_date ASC`,
        params
      );
      trend = trendResult.map((row: any) => ({
        date: row.record_date,
        value: parseFloat(row.total)
      }));

      res.json({
        success: true,
        data: {
          total: parseFloat(totalResult[0]?.total || 0),
          by_room: byRoom,
          by_type: byType,
          trend: trend
        }
      });
    } catch (error) {
      logger.error('Get energy stats error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 获取能耗排名
   */
  async getRanking(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id ? parseInt(req.query.hotel_id as string) : undefined;
      }
      if (!hotelId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const { date_range = '7d', order = 'desc', limit = 10 } = req.query;

      // 计算日期范围
      const endDate = new Date();
      const startDate = new Date();
      const days = parseInt((date_range as string).replace('d', '')) || 7;
      startDate.setDate(startDate.getDate() - days);

      const [rows] = await pool.query<RowDataPacket[]>(
        `SELECT 
          e.room_id, 
          r.room_number,
          SUM(e.consumption_value) as total_consumption
         FROM energy_consumption e
         LEFT JOIN rooms r ON e.room_id = r.id
         WHERE e.hotel_id = ? AND e.record_date BETWEEN ? AND ?
         GROUP BY e.room_id
         ORDER BY total_consumption ${order === 'asc' ? 'ASC' : 'DESC'}
         LIMIT ?`,
        [hotelId, startDate.toISOString().split('T')[0], endDate.toISOString().split('T')[0], parseInt(limit as string)]
      );

      const ranking = rows.map((row: any, index: number) => ({
        room_id: row.room_id,
        room_number: row.room_number,
        consumption_value: parseFloat(row.total_consumption),
        rank: order === 'asc' ? rows.length - index : index + 1
      }));

      res.json({
        success: true,
        data: {
          ranking: order === 'asc' ? ranking.reverse() : ranking
        }
      });
    } catch (error) {
      logger.error('Get energy ranking error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  /**
   * 获取节能建议
   */
  async getSuggestions(req: Request, res: Response) {
    try {
      const user = (req as any).user;
      let hotelId = user?.hotel_id;
      if (isSystemAdmin(user?.role)) {
        hotelId = req.query.hotel_id ? parseInt(req.query.hotel_id as string) : undefined;
      }
      if (!hotelId) {
        return res.status(401).json({ success: false, message: 'Unauthorized' });
      }

      const { room_id } = req.query;

      // 获取近期能耗数据
      let whereClause = 'WHERE hotel_id = ? AND record_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)';
      const params: any[] = [hotelId];

      if (room_id) {
        whereClause += ' AND room_id = ?';
        params.push(parseInt(room_id as string));
      }

      const [rows] = await pool.query<RowDataPacket[]>(
        `SELECT room_id, AVG(consumption_value) as avg_consumption 
         FROM energy_consumption ${whereClause} 
         GROUP BY room_id`,
        params
      );

      const suggestions = [];

      // 基于数据生成建议
      for (const row of rows as any[]) {
        if (row.avg_consumption > 50) {
          suggestions.push({
            type: 'high_consumption',
            title: '高能耗提醒',
            description: `房间 ${row.room_id} 平均能耗较高(${row.avg_consumption.toFixed(2)} kWh)，建议检查设备运行状态`,
            potential_savings: '预计可节省 15-20%'
          });
        }
      }

      // 通用建议
      suggestions.push(
        {
          type: 'temperature',
          title: '空调温度优化',
          description: '建议将空调温度设置在 24-26℃，每调高 1℃ 可节省约 6-8% 能耗',
          potential_savings: '预计可节省 10-15%'
        },
        {
          type: 'lighting',
          title: '照明节能',
          description: '建议安装人体感应开关，无人时自动关闭灯光',
          potential_savings: '预计可节省 20-30%'
        },
        {
          type: 'standby',
          title: '减少待机能耗',
          description: '建议客人离房时关闭电视、充电器等非必要设备的电源',
          potential_savings: '预计可节省 5-10%'
        }
      );

      res.json({
        success: true,
        data: {
          suggestions
        }
      });
    } catch (error) {
      logger.error('Get energy suggestions error:', error.message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }
}

export default new EnergyController();
