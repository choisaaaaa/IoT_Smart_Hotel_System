import { Router } from 'express';
import { RoomTypeController } from '../../controllers/room-type.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = Router();

// 所有房型操作都需要认证，且管理员/员工/系统管理员可查看，仅管理员/系统管理员可修改
router.get('/', authenticate as any, authorize(['admin', 'staff', 'system']), RoomTypeController.getAllRoomTypes);
router.get('/:id', authenticate as any, authorize(['admin', 'staff', 'system']), RoomTypeController.getRoomTypeById);
router.post('/', authenticate as any, authorize(['admin', 'system']), RoomTypeController.createRoomType);
router.put('/:id', authenticate as any, authorize(['admin', 'system']), RoomTypeController.updateRoomType);
router.delete('/:id', authenticate as any, authorize(['admin', 'system']), RoomTypeController.deleteRoomType);

export default router;
