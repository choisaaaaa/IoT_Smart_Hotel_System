import { Router } from 'express';
import * as messageController from '../../controllers/message.controller';
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

router.post('/', authenticate as any, messageController.sendMessage);

router.get('/', authenticate as any, messageController.getMessages);

router.get('/unread-count', authenticate as any, messageController.getUnreadCount);

router.get('/conversations', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), messageController.getRoomConversations);

router.put('/:id/read', authenticate as any, messageController.markAsRead);

router.put('/read-all', authenticate as any, messageController.markAllAsRead);

router.delete('/:id', authenticate as any, messageController.deleteMessage);

router.delete('/room/:room_id', authenticate as any, authorize([CANONICAL_ROLES.HOTEL_ADMIN, CANONICAL_ROLES.STAFF, CANONICAL_ROLES.SYSTEM_ADMIN]), messageController.deleteRoomMessages);

export default router;
