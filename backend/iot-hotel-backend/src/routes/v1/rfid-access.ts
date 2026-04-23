import { Router } from 'express';
import rfidAccessController from '../../controllers/rfid-access.controller';
import { authenticate, authorize, deviceAuthMiddleware } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

/**
 * @swagger
 * tags:
 *   name: RFIDAccess
 *   description: 刷卡开门记录与验证接口
 */

const router = Router();

/**
 * @swagger
 * /rfid-access/logs:
 *   get:
 *     summary: 获取刷卡记录列表
 *     tags: [RFIDAccess]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取列表
 */

/**
 * @swagger
 * /rfid-access/verify:
 *   post:
 *     summary: 验证房卡权限（设备端调用）
 *     tags: [RFIDAccess]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [card_no, device_id]
 *             properties:
 *               card_no: { type: string }
 *               device_id: { type: string }
 *     responses:
 *       200:
 *         description: 验证通过
 */

const allRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN];



// 需要认证的路由
router.get('/logs', authenticate as any, authorize(allRoles), rfidAccessController.getAll);
router.get('/logs/stats', authenticate as any, authorize(allRoles), rfidAccessController.getStats);

// 设备端调用（使用设备密钥认证 - S-03安全加固）
router.post('/logs', deviceAuthMiddleware as any, rfidAccessController.create);
router.post('/verify', deviceAuthMiddleware as any, rfidAccessController.verify);

export default router;
