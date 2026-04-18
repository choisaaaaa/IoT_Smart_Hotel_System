import { Router } from 'express';
import * as couponController from '../../controllers/coupon.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

const allRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST];
const staffRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN];
const adminRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN];

router.get('/', authenticate as any, authorize(staffRoles), couponController.get);
router.get('/me', authenticate as any, couponController.getMe);
router.post('/import', authenticate as any, couponController.importCoupon);
router.post('/redeem', authenticate as any, authorize(staffRoles), couponController.redeemByCode);

router.post('/issue-to-user', authenticate as any, authorize(adminRoles), couponController.issueToUser);
router.get('/hotels', authenticate as any, couponController.getHotels);

router.get('/:id', authenticate as any, authorize(staffRoles), couponController.getById);
router.post('/', authenticate as any, authorize(adminRoles), couponController.create);
router.put('/:id', authenticate as any, authorize(adminRoles), couponController.update);
router.delete('/:id', authenticate as any, authorize(adminRoles), couponController.remove);
router.post('/:id/receive', authenticate as any, couponController.receive);
router.post('/:id/redeem', authenticate as any, authorize(staffRoles), couponController.redeemCoupon);

export default router;
