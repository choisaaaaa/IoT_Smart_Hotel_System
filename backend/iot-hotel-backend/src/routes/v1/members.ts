import { Router } from 'express';
import * as memberController from '../../controllers/member.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

router.get('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER]), memberController.get);
router.get('/me', authenticate as any, memberController.getMe);
router.get('/status', authenticate as any, memberController.getStatus);
router.get('/discounts', memberController.getLevelDiscounts);
router.put('/discounts', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN]), memberController.updateLevelDiscounts);
router.post('/recharge', authenticate as any, memberController.rechargeBalance);
router.post('/checkin', authenticate as any, memberController.checkin);
router.post('/fix-schema', authenticate as any, memberController.fixDatabaseSchema);
router.get('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), memberController.getById);
router.post('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), memberController.create);
router.put('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), memberController.update);
router.post('/login', memberController.login);

export default router;
