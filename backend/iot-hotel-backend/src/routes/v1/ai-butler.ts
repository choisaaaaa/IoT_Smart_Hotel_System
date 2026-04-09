import { Router } from 'express';
import { body } from 'express-validator';
import aiButlerService from '../../services/ai-butler.service';
import { CallService } from '../../services/call.service';
import websocketService from '../../services/websocket.service';
import { authenticate } from '../../middleware/auth';
import logger from '../../utils/logger';

const router = Router();

/**
 * @route POST /api/v1/ai-butler/chat
 * @desc AI管家对话接口
 * @access Private
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

      // 如果需要转接人工，发起通话（集体呼叫模式）
      if (result.action === 'transfer' && result.target === 'front_desk') {
        try {
          // 查找在线的前台
          const onlineStaff = await getOnlineFrontDesk();
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
      logger.error('AI管家对话失败:', error);
      res.status(500).json({
        code: 500,
        message: 'AI服务暂时不可用',
        data: null
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

      res.json({
        code: 200,
        message: 'success',
        data: {
          accessible: true,
          guestName: session.guestName,
          checkInDate: session.checkInDate,
          checkOutDate: session.checkOutDate
        }
      });
    } catch (error) {
      logger.error('验证入住状态失败:', error);
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
      logger.error('唤醒检测失败:', error);
      res.status(500).json({
        code: 500,
        message: '检测失败',
        data: null
      });
    }
  }
);

/**
 * 获取在线前台列表
 */
async function getOnlineFrontDesk(): Promise<any[]> {
  // 从WebSocket服务获取真实在线的前台
  const frontDeskClients = websocketService.getClientsByType('front_desk');
  return frontDeskClients.map(client => ({
    clientId: client.clientId,
    name: client.clientName || client.clientId
  }));
}

export default router;
