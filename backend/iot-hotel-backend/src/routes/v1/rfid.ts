import { Router } from 'express';
import rfidController from '../../controllers/rfid.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

router.use(authenticate);

router.post('/issue', authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), rfidController.issue);
router.get('/list', authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), rfidController.getAll);
router.put('/status', authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), rfidController.updateStatus);

export default router;
