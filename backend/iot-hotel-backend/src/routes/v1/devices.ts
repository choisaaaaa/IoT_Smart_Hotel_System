import { Router } from 'express';
import deviceController from '../../controllers/device.controller';
import { authenticate, authorize, deviceAuthMiddleware, optionalDeviceAuthMiddleware } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

const adminRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN];
const allRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN];

// 设备注册接口 - 支持两种认证方式 (H-01安全加固)
// 方式1: 设备预注册Token认证 (新设备)
// 方式2: 管理员认证 (手动注册)
router.post('/register', optionalDeviceAuthMiddleware as any, deviceController.register);
router.post('/room-card', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF]), deviceController.handleRoomCard);
router.get('/', authenticate as any, authorize(allRoles), deviceController.getAll);
router.get('/:id', authenticate as any, authorize(allRoles), deviceController.getById);
router.put('/:id/audit', authenticate as any, authorize(adminRoles), deviceController.audit);
router.delete('/:id', authenticate as any, authorize(adminRoles), deviceController.delete);
router.post('/:id/command', authenticate as any, authorize(allRoles), deviceController.sendCommand);
router.get('/:id/sensor-data', authenticate as any, authorize(allRoles), deviceController.getSensorData);
router.get('/:id/sensor-data/latest', authenticate as any, authorize(allRoles), deviceController.getLatestSensorData);
router.get('/:id/commands', authenticate as any, authorize(allRoles), deviceController.getCommandHistory);

export default router;
