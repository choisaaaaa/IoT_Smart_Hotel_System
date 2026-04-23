import { Router } from 'express';
import * as guestController from '../../controllers/frequent-guest.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

/**
 * @swagger
 * tags:
 *   name: FrequentGuests
 *   description: 常住人/联系人管理接口
 */

const router = Router();

router.use(authenticate);

/**
 * @swagger
 * /frequent-guests:
 *   get:
 *     summary: 获取常住人列表
 *     tags: [FrequentGuests]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取列表
 */
router.get('/', authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), guestController.list);

/**
 * @swagger
 * /frequent-guests:
 *   post:
 *     summary: 添加新常住人
 *     tags: [FrequentGuests]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       201:
 *         description: 添加成功
 */
router.post('/', authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), guestController.create);

/**
 * @swagger
 * /frequent-guests/{id}:
 *   put:
 *     summary: 更新常住人信息
 *     tags: [FrequentGuests]
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
router.put('/:id', authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), guestController.update);

/**
 * @swagger
 * /frequent-guests/{id}:
 *   delete:
 *     summary: 删除常住人
 *     tags: [FrequentGuests]
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
router.delete('/:id', authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), guestController.remove);


export default router;
