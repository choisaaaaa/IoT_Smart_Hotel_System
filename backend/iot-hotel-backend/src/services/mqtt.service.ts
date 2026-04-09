import mqtt, { MqttClient, IClientOptions } from 'mqtt';
import config from '../config';
import logger from '../utils/logger';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import { calculateSignature, verifySignature } from '../utils/signature';

interface DeviceStatusPayload {
  device_id: string;
  hotel_id?: number;
  status: string;
  firmware_version?: string;
  signature?: string;
  timestamp?: string;
}

interface SensorDataPayload {
  device_id: string;
  sensor_type: string;
  value: string | number;
  signature?: string;
  timestamp?: string;
}

interface CommandResultPayload {
  device_id: string;
  command_id?: number;
  command_type: string;
  status: 'success' | 'failed' | 'timeout';
  result?: string;
  signature?: string;
  timestamp?: string;
}

class MQTTService {
  private client: MqttClient | null = null;
  private connected: boolean = false;
  private reconnectAttempts: number = 0;
  private maxReconnectAttempts: number = 10;
  private baseReconnectDelay: number = 1000;
  private wsInstance: any = null;

  constructor() {}

  setWebSocket(ws: any) {
    this.wsInstance = ws;
  }

  connect(): Promise<boolean> {
    return new Promise((resolve) => {
      const options: IClientOptions = {
        keepalive: 60,
        clean: true,
        connectTimeout: 10000,
        reconnectPeriod: 0,
        username: config.mqtt.username || undefined,
        password: config.mqtt.password || undefined,
        clientId: `iot_hotel_server_${Date.now()}`,
        rejectUnauthorized: false
      };

      const url = `mqtt://${config.mqtt.host}:${config.mqtt.port}`;
      
      try {
        this.client = mqtt.connect(url, options);
      } catch (error) {
        logger.error(`MQTT连接地址无效: ${url}`, error);
        this.scheduleReconnect();
        resolve(false);
        return;
      }

      this.client.on('connect', () => {
        logger.info('MQTT客户端连接成功');
        this.connected = true;
        this.reconnectAttempts = 0;
        this.subscribeAllTopics();
        resolve(true);
      });

      this.client.on('error', (error) => {
        logger.error('MQTT连接错误:', error.message || error);
        this.connected = false;
      });

      this.client.on('close', () => {
        if (this.connected) {
          logger.info('MQTT连接已关闭');
          this.connected = false;
          this.scheduleReconnect();
        }
      });

      this.client.on('message', async (topic: string, message: Buffer) => {
        const msgStr = message.toString();
        logger.debug(`收到MQTT消息 [${topic}]: ${msgStr}`);
        
        try {
          const data = JSON.parse(msgStr);
          await this.handleMessage(topic, data, message);
        } catch (parseError) {
          logger.warn(`MQTT消息解析失败 [${topic}]: ${msgStr}`);
          await this.handleMessage(topic, { raw: msgStr }, message);
        }
      });
    });
  }

  private scheduleReconnect() {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      logger.warn(`MQTT重连次数已达上限(${this.maxReconnectAttempts})，停止自动重连`);
      return;
    }
    
    const delay = Math.min(
      this.baseReconnectDelay * Math.pow(2, this.reconnectAttempts),
      30000
    );
    
    this.reconnectAttempts++;
    logger.info(`MQTT将在 ${delay/1000}s 后尝试第 ${this.reconnectAttempts} 次重连...`);
    
    setTimeout(() => {
      this.connect().catch(() => {});
    }, delay);
  }

  private subscribeAllTopics() {
    const topics = [
      'hotel/device/status',
      'hotel/device/data/+',
      'hotel/device/command/result',
      'hotel/security/event',
      'hotel/room/control/result',
      'hotel/call/signaling/+',
      'hotel/call/audio/+'
    ];

    topics.forEach((topic) => {
      this.subscribe(topic).catch(() => {});
    });
  }

  async handleMessage(topic: string, data: any, message: Buffer) {
    // 处理通话相关的消息（可能没有标准的 device_id 字段）
    if (topic.startsWith('hotel/call/signaling/')) {
      await this.handleCallSignaling(topic, data);
      return;
    }
    if (topic.startsWith('hotel/call/audio/')) {
      await this.handleCallAudio(topic, message);
      return;
    }

    const deviceId = data.device_id;
    if (!deviceId) {
      logger.warn(`收到缺少 device_id 的消息 [${topic}]`);
      return;
    }

    try {
      // 1. 获取设备信息以检查审核状态和密钥
      const [rows] = await pool.query<RowDataPacket[]>(
        'SELECT audit_status, device_key FROM devices WHERE device_id = ?',
        [deviceId]
      );

      const device = rows[0] as { audit_status: string, device_key: string } | undefined;

      // 2. 只有处于 pending 状态的设备可以发送 status 消息进行注册
      if (!device || device.audit_status !== 'approved') {
        if (topic === 'hotel/device/status' || topic.startsWith('hotel/device/status/')) {
          // 允许注册阶段的状态上报
          await this.handleDeviceStatus(data as DeviceStatusPayload);
          return;
        } else {
          logger.warn(`未审核通过的设备尝试发送数据: ${deviceId} [${topic}]`);
          return;
        }
      }

      // 3. 已通过审核的设备，必须验证签名
      if (!data.signature || !data.timestamp) {
        logger.error(`已审核设备发送消息缺少签名或时间戳: ${deviceId} [${topic}]`);
        return;
      }

      // 验证时间戳（防重放攻击，容忍 5 分钟误差）
      const msgTime = new Date(data.timestamp).getTime();
      const now = Date.now();
      if (isNaN(msgTime) || Math.abs(now - msgTime) > 5 * 60 * 1000) {
        logger.error(`消息时间戳无效或已过期: ${deviceId} [${topic}]`);
        return;
      }

      // 准备待签名的 Payload (排除 signature)
      const { signature, ...payloadWithoutSignature } = data;
      if (!verifySignature(payloadWithoutSignature, signature, device.device_key)) {
        logger.error(`设备消息签名验证失败: ${deviceId} [${topic}]`);
        return;
      }

      // 4. 签名验证通过，处理具体业务逻辑
      switch (topic) {
        case 'hotel/device/status':
        case (topic.startsWith('hotel/device/status/') ? topic : ''):
          await this.handleDeviceStatus(data as DeviceStatusPayload);
          break;
        case 'hotel/device/data/temperature':
        case 'hotel/device/data/humidity':
        case 'hotel/device/data/light':
        case 'hotel/device/data/motion':
        case 'hotel/device/data/door':
          await this.handleSensorData(data as SensorDataPayload);
          break;
        case 'hotel/device/command/result':
          await this.handleCommandResult(data as CommandResultPayload);
          break;
        case 'hotel/security/event':
          await this.handleSecurityEvent(data);
          break;
        default:
          if (topic.startsWith('hotel/device/data/')) {
            await this.handleSensorData(data as SensorDataPayload);
          } else {
            logger.debug(`未处理的MQTT主题: ${topic}`);
          }
      }
    } catch (error) {
      logger.error(`处理MQTT消息时发生错误: ${error}`);
    }
  }

  async handleCallSignaling(topic: string, data: any) {
    const callId = topic.split('/').pop();
    logger.info(`收到硬件通话信令 [${callId}]: ${JSON.stringify(data)}`);
    
    if (this.wsInstance) {
      // 将硬件发出的信令转发给对应的 Web/App 客户端
      // 硬件通常发给与其通话的对象，data 中应包含 target_type 和 target_id
      if (data.target_type && data.target_id) {
        this.wsInstance.emitToClient(data.target_type, data.target_id, 'webrtc_signal', {
          call_id: callId,
          ...data
        });
      }
    }
  }

  async handleCallAudio(topic: string, message: Buffer) {
    const callId = topic.split('/').pop();
    // 硬件发送的是原始音频二进制流
    if (this.wsInstance) {
      // 查找该通话的参与者并转发音频流
      // 这里需要从数据库或内存中查找 callId 对应的接收者
      const [rows] = await pool.query<RowDataPacket[]>(
        'SELECT caller_type, caller_id, callee_type, callee_id FROM calls WHERE call_id = ?',
        [callId]
      );
      
      if (rows.length > 0) {
        const call = rows[0];
        // 假设硬件是 callee (房间)，发给 caller (前台/App)
        this.wsInstance.emitToClient(call.caller_type, call.caller_id, 'audio_chunk', {
          call_id: callId,
          chunk: message
        });
      }
    }
  }

  async handleDeviceStatus(data: DeviceStatusPayload) {
    try {
      const now = new Date();
      const hotelId = data.hotel_id || 1; // 如果未提供，默认归属到 ID 为 1 的酒店
      
      // 使用 INSERT ... ON DUPLICATE KEY UPDATE 兼容新设备注册和旧设备更新
      await pool.query<ResultSetHeader>(
        `INSERT INTO devices (
          device_id, device_type, device_name, device_key, 
          device_status, firmware_version, last_seen, 
          audit_status, hotel_id, created_at, updated_at
        ) VALUES (?, ?, ?, '', ?, ?, ?, 'pending', ?, ?, ?)
        ON DUPLICATE KEY UPDATE 
          device_status = VALUES(device_status),
          last_seen = VALUES(last_seen),
          firmware_version = COALESCE(VALUES(firmware_version), firmware_version),
          hotel_id = VALUES(hotel_id),
          updated_at = VALUES(updated_at)`,
        [
          data.device_id, 
          (data as any).device_type || 'unknown', 
          `New Device ${data.device_id}`, 
          data.status, 
          data.firmware_version || null, 
          now, 
          hotelId,
          now, 
          now
        ]
      );

      logger.info(`设备状态更新 (MQTT): ${data.device_id} -> ${data.status}`);

      this.wsInstance?.emit('device_status_changed', {
        device_id: data.device_id,
        status: data.status,
        timestamp: now.toISOString()
      });
    } catch (error) {
      logger.error('处理设备状态更新失败:', error);
    }
  }

  async handleSensorData(data: SensorDataPayload) {
    try {
      const sensorType = data.sensor_type || 'unknown';
      
      await pool.query<ResultSetHeader>(
        `INSERT INTO sensor_data (device_id, sensor_type, sensor_value, created_at)
         VALUES (?, ?, ?, NOW())
         ON DUPLICATE KEY UPDATE sensor_value = VALUES(sensor_value), created_at = VALUES(created_at)`,
        [data.device_id, sensorType, String(data.value)]
      );

      this.wsInstance?.emit('sensor_data_update', {
        device_id: data.device_id,
        sensor_type: sensorType,
        value: data.value,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      logger.error('处理传感器数据失败:', error);
    }
  }

  async handleCommandResult(data: CommandResultPayload) {
    try {
      if (data.command_id) {
        await pool.query<ResultSetHeader>(
          `UPDATE control_commands SET 
            command_status = ?, 
            executed_at = NOW()
           WHERE id = ?`,
          [data.status, data.command_id]
        );
      }

      logger.info(`指令执行结果: 设备=${data.device_id}, 类型=${data.command_type}, 状态=${data.status}`);

      this.wsInstance?.emit('command_result', {
        device_id: data.device_id,
        command_type: data.command_type,
        status: data.status,
        result: data.result,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      logger.error('处理指令结果失败:', error);
    }
  }

  async handleSecurityEvent(data: any) {
    try {
      await pool.query<ResultSetHeader>(
        `INSERT INTO security_events (device_id, event_type, event_data, event_level, created_at)
         VALUES (?, ?, ?, ?, NOW())`,
        [
          data.device_id || '',
          data.event_type || 'unknown',
          JSON.stringify(data.data || {}),
          data.level || 'info'
        ]
      );

      logger.warn(`安防事件: ${data.event_type} - 设备 ${data.device_id}`);

      this.wsInstance?.emit('security_event', {
        device_id: data.device_id,
        event_type: data.event_type,
        level: data.level || 'info',
        data: data.data,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      logger.error('处理安防事件失败:', error);
    }
  }

  async publish(topic: string, message: object): Promise<boolean> {
    if (!this.connected || !this.client) {
      logger.warn(`MQTT未连接，无法发送消息到 ${topic}`);
      return false;
    }

    return new Promise((resolve) => {
      this.client!.publish(topic, JSON.stringify(message), { qos: 1, retain: false }, (err) => {
        if (err) {
          logger.error(`发送MQTT消息失败 [${topic}]:`, err.message);
          resolve(false);
        } else {
          logger.debug(`发送MQTT消息成功 [${topic}]`);
          resolve(true);
        }
      });
    });
  }

  async publishBinary(topic: string, message: Buffer): Promise<boolean> {
    if (!this.connected || !this.client) {
      logger.warn(`MQTT未连接，无法发送二进制消息到 ${topic}`);
      return false;
    }

    return new Promise((resolve) => {
      this.client!.publish(topic, message, { qos: 0, retain: false }, (err) => {
        if (err) {
          logger.error(`发送MQTT二进制消息失败 [${topic}]:`, err.message);
          resolve(false);
        } else {
          resolve(true);
        }
      });
    });
  }

  async sendDeviceCommand(deviceId: string, commandType: string, commandValue: string, createdBy?: string): Promise<number | null> {
    try {
      // 1. 获取设备密钥以计算签名
      const [rows] = await pool.query<RowDataPacket[]>(
        'SELECT device_key FROM devices WHERE device_id = ? AND audit_status = "approved"',
        [deviceId]
      );

      if (rows.length === 0) {
        logger.warn(`无法向未审核或不存在的设备发送指令: ${deviceId}`);
        return null;
      }

      const { device_key } = rows[0] as { device_key: string };

      // 2. 存入数据库
      const [result] = await pool.query<ResultSetHeader>(
        `INSERT INTO control_commands (device_id, command_type, command_value, command_status, created_by, created_at)
         VALUES (?, ?, ?, 'pending', ?, NOW())`,
        [deviceId, commandType, commandValue, createdBy || 'system']
      );

      const commandId = result.insertId;
      const timestamp = new Date().toISOString();

      // 3. 准备带有签名的消息
      const payload: any = {
        command_id: commandId,
        device_id: deviceId,
        command_type: commandType,
        command_value: commandValue,
        timestamp
      };

      payload.signature = calculateSignature(payload, device_key);

      // 4. 发布到 MQTT
      await this.publish('hotel/device/command', payload);

      logger.info(`发送设备指令 (已签名): #${commandId} -> ${deviceId}/${commandType}=${commandValue}`);
      return commandId;
    } catch (error) {
      logger.error('发送设备指令失败:', error);
      return null;
    }
  }

  async subscribe(topic: string): Promise<boolean> {
    if (!this.connected || !this.client) {
      logger.warn(`MQTT未连接，无法订阅 ${topic}`);
      return false;
    }

    return new Promise((resolve) => {
      this.client!.subscribe(topic, { qos: 1 }, (err) => {
        if (err) {
          logger.error(`订阅MQTT主题失败 [${topic}]:`, err.message);
          resolve(false);
        } else {
          logger.info(`已订阅MQTT主题: ${topic}`);
          resolve(true);
        }
      });
    });
  }

  isConnected(): boolean {
    return this.connected;
  }

  async disconnect() {
    if (this.client && this.connected) {
      try {
        await new Promise<void>((resolve) => {
          this.client!.end(false, () => resolve());
        });
      } catch (e) {}
      this.connected = false;
      logger.info('MQTT客户端已断开');
    }
  }

  async getOnlineDevices(): Promise<any[]> {
    try {
      const [rows] = await pool.query<RowDataPacket[]>(
        "SELECT * FROM devices WHERE device_status = 'online' ORDER BY last_seen DESC"
      );
      return rows;
    } catch (error) {
      logger.error('获取在线设备列表失败:', error);
      return [];
    }
  }

  async getLatestSensorData(deviceId: string, limit: number = 50): Promise<any[]> {
    try {
      const [rows] = await pool.query<RowDataPacket[]>(
        `SELECT * FROM sensor_data WHERE device_id = ? ORDER BY created_at DESC LIMIT ?`,
        [deviceId, limit]
      );
      return rows;
    } catch (error) {
      logger.error('获取传感器数据失败:', error);
      return [];
    }
  }
}

export default new MQTTService();