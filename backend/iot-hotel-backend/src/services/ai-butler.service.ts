import pool, { RowDataPacket } from '../config/database';
import logger from '../utils/logger';
import axios from 'axios';
import crypto from 'crypto';
import WebSocket from 'ws';

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
}

interface GuestSession {
  roomId: string;
  guestId: string;
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
        description: '转接人工前台服务',
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
      const [bookings] = await pool.query<RowDataPacket[]>(
        `SELECT b.*, r.room_number, r.id as room_db_id
         FROM bookings b
         JOIN rooms r ON b.room_id = r.id
         WHERE (r.id = ? OR r.room_number = ?)
         AND b.status = 'checked_in'
         AND b.check_in_date <= CURDATE()
         AND b.check_out_date >= CURDATE()
         ORDER BY b.created_at DESC
         LIMIT 1`,
        [roomId, roomId]
      );

      if (bookings.length === 0) {
        logger.warn(`房间 ${roomId} 无有效入住记录`);
        return null;
      }

      const booking = bookings[0];
      const session: GuestSession = {
        roomId: booking.room_number,
        guestId: booking.id,
        guestName: booking.guest_name || '尊敬的客人',
        checkInDate: booking.check_in_date,
        checkOutDate: booking.check_out_date,
        isValid: true
      };

      this.sessions.set(roomId, session);
      return session;
    } catch (error) {
      logger.error('验证客人入住状态失败:', error);
      return null;
    }
  }

  /**
   * 语音识别 - 阿里云ASR
   */
  async speechToText(audioBase64: string): Promise<string> {
    try {
      const url = 'https://nls-gateway-cn-shanghai.aliyuncs.com/stream/v1/asr';
      
      const date = new Date().toUTCString();
      const signature = this.buildAliyunSignature(date);
      
      const audioBuffer = Buffer.from(audioBase64, 'base64');
      
      const response = await axios.post(url, audioBuffer, {
        headers: {
          'X-NLS-Token': this.aliyunAccessKey,
          'X-NLS-Date': date,
          'Authorization': signature,
          'Content-Type': 'application/octet-stream',
          'X-NLS-Format': 'pcm',
          'X-NLS-Sample-Rate': '16000'
        },
        timeout: 10000
      });

      if (response.data && response.data.result) {
        return response.data.result;
      }
      
      throw new Error('ASR识别失败');
    } catch (error) {
      logger.error('阿里云ASR识别失败:', error);
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

回复要求：
- 语气亲切礼貌，称呼客人名字
- 回复简洁明了，不超过80字
- 主动确认操作结果
- 如果需要调用工具，先通过function calling执行`;

      const messages = [
        { role: 'system', content: systemPrompt },
        ...history.slice(-6),
        { role: 'user', content: text }
      ];

      const response = await axios.post('https://open.bigmodel.cn/api/paas/v4/chat/completions', {
        model: 'glm-4-flash',
        messages: messages,
        temperature: 0.7,
        max_tokens: 200,
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
      logger.error('智谱GLM-4调用失败:', error);
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
  async executeToolCall(toolName: string, args: any, session: GuestSession): Promise<string> {
    try {
      switch (toolName) {
        case 'control_device':
          return await this.controlDevice(args, session);
        case 'get_room_status':
          return await this.getRoomStatus(session);
        case 'request_service':
          return await this.requestService(args, session);
        case 'get_hotel_info':
          return await this.getHotelInfo(args.info_type);
        case 'transfer_to_human':
          return '[TRANSFER:front_desk]';
        default:
          return '抱歉，该功能暂不可用。';
      }
    } catch (error) {
      logger.error(`工具调用失败 ${toolName}:`, error);
      return `执行${toolName}时出现错误，请稍后重试或联系前台。`;
    }
  }

  /**
   * 控制设备
   */
  private async controlDevice(args: any, session: GuestSession): Promise<string> {
    const { device_type, action, value } = args;

    // 查询房间设备
    const [devices] = await pool.query<RowDataPacket[]>(
      `SELECT d.* FROM devices d
       JOIN rooms r ON d.room_id = r.id
       WHERE r.room_number = ? AND d.device_status = 'online'`,
      [session.roomId]
    );

    if (devices.length === 0) {
      return '抱歉，您房间暂时没有可控制的智能设备，请联系前台。';
    }

    // 根据设备类型筛选目标设备
    let targetDevices = devices;
    if (device_type !== 'all') {
      const typeMap: Record<string, string> = {
        'light': 'smart_light',
        'ac': 'smart_ac',
        'curtain': 'smart_curtain',
        'tv': 'smart_tv',
        'lock': 'smart_lock'
      };
      targetDevices = devices.filter((d: any) => d.device_type === typeMap[device_type]);
    }

    if (targetDevices.length === 0) {
      const typeName = { light: '灯光', ac: '空调', curtain: '窗帘', tv: '电视', lock: '门锁' }[device_type] || device_type;
      return `抱歉，您房间没有找到${typeName}设备。`;
    }

    // 通过MQTT发送控制指令（模拟实现）
    const results: string[] = [];
    for (const device of targetDevices) {
      const command = this.buildDeviceCommand(device_type, action, value);
      logger.info(`发送设备指令到 ${device.device_id}:`, command);
      
      // TODO: 实际通过MQTT发送指令
      // mqttService.publish(`hotel/device/command/${device.device_id}`, command);
      
      const actionText = this.getActionText(action, value, device_type);
      results.push(`${device.device_name || device.device_id}${actionText}`);
    }

    return `已为您${results.join('、')}。`;
  }

  /**
   * 构建设备控制指令
   */
  private buildDeviceCommand(deviceType: string, action: string, value?: number): any {
    const baseCommand = { timestamp: Date.now() };
    
    switch (action) {
      case 'on':
      case 'open':
        return { ...baseCommand, command: 'turn_on', status: 'on' };
      case 'off':
      case 'close':
        return { ...baseCommand, command: 'turn_off', status: 'off' };
      case 'toggle':
        return { ...baseCommand, command: 'toggle' };
      case 'set_temperature':
        return { ...baseCommand, command: 'set_temperature', temperature: value || 24 };
      case 'set_brightness':
        return { ...baseCommand, command: 'set_brightness', brightness: value || 100 };
      default:
        return { ...baseCommand, command: action, value };
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
         WHERE r.room_number = ?`,
        [session.roomId]
      );

      const [devices] = await pool.query<RowDataPacket[]>(
        `SELECT d.device_type, d.device_name, d.device_status
         FROM devices d
         JOIN rooms r ON d.room_id = r.id
         WHERE r.room_number = ?`,
        [session.roomId]
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
      logger.error('查询房间状态失败:', error);
      return '查询房间状态失败，请稍后重试。';
    }
  }

  /**
   * 请求服务
   */
  private async requestService(args: any, session: GuestSession): Promise<string> {
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
      if (service.table === 'maintenance_tickets') {
        // 创建维修/保洁工单
        const ticketNo = `MT${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${Date.now().toString(36).toUpperCase()}`;
        await pool.query(
          `INSERT INTO maintenance_tickets (hotel_id, ticket_no, room_id, fault_type, fault_description, priority, status, created_at)
           SELECT h.id, ?, r.id, ?, ?, ?, 'pending', NOW()
           FROM rooms r
           JOIN hotels h ON r.hotel_id = h.id
           WHERE r.room_number = ?`,
          [ticketNo, service.type, description, urgency, session.roomId]
        );
      } else {
        // 创建配送单
        const orderNo = `DEL${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${Date.now().toString(36).toUpperCase()}`;
        await pool.query(
          `INSERT INTO delivery_orders (hotel_id, order_no, room_id, item_name, quantity, note, status, created_at)
           SELECT h.id, ?, r.id, ?, 1, ?, 'pending', NOW()
           FROM rooms r
           JOIN hotels h ON r.hotel_id = h.id
           WHERE r.room_number = ?`,
          [orderNo, service.type, description, session.roomId]
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

      return `已为您安排${serviceName}${urgencyText}，工作人员会尽快到达您的房间。预计等待时间：${urgency === 'emergency' ? '5分钟' : urgency === 'urgent' ? '15分钟' : '30分钟'}。`;
    } catch (error) {
      logger.error('创建服务请求失败:', error);
      return '创建服务请求失败，请直接拨打前台电话或转接人工服务。';
    }
  }

  /**
   * 获取酒店信息
   */
  private async getHotelInfo(infoType: string): Promise<string> {
    const infoTemplates: Record<string, string> = {
      restaurant: `🍽️ 餐厅信息：
• 早餐：07:00 - 10:00（1楼西餐厅）
• 午餐：11:30 - 14:00
• 晚餐：17:30 - 21:00
• 客房送餐：24小时可用

需要我帮您安排送餐吗？`,

      gym: `💪 健身中心：
• 开放时间：06:00 - 23:00
• 位置：3楼
• 设施：跑步机、器械区、瑜伽室
• 凭房卡免费使用

还需要了解其他设施吗？`,

      wifi: `📶 WiFi信息：
• 网络名称：Hotel_Guest
• 密码：guest888
• 每个房间独立带宽100Mbps

连接遇到问题可以告诉我，我帮您报修。`,

      nearby: `🏪 周边推荐（步行5分钟内）：
• 便利店：楼下全家便利店
• 地铁站：500米（人民广场站）
• 商场：对面万达广场
• 医院：右侧市第一人民医院

需要更详细的信息吗？`,

      checkout: `📋 退房须知：
• 标准退房时间：12:00前
• 延迟退房：14:00前（需前台确认，可能产生费用）
• 快速退房：可将房卡投入大堂退房箱
• 发票：可选择电子发票或邮寄

需要我帮您安排延迟退房吗？`,

      breakfast: `🥐 早餐信息：
• 时间：07:00 - 10:00
• 地点：1楼西餐厅
• 形式：自助早餐
• 包含：中西式菜品、饮品、水果

需要我提醒您明早用餐吗？`,

      all: `🏨 酒店全览：

🍽️ 餐厅：早餐7-10点，午餐11:30-14点，晚餐17:30-21点
💪 健身房：6-23点，3楼，凭房卡免费
📶 WiFi：Hotel_Guest / 密码guest888
🛏️ 退房：12:00前，可申请延迟到14:00
🚗 停车：地下停车场B1-B2，住客免费

想了解哪项详情？`
    };

    return infoTemplates[infoType] || infoTemplates['all'];
  }

  /**
   * 语音合成 - 讯飞超拟人TTS (WebSocket)
   */
  async textToSpeech(text: string): Promise<string> {
    return new Promise((resolve, reject) => {
      try {
        const cleanText = text.replace(/\[TRANSFER:\w+\]/g, '');

        if (!cleanText.trim()) {
          resolve('');
          return;
        }

        logger.info(`开始TTS合成: "${cleanText.substring(0, 50)}..."`);
        logger.info(`使用AppID: ${this.xfyunAppId}, APIKey: ${this.xfyunApiKey?.substring(0, 10)}...`);

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

        logger.info(`TTS WebSocket URL: ${url}`);

        const ws = new WebSocket(wsUrl);

        let audioChunks: Buffer[] = [];
        let isResolved = false;

        ws.on('open', () => {
          logger.info('TTS WebSocket连接已建立');

          const request = {
            common: {
              app_id: this.xfyunAppId
            },
            business: {
              aue: 'lame',
              vcn: 'xiaoyan',
              speed: 50,
              volume: 50,
              pitch: 50,
              bgs: 0,
              sfl: 1
            },
            data: {
              text: Buffer.from(cleanText).toString('base64'),
              status: 2
            }
          };

          logger.info(`发送TTS请求: ${JSON.stringify(request).substring(0, 200)}...`);
          ws.send(JSON.stringify(request));
          logger.info('TTS请求已发送');
        });

        ws.on('message', (data: WebSocket.Data) => {
          try {
            const rawData = data.toString();
            logger.info(`TTS原始响应 (前500字符): ${rawData.substring(0, 500)}`);

            let response;
            try {
              response = JSON.parse(rawData);
            } catch (parseError) {
              logger.error(`TTS响应JSON解析失败: ${parseError.message}`);
              logger.error(`原始数据: ${rawData.substring(0, 200)}`);
              if (!isResolved) {
                isResolved = true;
                resolve('');
              }
              return;
            }

            logger.info(`TTS解析后响应: code=${response.code || 'N/A'}, message=${response.message || 'none'}, sid=${response.sid || 'none'}`);

            if (response.code !== undefined && response.code !== 0) {
              logger.error(`❌ TTS错误 [${response.code}]: ${response.message}`);
              if (response.code === 11200) {
                logger.error('错误11200提示: 可能原因 - 1.AppID未开通该服务 2.免费额度用完 3.API Key不匹配');
              }
              if (!isResolved) {
                isResolved = true;
                resolve('');
              }
              return;
            }

            // TTS v2 响应格式: data.audio (base64编码的音频)
            let audioData = null;

            if (response.data && response.data.audio) {
              audioData = Buffer.from(response.data.audio, 'base64');
              logger.info('✓ 检测到 TTS v2 响应格式: data.audio');
            }
            // 备用: data 字段本身就是音频
            else if (response.data && typeof response.data === 'string' && response.data.length > 100) {
              audioData = Buffer.from(response.data, 'base64');
              logger.info('✓ 检测到 TTS 响应格式: data (长字符串)');
            }

            if (audioData && audioData.length > 0) {
              audioChunks.push(audioData);
              logger.info(`✓ 收到音频块: ${audioData.length} bytes`);
            } else {
              logger.warn(`⚠️ 本次响应无音频数据, 完整响应keys: ${Object.keys(response).join(', ')}`);
            }

            // TTS v2: status=2 表示数据发送完成（我们一次性发送，所以收到响应就结束了）
            // 检查是否有音频数据或者 data.status === 2
            const isComplete = (response.data && response.data.status === 2) ||
                              (audioData && audioData.length > 0);

            if (isComplete) {
              if (!isResolved) {
                isResolved = true;
                if (audioChunks.length > 0) {
                  const fullAudio = Buffer.concat(audioChunks);
                  const base64Audio = fullAudio.toString('base64');
                  logger.info(`✅ TTS合成成功！音频大小: ${fullAudio.length} bytes (${(fullAudio.length / 1024).toFixed(1)} KB)`);
                  resolve(base64Audio);
                } else {
                  logger.warn('⚠️ TTS完成但无音频数据');
                  resolve('');
                }
              }
              ws.close();
            }
          } catch (e) {
            logger.error('解析TTS响应失败:', e);
          }
        });

        ws.on('error', (error) => {
          logger.error('❌ TTS WebSocket错误:', error.message || error);
          if (!isResolved) {
            isResolved = true;
            resolve('');
          }
        });

        ws.on('close', (code, reason) => {
          logger.debug(`TTS WebSocket连接已关闭 (code: ${code}, reason: ${reason})`);
          if (!isResolved) {
            isResolved = true;
            if (audioChunks.length > 0) {
              const fullAudio = Buffer.concat(audioChunks);
              logger.info(`✅ TTS连接关闭但有音频数据，大小: ${fullAudio.length} bytes`);
              resolve(fullAudio.toString('base64'));
            } else {
              resolve('');
            }
          }
        });

        setTimeout(() => {
          if (!isResolved) {
            isResolved = true;
            logger.warn('⏰ TTS超时（15秒），使用纯文本模式');
            ws.close();
            resolve('');
          }
        }, 15000);
      } catch (error) {
        logger.error('❌ 讯飞TTS合成异常:', error);
        resolve('');
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

      logger.info(`房间 ${roomId} 语音输入: ${userText}`);

      // 3. 大语言模型处理（支持Function Calling）
      const llmResult = await this.chatWithLLM(userText, session);

      // 4. 如果有工具调用，执行工具并生成最终回复
      if (llmResult.needToolCall && llmResult.tool_calls) {
        const toolResults: any[] = [];
        
        for (const toolCall of llmResult.tool_calls) {
          const functionName = toolCall.function.name;
          const functionArgs = JSON.parse(toolCall.function.arguments);
          
          logger.info(`执行工具: ${functionName}`, functionArgs);
          
          const toolResult = await this.executeToolCall(functionName, functionArgs, session);
          toolResults.push({
            id: toolCall.id,
            result: toolResult
          });
        }

        const finalMessages = [
          { role: 'system', content: '你是智慧酒店的AI管家"小智"。根据工具执行结果，用亲切的语气向客人汇报结果。' },
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
          temperature: 0.7,
          max_tokens: 200
        }, {
          headers: {
            'Authorization': `Bearer ${this.zhipuApiKey}`,
            'Content-Type': 'application/json'
          },
          timeout: 15000
        });

        const finalText = finalResponse.data?.choices?.[0]?.message?.content || toolResults[0].result;
        
        // 检查是否包含转接标记
        const transferMatch = finalText.match(/\[TRANSFER:(\w+)\]/);
        if (transferMatch) {
          const cleanText = finalText.replace(/\[TRANSFER:\w+\]/g, '');
          return {
            text: cleanText || '正在为您转接前台...',
            audioUrl: '',
            action: 'transfer',
            target: transferMatch[1]
          };
        }

        // 语音合成（容错处理）
        let audioBase64 = '';
        try {
          audioBase64 = await this.textToSpeech(finalText);
          if (!audioBase64) {
            logger.warn('TTS返回空音频，使用纯文本模式');
          }
        } catch (ttsError) {
          logger.warn('TTS合成失败，使用纯文本模式:', ttsError.message);
        }

        return {
          text: finalText,
          audioUrl: audioBase64,
          action: 'reply'
        };
      }

      // 5. 无工具调用的普通回复
      const aiReply = llmResult.content;

      // 检查是否需要转接
      const transferMatch = aiReply.match(/\[TRANSFER:(\w+)\]/);
      const action = transferMatch ? 'transfer' : 'reply';
      const target = transferMatch ? transferMatch[1] : undefined;
      const cleanText = aiReply.replace(/\[TRANSFER:\w+\]/g, '');

      if (action === 'transfer') {
        return {
          text: cleanText || '正在为您转接前台...',
          audioUrl: '',
          action,
          target
        };
      }

      // 6. 语音合成（容错处理）
      let audioBase64 = '';
      try {
        audioBase64 = await this.textToSpeech(cleanText);
        if (!audioBase64) {
          logger.warn('TTS返回空音频，使用纯文本模式');
        }
      } catch (ttsError) {
        logger.warn('TTS合成失败，使用纯文本模式:', ttsError.message);
      }

      return {
        text: cleanText,
        audioUrl: audioBase64,
        action,
        target
      };
    } catch (error) {
      logger.error('AI管家处理请求失败:', error);
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