import { Router } from 'express';
import { get, update, getStatistics } from '../../controllers/hotel.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = Router();

router.get('/', authenticate as any, get);
router.put('/', authenticate as any, authorize(['admin', 'system']), update);
router.get('/statistics', authenticate as any, authorize(['admin', 'staff', 'manager', 'system']), getStatistics);

export default router;
