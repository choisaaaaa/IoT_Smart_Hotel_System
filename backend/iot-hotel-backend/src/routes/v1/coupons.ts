import { Router } from 'express';
import * as couponController from '../../controllers/coupon.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

/**
 * @swagger
 * tags:
 *   name: Coupons
 *   description: 优惠券与营销管理接口
 */

const router = Router();

const allRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST];
const staffRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN];
const adminRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN];

/**
 * @swagger
 * /coupons:
 *   get:
 *     summary: 获取优惠券列表
 *     tags: [Coupons]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取列表
 */
router.get('/', authenticate as any, authorize(allRoles), couponController.get);

/**
 * @swagger
 * /coupons/me:
 *   get:
 *     summary: 获取当前用户的优惠券
 *     tags: [Coupons]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取
 */
router.get('/me', authenticate as any, couponController.getMe);

/**
 * @swagger
 * /coupons/import:
 *   post:
 *     summary: 批量导入优惠券
 *     tags: [Coupons]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 导入成功
 */
router.post('/import', authenticate as any, couponController.importCoupon);

/**
 * @swagger
 * /coupons/redeem:
 *   post:
 *     summary: 通过兑换码核销优惠券
 *     tags: [Coupons]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [code]
 *             properties:
 *               code: { type: string }
 *     responses:
 *       200:
 *         description: 核销成功
 */
router.post('/redeem', authenticate as any, authorize(staffRoles), couponController.redeemByCode);

/**
 * @swagger
 * /coupons/issue-to-user:
 *   post:
 *     summary: 向特定用户发放优惠券
 *     tags: [Coupons]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [user_id, coupon_id]
 *             properties:
 *               user_id: { type: integer }
 *               coupon_id: { type: integer }
 *     responses:
 *       200:
 *         description: 发放成功
 */
router.post('/issue-to-user', authenticate as any, authorize(adminRoles), couponController.issueToUser);

/**
 * @swagger
 * /coupons/hotels:
 *   get:
 *     summary: 获取优惠券关联酒店列表
 *     tags: [Coupons]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取
 */
router.get('/hotels', authenticate as any, couponController.getHotels);

/**
 * @swagger
 * /coupons/{id}:
 *   get:
 *     summary: 获取优惠券详情
 *     tags: [Coupons]
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
router.get('/:id', authenticate as any, authorize(allRoles), couponController.getById);

/**
 * @swagger
 * /coupons:
 *   post:
 *     summary: 创建优惠券（管理员）
 *     tags: [Coupons]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       201:
 *         description: 创建成功
 */
router.post('/', authenticate as any, authorize(adminRoles), couponController.create);

/**
 * @swagger
 * /coupons/{id}:
 *   put:
 *     summary: 更新优惠券
 *     tags: [Coupons]
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
 *     summary: 删除优惠券
 *     tags: [Coupons]
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
router.put('/:id', authenticate as any, authorize(adminRoles), couponController.update);

/**
 * @swagger
 * /coupons/{id}:
 *   delete:
 *     summary: 删除优惠券
 *     tags: [Coupons]
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
router.delete('/:id', authenticate as any, authorize(adminRoles), couponController.remove);
/**
 * @swagger
 * /coupons/{id}/receive:
 *   post:
 *     summary: 领取优惠券
 *     tags: [Coupons]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: 领取成功
 */
router.post('/:id/receive', authenticate as any, couponController.receive);

/**
 * @swagger
 * /coupons/{id}/redeem:
 *   post:
 *     summary: 核销指定优惠券
 *     tags: [Coupons]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: 核销成功
 */
router.post('/:id/redeem', authenticate as any, authorize(staffRoles), couponController.redeemCoupon);


export default router;
