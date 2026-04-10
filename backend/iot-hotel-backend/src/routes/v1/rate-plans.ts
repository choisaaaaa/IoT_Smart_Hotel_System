
import { Router } from 'express';
import * as ratePlanController from '../../controllers/rate-plan.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = Router();

router.get('/', authenticate as any, ratePlanController.getRatePlans);
router.post('/', authenticate as any, authorize(['admin', 'staff', 'system']), ratePlanController.createRatePlan);
router.put('/:id', authenticate as any, authorize(['admin', 'staff', 'system']), ratePlanController.updateRatePlan);
router.delete('/:id', authenticate as any, authorize(['admin', 'staff', 'system']), ratePlanController.deleteRatePlan);

export default router;
