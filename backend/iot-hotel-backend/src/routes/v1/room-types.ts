import { Router } from 'express';
import { RoomTypeController } from '../../controllers/room-type.controller';
import { authenticate, authorize, optionalAuth } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

router.get('/', optionalAuth as any, RoomTypeController.getRoomTypes);
router.get('/:id', optionalAuth as any, RoomTypeController.getRoomTypeById);
router.post('/', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), RoomTypeController.createRoomType);
router.put('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), RoomTypeController.updateRoomType);
router.delete('/:id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.SYSTEM_ADMIN]), RoomTypeController.deleteRoomType);

export default router;
