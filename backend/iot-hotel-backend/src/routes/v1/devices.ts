import { Router } from 'express';
import deviceController from '../../controllers/device.controller';
import { authenticate, authorize } from '../../middleware/auth';

const router = Router();

/**
 * @route   POST /api/v1/devices/register
 * @desc    硬件设备注册上报 (公开接口，但建议有签名机制)
 * @access  Public
 */
router.post('/register', deviceController.register);

/**
 * @route   GET /api/v1/devices
 * @desc    获取设备列表
 * @access  Private (Admin/Staff/System)
 */
router.get('/', authenticate as any, authorize(['admin', 'staff', 'system']), deviceController.getAll);

/**
 * @route   GET /api/v1/devices/:id
 * @desc    获取单个设备详情
 * @access  Private (Admin/Staff/System)
 */
router.get('/:id', authenticate as any, authorize(['admin', 'staff', 'system']), deviceController.getById);

/**
 * @route   PUT /api/v1/devices/:id/audit
 * @desc    设备审核与房间分配
 * @access  Private (Admin/System)
 */
router.put('/:id/audit', authenticate as any, authorize(['admin', 'system']), deviceController.audit);

/**
 * @route   DELETE /api/v1/devices/:id
 * @desc    删除设备
 * @access  Private (Admin/System)
 */
router.delete('/:id', authenticate as any, authorize(['admin', 'system']), deviceController.delete);

/**
 * @route   POST /api/v1/devices/:id/command
 * @desc    下发设备指令
 * @access  Private (Admin/Staff/System)
 */
router.post('/:id/command', authenticate as any, authorize(['admin', 'staff', 'system']), deviceController.sendCommand);

/**
 * @route   POST /api/v1/devices/room-card
 * @desc    发放/收回房卡
 * @access  Private (Admin/Staff)
 */
router.post('/room-card', authenticate as any, authorize(['admin', 'staff']), deviceController.handleRoomCard);

export default router;
