import { Router } from 'express';
import { get, getAll, create, remove, update, getStatistics } from '../../controllers/hotel.controller';
import { getReports } from '../../controllers/report.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

/**
 * @swagger
 * tags:
 *   name: HotelManagement
 *   description: 门店/酒店基础信息管理接口
 */

const router = Router();

/**
 * @swagger
 * /hotel:
 *   get:
 *     summary: 获取当前酒店基础信息
 *     tags: [HotelManagement]
 *     responses:
 *       200:
 *         description: 成功获取
 *   put:
 *     summary: 更新酒店信息
 *     tags: [HotelManagement]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 更新成功
 */

/**
 * @swagger
 * /hotel/all:
 *   get:
 *     summary: 获取所有酒店列表（系统管理员）
 *     tags: [HotelManagement]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取
 */
router.get('/', get as any);
router.get('/all', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.HOTEL_ADMIN]), getAll);

/**
 * @swagger
 * /hotel/statistics:
 *   get:
 *     summary: 获取酒店经营数据统计
 *     tags: [HotelManagement]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取统计
 */
router.post('/', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN]), create);
router.delete('/:id', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN]), remove);
router.put('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), update);
router.get('/statistics', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), getStatistics);

/**
 * @swagger
 * /hotel/reports:
 *   get:
 *     summary: 获取酒店详细报表
 *     tags: [HotelManagement]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取报表
 */
router.get('/reports', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.STAFF]), getReports);



export default router;
