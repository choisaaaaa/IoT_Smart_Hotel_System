import { Router } from 'express';
import { get, getAll, create, remove, update, getStatistics } from '../../controllers/hotel.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

router.get('/', authenticate as any, get);
router.get('/all', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN]), getAll);
router.post('/', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN]), create);
router.delete('/:id', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN]), remove);
router.put('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), update);
router.get('/statistics', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), getStatistics);

export default router;
