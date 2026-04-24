import { Response } from 'express';
import { AuthRequest } from '../types';
import pool, { RowDataPacket } from '../config/database';
import logger from '../utils/logger';
import mqttService from '../services/mqtt.service';

interface EnvironmentData {
  room_id: number;
  room_number: string;
  floor_id: number;
  floor_name: string;
  temperature: number;
  humidity: number;
  smoke_level: number;
  smoke_alarm: boolean;
  light_level: number;
  noise_level: number;
  pm25: number;
  update_time: string;
  status: 'normal' | 'warning' | 'danger';
  environment_score: number;
  /**
   * 本条记录中哪些物理量是"平台端从未收到任何上报"的（通常意味着该设备未配备该传感器，
   * 或设备离线从未上线过）。前端可据此展示"未配备"而不是一个误导性的 0。
   * 取值范围: 'temperature' | 'humidity' | 'smoke' | 'light' | 'noise' | 'pm25'
   */
  sensors_missing: string[];
}

interface DeviceInfo {
  device_id: string;
  device_type: string;
  device_name: string;
  room_id: number;
  status: 'online' | 'offline' | 'error';
  is_running: boolean;
  current_value: number;
  unit: string;
  battery_level?: number;
  last_maintenance?: string;
}

interface FireAlarmRecord {
  id: number;
  room_id: number;
  room_number: string;
  alarm_type: 'smoke' | 'temperature' | 'manual';
  severity: 'low' | 'medium' | 'high' | 'critical';
  value: number;
  threshold: number;
  triggered_at: string;
  resolved_at?: string;
  status: 'active' | 'acknowledged' | 'resolved' | 'false_alarm';
  handled_by?: string;
  description: string;
}

interface EventLog {
  id: number;
  event_type: 'fire_alarm' | 'device_error' | 'environment_warning' | 'device_control' | 'maintenance' | 'energy_alert';
  room_id: number;
  room_number: string;
  title: string;
  description: string;
  severity: 'info' | 'warning' | 'error' | 'critical';
  created_at: string;
  resolved: boolean;
  resolved_at?: string;
  handled_by?: string;
}

class EnvironmentController {
  constructor() {
    this.getEnvironmentData = this.getEnvironmentData.bind(this);
    this.getEnvironmentHistory = this.getEnvironmentHistory.bind(this);
    this.getDashboardStats = this.getDashboardStats.bind(this);
  }

  private calculateEnvStatus(temperature: number, humidity: number, smoke_level: number, pm25: number): 'normal' | 'warning' | 'danger' {
    if (smoke_level > 60 || temperature > 35 || temperature < 10 || pm25 > 75) {
      return 'danger';
    }
    if (temperature > 30 || temperature < 18 || humidity > 75 || humidity < 30) {
      return 'warning';
    }
    return 'normal';
  }

  private calculateEnvScore(temperature: number, humidity: number, smoke_level: number, pm25: number, noise_level: number): number {
    let score = 100;
    if (temperature > 30 || temperature < 18) score -= 20;
    if (humidity > 75 || humidity < 30) score -= 15;
    if (smoke_level > 40) score -= 25;
    if (pm25 > 50) score -= 20;
    if (noise_level > 60) score -= 10;
    return Math.max(0, Math.min(100, score));
  }

  async getEnvironmentData(req: AuthRequest, res: Response) {
    try {
      const { floor_id, room_id, status } = req.query;
      const hotelId = req.user?.hotel_id || 0;

      const [devices] = await pool.query<RowDataPacket[]>(
        `SELECT d.device_id, d.device_type, d.device_name, d.room_id, d.device_status,
                r.room_number, r.floor
         FROM devices d
         LEFT JOIN rooms r ON d.room_id = r.id
         WHERE d.device_type IN ('room', 'floor')
           AND (d.hotel_id = ? OR ? = 0)
         ORDER BY d.device_id`,
        [hotelId, hotelId]
      );

      if (devices.length === 0) {
        const emptySummary = {
          avg_temperature: 0, avg_humidity: 0, avg_smoke_level: 0,
          avg_noise_level: 0, avg_pm25: 0, avg_environment_score: 0,
          normal_count: 0, warning_count: 0, danger_count: 0, total_rooms: 0
        };
        res.json({ success: true, data: { list: [], total: 0, summary: emptySummary, update_time: new Date().toISOString() } });
        return;
      }

      const deviceIds = devices.map((d: any) => d.device_id);
      const placeholders = deviceIds.map(() => '?').join(',');

      const [sensorRows] = await pool.query<RowDataPacket[]>(
        `SELECT sd.device_id, sd.sensor_type, sd.sensor_value, sd.created_at
         FROM sensor_data sd
         INNER JOIN (
           SELECT device_id, sensor_type, MAX(created_at) as max_time
           FROM sensor_data
           WHERE device_id IN (${placeholders})
           GROUP BY device_id, sensor_type
         ) latest ON sd.device_id = latest.device_id
                   AND sd.sensor_type = latest.sensor_type
                   AND sd.created_at = latest.max_time`,
        deviceIds
      );

      const sensorMap = new Map<string, Map<string, { value: string; time: string }>>();
      for (const row of sensorRows) {
        if (!sensorMap.has(row.device_id)) {
          sensorMap.set(row.device_id, new Map());
        }
        sensorMap.get(row.device_id)!.set(row.sensor_type, {
          value: row.sensor_value,
          time: row.created_at
        });
      }

      const envList: EnvironmentData[] = [];

      for (const device of devices) {
        const sensors = sensorMap.get(device.device_id);
        const hasSensorData = sensors && sensors.size > 0;
        // 仅展示真实上报过环境数据的设备，避免把未上报设备显示成 0 值。
        if (!hasSensorData) {
          continue;
        }
        const missing: string[] = [];

        const temperature = sensors?.has('temperature') ? parseFloat(sensors.get('temperature')!.value) || 0 : 0;
        if (!sensors?.has('temperature')) { missing.push('temperature'); }
        const humidity = sensors?.has('humidity') ? parseFloat(sensors.get('humidity')!.value) || 0 : 0;
        if (!sensors?.has('humidity')) { missing.push('humidity'); }

        // 楼控/客房硬件上报的 MQ2 原始值类型为 air_quality_adc（老固件）或 smoke（已对齐后新固件）
        let smoke_level = 0;
        let hasSmoke = false;
        if (sensors?.has('air_quality_adc')) {
          const v = parseFloat(sensors.get('air_quality_adc')!.value);
          if (Number.isFinite(v)) {
            smoke_level = v;
            hasSmoke = true;
          }
        } else if (sensors?.has('smoke')) {
          const v = parseFloat(sensors.get('smoke')!.value);
          if (Number.isFinite(v)) {
            smoke_level = v;
            hasSmoke = true;
          }
        }
        if (!hasSmoke) { missing.push('smoke'); }

        const light_level = sensors?.has('light') ? parseFloat(sensors.get('light')!.value) || 0 : 0;
        if (!sensors?.has('light')) { missing.push('light'); }

        /* 硬件上没有噪声和 PM2.5 传感器，这两项始终标记为 missing，
           前端据此不再把 "0" 当成真实读数显示 */
        missing.push('noise', 'pm25');

        let latestTime = '';
        if (sensors) {
          for (const [, v] of sensors) {
            if (v.time > latestTime) latestTime = v.time;
          }
        }

        const floorId = device.floor || 0;
        const roomId = device.room_id || 0;
        const roomNumber = device.room_number || device.device_id;

        const envStatus = this.calculateEnvStatus(temperature, humidity, smoke_level, 0);
        const envScore = this.calculateEnvScore(temperature, humidity, smoke_level, 0, 0);

        envList.push({
          room_id: roomId,
          room_number: roomNumber,
          floor_id: floorId,
          floor_name: floorId > 0 ? `${floorId}楼` : '公共区域',
          temperature,
          humidity,
          smoke_level,
          smoke_alarm: smoke_level > 60,
          light_level,
          noise_level: 0,
          pm25: 0,
          update_time: latestTime || new Date().toISOString(),
          status: envStatus,
          environment_score: envScore,
          sensors_missing: missing
        });
      }

      let filteredList = envList;

      if (floor_id) {
        filteredList = filteredList.filter(item => item.floor_id === parseInt(floor_id as string));
      }

      if (room_id) {
        filteredList = filteredList.filter(item => item.room_id === parseInt(room_id as string));
      }

      if (status) {
        filteredList = filteredList.filter(item => item.status === status);
      }

      const summary = this.calculateSummary(filteredList);

      res.json({
        success: true,
        data: {
          list: filteredList,
          total: filteredList.length,
          summary,
          update_time: new Date().toISOString()
        }
      });
    } catch (error) {
      logger.error('Get environment data error:', (error as Error).message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  private calculateSummary(data: EnvironmentData[]) {
    if (data.length === 0) {
      return {
        avg_temperature: 0,
        avg_humidity: 0,
        avg_smoke_level: 0,
        avg_noise_level: 0,
        avg_pm25: 0,
        avg_environment_score: 0,
        normal_count: 0,
        warning_count: 0,
        danger_count: 0,
        total_rooms: 0
      };
    }

    const totalTemp = data.reduce((sum, item) => sum + item.temperature, 0);
    const totalHumidity = data.reduce((sum, item) => sum + item.humidity, 0);
    const totalSmoke = data.reduce((sum, item) => sum + item.smoke_level, 0);
    const totalNoise = data.reduce((sum, item) => sum + item.noise_level, 0);
    const totalPM25 = data.reduce((sum, item) => sum + item.pm25, 0);
    const totalScore = data.reduce((sum, item) => sum + item.environment_score, 0);

    const normalCount = data.filter(item => item.status === 'normal').length;
    const warningCount = data.filter(item => item.status === 'warning').length;
    const dangerCount = data.filter(item => item.status === 'danger').length;

    return {
      avg_temperature: parseFloat((totalTemp / data.length).toFixed(1)),
      avg_humidity: parseFloat((totalHumidity / data.length).toFixed(1)),
      avg_smoke_level: parseFloat((totalSmoke / data.length).toFixed(1)),
      avg_noise_level: parseInt((totalNoise / data.length).toString()),
      avg_pm25: parseFloat((totalPM25 / data.length).toFixed(1)),
      avg_environment_score: parseInt((totalScore / data.length).toString()),
      normal_count: normalCount,
      warning_count: warningCount,
      danger_count: dangerCount,
      total_rooms: data.length
    };
  }

  async getEnvironmentHistory(req: AuthRequest, res: Response) {
    try {
      const { room_id, device_id, hours = 24 } = req.query;
      const hoursNum = parseInt(hours as string);
      const hotelId = req.user?.hotel_id || 0;

      let query = `
        SELECT sd.device_id, sd.sensor_type, sd.sensor_value, sd.created_at
        FROM sensor_data sd
        INNER JOIN devices d ON sd.device_id = d.device_id
        WHERE sd.created_at >= DATE_SUB(NOW(), INTERVAL ? HOUR)
          AND (d.hotel_id = ? OR ? = 0)
      `;
      const params: any[] = [hoursNum, hotelId, hotelId];

      if (room_id) {
        query += ` AND d.room_id = ?`;
        params.push(parseInt(room_id as string));
      }

      if (device_id) {
        query += ` AND sd.device_id = ?`;
        params.push(device_id);
      }

      query += ` ORDER BY sd.created_at ASC`;

      const [rows] = await pool.query<RowDataPacket[]>(query, params);

      const timeMap = new Map<string, { temperature: number; humidity: number; smoke_level: number; noise_level: number; pm25: number }>();

      for (const row of rows) {
        const timeKey = new Date(row.created_at).toISOString().slice(0, 16);
        if (!timeMap.has(timeKey)) {
          timeMap.set(timeKey, { temperature: 0, humidity: 0, smoke_level: 0, noise_level: 0, pm25: 0 });
        }
        const entry = timeMap.get(timeKey)!;
        const val = parseFloat(row.sensor_value) || 0;

        switch (row.sensor_type) {
          case 'temperature':
            entry.temperature = val;
            break;
          case 'humidity':
            entry.humidity = val;
            break;
          case 'smoke':
          case 'air_quality_adc':
            entry.smoke_level = val;
            break;
        }
      }

      const historyData = Array.from(timeMap.entries()).map(([time, data]) => ({
        time,
        ...data
      }));

      res.json({
        success: true,
        data: {
          room_id: room_id || device_id || 'all',
          history: historyData,
          period: `${hoursNum}h`
        }
      });
    } catch (error) {
      logger.error('Get environment history error:', (error as Error).message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  async getFireAlarms(req: AuthRequest, res: Response) {
    try {
      const { status, severity, limit = 50 } = req.query;
      const hotelId = req.user?.hotel_id || 0;

      let query = `
        SELECT da.*, r.room_number
        FROM device_alarms da
        LEFT JOIN rooms r ON da.room_id = r.id
        WHERE (da.hotel_id = ? OR ? = 0)
      `;
      const params: any[] = [hotelId, hotelId];

      if (status) {
        const statusMap: Record<string, string> = {
          active: 'pending',
          acknowledged: 'processing',
          resolved: 'resolved',
          false_alarm: 'ignored'
        };
        query += ` AND da.status = ?`;
        params.push(statusMap[status as string] || status);
      }

      if (severity) {
        const severityMap: Record<string, string> = {
          critical: 'emergency',
          high: 'critical',
          medium: 'warning',
          low: 'info'
        };
        query += ` AND da.alarm_level = ?`;
        params.push(severityMap[severity as string] || severity);
      }

      query += ` ORDER BY da.created_at DESC LIMIT ?`;
      params.push(parseInt(limit as string));

      const [rows] = await pool.query<RowDataPacket[]>(query, params);

      const mapAlarmType = (type: string): any => {
        switch (type) {
          case 'fire': return 'smoke';
          case 'intrusion': return 'manual';
          default: return type || 'smoke';
        }
      };

      const mapAlarmLevel = (level: string): any => {
        switch (level) {
          case 'emergency': return 'critical';
          case 'critical': return 'high';
          case 'warning': return 'medium';
          case 'info': return 'low';
          default: return level || 'low';
        }
      };

      const mapAlarmStatus = (s: string): any => {
        switch (s) {
          case 'pending': return 'active';
          case 'processing': return 'acknowledged';
          case 'resolved': return 'resolved';
          case 'ignored': return 'false_alarm';
          default: return s;
        }
      };

      const alarms: FireAlarmRecord[] = rows.map((row: any) => ({
        id: row.id,
        room_id: row.room_id || 0,
        room_number: row.room_number || String(row.room_id || '-'),
        alarm_type: mapAlarmType(row.alarm_type),
        severity: mapAlarmLevel(row.alarm_level),
        value: 0,
        threshold: 0,
        triggered_at: row.created_at?.toISOString?.() || row.created_at,
        resolved_at: row.handled_at?.toISOString?.() || row.handled_at,
        status: mapAlarmStatus(row.status),
        handled_by: row.handled_by?.toString(),
        description: row.alarm_content || row.alarm_type
      }));

      const activeCount = alarms.filter(a => a.status === 'active').length;
      const acknowledgedCount = alarms.filter(a => a.status === 'acknowledged').length;
      const resolvedCount = alarms.filter(a => a.status === 'resolved').length;
      const falseAlarmCount = alarms.filter(a => a.status === 'false_alarm').length;

      res.json({
        success: true,
        data: {
          alarms,
          total: alarms.length,
          summary: {
            active_count: activeCount,
            acknowledged_count: acknowledgedCount,
            resolved_today: resolvedCount,
            false_alarm_count: falseAlarmCount
          }
        }
      });
    } catch (error) {
      logger.error('Get fire alarms error:', (error as Error).message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  async acknowledgeAlarm(req: AuthRequest, res: Response) {
    try {
      const alarmId = parseInt(req.params.id);
      const { handler, notes } = req.body;

      // 获取当前用户信息作为处理人
      const currentUser = req.user as any;
      const handlerId = currentUser?.id || null;
      const handlerName = handler || currentUser?.username || 'admin';

      await pool.query(
        `UPDATE device_alarms SET status = 'processing', handled_by = ?, handled_at = NOW(), handle_remark = ? WHERE id = ?`,
        [handlerId, notes || `确认处理: ${handlerName}`, alarmId]
      );

      res.json({
        success: true,
        message: 'Alarm acknowledged successfully',
        data: {
          alarm_id: alarmId,
          status: 'acknowledged',
          acknowledged_at: new Date().toISOString(),
          handled_by: handlerName
        }
      });
    } catch (error) {
      logger.error('Acknowledge alarm error:', (error as Error).message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  async resolveAlarm(req: AuthRequest, res: Response) {
    try {
      const alarmId = parseInt(req.params.id);
      const { resolution, handler } = req.body;

      // 获取当前用户信息作为处理人
      const currentUser = req.user as any;
      const handlerId = currentUser?.id || null;
      const handlerName = handler || currentUser?.username || 'admin';

      await pool.query(
        `UPDATE device_alarms SET status = 'resolved', handled_by = ?, handled_at = NOW(), handle_remark = ? WHERE id = ?`,
        [handlerId, resolution || `标记解决: ${handlerName}`, alarmId]
      );

      res.json({
        success: true,
        message: 'Alarm resolved successfully',
        data: {
          alarm_id: alarmId,
          status: 'resolved',
          resolved_at: new Date().toISOString(),
          resolution
        }
      });
    } catch (error) {
      logger.error('Resolve alarm error:', (error as Error).message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  async getRoomDevices(req: AuthRequest, res: Response) {
    try {
      const { room_id } = req.query;
      const hotelId = req.user?.hotel_id || 0;

      let query = `
        SELECT d.device_id, d.device_type, d.device_name, d.room_id, d.device_status,
               d.last_seen, r.room_number
        FROM devices d
        LEFT JOIN rooms r ON d.room_id = r.id
        WHERE (d.hotel_id = ? OR ? = 0)
      `;
      const params: any[] = [hotelId, hotelId];

      if (room_id) {
        query += ` AND d.room_id = ?`;
        params.push(parseInt(room_id as string));
      }

      query += ` ORDER BY d.device_id`;

      const [rows] = await pool.query<RowDataPacket[]>(query, params);

      const devices: DeviceInfo[] = rows.map((row: any) => {
        const status = row.device_status === 'online' ? 'online' as const
          : row.device_status === 'error' ? 'error' as const
          : 'offline' as const;

        return {
          device_id: row.device_id,
          device_type: row.device_type,
          device_name: row.device_name || row.device_id,
          room_id: row.room_id || 0,
          status,
          is_running: row.device_status === 'online',
          current_value: 0,
          unit: '',
          last_maintenance: row.last_seen
        };
      });

      const onlineCount = devices.filter(d => d.status === 'online').length;
      const offlineCount = devices.filter(d => d.status === 'offline').length;
      const errorCount = devices.filter(d => d.status === 'error').length;
      const runningCount = devices.filter(d => d.is_running).length;

      res.json({
        success: true,
        data: {
          devices,
          total: devices.length,
          summary: {
            online_count: onlineCount,
            offline_count: offlineCount,
            error_count: errorCount,
            running_count: runningCount,
            total_devices: devices.length,
            online_rate: devices.length > 0 ? Math.round((onlineCount / devices.length) * 100) : 0
          }
        }
      });
    } catch (error) {
      logger.error('Get room devices error:', (error as Error).message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  async controlDevice(req: AuthRequest, res: Response) {
    try {
      const deviceId = req.params.id;
      const { action, value } = req.body;
      const currentUser = req.user as any;

      logger.info(`收到设备控制请求 - 设备: ${deviceId}, 动作: ${action}, 值: ${value}`);

      // 1. 获取设备信息以确定类型
      const [devices] = await pool.query<RowDataPacket[]>(
        'SELECT device_type, device_name FROM devices WHERE device_id = ?',
        [deviceId]
      );

      if (devices.length === 0) {
        res.status(404).json({ success: false, message: '设备不存在' });
        return;
      }

      const device = devices[0];
      let cmdType = '';
      let cmdValue = '';

      // 2. 根据动作和设备类型映射 MQTT 指令
      // 这里的映射逻辑应与 emulator/common/config.py 保持一致
      switch (action) {
        case 'toggle':
          if (device.device_type === 'light') {
            cmdType = 'scene_next';
          } else {
            cmdType = this.mapDeviceTypeToCmd(device.device_type);
          }
          break;
        case 'turn_on':
        case 'open':
          if (device.device_type === 'curtain' || device.device_type === 'window_sensor') {
            cmdType = 'curtain_open';
          } else if (device.device_type === 'door_sensor' || device.device_type === 'lock') {
            cmdType = 'door_unlock';
          } else if (device.device_type === 'ac') {
            cmdType = 'air_on';
          } else {
            cmdType = 'light_on';
          }
          break;
        case 'turn_off':
        case 'close':
          if (device.device_type === 'curtain' || device.device_type === 'window_sensor') {
            cmdType = 'curtain_close';
          } else if (device.device_type === 'door_sensor' || device.device_type === 'lock') {
            cmdType = 'door_lock';
          } else if (device.device_type === 'ac') {
            cmdType = 'air_off';
          } else {
            cmdType = 'light_off';
          }
          break;
        case 'set_value':
          if (device.device_type === 'ac') {
            cmdType = 'set_ac_temp';
            cmdValue = String(value || 24);
          } else if (device.device_type === 'light') {
            cmdType = 'set_light_brightness';
            cmdValue = String(value ?? 80);
          } else if (device.device_type === 'room') {
            cmdType = 'set_volume';
            cmdValue = String(value ?? 60);
          } else {
            cmdType = this.mapDeviceTypeToCmd(device.device_type);
            cmdValue = String(value ?? '');
          }
          break;
        case 'broadcast_alarm':
          cmdType = 'broadcast_alarm';
          break;
        case 'floor_reset':
          cmdType = 'floor_reset';
          break;
        default:
          // 支持直接透传 command_type
          cmdType = action;
      }

      // 3. 发送 MQTT 指令
      const commandId = await mqttService.sendDeviceCommand(
        deviceId,
        cmdType,
        cmdValue,
        currentUser.username
      );

      if (!commandId) {
        res.status(500).json({ success: false, message: '指令发送失败（MQTT 服务异常或设备未审核）' });
        return;
      }

      res.json({
        success: true,
        message: `指令已下发: ${cmdType}=${cmdValue}`,
        data: {
          command_id: commandId,
          device_id: deviceId,
          action: cmdValue,
          executed_at: new Date().toISOString(),
          status: 'pending'
        }
      });
    } catch (error) {
      logger.error('Control device error:', (error as Error).message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  private mapDeviceTypeToCmd(type: string): string {
    const map: Record<string, string> = {
      'ac': 'air',
      'light': 'light',
      'curtain': 'curtain',
      'door_sensor': 'door',
      'lock': 'door',
      'floor_controller': 'alarm'
    };
    return map[type] || type;
  }

  async getEventLogs(req: AuthRequest, res: Response) {
    try {
      const { event_type, severity, limit = 100 } = req.query;
      const hotelId = req.user?.hotel_id || 0;

      const [alarmRows] = await pool.query<RowDataPacket[]>(
        `SELECT da.*, r.room_number
         FROM device_alarms da
         LEFT JOIN rooms r ON da.room_id = r.id
         WHERE (da.hotel_id = ? OR ? = 0)
         ORDER BY da.created_at DESC
         LIMIT ?`,
        [hotelId, hotelId, parseInt(limit as string)]
      );

      const [securityRows] = await pool.query<RowDataPacket[]>(
        `SELECT se.*, r.room_number
         FROM security_events se
         LEFT JOIN devices d ON se.device_id = d.device_id
         LEFT JOIN rooms r ON d.room_id = r.id
         WHERE (d.hotel_id = ? OR ? = 0)
         ORDER BY se.created_at DESC
         LIMIT ?`,
        [hotelId, hotelId, parseInt(limit as string)]
      );

      const mapEventType = (alarmType: string, source: string): any => {
        if (source === 'security') {
          switch (alarmType) {
            case 'fire_alarm': return 'fire_alarm';
            case 'intrusion': return 'device_error';
            default: return 'environment_warning';
          }
        }
        switch (alarmType) {
          case 'fire': return 'fire_alarm';
          case 'offline': return 'device_error';
          case 'sensor_error': return 'device_error';
          case 'intrusion': return 'environment_warning';
          default: return 'device_error';
        }
      };

      const mapSeverity = (level: string): any => {
        switch (level) {
          case 'emergency':
          case 'critical':
            return 'critical';
          case 'error':
          case 'high':
            return 'error';
          case 'warning':
          case 'medium':
            return 'warning';
          default:
            return 'info';
        }
      };

      const allLogs: EventLog[] = [];

      for (const row of alarmRows) {
        const createdAt = row.created_at instanceof Date ? row.created_at.toISOString() : String(row.created_at);
        const handledAt = row.handled_at instanceof Date ? row.handled_at.toISOString() : (row.handled_at ? String(row.handled_at) : undefined);
        allLogs.push({
          id: row.id,
          event_type: mapEventType(row.alarm_type, 'alarm'),
          room_id: row.room_id || 0,
          room_number: row.room_number || String(row.room_id || '-'),
          title: row.alarm_content || row.alarm_type,
          description: row.alarm_content || row.alarm_type,
          severity: mapSeverity(row.alarm_level),
          created_at: createdAt,
          resolved: row.status === 'resolved' || row.status === 'ignored',
          resolved_at: handledAt,
          handled_by: row.handled_by?.toString()
        });
      }

      for (const row of securityRows) {
        const createdAt = row.created_at instanceof Date ? row.created_at.toISOString() : String(row.created_at);
        const eventData = row.event_data ? (typeof row.event_data === 'string' ? row.event_data : JSON.stringify(row.event_data)) : '{}';
        allLogs.push({
          id: 10000 + row.id,
          event_type: mapEventType(row.event_type, 'security'),
          room_id: 0,
          room_number: row.room_number || row.device_id,
          title: row.event_type,
          description: eventData,
          severity: mapSeverity(row.event_level),
          created_at: createdAt,
          resolved: false,
        });
      }

      allLogs.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());

      let filteredLogs = allLogs;
      if (event_type) {
        filteredLogs = filteredLogs.filter(log => log.event_type === event_type);
      }
      if (severity) {
        filteredLogs = filteredLogs.filter(log => log.severity === severity);
      }

      const criticalCount = filteredLogs.filter(l => l.severity === 'critical' && !l.resolved).length;
      const unresolvedCount = filteredLogs.filter(l => !l.resolved).length;

      res.json({
        success: true,
        data: {
          logs: filteredLogs.slice(0, parseInt(limit as string)),
          total: filteredLogs.length,
          summary: {
            critical_count: criticalCount,
            unresolved_count: unresolvedCount,
            today_total: filteredLogs.filter(l => {
              const logDate = new Date(l.created_at);
              const today = new Date();
              return logDate.toDateString() === today.toDateString();
            }).length
          }
        }
      });
    } catch (error) {
      logger.error('Get event logs error:', (error as Error).message, (error as Error).stack);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  async getDashboardStats(req: AuthRequest, res: Response) {
    try {
      const hotelId = req.user?.hotel_id || 0;

      const [deviceRows] = await pool.query<RowDataPacket[]>(
        `SELECT device_status, COUNT(*) as count FROM devices WHERE (hotel_id = ? OR ? = 0) GROUP BY device_status`,
        [hotelId, hotelId]
      );

      const [sensorRows] = await pool.query<RowDataPacket[]>(
        `SELECT sd.sensor_type, AVG(CAST(sd.sensor_value AS DECIMAL(10,2))) as avg_value
         FROM sensor_data sd
         INNER JOIN devices d ON sd.device_id = d.device_id
         WHERE sd.created_at >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
           AND (d.hotel_id = ? OR ? = 0)
           AND sd.sensor_type IN ('temperature', 'humidity', 'smoke', 'air_quality_adc')
         GROUP BY sd.sensor_type`,
        [hotelId, hotelId]
      );

      const [alarmRows] = await pool.query<RowDataPacket[]>(
        `SELECT alarm_level, status, COUNT(*) as count
         FROM device_alarms
         WHERE (hotel_id = ? OR ? = 0)
         GROUP BY alarm_level, status`,
        [hotelId, hotelId]
      );

      let avgTemperature = 0;
      let avgHumidity = 0;
      let avgSmoke = 0;

      let smokeTypeAvg: number | null = null;
      let adcTypeAvg: number | null = null;
      for (const row of sensorRows) {
        switch (row.sensor_type) {
          case 'temperature':
            avgTemperature = parseFloat(row.avg_value) || 0;
            break;
          case 'humidity':
            avgHumidity = parseFloat(row.avg_value) || 0;
            break;
          case 'smoke':
            smokeTypeAvg = parseFloat(row.avg_value) || 0;
            break;
          case 'air_quality_adc':
            adcTypeAvg = parseFloat(row.avg_value) || 0;
            break;
        }
      }
      if (smokeTypeAvg != null && adcTypeAvg != null) {
        avgSmoke = (smokeTypeAvg + adcTypeAvg) / 2;
      } else {
        avgSmoke = smokeTypeAvg != null ? smokeTypeAvg : adcTypeAvg != null ? adcTypeAvg : 0;
      }

      let totalDevices = 0;
      let onlineDevices = 0;
      let offlineDevices = 0;
      let errorDevices = 0;

      for (const row of deviceRows) {
        totalDevices += row.count;
        if (row.device_status === 'online') onlineDevices = row.count;
        else if (row.device_status === 'offline') offlineDevices = row.count;
        else if (row.device_status === 'error') errorDevices = row.count;
      }

      let pendingAlarms = 0;
      let totalAlarms = 0;
      const byLevel: Record<string, number> = {};

      for (const row of alarmRows) {
        totalAlarms += row.count;
        if (row.status === 'pending') pendingAlarms += row.count;
        byLevel[row.alarm_level] = (byLevel[row.alarm_level] || 0) + row.count;
      }

      let environmentScore = 85;
      if (errorDevices > 0) environmentScore -= (errorDevices * 10);
      if (pendingAlarms > 0) environmentScore -= (pendingAlarms * 5);
      if (offlineDevices > 3) environmentScore -= 10;
      if (avgTemperature > 30 || avgTemperature < 18) environmentScore -= 10;
      if (avgHumidity > 75 || avgHumidity < 30) environmentScore -= 5;
      environmentScore = Math.max(0, Math.min(100, environmentScore));

      let airQuality = '优';
      if (avgTemperature > 30 || avgTemperature < 15) airQuality = '差';
      else if (avgTemperature > 28 || avgTemperature < 18) airQuality = '良';
      if (avgHumidity > 80 || avgHumidity < 20) airQuality = '差';
      else if (avgHumidity > 70 || avgHumidity < 30) airQuality = airQuality === '优' ? '良' : airQuality;

      const [smokeDetectorRows] = await pool.query<RowDataPacket[]>(
        `SELECT COUNT(*) as total,
                SUM(CASE WHEN device_status = 'online' THEN 1 ELSE 0 END) as online_count
         FROM devices
         WHERE device_type IN ('floor', 'room')
           AND (hotel_id = ? OR ? = 0)`,
        [hotelId, hotelId]
      );

      const detectorsTotal = smokeDetectorRows[0]?.total || 0;
      const detectorsOnline = smokeDetectorRows[0]?.online_count || 0;

      const dashboardStats = {
        environment: {
          avg_temperature: parseFloat(avgTemperature.toFixed(1)),
          avg_humidity: parseFloat(avgHumidity.toFixed(1)),
          avg_smoke_level: parseFloat(avgSmoke.toFixed(1)),
          avg_noise_level: 0,
          avg_pm25: 0,
          avg_environment_score: environmentScore,
          normal_count: onlineDevices,
          warning_count: offlineDevices,
          danger_count: errorDevices,
          total_rooms: totalDevices,
          air_quality: airQuality,
        },
        fire_safety: {
          active_alarms: pendingAlarms,
          today_alarms: totalAlarms,
          detectors_online: detectorsOnline,
          detectors_total: detectorsTotal,
          system_status: pendingAlarms > 0 ? 'alert' as const : 'normal' as const
        },
        devices: {
          total: totalDevices,
          online: onlineDevices,
          offline: offlineDevices,
          error: errorDevices,
          running: onlineDevices,
          maintenance_due: 0
        },
        alerts: {
          critical: byLevel['emergency'] || byLevel['critical'] || 0,
          warning: byLevel['warning'] || byLevel['medium'] || 0,
          info: byLevel['info'] || byLevel['low'] || 0,
          unresolved: pendingAlarms
        },
        environment_score: environmentScore
      };

      res.json({
        success: true,
        data: dashboardStats
      });
    } catch (error) {
      logger.error('Get dashboard stats error:', (error as Error).message);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }
}

export default new EnvironmentController();
