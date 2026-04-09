import { Server, Socket } from 'socket.io';
import http from 'http';
import config from '../config';
import logger from '../utils/logger';
import mqttService from './mqtt.service';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';

interface ClientInfo {
  socketId: string;
  roomId?: string;
  role?: string;
  clientType?: 'room' | 'front_desk' | 'ai' | 'app';
  clientId?: string;
  clientName?: string; // 新增：客户端显示名称
  connectedAt: Date;
}

class WebSocketService {
  private io: Server | null = null;
  private server: http.Server | null = null;
  private clients: Map<string, ClientInfo> = new Map();

  init(httpServer: http.Server) {
    this.server = httpServer;
    this.io = new Server(httpServer, {
      cors: {
        origin: '*',
        methods: ['GET', 'POST'],
        credentials: true
      },
      pingTimeout: 60000,
      pingInterval: 25000,
      maxHttpBufferSize: 1e6,
      transports: ['websocket', 'polling']
    });

    this.io.on('connection', (socket: Socket) => {
      const clientInfo: ClientInfo = {
        socketId: socket.id,
        connectedAt: new Date()
      };
      this.clients.set(socket.id, clientInfo);

      logger.info(`WebSocket客户端连接: ${socket.id} (当前在线: ${this.clients.size})`);

      socket.on('join_room', async (roomId: string) => {
        const room = String(roomId).trim();
        if (!room) return;

        const oldRoom = this.clients.get(socket.id)?.roomId;
        if (oldRoom && oldRoom !== room) {
          socket.leave(oldRoom);
        }

        socket.join(room);
        const info = this.clients.get(socket.id);
        if (info) {
          info.roomId = room;
          info.clientType = 'room';
          info.clientId = room;
        }

        logger.info(`客户端 ${socket.id} 加入房间: ${room}`);

        try {
          const [rows] = await pool.query<RowDataPacket[]>(
            `SELECT * FROM rooms WHERE id = ? OR room_number = ? LIMIT 1`,
            [room, room]
          );
          
          if (rows.length > 0) {
            socket.emit('room_info', rows[0]);
            
            const [deviceRows] = await pool.query<RowDataPacket[]>(
              `SELECT device_id, device_type, device_name, device_status, last_seen 
               FROM devices WHERE device_id LIKE ? OR device_id = ?`,
              [`R${room}%`, `R${room}`]
            );
            
            if (deviceRows.length > 0) {
              socket.emit('room_devices', deviceRows);
            }
          }
        } catch (error) {
          logger.error('获取房间信息失败:', error);
        }
      });

      socket.on('leave_room', (roomId: string) => {
        socket.leave(roomId);
        const info = this.clients.get(socket.id);
        if (info?.roomId === roomId) info.roomId = undefined;
        logger.info(`客户端 ${socket.id} 离开房间: ${roomId}`);
      });

      socket.on('register_client', async (data: { 
        clientType: 'room' | 'front_desk' | 'ai' | 'app'; 
        clientId: string 
      }) => {
        try {
          const validTypes = ['room', 'front_desk', 'ai', 'app'];
          
          if (!validTypes.includes(data.clientType)) {
            socket.emit('error', { message: `无效的clientType，支持的值: ${validTypes.join(', ')}` });
            return;
          }

          let displayName = data.clientId;

          // 人员识别逻辑：如果是前台或APP，从数据库验证并获取用户名
          if (data.clientType === 'front_desk' || data.clientType === 'app') {
            const [rows] = await pool.query<RowDataPacket[]>(
              'SELECT username, role FROM users WHERE id = ? OR username = ?',
              [data.clientId, data.clientId]
            );
            if (rows.length === 0) {
              socket.emit('error', { message: '身份验证失败：未找到该员工/用户' });
              return;
            }
            displayName = rows[0].username;
          } else if (data.clientType === 'room') {
            const [rows] = await pool.query<RowDataPacket[]>(
              'SELECT room_number FROM rooms WHERE id = ? OR room_number = ?',
              [data.clientId, data.clientId]
            );
            if (rows.length > 0) {
              displayName = `客房 ${rows[0].room_number}`;
            }
          }
          
          const info = this.clients.get(socket.id);
          if (info) {
            info.clientType = data.clientType;
            info.clientId = data.clientId;
            info.clientName = displayName;
            
            switch (data.clientType) {
              case 'room':
                socket.join(`room_${data.clientId}`);
                break;
              case 'front_desk':
                socket.join('front_desk');
                break;
              case 'ai':
                socket.join('ai');
                break;
              case 'app':
                socket.join(`app_${data.clientId}`);
                break;
            }
          }
          
          socket.emit('registered', {
            clientType: data.clientType,
            clientId: data.clientId,
            clientName: displayName,
            timestamp: new Date().toISOString()
          });
          
          logger.info(`客户端 ${socket.id} 注册为: ${data.clientType}/${displayName}`);
          
          // 广播更新在线列表
          this.broadcastOnlineStatus();
        } catch (error) {
          logger.error('注册客户端失败:', error);
          socket.emit('error', { message: '注册失败' });
        }
      });

      socket.on('get_online_status', () => {
        this.sendOnlineStatus(socket);
      });

      socket.on('send_message', (data: { roomId?: string; content: string; type?: string }) => {
        const targetRoom = data.roomId || this.clients.get(socket.id)?.roomId;
        if (!targetRoom) {
          socket.emit('error', { message: '未加入任何房间' });
          return;
        }

        const messageData = {
          id: Date.now(),
          sender: socket.id,
          content: data.content,
          type: data.type || 'text',
          timestamp: new Date().toISOString()
        };

        this.io?.to(targetRoom).emit('receive_message', messageData);
        logger.info(`消息发送到房间 ${targetRoom}: [${data.type || 'text'}]`);
      });

      socket.on('control_device', async (data: {
        deviceId: string;
        commandType: string;
        commandValue: string;
      }) => {
        logger.info(`收到设备控制请求: ${data.deviceId}/${data.commandType}=${data.commandValue}`);
        
        const commandId = await mqttService.sendDeviceCommand(
          data.deviceId,
          data.commandType,
          data.commandValue,
          socket.id
        );

        socket.emit('command_sent', {
          command_id: commandId,
          device_id: data.deviceId,
          command_type: data.commandType,
          status: commandId ? 'pending' : 'failed',
          timestamp: new Date().toISOString()
        });
      });

      socket.on('initiate_call', async (data: { 
        caller_type?: 'room' | 'front_desk' | 'ai' | 'app'; 
        caller_id?: string; 
        callee_type: 'room' | 'front_desk' | 'ai' | 'app'; 
        callee_id: string; 
        type?: string 
      }) => {
        try {
          const clientInfo = this.clients.get(socket.id);
          const caller_type = data.caller_type || clientInfo?.clientType || 'room';
          const caller_id = data.caller_id || clientInfo?.clientId || clientInfo?.roomId || 'unknown';
          const callee_type = data.callee_type;
          const callee_id = data.callee_id;
          const callType = data.type || 'voice';
          
          const validTypes = ['room', 'front_desk', 'ai', 'app'];
          
          if (!validTypes.includes(caller_type)) {
            socket.emit('call_error', { message: `无效的caller_type，支持的值: ${validTypes.join(', ')}` });
            return;
          }
          
          if (!validTypes.includes(callee_type)) {
            socket.emit('call_error', { message: `无效的callee_type，支持的值: ${validTypes.join(', ')}` });
            return;
          }
          
          const callId = `CALL${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${Math.random().toString(36).substring(2, 10).toUpperCase()}`;
          
          let calleeExists = false;
          
          switch (callee_type) {
            case 'room':
              const [room] = await pool.query<RowDataPacket[]>('SELECT id, room_number FROM rooms WHERE id = ? OR room_number = ?', [callee_id, callee_id]);
              calleeExists = room.length > 0;
              break;
            case 'front_desk':
              const [employee] = await pool.query<RowDataPacket[]>('SELECT id FROM users WHERE id = ? OR username = ?', [callee_id, callee_id]);
              calleeExists = employee.length > 0;
              break;
            case 'ai':
              calleeExists = true;
              break;
            case 'app':
              const [user] = await pool.query<RowDataPacket[]>('SELECT id FROM users WHERE id = ?', [callee_id]);
              calleeExists = user.length > 0;
              break;
          }
          
          if (!calleeExists) {
            socket.emit('call_error', { message: '被叫方不存在' });
            return;
          }
          
          const [existingCall] = await pool.query<RowDataPacket[]>(
            'SELECT * FROM calls WHERE (callee_type = ? AND callee_id = ? OR caller_type = ? AND caller_id = ?) AND status IN (?, ?, ?, ?) LIMIT 1',
            [callee_type, callee_id, callee_type, callee_id, 'calling', 'outgoing', 'ringing', 'connected']
          );
          
          if (existingCall.length > 0) {
            socket.emit('call_error', { message: '该用户已有通话进行中' });
            return;
          }
          
          const [result] = await pool.query<ResultSetHeader>(
            `INSERT INTO calls (call_id, caller_type, caller_id, callee_type, callee_id, status, started_at) 
             VALUES (?, ?, ?, ?, ?, ?, ?)`,
            [callId, caller_type, caller_id, callee_type, callee_id, 'calling', new Date()]
          );
          
          const callData = {
            call_id: callId,
            caller_type,
            caller_id,
            caller_name: clientInfo?.clientName || caller_id, // 新增：主叫名称
            callee_type,
            callee_id,
            status: 'calling',
            type: callType,
            started_at: new Date().toISOString()
          };
          
          socket.emit('call_initiated', callData);
          
          this.io?.to(`${callee_type}_${callee_id}`).emit('incoming_call', callData);
          
          logger.info(`通话发起: ${caller_type}/${caller_id} -> ${callee_type}/${callee_id} (${callId})`);
        } catch (error) {
          logger.error('发起语音通话失败:', error);
          socket.emit('call_error', { message: '发起语音通话失败' });
        }
      });

      // --- WebRTC 信令转发 ---
      
      socket.on('webrtc_offer', (data: { 
        target_type: 'room' | 'front_desk' | 'ai' | 'app'; 
        target_id: string; 
        offer: any;
        call_id: string;
      }) => {
        logger.info(`转发 WebRTC Offer: ${socket.id} -> ${data.target_type}_${data.target_id}`);
        
        if (data.target_type === 'room') {
          // 如果目标是房间硬件，转发到 MQTT
          mqttService.publish(`hotel/call/signaling/${data.call_id}`, {
            from_type: this.clients.get(socket.id)?.clientType,
            from_id: this.clients.get(socket.id)?.clientId,
            type: 'offer',
            offer: data.offer,
            target_type: 'room',
            target_id: data.target_id
          });
        } else {
          // 否则通过 WebSocket 转发
          this.io?.to(`${data.target_type}_${data.target_id}`).emit('webrtc_offer', {
            from_type: this.clients.get(socket.id)?.clientType,
            from_id: this.clients.get(socket.id)?.clientId,
            offer: data.offer,
            call_id: data.call_id
          });
        }
      });

      socket.on('webrtc_answer', (data: { 
        target_type: 'room' | 'front_desk' | 'ai' | 'app'; 
        target_id: string; 
        answer: any;
        call_id: string;
      }) => {
        logger.info(`转发 WebRTC Answer: ${socket.id} -> ${data.target_type}_${data.target_id}`);
        
        if (data.target_type === 'room') {
          mqttService.publish(`hotel/call/signaling/${data.call_id}`, {
            from_type: this.clients.get(socket.id)?.clientType,
            from_id: this.clients.get(socket.id)?.clientId,
            type: 'answer',
            answer: data.answer,
            target_type: 'room',
            target_id: data.target_id
          });
        } else {
          this.io?.to(`${data.target_type}_${data.target_id}`).emit('webrtc_answer', {
            from_type: this.clients.get(socket.id)?.clientType,
            from_id: this.clients.get(socket.id)?.clientId,
            answer: data.answer,
            call_id: data.call_id
          });
        }
      });

      socket.on('webrtc_ice_candidate', (data: { 
        target_type: 'room' | 'front_desk' | 'ai' | 'app'; 
        target_id: string; 
        candidate: any;
        call_id: string;
      }) => {
        if (data.target_type === 'room') {
          mqttService.publish(`hotel/call/signaling/${data.call_id}`, {
            from_type: this.clients.get(socket.id)?.clientType,
            from_id: this.clients.get(socket.id)?.clientId,
            type: 'ice_candidate',
            candidate: data.candidate,
            target_type: 'room',
            target_id: data.target_id
          });
        } else {
          this.io?.to(`${data.target_type}_${data.target_id}`).emit('webrtc_ice_candidate', {
            from_type: this.clients.get(socket.id)?.clientType,
            from_id: this.clients.get(socket.id)?.clientId,
            candidate: data.candidate,
            call_id: data.call_id
          });
        }
      });

      // --- 硬件音频流转发 (WebSocket Binary) ---
      
      socket.on('audio_chunk', (data: { 
        target_type: 'room' | 'front_desk' | 'ai' | 'app'; 
        target_id: string; 
        chunk: Buffer | ArrayBuffer;
        call_id: string;
      }) => {
        if (data.target_type === 'room') {
          // Web/App 发出的音频流，通过 MQTT 转发给硬件
          const audioBuffer = Buffer.isBuffer(data.chunk) 
            ? data.chunk 
            : Buffer.from(data.chunk as ArrayBuffer);
          mqttService.publishBinary(`hotel/call/audio/${data.call_id}`, audioBuffer);
        } else {
          // 转发给其他 Web/App 终端
          this.io?.to(`${data.target_type}_${data.target_id}`).emit('audio_chunk', {
            from_type: this.clients.get(socket.id)?.clientType,
            from_id: this.clients.get(socket.id)?.clientId,
            chunk: data.chunk,
            call_id: data.call_id
          });
        }
      });

      socket.on('answer_call', async (data: { callId: string }) => {
        try {
          const callId = String(data.callId).trim();
          
          const [call] = await pool.query<RowDataPacket[]>('SELECT * FROM calls WHERE call_id = ?', [callId]);
          if (call.length === 0) {
            socket.emit('call_error', { message: '通话不存在' });
            return;
          }
          
          const callData = call[0];
          
          if (['ended', 'rejected'].includes(callData.status)) {
            socket.emit('call_error', { message: '通话已结束或已拒接' });
            return;
          }
          
          const [result] = await pool.query<ResultSetHeader>(
            `UPDATE calls SET status = ?, answered_at = ? WHERE call_id = ?`,
            ['connected', new Date(), callId]
          );
          
          const answerData = {
            call_id: callId,
            status: 'connected',
            answered_at: new Date().toISOString()
          };
          
          socket.emit('call_answered', answerData);
          
          // 如果是拨给房间，通知硬件接通
          if (callData.callee_type === 'room') {
            mqttService.publish(`hotel/device/command/room/${callData.callee_id}`, {
              command_id: Date.now(),
              command_type: 'answer_call',
              call_id: callId
            });
          }
          
          this.io?.to(`${callData.caller_type}_${callData.caller_id}`).emit('call_answered', answerData);
          
          logger.info(`通话接听: ${callId}`);
        } catch (error) {
          logger.error('接听语音通话失败:', error);
          socket.emit('call_error', { message: '接听语音通话失败' });
        }
      });

      socket.on('reject_call', async (data: { callId: string }) => {
        try {
          const callId = String(data.callId).trim();
          
          const [call] = await pool.query<RowDataPacket[]>('SELECT * FROM calls WHERE call_id = ?', [callId]);
          if (call.length === 0) {
            socket.emit('call_error', { message: '通话不存在' });
            return;
          }
          
          const callData = call[0];
          
          if (callData.status === 'ended') {
            socket.emit('call_error', { message: '通话已结束' });
            return;
          }
          
          const [result] = await pool.query<ResultSetHeader>(
            `UPDATE calls SET status = ?, ended_at = ? WHERE call_id = ?`,
            ['rejected', new Date(), callId]
          );
          
          const rejectData = {
            call_id: callId,
            status: 'rejected',
            ended_at: new Date().toISOString()
          };
          
          socket.emit('call_rejected', rejectData);
          
          // 如果是拨给房间，通知硬件拒接
          if (callData.callee_type === 'room') {
            mqttService.publish(`hotel/device/command/room/${callData.callee_id}`, {
              command_id: Date.now(),
              command_type: 'reject_call',
              call_id: callId
            });
          }
          
          this.io?.to(`${callData.caller_type}_${callData.caller_id}`).emit('call_rejected', rejectData);
          
          logger.info(`通话拒接: ${callId}`);
        } catch (error) {
          logger.error('拒接语音通话失败:', error);
          socket.emit('call_error', { message: '拒接语音通话失败' });
        }
      });

      socket.on('hangup_call', async (data: { callId: string }) => {
        try {
          const callId = String(data.callId).trim();
          
          const [call] = await pool.query<RowDataPacket[]>('SELECT * FROM calls WHERE call_id = ?', [callId]);
          if (call.length === 0) {
            socket.emit('call_error', { message: '通话不存在' });
            return;
          }
          
          const callData = call[0];
          
          if (callData.status === 'ended') {
            socket.emit('call_error', { message: '通话已结束' });
            return;
          }
          
          const endedAt = new Date();
          const durationSec = callData.answered_at 
            ? Math.floor((endedAt.getTime() - new Date(callData.answered_at).getTime()) / 1000)
            : 0;
          
          const [result] = await pool.query<ResultSetHeader>(
            `UPDATE calls SET status = ?, ended_at = ?, duration_sec = ? WHERE call_id = ?`,
            ['ended', endedAt, durationSec, callId]
          );
          
          const hangupData = {
            call_id: callId,
            status: 'ended',
            ended_at: endedAt.toISOString(),
            duration_sec: durationSec
          };
          
          socket.emit('call_hungup', hangupData);
          
          // 通知双方挂断，如果是房间则发 MQTT
          if (callData.caller_type === 'room') {
            mqttService.publish(`hotel/device/command/room/${callData.caller_id}`, {
              command_id: Date.now(),
              command_type: 'hangup_call',
              call_id: callId
            });
          } else {
            this.io?.to(`${callData.caller_type}_${callData.caller_id}`).emit('call_hungup', hangupData);
          }

          if (callData.callee_type === 'room') {
            mqttService.publish(`hotel/device/command/room/${callData.callee_id}`, {
              command_id: Date.now(),
              command_type: 'hangup_call',
              call_id: callId
            });
          } else {
            this.io?.to(`${callData.callee_type}_${callData.callee_id}`).emit('call_hungup', hangupData);
          }
          
          logger.info(`通话挂断: ${callId}, 时长: ${durationSec}秒`);
        } catch (error) {
          logger.error('挂断语音通话失败:', error);
          socket.emit('call_error', { message: '挂断语音通话失败' });
        }
      });

      socket.on('get_room_status', async (roomId: string) => {
        try {
          const [sensorRows] = await pool.query<RowDataPacket[]>(
            `SELECT sensor_type, sensor_value, created_at 
             FROM sensor_data 
             WHERE device_id LIKE ? 
             ORDER BY created_at DESC LIMIT 20`,
            [`R${roomId}%`]
          );

          const [deviceRows] = await pool.query<RowDataPacket[]>(
            `SELECT * FROM devices WHERE device_id LIKE ?`,
            [`R${roomId}%`]
          );

          socket.emit('room_status', {
            room_id: roomId,
            sensors: sensorRows,
            devices: deviceRows,
            timestamp: new Date().toISOString()
          });
        } catch (error) {
          logger.error('获取房间状态失败:', error);
          socket.emit('error', { message: '获取房间状态失败' });
        }
      });

      socket.on('get_online_devices', async () => {
        try {
          const devices = await mqttService.getOnlineDevices();
          socket.emit('online_devices', devices);
        } catch (error) {
          logger.error('获取在线设备失败:', error);
        }
      });

      socket.on('disconnect', (reason) => {
        this.clients.delete(socket.id);
        logger.info(`WebSocket客户端断开: ${socket.id}, 原因: ${reason} (当前在线: ${this.clients.size})`);
        this.broadcastOnlineStatus();
      });

      socket.on('error', (error) => {
        logger.error(`Socket错误 (${socket.id}):`, error.message);
      });

      socket.emit('connected', {
        socketId: socket.id,
        timestamp: new Date().toISOString(),
        serverTime: Date.now()
      });
    });

    mqttService.setWebSocket(this);
    logger.info('WebSocket服务已启动');
  }

  emit(event: string, data: any, target?: string) {
    if (!this.io) {
      return;
    }

    if (target) {
      this.io.to(target).emit(event, data);
    } else {
      this.io.emit(event, data);
    }
  }

  emitToClient(clientType: string, clientId: string, event: string, data: any) {
    this.emit(event, data, `${clientType}_${clientId}`);
  }

  broadcastToAll(event: string, data: any) {
    this.emit(event, data);
  }

  getConnectedClients(): number {
    return this.clients.size;
  }

  getRoomClients(roomId: string): string[] {
    const clients: string[] = [];
    this.clients.forEach((info, socketId) => {
      if (info.roomId === roomId) clients.push(socketId);
    });
    return clients;
  }

  getClientsByType(clientType: string): ClientInfo[] {
    const result: ClientInfo[] = [];
    this.clients.forEach((info) => {
      if (info.clientType === clientType) result.push(info);
    });
    return result;
  }

  getIO(): Server | null {
    return this.io;
  }

  async sendOnlineStatus(socket: Socket) {
    try {
      // 1. 获取在线的 WebSocket 客户端
      const onlineWebClients: any[] = [];
      this.clients.forEach((info) => {
        if (info.clientType && info.clientId) {
          onlineWebClients.push({
            type: info.clientType,
            id: info.clientId,
            name: info.clientName
          });
        }
      });

      // 2. 获取在线的 MQTT 硬件设备
      const onlineMqttDevices = await mqttService.getOnlineDevices();
      const onlineRooms = onlineMqttDevices
        .filter(d => d.device_type === 'room_terminal') // 只看房间终端
        .map(d => ({
          type: 'room',
          id: d.device_id.startsWith('R') ? d.device_id.substring(1) : d.device_id,
          name: d.device_name
        }));

      socket.emit('online_status', {
        web: onlineWebClients,
        rooms: onlineRooms,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      logger.error('获取在线状态失败:', error);
    }
  }

  async broadcastOnlineStatus() {
    if (!this.io) return;
    
    try {
      const onlineWebClients: any[] = [];
      this.clients.forEach((info) => {
        if (info.clientType && info.clientId) {
          onlineWebClients.push({
            type: info.clientType,
            id: info.clientId,
            name: info.clientName
          });
        }
      });

      const onlineMqttDevices = await mqttService.getOnlineDevices();
      const onlineRooms = onlineMqttDevices
        .filter(d => d.device_type === 'room_terminal')
        .map(d => ({
          type: 'room',
          id: d.device_id.startsWith('R') ? d.device_id.substring(1) : d.device_id,
          name: d.device_name
        }));

      this.io.emit('online_status', {
        web: onlineWebClients,
        rooms: onlineRooms,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      logger.error('广播在线状态失败:', error);
    }
  }

  close() {
    if (this.io) {
      this.io.disconnectSockets(true);
      this.io.close();
      this.io = null;
    }
    this.clients.clear();
    logger.info('WebSocket服务已关闭');
  }
}

export default new WebSocketService();
