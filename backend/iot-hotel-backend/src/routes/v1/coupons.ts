import { Router } from 'express';
import * as couponController from '../../controllers/coupon.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = Router();

router.get('/', authenticate as any, couponController.get);
router.get('/:id', authenticate as any, couponController.getById);
router.post('/', authenticate as any, authorize(['admin', 'system']), couponController.create);
router.put('/:id', authenticate as any, authorize(['admin', 'system']), couponController.update);
router.delete('/:id', authenticate as any, authorize(['admin', 'system']), couponController.remove);
router.post('/:id/receive', authenticate as any, couponController.receive);

export default router;