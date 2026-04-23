import { Router } from 'express';
import { list, detail, create, update, remove, updatePassword, updateProfile, sendVerificationCode, authorizeManager, lock, unlock } from '../../controllers/user.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

/**
 * @swagger
 * tags:
 *   name: Users
 *   description: 系统用户与个人资料管理接口
 */

const router = Router();

/**
 * @swagger
 * /users/profile:
 *   put:
 *     summary: 更新个人资料
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               username: { type: string }
 *               email: { type: string }
 *               avatar: { type: string }
 *     responses:
 *       200:
 *         description: 更新成功
 */
router.post('/send-code', sendVerificationCode);
router.put('/profile', authenticate as any, updateProfile);

/**
 * @swagger
 * /users:
 *   get:
 *     summary: 获取系统用户列表
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取列表
 *   post:
 *     summary: 创建新系统用户
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [username, password, role]
 *             properties:
 *               username: { type: string }
 *               password: { type: string }
 *               role: { type: string }
 *               hotel_id: { type: integer }
 *     responses:
 *       201:
 *         description: 创建成功
 */
router.post('/authorize-manager', authenticate as any, authorizeManager);
router.get('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.STAFF]), list);
router.get('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.STAFF]), detail);
router.post('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), create);

router.put('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), update);
router.delete('/:id', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN]), remove);
/**
 * @swagger
 * /users/{id}/lock:
 *   post:
 *     summary: 锁定用户账户
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: 用户已锁定
 */
router.put('/:id/password', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), updatePassword);
router.post('/:id/lock', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN]), lock);

/**
 * @swagger
 * /users/{id}/unlock:
 *   post:
 *     summary: 解锁用户账户
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: 用户已解锁
 */
router.post('/:id/unlock', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), unlock);


export default router;
