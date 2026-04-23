import { Router } from 'express';
import * as maintenanceController from '../../controllers/maintenance.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

/**
 * @swagger
 * tags:
 *   name: Maintenance
 *   description: 维修工单管理接口
 */

const router = Router();

const allRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST];
const staffRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN];
const adminRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN];

/**
 * @swagger
 * /maintenance:
 *   get:
 *     summary: 获取维修工单列表
 *     tags: [Maintenance]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取列表
 *   post:
 *     summary: 创建维修工单
 *     tags: [Maintenance]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [room_id, title, description]
 *             properties:
 *               room_id: { type: integer }
 *               title: { type: string }
 *               description: { type: string }
 *               priority: { type: string, enum: [low, medium, high] }
 *     responses:
 *       201:
 *         description: 创建成功
 */
router.get('/', authenticate as any, authorize(allRoles), maintenanceController.get);
router.get('/:id', authenticate as any, authorize(allRoles), maintenanceController.getById);
router.post('/', authenticate as any, authorize(allRoles), maintenanceController.create);

router.put('/:id/assign', authenticate as any, authorize(staffRoles), maintenanceController.assign);
router.put('/:id/status', authenticate as any, authorize(staffRoles), maintenanceController.updateStatus);
router.put('/:id/complete', authenticate as any, authorize(staffRoles), maintenanceController.complete);
router.delete('/:id', authenticate as any, authorize(adminRoles), maintenanceController.remove);

export default router;
