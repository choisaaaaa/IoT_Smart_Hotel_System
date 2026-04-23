import { Router } from 'express';
import * as memberController from '../../controllers/member.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

/**
 * @swagger
 * tags:
 *   name: Members
 *   description: 会员与积分管理接口
 */

const router = Router();

/**
 * @swagger
 * /members/me:
 *   get:
 *     summary: 获取当前登录用户的会员信息
 *     tags: [Members]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取
 */
router.get('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), memberController.get);
router.get('/me', authenticate as any, memberController.getMe);

/**
 * @swagger
 * /members/recharge:
 *   post:
 *     summary: 会员余额充值
 *     tags: [Members]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [amount]
 *             properties:
 *               amount: { type: number, minimum: 0.01 }
 *     responses:
 *       200:
 *         description: 充值成功
 */
router.get('/status', authenticate as any, memberController.getStatus);
router.get('/discounts', memberController.getLevelDiscounts);
router.put('/discounts', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN]), memberController.updateLevelDiscounts);
router.post('/recharge', authenticate as any, memberController.rechargeBalance);
router.post('/checkin', authenticate as any, memberController.checkin);

router.post('/fix-schema', authenticate as any, memberController.fixDatabaseSchema);
router.get('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), memberController.getById);
router.post('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), memberController.create);
router.put('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), memberController.update);
router.post('/login', memberController.login);

export default router;
