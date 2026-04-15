import mqtt, { MqttClient, IClientOptions } from 'mqtt';
import config from '../config';
import logger from '../utils/logger';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import { calculateSignature, verifySignature } from '../utils/signature';
import { AIButlerService } from './ai-butler.service';

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
  private callCache: Map<string, { caller_type: string, caller_id: any, callee_type: string, callee_id: any }> = new Map();
  private deviceCache: Map<string, { audit_status: string, device_key: string, hotel_id?: number }> = new Map();

  constructor() {}

  setWebSocket(ws: any) {
    this.wsInstance = ws;
  }

  // 内部辅助方法：获取设备元数据
  private async getDeviceMetadata(deviceId: string) {
    let device = this.deviceCache.get(deviceId);
    
    if (!device) {
      const [rows] = await pool.query<RowDataPacket[]>(
        'SELECT audit_status, device_key, hotel_id FROM devices WHERE device_id = ?',
        [deviceId]
      );
      device = rows[0] as any;
      if (device) {
        this.deviceCache.set(deviceId, device);
        // 缓存10分钟
        setTimeout(() => this.deviceCache.delete(deviceId), 10 * 60 * 1000);
      }
    }
    return device;
  }

  private async logCommunication(topic: string, payload: any, direction: 'in' | 'out', qos: number = 0, retain: boolean = false) {
    try {
      let deviceId = null;
      let hotelId = 0;

      // 尝试从 payload 中提取 device_id
      if (payload && typeof payload === 'object') {
        deviceId = payload.device_id || null;
      } else if (typeof payload === 'string') {
        try {
          const parsed = JSON.parse(payload);
          deviceId = parsed.device_id || null;
        } catch (e) {
          // 不是 JSON，尝试从 topic 中提取
          const parts = topic.split('/');
          if (parts.length > 0) {
            deviceId = parts[parts.length - 1];
          }
        }
      }

      // 如果有 deviceId，尝试获取 hotelId
      if (deviceId) {
        const device = await this.getDeviceMetadata(deviceId);
        if (device) {
          hotelId = device.hotel_id || 0;
        }
      }

      const payloadStr = typeof payload === 'object' ? JSON.stringify(payload) : String(payload);
      
      await pool.query(
        `INSERT INTO mqtt_communication_logs (hotel_id, device_id, topic, payload, direction, qos, retain)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [hotelId, deviceId, topic, payloadStr.substring(0, 5000), direction, qos, retain ? 1 : 0]
      );
    } catch (error) {
      logger.error('记录MQTT通信日志失败:', error.message);
    }
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
        logger.error(`MQTT连接地址无效: ${url} - ${error.message}`);
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

      this.client.on('message', async (topic: string, message: Buffer, packet: any) => {
        // 通话音频流是二进制，不需要 toString 和 JSON.parse
        if (topic.startsWith('hotel/call/audio/')) {
          await this.handleCallAudio(topic, message);
          return;
        }

        const msgStr = message.toString();
        logger.debug(`收到MQTT消息 [${topic}]: ${msgStr}`);

        // 记录入站消息
        await this.logCommunication(topic, msgStr, 'in', packet.qos, packet.retain);
        
        try {
          const data = JSON.parse(msgStr);
          await this.handleMessage(topic, data, message);
        } catch (parseError) {
          // 通话信令通常是 JSON，如果解析失败再作为 raw 处理
          if (topic.startsWith('hotel/call/signaling/')) {
            await this.handleCallSignaling(topic, { raw: msgStr });
          } else {
            logger.warn(`MQTT消息解析失败 [${topic}]: ${msgStr.substring(0, 100)}${msgStr.length > 100 ? '...' : ''}`);
            await this.handleMessage(topic, { raw: msgStr }, message);
          }
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
      'hotel/call/audio/+',
      'hotel/ai/request/room/+'
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
    if (topic.startsWith('hotel/ai/request/room/')) {
      await this.handleAIRequest(topic, data);
      return;
    }

    const deviceId = data.device_id;
    if (!deviceId) {
      logger.warn(`收到缺少 device_id 的消息 [${topic}]`);
      return;
    }

    try {
      // 1. 获取设备元数据
      const device = await this.getDeviceMetadata(deviceId);

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
          await this.handleSensorData(data as SensorDataPayload, device.hotel_id);
          break;
        case 'hotel/device/command/result':
          await this.handleCommandResult(data as CommandResultPayload, device.hotel_id);
          break;
        case 'hotel/security/event':
          await this.handleSecurityEvent(data, device.hotel_id);
          break;
        default:
          if (topic.startsWith('hotel/device/data/')) {
            await this.handleSensorData(data as SensorDataPayload, device.hotel_id);
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
    if (!callId) return;

    // 硬件发送的是原始音频二进制流
    if (this.wsInstance) {
      let call = this.callCache.get(callId);
      
      if (!call) {
        // 只有缓存不中时才查询数据库
        const [rows] = await pool.query<RowDataPacket[]>(
          'SELECT caller_type, caller_id, callee_type, callee_id FROM calls WHERE call_id = ?',
          [callId]
        );
        
        if (rows.length > 0) {
          call = rows[0] as any;
          this.callCache.set(callId, call!);
          
          // 设置定时清理，防止内存泄漏（30分钟后过期）
          setTimeout(() => this.callCache.delete(callId), 30 * 60 * 1000);
        }
      }
      
      if (call) {
        // 硬件通常是 callee (房间)，发给 caller (前台/App)
        this.wsInstance.emitToClient(call.caller_type, call.caller_id, 'audio_chunk', {
          call_id: callId,
          chunk: message
        });
      }
    }
  }

  async handleAIRequest(topic: string, data: any) {
    const roomId = topic.split('/').pop();
    if (!roomId) return;

    logger.info(`收到硬件端 AI 请求 [房间 ${roomId}]: ${JSON.stringify(data)}`);

    try {
      const aiButler = AIButlerService.getInstance();
      
      // 如果硬件发送的是音频数据（base64）
      const aiResponse = await aiButler.processRequest({
        roomId: roomId,
        audioData: data.audio_data, // 假设硬件发送 audio_data 字段
        text: data.text,           // 或者直接发送识别好的文字
        sessionId: data.session_id || `hw_${roomId}_${Date.now()}`
      });

      // 将 AI 的回复发送回硬件
      const responseTopic = `hotel/ai/response/room/${roomId}`;
      await this.publish(responseTopic, {
        text: aiResponse.text,
        audio_data: aiResponse.audioUrl, // processRequest 返回的是 base64 字符串
        action: aiResponse.action,
        ticket_data: aiResponse.ticketData
      });

      logger.info(`已发送 AI 回复到硬件 [房间 ${roomId}]`);
    } catch (error) {
      logger.error(`处理硬件 AI 请求失败: ${error.message}`);
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

      // 关键修复：设备状态更新只发送给所属酒店的前台
      if (hotelId && this.wsInstance) {
        const hotelRoom = `front_desk_hotel_${hotelId}`;
        this.wsInstance.emit('device_status_changed', {
          device_id: data.device_id,
          status: data.status,
          timestamp: now.toISOString()
        }, hotelRoom);
      }
    } catch (error) {
      logger.error('处理设备状态更新失败:', error.message);
    }
  }

  async handleSensorData(data: SensorDataPayload, hotelId?: number) {
    try {
      const sensorType = data.sensor_type || 'unknown';
      
      await pool.query<ResultSetHeader>(
        `INSERT INTO sensor_data (device_id, sensor_type, sensor_value, created_at)
         VALUES (?, ?, ?, NOW())
         ON DUPLICATE KEY UPDATE sensor_value = VALUES(sensor_value), created_at = VALUES(created_at)`,
        [data.device_id, sensorType, String(data.value)]
      );

      // 关键修复：传感器数据更新只发送给所属酒店的前台
      if (hotelId && this.wsInstance) {
        const hotelRoom = `front_desk_hotel_${hotelId}`;
        this.wsInstance.emit('sensor_data_update', {
          device_id: data.device_id,
          sensor_type: sensorType,
          value: data.value,
          timestamp: new Date().toISOString()
        }, hotelRoom);
      }
    } catch (error) {
      logger.error('处理传感器数据失败:', error.message);
    }
  }

  async handleCommandResult(data: CommandResultPayload, hotelId?: number) {
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

      // 关键修复：指令结果只发送给所属酒店的前台
      if (hotelId && this.wsInstance) {
        const hotelRoom = `front_desk_hotel_${hotelId}`;
        this.wsInstance.emit('command_result', {
          device_id: data.device_id,
          command_type: data.command_type,
          status: data.status,
          result: data.result,
          timestamp: new Date().toISOString()
        }, hotelRoom);
      }
    } catch (error) {
      logger.error('处理指令结果失败:', error.message);
    }
  }

  async handleSecurityEvent(data: any, hotelId?: number) {
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

      // 关键修复：安防事件只发送给所属酒店的前台
      if (hotelId && this.wsInstance) {
        const hotelRoom = `front_desk_hotel_${hotelId}`;
        this.wsInstance.emit('security_event', {
          device_id: data.device_id,
          event_type: data.event_type,
          level: data.level || 'info',
          data: data.data,
          timestamp: new Date().toISOString()
        }, hotelRoom);
      }
    } catch (error) {
      logger.error('处理安防事件失败:', error.message);
    }
  }

  async publish(topic: string, message: object, qos: number = 1, retain: boolean = false): Promise<boolean> {
    if (!this.connected || !this.client) {
      logger.warn(`MQTT未连接，无法发送消息到 ${topic}`);
      return false;
    }

    return new Promise((resolve) => {
      this.client!.publish(topic, JSON.stringify(message), { qos: qos as any, retain }, (err) => {
        if (err) {
          logger.error(`发送MQTT消息失败 [${topic}]:`, err.message);
          resolve(false);
        } else {
          logger.debug(`发送MQTT消息成功 [${topic}]`);
          // 异步记录出站日志
          this.logCommunication(topic, message, 'out', qos, retain).catch(() => {});
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
          // 二进制消息通常很大（如音频），不记录完整 payload，只记录 topic
          this.logCommunication(topic, '[Binary Data]', 'out', 0, false).catch(() => {});
          resolve(true);
        }
      });
    });
  }

  async getCommunicationLogs(hotelId?: number, deviceId?: string, limit: number = 100, offset: number = 0): Promise<any[]> {
    try {
      let query = 'SELECT * FROM mqtt_communication_logs';
      const params: any[] = [];
      const conditions: string[] = [];

      if (hotelId !== undefined && hotelId !== 0) {
        conditions.push('hotel_id = ?');
        params.push(hotelId);
      }

      if (deviceId) {
        conditions.push('device_id = ?');
        params.push(deviceId);
      }

      if (conditions.length > 0) {
        query += ' WHERE ' + conditions.join(' AND ');
      }

      query += ' ORDER BY timestamp DESC LIMIT ? OFFSET ?';
      params.push(limit, offset);

      const [rows] = await pool.query<RowDataPacket[]>(query, params);
      return rows;
    } catch (error) {
      logger.error('获取MQTT通信日志失败:', error.message);
      return [];
    }
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
      logger.error('发送设备指令失败:', error.message);
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
      logger.error('获取在线设备列表失败:', error.message);
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
      logger.error('获取传感器数据失败:', error.message);
      return [];
    }
  }
}

export default new MQTTService();