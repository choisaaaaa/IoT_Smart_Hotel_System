import { Router } from 'express';
import * as reviewController from '../../controllers/review.controller';
import { authenticate } from '../../middleware/auth';

const router = Router();

router.get('/', reviewController.get);
router.get('/my', authenticate as any, reviewController.getMyReviews);
router.get('/stats', reviewController.getStats);
router.get('/appeals', authenticate as any, reviewController.getAppeals);
router.get('/:id', reviewController.getById);
router.post('/', authenticate as any, reviewController.create);
router.put('/:id', authenticate as any, reviewController.update);
router.delete('/:id', authenticate as any, reviewController.remove);
router.post('/:id/reply', authenticate as any, reviewController.reply);
router.post('/appeals', authenticate as any, reviewController.createAppeal);
router.put('/appeals/:id', authenticate as any, reviewController.handleAppeal);

export default router;
