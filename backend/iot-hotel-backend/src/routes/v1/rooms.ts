import { Router } from 'express';
import * as roomController from '../../controllers/room.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = Router();

// 调试：打印路由注册信息
console.log('[Rooms Router] 开始注册路由...');

// 顾客端接口 - 允许user角色访问自己的房间信息
router.get('/guest/my-room', authenticate as any, authorize(['user', 'admin', 'manager', 'staff', 'receptionist', 'system']), roomController.getGuestRoom);
router.get('/guest/:id/devices', authenticate as any, authorize(['user', 'admin', 'manager', 'staff', 'receptionist', 'system']), roomController.getGuestRoomDevices);

// 具体路由必须在参数化路由之前定义
router.get('/', authenticate as any, authorize(['admin', 'manager', 'staff', 'receptionist', 'system']), roomController.get);
router.post('/', authenticate as any, authorize(['admin', 'manager', 'system']), roomController.create);

// PATCH /:id/status 必须在 /:id 之前定义，否则会被 /:id 捕获
router.patch('/:id/status', authenticate as any, authorize(['admin', 'manager', 'staff', 'receptionist', 'system']), roomController.updateStatus);
router.put('/:id/status', authenticate as any, authorize(['admin', 'manager', 'staff', 'receptionist', 'system']), roomController.updateStatus);
console.log('[Rooms Router] 已注册 PATCH/PUT /:id/status');

router.get('/:id', authenticate as any, authorize(['admin', 'manager', 'staff', 'receptionist', 'system']), roomController.getById);
router.put('/:id', authenticate as any, authorize(['admin', 'manager', 'system']), roomController.update);
router.delete('/:id', authenticate as any, authorize(['admin', 'manager', 'system']), roomController.remove);

// 打印所有已注册的路由
console.log('[Rooms Router] 路由注册完成');
console.log('[Rooms Router] 已注册的路由:');
(router as any).stack.forEach((layer: any) => {
  if (layer.route) {
    const methods = Object.keys(layer.route.methods).join(', ').toUpperCase();
    console.log(`  ${methods} ${layer.route.path}`);
  }
});

export default router;
