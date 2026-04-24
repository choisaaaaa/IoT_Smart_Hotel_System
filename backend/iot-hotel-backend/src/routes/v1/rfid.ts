import { Router } from 'express';
import rfidController from '../../controllers/rfid.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

/**
 * @swagger
 * tags:
 *   name: RFID
 *   description: 房卡(RFID)管理与发放接口
 */

const router = Router();

/**
 * @swagger
 * /rfid/issue:
 *   post:
 *     summary: 发放新房卡
 *     tags: [RFID]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [booking_id, card_no]
 *             properties:
 *               booking_id: { type: integer }
 *               card_no: { type: string }
 *     responses:
 *       200:
 *         description: 发放成功
 */
/**
 * @swagger
 * /rfid/list:
 *   get:
 *     summary: 获取所有已发放房卡列表
 *     tags: [RFID]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取列表
 */
router.use(authenticate);

/**
 * @swagger
 * /rfid/issue:
 *   post:
 *     summary: 发放房卡
 *     tags: [RFID]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 发放成功
 */
router.post('/issue', authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), rfidController.issue);

/**
 * @swagger
 * /rfid/issue-privilege:
 *   post:
 *     summary: 发放特权房卡
 *     tags: [RFID]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 发放成功
 */
router.post('/issue-privilege', authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), rfidController.issuePrivilege);

/**
 * @swagger
 * /rfid/list:
 *   get:
 *     summary: 获取房卡列表
 *     tags: [RFID]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取列表
 */
router.get('/list', authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), rfidController.list);

/**
 * @swagger
 * /rfid/status:
 *   put:
 *     summary: 更新房卡状态（启用/禁用/作废）
 *     tags: [RFID]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 更新成功
 */
router.put('/status', authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), rfidController.updateStatus);

/**
 * @swagger
 * /rfid/info:
 *   get:
 *     summary: 获取房卡信息
 *     tags: [RFID]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取
 */
router.get('/info', rfidController.getInfo);

/**
 * @swagger
 * /rfid/booking/{booking_id}:
 *   get:
 *     summary: 获取预订关联的房卡列表
 *     tags: [RFID]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: booking_id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: 成功获取
 */
router.get('/booking/:booking_id', rfidController.getBookingCards);

/**
 * @swagger
 * /rfid/expiry:
 *   put:
 *     summary: 更新房卡有效期
 *     tags: [RFID]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 更新成功
 */
router.put('/expiry', authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), rfidController.updateExpiry);

export default router;
