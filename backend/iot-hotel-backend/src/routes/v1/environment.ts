import { Router } from 'express';
import environmentController from '../../controllers/environment.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

/**
 * @swagger
 * tags:
 *   name: Environment
 *   description: 环境监控与报警管理接口
 */

const router = Router();

/**
 * @swagger
 * /environment/dashboard:
 *   get:
 *     summary: 获取环境监控概览数据
 *     tags: [Environment]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取
 */
/**
 * @swagger
 * /environment:
 *   get:
 *     summary: 获取环境监控数据
 *     tags: [Environment]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取
 */
router.get('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), environmentController.getEnvironmentData);

/**
 * @swagger
 * /environment/fire-alarms:
 *   get:
 *     summary: 获取当前火警报警列表
 *     tags: [Environment]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取
 */
/**
 * @swagger
 * /environment/history:
 *   get:
 *     summary: 获取环境历史数据
 *     tags: [Environment]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取历史数据
 */
router.get('/history', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), environmentController.getEnvironmentHistory);

/**
 * @swagger
 * /environment/fire-alarms:
 *   get:
 *     summary: 获取火警报警列表
 *     tags: [Environment]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取
 */
router.get('/fire-alarms', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), environmentController.getFireAlarms);

/**
 * @swagger
 * /environment/fire-alarms/{id}/acknowledge:
 *   put:
 *     summary: 确认火警报警 (Acknowledge)
 *     tags: [Environment]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 确认成功
 */
router.put('/fire-alarms/:id/acknowledge', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF]), environmentController.acknowledgeAlarm);

/**
 * @swagger
 * /environment/fire-alarms/{id}/resolve:
 *   put:
 *     summary: 解决火警报警
 *     tags: [Environment]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 已解决
 */
router.put('/fire-alarms/:id/resolve', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF]), environmentController.resolveAlarm);

/**
 * @swagger
 * /environment/devices:
 *   get:
 *     summary: 获取环境传感器设备列表
 *     tags: [Environment]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取
 */
router.get('/devices', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), environmentController.getRoomDevices);

/**
 * @swagger
 * /environment/control:
 *   post:
 *     summary: 环境相关设备批量控制 (如一键通风)
 *     tags: [Environment]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [room_id, action]
 *             properties:
 *               room_id: { type: integer }
 *               action: { type: string, enum: [ventilate, purify, optimize] }
 *     responses:
 *       200:
 *         description: 指令已发送
 */
router.post('/control', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), environmentController.controlDevice);

/**
 * @swagger
 * /environment/event-logs:
 *   get:
 *     summary: 获取环境事件日志
 *     tags: [Environment]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取日志
 */
router.get('/event-logs', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), environmentController.getEventLogs);

/**
 * @swagger
 * /environment/dashboard:
 *   get:
 *     summary: 获取环境监控仪表盘数据
 *     tags: [Environment]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取
 */
router.get('/dashboard', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), environmentController.getDashboardStats);

export default router;
