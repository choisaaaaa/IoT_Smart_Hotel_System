import { Router } from 'express';
import * as paymentController from '../../controllers/payment.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

const allRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST];
const staffRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN];

router.get('/stats/revenue', authenticate as any, authorize(staffRoles), paymentController.getRevenueStats);
router.get('/', authenticate as any, authorize(staffRoles), paymentController.get);
router.get('/:id', authenticate as any, authorize(staffRoles), paymentController.getById);
router.post('/', authenticate as any, authorize(allRoles), paymentController.create);
router.put('/:id/pay', authenticate as any, paymentController.pay);

export default router;
