import { Router } from 'express';
import * as memberController from '../../controllers/member.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

/**
 * @swagger
 * tags:
 *   name: Members
 *   description: 会员与积分管理接口
 */

const router = Router();

/**
 * @swagger
 * /members:
 *   get:
 *     summary: 获取会员列表（管理员）
 *     tags: [Members]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取列表
 */
router.get('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), memberController.get);

/**
 * @swagger
 * /members/me:
 *   get:
 *     summary: 获取当前登录用户的会员信息
 *     tags: [Members]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取
 */
router.get('/me', authenticate as any, memberController.getMe);

/**
 * @swagger
 * /members/status:
 *   get:
 *     summary: 获取会员状态统计
 *     tags: [Members]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取
 */
router.get('/status', authenticate as any, memberController.getStatus);

/**
 * @swagger
 * /members/discounts:
 *   get:
 *     summary: 获取会员等级折扣配置
 *     tags: [Members]
 *     responses:
 *       200:
 *         description: 成功获取
 *   put:
 *     summary: 更新会员等级折扣配置
 *     tags: [Members]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 更新成功
 */
router.get('/discounts', memberController.getLevelDiscounts);

/**
 * @swagger
 * /members/discounts:
 *   put:
 *     summary: 更新会员等级折扣配置
 *     tags: [Members]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 更新成功
 */
router.put('/discounts', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN]), memberController.updateLevelDiscounts);

/**
 * @swagger
 * /members/recharge:
 *   post:
 *     summary: 会员余额充值
 *     tags: [Members]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [amount]
 *             properties:
 *               amount: { type: number, minimum: 0.01 }
 *     responses:
 *       200:
 *         description: 充值成功
 */
router.post('/recharge', authenticate as any, memberController.rechargeBalance);

/**
 * @swagger
 * /members/checkin:
 *   post:
 *     summary: 会员每日签到获取积分
 *     tags: [Members]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 签到成功
 */
router.post('/checkin', authenticate as any, memberController.checkin);

/**
 * @swagger
 * /members/fix-schema:
 *   post:
 *     summary: 修复会员数据库Schema
 *     tags: [Members]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 修复完成
 */
router.post('/fix-schema', authenticate as any, memberController.fixDatabaseSchema);

/**
 * @swagger
 * /members/{id}:
 *   get:
 *     summary: 获取会员详情
 *     tags: [Members]
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
router.get('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), memberController.getById);

/**
 * @swagger
 * /members:
 *   post:
 *     summary: 创建会员（管理员）
 *     tags: [Members]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       201:
 *         description: 创建成功
 */
router.post('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), memberController.create);

/**
 * @swagger
 * /members/{id}:
 *   put:
 *     summary: 更新会员信息
 *     tags: [Members]
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
router.put('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), memberController.update);

/**
 * @swagger
 * /members/login:
 *   post:
 *     summary: 会员登录
 *     tags: [Members]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [phone, password]
 *             properties:
 *               phone: { type: string }
 *               password: { type: string, format: password }
 *     responses:
 *       200:
 *         description: 登录成功
 */
router.post('/login', memberController.login);

export default router;
