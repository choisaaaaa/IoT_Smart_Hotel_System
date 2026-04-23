import { Router } from 'express';
import { get, getAll, create, remove, update, getStatistics } from '../../controllers/hotel.controller';
import { getReports } from '../../controllers/report.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

// 获取酒店信息 - 允许游客访问以便展示 Logo 和名称
router.get('/', get as any);
router.get('/all', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.HOTEL_ADMIN]), getAll);
router.post('/', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN]), create);
router.delete('/:id', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN]), remove);
router.put('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), update);
router.get('/statistics', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), getStatistics);
router.get('/reports', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.STAFF]), getReports);

export default router;
