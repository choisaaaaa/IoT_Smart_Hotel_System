import { Router } from 'express';
import * as roomController from '../../controllers/room.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

/**
 * @swagger
 * tags:
 *   name: Rooms
 *   description: 房间管理接口
 */

const router = Router();

/**
 * @swagger
 * /rooms/guest/my-room/devices:
 *   get:
 *     summary: 获取当前住客房间的设备列表
 *     tags: [Rooms]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取设备列表
 */
router.get('/guest/my-room/devices', authenticate as any, authorize([CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST, CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), roomController.getMyRoomDevices);

/**
 * @swagger
 * /rooms/guest/my-room:
 *   get:
 *     summary: 获取当前住客的房间信息
 *     tags: [Rooms]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功
 */
router.get('/guest/my-room', authenticate as any, authorize([CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST, CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), roomController.getGuestRoom);

/**
 * @swagger
 * /rooms/guest/{id}/devices:
 *   get:
 *     summary: 获取指定房间的所有设备状态
 *     tags: [Rooms]
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
 */
router.get('/guest/:id/devices', authenticate as any, authorize([CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST, CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), roomController.getGuestRoomDevices);

/**
 * @swagger
 * /rooms:
 *   get:
 *     summary: 获取房间列表
 *     tags: [Rooms]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: hotel_id
 *         schema: { type: integer }
 *         description: 酒店ID
 *     responses:
 *       200:
 *         description: 成功获取列表
 */
router.get('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), roomController.get);

/**
 * @swagger
 * /rooms:
 *   post:
 *     summary: 创建新房间
 *     tags: [Rooms]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [room_number, room_type_id, floor_id]
 *             properties:
 *               room_number: { type: string }
 *               room_type_id: { type: integer }
 *               floor_id: { type: integer }
 *     responses:
 *       201:
 *         description: 创建成功
 */
router.post('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), roomController.create);

/**
 * @swagger
 * /rooms/{id}/status:
 *   patch:
 *     summary: 更新房间状态 (PATCH)
 *     tags: [Rooms]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               status: { type: string, enum: [available, occupied, dirty, maintenance] }
 *     responses:
 *       200:
 *         description: 更新成功
 */
router.patch('/:id/status', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), roomController.updateStatus);
/**
 * @swagger
 * /rooms/{id}/status:
 *   put:
 *     summary: 更新房间状态 (PUT)
 *     tags: [Rooms]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               status: { type: string, enum: [available, occupied, dirty, maintenance] }
 *     responses:
 *       200:
 *         description: 更新成功
 */
router.put('/:id/status', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), roomController.updateStatus);
console.log('[Rooms Router] 已注册 PATCH/PUT /:id/status');

/**
 * @swagger
 * /rooms/{id}:
 *   get:
 *     summary: 获取房间详情
 *     tags: [Rooms]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 成功获取详情
 */
router.get('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), roomController.getById);

/**
 * @swagger
 * /rooms/{id}:
 *   put:
 *     summary: 更新房间信息
 *     tags: [Rooms]
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
 */
router.put('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), roomController.update);

/**
 * @swagger
 * /rooms/{id}:
 *   delete:
 *     summary: 删除房间
 *     tags: [Rooms]
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
router.delete('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), roomController.remove);

console.log('[Rooms Router] 路由注册完成');
console.log('[Rooms Router] 已注册的路由:');
(router as any).stack.forEach((layer: any) => {
  if (layer.route) {
    const methods = Object.keys(layer.route.methods).join(', ').toUpperCase();
    console.log(`  ${methods} ${layer.route.path}`);
  }
});

export default router;
