import { Router } from 'express';
import * as maintenanceController from '../../controllers/maintenance.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = Router();

router.get('/', authenticate as any, authorize(['admin', 'staff', 'system']), maintenanceController.get);
router.get('/:id', authenticate as any, authorize(['admin', 'staff', 'system']), maintenanceController.getById);
router.post('/', authenticate as any, authorize(['admin', 'staff', 'system']), maintenanceController.create);
router.put('/:id/assign', authenticate as any, authorize(['admin', 'staff', 'system']), maintenanceController.assign);
router.put('/:id/complete', authenticate as any, authorize(['admin', 'staff', 'system']), maintenanceController.complete);
router.delete('/:id', authenticate as any, authorize(['admin', 'staff', 'system']), maintenanceController.remove);

export default router;