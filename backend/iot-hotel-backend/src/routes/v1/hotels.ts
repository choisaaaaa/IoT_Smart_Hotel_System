import { Router } from 'express';
import {
  search,
  detail,
  getRoomAvailability,
  getHotelImages,
  addHotelImage,
  deleteHotelImage,
  updateHotelImage,
  updateHotel,
  getHotelDetailWithImages
} from '../../controllers/hotels.controller';
import { authenticate } from '../../middleware/auth';

const router = Router();

// 公开接口
router.get('/search', search);
router.get('/:id', detail);
router.get('/:hotelId/detail', getHotelDetailWithImages);
router.get('/:hotelId/images', getHotelImages);

// 需要登录的接口（选房和价格需要会员信息）
router.get('/:hotelId/rooms/availability', authenticate, getRoomAvailability);

// 酒店管理接口（需要酒店管理员或系统管理员权限）
router.put('/:hotelId', authenticate, updateHotel);
router.post('/:hotelId/images', authenticate, addHotelImage);
router.put('/:hotelId/images/:imageId', authenticate, updateHotelImage);
router.delete('/:hotelId/images/:imageId', authenticate, deleteHotelImage);

export default router;
