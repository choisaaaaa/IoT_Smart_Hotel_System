import { Router } from 'express';
import deviceController from '../../controllers/device.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

const allRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST];
const adminRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN];

router.post('/register', deviceController.register);
router.post('/room-card', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF]), deviceController.handleRoomCard);
router.get('/', authenticate as any, authorize(allRoles), deviceController.getAll);
router.get('/:id', authenticate as any, authorize(allRoles), deviceController.getById);
router.put('/:id/audit', authenticate as any, authorize(adminRoles), deviceController.audit);
router.delete('/:id', authenticate as any, authorize(adminRoles), deviceController.delete);
router.post('/:id/command', authenticate as any, authorize(allRoles), deviceController.sendCommand);

export default router;
