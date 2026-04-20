import { Router } from 'express';
import * as guestController from '../../controllers/guest.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

router.get('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), guestController.get);
router.get('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), guestController.getById);
router.post('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), guestController.create);
router.put('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), guestController.update);
router.delete('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), guestController.remove);
router.get('/booking/:booking_id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), guestController.getByBookingId);

export default router;
