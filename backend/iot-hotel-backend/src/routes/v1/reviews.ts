import { Router } from 'express';
import * as reviewController from '../../controllers/review.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = Router();

router.get('/', reviewController.get);
router.get('/:id', reviewController.getById);
router.post('/', authenticate as any, reviewController.create);

export default router;