import { Router } from 'express';
import deviceAlarmController from '../../controllers/device-alarm.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

const adminRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN];
const allRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN];

router.use(authenticate as any);

router.get('/', authorize(allRoles), deviceAlarmController.getAll);
router.get('/stats', authorize(allRoles), deviceAlarmController.getStats);
router.get('/:id', authorize(allRoles), deviceAlarmController.getById);
router.put('/:id/handle', authorize(allRoles), deviceAlarmController.handle);
router.post('/', deviceAlarmController.create); // 设备端调用，使用设备密钥认证

export default router;
