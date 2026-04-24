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
// BUG-050修复：添加CUSTOMER角色，允许已入住顾客控制房间设备
const allRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER];

/**
 * @swagger
 * /devices/register:
 *   post:
 *     summary: 设备注册/上线
 *     tags: [Devices]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 注册成功
 */
router.post('/register', optionalDeviceAuthMiddleware as any, deviceController.register);

/**
 * @swagger
 * /devices/test-beep:
 *   post:
 *     summary: 远程触发设备蜂鸣器测试
 *     tags: [Devices]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 指令已发送
 */
router.post('/test-beep', authenticate as any, authorize(allRoles), deviceController.testBeep);

/**
 * @swagger
 * /devices/room-card:
 *   post:
 *     summary: 处理房间插卡/取卡事件
 *     tags: [Devices]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 处理成功
 */
router.post('/room-card', authenticate as any, authorize(allRoles), deviceController.handleRoomCard);

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
router.get('/', authenticate as any, authorize(allRoles), deviceController.getAll);

/**
 * @swagger
 * /devices/{id}:
 *   get:
 *     summary: 获取设备详情
 *     tags: [Devices]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 成功获取详情
 */
router.get('/:id', authenticate as any, authorize(allRoles), deviceController.getById);

/**
 * @swagger
 * /devices/{id}/audit:
 *   put:
 *     summary: 设备审核/上线状态更新
 *     tags: [Devices]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 审核成功
 */
router.put('/:id/audit', authenticate as any, authorize(adminRoles), deviceController.audit);

/**
 * @swagger
 * /devices/{id}:
 *   delete:
 *     summary: 删除设备
 *     tags: [Devices]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 删除成功
 */
router.delete('/:id', authenticate as any, authorize(adminRoles), deviceController.delete);

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
router.post('/:id/command', authenticate as any, authorize(allRoles), deviceController.sendCommand);

/**
 * @swagger
 * /devices/{id}/sensor-data:
 *   get:
 *     summary: 获取设备历史传感器数据
 *     tags: [Devices]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 成功获取
 */
router.get('/:id/sensor-data', authenticate as any, authorize(allRoles), deviceController.getSensorData);

/**
 * @swagger
 * /devices/{id}/sensor-data/latest:
 *   get:
 *     summary: 获取设备最新传感器数据
 *     tags: [Devices]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 成功获取
 */
router.get('/:id/sensor-data/latest', authenticate as any, authorize(allRoles), deviceController.getLatestSensorData);

/**
 * @swagger
 * /devices/{id}/commands:
 *   get:
 *     summary: 获取设备指令历史
 *     tags: [Devices]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 成功获取指令历史
 */
router.get('/:id/commands', authenticate as any, authorize(allRoles), deviceController.getCommandHistory);


export default router;
