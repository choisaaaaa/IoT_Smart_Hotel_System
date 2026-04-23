import { Router } from 'express';
import * as reviewController from '../../controllers/review.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

/**
 * @swagger
 * tags:
 *   name: Reviews
 *   description: 酒店评价与申诉管理接口
 */

const router = Router();

/**
 * @swagger
 * /reviews:
 *   get:
 *     summary: 获取评价列表
 *     tags: [Reviews]
 *     parameters:
 *       - in: query
 *         name: hotel_id
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: 成功获取列表
 *   post:
 *     summary: 发表评价
 *     tags: [Reviews]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [booking_id, rating, content]
 *             properties:
 *               booking_id: { type: integer }
 *               rating: { type: integer, minimum: 1, maximum: 5 }
 *               content: { type: string }
 *               images: { type: array, items: { type: string } }
 *     responses:
 *       201:
 *         description: 发表成功
 */

const allRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST];
const staffRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN];
const adminRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN];

// 评价列表和统计 - 游客也可访问
router.get('/', reviewController.get);
router.get('/my', authenticate as any, reviewController.getMyReviews);
router.get('/stats', reviewController.getStats);
router.get('/appeals', authenticate as any, authorize(staffRoles), reviewController.getAppeals);
router.get('/:id', reviewController.getById);
router.post('/', authenticate as any, reviewController.create);
router.put('/:id', authenticate as any, reviewController.update);
/**
 * @swagger
 * /reviews/{id}/reply:
 *   post:
 *     summary: 回复住客评价
 *     tags: [Reviews]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [reply_content]
 *             properties:
 *               reply_content: { type: string }
 *     responses:
 *       200:
 *         description: 回复成功
 */
router.delete('/:id', authenticate as any, authorize(adminRoles), reviewController.remove);
router.post('/:id/reply', authenticate as any, authorize(staffRoles), reviewController.reply);

/**
 * @swagger
 * /reviews/appeals:
 *   post:
 *     summary: 发起评价申诉
 *     tags: [Reviews]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [review_id, reason]
 *             properties:
 *               review_id: { type: integer }
 *               reason: { type: string }
 *     responses:
 *       201:
 *         description: 申诉已提交
 */
router.post('/appeals', authenticate as any, reviewController.createAppeal);
router.put('/appeals/:id', authenticate as any, authorize(adminRoles), reviewController.handleAppeal);



export default router;
