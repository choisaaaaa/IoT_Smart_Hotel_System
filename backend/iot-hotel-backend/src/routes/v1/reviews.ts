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

/**
 * @swagger
 * /reviews:
 *   get:
 *     summary: 获取评价列表
 *     tags: [Reviews]
 *     responses:
 *       200:
 *         description: 成功获取列表
 */
router.get('/', reviewController.get);

/**
 * @swagger
 * /reviews/my:
 *   get:
 *     summary: 获取当前用户的评价
 *     tags: [Reviews]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取
 */
router.get('/my', authenticate as any, reviewController.getMyReviews);

/**
 * @swagger
 * /reviews/stats:
 *   get:
 *     summary: 获取评价统计数据
 *     tags: [Reviews]
 *     parameters:
 *       - in: query
 *         name: hotel_id
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: 成功获取统计
 */
router.get('/stats', reviewController.getStats);

/**
 * @swagger
 * /reviews/appeals:
 *   get:
 *     summary: 获取评价申诉列表（管理员）
 *     tags: [Reviews]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取列表
 */
router.get('/appeals', authenticate as any, authorize(staffRoles), reviewController.getAppeals);

/**
 * @swagger
 * /reviews/{id}:
 *   get:
 *     summary: 获取评价详情
 *     tags: [Reviews]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: 成功获取
 */
router.get('/:id', reviewController.getById);

/**
 * @swagger
 * /reviews:
 *   post:
 *     summary: 创建评价
 *     tags: [Reviews]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       201:
 *         description: 创建成功
 */
router.post('/', authenticate as any, reviewController.create);

/**
 * @swagger
 * /reviews/{id}:
 *   put:
 *     summary: 更新评价
 *     tags: [Reviews]
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
 *     summary: 删除评价
 *     tags: [Reviews]
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

/**
 * @swagger
 * /reviews/{id}/reply:
 *   post:
 *     summary: 回复评价
 *     tags: [Reviews]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: 回复成功
 */
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

/**
 * @swagger
 * /reviews/appeals/{id}:
 *   put:
 *     summary: 处理评价申诉（管理员）
 *     tags: [Reviews]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: 处理完成
 */
router.put('/appeals/:id', authenticate as any, authorize(adminRoles), reviewController.handleAppeal);



export default router;
