import { Router } from 'express';
import * as reviewController from '../../controllers/review.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

const allRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.CUSTOMER, CANONICAL_ROLES.GUEST];
const staffRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN];
const adminRoles = [CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN];

router.get('/', reviewController.get);
router.get('/my', authenticate as any, reviewController.getMyReviews);
router.get('/stats', authenticate as any, authorize(staffRoles), reviewController.getStats);
router.get('/appeals', authenticate as any, authorize(staffRoles), reviewController.getAppeals);
router.get('/:id', reviewController.getById);
router.post('/', authenticate as any, reviewController.create);
router.put('/:id', authenticate as any, reviewController.update);
router.delete('/:id', authenticate as any, reviewController.remove);
router.post('/:id/reply', authenticate as any, authorize(staffRoles), reviewController.reply);
router.post('/appeals', authenticate as any, reviewController.createAppeal);
router.put('/appeals/:id', authenticate as any, authorize(adminRoles), reviewController.handleAppeal);

export default router;
