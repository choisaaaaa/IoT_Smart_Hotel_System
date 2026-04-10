import { Router } from 'express';
import * as roomController from '../../controllers/room.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = Router();

// 顾客端接口 - 允许user角色访问自己的房间信息
router.get('/guest/my-room', authenticate as any, authorize(['user', 'admin', 'manager', 'staff', 'receptionist', 'system']), roomController.getGuestRoom);
router.get('/guest/:id/devices', authenticate as any, authorize(['user', 'admin', 'manager', 'staff', 'receptionist', 'system']), roomController.getGuestRoomDevices);

router.get('/', authenticate as any, authorize(['admin', 'manager', 'staff', 'receptionist', 'system']), roomController.get);
router.get('/:id', authenticate as any, authorize(['admin', 'manager', 'staff', 'receptionist', 'system']), roomController.getById);
router.post('/', authenticate as any, authorize(['admin', 'manager', 'system']), roomController.create);
router.put('/:id', authenticate as any, authorize(['admin', 'manager', 'system']), roomController.update);
router.patch('/:id/status', authenticate as any, authorize(['admin', 'manager', 'staff', 'receptionist', 'system']), roomController.updateStatus);
router.delete('/:id', authenticate as any, authorize(['admin', 'manager', 'system']), roomController.remove);

export default router;