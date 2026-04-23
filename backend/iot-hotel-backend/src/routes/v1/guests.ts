import { Router } from 'express';
import * as guestController from '../../controllers/guest.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

/**
 * @swagger
 * tags:
 *   name: Guests
 *   description: 住客信息管理接口
 */

const router = Router();

/**
 * @swagger
 * /guests:
 *   get:
 *     summary: 获取住客列表
 *     tags: [Guests]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取列表
 */
/**
 * @swagger
 * /guests/{id}:
 *   get:
 *     summary: 获取住客详情
 *     tags: [Guests]
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
 *   put:
 *     summary: 更新住客信息
 *     tags: [Guests]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 更新成功
 *   delete:
 *     summary: 删除住客记录
 *     tags: [Guests]
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
router.get('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), guestController.get);
router.get('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), guestController.getById);
router.post('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), guestController.create);
router.put('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), guestController.update);
router.delete('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), guestController.remove);

/**
 * @swagger
 * /guests/booking/{booking_id}:
 *   get:
 *     summary: 按预订ID查询住客
 *     tags: [Guests]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: booking_id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 成功获取
 */
router.get('/booking/:booking_id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), guestController.getByBookingId);


export default router;
