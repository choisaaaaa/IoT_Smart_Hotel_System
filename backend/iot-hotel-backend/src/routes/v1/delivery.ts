import { Router } from 'express';
import * as deliveryController from '../../controllers/delivery.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

/**
 * @swagger
 * tags:
 *   name: Delivery
 *   description: 客房送物管理接口
 */

const router = Router();

const allRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST];
const staffRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN];

/**
 * @swagger
 * /delivery:
 *   get:
 *     summary: 获取送物订单列表
 *     tags: [Delivery]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取列表
 *   post:
 *     summary: 创建送物订单
 *     tags: [Delivery]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [room_id, items]
 *             properties:
 *               room_id: { type: string, example: "301" }
 *               items: 
 *                 type: array
 *                 items:
 *                   type: object
 *                   properties:
 *                     name: { type: string }
 *                     quantity: { type: integer }
 *     responses:
 *       201:
 *         description: 创建成功
 */
router.get('/', authenticate as any, authorize(allRoles), deliveryController.get);

router.get('/:id', authenticate as any, authorize(allRoles), deliveryController.getById);
router.post('/', authenticate as any, authorize(allRoles), deliveryController.create);
router.put('/:id/status', authenticate as any, authorize(staffRoles), deliveryController.updateStatus);
router.put('/:id/complete', authenticate as any, authorize(staffRoles), deliveryController.complete);

export default router;
