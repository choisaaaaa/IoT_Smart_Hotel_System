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
router.get('/logs', authenticate as any, authorize(allRoles), rfidAccessController.getAll);

/**
 * @swagger
 * /rfid-access/logs/stats:
 *   get:
 *     summary: 获取刷卡记录统计
 *     tags: [RFIDAccess]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取统计
 */
router.get('/logs/stats', authenticate as any, authorize(allRoles), rfidAccessController.getStats);

/**
 * @swagger
 * /rfid-access/logs:
 *   post:
 *     summary: 创建刷卡记录（设备端调用）
 *     tags: [RFIDAccess]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       201:
 *         description: 记录创建成功
 */
router.post('/logs', deviceAuthMiddleware as any, rfidAccessController.create);

/**
 * @swagger
 * /rfid-access/verify:
 *   post:
 *     summary: 验证RFID刷卡权限
 *     tags: [RFIDAccess]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 验证结果
 */
router.post('/verify', deviceAuthMiddleware as any, rfidAccessController.verify);

export default router;
