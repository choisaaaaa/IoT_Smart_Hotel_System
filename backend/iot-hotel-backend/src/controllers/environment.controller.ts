import { Request, Response } from 'express';
import logger from '../utils/logger';

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

interface EnergyConsumption {
  room_id: number;
  room_number: string;
  floor_id: number;
  today_kwh: number;
  yesterday_kwh: number;
  this_month_kwh: number;
  peak_usage: number;
  peak_time: string;
  devices_count: number;
  efficiency_rating: 'A' | 'B' | 'C' | 'D' | 'F';
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
  private generateMockData(): EnvironmentData[] {
    const now = new Date();
    const rooms = [
      { room_id: 1, room_number: '301', floor_id: 3, floor_name: '3楼' },
      { room_id: 2, room_number: '302', floor_id: 3, floor_name: '3楼' },
      { room_id: 3, room_number: '303', floor_id: 3, floor_name: '3楼' },
      { room_id: 4, room_number: '304', floor_id: 3, floor_name: '3楼' },
      { room_id: 5, room_number: '305', floor_id: 3, floor_name: '3楼' },
      { room_id: 6, room_number: '401', floor_id: 4, floor_name: '4楼' },
      { room_id: 7, room_number: '402', floor_id: 4, floor_name: '4楼' },
      { room_id: 8, room_number: '403', floor_id: 4, floor_name: '4楼' },
      { room_id: 9, room_number: '404', floor_id: 4, floor_name: '4楼' },
      { room_id: 10, room_number: '405', floor_id: 4, floor_name: '4楼' },
      { room_id: 11, room_number: '501', floor_id: 5, floor_name: '5楼' },
      { room_id: 12, room_number: '502', floor_id: 5, floor_name: '5楼' },
    ];

    return rooms.map((room, index) => {
      const temperature = 22 + Math.random() * 8;
      const humidity = 45 + Math.random() * 30;
      const smoke_level = Math.random() * 30;
      const light_level = 200 + Math.random() * 600;
      const noise_level = 30 + Math.random() * 40;
      const pm25 = 15 + Math.random() * 60;

      let status: 'normal' | 'warning' | 'danger' = 'normal';

      if (temperature > 30 || temperature < 18 || humidity > 75 || humidity < 30) {
        status = 'warning';
      }

      if (smoke_level > 60 || temperature > 35 || pm25 > 75) {
        status = 'danger';
      }

      if (index === 3) {
        status = 'warning';
      }
      if (index === 7) {
        status = 'danger';
      }

      let score = 100;
      if (temperature > 30 || temperature < 18) score -= 20;
      if (humidity > 75 || humidity < 30) score -= 15;
      if (smoke_level > 40) score -= 25;
      if (pm25 > 50) score -= 20;
      if (noise_level > 60) score -= 10;
      score = Math.max(0, Math.min(100, score));

      return {
        ...room,
        temperature: parseFloat(temperature.toFixed(1)),
        humidity: parseFloat(humidity.toFixed(1)),
        smoke_level: parseFloat(smoke_level.toFixed(1)),
        smoke_alarm: smoke_level > 60,
        light_level: parseInt(light_level.toString()),
        noise_level: parseInt(noise_level.toString()),
        pm25: parseFloat(pm25.toFixed(1)),
        update_time: new Date(now.getTime() - index * 60000).toISOString(),
        status,
        environment_score: score
      };
    });
  }

  async getEnvironmentData(req: Request, res: Response) {
    try {
      const { floor_id, room_id, status } = req.query;

      let data = this.generateMockData();

      if (floor_id) {
        data = data.filter(item => item.floor_id === parseInt(floor_id as string));
      }

      if (room_id) {
        data = data.filter(item => item.room_id === parseInt(room_id as string));
      }

      if (status) {
        data = data.filter(item => item.status === status);
      }

      const summary = this.calculateSummary(data);

      res.json({
        success: true,
        data: {
          list: data,
          total: data.length,
          summary,
          update_time: new Date().toISOString()
        }
      });
    } catch (error) {
      logger.error('Get environment data error:', error);
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

  async getEnvironmentHistory(req: Request, res: Response) {
    try {
      const { room_id, hours = 24 } = req.query;
      const hoursNum = parseInt(hours as string);

      const now = new Date();
      const historyData = [];

      for (let i = hoursNum; i >= 0; i--) {
        const time = new Date(now.getTime() - i * 3600000);
        historyData.push({
          time: time.toISOString(),
          temperature: 22 + Math.random() * 8,
          humidity: 45 + Math.random() * 30,
          smoke_level: Math.random() * 25,
          noise_level: 30 + Math.random() * 35,
          pm25: 15 + Math.random() * 50
        });
      }

      res.json({
        success: true,
        data: {
          room_id: room_id || 'all',
          history: historyData,
          period: `${hoursNum}h`
        }
      });
    } catch (error) {
      logger.error('Get environment history error:', error);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  async getFireAlarms(req: Request, res: Response) {
    try {
      const { status, severity, limit = 50 } = req.query;

      const mockAlarms: FireAlarmRecord[] = [
        {
          id: 1,
          room_id: 8,
          room_number: '403',
          alarm_type: 'smoke',
          severity: 'critical',
          value: 78.5,
          threshold: 60,
          triggered_at: new Date(Date.now() - 1800000).toISOString(),
          status: 'active',
          description: '烟雾浓度严重超标，可能存在火灾风险'
        },
        {
          id: 2,
          room_id: 4,
          room_number: '304',
          alarm_type: 'temperature',
          severity: 'high',
          value: 36.2,
          threshold: 35,
          triggered_at: new Date(Date.now() - 3600000).toISOString(),
          status: 'acknowledged',
          handled_by: 'admin1',
          description: '房间温度过高，空调可能故障'
        },
        {
          id: 3,
          room_id: 11,
          room_number: '501',
          alarm_type: 'smoke',
          severity: 'medium',
          value: 55.3,
          threshold: 60,
          triggered_at: new Date(Date.now() - 7200000).toISOString(),
          status: 'resolved',
          resolved_at: new Date(Date.now() - 3600000).toISOString(),
          handled_by: 'reception_01',
          description: '轻微烟雾异常，已确认为烹饪引起'
        },
        {
          id: 4,
          room_id: 6,
          room_number: '401',
          alarm_type: 'manual',
          severity: 'high',
          value: 0,
          threshold: 0,
          triggered_at: new Date(Date.now() - 10800000).toISOString(),
          status: 'false_alarm',
          handled_by: 'admin1',
          description: '住客误触手动报警按钮'
        },
        {
          id: 5,
          room_id: 2,
          room_number: '302',
          alarm_type: 'smoke',
          severity: 'low',
          value: 48.7,
          threshold: 60,
          triggered_at: new Date(Date.now() - 14400000).toISOString(),
          status: 'resolved',
          resolved_at: new Date(Date.now() - 12600000).toISOString(),
          handled_by: 'system',
          description: '短暂烟雾波动，已自动恢复'
        }
      ];

      let filteredAlarms = mockAlarms;

      if (status) {
        filteredAlarms = filteredAlarms.filter(alarm => alarm.status === status);
      }

      if (severity) {
        filteredAlarms = filteredAlarms.filter(alarm => alarm.severity === severity);
      }

      res.json({
        success: true,
        data: {
          alarms: filteredAlarms.slice(0, parseInt(limit as string)),
          total: filteredAlarms.length,
          summary: {
            active_count: mockAlarms.filter(a => a.status === 'active').length,
            acknowledged_count: mockAlarms.filter(a => a.status === 'acknowledged').length,
            resolved_today: mockAlarms.filter(a => a.status === 'resolved').length,
            false_alarm_count: mockAlarms.filter(a => a.status === 'false_alarm').length
          }
        }
      });
    } catch (error) {
      logger.error('Get fire alarms error:', error);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  async acknowledgeAlarm(req: Request, res: Response) {
    try {
      const alarmId = parseInt(req.params.id);
      const { handler, notes } = req.body;

      logger.info(`Alarm ${alarmId} acknowledged by ${handler}: ${notes}`);

      res.json({
        success: true,
        message: 'Alarm acknowledged successfully',
        data: {
          alarm_id: alarmId,
          status: 'acknowledged',
          acknowledged_at: new Date().toISOString(),
          handled_by: handler
        }
      });
    } catch (error) {
      logger.error('Acknowledge alarm error:', error);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  async resolveAlarm(req: Request, res: Response) {
    try {
      const alarmId = parseInt(req.params.id);
      const { resolution, handler } = req.body;

      logger.info(`Alarm ${alarmId} resolved by ${handler}: ${resolution}`);

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
      logger.error('Resolve alarm error:', error);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  async getRoomDevices(req: Request, res: Response) {
    try {
      const { room_id } = req.query;

      const allDevices: DeviceInfo[] = [
        { device_id: 'AC_001', device_type: 'ac', device_name: '智能空调', room_id: 1, status: 'online', is_running: true, current_value: 24, unit: '°C', last_maintenance: '2026-03-15' },
        { device_id: 'LIGHT_001', device_type: 'light', device_name: '主灯', room_id: 1, status: 'online', is_running: true, current_value: 80, unit: '%' },
        { device_id: 'LIGHT_002', device_type: 'light', device_name: '床头灯', room_id: 1, status: 'online', is_running: false, current_value: 0, unit: '%' },
        { device_id: 'WINDOW_001', device_type: 'window_sensor', device_name: '窗户传感器', room_id: 1, status: 'online', is_running: true, current_value: 0, unit: '' },
        { device_id: 'DOOR_001', device_type: 'door_sensor', device_name: '门磁传感器', room_id: 1, status: 'online', is_running: true, current_value: 1, unit: '' },
        { device_id: 'CURTAIN_001', device_type: 'curtain', device_name: '智能窗帘', room_id: 1, status: 'online', is_running: false, current_value: 100, unit: '%' },

        { device_id: 'AC_002', device_type: 'ac', device_name: '智能空调', room_id: 2, status: 'online', is_running: true, current_value: 26, unit: '°C' },
        { device_id: 'LIGHT_003', device_type: 'light', device_name: '主灯', room_id: 2, status: 'online', is_running: true, current_value: 100, unit: '%' },
        { device_id: 'AC_003', device_type: 'ac', device_name: '智能空调', room_id: 3, status: 'offline', is_running: false, current_value: 0, unit: '°C' },
        { device_id: 'LIGHT_004', device_type: 'light', device_name: '主灯', room_id: 3, status: 'online', is_running: true, current_value: 60, unit: '%' },

        { device_id: 'AC_004', device_type: 'ac', device_name: '智能空调', room_id: 4, status: 'online', is_running: true, current_value: 28, unit: '°C', last_maintenance: '2026-02-20' },
        { device_id: 'LIGHT_005', device_type: 'light', device_name: '主灯', room_id: 4, status: 'error', is_running: false, current_value: 0, unit: '%' },
        { device_id: 'SMOKE_001', device_type: 'smoke_detector', device_name: '烟雾探测器', room_id: 4, status: 'online', is_running: true, current_value: 45, unit: '%', battery_level: 85 },

        { device_id: 'AC_005', device_type: 'ac', device_name: '智能空调', room_id: 5, status: 'online', is_running: false, current_value: 22, unit: '°C' },
        { device_id: 'HUMIDITY_001', device_type: 'humidifier', device_name: '加湿器', room_id: 5, status: 'online', is_running: true, current_value: 55, unit: '%' },

        { device_id: 'AC_006', device_type: 'ac', device_name: '智能空调', room_id: 6, status: 'online', is_running: true, current_value: 23, unit: '°C' },
        { device_id: 'LIGHT_006', device_type: 'light', device_name: '主灯', room_id: 6, status: 'online', is_running: true, current_value: 90, unit: '%' },
        { device_id: 'TV_001', device_type: 'tv', device_name: '智能电视', room_id: 6, status: 'online', is_running: true, current_value: 1, unit: '' },

        { device_id: 'AC_007', device_type: 'ac', device_name: '智能空调', room_id: 7, status: 'online', is_running: true, current_value: 25, unit: '°C' },
        { device_id: 'LIGHT_007', device_type: 'light', device_name: '主灯', room_id: 7, status: 'online', is_running: false, current_value: 0, unit: '%' },

        { device_id: 'AC_008', device_type: 'ac', device_name: '智能空调', room_id: 8, status: 'online', is_running: true, current_value: 36, unit: '°C' },
        { device_id: 'SMOKE_002', device_type: 'smoke_detector', device_name: '烟雾探测器', room_id: 8, status: 'online', is_running: true, current_value: 78, unit: '%', battery_level: 92 },
        { device_id: 'LIGHT_008', device_type: 'light', device_name: '主灯', room_id: 8, status: 'online', is_running: true, current_value: 100, unit: '%' },

        { device_id: 'AC_009', device_type: 'ac', device_name: '智能空调', room_id: 9, status: 'online', is_running: false, current_value: 20, unit: '°C' },
        { device_id: 'LIGHT_009', device_type: 'light', device_name: '主灯', room_id: 9, status: 'online', is_running: true, current_value: 70, unit: '%' },

        { device_id: 'AC_010', device_type: 'ac', device_name: '智能空调', room_id: 10, status: 'online', is_running: true, current_value: 24, unit: '°C' },
        { device_id: 'LIGHT_010', device_type: 'light', device_name: '主灯', room_id: 10, status: 'online', is_running: true, current_value: 85, unit: '%' },

        { device_id: 'AC_011', device_type: 'ac', device_name: '智能空调', room_id: 11, status: 'online', is_running: true, current_value: 23, unit: '°C' },
        { device_id: 'SMOKE_003', device_type: 'smoke_detector', device_name: '烟雾探测器', room_id: 11, status: 'online', is_running: true, current_value: 55, unit: '%', battery_level: 78 },
        { device_id: 'LIGHT_011', device_type: 'light', device_name: '主灯', room_id: 11, status: 'online', is_running: true, current_value: 95, unit: '%' },

        { device_id: 'AC_012', device_type: 'ac', device_name: '智能空调', room_id: 12, status: 'online', is_running: true, current_value: 25, unit: '°C' },
        { device_id: 'LIGHT_012', device_type: 'light', device_name: '主灯', room_id: 12, status: 'online', is_running: false, current_value: 0, unit: '%' },
        { device_id: 'CURTAIN_002', device_type: 'curtain', device_name: '智能窗帘', room_id: 12, status: 'online', is_running: true, current_value: 50, unit: '%' }
      ];

      let filteredDevices = allDevices;

      if (room_id) {
        filteredDevices = allDevices.filter(device => device.room_id === parseInt(room_id as string));
      }

      const onlineCount = filteredDevices.filter(d => d.status === 'online').length;
      const offlineCount = filteredDevices.filter(d => d.status === 'offline').length;
      const errorCount = filteredDevices.filter(d => d.status === 'error').length;
      const runningCount = filteredDevices.filter(d => d.is_running).length;

      res.json({
        success: true,
        data: {
          devices: filteredDevices,
          total: filteredDevices.length,
          summary: {
            online_count: onlineCount,
            offline_count: offlineCount,
            error_count: errorCount,
            running_count: runningCount,
            total_devices: filteredDevices.length,
            online_rate: filteredDevices.length > 0 ? Math.round((onlineCount / filteredDevices.length) * 100) : 0
          }
        }
      });
    } catch (error) {
      logger.error('Get room devices error:', error);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  async controlDevice(req: Request, res: Response) {
    try {
      const deviceId = req.params.id;
      const { action, value } = req.body;

      logger.info(`Control device ${deviceId}: action=${action}, value=${value}`);

      setTimeout(() => {
        logger.info(`Device ${deviceId} command executed successfully`);
      }, 1000);

      res.json({
        success: true,
        message: `Device command sent: ${action}`,
        data: {
          device_id: deviceId,
          action,
          value,
          executed_at: new Date().toISOString(),
          status: 'pending'
        }
      });
    } catch (error) {
      logger.error('Control device error:', error);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  async getEnergyConsumption(req: Request, res: Response) {
    try {
      const { room_id, period = 'today' } = req.query;

      const mockEnergyData: EnergyConsumption[] = [
        { room_id: 1, room_number: '301', floor_id: 3, today_kwh: 12.5, yesterday_kwh: 14.2, this_month_kwh: 385.6, peak_usage: 3.2, peak_time: '19:30', devices_count: 5, efficiency_rating: 'A' },
        { room_id: 2, room_number: '302', floor_id: 3, today_kwh: 8.3, yesterday_kwh: 9.1, this_month_kwh: 278.4, peak_usage: 2.1, peak_time: '21:00', devices_count: 2, efficiency_rating: 'A' },
        { room_id: 3, room_number: '303', floor_id: 3, today_kwh: 15.7, yesterday_kwh: 16.8, this_month_kwh: 456.2, peak_usage: 4.5, peak_time: '20:15', devices_count: 2, efficiency_rating: 'B' },
        { room_id: 4, room_number: '304', floor_id: 3, today_kwh: 18.9, yesterday_kwh: 17.5, this_month_kwh: 512.8, peak_usage: 5.2, peak_time: '18:45', devices_count: 3, efficiency_rating: 'C' },
        { room_id: 5, room_number: '305', floor_id: 3, today_kwh: 6.2, yesterday_kwh: 7.8, this_month_kwh: 198.5, peak_usage: 1.8, peak_time: '22:30', devices_count: 2, efficiency_rating: 'A' },
        { room_id: 6, room_number: '401', floor_id: 4, today_kwh: 10.4, yesterday_kwh: 11.2, this_month_kwh: 342.1, peak_usage: 2.8, peak_time: '20:00', devices_count: 3, efficiency_rating: 'A' },
        { room_id: 7, room_number: '402', floor_id: 4, today_kwh: 7.8, yesterday_kwh: 8.5, this_month_kwh: 245.3, peak_usage: 2.0, peak_time: '21:30', devices_count: 2, efficiency_rating: 'A' },
        { room_id: 8, room_number: '403', floor_id: 4, today_kwh: 22.3, yesterday_kwh: 20.1, this_month_kwh: 589.4, peak_usage: 6.1, peak_time: '17:30', devices_count: 3, efficiency_rating: 'D' },
        { room_id: 9, room_number: '404', floor_id: 4, today_kwh: 9.1, yesterday_kwh: 10.3, this_month_kwh: 298.7, peak_usage: 2.5, peak_time: '19:00', devices_count: 2, efficiency_rating: 'A' },
        { room_id: 10, room_number: '405', floor_id: 4, today_kwh: 13.6, yesterday_kwh: 12.9, this_month_kwh: 412.5, peak_usage: 3.8, peak_time: '20:45', devices_count: 2, efficiency_rating: 'B' },
        { room_id: 11, room_number: '501', floor_id: 5, today_kwh: 11.2, yesterday_kwh: 13.4, this_month_kwh: 367.8, peak_usage: 3.0, peak_time: '18:30', devices_count: 3, efficiency_rating: 'A' },
        { room_id: 12, room_number: '502', floor_id: 5, today_kwh: 8.9, yesterday_kwh: 9.6, this_month_kwh: 268.9, peak_usage: 2.3, peak_time: '21:15', devices_count: 3, efficiency_rating: 'A' }
      ];

      let filteredData = mockEnergyData;

      if (room_id) {
        filteredData = mockEnergyData.filter(item => item.room_id === parseInt(room_id as string));
      }

      const totalToday = filteredData.reduce((sum, item) => sum + item.today_kwh, 0);
      const totalYesterday = filteredData.reduce((sum, item) => sum + item.yesterday_kwh, 0);
      const totalMonth = filteredData.reduce((sum, item) => sum + item.this_month_kwh, 0);

      const savingsRate = totalYesterday > 0 ? parseFloat(((totalYesterday - totalToday) / totalYesterday * 100).toFixed(1)) : 0;

      res.json({
        success: true,
        data: {
          consumption: filteredData,
          total: filteredData.length,
          summary: {
            total_today_kwh: parseFloat(totalToday.toFixed(1)),
            total_yesterday_kwh: parseFloat(totalYesterday.toFixed(1)),
            total_month_kwh: parseFloat(totalMonth.toFixed(1)),
            savings_rate: savingsRate,
            estimated_monthly_cost: parseFloat((totalMonth * 0.85).toFixed(2)),
            most_efficient_room: filteredData.sort((a, b) => a.today_kwh - b.today_kwh)[0]?.room_number || '-',
            least_efficient_room: filteredData.sort((a, b) => b.today_kwh - a.today_kwh)[0]?.room_number || '-'
          }
        }
      });
    } catch (error) {
      logger.error('Get energy consumption error:', error);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  async getEventLogs(req: Request, res: Response) {
    try {
      const { event_type, severity, limit = 100 } = req.query;

      const now = new Date();
      const mockLogs: EventLog[] = [
        {
          id: 1,
          event_type: 'fire_alarm',
          room_id: 8,
          room_number: '403',
          title: '🚨 火警警报 - 烟雾超标',
          description: '403房烟雾浓度达到78.5%，超过安全阈值（60%），请立即检查！',
          severity: 'critical',
          created_at: new Date(now.getTime() - 1800000).toISOString(),
          resolved: false
        },
        {
          id: 2,
          event_type: 'device_error',
          room_id: 4,
          room_number: '304',
          title: '⚠️ 设备故障 - 主灯异常',
          description: '304房主灯控制器响应超时，可能需要维修或更换',
          severity: 'warning',
          created_at: new Date(now.getTime() - 3600000).toISOString(),
          resolved: false
        },
        {
          id: 3,
          event_type: 'environment_warning',
          room_id: 4,
          room_number: '304',
          title: '🌡️ 温度警告',
          description: '304房温度达到36.2°C，超过舒适温度上限（35°C）',
          severity: 'error',
          created_at: new Date(now.getTime() - 3600000).toISOString(),
          resolved: true,
          resolved_at: new Date(now.getTime() - 1800000).toISOString(),
          handled_by: 'admin1'
        },
        {
          id: 4,
          event_type: 'device_control',
          room_id: 1,
          room_number: '301',
          title: '📱 远程控制 - 调节空调温度',
          description: '管理员将301房空调温度从26°C调节至24°C',
          severity: 'info',
          created_at: new Date(now.getTime() - 7200000).toISOString(),
          resolved: true,
          handled_by: 'reception_01'
        },
        {
          id: 5,
          event_type: 'maintenance',
          room_id: 3,
          room_number: '303',
          title: '🔧 维护提醒 - 空调保养',
          description: '303房空调已运行超过2000小时，建议进行例行维护保养',
          severity: 'info',
          created_at: new Date(now.getTime() - 10800000).toISOString(),
          resolved: false
        },
        {
          id: 6,
          event_type: 'energy_alert',
          room_id: 8,
          room_number: '403',
          title: '⚡ 能耗预警',
          description: '403房今日能耗已达22.3kWh，较昨日同期增长15%，请注意节能',
          severity: 'warning',
          created_at: new Date(now.getTime() - 14400000).toISOString(),
          resolved: false
        },
        {
          id: 7,
          event_type: 'fire_alarm',
          room_id: 11,
          room_number: '501',
          title: '🔥 火警警报 - 已解除',
          description: '501房烟雾浓度异常（55.3%），经现场核查为住客烹饪引起，已恢复正常',
          severity: 'warning',
          created_at: new Date(now.getTime() - 7200000).toISOString(),
          resolved: true,
          resolved_at: new Date(now.getTime() - 3600000).toISOString(),
          handled_by: 'reception_01'
        },
        {
          id: 8,
          event_type: 'device_error',
          room_id: 3,
          room_number: '303',
          title: '❌ 设备离线 - 空调掉线',
          description: '303房智能空调失去连接，最后在线时间：2小时前',
          severity: 'error',
          created_at: new Date(now.getTime() - 18000000).toISOString(),
          resolved: false
        },
        {
          id: 9,
          event_type: 'environment_warning',
          room_id: 8,
          room_number: '403',
          title: '💨 PM2.5偏高',
          description: '403房PM2.5浓度达到68μg/m³，建议开启空气净化或通风',
          severity: 'warning',
          created_at: new Date(now.getTime() - 21600000).toISOString(),
          resolved: false
        },
        {
          id: 10,
          event_type: 'device_control',
          room_id: 12,
          room_number: '502',
          title: '🪟 远程控制 - 调节窗帘',
          description: '自动根据光照强度将502房窗帘开度调节至50%',
          severity: 'info',
          created_at: new Date(now.getTime() - 25200000).toISOString(),
          resolved: true,
          handled_by: 'system'
        }
      ];

      let filteredLogs = mockLogs;

      if (event_type) {
        filteredLogs = filteredLogs.filter(log => log.event_type === event_type);
      }

      if (severity) {
        filteredLogs = filteredLogs.filter(log => log.severity === severity);
      }

      res.json({
        success: true,
        data: {
          logs: filteredLogs.slice(0, parseInt(limit as string)),
          total: filteredLogs.length,
          summary: {
            critical_count: mockLogs.filter(l => l.severity === 'critical' && !l.resolved).length,
            unresolved_count: mockLogs.filter(l => !l.resolved).length,
            today_total: mockLogs.filter(l => {
              const logDate = new Date(l.created_at);
              const today = new Date();
              return logDate.toDateString() === today.toDateString();
            }).length
          }
        }
      });
    } catch (error) {
      logger.error('Get event logs error:', error);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }

  async getDashboardStats(req: Request, res: Response) {
    try {
      const envData = this.generateMockData();
      const summary = this.calculateSummary(envData);

      const dashboardStats = {
        environment: {
          ...summary,
          air_quality: summary.avg_pm25 <= 35 ? '优' : summary.avg_pm25 <= 75 ? '良' : summary.avg_pm25 <= 115 ? '轻度污染' : '中度污染'
        },
        fire_safety: {
          active_alarms: 1,
          today_alarms: 3,
          detectors_online: 12,
          detectors_total: 12,
          last_drill: '2026-04-01',
          system_status: 'normal' as const
        },
        devices: {
          total: 32,
          online: 29,
          offline: 1,
          error: 2,
          running: 18,
          maintenance_due: 3
        },
        energy: {
          today_total: 145.9,
          yesterday_total: 152.4,
          savings_percent: 4.3,
          monthly_estimate: 4342.5,
          monthly_cost: 3691.13,
          peak_hour: '19:00-20:00'
        },
        alerts: {
          critical: 1,
          warning: 4,
          info: 5,
          unresolved: 6
        }
      };

      res.json({
        success: true,
        data: dashboardStats
      });
    } catch (error) {
      logger.error('Get dashboard stats error:', error);
      res.status(500).json({ success: false, message: 'Internal server error' });
    }
  }
}

export default new EnvironmentController();
