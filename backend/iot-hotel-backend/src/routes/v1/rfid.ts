import { Router } from 'express';
import rfidController from '../../controllers/rfid.controller';
import { authenticate } from '../../middleware/auth';

const router = Router();

router.use(authenticate);

router.post('/issue', rfidController.issue);
router.get('/list', rfidController.getAll);
router.put('/status', rfidController.updateStatus);

export default router;
