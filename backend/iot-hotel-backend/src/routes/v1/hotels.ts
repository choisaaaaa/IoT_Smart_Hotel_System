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

/**
 * @swagger
 * /hotels/{hotelId}/images:
 *   get:
 *     summary: 获取酒店图片列表
 *     tags: [Hotels]
 *     parameters:
 *       - in: path
 *         name: hotelId
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 成功获取列表
 */
router.get('/:hotelId/images', getHotelImages);

/**
 * @swagger
 * /hotels/{hotelId}/rooms/availability:
 *   get:
 *     summary: 获取房型实时可用性
 *     tags: [Hotels]
 *     parameters:
 *       - in: path
 *         name: hotelId
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 成功获取
 */
// 房型可用性查询 - 游客也可访问
router.get('/:hotelId/rooms/availability', getRoomAvailability);

/**
 * @swagger
 * /hotels/{hotelId}:
 *   put:
 *     summary: 更新酒店信息（管理员）
 *     tags: [Hotels]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: hotelId
 *         required: true
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: 更新成功
 */
router.put('/:hotelId', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.HOTEL_ADMIN]), updateHotel);

/**
 * @swagger
 * /hotels/{hotelId}/images:
 *   post:
 *     summary: 添加酒店图片
 *     tags: [Hotels]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: hotelId
 *         required: true
 *         schema: { type: string }
 *     requestBody:
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               image: { type: string, format: binary }
 *     responses:
 *       200:
 *         description: 添加成功
 */
router.post('/:hotelId/images', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.HOTEL_ADMIN]), addHotelImage);

/**
 * @swagger
 * /hotels/{hotelId}/images/{imageId}:
 *   put:
 *     summary: 更新酒店图片信息
 *     tags: [Hotels]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: hotelId
 *         required: true
 *         schema: { type: string }
 *       - in: path
 *         name: imageId
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: 更新成功
 */
router.put('/:hotelId/images/:imageId', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.HOTEL_ADMIN]), updateHotelImage);

/**
 * @swagger
 * /hotels/{hotelId}/images/{imageId}:
 *   delete:
 *     summary: 删除酒店图片
 *     tags: [Hotels]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: hotelId
 *         required: true
 *         schema: { type: string }
 *       - in: path
 *         name: imageId
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: 删除成功
 */
router.delete('/:hotelId/images/:imageId', authenticate as any, authorize([CANONICAL_ROLES.SYSTEM_ADMIN, CANONICAL_ROLES.HOTEL_ADMIN]), deleteHotelImage);

export default router;
