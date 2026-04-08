import { Router } from 'express';
import * as paymentController from '../../controllers/payment.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = Router();

router.get('/', authenticate as any, authorize(['admin', 'staff', 'system']), paymentController.get);
router.get('/:id', authenticate as any, authorize(['admin', 'staff', 'system']), paymentController.getById);
router.post('/', authenticate as any, paymentController.create);
router.put('/:id/pay', authenticate as any, paymentController.pay);

export default router;