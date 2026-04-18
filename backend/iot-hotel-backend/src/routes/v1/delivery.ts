import { Router } from 'express';
import * as deliveryController from '../../controllers/delivery.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

const allRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST];
const staffRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN];

router.get('/', authenticate as any, deliveryController.get);
router.get('/:id', authenticate as any, deliveryController.getById);
router.post('/', authenticate as any, authorize(allRoles), deliveryController.create);
router.put('/:id/status', authenticate as any, authorize(staffRoles), deliveryController.updateStatus);
router.put('/:id/complete', authenticate as any, authorize(staffRoles), deliveryController.complete);

export default router;
