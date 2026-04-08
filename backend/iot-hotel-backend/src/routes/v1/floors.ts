import { Router } from 'express';
import { FloorController } from '../../controllers/floor.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = Router();

router.get('/', authenticate as any, authorize(['admin', 'staff', 'system']), FloorController.getAllFloors);
router.get('/:id', authenticate as any, authorize(['admin', 'staff', 'system']), FloorController.getFloorById);
router.post('/', authenticate as any, authorize(['admin', 'system']), FloorController.createFloor);
router.put('/:id', authenticate as any, authorize(['admin', 'system']), FloorController.updateFloor);
router.delete('/:id', authenticate as any, authorize(['admin', 'system']), FloorController.deleteFloor);

export default router;
