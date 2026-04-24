import mqtt, { MqttClient, IClientOptions } from 'mqtt';
import fs from 'fs';
import config from '../config';
import logger from '../utils/logger';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import { calculateSignature, verifySignature, sortObject } from '../utils/signature';
import { verifyDeviceKey, getRawKeyForSigning } from '../utils/device-key';
import { AIButlerService } from './ai-butler.service';
import { getVoiceGateway } from './voice-gateway.service';

import CacheService from './cache.service';

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
  private deviceCache: Map<string, { audit_status: string, device_key: string, device_key_encrypted?: string, hotel_id?: number, room_id?: number }> = new Map();

  constructor() {
    this.startOfflineCheck();
  }

  private startOfflineCheck() {
    const OFFLINE_TIMEOUT_MS = 5 * 60 * 1000;
    const CHECK_INTERVAL_MS = 60 * 1000;

    setInterval(async () => {
      try {
        const [rows] = await pool.query<RowDataPacket[]>(
          `SELECT device_id FROM devices WHERE device_status = 'online' AND last_seen < DATE_SUB(NOW(), INTERVAL 5 MINUTE)`
        );
        if (rows.length > 0) {
          const deviceIds = rows.map((r: any) => r.device_id);
          await pool.query(
            `UPDATE devices SET device_status = 'offline', updated_at = NOW() WHERE device_status = 'online' AND last_seen < DATE_SUB(NOW(), INTERVAL 5 MINUTE)`
          );
          logger.info(`心跳超时离线检测: ${deviceIds.join(', ')} 已标记为离线`);
        }
      } catch (error) {
        logger.error('心跳超时离线检测失败:', (error as Error).message);
      }
    }, CHECK_INTERVAL_MS);
  }

  setWebSocket(ws: any) {
    this.wsInstance = ws;
  }

  // 内部辅助方法：获取设备元数据
  private async getDeviceMetadata(deviceId: string) {
    let device = this.deviceCache.get(deviceId);

    if (!device) {
      const [rows] = await pool.query<RowDataPacket[]>(
        'SELECT audit_status, device_key, device_key_encrypted, hotel_id, room_id FROM devices WHERE device_id = ?',
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
      // 根据环境配置TLS选项
      const isProduction = process.env.NODE_ENV === 'production';
      const useTLS = process.env.MQTT_USE_TLS === 'true' || isProduction;

      const options: IClientOptions = {
        keepalive: 60,
        clean: true,
        connectTimeout: 10000,
        reconnectPeriod: 0,
        username: config.mqtt.username || undefined,
        password: config.mqtt.password || undefined,
        clientId: `iot_hotel_server_${Date.now()}`,
        rejectUnauthorized: isProduction ? true : false // 生产环境必须验证证书
      };

      // 配置TLS证书
      if (useTLS) {
        try {
          const caPath = process.env.MQTT_CA_CERT_PATH;
          const certPath = process.env.MQTT_CLIENT_CERT_PATH;
          const keyPath = process.env.MQTT_CLIENT_KEY_PATH;

          if (caPath && fs.existsSync(caPath)) {
            options.ca = fs.readFileSync(caPath);
            logger.info('MQTT TLS CA证书已加载');
          } else if (isProduction) {
            logger.warn('生产环境建议配置MQTT CA证书');
          }

          if (certPath && keyPath && fs.existsSync(certPath) && fs.existsSync(keyPath)) {
            options.cert = fs.readFileSync(certPath);
            options.key = fs.readFileSync(keyPath);
            logger.info('MQTT TLS客户端证书已加载');
          }
        } catch (error) {
          logger.error('加载MQTT TLS证书失败:', error.message);
        }
      }

      const protocol = useTLS ? 'mqtts' : 'mqtt';
      const port = useTLS ? (parseInt(config.mqtt.port as any) || 8883) : (parseInt(config.mqtt.port as any) || 1883);
      const url = `${protocol}://${config.mqtt.host}:${port}`;

      logger.info(`MQTT连接地址: ${url}`);
      logger.info(`MQTT配置: host=${config.mqtt.host}, port=${port}, username=${config.mqtt.username || '无'}`);

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
        logger.error('MQTT连接配置:', {
          host: config.mqtt.host,
          port: config.mqtt.port,
          username: config.mqtt.username ? '已设置' : '未设置',
          password: config.mqtt.password ? '已设置' : '未设置'
        });
        this.connected = false;
      });

      this.client.on('close', () => {
        if (this.connected) {
          logger.info('MQTT连接已关闭');
          this.connected = false;
          this.scheduleReconnect();
        }
      });

      this.client.on('message', (topic: string, message: Buffer, packet: any) => {
        // 通话音频流是二进制，不需要 toString 和 JSON.parse
        // 统一格式: hotel/device/call/{callId}/up
        // 旧格式: hotel/call/audio/{callId}/up
        if (topic.startsWith('hotel/device/call/') && topic.endsWith('/up')) {
          this.handleCallAudio(topic, message).catch(err => 
            logger.error(`[Audio] 转发失败: ${err.message}`)
          );
          return;
        }
        // 兼容旧格式
        if (topic.startsWith('hotel/call/audio/') && topic.endsWith('/up')) {
          this.handleCallAudio(topic, message).catch(err => 
            logger.error(`[Audio] 转发失败: ${err.message}`)
          );
          return;
        }

        // 客房语音 Agent 上行：JSON+PCM，无签名（固件用 publish_silent）→ 语音助手桥
        if (topic.startsWith('hotel/device/audio/uplink/')) {
          const msgStr = message.toString();
          this.logCommunication(topic, msgStr, 'in', packet.qos, packet.retain).catch(() => {});
          try {
            const data = JSON.parse(msgStr);
            // 动态 import 避免 mqtt.service ↔ voice-agent-bridge 循环依赖
            void import('./voice-agent-bridge.service')
              .then((m) => m.getVoiceAgentBridge().handleUplinkMessage(topic, data))
              .catch((err) => logger.error(`[VoiceAgentBridge] 处理失败: ${(err as Error).message}`));
          } catch (e) {
            logger.warn(`[VoiceAgentBridge] JSON 解析失败: ${topic}`);
          }
          return;
        }

        const processMessage = async () => {
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
        };

        processMessage().catch(err => {
          logger.error(`处理MQTT消息异常 [${topic}]:`, err);
        });
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
      // 统一主题格式: hotel/device/{category}/{type}/{id}
      'hotel/device/status/+/+',           // 设备状态上报
      'hotel/device/data/+/+',             // 传感器数据上报：hotel/device/data/{sensor_type}/{device_id}
      'hotel/device/command/result',       // 指令执行结果
      'hotel/device/security/event',       // 安防事件
      'hotel/device/call/+/up',            // 通话信令/音频上行（统一格式）
      'hotel/device/call/+/down',          // 通话下行
      'hotel/device/audio/uplink/+',        // 客房语音上行（Agent/通话 JSON+PCM，见 voice_session.c）
      'hotel/device/ai/request/+',         // AI语音请求
      'hotel/device/service/delivery/+',   // 送物服务请求
      'hotel/device/service/maintenance/+',// 维修服务请求
      'hotel/device/service/+/status'      // 服务状态查询
    ];

    topics.forEach((topic) => {
      this.subscribe(topic).catch(() => {});
    });

    // 兼容性订阅旧格式主题（向后兼容，逐步废弃）
    const legacyTopics = [
      'hotel/device/status',
      'hotel/security/event',
      'hotel/room/+/scene',
      'hotel/call/signaling/+',
      'hotel/call/audio/+/up',
      'hotel/ai/request/room/+',
      'hotel/service/delivery/+/request',
      'hotel/service/maintenance/+/request',
      'hotel/service/room/+/status'
    ];

    legacyTopics.forEach((topic) => {
      this.subscribe(topic).catch(() => {});
    });

    logger.info('已订阅MQTT主题（统一格式+兼容旧格式）');
  }

  /**
   * 清除特定设备的元数据缓存，通常在后台审核状态变更后调用
   */
  public clearDeviceCache(deviceId: string) {
    this.deviceCache.delete(deviceId);
    logger.info(`[MQTT] 已手动清除设备缓存: ${deviceId}`);
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
    // 处理客房服务相关消息
    if (topic.startsWith('hotel/service/')) {
      await this.handleServiceRequest(topic, data);
      return;
    }
    // 处理房间场景控制
    if (topic.startsWith('hotel/room/') && topic.endsWith('/scene')) {
      await this.handleSceneControl(topic, data);
      return;
    }

    // 统一主题格式: hotel/device/{category}/{type}/{id}
    // 从主题中提取 device_id（如果 payload 中没有）
    const deviceId = data.device_id || this.extractDeviceIdFromTopic(topic);
    if (!deviceId) {
      logger.warn(`收到缺少 device_id 的消息 [${topic}]`);
      return;
    }

    try {
      // 1. 获取设备元数据
      const device = await this.getDeviceMetadata(deviceId);

      // 2. 只有处于 pending 状态的设备可以发送 status 消息进行注册
      if (!device || device.audit_status !== 'approved') {
        if (topic.startsWith('hotel/device/status')) {
          // 允许注册阶段的状态上报
          await this.handleDeviceStatus(data as DeviceStatusPayload);
          return;
        } else if (topic.startsWith('hotel/call/') || topic.startsWith('hotel/device/data/')) {
          // 关键修复：允许通话信令、音频流以及基础传感器数据通过（即时预览需求）
          // 传感器数据允许通过是为了让 Web 端在审核前也能看到设备“在线”并有数据波动
          if (topic.startsWith('hotel/call/')) {
            logger.info(`允许未审核设备发送通话数据: ${deviceId} [${topic}]`);
            if (topic.startsWith('hotel/call/signaling/')) {
              await this.handleCallSignaling(topic, data);
            }
          }
        } else {
          logger.warn(`未审核通过的设备尝试发送业务指令: ${deviceId} [${topic}]`);
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
      
      // 获取用于签名的原始密钥（支持新的加密存储格式）
      // device_key_encrypted 存储 AES 加密的原始密钥，device_key 存储哈希值
      const encryptedKey = device.device_key_encrypted || device.device_key;
      const signingKey = getRawKeyForSigning(encryptedKey, device.device_key);
      if (!signingKey) {
        logger.error(`设备 ${deviceId} 无法获取签名密钥`);
        return;
      }
      
      // 调试日志：打印实际接收的数据和计算的签名
      const calculatedSig = calculateSignature(payloadWithoutSignature, signingKey);
      const signingPayloadStr = JSON.stringify(sortObject(payloadWithoutSignature));
      logger.info(`[签名调试] 设备: ${deviceId}, 主题: ${topic}`);
      logger.info(`[签名调试] 原始消息: ${JSON.stringify(data)}`);
      logger.info(`[签名调试] 签名原文: ${signingPayloadStr}`);
      logger.info(`[签名调试] 签名密钥: ${signingKey.substring(0, 8)}...`);
      logger.info(`[签名调试] 接收到的签名: ${signature}`);
      logger.info(`[签名调试] 计算的签名: ${calculatedSig}`);
      logger.info(`[签名调试] 数据类型: value=${typeof data.value}, timestamp=${typeof data.timestamp}`);
      
      if (!verifySignature(payloadWithoutSignature, signature, signingKey)) {
        logger.error(`设备消息签名验证失败: ${deviceId} [${topic}]`);
        logger.error(`期望签名: ${calculatedSig}`);
        logger.error(`实际签名: ${signature}`);
        return;
      }

      // 4. 签名验证通过，处理具体业务逻辑
      // 统一采用硬件端主题格式: hotel/device/{category}/{type}/{id}
      if (topic.startsWith('hotel/device/status')) {
        await this.handleDeviceStatus(data as DeviceStatusPayload);
      } else if (topic.startsWith('hotel/device/data/')) {
        await this.handleSensorData(data as SensorDataPayload, device.hotel_id);
      } else if (topic.startsWith('hotel/device/command/result')) {
        await this.handleCommandResult(data as CommandResultPayload, device.hotel_id);
      } else if (topic.startsWith('hotel/security/event') || topic.includes('security/event')) {
        await this.handleSecurityEvent(data, device.hotel_id);
      } else {
        logger.debug(`未处理的MQTT主题: ${topic}`);
      }
    } catch (error) {
      logger.error(`处理MQTT消息时发生错误: ${error}`);
    }
  }

  /**
   * 从MQTT主题中提取device_id
   * 支持格式:
   * - hotel/device/status/{type}/{id} -> id
   * - hotel/device/data/{type} -> 从payload获取
   * - hotel/device/command/{type}/{id} -> id
   */
  private extractDeviceIdFromTopic(topic: string): string | null {
    const parts = topic.split('/');
    // hotel/device/status/{type}/{id}
    if (parts.length >= 5 && parts[1] === 'device' && parts[2] === 'status') {
      return parts[4];
    }
    // hotel/device/command/{type}/{id}
    if (parts.length >= 5 && parts[1] === 'device' && parts[2] === 'command') {
      return parts[4];
    }
    return null;
  }

  async handleCallSignaling(topic: string, data: any) {
    // 统一格式: hotel/device/call/{callId}/up
    // 旧格式: hotel/call/signaling/{callId}
    let callId = '';
    const parts = topic.split('/');
    if (topic.startsWith('hotel/device/call/')) {
      callId = parts[3]; // hotel/device/call/{callId}/up
    } else {
      callId = parts.pop() || ''; // hotel/call/signaling/{callId}
    }
    
    if (!callId) {
      logger.warn('通话信令缺少callId:', topic);
      return;
    }

    logger.info(`收到硬件通话信令 [${callId}]: ${JSON.stringify(data)}`);

    // 将信令传递给语音网关进行WebRTC桥接
    const voiceGateway = getVoiceGateway();
    voiceGateway.handleMqttMessage(topic, data);

    if (data.action === 'initiate') {
      // 硬件发起呼叫，创建通话记录并通知前台
      try {
        const caller_type = data.caller_type || 'room';
        const caller_id = data.caller_id;
        const callee_type = data.callee_type || 'front_desk';
        const callee_id = data.callee_id || 'all';
        
        // 获取房间所属酒店ID和真实房号
        const [roomRows] = await pool.query<RowDataPacket[]>(
          'SELECT id, room_number, hotel_id FROM rooms WHERE room_number = ? OR id = ?',
          [caller_id, caller_id]
        );
        
        const roomInfo = roomRows[0];
        const hotelId = roomInfo ? roomInfo.hotel_id : 1;
        const realRoomNumber = roomInfo ? roomInfo.room_number : caller_id;
        const dbRoomId = roomInfo ? roomInfo.id : caller_id;

        // 写入数据库
        await pool.query(
          `INSERT INTO calls (call_id, caller_type, caller_id, callee_type, callee_id, hotel_id, status, started_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, NOW())`,
          [callId, caller_type, dbRoomId, callee_type, callee_id, hotelId, 'calling']
        );

        // 通知所有在线前台
        if (this.wsInstance) {
          const hotelRoom = `front_desk_hotel_${hotelId}`;
          this.wsInstance.emit('incoming_call', {
            call_id: callId,
            caller_type,
            caller_id: realRoomNumber,
            callee_type,
            callee_id,
            created_at: new Date().toISOString()
          }, hotelRoom);
          logger.info(`[MQTT -> WS] 转发硬件呼叫请求到前台: ${hotelRoom}, 房号: ${realRoomNumber}`);
        }
      } catch (error) {
        logger.error('处理硬件发起呼叫失败:', error.message);
      }
      return;
    }

    if (data.action === 'hangup') {
      // 硬件发起挂断，更新数据库并通知Web端
      try {
        await pool.query(
          "UPDATE calls SET status = 'ended', ended_at = NOW() WHERE call_id = ?",
          [callId]
        );
        
        const [callRows] = await pool.query<RowDataPacket[]>(
          'SELECT caller_type, caller_id, callee_type, callee_id, hotel_id FROM calls WHERE call_id = ?',
          [callId]
        );
        
        if (callRows.length > 0) {
          const call = callRows[0] as any;
          if (this.wsInstance) {
            const hotelRoom = `front_desk_hotel_${call.hotel_id}`;
            this.wsInstance.emit('call_hungup', { call_id: callId }, hotelRoom);
            logger.info(`[MQTT -> WS] 转发硬件挂断信号到前台: ${hotelRoom}`);
          }
        }
      } catch (error) {
        logger.error('处理硬件挂断失败:', error.message);
      }
      return;
    }

    if (this.wsInstance) {
      // 将硬件发出的信令转发给对应的Web/App客户端
      if (data.target_type && data.target_id) {
        let eventName = 'webrtc_signal';
        if (data.offer) eventName = 'webrtc_offer';
        else if (data.answer) eventName = 'webrtc_answer';
        else if (data.candidate) eventName = 'webrtc_ice_candidate';

        this.wsInstance.emitToClient(data.target_type, data.target_id, eventName, {
          call_id: callId,
          from_type: 'room',
          from_id: data.device_id || '',
          ...data
        });
      }
    }
  }

  async handleCallAudio(topic: string, message: Buffer) {
    // 主题格式: hotel/call/audio/{callId}/up
    const parts = topic.split('/');
    const callId = parts[parts.length - 2];
    if (!callId) {return;}

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
        // 确定接收方：如果硬件是主叫，发给被叫；如果硬件是被叫，发给主叫
        // 由于是从 MQTT 来的，说明发送方是硬件（房间）
        const isHardwareCaller = call.caller_type === 'room';
        const targetType = isHardwareCaller ? call.callee_type : call.caller_type;
        const targetId = isHardwareCaller ? call.callee_id : call.caller_id;

        this.wsInstance.emitToClient(targetType, targetId, 'audio_chunk', {
          call_id: callId,
          chunk: message
        });
      }
    }
  }

  async handleAIRequest(topic: string, data: any) {
    const roomId = topic.split('/').pop();
    if (!roomId) {return;}

    logger.info(`收到硬件端 AI 请求 [房间 ${roomId}]: text=${data.text || '(音频)'}`);

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
        response: aiResponse.text,
        audio_base64: aiResponse.audioUrl, // ai-butler.service.ts 中返回的是 base64 字符串，对应这里的 audio_base64
        actions: aiResponse.action ? [{ type: aiResponse.action }] : [],
        ticket_data: aiResponse.ticketData
      });

      logger.info(`已发送 AI 回复到硬件 [房间 ${roomId}] (长度:${(aiResponse.text||'').length})`);
    } catch (error) {
      logger.error(`处理硬件 AI 请求失败: ${error.message}`);
    }
  }

  async handleDeviceStatus(data: DeviceStatusPayload) {
    try {
      const now = new Date();
      const hotelId = data.hotel_id || 1; 

      // 自动识别设备类型
      let deviceType = (data as any).device_type;
      if (!deviceType || deviceType === 'unknown') {
        if (data.device_id.startsWith('ROO_')) {deviceType = 'room';}
        else if (data.device_id.startsWith('FLO_')) {deviceType = 'floor_controller';}
        else if (data.device_id.startsWith('FRN_')) {deviceType = 'front_desk';}
        else {deviceType = 'unknown';}
      }

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
          hotel_id = COALESCE(hotel_id, VALUES(hotel_id)),
          updated_at = VALUES(updated_at)`,
        [
          data.device_id,
          deviceType,
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

      // 清除相关缓存，确保设备列表和信息即时更新
      await CacheService.delete(CacheService.deviceKeys.pending());
      await CacheService.deletePattern('device:list:*');

      // 关键修复：设备状态更新只发送给所属酒店的前台
      if (hotelId && this.wsInstance) {
        const hotelRoom = `front_desk_hotel_${hotelId}`;
        this.wsInstance.emit('device_status_changed', {
          device_id: data.device_id,
          status: data.status,
          timestamp: now.toISOString()
        }, hotelRoom);
        
        // 同时触发全量在线状态广播，确保语音通话清单即时更新
        this.wsInstance.broadcastOnlineStatus().catch(err => 
          logger.error('状态更新时广播失败:', err.message)
        );
      }
    } catch (error) {
      logger.error('处理设备状态更新失败:', error.message);
    }
  }

  async handleSensorData(data: SensorDataPayload, hotelId?: number) {
    try {
      const sensorType = data.sensor_type || 'unknown';

      // 1. 更新或插入传感器最新值
      await pool.query<ResultSetHeader>(
        `INSERT INTO sensor_data (device_id, sensor_type, sensor_value, created_at)
         VALUES (?, ?, ?, NOW())
         ON DUPLICATE KEY UPDATE sensor_value = VALUES(sensor_value), created_at = VALUES(created_at)`,
        [data.device_id, sensorType, String(data.value)]
      );

      // 2. 更新设备活跃时间并确保状态为 online
      await pool.query(
        `UPDATE devices SET last_seen = NOW(), device_status = 'online', updated_at = NOW() WHERE device_id = ?`,
        [data.device_id]
      );

      // 3. 获取最新的设备元数据（可能刚插入或更新了状态）
      const device = await this.getDeviceMetadata(data.device_id);
      const effectiveHotelId = hotelId || (device ? device.hotel_id : 1);

      if (effectiveHotelId && this.wsInstance) {
        const hotelRoom = `front_desk_hotel_${effectiveHotelId}`;
        this.wsInstance.emit('sensor_data_update', {
          device_id: data.device_id,
          sensor_type: sensorType,
          value: data.value,
          timestamp: new Date().toISOString()
        }, hotelRoom);

        // 触发全量在线状态广播，确保设备在掉线重连后能即时出现在清单
        this.wsInstance.broadcastOnlineStatus().catch(() => {});
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

  /** 合并客房 event_data、固件 data、以及 detail 文本，写入 data 供后续统一使用 */
  private normalizeSecurityEventPayload(data: any): void {
    const merged: Record<string, any> = {};
    if (data.data && typeof data.data === 'object' && !Array.isArray(data.data)) {
      Object.assign(merged, data.data);
    }
    if (data.event_data != null) {
      let ev = data.event_data;
      if (typeof ev === 'string') {
        try {
          ev = JSON.parse(ev);
        } catch {
          ev = {};
        }
      }
      if (ev && typeof ev === 'object' && !Array.isArray(ev)) {
        Object.assign(merged, ev);
      }
    }
    if (data.detail && typeof data.detail === 'string' && !merged.message) {
      merged.message = data.detail;
    }
    data.data = merged;
  }

  /** room_id 可能是房号字符串或错误的数据库 id，按酒店归一到 rooms.id */
  private async resolveRoomDbId(hotelId: number, raw: any): Promise<number | null> {
    if (raw === undefined || raw === null || raw === '') {
      return null;
    }
    const s = String(raw).trim();
    if (!s) {
      return null;
    }
    const n = parseInt(s, 10);
    try {
      if (hotelId && hotelId !== 0) {
        const [byNum] = await pool.query<RowDataPacket[]>(
          'SELECT id FROM rooms WHERE hotel_id = ? AND (room_number = ? OR id = ?)',
          [hotelId, s, Number.isNaN(n) ? -1 : n]
        );
        if (byNum.length > 0) {
          return (byNum[0] as any).id as number;
        }
      } else {
        const [byNum] = await pool.query<RowDataPacket[]>(
          'SELECT id FROM rooms WHERE room_number = ? OR id = ?',
          [s, Number.isNaN(n) ? -1 : n]
        );
        if (byNum.length > 0) {
          return (byNum[0] as any).id as number;
        }
      }
    } catch (e) {
      logger.warn('resolveRoomDbId failed:', (e as Error).message);
    }
    return null;
  }

  private normalizeAlarmLevelForDb(level: string | undefined): string {
    const l = (level || 'warning').toLowerCase();
    if (l === 'critical' || l === 'alarm') {
      return 'emergency';
    }
    if (l === 'emergency') {
      return 'emergency';
    }
    if (l === 'warning') {
      return 'warning';
    }
    if (l === 'info') {
      return 'info';
    }
    return 'warning';
  }

  async handleSecurityEvent(data: any, hotelId?: number) {
    try {
      this.normalizeSecurityEventPayload(data);
      const merged = data.data || {};

      await pool.query<ResultSetHeader>(
        `INSERT INTO security_events (device_id, event_type, event_data, event_level, created_at)
         VALUES (?, ?, ?, ?, NOW())`,
        [
          data.device_id || '',
          data.event_type || 'unknown',
          JSON.stringify(merged),
          data.level || 'info'
        ]
      );

      logger.warn(`安防事件: ${data.event_type} - 设备 ${data.device_id}, hotelId: ${hotelId}`);

      const et = data.event_type || '';
      const alarmTypesForDeviceAlarms = [
        'fire_alarm',
        'sos_alarm',
        'room_sos_pressed',
        'front_alarm_triggered',
        'floor_fire_suspected',
        'floor_alarm_pressed'
      ];

      if (alarmTypesForDeviceAlarms.includes(et)) {
        try {
          let resolvedHotelId = hotelId;
          let roomId: number | null = null;

          if (!resolvedHotelId || resolvedHotelId === 0) {
            const device = await this.getDeviceMetadata(data.device_id);
            resolvedHotelId = device?.hotel_id || 0;
            roomId = device?.room_id ?? null;
          }

          if (merged.room_id !== undefined && merged.room_id !== null && merged.room_id !== '') {
            const rid = await this.resolveRoomDbId(resolvedHotelId || 0, merged.room_id);
            if (rid != null) {
              roomId = rid;
            }
          }

          let alarmTypeDb = 'sos_alarm';
          if (et === 'fire_alarm' || et === 'floor_fire_suspected') {
            alarmTypeDb = 'fire';
          } else if (et === 'floor_alarm_pressed') {
            alarmTypeDb = 'manual';
          }

          const alarmLevelDb = this.normalizeAlarmLevelForDb(data.level);
          const defaultMsg =
            et === 'fire_alarm' || et === 'floor_fire_suspected'
              ? '消防报警触发'
              : et === 'floor_alarm_pressed'
                ? '楼道报警按钮触发'
                : 'SOS报警触发';

          const [result] = await pool.query<ResultSetHeader>(
            `INSERT INTO device_alarms (device_id, hotel_id, room_id, alarm_type, alarm_level, alarm_content, status, created_at)
             VALUES (?, ?, ?, ?, ?, ?, 'pending', NOW())`,
            [
              data.device_id || '',
              resolvedHotelId || 0,
              roomId,
              alarmTypeDb,
              alarmLevelDb,
              merged.message || data.description || defaultMsg
            ]
          );
          logger.info(`[MQTT] ${et} 已同步到 device_alarms 表, alarm_id: ${result.insertId}`);

          data.data = { ...merged, alarm_id: result.insertId };
        } catch (alarmError) {
          logger.error(`[MQTT] 同步 ${et} 到 device_alarms 失败:`, (alarmError as Error).message);
        }
      }
      
      // 处理火警消警事件
      if (data.event_type === 'fire_alarm_cleared' || data.event_type === 'alarm_reset') {
        try {
          // 获取设备信息以确定酒店ID
          let resolvedHotelId = hotelId;
          if (!resolvedHotelId || resolvedHotelId === 0) {
            const device = await this.getDeviceMetadata(data.device_id);
            resolvedHotelId = device?.hotel_id || 0;
          }
          
          // 更新该设备相关的待处理报警为已解决
          const [updateResult] = await pool.query<ResultSetHeader>(
            `UPDATE device_alarms 
             SET status = 'resolved', handled_at = NOW(), handle_remark = ?
             WHERE device_id = ? AND status = 'pending' AND alarm_type = 'fire'`,
            [`设备自动消警: ${data.data?.message || '报警解除'}`, data.device_id]
          );
          
          logger.info(`[MQTT] 火警消警处理完成, device_id: ${data.device_id}, 更新记录数: ${updateResult.affectedRows}`);
          
          // 发送消警事件到前端
          if (resolvedHotelId && resolvedHotelId !== 0 && this.wsInstance) {
            const hotelRoom = `front_desk_hotel_${resolvedHotelId}`;
            this.wsInstance.emit('security_event', {
              device_id: data.device_id,
              event_type: 'fire_alarm_cleared',
              level: 'info',
              data: {
                message: data.data?.message || '火警已解除',
                cleared_at: new Date().toISOString(),
                cleared_by: 'device'
              },
              timestamp: new Date().toISOString(),
              hotel_id: resolvedHotelId
            }, hotelRoom);
            logger.info(`[MQTT] 消警事件已发送到: ${hotelRoom}`);
          }
        } catch (clearError) {
          logger.error(`[MQTT] 处理火警消警失败:`, clearError.message);
        }
      }

      // 如果是发卡器感应到卡片，更新设备的 last_card_uid，并尝试下发同步指令
      if (data.event_type === 'card_uid_detected' && data.card_uid) {
        const cardUid = data.card_uid;
        const deviceId = data.device_id;
        
        // 关键修复：确保 hotelId 有效
        let resolvedHotelId = hotelId;
        if (!resolvedHotelId || resolvedHotelId === 0) {
          const device = await this.getDeviceMetadata(deviceId);
          resolvedHotelId = device?.hotel_id || 0;
        }

        await pool.query(
          'UPDATE devices SET last_card_uid = ? WHERE device_id = ?',
          [cardUid, deviceId]
        );
        logger.info(`[MQTT] 更新设备 ${deviceId} 的最新感应卡片 UID: ${cardUid}`);
        
        // 尝试查询数据库中该卡片的信息并同步回模拟器显示
        const rfidService = require('./rfid.service').default;
        const cardInfo = await rfidService.getCardInfo(cardUid, resolvedHotelId);
        if (cardInfo) {
          logger.info(`[MQTT] 发现已知卡片 ${cardUid} (酒店 ${resolvedHotelId}), 类型: ${cardInfo.card_type}, 持卡人: ${cardInfo.holder_name}`);
          
          // 下发同步指令到当前探测到卡片的设备
          await this.sendDeviceCommand(
            deviceId,
            'room_card_op',
            JSON.stringify({
              action: 'sync',
              card_uid: cardUid,
              card_type: cardInfo.card_type,
              holder_name: cardInfo.holder_name || cardInfo.member_name || '',
              room_number: cardInfo.room_number || ''
            }),
            'system'
          );

          // 关键联动：如果是客房设备上报的卡片，且卡片权限匹配该房间或具有特权，则自动下发开锁指令
          const [deviceRows] = await pool.query<RowDataPacket[]>(
            'SELECT device_type, room_id FROM devices WHERE device_id = ?',
            [deviceId]
          );

          if (deviceRows.length > 0 && deviceRows[0].device_type === 'room') {
            const deviceRoomId = deviceRows[0].room_id;
            let canUnlock = false;

            if (cardInfo.card_type === 'master' || cardInfo.card_type === 'emergency') {
              canUnlock = true; // 万能卡或紧急卡
            } else if (cardInfo.card_type === 'guest' && cardInfo.room_id === deviceRoomId) {
              // 检查卡片是否有效且未过期
              const now = new Date();
              if (cardInfo.status === 'active' && (!cardInfo.expires_at || new Date(cardInfo.expires_at) > now)) {
                canUnlock = true;
              }
            } else if (cardInfo.card_type === 'floor' || cardInfo.card_type === 'staff') {
              // 检查楼层卡/员工卡权限 (这里简化处理，实际应查询 staff_access_policies)
              canUnlock = true; 
            }

            if (canUnlock) {
              logger.info(`[MQTT] 卡片 ${cardUid} 鉴权通过，向设备 ${deviceId} 发送自动开锁指令`);
              await this.sendDeviceCommand(
                deviceId,
                'door',
                'unlock',
                'system_auto_auth'
              );
            } else {
              logger.warn(`[MQTT] 卡片 ${cardUid} 尝试开启房间 ${deviceRoomId} 但权限不足或已过期`);
            }
          }
        } else {
          logger.info(`[MQTT] 未在数据库中找到卡片 ${cardUid} (酒店 ${resolvedHotelId})，通知模拟器保持空白状态`);
          // 明确告知模拟器这是一个未知/空白卡，彻底清除任何残留显示
          await this.sendDeviceCommand(
            deviceId,
            'room_card_op',
            JSON.stringify({
              action: 'sync_clear',
              card_uid: cardUid
            }),
            'system'
          );
        }

        // 清除相关缓存
        await CacheService.deletePattern('device:list:*');
      }

      // 如果是发卡成功事件，更新 rfid_cards 表中的真实 UID
      if (data.event_type === 'card_issued' && data.data?.card_uid) {
        const realUid = data.data.card_uid;
        const roomId = data.data.room_id;
        const bookingId = data.data.booking_id;
        const deviceId = data.device_id;

        // 1. 首先检查是否有暂存的“特权卡签发”任务
        const cacheKey = `pending_privilege_issue:${deviceId}`;
        const pendingIssue = await CacheService.get(cacheKey);

        if (pendingIssue) {
          logger.info(`[MQTT] 发现硬件 ${deviceId} 的暂存签发任务，正在写入数据库...`);
          const { card_type, hotel_id, operator_id, expires_at, holder_name, holder_id, remark, floors, rooms } = pendingIssue as any;

          // 写入 rfid_cards
          await pool.query(
            `INSERT INTO rfid_cards (card_uid, hotel_id, card_type, expires_at, status, issued_at, holder_name, holder_id, remark)
             VALUES (?, ?, ?, ?, 'active', NOW(), ?, ?, ?)
             ON DUPLICATE KEY UPDATE 
               card_type = VALUES(card_type),
               expires_at = VALUES(expires_at),
               status = 'active',
               holder_name = VALUES(holder_name),
               holder_id = VALUES(holder_id),
               remark = VALUES(remark)`,
            [realUid, hotel_id, card_type, expires_at, holder_name, holder_id, remark]
          );

          // 记录生命周期
          await pool.query(
            `INSERT INTO card_lifecycle_logs (card_uid, hotel_id, action_type, operator_id, target_user_id, notes)
             VALUES (?, ?, ?, ?, ?, ?)`,
            [realUid, hotel_id, 'issue', operator_id, null, `签发特权卡: ${card_type}, 持卡人: ${holder_name}, 备注: ${remark}`]
          );

          // 如果有权限策略
          if (card_type === 'floor' || card_type === 'staff') {
            const scope = card_type === 'floor' ? 'floor' : 'room_list';
            const scopeValue = card_type === 'floor' ? JSON.stringify(floors) : JSON.stringify(rooms);
            await pool.query(
              `INSERT INTO staff_access_policies (hotel_id, user_id, access_scope, scope_value, is_active)
               VALUES (?, ?, ?, ?, 1)
               ON DUPLICATE KEY UPDATE access_scope = VALUES(access_scope), scope_value = VALUES(scope_value), is_active = 1`,
              [hotel_id, operator_id, scope, scopeValue]
            );
          }

          // 清除缓存
          await CacheService.delete(cacheKey);
          logger.info(`[MQTT] 特权卡签发成功，UID: ${realUid}`);
        } else {
          // 2. 否则，查找最近一个使用 PRIV_ 前缀生成的临时卡片记录并更新为真实 UID (兼容普通客房发卡)
          let updateQuery = '';
          let updateParams = [];

          if (bookingId) {
            updateQuery = 'UPDATE rfid_cards SET card_uid = ? WHERE booking_id = ? AND card_uid LIKE "PRIV_%"';
            updateParams = [realUid, bookingId];
          } else if (roomId) {
            updateQuery = `
              UPDATE rfid_cards c
              LEFT JOIN rooms r ON c.room_id = r.id
              SET c.card_uid = ? 
              WHERE (c.room_id = ? OR r.room_number = ?) AND c.card_uid LIKE "PRIV_%"
            `;
            updateParams = [realUid, roomId, roomId];
          }

          if (updateQuery) {
            const [result] = await pool.query<ResultSetHeader>(updateQuery, updateParams);
            if (result.affectedRows > 0) {
              logger.info(`[MQTT] 已将临时客房卡片更新为真实物理 UID: ${realUid}`);
              await pool.query(
                'UPDATE card_lifecycle_logs SET card_uid = ? WHERE card_uid LIKE "PRIV_%" AND hotel_id = ? ORDER BY created_at DESC LIMIT 1',
                [realUid, hotelId]
              );
            } else {
              // 兜底方案：如果没有找到临时记录（例如记录创建失败或被清理），直接创建正式记录
              logger.warn(`[MQTT] 未找到临时记录，正在为 UID ${realUid} 直接创建客房卡片记录...`);
              const rfidService = require('./rfid.service').default;
              
              // 尝试从 booking_id 获取退房时间作为有效期
              let expiresAt = null;
              if (bookingId) {
                const [bookingRows] = await pool.query<any[]>('SELECT check_out_date FROM bookings WHERE id = ?', [bookingId]);
                if (bookingRows.length > 0) expiresAt = bookingRows[0].check_out_date;
              }

              await rfidService.issueCard({
                card_uid: realUid,
                hotel_id: hotelId,
                booking_id: bookingId,
                room_id: roomId, // 注意：这里的 roomId 可能是 room_number，issueCard 会处理
                card_type: 'guest',
                expires_at: expiresAt,
                status: 'active'
              });

              await pool.query(
                'INSERT INTO card_lifecycle_logs (card_uid, hotel_id, action_type, operator_id, notes) VALUES (?, ?, ?, ?, ?)',
                [realUid, hotelId, 'issue', 0, `补录签发客房卡: UID=${realUid}, 房间=${roomId}`]
              );
            }
          }
        }
      }

      // 关键修复：确保 hotelId 有效
      let resolvedHotelId = hotelId;
      if (!resolvedHotelId || resolvedHotelId === 0) {
        const device = await this.getDeviceMetadata(data.device_id);
        resolvedHotelId = device?.hotel_id || 0;
      }

      // 关键修复：安防事件只发送给所属酒店的前台
      // 如果没有 hotelId，不再广播到所有前台（防止跨店泄露）
      if (resolvedHotelId && resolvedHotelId !== 0 && this.wsInstance) {
        const hotelRoom = `front_desk_hotel_${resolvedHotelId}`;
        logger.info(`发送安防事件到房间: ${hotelRoom}`);
        let wsLevel = data.level || 'info';
        if (wsLevel === 'alarm') {
          wsLevel = 'critical';
        }
        this.wsInstance.emit('security_event', {
          device_id: data.device_id,
          event_type: data.event_type,
          level: wsLevel,
          data: data.data,
          timestamp: new Date().toISOString(),
          hotel_id: resolvedHotelId
        }, hotelRoom);
      } else {
        // 如果没有 hotelId，记录错误日志，不再广播到所有前台
        logger.error(`安防事件无法发送：无法确定酒店ID，设备ID: ${data.device_id}`);
      }
    } catch (error) {
      logger.error('处理安防事件失败:', error.message);
    }
  }

  /**
   * 处理客房服务相关请求
   * 主题格式:
   * - hotel/service/delivery/{room_id}/request - 送物服务请求
   * - hotel/service/maintenance/{room_id}/request - 维修服务请求
   * - hotel/service/room/{room_id}/status - 房间服务状态查询
   */
  async handleServiceRequest(topic: string, data: any) {
    try {
      const topicParts = topic.split('/');
      if (topicParts.length < 5) {
        logger.warn(`客房服务主题格式错误: ${topic}`);
        return;
      }

      const serviceType = topicParts[2]; // delivery, maintenance, room
      const roomId = topicParts[3];
      const action = topicParts[4]; // request, status

      logger.info(`[客房服务] 收到请求 - 类型: ${serviceType}, 房间: ${roomId}, 动作: ${action}`);

      // 获取房间信息
      const [roomRows] = await pool.query<RowDataPacket[]>(
        'SELECT id, room_number, hotel_id FROM rooms WHERE id = ? OR room_number = ?',
        [roomId, roomId]
      );

      if (roomRows.length === 0) {
        logger.warn(`[客房服务] 房间不存在: ${roomId}`);
        // 发送错误响应
        await this.publish(`hotel/service/response/${roomId}`, {
          success: false,
          error: '房间不存在',
          timestamp: new Date().toISOString()
        });
        return;
      }

      const room = roomRows[0] as any;
      const actualRoomId = room.id;
      const hotelId = room.hotel_id;

      // 获取当前入住信息
      const [bookingRows] = await pool.query<RowDataPacket[]>(
        `SELECT id, guest_id FROM bookings
         WHERE room_id = ? AND status = 'checked_in'
         LIMIT 1`,
        [actualRoomId]
      );

      const bookingId = bookingRows.length > 0 ? (bookingRows[0] as any).id : null;
      const guestId = bookingRows.length > 0 ? (bookingRows[0] as any).guest_id : null;

      if (action === 'request') {
        if (serviceType === 'delivery') {
          // 处理送物请求
          await this.handleDeliveryRequest(actualRoomId, bookingId, guestId, room.room_number, hotelId, data);
        } else if (serviceType === 'maintenance') {
          // 处理维修请求
          await this.handleMaintenanceRequest(actualRoomId, bookingId, guestId, room.room_number, hotelId, data);
        }
      } else if (action === 'status') {
        // 查询房间服务状态
        await this.handleRoomServiceStatus(actualRoomId, room.room_number, hotelId);
      }
    } catch (error) {
      logger.error('[客房服务] 处理请求失败:', error.message);
    }
  }

  /**
   * 处理送物服务请求
   */
  private async handleDeliveryRequest(
    roomId: number,
    bookingId: number | null,
    guestId: number | null,
    roomNumber: string,
    hotelId: number,
    data: any
  ) {
    try {
      const itemName = data.item_name || '未知物品';
      const quantity = data.quantity || 1;
      const note = data.note || '';

      const orderNo = `DEL${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${Date.now().toString(36).toUpperCase()}`;

      const [result] = await pool.query<ResultSetHeader>(
        'INSERT INTO delivery_orders (order_no, room_id, booking_id, guest_id, item_name, quantity, note, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [orderNo, roomId, bookingId, guestId, itemName, quantity, note, 'pending']
      );

      // 发送响应给房间
      await this.publish(`hotel/service/response/${roomNumber}`, {
        success: true,
        type: 'delivery',
        order_id: result.insertId,
        order_no: orderNo,
        message: `送物订单已创建，订单号: ${orderNo}`,
        timestamp: new Date().toISOString()
      });

      // 通知前台
      await this.publish(`hotel/${hotelId}/reception/announce`, {
        type: 'delivery_order_created',
        order_id: result.insertId,
        order_no: orderNo,
        room_id: roomId,
        room_number: roomNumber,
        hotel_id: hotelId,
        item_name: itemName,
        quantity: quantity,
        note: note,
        status: 'pending',
        created_at: new Date().toISOString(),
        message: `房间 ${roomNumber} 请求送物: ${itemName} x${quantity}`,
        announce: true
      });

      logger.info(`[送物服务] 订单创建成功 - 订单号: ${orderNo}, 房间: ${roomNumber}`);
    } catch (error) {
      logger.error('[送物服务] 创建订单失败:', error.message);
      await this.publish(`hotel/service/response/${roomNumber}`, {
        success: false,
        type: 'delivery',
        error: '创建订单失败',
        timestamp: new Date().toISOString()
      });
    }
  }

  /**
   * 处理维修服务请求
   */
  private async handleMaintenanceRequest(
    roomId: number,
    bookingId: number | null,
    guestId: number | null,
    roomNumber: string,
    hotelId: number,
    data: any
  ) {
    try {
      const faultType = data.fault_type || 'other';
      const faultDescription = data.fault_description || '无描述';
      const priority = data.priority || 'normal';

      const ticketNo = `MT${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${Date.now().toString(36).toUpperCase()}`;

      const [result] = await pool.query<ResultSetHeader>(
        'INSERT INTO maintenance_tickets (ticket_no, room_id, booking_id, guest_id, fault_type, fault_description, priority, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [ticketNo, roomId, bookingId, guestId, faultType, faultDescription, priority, 'pending']
      );

      // 更新房间状态为维修中
      await pool.query('UPDATE rooms SET room_status = ? WHERE id = ?', ['maintenance', roomId]);

      // 发送响应给房间
      await this.publish(`hotel/service/response/${roomNumber}`, {
        success: true,
        type: 'maintenance',
        ticket_id: result.insertId,
        ticket_no: ticketNo,
        message: `维修工单已创建，工单号: ${ticketNo}`,
        timestamp: new Date().toISOString()
      });

      // 通知前台
      await this.publish(`hotel/${hotelId}/reception/announce`, {
        type: 'maintenance_ticket_created',
        ticket_id: result.insertId,
        ticket_no: ticketNo,
        room_id: roomId,
        room_number: roomNumber,
        hotel_id: hotelId,
        fault_type: faultType,
        fault_description: faultDescription,
        priority: priority,
        status: 'pending',
        created_at: new Date().toISOString(),
        message: `房间 ${roomNumber} 报修: ${faultType} - ${faultDescription?.substring(0, 30)}`,
        announce: true
      });

      logger.info(`[维修服务] 工单创建成功 - 工单号: ${ticketNo}, 房间: ${roomNumber}`);
    } catch (error) {
      logger.error('[维修服务] 创建工单失败:', error.message);
      await this.publish(`hotel/service/response/${roomNumber}`, {
        success: false,
        type: 'maintenance',
        error: '创建工单失败',
        timestamp: new Date().toISOString()
      });
    }
  }

  /**
   * 处理房间服务状态查询
   */
  private async handleRoomServiceStatus(
    roomId: number,
    roomNumber: string,
    hotelId: number
  ) {
    try {
      // 查询进行中的送物订单
      const [deliveryRows] = await pool.query<RowDataPacket[]>(
        `SELECT id, order_no, item_name, quantity, status, created_at
         FROM delivery_orders
         WHERE room_id = ? AND status IN ('pending', 'delivering')
         ORDER BY created_at DESC`,
        [roomId]
      );

      // 查询进行中的维修工单
      const [maintenanceRows] = await pool.query<RowDataPacket[]>(
        `SELECT id, ticket_no, fault_type, fault_description, status, created_at
         FROM maintenance_tickets
         WHERE room_id = ? AND status IN ('pending', 'assigned', 'processing')
         ORDER BY created_at DESC`,
        [roomId]
      );

      // 发送状态响应
      await this.publish(`hotel/service/response/${roomNumber}`, {
        success: true,
        type: 'status',
        room_number: roomNumber,
        pending_deliveries: deliveryRows,
        pending_maintenance: maintenanceRows,
        timestamp: new Date().toISOString()
      });

      logger.info(`[服务状态] 查询成功 - 房间: ${roomNumber}, 送物: ${deliveryRows.length}, 维修: ${maintenanceRows.length}`);
    } catch (error) {
      logger.error('[服务状态] 查询失败:', error.message);
      await this.publish(`hotel/service/response/${roomNumber}`, {
        success: false,
        type: 'status',
        error: '查询失败',
        timestamp: new Date().toISOString()
      });
    }
  }

  /**
   * 处理房间场景控制
   * 场景: welcome=欢迎模式, sleep=睡眠模式, leave=外出模式
   */
  private async handleSceneControl(topic: string, data: any) {
    try {
      const topicParts = topic.split('/');
      const roomId = topicParts[2]; // hotel/room/{roomId}/scene

      const scene = data.scene || data.type;
      const timestamp = data.timestamp || new Date().toISOString();

      logger.info(`[场景控制] 房间 ${roomId} - 场景: ${scene}`);

      // 根据不同场景下发设备控制指令
      const controlTopic = `hotel/device/command/room/${roomId}`;
      
      switch (scene) {
        case 'welcome':
          // 欢迎模式：开灯、开窗帘、空调调到舒适温度
          await this.publish(controlTopic, {
            device_type: 'all',
            action: 'on',
            timestamp
          });
          logger.info(`[场景控制] ${roomId} 欢迎模式：设备已开启`);
          break;
        case 'sleep':
          // 睡眠模式：关灯、关窗帘、空调调到26度
          await this.publish(controlTopic, {
            device_type: 'light',
            action: 'off',
            timestamp
          });
          await this.publish(controlTopic, {
            device_type: 'curtain',
            action: 'close',
            timestamp
          });
          await this.publish(controlTopic, {
            device_type: 'ac',
            action: 'set_temperature',
            value: 26,
            timestamp
          });
          logger.info(`[场景控制] ${roomId} 睡眠模式：灯光关闭，窗帘关闭，空调26度`);
          break;
        case 'leave':
          // 外出模式：关闭所有设备
          await this.publish(controlTopic, {
            device_type: 'all',
            action: 'off',
            timestamp
          });
          logger.info(`[场景控制] ${roomId} 外出模式：所有设备已关闭`);
          break;
        default:
          logger.warn(`[场景控制] 未知场景: ${scene}`);
      }

      // 发送场景执行结果
      await this.publish(`hotel/room/${roomId}/scene/result`, {
        success: true,
        scene: scene,
        message: `${scene}模式已激活`,
        timestamp
      });
    } catch (error) {
      logger.error('[场景控制] 处理失败:', error.message);
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
        'SELECT device_key, device_key_encrypted FROM devices WHERE device_id = ? AND audit_status = "approved"',
        [deviceId]
      );

      if (rows.length === 0) {
        logger.warn(`无法向未审核或不存在的设备发送指令: ${deviceId}`);
        return null;
      }

      const { device_key, device_key_encrypted } = rows[0] as { device_key: string; device_key_encrypted?: string };
      const signingKey = getRawKeyForSigning(device_key_encrypted || device_key, device_key);
      if (!signingKey) {
        logger.error(`无法获取设备 ${deviceId} 的签名密钥`);
        return null;
      }

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

      payload.signature = calculateSignature(payload, signingKey);

      // 4. 发布到 MQTT (发布到特定设备的 sub-topic: hotel/device/command/{type}/{id})
      const [deviceRows] = await pool.query<RowDataPacket[]>(
        'SELECT device_type FROM devices WHERE device_id = ?',
        [deviceId]
      );
      const deviceType = deviceRows.length > 0 ? deviceRows[0].device_type : 'unknown';
      const specificTopic = `hotel/device/command/${deviceType}/${deviceId}`;

      await this.publish(specificTopic, payload);

      logger.info(`发送设备指令 (已签名): #${commandId} -> ${specificTopic}/${commandType}=${commandValue}`);
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
