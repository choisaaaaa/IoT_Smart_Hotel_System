import { Router } from 'express';
import * as couponController from '../../controllers/coupon.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = Router();

router.get('/', authenticate as any, couponController.get);
router.get('/me', authenticate as any, couponController.getMe);
router.post('/import', authenticate as any, couponController.importCoupon);

router.post('/issue-to-user', authenticate as any, authorize(['admin', 'system']), couponController.issueToUser);
router.get('/hotels', authenticate as any, couponController.getHotels);

router.get('/:id', authenticate as any, couponController.getById);
router.post('/', authenticate as any, authorize(['admin', 'system']), couponController.create);
router.put('/:id', authenticate as any, authorize(['admin', 'system']), couponController.update);
router.delete('/:id', authenticate as any, authorize(['admin', 'system']), couponController.remove);
router.post('/:id/receive', authenticate as any, couponController.receive);
router.post('/:id/redeem', authenticate as any, authorize(['staff', 'admin', 'system']), couponController.redeemCoupon);

export default router;
