import { Router } from 'express';
import deviceGroupController from '../../controllers/device-group.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

const adminRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN];
const allRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN];

router.use(authenticate as any);

router.get('/', authorize(allRoles), deviceGroupController.getAll);
router.post('/', authorize(adminRoles), deviceGroupController.create);
router.put('/:id', authorize(adminRoles), deviceGroupController.update);
router.delete('/:id', authorize(adminRoles), deviceGroupController.delete);
router.post('/:id/devices', authorize(adminRoles), deviceGroupController.addDevices);
router.delete('/:id/devices/:device_id', authorize(adminRoles), deviceGroupController.removeDevice);
router.post('/:id/command', authorize(allRoles), deviceGroupController.sendCommand);

export default router;
