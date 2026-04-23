import { Router } from 'express';
import deviceController from '../../controllers/device.controller';
import { authenticate, authorize, deviceAuthMiddleware, optionalDeviceAuthMiddleware } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

/**
 * @swagger
 * tags:
 *   name: Devices
 *   description: 物联网设备管理与控制接口
 */

const router = Router();

const adminRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN];
const allRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN];

/**
 * @swagger
 * /devices:
 *   get:
 *     summary: 获取设备列表
 *     tags: [Devices]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取列表
 */

/**
 * @swagger
 * /devices/{id}/command:
 *   post:
 *     summary: 向设备发送控制指令
 *     tags: [Devices]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [command, payload]
 *             properties:
 *               command: { type: string, example: "light_on" }
 *               payload: { type: object }
 *     responses:
 *       200:
 *         description: 指令已发送
 */
router.post('/register', optionalDeviceAuthMiddleware as any, deviceController.register);
router.post('/test-beep', authenticate as any, authorize(allRoles), deviceController.testBeep);
router.post('/room-card', authenticate as any, authorize(allRoles), deviceController.handleRoomCard);
router.get('/', authenticate as any, authorize(allRoles), deviceController.getAll);
router.get('/:id', authenticate as any, authorize(allRoles), deviceController.getById);
router.put('/:id/audit', authenticate as any, authorize(adminRoles), deviceController.audit);
router.delete('/:id', authenticate as any, authorize(adminRoles), deviceController.delete);
router.post('/:id/command', authenticate as any, authorize(allRoles), deviceController.sendCommand);

router.get('/:id/sensor-data', authenticate as any, authorize(allRoles), deviceController.getSensorData);
router.get('/:id/sensor-data/latest', authenticate as any, authorize(allRoles), deviceController.getLatestSensorData);
router.get('/:id/commands', authenticate as any, authorize(allRoles), deviceController.getCommandHistory);

export default router;
