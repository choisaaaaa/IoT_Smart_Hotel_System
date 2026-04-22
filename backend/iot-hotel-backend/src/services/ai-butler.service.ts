import pool, { RowDataPacket } from '../config/database';
import logger from '../utils/logger';
import axios from 'axios';
import crypto from 'crypto';
import WebSocket from 'ws';
import { KnowledgeBaseService } from './knowledge-base.service';
import mqttService from './mqtt.service';

interface AIRequest {
  roomId: string;
  guestId?: string;
  audioData?: string; // base64音频
  text?: string;
  sessionId: string;
}

interface AIResponse {
  text: string;
  audioUrl?: string;
  action?: string;
  target?: string;
  response?: string;
  callId?: number;
  frontDeskCount?: number;
  toolCalls?: any[];
  ticketData?: any;
  hotelName?: string;
}

interface GuestSession {
  roomId: string;
  roomDbId: number;
  hotelId: number;
  hotelName: string;
  guestId: number;
  bookingId: number;
  guestName: string;
  checkInDate: string;
  checkOutDate: string;
  isValid: boolean;
}

export class AIButlerService {
  private static instance: AIButlerService;
  private sessions: Map<string, GuestSession> = new Map();

  // API配置
  private zhipuApiKey = process.env.ZHIPU_API_KEY || '';
  private xfyunAppId = process.env.XFYUN_APP_ID || '';
  private xfyunApiKey = process.env.XFYUN_API_KEY || '';
  private xfyunApiSecret = process.env.XFYUN_API_SECRET || '';
  private aliyunAccessKey = process.env.ALIYUN_ACCESS_KEY || '';
  private aliyunAccessSecret = process.env.ALIYUN_ACCESS_SECRET || '';
  private aliyunAppKey = process.env.ALIYUN_APP_KEY || '';

  // 工具定义（Function Calling）
  private tools = [
    {
      type: 'function',
      function: {
        name: 'control_device',
        description: '控制房间内的智能设备（灯光、空调、窗帘、电视等）',
        parameters: {
          type: 'object',
          properties: {
            device_type: {
              type: 'string',
              enum: ['light', 'ac', 'curtain', 'tv', 'lock', 'all'],
              description: '设备类型：light=灯, ac=空调, curtain=窗帘, tv=电视, lock=门锁, all=全部'
            },
            action: {
              type: 'string',
              enum: ['on', 'off', 'toggle', 'set_temperature', 'set_brightness', 'open', 'close'],
              description: '操作：on=开, off=关, toggle=切换, set_temperature=设置温度, set_brightness=设置亮度, open=打开, close=关闭'
            },
            value: {
              type: 'number',
              description: '参数值（温度、亮度等），可选'
            }
          },
          required: ['device_type', 'action']
        }
      }
    },
    {
      type: 'function',
      function: {
        name: 'get_room_status',
        description: '查询房间当前状态（设备状态、温度、湿度等）',
        parameters: {
          type: 'object',
          properties: {},
          required: []
        }
      }
    },
    {
      type: 'function',
      function: {
        name: 'request_service',
        description: '请求客房服务（清洁、维修、送餐、送物品等）',
        parameters: {
          type: 'object',
          properties: {
            service_type: {
              type: 'string',
              enum: ['cleaning', 'maintenance', 'room_service', 'towels', 'water', 'other'],
              description: '服务类型：cleaning=保洁, maintenance=维修, room_service=送餐, towels=换毛巾, water=送水, other=其他'
            },
            description: {
              type: 'string',
              description: '服务详细描述（如：空调不制冷、需要2瓶矿泉水等）'
            },
            urgency: {
              type: 'string',
              enum: ['normal', 'urgent', 'emergency'],
              description: '紧急程度：normal=普通, urgent=紧急, emergency=非常紧急'
            }
          },
          required: ['service_type', 'description']
        }
      }
    },
    {
      type: 'function',
      function: {
        name: 'get_hotel_info',
        description: '查询酒店信息（餐厅时间、健身房、WiFi密码、周边推荐等）',
        parameters: {
          type: 'object',
          properties: {
            info_type: {
              type: 'string',
              enum: ['restaurant', 'gym', 'wifi', 'nearby', 'checkout', 'breakfast', 'all'],
              description: '信息类型：restaurant=餐厅, gym=健身房, wifi=WiFi, nearby=周边, checkout=退房, breakfast=早餐, all=全部'
            }
          },
          required: ['info_type']
        }
      }
    },
    {
      type: 'function',
      function: {
        name: 'transfer_to_human',
        description: '转接人工前台服务（进行语音通话）',
        parameters: {
          type: 'object',
          properties: {
            reason: {
              type: 'string',
              description: '转接原因'
            }
          },
          required: []
        }
      }
    },
    {
      type: 'function',
      function: {
        name: 'voice_call',
        description: '呼叫前台或拨打语音电话',
        parameters: {
          type: 'object',
          properties: {
            target: {
              type: 'string',
              enum: ['front_desk', 'room_service', 'maintenance'],
              description: '呼叫目标：front_desk=前台, room_service=送餐部, maintenance=维修部'
            }
          },
          required: ['target']
        }
      }
    }
  ];

  static getInstance(): AIButlerService {
    if (!AIButlerService.instance) {
      AIButlerService.instance = new AIButlerService();
    }
    return AIButlerService.instance;
  }

  /**
   * 验证客人入住状态
   */
  async verifyGuestAccess(roomId: string): Promise<GuestSession | null> {
    try {
      let actualRoomDbId: number | null = null;
      let actualRoomNumber: string | null = null;
      let deviceFoundId: string | null = null;

      logger.debug(`验证入住状态 - 原始roomId: ${roomId}`);

      // 策略1: 直接作为 device_id 查找
      const [deviceRows] = await pool.query<RowDataPacket[]>(
        `SELECT d.device_id, d.room_id, r.room_number FROM devices d
         LEFT JOIN rooms r ON d.room_id = r.id
         WHERE d.device_id = ? AND d.room_id IS NOT NULL`,
        [roomId]
      );
      if (deviceRows.length > 0) {
        actualRoomDbId = deviceRows[0].room_id;
        actualRoomNumber = deviceRows[0].room_number;
        deviceFoundId = deviceRows[0].device_id;
        logger.info(`通过设备ID ${roomId} 解析到房间DB ID ${actualRoomDbId}, 房号 ${actualRoomNumber}`);
      }

      // 策略2: 如果策略1失败，尝试从 roomId 中提取数字作为 room_id
      if (!actualRoomDbId) {
        const numericId = roomId.replace(/^room_?/, '');
        if (numericId && /^\d+$/.test(numericId)) {
          const numId = parseInt(numericId);
          const [roomRows] = await pool.query<RowDataPacket[]>(
            `SELECT r.id, r.room_number FROM rooms r WHERE r.id = ?`,
            [numId]
          );
          if (roomRows.length > 0) {
            actualRoomDbId = roomRows[0].id;
            actualRoomNumber = roomRows[0].room_number;
            logger.info(`通过解析数字 ${numId} 找到房间DB ID ${actualRoomDbId}, 房号 ${actualRoomNumber}`);
          }
        }
      }

      // 策略3: 尝试作为 room_number 查找
      if (!actualRoomDbId) {
        const [roomRows] = await pool.query<RowDataPacket[]>(
          `SELECT r.id, r.room_number FROM rooms r WHERE r.room_number = ?`,
          [roomId]
        );
        if (roomRows.length > 0) {
          actualRoomDbId = roomRows[0].id;
          actualRoomNumber = roomRows[0].room_number;
          logger.info(`通过房号 ${roomId} 找到房间DB ID ${actualRoomDbId}`);
        }
      }

      if (!actualRoomDbId) {
        logger.warn(`房间 ${roomId} 无有效入住记录，无法解析到任何房间`);
        return null;
      }

      const [guests] = await pool.query<RowDataPacket[]>(
        `SELECT g.*, r.room_number, r.hotel_id, h.hotel_name, b.check_in_date, b.check_out_date
         FROM guests g
         JOIN rooms r ON g.room_id = r.id
         JOIN hotels h ON r.hotel_id = h.id
         LEFT JOIN bookings b ON g.booking_id = b.id
         WHERE r.id = ?
         AND g.check_out_time IS NULL
         ORDER BY g.check_in_time DESC
         LIMIT 1`,
        [actualRoomDbId]
      );

      if (guests.length === 0) {
        logger.warn(`房间 ${actualRoomNumber}(DB ID:${actualRoomDbId}) 无有效入住记录`);
        return null;
      }

      const guest = guests[0];
      const session: GuestSession = {
        roomId: guest.room_number,
        roomDbId: guest.room_id,
        hotelId: guest.hotel_id,
        hotelName: guest.hotel_name,
        guestId: guest.id,
        bookingId: guest.booking_id,
        guestName: guest.guest_name || '尊敬的客人',
        checkInDate: guest.check_in_date,
        checkOutDate: guest.check_out_date,
        isValid: true
      };

      this.sessions.set(roomId, session);
      return session;
    } catch (error) {
      logger.error('验证客人入住状态失败:', error.message);
      return null;
    }
  }

  /**
   * 获取客人的所有已入住房间
   */
  async getGuestRooms(roomId: string): Promise<string[]> {
    try {
      // 1. 先找到当前房间对应的客人信息
      const [currentGuests] = await pool.query<RowDataPacket[]>(
        `SELECT g.guest_phone, b.user_id 
         FROM guests g 
         LEFT JOIN bookings b ON g.booking_id = b.id
         JOIN rooms r ON g.room_id = r.id
         WHERE (r.id = ? OR r.room_number = ?) AND g.check_out_time IS NULL
         LIMIT 1`,
        [roomId, roomId]
      );

      if (currentGuests.length === 0) {return [];}

      const { guest_phone, user_id } = currentGuests[0];

      // 2. 查找该客人名下所有未退房的房间
      const [rooms] = await pool.query<RowDataPacket[]>(
        `SELECT DISTINCT r.room_number 
         FROM guests g
         JOIN rooms r ON g.room_id = r.id
         LEFT JOIN bookings b ON g.booking_id = b.id
         WHERE (g.guest_phone = ? OR (b.user_id IS NOT NULL AND b.user_id = ?))
         AND g.check_out_time IS NULL`,
        [guest_phone, user_id]
      );

      return rooms.map(r => r.room_number);
    } catch (error) {
      logger.error('获取客人房间列表失败:', error.message);
      return [];
    }
  }

  /**
   * 语音识别 - 阿里云百炼ASR (使用FunASR模型)
   * 文档: https://help.aliyun.com/document_detail/2712536.html
   */
  async speechToText(audioBase64: string): Promise<string> {
    try {
      // 检查 API Key 是否配置
      if (!this.aliyunAccessKey) {
        logger.error('阿里云百炼ASR: ALIYUN_ACCESS_KEY 未配置');
        return '';
      }

      // 百炼语音识别API - 只需要API Key
      const url = 'https://dashscope.aliyuncs.com/api/v1/services/audio/asr/transcription';

      const response = await axios.post(url, {
        model: 'paraformer-realtime-v2',  // 使用实时语音识别模型
        input: {
          audio: audioBase64  // base64编码的音频数据
        },
        parameters: {
          format: 'pcm',
          sample_rate: 16000,
          language_hints: ['zh', 'en']  // 支持中英文
        }
      }, {
        headers: {
          'Authorization': `Bearer ${this.aliyunAccessKey}`,
          'Content-Type': 'application/json'
        },
        timeout: 30000
      });

      // 解析响应
      if (response.data && response.data.output) {
        const result = response.data.output;
        if (result.text) {
          logger.info(`百炼ASR识别成功: "${result.text}"`);
          return result.text;
        }
      }

      logger.warn('百炼ASR响应格式异常:', response.data);
      return '';
    } catch (error: any) {
      const status = error.response?.status;
      const data = error.response?.data;
      
      // 详细错误日志
      if (status === 401) {
        logger.error('百炼ASR认证失败: API Key无效或已过期');
      } else if (status === 429) {
        logger.error('百炼ASR请求过于频繁，请稍后重试');
      } else {
        logger.error('百炼ASR识别失败:', {
          message: error.message,
          status,
          details: data
        });
      }
      
      return '';
    }
  }

  /**
   * 大语言模型对话 - 智谱GLM-4-Flash with Function Calling
   */
  async chatWithLLM(text: string, session: GuestSession, history: any[] = []): Promise<any> {
    try {
      const systemPrompt = `你是智慧酒店的AI管家"小智"，为客人提供贴心服务。
当前客人：${session.guestName}，房间号：${session.roomId}，入住日期：${session.checkInDate}，退房日期：${session.checkOutDate}。

你的职责：
1. **设备控制** - 帮助客人控制房间的智能设备（灯光、空调、窗帘、电视等）
2. **房间状态** - 查询房间当前状态和环境信息
3. **客房服务** - 安排保洁、维修、送餐、送物品等服务
4. **酒店信息** - 提供酒店设施信息、营业时间、周边推荐等
5. **人工转接** - 当无法处理或客人明确要求时，转接人工前台

⚠️ 重要约束：
- 严格基于知识库中的实际内容回复，禁止编造任何未在知识库中提供的信息
- 如果知识库中没有相关信息，请明确告知"该信息暂未录入，建议联系前台咨询"
- 回复简洁明了，不超过80字
- 语气亲切礼貌，称呼客人名字
- 如果需要调用工具，先通过function calling执行`;

      const messages = [
        { role: 'system', content: systemPrompt },
        ...history.slice(-6),
        { role: 'user', content: text }
      ];

      const response = await axios.post('https://open.bigmodel.cn/api/paas/v4/chat/completions', {
        model: 'glm-4-flash',
        messages: messages,
        temperature: 0.3,
        max_tokens: 500,
        tools: this.tools,
        tool_choice: 'auto'
      }, {
        headers: {
          'Authorization': `Bearer ${this.zhipuApiKey}`,
          'Content-Type': 'application/json'
        },
        timeout: 15000
      });

      if (response.data && response.data.choices && response.data.choices[0]) {
        const choice = response.data.choices[0];

        // 检查是否有工具调用
        if (choice.message.tool_calls && choice.message.tool_calls.length > 0) {
          return {
            content: choice.message.content || '',
            tool_calls: choice.message.tool_calls,
            needToolCall: true
          };
        }

        return {
          content: choice.message.content,
          tool_calls: null,
          needToolCall: false
        };
      }

      throw new Error('LLM响应异常');
    } catch (error) {
      logger.error('智谱GLM-4调用失败:', error.message);
      return {
        content: `您好${session.guestName}，小智正在学习中，马上为您转接前台。[TRANSFER:front_desk]`,
        tool_calls: null,
        needToolCall: false
      };
    }
  }

  /**
   * 执行工具调用
   */
  async executeToolCall(toolName: string, args: any, session: GuestSession): Promise<any> {
    try {
      switch (toolName) {
        case 'control_device':
          return await this.controlDevice(args, session);
        case 'get_room_status':
          return await this.getRoomStatus(session);
        case 'request_service':
          return await this.requestService(args, session);
        case 'get_hotel_info':
          return await this.getHotelInfo(args.info_type, session);
        case 'transfer_to_human':
        case 'voice_call':
          return `正在为您转接${args.target === 'room_service' ? '送餐部' : args.target === 'maintenance' ? '维修部' : '前台'}，请稍候。[TRANSFER:front_desk]`;
        default:
          return '抱歉，该功能暂不可用。';
      }
    } catch (error) {
      logger.error(`工具调用失败 ${toolName}: ${error.message}`);
      return `执行${toolName}时出现错误，请稍后重试或联系前台。`;
    }
  }

  /**
   * 控制设备
   */
  private async controlDevice(args: any, session: GuestSession): Promise<string> {
    const { device_type, action, value } = args;

    const [devices] = await pool.query<RowDataPacket[]>(
      `SELECT d.* FROM devices d
       WHERE d.room_id = ? AND d.device_type IN ('room', 'floor')`,
      [session.roomDbId]
    );

    if (devices.length === 0) {
      return '抱歉，您房间暂时没有可控制的智能设备，请联系前台。';
    }

    const device = devices[0];
    const command = this.buildDeviceCommand(device_type, action, value);
    logger.debug(`通过AI发送设备指令到 ${device.device_id}:`, command);

    const topic = `hotel/device/command/room/${device.device_id}`;
    await mqttService.publish(topic, {
      device_id: device.device_id,
      ...command
    });

    const actionText = this.getActionText(action, value, device_type);
    return `已为您${device.device_name || device.device_id}${actionText}。`;
  }

  /**
   * 构建设备控制指令
   */
  private buildDeviceCommand(deviceType: string, action: string, value?: number): any {
    const cmdTypeMap: Record<string, string> = {
      'light': 'light',
      'ac': 'air',
      'curtain': 'curtain',
      'tv': 'tv',
      'lock': 'door',
      'all': 'scene'
    };

    const cmdType = cmdTypeMap[deviceType] || deviceType;

    switch (action) {
      case 'on':
      case 'open':
        return { command_type: cmdType, command_value: 'on' };
      case 'off':
      case 'close':
        return { command_type: cmdType, command_value: 'off' };
      case 'toggle':
        return { command_type: cmdType, command_value: cmdType === 'light' ? 'on' : 'toggle' };
      case 'set_temperature':
        return { command_type: 'air', command_value: `temp:${value || 24}` };
      case 'set_brightness':
        return { command_type: 'light', command_value: 'on' };
      default:
        return { command_type: cmdType, command_value: action };
    }
  }

  /**
   * 获取操作文本描述
   */
  private getActionText(action: string, value?: number, deviceType?: string): string {
    switch (action) {
      case 'on':
      case 'open':
        return '已打开';
      case 'off':
      case 'close':
        return '已关闭';
      case 'toggle':
        return '已切换';
      case 'set_temperature':
        return `已设置为${value || 24}度`;
      case 'set_brightness':
        return `已调整至${value || 100}%亮度`;
      default:
        return '已执行操作';
    }
  }

  /**
   * 获取房间状态
   */
  private async getRoomStatus(session: GuestSession): Promise<string> {
    try {
      // 查询房间信息和设备状态
      const [rooms] = await pool.query<RowDataPacket[]>(
        `SELECT r.*, rt.name as type_name, rt.base_price
         FROM rooms r
         LEFT JOIN room_types rt ON r.room_type_id = rt.id
         WHERE r.id = ?`,
        [session.roomDbId]
      );

      const [devices] = await pool.query<RowDataPacket[]>(
        `SELECT d.device_type, d.device_name, d.device_status
         FROM devices d
         WHERE d.room_id = ?`,
        [session.roomDbId]
      );

      if (rooms.length === 0) {
        return '未找到房间信息。';
      }

      const room = rooms[0];
      const deviceList = devices.map((d: any) => {
        const status = d.device_status === 'online' ? '在线' : '离线';
        return `${d.device_name || d.device_type}(${status})`;
      });

      return `${session.roomId}号房状态：
🏠 房型：${room.type_name || '标准间'}
📱 设备：${deviceList.join('、') || '无智能设备'}
🌡️ 温度：正常（请查看室内显示屏获取精确数据）

还需要了解什么吗？`;
    } catch (error) {
      logger.error('查询房间状态失败:', error.message);
      return '查询房间状态失败，请稍后重试。';
    }
  }

  /**
   * 请求服务
   */
  private async requestService(args: any, session: GuestSession): Promise<any> {
    const { service_type, description, urgency = 'normal' } = args;

    // 映射服务类型
    const serviceMap: Record<string, { table: string; type: string }> = {
      cleaning: { table: 'maintenance_tickets', type: 'cleaning' },
      maintenance: { table: 'maintenance_tickets', type: 'maintenance' },
      room_service: { table: 'delivery_orders', type: 'room_service' },
      towels: { table: 'delivery_orders', type: 'amenities' },
      water: { table: 'delivery_orders', type: 'amenities' },
      other: { table: 'maintenance_tickets', type: 'other' }
    };

    const service = serviceMap[service_type] || serviceMap.other;

    try {
      let orderNo = '';
      if (service.table === 'maintenance_tickets') {
        // 创建维修/保洁工单
        orderNo = `MT${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${Date.now().toString(36).toUpperCase()}`;
        await pool.query(
          `INSERT INTO maintenance_tickets (ticket_no, booking_id, guest_id, room_id, fault_type, fault_description, priority, status, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, 'pending', NOW())`,
          [orderNo, session.bookingId, session.guestId, session.roomDbId, service.type, description, urgency]
        );
      } else {
        // 创建配送单
        orderNo = `DEL${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${Date.now().toString(36).toUpperCase()}`;
        await pool.query(
          `INSERT INTO delivery_orders (order_no, booking_id, guest_id, room_id, item_name, quantity, note, status, created_at)
           VALUES (?, ?, ?, ?, ?, 1, ?, 'pending', NOW())`,
          [orderNo, session.bookingId, session.guestId, session.roomDbId, service.type, description]
        );
      }

      const urgencyText = { normal: '', urgent: '（加急）', emergency: '（紧急）' }[urgency];
      const serviceName = {
        cleaning: '保洁服务',
        maintenance: '维修服务',
        room_service: '送餐服务',
        towels: '更换毛巾',
        water: '送水服务',
        other: '其他服务'
      }[service_type];

      const replyText = `已为您安排${serviceName}${urgencyText}，工作人员会尽快到达您的房间并为您处理。`;
      
      return {
        text: replyText,
        data: {
          ticketNo: orderNo,
          type: serviceName,
          description: description,
          urgency: urgencyText || '普通',
          roomNumber: session.roomId,
          createdAt: new Date().toLocaleString('zh-CN')
        }
      };
    } catch (error) {
      logger.error('创建服务请求失败:', error.message);
      return '创建服务请求失败，请直接拨打前台电话或转接人工服务。';
    }
  }

  /**
   * 获取酒店信息
   */
  private async getHotelInfo(infoType: string, session: GuestSession): Promise<string> {
    try {
      const knowledgeList = await KnowledgeBaseService.getActiveByHotel(session.hotelId);

      if (knowledgeList.length === 0) {
        return '抱歉，该门店的知识库暂未配置，建议联系前台咨询。';
      }

      if (infoType === 'all') {
        let allInfo = `🏨 ${session.hotelName}欢迎您：\n\n`;
        
        for (const kb of knowledgeList) {
          allInfo += `${kb.content}\n\n`;
        }

        allInfo += `想了解哪项详情？`;
        return allInfo;
      }

      const targetKnowledge = knowledgeList.find(kb => kb.category === infoType);

      if (!targetKnowledge) {
        return `抱歉，${infoType}相关的信息暂未录入知识库，建议您直接联系前台咨询（内线0000）。`;
      }

      return targetKnowledge.content;
    } catch (error) {
      logger.error('查询酒店信息失败:', error.message);
      return '查询酒店信息失败，请稍后重试或联系前台。';
    }
  }

  /**
   * 清理文本用于TTS语音合成（去除emoji、特殊符号、格式标记等）
   */
  private cleanTextForTTS(text: string): string {
    let cleaned = text;

    cleaned = cleaned.replace(/[\u{1F600}-\u{1F64F}]/gu, '');
    cleaned = cleaned.replace(/[\u{1F300}-\u{1F5FF}]/gu, '');
    cleaned = cleaned.replace(/[\u{1F680}-\u{1F6FF}]/gu, '');
    cleaned = cleaned.replace(/[\u{1F1E0}-\u{1F1FF}]/gu, '');
    cleaned = cleaned.replace(/[\u{2600}-\u{26FF}]/gu, '');
    cleaned = cleaned.replace(/[\u{2700}-\u{27BF}]/gu, '');
    cleaned = cleaned.replace(/[\u{FE00}-\u{FE0F}]/gu, '');
    cleaned = cleaned.replace(/[\u{1F900}-\u{1F9FF}]/gu, '');
    cleaned = cleaned.replace(/[\u{1FA00}-\u{1FA6F}]/gu, '');
    cleaned = cleaned.replace(/[\u{1FA70}-\u{1FAFF}]/gu, '');
    cleaned = cleaned.replace(/[\u{200D}]/gu, '');
    cleaned = cleaned.replace(/[\u{FEFF}]/gu, '');
    cleaned = cleaned.replace(/[\u{200B}]/gu, '');

    cleaned = cleaned.replace(/^[•·\-–—]\s*/gm, '');

    cleaned = cleaned.replace(/\*\*(.*?)\*\*/g, '$1');
    cleaned = cleaned.replace(/\*(.*?)\*/g, '$1');
    cleaned = cleaned.replace(/`(.*?)`/g, '$1');

    cleaned = cleaned.replace(/<[^>]+>/g, '');

    cleaned = cleaned.replace(/\[TRANSFER:\w+\]/g, '');

    cleaned = cleaned.replace(/\n{2,}/g, '。');
    cleaned = cleaned.replace(/\n/g, '，');
    cleaned = cleaned.replace(/[ \t]+/g, ' ');
    cleaned = cleaned.trim();

    if (cleaned.length > 500) {
      logger.warn(`⚠️ TTS文本过长(${cleaned.length}字)，截断到500字`);
      cleaned = cleaned.substring(0, 500);
    }

    return cleaned;
  }

  /**
   * 语音合成 - 优先超拟人，自动降级TTS v2
   */
  async textToSpeech(text: string): Promise<string> {
    const cleanText = this.cleanTextForTTS(text);
    if (!cleanText.trim()) {return '';}

    logger.debug(`🎙️ [TTS] 待合成文本: "${cleanText.substring(0, 50)}${cleanText.length > 50 ? '...' : ''}" (${cleanText.length}字)`);

    try {
      const audio = await this.superHumanTTS(cleanText);
      if (audio) {return audio;}
    } catch (e) {
      logger.warn('⚠️ 超拟人TTS失败，降级到TTS v2');
    }

    try {
      const audio = await this.ttsV2(cleanText);
      if (audio) {return audio;}
    } catch (e) {
      logger.error('❌ TTS v2也失败:', e.message);
    }

    return '';
  }

  /**
   * 超拟人语音合成
   */
  private async superHumanTTS(text: string): Promise<string> {
    return new Promise((resolve, reject) => {
      try {
        logger.debug(`🎙️ [超拟人] 开始合成: "${text.substring(0, 30)}..."`);

        const url = 'wss://cbm01.cn-huabei-1.xf-yun.com/v1/private/mcd9m97e6';
        const host = 'cbm01.cn-huabei-1.xf-yun.com';
        const path = '/v1/private/mcd9m97e6';
        const date = new Date().toUTCString();

        const signatureOrigin = `host: ${host}\ndate: ${date}\nGET ${path} HTTP/1.1`;
        const signatureSha = crypto
          .createHmac('sha256', this.xfyunApiSecret)
          .update(signatureOrigin)
          .digest('base64');
        const authorizationOrigin = `api_key="${this.xfyunApiKey}", algorithm="hmac-sha256", headers="host date request-line", signature="${signatureSha}"`;
        const authorization = Buffer.from(authorizationOrigin).toString('base64');

        const wsUrl = `${url}?authorization=${encodeURIComponent(authorization)}&date=${encodeURIComponent(date)}&host=${host}`;

        const ws = new WebSocket(wsUrl);
        const audioChunks: Buffer[] = [];
        let isResolved = false;

        ws.on('open', () => {
          const request = {
            header: { app_id: this.xfyunAppId, status: 2 },
            parameter: {
              oral: { oral_level: 'mid', spark_assist: 0, stop_split: 1, remain: 1 },
              tts: {
                vcn: 'x5_lingyuzhao_flow',
                speed: 50, volume: 50, pitch: 50, bgs: 0, reg: 0, rdn: 0,
                audio: { encoding: 'lame', sample_rate: 24000, channels: 1, bit_depth: 16 }
              }
            },
            payload: {
              text: { encoding: 'utf8', compress: 'raw', format: 'plain', status: 2, seq: 0, text: Buffer.from(text).toString('base64') }
            }
          };
          ws.send(JSON.stringify(request));
        });

        ws.on('message', (data: WebSocket.Data) => {
          try {
            const response = JSON.parse(data.toString());

            if (response.header && response.header.code !== undefined && response.header.code !== 0) {
              logger.error(`❌ [超拟人] 错误 ${response.header.code}: ${response.header.message}`);
              if (!isResolved) { isResolved = true; reject(new Error(`${response.header.code}`)); }
              return;
            }

            if (response.payload && response.payload.audio && response.payload.audio.audio) {
              audioChunks.push(Buffer.from(response.payload.audio.audio, 'base64'));
            }

            if (response.header && response.header.status === 2) {
              if (!isResolved) {
                isResolved = true;
                if (audioChunks.length > 0) {
                  const fullAudio = Buffer.concat(audioChunks as Uint8Array[]);
                  logger.debug(`🎉 [超拟人] 合成成功！${fullAudio.length} bytes (${audioChunks.length}块)`);
                  resolve(fullAudio.toString('base64'));
                } else {
                  reject(new Error('无音频数据'));
                }
              }
              ws.close();
            }
          } catch (e) { /* ignore parse errors */ }
        });

        ws.on('error', (error) => {
          if (!isResolved) { isResolved = true; reject(error); }
        });

        ws.on('close', () => {
          if (!isResolved) {
            isResolved = true;
            if (audioChunks.length > 0) {
              resolve(Buffer.concat(audioChunks as Uint8Array[]).toString('base64'));
            } else {
              reject(new Error('连接关闭无数据'));
            }
          }
        });

        setTimeout(() => {
          if (!isResolved) { isResolved = true; ws.close(); reject(new Error('超时')); }
        }, 15000);
      } catch (error) {
        reject(error);
      }
    });
  }

  /**
   * TTS v2 语音合成 (降级方案)
   */
  private async ttsV2(text: string): Promise<string> {
    return new Promise((resolve, reject) => {
      try {
        logger.debug(`🎙️ [TTS v2] 开始合成: "${text.substring(0, 30)}..."`);

        const url = 'wss://tts-api.xfyun.cn/v2/tts';
        const host = 'tts-api.xfyun.cn';
        const path = '/v2/tts';
        const date = new Date().toUTCString();

        const signatureOrigin = `host: ${host}\ndate: ${date}\nGET ${path} HTTP/1.1`;
        const signatureSha = crypto
          .createHmac('sha256', this.xfyunApiSecret)
          .update(signatureOrigin)
          .digest('base64');
        const authorizationOrigin = `api_key="${this.xfyunApiKey}", algorithm="hmac-sha256", headers="host date request-line", signature="${signatureSha}"`;
        const authorization = Buffer.from(authorizationOrigin).toString('base64');

        const wsUrl = `${url}?authorization=${encodeURIComponent(authorization)}&date=${encodeURIComponent(date)}&host=${host}`;

        const ws = new WebSocket(wsUrl);
        const audioChunks: Buffer[] = [];
        let isResolved = false;

        ws.on('open', () => {
          const request = {
            common: { app_id: this.xfyunAppId },
            business: {
              aue: 'lame', sfl: 1,
              auf: 'audio/L16;rate=16000',
              vcn: 'xiaoyan',
              speed: 50, volume: 50, pitch: 50,
              bgs: 0,
              tte: 'UTF8',
              reg: '2',
              rdn: '0'
            },
            data: { text: Buffer.from(text).toString('base64'), status: 2 }
          };
          ws.send(JSON.stringify(request));
        });

        ws.on('message', (data: WebSocket.Data) => {
          try {
            const response = JSON.parse(data.toString());

            if (response.code !== undefined && response.code !== 0) {
              logger.error(`❌ [TTS v2] 错误 ${response.code}: ${response.message}`);
              if (!isResolved) { isResolved = true; reject(new Error(`${response.code}`)); }
              return;
            }

            // 收集所有音频块，不要提前结束！
            if (response.data && response.data.audio) {
              audioChunks.push(Buffer.from(response.data.audio, 'base64'));
            }

            // 只有 status=2 才表示所有数据发送完毕
            if (response.data && response.data.status === 2) {
              if (!isResolved) {
                isResolved = true;
                if (audioChunks.length > 0) {
                  const fullAudio = Buffer.concat(audioChunks as Uint8Array[]);
                  logger.debug(`🎉 [TTS v2] 合成成功！${fullAudio.length} bytes (${audioChunks.length}块)`);
                  resolve(fullAudio.toString('base64'));
                } else {
                  reject(new Error('无音频数据'));
                }
              }
              ws.close();
            }
          } catch (e) { /* ignore */ }
        });

        ws.on('error', (error) => {
          if (!isResolved) { isResolved = true; reject(error); }
        });

        ws.on('close', () => {
          if (!isResolved) {
            isResolved = true;
            if (audioChunks.length > 0) {
              resolve(Buffer.concat(audioChunks as Uint8Array[]).toString('base64'));
            } else {
              reject(new Error('连接关闭无数据'));
            }
          }
        });

        setTimeout(() => {
          if (!isResolved) { isResolved = true; ws.close(); reject(new Error('超时')); }
        }, 15000);
      } catch (error) {
        reject(error);
      }
    });
  }

  /**
   * 处理AI管家请求（完整流程，支持Function Calling）
   */
  async processRequest(request: AIRequest): Promise<AIResponse> {
    const { roomId, audioData, text, sessionId } = request;

    // 1. 验证入住状态
    let session = this.sessions.get(roomId);
    if (!session) {
      session = await this.verifyGuestAccess(roomId);
      if (!session) {
        return {
          text: '抱歉，该房间暂无入住记录，无法使用AI管家服务。如需帮助，请直接联系前台。',
          action: 'unauthorized'
        };
      }
    }

    try {
      // 2. 语音识别（如果有音频）
      let userText = text || '';
      if (audioData && !text) {
        userText = await this.speechToText(audioData);
      }

      if (!userText.trim()) {
        return {
          text: '抱歉，我没有听清楚，请再说一遍。',
          audioUrl: ''
        };
      }

      logger.debug(`房间 ${roomId} 语音输入: ${userText}`);

      // 3. 大语言模型处理（支持Function Calling）
      const llmResult = await this.chatWithLLM(userText, session);

      // 4. 如果有工具调用，执行工具并生成最终回复
      if (llmResult.needToolCall && llmResult.tool_calls) {
        const toolResults: any[] = [];
        let ticketData: any = null;

        for (const toolCall of llmResult.tool_calls) {
          const functionName = toolCall.function.name;
          const functionArgs = JSON.parse(toolCall.function.arguments);

          logger.debug(`执行工具: ${functionName}`, functionArgs);

          const toolResult = await this.executeToolCall(functionName, functionArgs, session);
          
          // 处理带数据的工具返回
          let resultText = '';
          if (typeof toolResult === 'object' && toolResult.text) {
            resultText = toolResult.text;
            if (toolResult.data) {
              ticketData = toolResult.data;
            }
          } else {
            resultText = toolResult;
          }

          toolResults.push({
            id: toolCall.id,
            result: resultText
          });
        }

        const finalMessages = [
          { role: 'system', content: '你是智慧酒店的AI管家"小智"。根据工具执行结果，用亲切的语气向客人汇报结果。严禁编造工具结果中未包含的信息（如具体的等待时间、具体的排队人数等）。如果涉及到转接前台，请务必根据提供的在线人数报出来（例如：正在为您转接前台，目前有2位工作人员在线）。' },
          { role: 'user', content: userText },
          { role: 'assistant', content: llmResult.content || '', tool_calls: llmResult.tool_calls },
          ...toolResults.map(tr => ({
            role: 'tool',
            tool_call_id: tr.id,
            content: tr.result
          }))
        ];

        const finalResponse = await axios.post('https://open.bigmodel.cn/api/paas/v4/chat/completions', {
          model: 'glm-4-flash',
          messages: finalMessages,
          temperature: 0.3,
          max_tokens: 500
        }, {
          headers: {
            'Authorization': `Bearer ${this.zhipuApiKey}`,
            'Content-Type': 'application/json'
          },
          timeout: 15000
        });

        const finalContent = finalResponse.data.choices[0].message.content;
        
        // 5. 将最终文本转为语音
        let audioBase64 = '';
        try {
          audioBase64 = await this.textToSpeech(finalContent);
        } catch (ttsError) {
          logger.warn('TTS合成失败:', ttsError.message);
        }

        return {
          text: finalContent,
          audioUrl: audioBase64,
          action: llmResult.tool_calls[0].function.name, // 记录第一个动作
          ticketData: ticketData,
          hotelName: session.hotelName
        };
      }

      const aiReply = llmResult.content;
      
      // 5. 将回复文本转为语音
      let audioBase64 = '';
      try {
        audioBase64 = await this.textToSpeech(aiReply);
      } catch (ttsError) {
        logger.warn('TTS合成失败:', ttsError.message);
      }

      const transferMatch = aiReply.match(/\[TRANSFER:(\w+)\]/);
      const action = transferMatch ? 'transfer' : 'reply';
      const target = transferMatch ? transferMatch[1] : undefined;
      const cleanText = aiReply.replace(/\[TRANSFER:\w+\]/g, '');

      return {
        text: cleanText,
        audioUrl: audioBase64,
        action,
        target,
        hotelName: session.hotelName
      };
    } catch (error) {
      logger.error('AI管家处理请求失败:', error.message);
      return {
        text: '抱歉，服务暂时不可用，为您转接前台。',
        action: 'transfer',
        target: 'front_desk'
      };
    }
  }

  /**
   * 阿里云鉴权签名
   */
  private buildAliyunSignature(date: string): string {
    const stringToSign = `POST\napplication/json\n${date}\n/xiaoyu/api/v1/asr`;
    return crypto
      .createHmac('sha256', this.aliyunAccessSecret)
      .update(stringToSign)
      .digest('base64');
  }

  /**
   * 讯飞鉴权签名
   */
  private buildXfyunSignature(date: string): string {
    const signatureOrigin = `host: tts-api.xfyun.cn\ndate: ${date}\nGET /v2/tts HTTP/1.1`;
    const signature = crypto
      .createHmac('sha256', this.xfyunApiSecret)
      .update(signatureOrigin)
      .digest('base64');
    const authorizationOrigin = `api_key="${this.xfyunApiKey}", algorithm="hmac-sha256", headers="host date request-line", signature="${signature}"`;
    return Buffer.from(authorizationOrigin).toString('base64');
  }

  /**
   * 清理会话
   */
  clearSession(roomId: string): void {
    this.sessions.delete(roomId);
  }
}

export default AIButlerService.getInstance();
