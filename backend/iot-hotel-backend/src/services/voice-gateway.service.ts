import logger from '../utils/logger';
import mqttService from './mqtt.service';
import { getWebSocketService } from './websocket.service';
import { v4 as uuidv4 } from 'uuid';

/**
 * WebRTC 会话信息
 */
export interface WebRTCSession {
  sessionId: string;
  callId: string;
  deviceId: string;
  roomNumber: string;
  hotelId: number;
  frontendClientId: string | null; // WebSocket client ID
  state: 'initiating' | 'negotiating' | 'connected' | 'terminated';
  createdAt: Date;
  connectedAt: Date | null;
  terminatedAt: Date | null;
}

/**
 * 语音网关服务
 * 
 * 功能:
 * 1. 桥接 MQTT 语音通道（硬件设备）和 WebRTC 通道（前端浏览器）
 * 2. 管理 WebRTC 信令交换（SDP offer/answer, ICE candidates）
 * 3. 处理语音数据转发
 * 4. 支持双通道并发（设备可同时通过MQTT和WebRTC接收语音）
 */
class VoiceGatewayService {
  // 活跃的 WebRTC 会话
  private sessions: Map<string, WebRTCSession> = new Map();
  // 设备到会话的映射
  private deviceSessions: Map<string, string> = new Map();
  // 通话ID到会话的映射
  private callSessions: Map<string, string> = new Map();

  constructor() {
    this.setupMqttListeners();
  }

  /**
   * 设置 MQTT 监听器，接收来自硬件的语音消息
   */
  private setupMqttListeners(): void {
    // 监听来自设备的语音数据
    mqttService.subscribe('hotel/device/voice/+/+').catch(() => {});
    mqttService.subscribe('hotel/device/call/+/+').catch(() => {});

    logger.info('[VoiceGateway] MQTT 监听器已设置');
  }

  /**
   * 处理来自 MQTT 的消息（由外部调用，集成到 mqtt.service 的消息处理流程中）
   */
  handleMqttMessage(topic: string, payload: any): void {
    if (topic.startsWith('hotel/device/voice/')) {
      const parts = topic.split('/');
      const deviceId = parts[3];
      this.forwardVoiceToWebRTC(deviceId, payload);
    } else if (topic.startsWith('hotel/device/call/')) {
      const parts = topic.split('/');
      const deviceId = parts[3];
      this.forwardCallStatusToFrontend(deviceId, payload);
    } else if (topic.includes('webrtc_sdp_answer') || topic.includes('signal')) {
      // 处理设备发来的 SDP Answer 和 ICE Candidate
      if (payload.sdp && payload.session_id) {
        this.handleSDPAnswer(payload.device_id || '', payload.session_id, payload.sdp);
      } else if (payload.candidate && payload.session_id) {
        this.handleDeviceICECandidate(payload.device_id || '', payload.session_id, payload.candidate);
      }
    }
  }

  /**
   * 创建新的 WebRTC 会话
   */
  async createSession(callId: string, deviceId: string, roomNumber: string, hotelId: number): Promise<WebRTCSession> {
    const sessionId = uuidv4();
    
    const session: WebRTCSession = {
      sessionId,
      callId,
      deviceId,
      roomNumber,
      hotelId,
      frontendClientId: null,
      state: 'initiating',
      createdAt: new Date(),
      connectedAt: null,
      terminatedAt: null
    };

    this.sessions.set(sessionId, session);
    this.deviceSessions.set(deviceId, sessionId);
    this.callSessions.set(callId, sessionId);

    logger.info(`[VoiceGateway] 创建会话: ${sessionId}, 设备: ${deviceId}, 房间: ${roomNumber}`);

    // 通知硬件设备准备接收 WebRTC 信令
    mqttService.publish(`hotel/device/config/room/${deviceId}`, {
      command_id: Date.now(),
      command_type: 'webrtc_initiate',
      call_id: callId,
      session_id: sessionId,
      timestamp: new Date().toISOString()
    });

    return session;
  }

  /**
   * 获取会话信息
   */
  getSession(sessionId: string): WebRTCSession | null {
    return this.sessions.get(sessionId) || null;
  }

  /**
   * 根据设备ID获取会话
   */
  getSessionByDevice(deviceId: string): WebRTCSession | null {
    const sessionId = this.deviceSessions.get(deviceId);
    if (!sessionId) return null;
    return this.sessions.get(sessionId) || null;
  }

  /**
   * 根据通话ID获取会话
   */
  getSessionByCall(callId: string): WebRTCSession | null {
    const sessionId = this.callSessions.get(callId);
    if (!sessionId) return null;
    return this.sessions.get(sessionId) || null;
  }

  /**
   * 处理 WebRTC SDP Offer（来自前端）
   */
  async handleSDPOffer(sessionId: string, frontendClientId: string, sdp: any): Promise<{ success: boolean; answer?: any; error?: string }> {
    const session = this.sessions.get(sessionId);
    if (!session) {
      return { success: false, error: '会话不存在' };
    }

    if (session.state === 'terminated') {
      return { success: false, error: '会话已终止' };
    }

    // 更新前端客户端ID
    session.frontendClientId = frontendClientId;
    session.state = 'negotiating';

    logger.info(`[VoiceGateway] 处理 SDP Offer: ${sessionId}, 前端: ${frontendClientId}`);

    // 将 SDP Offer 转发给硬件设备
    mqttService.publish(`hotel/device/signal/room/${session.deviceId}`, {
      command_id: Date.now(),
      command_type: 'webrtc_sdp_offer',
      session_id: sessionId,
      sdp: sdp,
      timestamp: new Date().toISOString()
    });

    return { success: true };
  }

  /**
   * 处理 WebRTC SDP Answer（来自设备，通过 MQTT）
   */
  async handleSDPAnswer(deviceId: string, sessionId: string, sdp: any): Promise<void> {
    const session = this.sessions.get(sessionId);
    if (!session) {
      logger.warn(`[VoiceGateway] 收到未知会话的 SDP Answer: ${sessionId}`);
      return;
    }

    if (!session.frontendClientId) {
      logger.warn(`[VoiceGateway] 前端客户端未连接: ${sessionId}`);
      return;
    }

    logger.info(`[VoiceGateway] 转发 SDP Answer 到前端: ${sessionId}`);

    // 通过 WebSocket 转发给前端
    const wsService = getWebSocketService();
    const io = wsService?.getIO();
    if (io && session.frontendClientId) {
      io.to(session.frontendClientId).emit('webrtc_sdp_answer', {
        session_id: sessionId,
        call_id: session.callId,
        sdp: sdp,
        timestamp: new Date().toISOString()
      });
    }
  }

  /**
   * 处理 ICE Candidate（来自前端）
   */
  async handleICECandidate(sessionId: string, candidate: any): Promise<void> {
    const session = this.sessions.get(sessionId);
    if (!session) {
      logger.warn(`[VoiceGateway] 收到未知会话的 ICE Candidate: ${sessionId}`);
      return;
    }

    logger.info(`[VoiceGateway] 转发 ICE Candidate 到设备: ${sessionId}`);

    // 转发给硬件设备
    mqttService.publish(`hotel/device/signal/room/${session.deviceId}`, {
      command_id: Date.now(),
      command_type: 'webrtc_ice_candidate',
      session_id: sessionId,
      candidate: candidate,
      timestamp: new Date().toISOString()
    });
  }

  /**
   * 处理设备发来的 ICE Candidate（通过 MQTT）
   */
  async handleDeviceICECandidate(deviceId: string, sessionId: string, candidate: any): Promise<void> {
    const session = this.sessions.get(sessionId);
    if (!session) {
      logger.warn(`[VoiceGateway] 收到未知设备的 ICE Candidate: ${deviceId}`);
      return;
    }

    if (!session.frontendClientId) {
      logger.warn(`[VoiceGateway] 前端客户端未连接: ${sessionId}`);
      return;
    }

    logger.info(`[VoiceGateway] 转发设备 ICE Candidate 到前端: ${sessionId}`);

    // 通过 WebSocket 转发给前端
    const wsService = getWebSocketService();
    const io = wsService?.getIO();
    if (io && session.frontendClientId) {
      io.to(session.frontendClientId).emit('webrtc_ice_candidate', {
        session_id: sessionId,
        call_id: session.callId,
        candidate: candidate,
        timestamp: new Date().toISOString()
      });
    }
  }

  /**
   * 转发语音数据到 WebRTC 前端
   */
  private forwardVoiceToWebRTC(deviceId: string, payload: any): void {
    const session = this.getSessionByDevice(deviceId);
    if (!session || !session.frontendClientId) {
      return;
    }

    const wsService = getWebSocketService();
    const io = wsService?.getIO();
    if (io) {
      io.to(session.frontendClientId).emit('webrtc_voice_data', {
        session_id: session.sessionId,
        call_id: session.callId,
        data: payload,
        timestamp: new Date().toISOString()
      });
    }
  }

  /**
   * 转发呼叫状态到前端
   */
  private forwardCallStatusToFrontend(deviceId: string, payload: any): void {
    const session = this.getSessionByDevice(deviceId);
    if (!session || !session.frontendClientId) {
      return;
    }

    const wsService = getWebSocketService();
    const io = wsService?.getIO();
    if (io) {
      io.to(session.frontendClientId).emit('webrtc_call_status', {
        session_id: session.sessionId,
        call_id: session.callId,
        status: payload.status,
        data: payload,
        timestamp: new Date().toISOString()
      });
    }
  }

  /**
   * 标记会话为已连接
   */
  markConnected(sessionId: string): void {
    const session = this.sessions.get(sessionId);
    if (session) {
      session.state = 'connected';
      session.connectedAt = new Date();
      logger.info(`[VoiceGateway] 会话已连接: ${sessionId}`);
    }
  }

  /**
   * 终止会话
   */
  terminateSession(sessionId: string, reason: string = 'user_hangup'): void {
    const session = this.sessions.get(sessionId);
    if (!session) {
      return;
    }

    session.state = 'terminated';
    session.terminatedAt = new Date();

    logger.info(`[VoiceGateway] 终止会话: ${sessionId}, 原因: ${reason}`);

    // 通知硬件设备
    mqttService.publish(`hotel/device/signal/room/${session.deviceId}`, {
      command_id: Date.now(),
      command_type: 'webrtc_terminate',
      session_id: sessionId,
      reason: reason,
      timestamp: new Date().toISOString()
    });

    // 通知前端
    if (session.frontendClientId) {
      const wsService = getWebSocketService();
      const io = wsService?.getIO();
      if (io) {
        io.to(session.frontendClientId).emit('webrtc_terminated', {
          session_id: sessionId,
          call_id: session.callId,
          reason: reason,
          duration: session.connectedAt ? Math.floor((Date.now() - session.connectedAt.getTime()) / 1000) : 0,
          timestamp: new Date().toISOString()
        });
      }
    }

    // 清理映射
    this.deviceSessions.delete(session.deviceId);
    this.callSessions.delete(session.callId);
    
    // 延迟删除会话（保留一段时间用于查询）
    setTimeout(() => {
      this.sessions.delete(sessionId);
    }, 5 * 60 * 1000); // 5分钟后删除
  }

  /**
   * 获取活跃会话数量
   */
  getActiveSessionCount(): number {
    return Array.from(this.sessions.values()).filter(s => s.state !== 'terminated').length;
  }

  /**
   * 获取所有活跃会话
   */
  getActiveSessions(): WebRTCSession[] {
    return Array.from(this.sessions.values()).filter(s => s.state !== 'terminated');
  }

  /**
   * 获取会话统计
   */
  getStats(): {
    totalSessions: number;
    activeSessions: number;
    connectedSessions: number;
    terminatedSessions: number;
  } {
    const allSessions = Array.from(this.sessions.values());
    return {
      totalSessions: allSessions.length,
      activeSessions: allSessions.filter(s => s.state !== 'terminated').length,
      connectedSessions: allSessions.filter(s => s.state === 'connected').length,
      terminatedSessions: allSessions.filter(s => s.state === 'terminated').length
    };
  }
}

// 单例实例
let voiceGatewayInstance: VoiceGatewayService | null = null;

/**
 * 获取语音网关单例
 */
export function getVoiceGateway(): VoiceGatewayService {
  if (!voiceGatewayInstance) {
    voiceGatewayInstance = new VoiceGatewayService();
  }
  return voiceGatewayInstance;
}

export default VoiceGatewayService;
