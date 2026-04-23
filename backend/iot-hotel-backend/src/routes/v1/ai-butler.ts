import { Router } from 'express';
import { body } from 'express-validator';
import pool, { RowDataPacket } from '../../config/database';
import aiButlerService from '../../services/ai-butler.service';
import mqttService from '../../services/mqtt.service';
import { CallService } from '../../services/call.service';
import websocketService from '../../services/websocket.service';
import { authenticate } from '../../middleware/auth';
import logger from '../../utils/logger';

/**
 * @swagger
 * tags:
 *   name: AI Butler
 *   description: AI 管家语音与文本交互接口
 */

const router = Router();

/**
 * @swagger
 * /ai-butler/chat:
 *   post:
 *     summary: AI管家对话接口
 *     tags: [AI Butler]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [room_id]
 *             properties:
 *               room_id: { type: string, example: "301" }
 *               text: { type: string, example: "打开空调" }
 *               audio: { type: string, description: "Base64编码的音频数据" }
 *               session_id: { type: string }
 *     responses:
 *       200:
 *         description: 成功获取AI响应
 */
router.post('/chat',
  authenticate,
  [
    body('room_id').notEmpty().withMessage('房间号不能为空'),
    body('text').optional().isString(),
    body('audio').optional().isString()
  ],
  async (req, res) => {
    try {
      const { room_id, text, audio } = req.body;

      const result = await aiButlerService.processRequest({
        roomId: room_id,
        text: text,
        audioData: audio,
        sessionId: req.body.session_id || `${room_id}_${Date.now()}`
      });

      // 获取酒店ID用于精准统计在线前台
      const hotelId = result.hotelName ? undefined : req.user?.hotel_id; // 如果result里有酒店名，说明已经内部处理了session

      // 查找在线的前台，用于补充信息
      const onlineStaff = await getOnlineFrontDesk(hotelId);
      result.frontDeskCount = onlineStaff.length;

      // 如果需要转接人工，发起通话（集体呼叫模式）
      if (result.action === 'transfer' && result.target === 'front_desk') {
        try {
          if (onlineStaff.length > 0) {
            // 获取房间所属酒店ID
            const hotelId = req.user?.hotel_id || 1;
            // 发起通话 - 使用room类型，方便前台回拨
            const call = await CallService.initiateCall({
              hotel_id: hotelId,
              caller_type: 'room',
              caller_id: room_id,
              callee_type: 'front_desk',
              callee_id: 'all', // 集体呼叫
              type: 'voice'
            });

            // 广播通知所有在线前台有AI转接的通话
            websocketService.broadcastIncomingCall({
              call_id: call.call_id,
              caller_type: 'room',
              caller_id: room_id,
              caller_name: `AI管家(房间${room_id})`,
              callee_type: 'front_desk',
              callee_id: 'all',
              status: 'calling',
              isTransfer: true,
              transferReason: text
            });

            (result as any).callId = call.call_id;
            (result as any).frontDeskCount = onlineStaff.length;
          } else {
            result.response = '抱歉，当前前台无人在线，请稍后再试或使用手机拨打前台电话。';
          }
        } catch (callError) {
          logger.error('AI转接通话失败:', callError);
          result.response = '转接失败，请稍后再试。';
        }
      }

      res.json({
        code: 200,
        message: 'success',
        data: result
      });
    } catch (error) {
      logger.error('AI管家对话失败:', error.message);
      res.status(500).json({
        code: 500,
        message: 'AI服务暂时不可用',
        data: null
      });
    }
  }
);

/**
 * @route POST /api/v1/ai-butler/asr
 * @desc 纯语音识别接口 - 识别语音并用AI优化文本（去重、修正口语化）
 * @access Private
 */
router.post('/asr',
  authenticate,
  [
    body('audio').notEmpty().withMessage('音频数据不能为空')
  ],
  async (req, res) => {
    try {
      const { audio } = req.body;

      // 调用ASR进行语音识别
      const recognizedText = await aiButlerService.speechToText(audio);

      if (!recognizedText.trim()) {
        return res.json({
          code: 200,
          message: 'success',
          data: {
            text: '',
            recognized: false,
            message: '未能识别到语音内容，请重试'
          }
        });
      }

      // 使用AI对ASR识别结果进行语义优化（去重、修正口语化表达）
      let optimizedText = recognizedText;
      try {
        optimizedText = await aiButlerService.optimizeAsrText(recognizedText);
        logger.info(`[ASR优化] 原始: "${recognizedText}" -> 优化: "${optimizedText}"`);
      } catch (optimizeError) {
        logger.warn('[ASR优化] AI优化失败，使用原始识别结果:', optimizeError.message);
        // 优化失败时使用原始识别结果
      }

      res.json({
        code: 200,
        message: 'success',
        data: {
          text: optimizedText,
          recognized: true,
          originalText: recognizedText, // 保留原始识别结果供调试
          message: '识别成功'
        }
      });
    } catch (error) {
      logger.error('语音识别失败:', error.message);
      res.status(500).json({
        code: 500,
        message: '语音识别失败',
        data: {
          text: '',
          recognized: false,
          message: error.message
        }
      });
    }
  }
);

/**
 * @route POST /api/v1/ai-butler/verify
 * @desc 验证房间入住状态
 * @access Private
 */
router.post('/verify',
  authenticate,
  [
    body('room_id').notEmpty().withMessage('房间号不能为空')
  ],
  async (req, res) => {
    try {
      const { room_id } = req.body;
      const session = await aiButlerService.verifyGuestAccess(room_id);

      if (!session) {
        return res.json({
          code: 403,
          message: '该房间暂无入住记录，无法使用AI管家服务',
          data: { accessible: false }
        });
      }

      // 获取该客人的所有房间
      const roomList = await aiButlerService.getGuestRooms(room_id);

      // 获取在线前台数量
      const onlineStaff = await getOnlineFrontDesk(session.hotelId);

      // 获取酒店详情
      const [hotels] = await pool.query<RowDataPacket[]>(
        'SELECT hotel_name FROM hotels WHERE id = ?',
        [session.hotelId]
      );
      const hotelName = hotels.length > 0 ? hotels[0].hotel_name : '智联酒店';

      res.json({
        code: 200,
        message: 'success',
        data: {
          accessible: true,
          guestName: session.guestName,
          checkInDate: session.checkInDate,
          checkOutDate: session.checkOutDate,
          roomList: roomList.length > 0 ? roomList : [room_id],
          frontDeskOnline: onlineStaff.length > 0,
          frontDeskCount: onlineStaff.length,
          hotelName: hotelName
        }
      });
    } catch (error) {
      logger.error('验证入住状态失败:', error.message);
      res.status(500).json({
        code: 500,
        message: '验证失败',
        data: null
      });
    }
  }
);

/**
 * @route POST /api/v1/ai-butler/wake
 * @desc AI管家唤醒检测
 * @access Private
 */
router.post('/wake',
  authenticate,
  [
    body('room_id').notEmpty().withMessage('房间号不能为空'),
    body('text').notEmpty().withMessage('语音文本不能为空')
  ],
  async (req, res) => {
    try {
      const { room_id, text } = req.body;

      // 唤醒词检测
      const wakeWords = ['小智', '小智小智', 'ai管家', '管家'];
      const isWake = wakeWords.some(word => text.includes(word));

      if (!isWake) {
        return res.json({
          code: 200,
          message: 'success',
          data: { isWake: false }
        });
      }

      // 验证入住状态
      const session = await aiButlerService.verifyGuestAccess(room_id);

      res.json({
        code: 200,
        message: 'success',
        data: {
          isWake: true,
          accessible: !!session,
          guestName: session?.guestName
        }
      });
    } catch (error) {
      logger.error('唤醒检测失败:', error.message);
      res.status(500).json({
        code: 500,
        message: '检测失败',
        data: null
      });
    }
  }
);

/**
 * @route POST /api/v1/ai-butler/broadcast
 * @desc 房间广播接口（AI语音下发）
 * @access Private
 */
router.post('/broadcast',
  authenticate,
  [
    body('room_id').notEmpty().withMessage('房间号不能为空'),
    body('text').notEmpty().withMessage('广播文本不能为空')
  ],
  async (req, res) => {
    try {
      let { room_id, text } = req.body;
      
      // 归一化为数组处理
      const roomIds = Array.isArray(room_id) ? room_id : [room_id];

      logger.info(`收到房间广播请求: 房间=${JSON.stringify(roomIds)}, 文本="${text}"`);

      // 1. 批量查询房间对应的设备 ID
      // 使用 IN 查询，支持多个房间号或 ID
      const [devices] = await pool.query<RowDataPacket[]>(
        `SELECT d.device_id, r.room_number FROM devices d
         JOIN rooms r ON d.room_id = r.id
         WHERE (r.room_number IN (?) OR r.id IN (?)) AND d.device_type = 'room'`,
        [roomIds, roomIds]
      );

      if (devices.length === 0) {
        return res.status(404).json({
          code: 404,
          message: '未找到指定房间的智能终端设备',
          data: null
        });
      }

      // 2. 调用 TTS 合成语音 (只合成一次)
      const audioBase64 = await aiButlerService.textToSpeech(text);

      if (!audioBase64) {
        return res.status(500).json({
          code: 500,
          message: '语音合成失败',
          data: null
        });
      }

      // 3. 循环下发消息
      const results = [];
      for (const device of devices) {
        const deviceId = device.device_id;
        const actualRoomNumber = device.room_number;
        
        const topic = `hotel/ai/response/room/${deviceId}`;
        const payload = {
          device_id: deviceId,
          room_id: actualRoomNumber,
          text: text,
          audio_base64: audioBase64,
          timestamp: Date.now(),
          type: 'broadcast'
        };

        await mqttService.publish(topic, payload);
        results.push({ room_id: actualRoomNumber, device_id: deviceId });
        logger.info(`广播已下发至房间 ${actualRoomNumber} (设备 ${deviceId})`);
      }

      res.json({
        code: 200,
        message: `广播已成功下发至 ${results.length} 个房间`,
        data: results
      });
    } catch (error) {
      logger.error('下发广播失败:', error.message);
      res.status(500).json({
        code: 500,
        message: '下发广播失败',
        data: null
      });
    }
  }
);

/**
 * 获取在线前台列表
 */
async function getOnlineFrontDesk(hotelId?: number): Promise<any[]> {
  // 从WebSocket服务获取真实在线的前台
  const frontDeskClients = websocketService.getClientsByType('front_desk', hotelId);
  return frontDeskClients.map(client => ({
    clientId: client.id, // 这里 WebSocketService 返回的是 { id, name, connectedAt }
    name: client.name || client.id
  }));
}

export default router;
