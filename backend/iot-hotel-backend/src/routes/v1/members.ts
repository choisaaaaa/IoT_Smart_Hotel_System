import { Router } from 'express';
import * as memberController from '../../controllers/member.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = Router();

router.get('/', authenticate as any, authorize(['admin', 'staff', 'system', 'user']), memberController.get);
router.get('/me', authenticate as any, memberController.getMe);
router.get('/status', authenticate as any, memberController.getStatus);
router.get('/discounts', memberController.getLevelDiscounts);
router.put('/discounts', authenticate as any, authorize(['system']), memberController.updateLevelDiscounts);
router.post('/checkin', authenticate as any, memberController.checkin);
router.get('/:id', authenticate as any, authorize(['admin', 'staff', 'system']), memberController.getById);
router.post('/', authenticate as any, authorize(['admin', 'system']), memberController.create);
router.put('/:id', authenticate as any, authorize(['admin', 'system']), memberController.update);
router.post('/login', memberController.login);

export default router;
