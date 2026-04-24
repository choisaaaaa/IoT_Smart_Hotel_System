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

const allRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST];
const staffRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN];

/**
 * @swagger
 * /payments/stats/revenue:
 *   get:
 *     summary: 获取收入统计数据 (管理员)
 *     tags: [Payments]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取统计
 */
router.get('/stats/revenue', authenticate as any, authorize(staffRoles), paymentController.getRevenueStats);

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
 */
router.get('/', authenticate as any, authorize(staffRoles), paymentController.get);

/**
 * @swagger
 * /payments/{id}:
 *   get:
 *     summary: 获取支付详情
 *     tags: [Payments]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: 成功获取
 */
router.get('/:id', authenticate as any, authorize(staffRoles), paymentController.getById);

/**
 * @swagger
 * /payments:
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
router.post('/', authenticate as any, authorize(allRoles), paymentController.create);

/**
 * @swagger
 * /payments/{id}/pay:
 *   put:
 *     summary: 确认支付
 *     tags: [Payments]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: 支付确认成功
 */
router.put('/:id/pay', authenticate as any, paymentController.pay);

/**
 * @swagger
 * /payments/{id}/refund:
 *   put:
 *     summary: 执行退款
 *     tags: [Payments]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               refund_reason: { type: string }
 *     responses:
 *       200:
 *         description: 退款成功
 */
router.put('/:id/refund', authenticate as any, authorize(staffRoles), paymentController.refund);

export default router;