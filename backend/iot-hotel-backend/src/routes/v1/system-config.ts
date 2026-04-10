import express from 'express';
import * as systemConfigController from '../../controllers/system-config.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = express.Router();

// 公开接口：获取特定配置
router.get('/:key', systemConfigController.getConfigByKey);

// 管理接口：获取所有配置
router.get('/', authenticate as any, authorize(['system']) as any, systemConfigController.getAllConfigs);

// 管理接口：更新配置
router.post('/', authenticate as any, authorize(['system']) as any, systemConfigController.updateConfigs);

export default router;
