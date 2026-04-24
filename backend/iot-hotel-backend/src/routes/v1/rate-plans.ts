import { Router } from 'express';
import * as ratePlanController from '../../controllers/rate-plan.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

/**
 * @swagger
 * tags:
 *   name: RatePlans
 *   description: 价格方案管理接口
 */

const router = Router();

/**
 * @swagger
 * /rate-plans:
 *   get:
 *     summary: 获取价格方案列表
 *     tags: [RatePlans]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取列表
 */
router.get('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), ratePlanController.getRatePlans);

/**
 * @swagger
 * /rate-plans:
 *   post:
 *     summary: 创建价格方案
 *     tags: [RatePlans]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       201:
 *         description: 创建成功
 */
router.post('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), ratePlanController.createRatePlan);

/**
 * @swagger
 * /rate-plans/{id}:
 *   put:
 *     summary: 更新价格方案
 *     tags: [RatePlans]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: 更新成功
 */
router.put('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), ratePlanController.updateRatePlan);

/**
 * @swagger
 * /rate-plans/{id}:
 *   delete:
 *     summary: 删除价格方案
 *     tags: [RatePlans]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: 删除成功
 */
router.delete('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), ratePlanController.deleteRatePlan);

export default router;
