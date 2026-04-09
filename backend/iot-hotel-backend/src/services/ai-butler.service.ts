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
  callId?: string;
  frontDeskCount?: number;
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
        `SELECT b.*, r.room_number
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
      
      // 构建鉴权
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
      // 降级处理：返回空字符串
      return '';
    }
  }

  /**
   * 大语言模型对话 - 智谱GLM-4-Flash
   */
  async chatWithLLM(text: string, session: GuestSession, history: any[] = []): Promise<string> {
    try {
      const systemPrompt = `你是智慧酒店的AI管家"小智"，为客人提供贴心服务。
当前客人：${session.guestName}，房间号：${session.roomId}，入住日期：${session.checkInDate}，退房日期：${session.checkOutDate}。

你可以提供以下服务：
1. 转接前台人工服务 - 当客人说"转人工"、"找前台"、"需要人工服务"时
2. 客房服务 - 清洁、送物品等
3. 酒店信息咨询
4. 周边推荐

回复要求：
- 语气亲切礼貌，称呼客人名字
- 回复简洁，不超过50字
- 如需转接人工，在回复末尾添加 [TRANSFER:front_desk]`;

      const messages = [
        { role: 'system', content: systemPrompt },
        ...history.slice(-4), // 保留最近4轮对话
        { role: 'user', content: text }
      ];

      const response = await axios.post('https://open.bigmodel.cn/api/paas/v4/chat/completions', {
        model: 'glm-4-flash',
        messages: messages,
        temperature: 0.7,
        max_tokens: 150
      }, {
        headers: {
          'Authorization': `Bearer ${this.zhipuApiKey}`,
          'Content-Type': 'application/json'
        },
        timeout: 10000
      });

      if (response.data && response.data.choices && response.data.choices[0]) {
        return response.data.choices[0].message.content;
      }

      throw new Error('LLM响应异常');
    } catch (error) {
      logger.error('智谱GLM-4调用失败:', error);
      // 降级回复
      return `您好${session.guestName}，小智正在学习中，马上为您转接前台。[TRANSFER:front_desk]`;
    }
  }

  /**
   * 语音合成 - 讯飞TTS
   */
  async textToSpeech(text: string): Promise<string> {
    try {
      // 移除转接标记后再合成语音
      const cleanText = text.replace(/\[TRANSFER:\w+\]/g, '');
      
      const url = 'https://tts-api.xfyun.cn/v2/tts';
      const date = new Date().toUTCString();
      
      const signature = this.buildXfyunSignature(date);
      
      const response = await axios.post(url, {
        common: {
          app_id: this.xfyunAppId
        },
        business: {
          aue: 'lame', // mp3格式
          vcn: 'xiaoyan', // 发音人
          speed: 50,
          volume: 50,
          pitch: 50
        },
        data: {
          text: Buffer.from(cleanText).toString('base64'),
          status: 2
        }
      }, {
        headers: {
          'Date': date,
          'Authorization': signature,
          'Content-Type': 'application/json'
        },
        timeout: 15000
      });

      if (response.data && response.data.data && response.data.data.audio) {
        return response.data.data.audio; // base64音频
      }

      throw new Error('TTS合成失败');
    } catch (error) {
      logger.error('讯飞TTS合成失败:', error);
      return '';
    }
  }

  /**
   * 处理AI管家请求（完整流程）
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

      // 3. 大语言模型处理
      const aiReply = await this.chatWithLLM(userText, session);

      // 4. 检查是否需要转接
      const transferMatch = aiReply.match(/\[TRANSFER:(\w+)\]/);
      const action = transferMatch ? 'transfer' : 'reply';
      const target = transferMatch ? transferMatch[1] : undefined;
      const cleanText = aiReply.replace(/\[TRANSFER:\w+\]/g, '');

      // 5. 如果需要转接，立即返回（不等待语音合成）
      if (action === 'transfer') {
        return {
          text: cleanText || '正在为您转接前台...',
          audioUrl: '', // 转接时不播放语音
          action,
          target
        };
      }

      // 6. 语音合成（仅普通回复）
      const audioBase64 = await this.textToSpeech(cleanText);

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
   * 检查是否需要转接人工（关键词匹配兜底）
   */
  checkTransferKeyword(text: string): { needTransfer: boolean; target?: string } {
    const transferKeywords = ['转人工', '找前台', '人工服务', '找服务员', '投诉'];
    const lowerText = text.toLowerCase();
    
    for (const keyword of transferKeywords) {
      if (lowerText.includes(keyword)) {
        return { needTransfer: true, target: 'front_desk' };
      }
    }
    
    return { needTransfer: false };
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
