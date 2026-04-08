import { Router } from 'express';
import * as bookingController from '../../controllers/booking.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = Router();

router.get('/', authenticate as any, authorize(['admin', 'staff', 'system']), bookingController.get);
router.get('/:id', authenticate as any, authorize(['admin', 'staff', 'system']), bookingController.getById);
router.post('/', authenticate as any, authorize(['admin', 'staff', 'system']), bookingController.create);
router.put('/:id/confirm', authenticate as any, authorize(['admin', 'staff', 'system']), bookingController.confirm);
router.put('/:id/checkin', authenticate as any, authorize(['admin', 'staff', 'system']), bookingController.checkin);
router.put('/:id/checkout', authenticate as any, authorize(['admin', 'staff', 'system']), bookingController.checkout);
router.put('/:id/cancel', authenticate as any, authorize(['admin', 'staff', 'system']), bookingController.cancel);

export default router;