import { Router } from 'express';
import irRemoteController from '../../controllers/ir-remote.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

const adminRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN];
const allRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN];

// 需要认证的路由
router.get('/codes', authenticate as any, authorize(allRoles), irRemoteController.getAll);
router.get('/codes/:id', authenticate as any, authorize(allRoles), irRemoteController.getById);
router.post('/codes', authenticate as any, authorize(adminRoles), irRemoteController.create);
router.put('/codes/:id', authenticate as any, authorize(adminRoles), irRemoteController.update);
router.delete('/codes/:id', authenticate as any, authorize(adminRoles), irRemoteController.delete);
router.post('/send', authenticate as any, authorize(allRoles), irRemoteController.send);
router.get('/brands', authenticate as any, authorize(allRoles), irRemoteController.getBrands);
router.get('/brands/:brand/functions', authenticate as any, authorize(allRoles), irRemoteController.getBrandFunctions);

// 设备端调用（使用设备密钥认证）
router.post('/learn/start', irRemoteController.startLearn);
router.post('/learn/complete', irRemoteController.completeLearn);

export default router;
