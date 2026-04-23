import express from 'express';
import * as systemConfigController from '../../controllers/system-config.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

/**
 * @swagger
 * tags:
 *   name: Config
 *   description: 系统全局参数配置接口
 */

const router = express.Router();

/**
 * @swagger
 * /system-config:
 *   get:
 *     summary: 获取所有系统配置
 *     tags: [Config]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取
 */
router.get('/:key', authenticate as any, systemConfigController.getConfigByKey);

router.get('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST]), systemConfigController.getAllConfigs);
router.post('/', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN]) as any, systemConfigController.updateConfigs);

export default router;
