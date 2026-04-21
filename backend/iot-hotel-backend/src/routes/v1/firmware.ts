import { Router } from 'express';
import firmwareController from '../../controllers/firmware.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

const adminRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN];
const allRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN];

// 需要认证的路由
router.get('/updates', authenticate as any, authorize(allRoles), firmwareController.getAll);
router.get('/updates/:id', authenticate as any, authorize(allRoles), firmwareController.getById);
router.post('/updates', authenticate as any, authorize(adminRoles), firmwareController.create);
router.post('/updates/:id/cancel', authenticate as any, authorize(adminRoles), firmwareController.cancel);

// 设备端调用
router.post('/progress', firmwareController.reportProgress);

export default router;
