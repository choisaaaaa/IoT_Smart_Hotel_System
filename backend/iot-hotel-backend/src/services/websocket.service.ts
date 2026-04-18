import { Server, Socket } from 'socket.io';
import http from 'http';
import config from '../config';
import logger from '../utils/logger';
import mqttService from './mqtt.service';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import { normalizeRole, CANONICAL_ROLES } from '../utils/role';

interface ClientInfo {
  socketId: string;
  roomId?: string;
  role?: string;
  hotelId?: number;
  userId?: number; // 新增：用户数据库 ID
  isOnDuty?: boolean; // 新增：是否在岗
  dutyRole?: string; // 新增：岗位角色 (reception, cleaning, etc.)
  clientType?: 'room' | 'front_desk' | 'ai' | 'app';
  clientId?: string;
  clientName?: string;
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
        if (!room) {return;}

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
          logger.error('获取房间信息失败:', error.message);
        }
      });

      socket.on('leave_room', (roomId: string) => {
        socket.leave(roomId);
        const info = this.clients.get(socket.id);
        if (info?.roomId === roomId) {info.roomId = undefined;}
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
          let hotelId: number | undefined = undefined;

          // 人员识别逻辑
          if (data.clientType === 'front_desk') {
            // 前台必须从数据库验证，且角色必须是 staff (原 reception) 或管理角色
            const [rows] = await pool.query<RowDataPacket[]>(
              'SELECT id, username, role, hotel_id FROM users WHERE id = ? OR username = ?',
              [data.clientId, data.clientId]
            );
            if (rows.length === 0) {
              socket.emit('error', { message: '身份验证失败：未找到该员工/用户' });
              return;
            }
            
            const user = rows[0];
            const normalizedRole = normalizeRole(user.role);
            if (normalizedRole === CANONICAL_ROLES.CUSTOMER || normalizedRole === CANONICAL_ROLES.GUEST) {
              socket.emit('error', { message: '身份验证失败：普通顾客/游客无法以柜台身份登录' });
              return;
            }
            
            displayName = user.username;
            hotelId = user.hotel_id;
            
            // 更新客户端信息中的用户 ID 和 默认在岗状态
            const info = this.clients.get(socket.id);
            if (info) {
              info.userId = user.id;
              info.role = user.role;
              info.isOnDuty = true; // 默认登录即在岗
              info.dutyRole = user.role === 'staff' ? 'reception' : user.role;
            }
          } else if (data.clientType === 'app') {
            if (data.clientId.startsWith('guest_')) {
              const roomId = data.clientId.replace('guest_', '');
              displayName = `顾客${roomId}`;
              const [roomRows] = await pool.query<RowDataPacket[]>(
                'SELECT hotel_id FROM rooms WHERE id = ?',
                [roomId]
              );
              if (roomRows.length > 0) {
                hotelId = roomRows[0].hotel_id;
              }
            } else {
              const [userRows] = await pool.query<RowDataPacket[]>(
                'SELECT id, username, hotel_id FROM users WHERE id = ? OR username = ?',
                [data.clientId, data.clientId]
              );
              if (userRows.length > 0) {
                const user = userRows[0];
                displayName = user.username;
                const userId = user.id;
                if (user.hotel_id) {
                  hotelId = user.hotel_id;
                }
                const [bookings] = await pool.query<RowDataPacket[]>(
                  `SELECT r.hotel_id FROM bookings b JOIN rooms r ON b.room_id = r.id
                   WHERE b.user_id = ? AND b.status IN ('checked_in', 'pre_checked_in') LIMIT 1`,
                  [userId]
                );
                if (bookings.length > 0) {
                  hotelId = bookings[0].hotel_id;
                }
              } else {
                displayName = data.clientId;
              }
            }
          } else if (data.clientType === 'room') {
            const [rows] = await pool.query<RowDataPacket[]>(
              'SELECT id, room_number, hotel_id FROM rooms WHERE id = ? OR room_number = ?',
              [data.clientId, data.clientId]
            );
            if (rows.length > 0) {
              const room = rows[0];
              displayName = `客房 ${room.room_number}`;
              hotelId = room.hotel_id;
              // 强制将 clientId 统一为数据库 ID，确保全局唯一
              data.clientId = String(room.id);
            }
          }
          
          const info = this.clients.get(socket.id);
          if (info) {
            info.clientType = data.clientType;
            info.clientId = data.clientId;
            info.clientName = displayName;
            info.hotelId = hotelId;
            
            // 1. 门店隔离：加入基于酒店的类型房间（强制隔离，不再加入全局类型房间）
            if (hotelId) {
              const hotelTypeRoom = `${data.clientType}_hotel_${hotelId}`;
              socket.join(hotelTypeRoom);
              logger.info(`客户端 ${socket.id} 加入门店隔离房间: ${hotelTypeRoom}`);
            } else {
              // 如果没有酒店ID（如系统管理员），则加入全局房间作为兜底
              socket.join(data.clientType);
              logger.info(`客户端 ${socket.id} 加入全局类型房间: ${data.clientType}`);
            }

            // 2. 加入个人专属房间，用于接收定向消息
            const personalRoom = `${data.clientType}_${data.clientId}`;
            socket.join(personalRoom);
            logger.info(`客户端 ${socket.id} 加入个人专属房间: ${personalRoom}`);

            // 3. 移除 legacy 的全局 'front_desk' 房间，防止跨店泄露
            // if (data.clientType === 'front_desk') { socket.join('front_desk'); }
            
            this.broadcastOnlineStatus();
          }
          
          socket.emit('registered', {
            clientType: data.clientType,
            clientId: data.clientId,
            clientName: displayName,
            hotelId: hotelId,
            webrtcConfig: config.webrtc,
            timestamp: new Date().toISOString()
          });
          
          logger.info(`客户端 ${socket.id} 注册为: ${data.clientType}/${displayName}`);
        } catch (error) {
          logger.error('注册客户端失败:', error.message);
          socket.emit('error', { message: '注册失败' });
        }
      });

      socket.on('set_duty_status', (data: { isOnDuty: boolean, dutyRole?: string }) => {
        const info = this.clients.get(socket.id);
        if (info && info.clientType === 'front_desk') {
          info.isOnDuty = data.isOnDuty;
          if (data.dutyRole) {info.dutyRole = data.dutyRole;}
          
          logger.info(`员工 ${info.clientName} 更新在岗状态: ${data.isOnDuty ? '在岗' : '离岗'} (${info.dutyRole})`);
          this.broadcastOnlineStatus();
          socket.emit('duty_status_updated', { isOnDuty: info.isOnDuty, dutyRole: info.dutyRole });
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
        caller_type: 'room' | 'front_desk' | 'ai' | 'app'; 
        caller_id: string; 
        callee_type: 'room' | 'front_desk' | 'ai' | 'app';
        callee_id: string;
        type?: 'voice' | 'video'
      }) => {
        try {
          let { caller_type, caller_id, callee_type, callee_id, type: callType = 'voice' } = data;
          const clientInfo = this.clients.get(socket.id);

          const validTypes = ['room', 'front_desk', 'ai', 'app'];
          
          if (!validTypes.includes(caller_type)) {
            socket.emit('call_error', { message: `无效的caller_type，支持的值: ${validTypes.join(', ')}` });
            return;
          }
          
          if (!validTypes.includes(callee_type)) {
            socket.emit('call_error', { message: `无效的callee_type，支持的值: ${validTypes.join(', ')}` });
            return;
          }

          if (caller_type === 'room') {
            const [roomRows] = await pool.query<RowDataPacket[]>(
              'SELECT id FROM rooms WHERE id = ? OR room_number = ?',
              [caller_id, caller_id]
            );
            if (roomRows.length > 0) {
              caller_id = String(roomRows[0].id);
            }
          }

          if (callee_type === 'room') {
            const [roomRows] = await pool.query<RowDataPacket[]>(
              'SELECT id FROM rooms WHERE id = ? OR room_number = ?',
              [callee_id, callee_id]
            );
            if (roomRows.length > 0) {
              callee_id = String(roomRows[0].id);
            }
          }

          // 关键修复：呼叫权限校验与跨店呼叫隔离
          const callerHotelId = clientInfo?.hotelId;
          
          if (caller_type === 'room' || caller_type === 'app') {
            // 1. 验证主叫方是否为已入住用户
            const [callerCheckin] = await pool.query<RowDataPacket[]>(
              `SELECT id, hotel_id FROM bookings 
               WHERE (room_id = ? OR user_id = ?) AND status = 'checked_in'
               LIMIT 1`,
              [caller_id, clientInfo?.userId]
            );

            if (callerCheckin.length === 0) {
              socket.emit('call_error', { message: '权限不足：客房服务仅对已入住用户开放' });
              return;
            }

            // 2. 强制酒店隔离（如果是呼叫特定目标，非 broadcast 模式）
            if (callee_type === 'room') {
              const [calleeRoom] = await pool.query<RowDataPacket[]>(
                'SELECT hotel_id FROM rooms WHERE id = ? OR room_number = ?',
                [callee_id, callee_id]
              );
              if (calleeRoom.length > 0 && calleeRoom[0].hotel_id !== callerHotelId) {
                socket.emit('call_error', { message: '非法操作：禁止跨店呼叫其他房间' });
                return;
              }
            } else if (callee_type === 'front_desk' && callee_id !== 'all' && callee_id !== 'staff') {
              const [calleeStaff] = await pool.query<RowDataPacket[]>(
                'SELECT hotel_id FROM users WHERE id = ? OR username = ?',
                [callee_id, callee_id]
              );
              if (calleeStaff.length > 0 && calleeStaff[0].hotel_id !== callerHotelId) {
                socket.emit('call_error', { message: '非法操作：禁止跨店呼叫前台人员' });
                return;
              }
            }
          }
          
          const callId = `CALL${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${Math.random().toString(36).substring(2, 10).toUpperCase()}`;
          
          let calleeExists = false;
          
          switch (callee_type) {
            case 'room':
              const [room] = await pool.query<RowDataPacket[]>('SELECT id, room_number FROM rooms WHERE id = ? OR room_number = ?', [callee_id, callee_id]);
              calleeExists = room.length > 0;
              break;
            case 'front_desk':
              // 如果是呼叫所有前台（all 或 staff），则不需要检查具体用户
              if (callee_id === 'all' || callee_id === 'staff') {
                calleeExists = true;
              } else {
                const [employee] = await pool.query<RowDataPacket[]>('SELECT id FROM users WHERE id = ? OR username = ?', [callee_id, callee_id]);
                calleeExists = employee.length > 0;
              }
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
            `INSERT INTO calls (call_id, caller_type, caller_id, callee_type, callee_id, hotel_id, status, started_at) 
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
            [callId, caller_type, caller_id, callee_type, callee_id, callerHotelId, 'calling', new Date()]
          );
          
          // 1. 获取主叫方的酒店信息（如果是房间）
          let callerHotelName = '';
          if (caller_type === 'room') {
            const [hotelRows] = await pool.query<RowDataPacket[]>(
              'SELECT h.hotel_name FROM rooms r JOIN hotels h ON r.hotel_id = h.id WHERE r.id = ? OR r.room_number = ?',
              [caller_id, caller_id]
            );
            if (hotelRows.length > 0) {
              callerHotelName = hotelRows[0].hotel_name;
            }
          }

          const callData = {
            call_id: callId,
            caller_type,
            caller_id,
            caller_name: clientInfo?.clientName || caller_id,
            hotel_name: callerHotelName, // 新增：所属酒店
            callee_type,
            callee_id,
            status: 'calling',
            type: callType,
            started_at: new Date().toISOString()
          };
          
          socket.emit('call_initiated', callData);
          
          // 如果是呼叫所有前台，广播到所属酒店的前台房间
          if (callee_type === 'front_desk' && (callee_id === 'all' || callee_id === 'staff')) {
            // 获取主叫方的酒店ID
            const callerHotelId = clientInfo?.hotelId;
            if (callerHotelId) {
              // --- 智能调度逻辑 ---
              // 1. 查找该酒店所有“在岗”且“角色匹配”的员工
              const onDutyStaff = Array.from(this.clients.values()).filter(c => 
                c.clientType === 'front_desk' && 
                c.hotelId === callerHotelId && 
                c.isOnDuty === true &&
                (callee_id === 'all' || c.dutyRole === 'reception') // 呼叫 all 则所有在岗都响，呼叫 staff 则仅前台岗位响
              );

              if (onDutyStaff.length > 0) {
                onDutyStaff.forEach(staff => {
                  this.io?.to(staff.socketId).emit('incoming_call', callData);
                });
                logger.info(`呼叫已路由到 ${onDutyStaff.length} 名在岗员工`);
              } else {
                // 2. 如果没有人在线/在岗，则广播到该门店所有前台
                const hotelRoom = `front_desk_hotel_${callerHotelId}`;
                this.io?.to(hotelRoom).emit('incoming_call', callData);
                logger.info(`无在岗员工，广播到门店房间: ${hotelRoom}`);
              }
            } else {
              // 关键修复：如果没有酒店ID，不允许呼叫前台广播
              logger.error(`主叫方 ${socket.id} 缺少酒店ID，拒绝呼叫前台广播`);
              socket.emit('call_error', { message: '系统错误：主叫方所属门店信息丢失，请重新登录' });
            }
          } else {
            const targetRoom = `${callee_type}_${callee_id}`;
            logger.info(`发送 incoming_call 到房间: ${targetRoom}, 数据:`, callData);
            this.io?.to(targetRoom).emit('incoming_call', callData);
          }
          
          logger.info(`通话发起: ${caller_type}/${caller_id} -> ${callee_type}/${callee_id} (${callId})`);
        } catch (error) {
          logger.error('发起语音通话失败:', error.message);
          socket.emit('call_error', { message: '发起语音通话失败' });
        }
      });

      // --- WebRTC 信令转发 ---
      
      socket.on('webrtc_offer', async (data: { 
        target_type: 'room' | 'front_desk' | 'ai' | 'app'; 
        target_id: string; 
        offer: any;
        call_id: string;
      }) => {
        let { target_type, target_id, offer, call_id } = data;
        
        if (target_type === 'room') {
          const [roomRows] = await pool.query<RowDataPacket[]>(
            'SELECT id FROM rooms WHERE id = ? OR room_number = ?',
            [target_id, target_id]
          );
          if (roomRows.length > 0) {
            target_id = String(roomRows[0].id);
          }
        }
        
        logger.info(`[WebRTC] 收到Offer: ${socket.id} -> ${target_type}_${target_id}, call_id: ${call_id}`);
        
        if (target_type === 'room') {
          // 检查房间是否有WebSocket客户端在线
          const roomClients = Array.from(this.clients.entries()).filter(
            ([_, client]) => client.clientType === 'room' && client.clientId === target_id
          );
          
          logger.info(`[WebRTC] 房间${target_id}的WebSocket客户端数量: ${roomClients.length}`);
          
          // 打印所有已注册的客户端，用于调试
          const allClients = Array.from(this.clients.entries()).map(([id, client]) => ({
            socketId: id,
            clientType: client.clientType,
            clientId: client.clientId,
            roomId: client.roomId
          }));
          logger.info(`[WebRTC] 所有已注册客户端: ${JSON.stringify(allClients)}`);
          
          if (roomClients.length > 0) {
            // 通过WebSocket转发给房间的Web端
            const targetRoom = `room_${target_id}`;
            this.io?.to(targetRoom).emit('webrtc_offer', {
              from_type: this.clients.get(socket.id)?.clientType,
              from_id: this.clients.get(socket.id)?.clientId,
              offer: offer,
              call_id: call_id
            });
            logger.info(`[WebRTC] Offer通过WebSocket发送给房间: ${targetRoom}`);
          } else {
            // 通过MQTT转发给硬件
            mqttService.publish(`hotel/call/signaling/${call_id}`, {
              from_type: this.clients.get(socket.id)?.clientType,
              from_id: this.clients.get(socket.id)?.clientId,
              type: 'offer',
              offer: offer,
              target_type: 'room',
              target_id: target_id
            });
            logger.info(`[WebRTC] Offer通过MQTT发送给硬件房间: ${target_id}`);
          }
        } else if (target_type === 'front_desk' && target_id === 'all') {
          // 集体呼叫模式：广播给当前酒店的所有在线前台
          const senderHotelId = this.clients.get(socket.id)?.hotelId;
          this.clients.forEach((client, socketId) => {
            if (client.clientType === 'front_desk' && client.hotelId === senderHotelId) {
              this.io?.to(socketId).emit('webrtc_offer', {
                from_type: this.clients.get(socket.id)?.clientType,
                from_id: this.clients.get(socket.id)?.clientId,
                offer: offer,
                call_id: call_id
              });
            }
          });
        } else {
          // 否则通过 WebSocket 转发
          this.io?.to(`${target_type}_${target_id}`).emit('webrtc_offer', {
            from_type: this.clients.get(socket.id)?.clientType,
            from_id: this.clients.get(socket.id)?.clientId,
            offer: offer,
            call_id: call_id
          });
        }
      });

      socket.on('webrtc_answer', async (data: { 
        target_type: 'room' | 'front_desk' | 'ai' | 'app'; 
        target_id: string; 
        answer: any;
        call_id: string;
      }) => {
        let { target_type, target_id, answer, call_id } = data;

        if (target_type === 'room') {
          const [roomRows] = await pool.query<RowDataPacket[]>(
            'SELECT id FROM rooms WHERE id = ? OR room_number = ?',
            [target_id, target_id]
          );
          if (roomRows.length > 0) {
            target_id = String(roomRows[0].id);
          }
        }

        logger.info(`转发 WebRTC Answer: ${socket.id} -> ${target_type}_${target_id}`);
        
        if (target_type === 'room') {
          // 检查房间是否有WebSocket客户端在线
          const roomClients = Array.from(this.clients.entries()).filter(
            ([_, client]) => client.clientType === 'room' && client.clientId === target_id
          );
          
          if (roomClients.length > 0) {
            // 通过WebSocket转发给房间的Web端
            this.io?.to(`room_${target_id}`).emit('webrtc_answer', {
              from_type: this.clients.get(socket.id)?.clientType,
              from_id: this.clients.get(socket.id)?.clientId,
              answer: answer,
              call_id: call_id
            });
            logger.info(`WebRTC Answer通过WebSocket发送给房间: room_${target_id}`);
          } else {
            // 通过MQTT转发给硬件
            mqttService.publish(`hotel/call/signaling/${call_id}`, {
              from_type: this.clients.get(socket.id)?.clientType,
              from_id: this.clients.get(socket.id)?.clientId,
              type: 'answer',
              answer: answer,
              target_type: 'room',
              target_id: target_id
            });
            logger.info(`WebRTC Answer通过MQTT发送给硬件房间: ${target_id}`);
          }
        } else if (target_type === 'front_desk' && target_id === 'all') {
          // 集体呼叫模式：广播给当前酒店的所有在线前台
          const senderHotelId = this.clients.get(socket.id)?.hotelId;
          this.clients.forEach((client, socketId) => {
            if (client.clientType === 'front_desk' && client.hotelId === senderHotelId) {
              this.io?.to(socketId).emit('webrtc_answer', {
                from_type: this.clients.get(socket.id)?.clientType,
                from_id: this.clients.get(socket.id)?.clientId,
                answer: answer,
                call_id: call_id
              });
            }
          });
        } else {
          this.io?.to(`${target_type}_${target_id}`).emit('webrtc_answer', {
            from_type: this.clients.get(socket.id)?.clientType,
            from_id: this.clients.get(socket.id)?.clientId,
            answer: answer,
            call_id: call_id
          });
        }
      });

      socket.on('webrtc_ice_candidate', async (data: { 
        target_type: 'room' | 'front_desk' | 'ai' | 'app'; 
        target_id: string; 
        candidate: any;
        call_id: string;
      }) => {
        let { target_type, target_id, candidate, call_id } = data;

        if (target_type === 'room') {
          const [roomRows] = await pool.query<RowDataPacket[]>(
            'SELECT id FROM rooms WHERE id = ? OR room_number = ?',
            [target_id, target_id]
          );
          if (roomRows.length > 0) {
            target_id = String(roomRows[0].id);
          }
        }

        if (target_type === 'room') {
          // 检查房间是否有WebSocket客户端在线
          const roomClients = Array.from(this.clients.entries()).filter(
            ([_, client]) => client.clientType === 'room' && client.clientId === target_id
          );
          
          if (roomClients.length > 0) {
            // 通过WebSocket转发给房间的Web端
            this.io?.to(`room_${target_id}`).emit('webrtc_ice_candidate', {
              from_type: this.clients.get(socket.id)?.clientType,
              from_id: this.clients.get(socket.id)?.clientId,
              candidate: candidate,
              call_id: call_id
            });
          } else {
            // 通过MQTT转发给硬件
            mqttService.publish(`hotel/call/signaling/${call_id}`, {
              from_type: this.clients.get(socket.id)?.clientType,
              from_id: this.clients.get(socket.id)?.clientId,
              type: 'ice_candidate',
              candidate: candidate,
              target_type: 'room',
              target_id: target_id
            });
          }
        } else if (target_type === 'front_desk' && target_id === 'all') {
          // 集体呼叫模式：广播给当前酒店的所有在线前台
          const senderHotelId = this.clients.get(socket.id)?.hotelId;
          this.clients.forEach((client, socketId) => {
            if (client.clientType === 'front_desk' && client.hotelId === senderHotelId) {
              this.io?.to(socketId).emit('webrtc_ice_candidate', {
                from_type: this.clients.get(socket.id)?.clientType,
                from_id: this.clients.get(socket.id)?.clientId,
                candidate: candidate,
                call_id: call_id
              });
            }
          });
        } else {
          this.io?.to(`${target_type}_${target_id}`).emit('webrtc_ice_candidate', {
            from_type: this.clients.get(socket.id)?.clientType,
            from_id: this.clients.get(socket.id)?.clientId,
            candidate: candidate,
            call_id: call_id
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

      socket.on('answer_call', async (data: { callId?: string; call_id?: string }) => {
        try {
          const callId = String(data.callId || data.call_id).trim();
          const currentClient = this.clients.get(socket.id);
          
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

          let normalizedCallerId = String(callData.caller_id);
          let normalizedCalleeId = String(callData.callee_id);

          if (callData.caller_type === 'room') {
            const [roomRows] = await pool.query<RowDataPacket[]>(
              'SELECT id FROM rooms WHERE id = ? OR room_number = ?',
              [callData.caller_id, callData.caller_id]
            );
            if (roomRows.length > 0) {
              normalizedCallerId = String(roomRows[0].id);
            }
          }

          if (callData.callee_type === 'room') {
            const [roomRows] = await pool.query<RowDataPacket[]>(
              'SELECT id FROM rooms WHERE id = ? OR room_number = ?',
              [callData.callee_id, callData.callee_id]
            );
            if (roomRows.length > 0) {
              normalizedCalleeId = String(roomRows[0].id);
            }
          }
          
          const [result] = await pool.query<ResultSetHeader>(
            `UPDATE calls SET status = ?, answered_at = ? WHERE call_id = ?`,
            ['connected', new Date(), callId]
          );
          
          const answerData = {
            call_id: callId,
            status: 'connected',
            answered_at: new Date().toISOString(),
            caller_type: callData.caller_type,
            caller_id: callData.caller_id,
            callee_type: callData.callee_type,
            callee_id: callData.callee_id
          };
          
          // 1. 通知主叫方（使用标准化ID精准通知个人房间）
          const callerRoom = `${callData.caller_type}_${normalizedCallerId}`;
          logger.info(`发送 call_answered 到主叫房间: ${callerRoom} (原始caller_id: ${callData.caller_id})`);
          this.io?.to(callerRoom).emit('call_answered', answerData);
          
          // 2. 通知被叫方（使用标准化ID精准通知个人房间）
          const calleeRoom = `${callData.callee_type}_${normalizedCalleeId}`;
          logger.info(`发送 call_answered 到被叫方房间: ${calleeRoom} (原始callee_id: ${callData.callee_id})`);
          this.io?.to(calleeRoom).emit('call_answered', answerData);
          
          // 3. 通知该门店的所有前台（同步状态）
          const hId = callData.hotel_id || currentClient?.hotelId;
          if (hId) {
            const hotelRoom = `front_desk_hotel_${hId}`;
            this.io?.to(hotelRoom).emit('call_answered', answerData);
          }
          
          // 如果是拨给房间，通知硬件接通
          if (callData.callee_type === 'room') {
            mqttService.publish(`hotel/device/command/room/${normalizedCalleeId}`, {
              command_id: Date.now(),
              command_type: 'answer_call',
              call_id: callId
            });
          }
          
          logger.info(`通话接听: ${callId}`);
        } catch (error) {
          logger.error('接听语音通话失败:', error.message);
          socket.emit('call_error', { message: '接听语音通话失败' });
        }
      });

      socket.on('reject_call', async (data: { callId?: string; call_id?: string }) => {
        try {
          const callId = String(data.callId || data.call_id).trim();
          const currentClient = this.clients.get(socket.id);
          
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
          
          let normalizedCalleeId = String(callData.callee_id);
          if (callData.callee_type === 'room') {
            const [roomRows] = await pool.query<RowDataPacket[]>(
              'SELECT id FROM rooms WHERE id = ? OR room_number = ?',
              [callData.callee_id, callData.callee_id]
            );
            if (roomRows.length > 0) {
              normalizedCalleeId = String(roomRows[0].id);
            }
          }

          // 如果是拨给房间，通知硬件拒接
          if (callData.callee_type === 'room') {
            mqttService.publish(`hotel/device/command/room/${normalizedCalleeId}`, {
              command_id: Date.now(),
              command_type: 'reject_call',
              call_id: callId
            });
          }
          
          // 通知主叫方（使用标准化ID）
          let normalizedCallerId = String(callData.caller_id);
          if (callData.caller_type === 'room') {
            const [roomRows] = await pool.query<RowDataPacket[]>(
              'SELECT id FROM rooms WHERE id = ? OR room_number = ?',
              [callData.caller_id, callData.caller_id]
            );
            if (roomRows.length > 0) {
              normalizedCallerId = String(roomRows[0].id);
            }
          }
          this.io?.to(`${callData.caller_type}_${normalizedCallerId}`).emit('call_rejected', rejectData);
          
          const hId = callData.hotel_id || currentClient?.hotelId;
          if (hId) {
            const hotelRoom = `front_desk_hotel_${hId}`;
            this.io?.to(hotelRoom).emit('call_rejected', rejectData);
          }
          
          logger.info(`通话拒接: ${callId}`);
        } catch (error) {
          logger.error('拒接语音通话失败:', error.message);
          socket.emit('call_error', { message: '拒接语音通话失败' });
        }
      });

      socket.on('hangup_call', async (data: { callId?: string; call_id?: string }) => {
        try {
          const callId = String(data.callId || data.call_id).trim();
          const currentClient = this.clients.get(socket.id);
          
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
          
          let normalizedCallerId = String(callData.caller_id);
          if (callData.caller_type === 'room') {
            const [roomRows] = await pool.query<RowDataPacket[]>(
              'SELECT id FROM rooms WHERE id = ? OR room_number = ?',
              [callData.caller_id, callData.caller_id]
            );
            if (roomRows.length > 0) {
              normalizedCallerId = String(roomRows[0].id);
            }
          }

          let normalizedCalleeId = String(callData.callee_id);
          if (callData.callee_type === 'room') {
            const [roomRows] = await pool.query<RowDataPacket[]>(
              'SELECT id FROM rooms WHERE id = ? OR room_number = ?',
              [callData.callee_id, callData.callee_id]
            );
            if (roomRows.length > 0) {
              normalizedCalleeId = String(roomRows[0].id);
            }
          }

          // 通知双方挂断，如果是房间则发 MQTT
          if (callData.caller_type === 'room') {
            mqttService.publish(`hotel/device/command/room/${normalizedCallerId}`, {
              command_id: Date.now(),
              command_type: 'hangup_call',
              call_id: callId
            });
            this.io?.to(`${callData.caller_type}_${normalizedCallerId}`).emit('call_hungup', hangupData);
          } else {
            this.io?.to(`${callData.caller_type}_${normalizedCallerId}`).emit('call_hungup', hangupData);
          }

          if (callData.callee_type === 'room') {
            mqttService.publish(`hotel/device/command/room/${normalizedCalleeId}`, {
              command_id: Date.now(),
              command_type: 'hangup_call',
              call_id: callId
            });
            this.io?.to(`${callData.callee_type}_${normalizedCalleeId}`).emit('call_hungup', hangupData);
          } else {
            this.io?.to(`${callData.callee_type}_${normalizedCalleeId}`).emit('call_hungup', hangupData);
          }
          
          const hId = callData.hotel_id || currentClient?.hotelId;
          if (hId) {
            const hotelRoom = `front_desk_hotel_${hId}`;
            this.io?.to(hotelRoom).emit('call_hungup', hangupData);
          }
          
          logger.info(`通话挂断: ${callId}, 时长: ${durationSec}秒`);
        } catch (error) {
          logger.error('挂断语音通话失败:', error.message);
          socket.emit('call_error', { message: '挂断语音通话失败' });
        }
      });

      // 信号送达确认（Ack）机制：客户端收到核心信令后回复确认，防止丢包
      socket.on('call_signal_ack', (data: { call_id: string, signal_type: string }) => {
        logger.info(`[Ack] 收到信号确认: ${data.signal_type} for ${data.call_id} from ${socket.id}`);
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
          logger.error('获取房间状态失败:', error.message);
          socket.emit('error', { message: '获取房间状态失败' });
        }
      });

      socket.on('get_online_devices', async () => {
        try {
          const devices = await mqttService.getOnlineDevices();
          socket.emit('online_devices', devices);
        } catch (error) {
          logger.error('获取在线设备失败:', error.message);
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
      if (info.roomId === roomId) {clients.push(socketId);}
    });
    return clients;
  }

  /**
   * 发送在线状态给特定客户端
   */
  private sendOnlineStatus(socket: Socket) {
    const clientInfo = this.clients.get(socket.id);
    const hotelId = clientInfo?.hotelId;

    const data = {
      web: this.getClientsByType('front_desk', hotelId),
      rooms: this.getClientsByType('room', hotelId),
      ai: this.getClientsByType('ai', hotelId),
      app: this.getClientsByType('app', hotelId)
    };
    socket.emit('online_status', data);
  }

  /**
   * 广播在线状态给所有相关客户端
   */
  private broadcastOnlineStatus() {
    // 方案 A: 简单广播所有（不安全，但简单）
    // 方案 B: 分酒店广播（推荐）
    
    // 我们获取所有唯一的酒店ID
    const hotelIds = new Set<number>();
    for (const info of this.clients.values()) {
      if (info.hotelId) {hotelIds.add(info.hotelId);}
    }

    // 为每个酒店广播
    for (const hotelId of hotelIds) {
      const data = {
        web: this.getClientsByType('front_desk', hotelId),
        rooms: this.getClientsByType('room', hotelId),
        ai: this.getClientsByType('ai', hotelId),
        app: this.getClientsByType('app', hotelId)
      };
      
      // 发送给该酒店的前台房间
      this.io?.to(`front_desk_hotel_${hotelId}`).emit('online_status', data);
    }
  }

  /**
   * 获取特定类型的客户端列表
   */
  public getClientsByType(type: string, hotelId?: number): any[] {
    const list: any[] = [];
    for (const info of this.clients.values()) {
      if (info.clientType === type) {
        // 如果指定了 hotelId，则过滤
        if (hotelId !== undefined && info.hotelId !== hotelId) {
          continue;
        }
        
        list.push({
          id: info.clientId,
          name: info.clientName,
          type: info.clientType,
          isOnDuty: info.isOnDuty,
          dutyRole: info.dutyRole,
          connectedAt: info.connectedAt
        });
      }
    }
    return list;
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

  // 获取 io 实例（用于从外部发送事件）
  getIO(): Server | null {
    return this.io;
  }

  // 通知前台有AI转接的来电（定向）
  notifyIncomingCall(callData: any) {
    if (!this.io) {return;}
    
    // 确保定向通知也遵循酒店隔离（如果 callData 中有 hotel_id）
    const targetRoom = `${callData.callee_type}_${callData.callee_id}`;
    this.io.to(targetRoom).emit('incoming_call', callData);
    logger.info(`AI转接通知已发送: ${targetRoom}`);
  }

  // 广播AI转接来电给特定酒店的所有前台
  broadcastIncomingCall(callData: any, hotelId?: number) {
    if (!this.io) {return;}
    
    const hId = hotelId || callData.hotel_id;
    if (hId) {
      const hotelRoom = `front_desk_hotel_${hId}`;
      this.io.to(hotelRoom).emit('incoming_call', callData);
      logger.info(`AI转接广播已发送: 门店 ${hId}, 呼叫ID: ${callData.call_id}`);
    } else {
      // 关键修复：禁止全局广播，防止跨店泄露
      logger.error(`AI转接广播失败：缺少酒店ID，无法路由。呼叫ID: ${callData.call_id}`);
    }
  }
}

const webSocketService = new WebSocketService();
export default webSocketService;

export function getWebSocketService(): WebSocketService {
  return webSocketService;
}
