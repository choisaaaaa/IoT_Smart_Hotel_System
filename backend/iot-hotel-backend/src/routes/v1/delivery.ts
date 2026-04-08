import { Router } from 'express';
import * as deliveryController from '../../controllers/delivery.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = Router();

router.get('/', authenticate as any, authorize(['admin', 'staff', 'system']), deliveryController.get);
router.get('/:id', authenticate as any, authorize(['admin', 'staff', 'system']), deliveryController.getById);
router.post('/', authenticate as any, authorize(['admin', 'staff', 'system']), deliveryController.create);
router.put('/:id/complete', authenticate as any, authorize(['admin', 'staff', 'system']), deliveryController.complete);

export default router;