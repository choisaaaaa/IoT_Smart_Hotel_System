import { Router } from 'express';
import * as paymentController from '../../controllers/payment.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

/**
 * @swagger
 * tags:
 *   name: Payments
 *   description: 支付与账单管理接口
 */

const router = Router();

/**
 * @swagger
 * /payments:
 *   get:
 *     summary: 获取支付账单列表
 *     tags: [Payments]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取列表
 *   post:
 *     summary: 创建支付订单
 *     tags: [Payments]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [booking_id, amount, payment_method]
 *             properties:
 *               booking_id: { type: integer }
 *               amount: { type: number }
 *               payment_method: { type: string, enum: [wechat, alipay, cash, card] }
 *     responses:
 *       201:
 *         description: 创建成功
 */

const allRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST];
const staffRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN];

router.get('/stats/revenue', authenticate as any, authorize(staffRoles), paymentController.getRevenueStats);
router.get('/', authenticate as any, authorize(staffRoles), paymentController.get);
router.get('/:id', authenticate as any, authorize(staffRoles), paymentController.getById);
router.post('/', authenticate as any, authorize(allRoles), paymentController.create);
router.put('/:id/pay', authenticate as any, paymentController.pay);


export default router;