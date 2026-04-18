import { Router } from 'express';
import * as reviewController from '../../controllers/review.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

router.get('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), reviewController.get);
router.get('/my', authenticate as any, reviewController.getMyReviews);
router.get('/stats', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), reviewController.getStats);
router.get('/appeals', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), reviewController.getAppeals);
router.get('/:id', authenticate as any, reviewController.getById);
router.post('/', authenticate as any, reviewController.create);
router.put('/:id', authenticate as any, reviewController.update);
router.delete('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), reviewController.remove);
router.post('/:id/reply', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), reviewController.reply);
router.post('/appeals', authenticate as any, reviewController.createAppeal);
router.put('/appeals/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), reviewController.handleAppeal);

export default router;
