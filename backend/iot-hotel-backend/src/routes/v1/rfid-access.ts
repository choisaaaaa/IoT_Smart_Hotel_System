import { Router } from 'express';
import rfidAccessController from '../../controllers/rfid-access.controller';
import { authenticate, authorize, deviceAuthMiddleware } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

const allRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN];

// 需要认证的路由
router.get('/logs', authenticate as any, authorize(allRoles), rfidAccessController.getAll);
router.get('/logs/stats', authenticate as any, authorize(allRoles), rfidAccessController.getStats);

// 设备端调用（使用设备密钥认证 - S-03安全加固）
router.post('/logs', deviceAuthMiddleware as any, rfidAccessController.create);
router.post('/verify', deviceAuthMiddleware as any, rfidAccessController.verify);

export default router;
