import { Router } from 'express';
import { list, detail, create, update, remove, updatePassword, updateProfile, sendVerificationCode, authorizeManager, lock, unlock } from '../../controllers/user.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

router.post('/send-code', sendVerificationCode);
router.put('/profile', authenticate as any, updateProfile);
router.post('/authorize-manager', authenticate as any, authorizeManager);
router.get('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.STAFF]), list);
router.get('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.STAFF]), detail);
router.post('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), create);
router.put('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), update);
router.delete('/:id', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN]), remove);
router.put('/:id/password', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), updatePassword);
router.post('/:id/lock', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN]), lock);
router.post('/:id/unlock', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), unlock);

export default router;
