import { Router } from 'express';
import * as maintenanceController from '../../controllers/maintenance.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

const allRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST];
const staffRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN];
const adminRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN];

router.get('/', authenticate as any, maintenanceController.get);
router.get('/:id', authenticate as any, maintenanceController.getById);
router.post('/', authenticate as any, authorize(allRoles), maintenanceController.create);
router.put('/:id/assign', authenticate as any, authorize(staffRoles), maintenanceController.assign);
router.put('/:id/status', authenticate as any, authorize(staffRoles), maintenanceController.updateStatus);
router.put('/:id/complete', authenticate as any, authorize(staffRoles), maintenanceController.complete);
router.delete('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), maintenanceController.remove);

export default router;
