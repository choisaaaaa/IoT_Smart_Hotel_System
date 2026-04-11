import { Router } from 'express';
import * as bookingController from '../../controllers/booking.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = Router();

// 注意：POST 路由必须放在 GET 之前或确保不冲突
router.get('/lookup', bookingController.lookupForGuest);
router.get('/calculate-price', authenticate, bookingController.getCalculatedPrice);
router.post('/calculate-price', authenticate, bookingController.getCalculatedPrice);
router.post('/checkin-online/:id', bookingController.checkinOnline);
router.post('/:id/checkin-online', bookingController.checkinOnline);

router.post('/test', (req, res) => res.json({ message: 'test ok' }));
router.post('/', authenticate as any, authorize(['admin', 'staff', 'system', 'user']), bookingController.create);
router.get('/', authenticate as any, authorize(['admin', 'staff', 'system', 'user']), bookingController.get);
router.get('/:id', authenticate as any, authorize(['admin', 'staff', 'system', 'user']), bookingController.getById);

router.put('/:id/confirm', authenticate as any, authorize(['admin', 'staff', 'system']), bookingController.confirm);
router.put('/:id/checkin', authenticate as any, authorize(['admin', 'staff', 'system']), bookingController.checkin);
router.put('/:id/reject-pre-checkin', authenticate as any, authorize(['admin', 'staff', 'system']), bookingController.rejectPreCheckin);
router.put('/:id/checkout', authenticate as any, authorize(['admin', 'staff', 'system', 'user']), bookingController.checkout);
router.put('/:id/cancel', authenticate as any, authorize(['admin', 'staff', 'system', 'user']), bookingController.cancel);
router.put('/:id/extend', authenticate as any, authorize(['admin', 'staff', 'system', 'user']), bookingController.extendStay);
router.patch('/:id/status', authenticate as any, authorize(['admin', 'staff', 'system']), bookingController.updateStatus);

export default router;
