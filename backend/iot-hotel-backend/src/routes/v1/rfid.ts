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


router.post('/issue', authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), rfidController.issue);
router.post('/issue-privilege', authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), rfidController.issuePrivilege);
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
router.get('/info', rfidController.getInfo);
router.get('/booking/:booking_id', rfidController.getBookingCards);
router.put('/status', authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), rfidController.updateStatus);
router.put('/expiry', authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), rfidController.updateExpiry);

export default router;
