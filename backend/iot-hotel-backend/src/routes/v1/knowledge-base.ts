import { Router } from 'express';
import { getAll, getById, createOrUpdate, toggleActive, remove, initDefault } from '../../controllers/knowledge-base.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

/**
 * @swagger
 * tags:
 *   name: KnowledgeBase
 *   description: AI 知识库管理接口
 */

const router = Router();

/**
 * @swagger
 * /knowledge-base:
 *   get:
 *     summary: 获取所有知识库条目
 *     tags: [KnowledgeBase]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取列表
 */
router.get('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), getAll);

router.post('/init', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), initDefault);
router.get('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), getById);
/**
 * @swagger
 * /knowledge-base/{category}:
 *   put:
 *     summary: 创建或更新分类知识库内容
 *     tags: [KnowledgeBase]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: category
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 操作成功
 */
router.put('/:category', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), createOrUpdate);
router.patch('/:id/toggle', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), toggleActive);
router.delete('/:id', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN]), remove);

export default router;
