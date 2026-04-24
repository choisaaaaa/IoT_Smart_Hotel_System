import { Router } from 'express';
import * as callController from '../../controllers/call.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';
import { successResponse, errorResponse, AuthRequest } from '../../types';
import { getVoiceGateway } from '../../services/voice-gateway.service';
import logger from '../../utils/logger';
import pool, { RowDataPacket } from '../../config/database';
import mqttService from '../../services/mqtt.service';

/**
 * @swagger
 * tags:
 *   name: Calls
 *   description: 语音通话与前台呼叫接口
 */

const router = Router();

/**
 * @swagger
 * /calls/initiate:
 *   post:
 *     summary: 发起通话
 *     tags: [Calls]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [callee_type, callee_id]
 *             properties:
 *               callee_type: { type: string, enum: [front_desk, room] }
 *               callee_id: { type: string }
 *     responses:
 *       200:
 *         description: 通话已发起
 */
router.post('/initiate', authenticate as any, callController.initiateCall);
router.post('/outbound', authenticate as any, callController.outboundCall);

// BUG-067修复：固定路径必须放在动态路径/:call_id之前，否则/active会被当作call_id匹配
router.get('/active', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), callController.getActiveCalls);
router.get('/history', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), callController.getCallHistory);
router.get('/stats', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), callController.getCallStats);

router.get('/:call_id/answer', authenticate as any, callController.answerCall);

/**
 * @swagger
 * /calls/{call_id}/answer:
 *   post:
 *     summary: 接听通话
 *     tags: [Calls]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: call_id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 接听成功
 */
router.post('/:call_id/answer', authenticate as any, callController.answerCall);

/**
 * @swagger
 * /calls/{call_id}/reject:
 *   post:
 *     summary: 拒接通话
 *     tags: [Calls]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: call_id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 拒接成功
 */
router.post('/:call_id/reject', authenticate as any, callController.rejectCall);
router.post('/:call_id/hangup', authenticate as any, callController.hangupCall);
router.get('/:call_id/status', authenticate as any, callController.getCallStatus);

// WebRTC 语音网关路由

/**
 * POST /api/v1/calls/webrtc/session
 * 创建 WebRTC 语音会话
 * 用于前端浏览器与房间硬件设备建立 WebRTC 语音通话
 */
/**
 * @swagger
 * /calls/webrtc/session:
 *   post:
 *     summary: 创建 WebRTC 语音会话
 *     tags: [Calls]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [call_id]
 *             properties:
 *               call_id: { type: string }
 *               room_id: { type: integer }
 *               room_number: { type: string }
 *     responses:
 *       200:
 *         description: 会话已创建
 */
router.post('/webrtc/session', authenticate as any, async (req: AuthRequest, res) => {

  try {
    const { call_id, room_id, room_number } = req.body;
    const currentUser = req.user as any;

    if (!call_id || (!room_id && !room_number)) {
      return res.status(400).json(errorResponse('缺少必要参数：call_id 和 room_id/room_number'));
    }

    // 验证通话存在
    const [calls] = await pool.query<RowDataPacket[]>('SELECT * FROM calls WHERE call_id = ?', [call_id]);
    if (calls.length === 0) {
      return res.status(404).json(errorResponse('通话不存在'));
    }

    // 获取房间设备ID
    let targetRoomId = room_id;
    if (room_number && !room_id) {
      const [rooms] = await pool.query<RowDataPacket[]>('SELECT id FROM rooms WHERE room_number = ? AND hotel_id = ?', [room_number, currentUser.hotel_id]);
      if (rooms.length > 0) {
        targetRoomId = rooms[0].id;
      }
    }

    if (!targetRoomId) {
      return res.status(404).json(errorResponse('房间不存在'));
    }

    // 查询房间设备
    const [devices] = await pool.query<RowDataPacket[]>(
      'SELECT device_id, device_type FROM devices WHERE room_id = ? AND device_type = "room" AND audit_status = "approved" LIMIT 1',
      [targetRoomId]
    );

    if (devices.length === 0) {
      return res.status(404).json(errorResponse('房间设备不存在或未审核'));
    }

    const deviceId = devices[0].device_id;

    // 获取房间号
    let finalRoomNumber = room_number;
    if (!finalRoomNumber) {
      const [rooms] = await pool.query<RowDataPacket[]>('SELECT room_number FROM rooms WHERE id = ?', [targetRoomId]);
      if (rooms.length > 0) {
        finalRoomNumber = rooms[0].room_number;
      }
    }

    // 创建 WebRTC 会话
    const voiceGateway = getVoiceGateway();
    const session = await voiceGateway.createSession(call_id, deviceId, finalRoomNumber || 'unknown', currentUser.hotel_id);

    logger.info(`[VoiceGateway] 前端请求创建 WebRTC 会话: call_id=${call_id}, device=${deviceId}, room=${finalRoomNumber}`);

    return res.json(successResponse({
      session_id: session.sessionId,
      call_id: session.callId,
      device_id: session.deviceId,
      room_number: session.roomNumber,
      state: session.state,
      created_at: session.createdAt.toISOString()
    }, 'WebRTC 会话已创建，等待设备响应'));
  } catch (error: any) {
    logger.error(`创建 WebRTC 会话失败: ${error.message}`, { stack: error.stack });
    return res.status(500).json(errorResponse(`创建 WebRTC 会话失败: ${error.message}`));
  }
});

/**
 * POST /api/v1/calls/webrtc/:session_id/sdp-offer
 * 前端发送 SDP Offer 到语音网关
 */
/**
 * @swagger
 * /calls/webrtc/{session_id}/sdp-offer:
 *   post:
 *     summary: 发送SDP Offer到语音网关
 *     tags: [Calls]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: session_id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [sdp]
 *             properties:
 *               sdp: { type: object, description: "SDP Offer对象" }
 *     responses:
 *       200:
 *         description: SDP Offer已接收
 */
router.post('/webrtc/:session_id/sdp-offer', authenticate as any, async (req: AuthRequest, res) => {
  try {
    const { session_id } = req.params;
    const { sdp } = req.body;
    const currentUser = req.user as any;

    if (!sdp || !sdp.type || !sdp.sdp) {
      return res.status(400).json(errorResponse('缺少 SDP 参数'));
    }

    const voiceGateway = getVoiceGateway();
    const session = voiceGateway.getSession(session_id);

    if (!session) {
      return res.status(404).json(errorResponse('会话不存在'));
    }

    // 权限检查
    if (session.hotelId !== currentUser.hotel_id && currentUser.role !== 'system_admin') {
      return res.status(403).json(errorResponse('权限不足'));
    }

    const result = await voiceGateway.handleSDPOffer(session_id, req.headers['x-client-id'] as string || session_id, sdp);

    if (!result.success) {
      return res.status(400).json(errorResponse(result.error || '处理 SDP Offer 失败'));
    }

    return res.json(successResponse({
      session_id,
      state: 'negotiating',
      message: 'SDP Offer 已转发到设备，等待 SDP Answer'
    }, 'SDP Offer 已接收'));
  } catch (error: any) {
    logger.error(`处理 SDP Offer 失败: ${error.message}`, { stack: error.stack });
    return res.status(500).json(errorResponse(`处理 SDP Offer 失败: ${error.message}`));
  }
});

/**
 * POST /api/v1/calls/webrtc/:session_id/ice-candidate
 * 前端发送 ICE Candidate 到语音网关
 */
/**
 * @swagger
 * /calls/webrtc/{session_id}/ice-candidate:
 *   post:
 *     summary: 发送ICE Candidate到语音网关
 *     tags: [Calls]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: session_id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [candidate]
 *             properties:
 *               candidate: { type: object, description: "ICE Candidate对象" }
 *     responses:
 *       200:
 *         description: ICE Candidate已接收
 */
router.post('/webrtc/:session_id/ice-candidate', authenticate as any, async (req: AuthRequest, res) => {
  try {
    const { session_id } = req.params;
    const { candidate } = req.body;

    if (!candidate) {
      return res.status(400).json(errorResponse('缺少 ICE candidate 参数'));
    }

    const voiceGateway = getVoiceGateway();
    const session = voiceGateway.getSession(session_id);

    if (!session) {
      return res.status(404).json(errorResponse('会话不存在'));
    }

    await voiceGateway.handleICECandidate(session_id, candidate);

    return res.json(successResponse({
      session_id,
      message: 'ICE candidate 已转发'
    }, 'ICE candidate 已接收'));
  } catch (error: any) {
    logger.error(`处理 ICE candidate 失败: ${error.message}`, { stack: error.stack });
    return res.status(500).json(errorResponse(`处理 ICE candidate 失败: ${error.message}`));
  }
});

/**
 * POST /api/v1/calls/webrtc/:session_id/terminate
 * 终止 WebRTC 会话
 */
/**
 * @swagger
 * /calls/webrtc/{session_id}/terminate:
 *   post:
 *     summary: 终止WebRTC会话
 *     tags: [Calls]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: session_id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               reason: { type: string, example: "user_hangup" }
 *     responses:
 *       200:
 *         description: 会话已终止
 */
router.post('/webrtc/:session_id/terminate', authenticate as any, async (req: AuthRequest, res) => {
  try {
    const { session_id } = req.params;
    const { reason = 'user_hangup' } = req.body;
    const currentUser = req.user as any;

    const voiceGateway = getVoiceGateway();
    const session = voiceGateway.getSession(session_id);

    if (!session) {
      return res.status(404).json(errorResponse('会话不存在'));
    }

    // 权限检查
    if (session.hotelId !== currentUser.hotel_id && currentUser.role !== 'system_admin') {
      return res.status(403).json(errorResponse('权限不足'));
    }

    voiceGateway.terminateSession(session_id, reason);

    return res.json(successResponse({
      session_id,
      call_id: session.callId,
      reason,
      message: '会话已终止'
    }, '会话已终止'));
  } catch (error: any) {
    logger.error(`终止 WebRTC 会话失败: ${error.message}`, { stack: error.stack });
    return res.status(500).json(errorResponse(`终止 WebRTC 会话失败: ${error.message}`));
  }
});

/**
 * GET /api/v1/calls/webrtc/sessions
 * 获取活跃 WebRTC 会话列表（管理用）
 */
/**
 * @swagger
 * /calls/webrtc/sessions:
 *   get:
 *     summary: 获取活跃WebRTC会话列表
 *     tags: [Calls]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取会话列表
 */
router.get('/webrtc/sessions', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), async (req: AuthRequest, res) => {
  try {
    const voiceGateway = getVoiceGateway();
    const sessions = voiceGateway.getActiveSessions();
    const stats = voiceGateway.getStats();

    return res.json(successResponse({
      sessions,
      stats,
      timestamp: new Date().toISOString()
    }, '获取 WebRTC 会话列表成功'));
  } catch (error: any) {
    logger.error(`获取 WebRTC 会话列表失败: ${error.message}`, { stack: error.stack });
    return res.status(500).json(errorResponse(`获取 WebRTC 会话列表失败: ${error.message}`));
  }
});

/**
 * GET /api/v1/calls/webrtc/stats
 * 获取 WebRTC 语音网关统计
 */
/**
 * @swagger
 * /calls/webrtc/stats:
 *   get:
 *     summary: 获取WebRTC语音网关统计
 *     tags: [Calls]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取统计
 */
router.get('/webrtc/stats', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), async (req: AuthRequest, res) => {
  try {
    const voiceGateway = getVoiceGateway();
    const stats = voiceGateway.getStats();

    return res.json(successResponse(stats, '获取 WebRTC 统计成功'));
  } catch (error: any) {
    logger.error(`获取 WebRTC 统计失败: ${error.message}`, { stack: error.stack });
    return res.status(500).json(errorResponse(`获取 WebRTC 统计失败: ${error.message}`));
  }
});

export default router;
