import { Router } from 'express';
import energyController from '../../controllers/energy.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

const allRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN];

// 需要认证的路由
router.get('/consumption', authenticate as any, authorize(allRoles), energyController.getConsumption);
router.get('/stats', authenticate as any, authorize(allRoles), energyController.getStats);
router.get('/ranking', authenticate as any, authorize(allRoles), energyController.getRanking);
router.get('/suggestions', authenticate as any, authorize(allRoles), energyController.getSuggestions);

// 设备端调用
router.post('/consumption', energyController.create);

export default router;
