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
import { authenticate, authorize } from '../../middleware/auth';
import { CANONICAL_ROLES } from '../../utils/role';

const router = Router();

router.get('/search', search);
router.get('/:id', detail);
router.get('/:hotelId/detail', getHotelDetailWithImages);
router.get('/:hotelId/images', getHotelImages);

router.get('/:hotelId/rooms/availability', authenticate, getRoomAvailability);

router.put('/:hotelId', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.HOTEL_ADMIN]), updateHotel);
router.post('/:hotelId/images', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.HOTEL_ADMIN]), addHotelImage);
router.put('/:hotelId/images/:imageId', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.HOTEL_ADMIN]), updateHotelImage);
router.delete('/:hotelId/images/:imageId', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.HOTEL_ADMIN]), deleteHotelImage);

export default router;
