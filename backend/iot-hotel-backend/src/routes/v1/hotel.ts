import { Router } from 'express';
import { get, getAll, create, update, remove } from '../../controllers/hotel.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = Router();

// 管理员获取本酒店信息
router.get('/', authenticate as any, authorize(['admin', 'manager', 'receptionist', 'system']), get);

// 系统管理员获取所有酒店列表
router.get('/all', authenticate as any, authorize(['admin', 'system']), getAll);

// 系统管理员创建新酒店
router.post('/', authenticate as any, authorize(['admin', 'system']), create);

// 管理员更新酒店信息 (Manager 修改自己，Admin/System 修改指定)
router.put('/:id?', authenticate as any, authorize(['admin', 'manager', 'system']), update);

// 系统管理员删除酒店
router.delete('/:id', authenticate as any, authorize(['admin', 'system']), remove);

export default router;
