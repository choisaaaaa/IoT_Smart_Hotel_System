import { Router } from 'express';
import { search, detail, getRoomAvailability } from '../../controllers/hotels.controller';
import { authenticate } from '../../middleware/auth';

const router = Router();

// 公开接口
router.get('/search', search);
router.get('/:id', detail);

// 需要登录的接口（选房和价格需要会员信息）
router.get('/:hotelId/rooms/availability', authenticate, getRoomAvailability);

export default router;
