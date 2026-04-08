import { Router } from 'express';
import * as guestController from '../../controllers/frequent-guest.controller';
import { authenticate } from '../../middleware/auth';

const router = Router();

// 所有接口都需要登录
router.use(authenticate);

router.get('/', guestController.list);
router.post('/', guestController.create);
router.put('/:id', guestController.update);
router.delete('/:id', guestController.remove);

export default router;
