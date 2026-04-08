import { Router } from 'express';
import * as roomController from '../../controllers/room.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = Router();

router.get('/', authenticate as any, authorize(['admin', 'staff', 'system']), roomController.get);
router.get('/:id', authenticate as any, authorize(['admin', 'staff', 'system']), roomController.getById);
router.post('/', authenticate as any, authorize(['admin', 'system']), roomController.create);
router.put('/:id', authenticate as any, authorize(['admin', 'system']), roomController.update);
router.delete('/:id', authenticate as any, authorize(['admin', 'system']), roomController.remove);

export default router;