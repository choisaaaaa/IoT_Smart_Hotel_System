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
 * /users/send-code:
 *   post:
 *     summary: 发送手机验证码
 *     tags: [Users]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [phone]
 *             properties:
 *               phone: { type: string, example: "13800138000" }
 *     responses:
 *       200:
 *         description: 验证码已发送
 */
router.post('/send-code', sendVerificationCode);

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
router.put('/profile', authenticate as any, updateProfile);

/**
 * @swagger
 * /users/authorize-manager:
 *   post:
 *     summary: 授权用户为酒店管理员
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 授权成功
 */
router.post('/authorize-manager', authenticate as any, authorizeManager);

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
 */
router.get('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.STAFF]), list);

/**
 * @swagger
 * /users/{id}:
 *   get:
 *     summary: 获取用户详情
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
 *         description: 成功获取
 */
router.get('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.STAFF]), detail);

/**
 * @swagger
 * /users:
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
router.post('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), create);

/**
 * @swagger
 * /users/{id}:
 *   put:
 *     summary: 更新用户信息
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
 *         description: 更新成功
 */
router.put('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), update);

/**
 * @swagger
 * /users/{id}:
 *   delete:
 *     summary: 删除用户
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
 *         description: 删除成功
 */
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
/**
 * @swagger
 * /users/{id}/password:
 *   put:
 *     summary: 重置用户密码（管理员）
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
 *         description: 密码重置成功
 */
router.put('/:id/password', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), updatePassword);

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
 *         description: 锁定成功
 */
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
