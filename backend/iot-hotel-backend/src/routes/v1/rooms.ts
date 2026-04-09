import { Router } from 'express';
import * as roomController from '../../controllers/room.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = Router();

router.get('/', authenticate as any, authorize(['admin', 'manager', 'receptionist', 'system']), roomController.get);
router.get('/:id', authenticate as any, authorize(['admin', 'manager', 'receptionist', 'system']), roomController.getById);
router.post('/', authenticate as any, authorize(['admin', 'manager', 'system']), roomController.create);
router.put('/:id', authenticate as any, authorize(['admin', 'manager', 'system']), roomController.update);
router.patch('/:id/status', authenticate as any, authorize(['admin', 'manager', 'receptionist', 'system']), roomController.updateStatus);
router.delete('/:id', authenticate as any, authorize(['admin', 'manager', 'system']), roomController.remove);

export default router;