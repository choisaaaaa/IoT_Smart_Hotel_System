import { Router } from 'express';
import * as callController from '../../controllers/call.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

router.post('/initiate', authenticate as any, callController.initiateCall);
router.post('/outbound', authenticate as any, callController.outboundCall);
router.post('/:call_id/answer', authenticate as any, callController.answerCall);
router.post('/:call_id/reject', authenticate as any, callController.rejectCall);
router.post('/:call_id/hangup', authenticate as any, callController.hangupCall);
router.get('/:call_id/status', authenticate as any, callController.getCallStatus);
router.get('/active', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), callController.getActiveCalls);
router.get('/history', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), callController.getCallHistory);
router.get('/stats', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), callController.getCallStats);

export default router;
