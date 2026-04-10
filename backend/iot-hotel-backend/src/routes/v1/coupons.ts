import { Router } from 'express';
import * as couponController from '../../controllers/coupon.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = Router();

router.get('/', authenticate as any, couponController.get);
router.get('/me', authenticate as any, couponController.getMe);
router.post('/import', authenticate as any, couponController.importCoupon);
router.post('/issue-to-user', authenticate as any, authorize(['admin', 'staff', 'system']), couponController.issueToUser);
router.get('/:id', authenticate as any, couponController.getById);
router.post('/', authenticate as any, authorize(['admin', 'system', 'staff']), couponController.create);
router.put('/:id', authenticate as any, authorize(['admin', 'system', 'staff']), couponController.update);
router.delete('/:id', authenticate as any, authorize(['admin', 'system', 'staff']), couponController.remove);
router.post('/:id/receive', authenticate as any, couponController.receive);

export default router;
