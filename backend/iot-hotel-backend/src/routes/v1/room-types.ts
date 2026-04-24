import { Router } from 'express';
import { RoomTypeController } from '../../controllers/room-type.controller';
import { authenticate, authorize, optionalAuth } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

/**
 * @swagger
 * tags:
 *   name: RoomTypes
 *   description: 房型定义管理接口
 */

const router = Router();

/**
 * @swagger
 * /room-types:
 *   get:
 *     summary: 获取房型列表
 *     tags: [RoomTypes]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取列表
 */
router.get('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), RoomTypeController.getRoomTypes);

/**
 * @swagger
 * /room-types/{id}:
 *   get:
 *     summary: 获取房型详情
 *     tags: [RoomTypes]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: 成功获取详情
 */
router.get('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), RoomTypeController.getRoomTypeById);

/**
 * @swagger
 * /room-types:
 *   post:
 *     summary: 创建新房型
 *     tags: [RoomTypes]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [name, hotel_id, base_price]
 *             properties:
 *               name: { type: string }
 *               hotel_id: { type: integer }
 *               base_price: { type: number }
 *     responses:
 *       201:
 *         description: 创建成功
 */
router.post('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), RoomTypeController.createRoomType);

/**
 * @swagger
 * /room-types/{id}:
 *   put:
 *     summary: 更新房型信息
 *     tags: [RoomTypes]
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
 *   delete:
 *     summary: 删除房型
 *     tags: [RoomTypes]
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
router.put('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), RoomTypeController.updateRoomType);

/**
 * @swagger
 * /room-types/{id}:
 *   delete:
 *     summary: 删除房型
 *     tags: [RoomTypes]
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
router.delete('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), RoomTypeController.deleteRoomType);

export default router;
