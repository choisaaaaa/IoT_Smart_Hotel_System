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

/**
 * @swagger
 * tags:
 *   name: Hotels
 *   description: 酒店管理接口
 */

const router = Router();

/**
 * @swagger
 * /hotels/search:
 *   get:
 *     summary: 搜索酒店列表
 *     tags: [Hotels]
 *     parameters:
 *       - in: query
 *         name: keyword
 *         schema:
 *           type: string
 *         description: 搜索关键字
 *     responses:
 *       200:
 *         description: 成功获取酒店列表
 */
router.get('/search', search);

/**
 * @swagger
 * /hotels/{id}:
 *   get:
 *     summary: 获取酒店基础详情
 *     tags: [Hotels]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: 成功获取酒店详情
 */
router.get('/:id', detail);

/**
 * @swagger
 * /hotels/{hotelId}/detail:
 *   get:
 *     summary: 获取酒店详情（包含图片）
 *     tags: [Hotels]
 *     parameters:
 *       - in: path
 *         name: hotelId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: 成功获取完整酒店详情
 */
router.get('/:hotelId/detail', getHotelDetailWithImages);

router.get('/:hotelId/images', getHotelImages);

// 房型可用性查询 - 游客也可访问
router.get('/:hotelId/rooms/availability', getRoomAvailability);

router.put('/:hotelId', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.HOTEL_ADMIN]), updateHotel);
router.post('/:hotelId/images', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.HOTEL_ADMIN]), addHotelImage);
router.put('/:hotelId/images/:imageId', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.HOTEL_ADMIN]), updateHotelImage);
router.delete('/:hotelId/images/:imageId', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.HOTEL_ADMIN]), deleteHotelImage);

export default router;
