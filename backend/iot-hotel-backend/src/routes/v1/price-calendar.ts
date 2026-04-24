import { Router } from 'express';
import * as priceController from '../../controllers/price-calendar.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

/**
 * @swagger
 * tags:
 *   name: Pricing
 *   description: 价格日历与库存管理接口
 */

const router = Router();

/**
 * @swagger
 * /price-calendar:
 *   get:
 *     summary: 获取价格日历列表
 *     tags: [Pricing]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取
 */
router.get('/', authenticate as any, priceController.getPriceCalendar);

/**
 * @swagger
 * /price-calendar/set:
 *   post:
 *     summary: 批量设置价格日历
 *     tags: [Pricing]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 设置成功
 */
router.post('/set', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), priceController.setPriceCalendar);

/**
 * @swagger
 * /price-calendar/today:
 *   get:
 *     summary: 获取今日房态与价格概览
 *     tags: [Pricing]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取
 */
router.get('/today', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), priceController.getTodayInventory);

/**
 * @swagger
 * /price-calendar/today/update:
 *   post:
 *     summary: 实时更新今日房态/价格
 *     tags: [Pricing]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 更新成功
 */
router.post('/today/update', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), priceController.updateTodayInventory);



export default router;
