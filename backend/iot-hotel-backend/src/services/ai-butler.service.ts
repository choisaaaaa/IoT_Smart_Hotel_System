import pool, { RowDataPacket } from '../config/database';
import logger from '../utils/logger';
import axios from 'axios';
import crypto from 'crypto';
import WebSocket from 'ws';
import { KnowledgeBaseService } from './knowledge-base.service';
import mqttService from './mqtt.service';
import dotenv from 'dotenv';
import path from 'path';
import fs from 'fs';

// 确保 .env 被加载 - 尝试多个可能的路径
const envPaths = [
  path.resolve(process.cwd(), '.env'),
  path.resolve(__dirname, '../../.env'),
  path.resolve(__dirname, '../../../.env'),
];

let envLoaded = false;
for (const envPath of envPaths) {
  if (fs.existsSync(envPath)) {
    dotenv.config({ path: envPath });
    logger.info(`[AI-Butler] 已加载环境变量: ${envPath}`);
    envLoaded = true;
    break;
  }
}

if (!envLoaded) {
  logger.warn('[AI-Butler] 未找到.env文件，使用已加载的环境变量');
}

// 调试：打印关键环境变量（只显示前10位）
logger.info('[AI-Butler] 环境变量检查:');
logger.info(`  ALIYUN_ACCESS_KEY: ${process.env.ALIYUN_ACCESS_KEY ? process.env.ALIYUN_ACCESS_KEY.substring(0, 10) + '...' : '未设置'}`);
logger.info(`  ZHIPU_API_KEY: ${process.env.ZHIPU_API_KEY ? process.env.ZHIPU_API_KEY.substring(0, 10) + '...' : '未设置'}`);

interface AIRequest {
  roomId: string;
  guestId?: string;
  audioData?: string; // base64音频
  text?: string;
  sessionId: string;
  /** 客房硬件：TTS 输出 16kHz s16le PCM（base64），经 MQTT 下发前再上采样为 32k */
  hardwarePcmTts?: boolean;
}

interface AIResponse {
  text: string;
  audioUrl?: string;
  /** 16kHz s16le mono PCM 的 base64，仅 hardwarePcmTts 时有效 */
  audioPcmBase64?: string;
  action?: string;
  target?: string;
  response?: string;
  callId?: number;
  frontDeskCount?: number;
  toolCalls?: any[];
  ticketData?: any;
  hotelName?: string;
  recognizedText?: string; // 语音识别原始结果
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
  private zhipuApiKey: string;
  private xfyunAppId: string;
  private xfyunApiKey: string;
  private xfyunApiSecret: string;
  private aliyunAccessSecret: string;
  private aliyunAppKey: string;
  private aliyunAccessKey: string;

  private constructor() {
    // 在构造函数中初始化所有环境变量，确保 .env 已加载
    this.zhipuApiKey = process.env.ZHIPU_API_KEY || '';
    this.xfyunAppId = process.env.XFYUN_APP_ID || '';
    this.xfyunApiKey = process.env.XFYUN_API_KEY || '';
    this.xfyunApiSecret = process.env.XFYUN_API_SECRET || '';
    this.aliyunAccessSecret = process.env.ALIYUN_ACCESS_SECRET || '';
    this.aliyunAppKey = process.env.ALIYUN_APP_KEY || '';
    // 支持 DASHSCOPE_API_KEY 和 ALIYUN_ACCESS_KEY 两种环境变量名
    this.aliyunAccessKey = process.env.DASHSCOPE_API_KEY || process.env.ALIYUN_ACCESS_KEY || '';
    
    logger.info('[AI-Butler] 服务初始化完成，API Key状态:');
    logger.info(`  DASHSCOPE_API_KEY: ${process.env.DASHSCOPE_API_KEY ? process.env.DASHSCOPE_API_KEY.substring(0, 10) + '...' : '未设置'}`);
    logger.info(`  ALIYUN_ACCESS_KEY: ${process.env.ALIYUN_ACCESS_KEY ? process.env.ALIYUN_ACCESS_KEY.substring(0, 10) + '...' : '未设置'}`);
    logger.info(`  ZHIPU_API_KEY: ${this.zhipuApiKey ? this.zhipuApiKey.substring(0, 10) + '...' : '未设置'}`);
  }

  /**
   * 重新加载环境变量（用于调试）
   */
  public reloadEnv(): void {
    this.aliyunAccessKey = process.env.DASHSCOPE_API_KEY || process.env.ALIYUN_ACCESS_KEY || '';
    logger.info('[AI-Butler] 重新加载环境变量:');
    logger.info(
      `  百炼 Key: ${this.aliyunAccessKey ? this.aliyunAccessKey.substring(0, 10) + '...' : '未设置'}`
    );
  }

  /**
   * 开发联调兜底：允许指定房间跳过入住校验。
   * 仅在非 production 且 DEV_ASSUME_CHECKED_IN_ROOMS 命中时生效。
   * 格式示例：DEV_ASSUME_CHECKED_IN_ROOMS=301,room_301,front_01
   */
  private isDevAssumeCheckedInEnabled(roomId: string): boolean {
    if (process.env.NODE_ENV === 'production') {
      return false;
    }
    const raw = process.env.DEV_ASSUME_CHECKED_IN_ROOMS || '';
    if (!raw.trim()) {
      return false;
    }
    const allowSet = new Set(
      raw
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean)
    );
    if (allowSet.has(roomId)) {
      return true;
    }
    const numericId = roomId.replace(/^room_?/, '');
    if (numericId && allowSet.has(numericId)) {
      return true;
    }
    return false;
  }

  /**
   * DEV联调兜底：基于配置生成一个“已入住”会话，供无板/无住客数据时调通链路。
   * 默认目标房间号 301，可通过 DEV_ASSUME_ROOM_NUMBER / DEV_ASSUME_HOTEL_ID 覆盖。
   */
  private async buildDevAssumeSession(roomId: string): Promise<GuestSession | null> {
    if (!this.isDevAssumeCheckedInEnabled(roomId)) {
      return null;
    }

    const assumeRoomNumber = (process.env.DEV_ASSUME_ROOM_NUMBER || '301').trim();
    const assumeHotelIdRaw = (process.env.DEV_ASSUME_HOTEL_ID || '3').trim();
    const assumeHotelId = /^\d+$/.test(assumeHotelIdRaw) ? parseInt(assumeHotelIdRaw, 10) : 3;

    const [roomRows] = await pool.query<RowDataPacket[]>(
      `SELECT r.id, r.room_number, r.hotel_id, h.hotel_name
       FROM rooms r
       LEFT JOIN hotels h ON r.hotel_id = h.id
       WHERE r.room_number = ? AND r.hotel_id = ?
       LIMIT 1`,
      [assumeRoomNumber, assumeHotelId]
    );
    if (roomRows.length === 0) {
      logger.warn(`[AI-Butler] DEV联调兜底失败：未找到房间 room_number=${assumeRoomNumber}, hotel_id=${assumeHotelId}`);
      return null;
    }

    const roomInfo = roomRows[0];
    const mockSession: GuestSession = {
      roomId: roomInfo.room_number || assumeRoomNumber,
      roomDbId: roomInfo.id,
      hotelId: roomInfo.hotel_id || assumeHotelId,
      hotelName: roomInfo.hotel_name || '联调酒店',
      guestId: 0,
      bookingId: 0,
      guestName: '联调住客',
      checkInDate: new Date().toISOString(),
      checkOutDate: '',
      isValid: true
    };
    this.sessions.set(roomId, mockSession);
    logger.warn(`[AI-Butler] DEV联调兜底生效：${roomId} -> 酒店${mockSession.hotelId} 房间${mockSession.roomId}`);
    return mockSession;
  }

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
              enum: ['on', 'off', 'toggle', 'set_temperature', 'set_brightness', 'set_volume', 'open', 'close'],
              description: '操作：on=开, off=关, toggle=切换, set_temperature=设置温度, set_brightness=设置亮度, set_volume=设置音量, open=打开, close=关闭'
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
  async verifyGuestAccess(roomId: string | number): Promise<GuestSession | null> {
    try {
      let actualRoomDbId: number | null = null;
      let actualRoomNumber: string | null = null;
      let deviceFoundId: string | null = null;

      // 确保roomId是字符串类型
      const roomIdStr = String(roomId);
      logger.debug(`验证入住状态 - 原始roomId: ${roomId}, 转换后: ${roomIdStr}`);

      // 策略1: 直接作为 device_id 查找
      const [deviceRows] = await pool.query<RowDataPacket[]>(
        `SELECT d.device_id, d.room_id, r.room_number FROM devices d
         LEFT JOIN rooms r ON d.room_id = r.id
         WHERE d.device_id = ? AND d.room_id IS NOT NULL`,
        [roomIdStr]
      );
      if (deviceRows.length > 0) {
        actualRoomDbId = deviceRows[0].room_id;
        actualRoomNumber = deviceRows[0].room_number;
        deviceFoundId = deviceRows[0].device_id;
        logger.info(`通过设备ID ${roomIdStr} 解析到房间DB ID ${actualRoomDbId}, 房号 ${actualRoomNumber}`);
      }

      // 策略2: 如果策略1失败，尝试从 roomId 中提取数字作为 room_id
      if (!actualRoomDbId) {
        const numericId = roomIdStr.replace(/^room_?/, '');
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
          [roomIdStr]
        );
        if (roomRows.length > 0) {
          actualRoomDbId = roomRows[0].id;
          actualRoomNumber = roomRows[0].room_number;
          logger.info(`通过房号 ${roomIdStr} 找到房间DB ID ${actualRoomDbId}`);
        }
      }

      if (!actualRoomDbId) {
        const devSession = await this.buildDevAssumeSession(roomIdStr);
        if (devSession) {
          return devSession;
        }
        logger.warn(`房间 ${roomIdStr} 无有效入住记录，无法解析到任何房间`);
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
        const devSession = await this.buildDevAssumeSession(roomIdStr);
        if (devSession) {
          return devSession;
        }
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

      this.sessions.set(roomIdStr, session);
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
   * 语音识别 - 阿里云百炼Fun-ASR
   */
  async speechToText(audioBase64: string): Promise<string> {
    try {
      // 关键修复：在方法调用时重新读取环境变量，确保获取最新值
      const currentApiKey = process.env.DASHSCOPE_API_KEY || process.env.ALIYUN_ACCESS_KEY || '';
      
      // 调试：检查API Key
      logger.info(`[speechToText] this.aliyunAccessKey: "${this.aliyunAccessKey}"`);
      logger.info(`[speechToText] process.env.ALIYUN_ACCESS_KEY: "${currentApiKey?.substring(0, 10)}..."`);
      
      // 如果实例属性为空但环境变量有值，更新实例属性
      if (!this.aliyunAccessKey && currentApiKey) {
        logger.info('[speechToText] 更新实例属性为环境变量值');
        this.aliyunAccessKey = currentApiKey;
      }
      
      // 检查 API Key 是否配置
      if (!this.aliyunAccessKey) {
        logger.error('阿里云百炼Fun-ASR: ALIYUN_ACCESS_KEY 未配置');
        return '';
      }

      // 将base64音频转换为Buffer
      const audioBuffer = Buffer.from(audioBase64, 'base64');
      
      // 确保音频格式正确（WAV格式）
      const preparedBuffer = this.prepareAudioData(audioBuffer);
      
      // 使用Fun-ASR进行语音识别
      return await this.recognizeWithFunASR(preparedBuffer);
      
    } catch (error: any) {
      logger.error('语音识别处理失败:', error.message || error);
      return '';
    }
  }

  /**
   * 优化ASR识别文本 - 去除重复、修正口语化表达
   * 使用智谱AI进行语义优化
   */
  async optimizeAsrText(rawText: string): Promise<string> {
    try {
      if (!this.zhipuApiKey) {
        logger.warn('[ASR优化] 智谱API Key未配置，跳过优化');
        return rawText;
      }

      const prompt = `你是一个语音识别文本优化助手。请优化以下语音识别结果：
"${rawText}"

优化要求：
1. 去除重复的词语（如"酒店的酒店的"→"酒店的"）
2. 修正口语化表达，使其更通顺
3. 修正语音识别错误的同音词
4. 保持原意不变
5. 只输出优化后的文本，不要任何解释

优化后的文本：`;

      const response = await axios.post('https://open.bigmodel.cn/api/paas/v4/chat/completions', {
        model: 'glm-4-flash',
        messages: [{ role: 'user', content: prompt }],
        temperature: 0.1,
        max_tokens: 200
      }, {
        headers: {
          'Authorization': `Bearer ${this.zhipuApiKey}`,
          'Content-Type': 'application/json'
        },
        timeout: 10000
      });

      if (response.data?.choices?.[0]?.message?.content) {
        const optimized = response.data.choices[0].message.content.trim();
        return optimized || rawText;
      }

      return rawText;
    } catch (error) {
      logger.error('[ASR优化] AI优化失败:', error.message);
      return rawText;
    }
  }

  /**
   * 准备音频数据 - 确保格式正确
   */
  private prepareAudioData(buffer: Buffer): Buffer {
    // 检测音频格式
    const magicBytes = buffer.slice(0, 12).toString('hex');
    logger.info(`[音频格式检测] 前12字节hex: ${magicBytes}`);
    
    // WAV: 52 49 46 46 ... 57 41 56 45 (RIFF ... WAVE)
    // AMR: 23 21 (%)
    // AAC: 通常以 FF 开头
    // OPUS: 4F 67 67 53 (OggS)
    
    if (this.isWavFormat(buffer)) {
      logger.info('检测到WAV格式音频');
      return buffer;
    }
    
    // 检查是否是AMR (23 21)
    if (magicBytes.startsWith('2321')) {
      logger.info('检测到AMR格式，Fun-ASR支持但需要设置format=amr');
      // AMR直接返回，但需要修改运行任务参数
      return buffer;
    }
    
    // 检查是否是AAC相关 (FF)
    if (magicBytes.startsWith('ff') || magicBytes.startsWith('fff')) {
      logger.info('检测到可能为AAC/MP4格式');
      return buffer;
    }
    
    // 默认当作PCM处理，包装成WAV
    logger.info('非WAV格式，当作PCM包装为WAV');
    return this.wrapPcmToWav(buffer);
  }

  /**
   * 将PCM数据包装为WAV格式
   */
  private wrapPcmToWav(pcmData: Buffer): Buffer {
    const sampleRate = 16000;
    const numChannels = 1;
    const bitsPerSample = 16;
    const byteRate = sampleRate * numChannels * bitsPerSample / 8;
    const blockAlign = numChannels * bitsPerSample / 8;
    const dataSize = pcmData.length;
    const fileSize = 44 + dataSize;
    
    const wavBuffer = Buffer.alloc(fileSize);
    
    // RIFF chunk
    wavBuffer.write('RIFF', 0);
    wavBuffer.writeUInt32LE(fileSize - 8, 4);
    wavBuffer.write('WAVE', 8);
    
    // fmt chunk
    wavBuffer.write('fmt ', 12);
    wavBuffer.writeUInt32LE(16, 16);
    wavBuffer.writeUInt16LE(1, 20);
    wavBuffer.writeUInt16LE(numChannels, 22);
    wavBuffer.writeUInt32LE(sampleRate, 24);
    wavBuffer.writeUInt32LE(byteRate, 28);
    wavBuffer.writeUInt16LE(blockAlign, 32);
    wavBuffer.writeUInt16LE(bitsPerSample, 34);
    
    // data chunk
    wavBuffer.write('data', 36);
    wavBuffer.writeUInt32LE(dataSize, 40);
    pcmData.copy(wavBuffer, 44);
    
    return wavBuffer;
  }

  /**
   * 检查是否是WAV格式
   */
  private isWavFormat(buffer: Buffer): boolean {
    return buffer.length > 44 && 
           buffer.toString('ascii', 0, 4) === 'RIFF' && 
           buffer.toString('ascii', 8, 12) === 'WAVE';
  }

  /**
   * 从WAV文件中提取PCM数据
   */
  private extractPcmFromWav(wavBuffer: Buffer): Buffer {
    // WAV文件头部44字节
    // 从第44字节开始是PCM数据
    const dataOffset = 44;
    
    // 读取data chunk的大小（位于36-40字节）
    const dataSize = wavBuffer.readUInt32LE(40);
    
    logger.debug(`WAV文件: 总大小=${wavBuffer.length}, PCM数据偏移=${dataOffset}, PCM数据大小=${dataSize}`);
    
    // 提取PCM数据
    return wavBuffer.slice(dataOffset, dataOffset + dataSize);
  }

  /**
   * 从百炼 Fun-ASR WebSocket result-generated 的 payload 抽取识别文本（字段因版本可能略有差异）
   */
  private extractFunAsrResultText(message: any): string {
    const out = message?.payload?.output;
    if (!out) {
      return '';
    }
    const st = out.sentence;
    if (st && typeof st.text === 'string' && st.text.trim()) {
      return st.text.trim();
    }
    const tr = out.transcription;
    if (tr && typeof tr.text === 'string' && tr.text.trim()) {
      return tr.text.trim();
    }
    if (typeof out.text === 'string' && out.text.trim()) {
      return out.text.trim();
    }
    if (out.stash && typeof out.stash.text === 'string' && out.stash.text.trim()) {
      return out.stash.text.trim();
    }
    return '';
  }

  /**
   * 使用WebSocket连接阿里云百炼Fun-ASR实时语音识别
   * 参考文档: https://help.aliyun.com/zh/model-studio/real-time-speech-recognition
   * 认证方式: 通过URL参数传递token
   */
  private recognizeWithFunASR(audioBuffer: Buffer): Promise<string> {
    return new Promise((resolve, reject) => {
      /**
       * 流式 ASR 官方示例对麦克风流使用 format=pcm 发 s16le 原始帧；本处若用 wav 分片发送，
       * 服务端对 RIFF 边界的解析易异常，转写会飘或为空 —— 与「肯定是转文字问题」强相关。
       */
      let pcmToSend = audioBuffer;
      if (this.isWavFormat(audioBuffer)) {
        pcmToSend = this.extractPcmFromWav(audioBuffer);
      }
      if (pcmToSend.length < 2 || pcmToSend.length % 2 !== 0) {
        reject(new Error('Fun-ASR: 无效 16k PCM 长度（需偶数字节）'));
        return;
      }
      const approxMs = Math.round((pcmToSend.length / 2 / 16000) * 1000);
      logger.info(
        `[Fun-ASR] 流式输入: PCM s16le mono, ${pcmToSend.length} bytes ≈${approxMs}ms @16k, format=pcm`
      );

      /** 每轮 result-generated 多为整句当前最佳假设，应取最后一次，避免多段 append 成重复/乱字 */
      let latestText = '';
      let ws: WebSocket | null = null;
      let isResolved = false;
      let taskStarted = false;
      // 生成32位随机ID（阿里云要求）
      const taskId = `${Date.now()}${Math.random().toString(36).substr(2, 15)}`.slice(0, 32);

      try {
        // 调试：检查API Key
        logger.info(`[DEBUG] this.aliyunAccessKey 类型: ${typeof this.aliyunAccessKey}`);
        logger.info(`[DEBUG] this.aliyunAccessKey 值: "${this.aliyunAccessKey}"`);
        logger.info(`[DEBUG] this.aliyunAccessKey 长度: ${this.aliyunAccessKey?.length || 0}`);
        
        // 构建WebSocket URL（注意：URL末尾有斜杠）
        const wsUrl = 'wss://dashscope.aliyuncs.com/api-ws/v1/inference/';
        const apiKey = this.aliyunAccessKey || '';
        
        logger.info('正在连接百炼Fun-ASR WebSocket...');
        logger.info(`API Key前10位: ${apiKey ? apiKey.substring(0, 10) : '空'}`);
        logger.info(`WebSocket URL: ${wsUrl}`);
        
        // 使用 Authorization header 进行认证（官方推荐方式）
        // 注意：bearer 要小写
        ws = new WebSocket(wsUrl, {
          headers: {
            Authorization: `bearer ${apiKey}`
          }
        });

        ws.on('open', () => {
          logger.info('百炼Fun-ASR WebSocket连接已建立');

          // 发送run-task指令
          // 参考: https://help.aliyun.com/zh/model-studio/real-time-speech-recognition
          const runTaskMessage = {
            header: {
              action: 'run-task',
              task_id: taskId,
              streaming: 'duplex'
            },
            payload: {
              task_group: 'audio',
              task: 'asr',
              function: 'recognition',
              model: 'fun-asr-realtime',
              parameters: {
                sample_rate: 16000,
                format: 'pcm'
              },
              input: {}
            }
          };
          
          try {
            ws!.send(JSON.stringify(runTaskMessage));
            logger.info('已发送run-task指令:', JSON.stringify(runTaskMessage));
          } catch (error) {
            logger.error('发送run-task指令失败:', error);
            if (!isResolved) {
              isResolved = true;
              reject(new Error('发送run-task指令失败'));
            }
          }
        });

        ws.on('message', (data) => {
          try {
            // 按照官方示例，直接解析JSON
            const message = JSON.parse(data.toString());
            
            logger.info(`收到Fun-ASR事件: ${message.header?.event}`);
            
            if (!message.header || !message.header.event) {
              logger.warn('收到无效消息格式');
              return;
            }

            switch (message.header.event) {
              case 'task-started':
                logger.info('Fun-ASR任务已启动，开始发送音频流');
                taskStarted = true;
                this.sendAudioStream(ws!, pcmToSend, taskId);
                break;

              case 'result-generated': {
                const text = this.extractFunAsrResultText(message);
                logger.info(`result-generated payload: ${JSON.stringify(message.payload)}`);
                if (text) {
                  latestText = text;
                  logger.info(`Fun-ASR识别(当前最佳): "${text}"`);
                } else {
                  logger.warn('Fun-ASR result-generated 但未能解析出 text，请对照 payload 结构');
                }
                break;
              }

              case 'task-finished':
                logger.info('Fun-ASR任务完成');
                if (!isResolved) {
                  isResolved = true;
                  logger.info(`百炼Fun-ASR识别成功: "${latestText}"`);
                  resolve(latestText);
                  ws!.close();
                }
                break;

              case 'task-failed':
                const errorMsg = message.header.error_message || 'Fun-ASR任务失败';
                logger.error(`Fun-ASR任务失败: ${errorMsg}`);
                if (!isResolved) {
                  isResolved = true;
                  ws!.close();
                  reject(new Error(errorMsg));
                }
                break;

              default:
                logger.debug('Fun-ASR其他事件:', message.header.event);
            }
          } catch (e) {
            // 如果JSON解析失败，可能是二进制数据，忽略
            logger.debug('解析消息失败，可能是二进制音频数据');
          }
        });

        ws.on('error', (error) => {
          logger.error('百炼Fun-ASR WebSocket错误:', error);
          if (!isResolved) {
            isResolved = true;
            reject(new Error(`WebSocket错误: ${error.message || '未知错误'}`));
          }
        });

        ws.on('close', (code: number, reason: Buffer) => {
          const reasonStr = reason.toString() || '无原因';
          logger.info(`百炼Fun-ASR WebSocket连接已关闭 - 代码: ${code}, 原因: ${reasonStr}`);
          logger.info(
            `[DEBUG] close事件 taskStarted: ${taskStarted} latestText: "${latestText}"`
          );

          if (!isResolved) {
            isResolved = true;

            // 1000 = 正常关闭, 1005 = 无状态码, 其他为异常
            if (code === 1007) {
              reject(
                new Error(
                  `连接被关闭(1007 Invalid payload data): 请检查音频数据格式(建议PCM)或API Key是否正确`
                )
              );
            } else if (!taskStarted) {
              reject(new Error(`任务未启动连接已关闭(代码:${code})，未收到任何响应消息`));
            } else if (latestText) {
              logger.info(`百炼Fun-ASR识别完成: "${latestText}"`);
              resolve(latestText);
            } else {
              reject(new Error(`WebSocket连接关闭(代码:${code})，未获取到识别结果`));
            }
          }
        });

        // 超时处理 - 增加到60秒给足处理时间
        const timeoutId = setTimeout(() => {
          if (!isResolved) {
            isResolved = true;
            if (latestText) {
              logger.info(`百炼Fun-ASR超时但返回结果: "${latestText}"`);
              resolve(latestText);
            } else {
              reject(new Error('百炼Fun-ASR识别超时(60秒)'));
            }
            try {
              ws!.close();
            } catch (e) {
              // 忽略关闭错误
            }
          }
        }, 60000);

      } catch (error) {
        logger.error('百炼Fun-ASR WebSocket初始化失败:', error);
        reject(error);
      }
    });
  }

  /**
   * 发送音频流到 Fun-ASR
   *
   * 调优：
   *   - 块大小 3200B = 100ms @16k s16le，与官方推荐一致；
   *   - 节奏 60ms < 100ms，让服务端总是有「下一块已到」的预读，避免它把短停顿当句末提前出结果；
   *   - 失败时退避 30ms 再试，连失 3 次直接结束；
   *   - 全部块发送完毕后立即发 finish-task，不等待 setTimeout，避免最后 100ms 字尾被吞。
   */
  private sendAudioStream(ws: WebSocket, audioBuffer: Buffer, taskId: string): void {
    if (!audioBuffer || audioBuffer.length === 0) {
      logger.error('音频数据为空，无法发送');
      return;
    }

    const chunkSize = 3200; // 100ms @ 16kHz mono s16le
    /** 比 100ms 略快，让 Fun-ASR 始终有 backpressure，识别更稳 */
    const sendIntervalMs = 60;
    let offset = 0;
    let chunkCount = 0;
    let consecutiveErrors = 0;

    logger.info(`[Fun-ASR 上行] 总大小: ${audioBuffer.length} bytes, chunkSize=${chunkSize}, 间隔=${sendIntervalMs}ms`);

    const sendFinish = () => {
      try {
        const finishTaskMessage = {
          header: {
            action: 'finish-task',
            task_id: taskId,
            streaming: 'duplex'
          },
          payload: { input: {} }
        };
        ws.send(JSON.stringify(finishTaskMessage));
        logger.info(`[Fun-ASR 上行] 已发完 ${chunkCount} 块，已发送 finish-task`);
      } catch (error) {
        logger.error('发送 finish-task 失败:', error);
      }
    };

    const sendNextChunk = () => {
      if (ws.readyState !== WebSocket.OPEN) {
        logger.warn('WebSocket 已关闭，停止发送音频');
        return;
      }

      if (offset >= audioBuffer.length) {
        sendFinish();
        return;
      }

      const endOffset = Math.min(offset + chunkSize, audioBuffer.length);
      const chunk = audioBuffer.subarray(offset, endOffset);

      try {
        ws.send(chunk);
        chunkCount++;
        offset += chunk.length;
        consecutiveErrors = 0;

        if (chunkCount % 10 === 0) {
          logger.debug(`[Fun-ASR 上行] 已发送 ${chunkCount} 块, 进度: ${offset}/${audioBuffer.length}`);
        }

        // 最后一块直接立刻发 finish-task，不再 setTimeout 60ms 等
        if (offset >= audioBuffer.length) {
          sendFinish();
        } else {
          setTimeout(sendNextChunk, sendIntervalMs);
        }
      } catch (error) {
        consecutiveErrors++;
        logger.error(`发送音频块失败 (${consecutiveErrors}/3):`, error);
        if (consecutiveErrors >= 3) {
          logger.error('Fun-ASR 上行连续失败 3 次，放弃本次会话');
          try { ws.close(); } catch { /* ignore */ }
          return;
        }
        setTimeout(sendNextChunk, 30);
      }
    };

    sendNextChunk();
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

      // 模型列表：优先使用flash，如果限流则降级到air
      const models = ['glm-4-flash', 'glm-4-air', 'glm-4'];
      let lastError: any = null;

      for (const model of models) {
        try {
          logger.info(`[AI-Butler] 尝试使用模型: ${model}`);

          const response = await axios.post('https://open.bigmodel.cn/api/paas/v4/chat/completions', {
            model: model,
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
            logger.info(`[AI-Butler] 模型 ${model} 调用成功`);

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
        } catch (error: any) {
          lastError = error;

          // 如果是429限流错误，尝试下一个模型
          if (error.response && error.response.status === 429) {
            logger.warn(`[AI-Butler] 模型 ${model} 限流，尝试下一个模型`);
            continue;
          }

          // 其他错误直接抛出
          throw error;
        }
      }

      // 所有模型都失败了
      logger.error('[AI-Butler] 所有模型都不可用:', lastError?.message);
      if (lastError?.response) {
        logger.error('[AI-Butler] API错误详情:', {
          status: lastError.response.status,
          statusText: lastError.response.statusText,
          data: lastError.response.data
        });
      }

      return {
        content: `您好${session.guestName}，小智正在学习中，马上为您转接前台。[TRANSFER:front_desk]`,
        tool_calls: null,
        needToolCall: false
      };
    } catch (error: any) {
      logger.error('智谱GLM-4调用失败:', error.message);
      if (error.response) {
        logger.error('智谱API错误详情:', {
          status: error.response.status,
          statusText: error.response.statusText,
          data: error.response.data
        });
      }
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

    // 获取房间信息
    const [rooms] = await pool.query<RowDataPacket[]>(
      `SELECT r.id, r.room_number FROM rooms r WHERE r.id = ?`,
      [session.roomDbId]
    );

    if (rooms.length === 0) {
      return '抱歉，无法找到您的房间信息，请联系前台。';
    }

    const room = rooms[0];
    const command = this.buildDeviceCommand(device_type, action, value);

    // 使用房间ID（数据库ID）作为设备ID发送指令
    // 模拟器订阅的主题是 hotel/device/command/room/{room_id}
    const targetDeviceId = `room_${room.id}`;
    logger.debug(`通过AI发送设备指令到房间 ${targetDeviceId}:`, command);

    // 直接向MQTT发送指令，不经过数据库验证（适用于模拟器）
    await this.sendCommandToMQTT(
      targetDeviceId,
      command.command_type,
      command.command_value
    );

    const actionText = this.getActionText(action, value, device_type);
    return `已为您${actionText}。`;
  }

  /**
   * 直接向MQTT发送指令（不经过数据库验证，适用于模拟器）
   */
  private async sendCommandToMQTT(
    deviceId: string,
    commandType: string,
    commandValue: string
  ): Promise<void> {
    try {
      // 使用默认密钥进行签名（模拟器使用默认密钥）
      const defaultKey = '57a2e67b8c3d4e5f6a7b8c9d0e1f2a3b';
      const timestamp = new Date().toISOString();

      // 准备带有签名的消息
      const payload: any = {
        command_id: Date.now(),
        device_id: deviceId,
        command_type: commandType,
        command_value: commandValue,
        timestamp
      };

      // 计算签名
      const crypto = require('crypto');
      const signaturePayload = JSON.stringify({
        command_id: payload.command_id,
        device_id: payload.device_id,
        command_type: payload.command_type,
        command_value: payload.command_value,
        timestamp: payload.timestamp
      });
      payload.signature = crypto.createHmac('sha256', defaultKey).update(signaturePayload).digest('hex');

      // 发布到 MQTT
      const topic = `hotel/device/command/room/${deviceId}`;
      await mqttService.publish(topic, payload);

      logger.info(`AI助手发送设备指令: ${topic}/${commandType}=${commandValue}`);
    } catch (error: any) {
      logger.error('AI助手发送设备指令失败:', error.message);
      throw error;
    }
  }

  /**
   * 构建设备控制指令
   */
  private buildDeviceCommand(deviceType: string, action: string, value?: number): any {
    const v = Number.isFinite(Number(value)) ? Number(value) : undefined;
    switch (action) {
      case 'on':
      case 'open':
        if (deviceType === 'light') {return { command_type: 'light', command_value: 'on' };}
        if (deviceType === 'ac') {return { command_type: 'air', command_value: 'on' };}
        if (deviceType === 'curtain') {return { command_type: 'curtain', command_value: 'open' };}
        if (deviceType === 'lock') {return { command_type: 'door', command_value: 'unlock' };}
        if (deviceType === 'all') {return { command_type: 'scene', command_value: 'welcome' };}
        return { command_type: deviceType, command_value: 'on' };
      case 'off':
      case 'close':
        if (deviceType === 'light') {return { command_type: 'light', command_value: 'off' };}
        if (deviceType === 'ac') {return { command_type: 'air', command_value: 'off' };}
        if (deviceType === 'curtain') {return { command_type: 'curtain', command_value: 'close' };}
        if (deviceType === 'lock') {return { command_type: 'door', command_value: 'lock' };}
        if (deviceType === 'all') {return { command_type: 'scene', command_value: 'sleep' };}
        return { command_type: deviceType, command_value: 'off' };
      case 'toggle':
        if (deviceType === 'light') {return { command_type: 'scene', command_value: 'next' };}
        if (deviceType === 'all') {return { command_type: 'scene', command_value: 'next' };}
        return { command_type: deviceType, command_value: 'toggle' };
      case 'set_temperature':
        return { command_type: 'air', command_value: `temp:${Math.round(v ?? 24)}` };
      case 'set_brightness':
        return { command_type: 'light', command_value: `brightness:${Math.round(v ?? 80)}` };
      case 'set_volume':
        return { command_type: 'volume', command_value: String(Math.round(v ?? 60)) };
      default:
        // 兜底：允许模型直接给出硬件 command_type（例如 light / air / curtain / door / scene）
        return { command_type: deviceType, command_value: action };
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
      case 'set_volume':
        return `已调整至${value || 60}%音量`;
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
   * 语音合成：统一使用 TTS v2（单一路径）
   */
  async textToSpeech(text: string): Promise<string> {
    const cleanText = this.cleanTextForTTS(text);
    if (!cleanText.trim()) {return '';}

    logger.debug(`🎙️ [TTS v2] 待合成文本: "${cleanText.substring(0, 50)}${cleanText.length > 50 ? '...' : ''}" (${cleanText.length}字)`);

    try {
      const audio = await this.ttsV2(cleanText);
      if (audio) {return audio;}
    } catch (e) {
      logger.error('❌ TTS v2也失败:', e.message);
    }

    return '';
  }

  /**
   * 硬件播放用：16kHz s16le mono PCM（Buffer），统一使用 TTS v2 raw
   */
  async textToSpeechPcmS16k(text: string): Promise<Buffer> {
    const cleanText = this.cleanTextForTTS(text);
    if (!cleanText.trim()) {
      return Buffer.alloc(0);
    }
    try {
      const buf = await this.ttsV2Pcm(cleanText);
      if (buf && buf.length > 0) {
        return buf;
      }
    } catch (e: any) {
      logger.error('❌ TTS v2 PCM 也失败:', e.message);
    }
    return Buffer.alloc(0);
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
   * 超拟人：输出 raw PCM 16kHz s16le mono
   */
  private async superHumanTTSPcm(text: string): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      try {
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
                audio: { encoding: 'raw', sample_rate: 16000, channels: 1, bit_depth: 16 }
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
              if (!isResolved) {
                isResolved = true;
                reject(new Error(`${response.header.code}`));
              }
              return;
            }

            if (response.payload && response.payload.audio && response.payload.audio.audio) {
              audioChunks.push(Buffer.from(response.payload.audio.audio, 'base64'));
            }

            if (response.header && response.header.status === 2) {
              if (!isResolved) {
                isResolved = true;
                if (audioChunks.length > 0) {
                  resolve(Buffer.concat(audioChunks as Uint8Array[]));
                } else {
                  reject(new Error('无音频数据'));
                }
              }
              ws.close();
            }
          } catch (e) { /* ignore */ }
        });

        ws.on('error', (error) => {
          if (!isResolved) {
            isResolved = true;
            reject(error);
          }
        });

        ws.on('close', () => {
          if (!isResolved) {
            isResolved = true;
            if (audioChunks.length > 0) {
              resolve(Buffer.concat(audioChunks as Uint8Array[]));
            } else {
              reject(new Error('连接关闭无数据'));
            }
          }
        });

        setTimeout(() => {
          if (!isResolved) {
            isResolved = true;
            ws.close();
            reject(new Error('超时'));
          }
        }, 20000);
      } catch (error) {
        reject(error);
      }
    });
  }

  /**
   * TTS v2：输出 raw PCM 16kHz
   */
  private async ttsV2Pcm(text: string): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      try {
        const url = 'wss://tts-api.xfyun.cn/v2/tts';
        const host = 'tts-api.xfyun.cn';
        const tpath = '/v2/tts';
        const date = new Date().toUTCString();

        const signatureOrigin = `host: ${host}\ndate: ${date}\nGET ${tpath} HTTP/1.1`;
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
              aue: 'raw',
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
              if (!isResolved) {
                isResolved = true;
                reject(new Error(`${response.code}`));
              }
              return;
            }

            if (response.data && response.data.audio) {
              audioChunks.push(Buffer.from(response.data.audio, 'base64'));
            }

            if (response.data && response.data.status === 2) {
              if (!isResolved) {
                isResolved = true;
                if (audioChunks.length > 0) {
                  resolve(Buffer.concat(audioChunks as Uint8Array[]));
                } else {
                  reject(new Error('无音频数据'));
                }
              }
              ws.close();
            }
          } catch (e) { /* ignore */ }
        });

        ws.on('error', (error) => {
          if (!isResolved) {
            isResolved = true;
            reject(error);
          }
        });

        ws.on('close', () => {
          if (!isResolved) {
            isResolved = true;
            if (audioChunks.length > 0) {
              resolve(Buffer.concat(audioChunks as Uint8Array[]));
            } else {
              reject(new Error('连接关闭无数据'));
            }
          }
        });

        setTimeout(() => {
          if (!isResolved) {
            isResolved = true;
            ws.close();
            reject(new Error('超时'));
          }
        }, 20000);
      } catch (error) {
        reject(error);
      }
    });
  }

  /**
   * 处理AI管家请求（完整流程，支持Function Calling）
   */
  async processRequest(request: AIRequest): Promise<AIResponse> {
    const { roomId, audioData, text, sessionId, hardwarePcmTts = false } = request;

    // 1. 验证入住状态
    let session = this.sessions.get(roomId);
    if (!session) {
      session = await this.verifyGuestAccess(roomId);
      if (!session) {
        const denyText = '抱歉，该房间暂无入住记录，无法使用AI管家服务。如需帮助，请直接联系前台。';
        let audioPcmBase64: string | undefined;
        if (hardwarePcmTts) {
          const b = await this.textToSpeechPcmS16k(denyText);
          if (b.length) {
            audioPcmBase64 = b.toString('base64');
          }
        }
        return {
          text: denyText,
          action: 'unauthorized',
          audioUrl: '',
          audioPcmBase64
        };
      }
    }

    let recognizedText = ''; // 在try外部声明，让catch也能访问
    try {
      // 2. 语音识别（如果有音频）
      let userText = text || '';
      if (audioData && !text) {
        recognizedText = await this.speechToText(audioData);
        userText = recognizedText;
      }

      if (!userText.trim()) {
        let approxMs: number | undefined;
        if (audioData) {
          try {
            const pcmBytes = Buffer.from(audioData, 'base64').length;
            approxMs = Math.round((pcmBytes / 2 / 16000) * 1000);
          } catch {
            /* ignore */
          }
        }
        logger.warn(
          `[AI管家] ASR 无有效文本（未走知识库/大模型，仅因识别结果为空）roomId=${roomId} raw=${JSON.stringify(
            recognizedText
          )}${approxMs != null ? ` ~${approxMs}ms@16k` : ''}`
        );
        const emptyHint = '抱歉，我没有听清楚，请再说一遍。';
        let audioUrl = '';
        let audioPcmBase64: string | undefined;
        if (hardwarePcmTts) {
          const b = await this.textToSpeechPcmS16k(emptyHint);
          if (b.length) {
            audioPcmBase64 = b.toString('base64');
          }
        } else {
          audioUrl = (await this.textToSpeech(emptyHint)) || '';
        }
        return {
          text: emptyHint,
          audioUrl,
          audioPcmBase64,
          recognizedText: recognizedText
        };
      }

      logger.debug(`房间 ${roomId} 语音输入: ${userText}`);

      // 3. 大语言模型处理（支持Function Calling）
      const llmResult = await this.chatWithLLM(userText, session);

      // 模型列表（用于降级）
      const models = ['glm-4-flash', 'glm-4-air', 'glm-4'];

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

        // 二次调用也使用模型降级机制
        let finalContent = '';
        for (const model of models) {
          try {
            logger.info(`[AI-Butler] 二次调用尝试使用模型: ${model}`);
            const finalResponse = await axios.post('https://open.bigmodel.cn/api/paas/v4/chat/completions', {
              model: model,
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

            if (finalResponse.data && finalResponse.data.choices && finalResponse.data.choices[0]) {
              finalContent = finalResponse.data.choices[0].message.content;
              logger.info(`[AI-Butler] 二次调用模型 ${model} 成功`);
              break;
            }
          } catch (error: any) {
            if (error.response && error.response.status === 429) {
              logger.warn(`[AI-Butler] 二次调用模型 ${model} 限流，尝试下一个模型`);
              continue;
            }
            throw error;
          }
        }

        if (!finalContent) {
          throw new Error('所有模型二次调用均失败');
        }
        
        // 5. 将最终文本转为语音
        let audioBase64 = '';
        let audioPcmBase64: string | undefined;
        try {
          if (hardwarePcmTts) {
            const b = await this.textToSpeechPcmS16k(finalContent);
            if (b.length) {
              audioPcmBase64 = b.toString('base64');
            }
          } else {
            audioBase64 = await this.textToSpeech(finalContent);
          }
        } catch (ttsError: any) {
          logger.warn('TTS合成失败:', ttsError.message);
        }

        return {
          text: finalContent,
          audioUrl: audioBase64,
          audioPcmBase64,
          action: llmResult.tool_calls[0].function.name,
          ticketData: ticketData,
          hotelName: session.hotelName,
          recognizedText: recognizedText
        };
      }

      const aiReply = llmResult.content;
      
      // 5. 将回复文本转为语音
      let audioBase64 = '';
      let audioPcmBase64: string | undefined;
      try {
        if (hardwarePcmTts) {
          const b = await this.textToSpeechPcmS16k(aiReply);
          if (b.length) {
            audioPcmBase64 = b.toString('base64');
          }
        } else {
          audioBase64 = await this.textToSpeech(aiReply);
        }
      } catch (ttsError: any) {
        logger.warn('TTS合成失败:', ttsError.message);
      }

      const transferMatch = aiReply.match(/\[TRANSFER:(\w+)\]/);
      const action = transferMatch ? 'transfer' : 'reply';
      const target = transferMatch ? transferMatch[1] : undefined;
      const cleanText = aiReply.replace(/\[TRANSFER:\w+\]/g, '');

      return {
        text: cleanText,
        audioUrl: audioBase64,
        audioPcmBase64,
        action,
        target,
        hotelName: session.hotelName,
        recognizedText: recognizedText
      };
    } catch (error: any) {
      logger.error('AI管家处理请求失败:', error.message);
      logger.error('错误堆栈:', error.stack);
      const errText = '抱歉，服务暂时不可用，为您转接前台。';
      let audioPcmBase64: string | undefined;
      let audioUrl = '';
      try {
        if (hardwarePcmTts) {
          const b = await this.textToSpeechPcmS16k(errText);
          if (b.length) {
            audioPcmBase64 = b.toString('base64');
          }
        } else {
          audioUrl = (await this.textToSpeech(errText)) || '';
        }
      } catch (e) {
        /* 忽略 TTS 失败 */
      }
      return {
        text: errText,
        action: 'transfer',
        target: 'front_desk',
        recognizedText: recognizedText,
        audioUrl: audioUrl || undefined,
        audioPcmBase64
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
