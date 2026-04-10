
import { Router } from 'express';
import * as priceController from '../../controllers/price-calendar.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = Router();

router.get('/', authenticate as any, priceController.getPriceCalendar);
router.post('/set', authenticate as any, authorize(['admin', 'manager', 'system']), priceController.setPriceCalendar);

export default router;
