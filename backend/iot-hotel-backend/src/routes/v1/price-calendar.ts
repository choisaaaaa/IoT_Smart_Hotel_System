import { Router } from 'express';
import * as priceController from '../../controllers/price-calendar.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

router.get('/', authenticate as any, priceController.getPriceCalendar);
router.post('/set', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), priceController.setPriceCalendar);

export default router;
