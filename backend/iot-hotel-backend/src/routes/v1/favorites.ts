import { Router, Response } from 'express';
import { AuthRequest, successResponse, errorResponse } from '../../types';
import pool, { RowDataPacket, ResultSetHeader } from '../../config/database';
import { authenticate } from '../../middleware/auth';
import logger from '../../utils/logger';

/**
 * @swagger
 * tags:
 *   name: Favorites
 *   description: 用户酒店收藏管理接口
 */

const router = Router();

/**
 * @swagger
 * /favorites:
 *   get:
 *     summary: 获取我的收藏列表
 *     tags: [Favorites]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: 成功获取
 *   post:
 *     summary: 添加酒店到收藏
 *     tags: [Favorites]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [hotel_id]
 *             properties:
 *               hotel_id: { type: integer }
 *     responses:
 *       200:
 *         description: 收藏成功
 */

// 需要认证的路由
const authenticatedRouter = Router();

authenticatedRouter.use(authenticate);

authenticatedRouter.get('/', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json(errorResponse('未登录'));
    }

    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT uf.*, h.hotel_name, h.hotel_address, h.hotel_star, h.hotel_phone,
              h.logo, h.description, h.city, h.location, h.star_rating,
              h.rating, h.review_count, h.image_url, h.hotel_code
       FROM user_favorites uf
       LEFT JOIN hotels h ON uf.hotel_id = h.id
       WHERE uf.user_id = ?
       ORDER BY uf.created_at DESC`,
      [userId]
    );

    const hotels = rows.map((row: any) => ({
      id: row.hotel_id,
      hotel_name: row.hotel_name,
      hotel_address: row.hotel_address,
      hotel_star: row.hotel_star,
      hotel_phone: row.hotel_phone,
      logo: row.logo,
      description: row.description,
      city: row.city,
      location: row.location,
      star_rating: row.star_rating,
      rating: row.rating,
      review_count: row.review_count,
      image_url: row.image_url,
      hotel_code: row.hotel_code,
      favorited_at: row.created_at,
    }));

    return res.json(successResponse(hotels, '获取收藏列表成功'));
  } catch (error: any) {
    logger.error('获取收藏列表失败:', error.message);
    return res.status(500).json(errorResponse('获取收藏列表失败'));
  }
});

authenticatedRouter.post('/', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json(errorResponse('未登录'));
    }

    const { hotel_id } = req.body;
    if (!hotel_id) {
      return res.status(400).json(errorResponse('缺少酒店ID'));
    }

    const [hotelRows] = await pool.query<RowDataPacket[]>(
      'SELECT id FROM hotels WHERE id = ?',
      [hotel_id]
    );
    if (hotelRows.length === 0) {
      return res.status(404).json(errorResponse('酒店不存在'));
    }

    const [existing] = await pool.query<RowDataPacket[]>(
      'SELECT id FROM user_favorites WHERE user_id = ? AND hotel_id = ?',
      [userId, hotel_id]
    );
    if (existing.length > 0) {
      return res.json(successResponse(null, '已收藏该酒店'));
    }

    const [result] = await pool.query<ResultSetHeader>(
      'INSERT INTO user_favorites (user_id, hotel_id) VALUES (?, ?)',
      [userId, hotel_id]
    );

    return res.json(successResponse({ id: result.insertId, hotel_id }, '收藏成功'));
  } catch (error: any) {
    logger.error('添加收藏失败:', error.message);
    return res.status(500).json(errorResponse('添加收藏失败'));
  }
});

/**
 * @swagger
 * /favorites/{hotelId}:
 *   delete:
 *     summary: 取消收藏酒店
 *     tags: [Favorites]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: hotelId
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: 取消成功
 */
authenticatedRouter.delete('/:hotelId', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json(errorResponse('未登录'));
    }

    const hotelId = req.params.hotelId;

    const [result] = await pool.query<ResultSetHeader>(
      'DELETE FROM user_favorites WHERE user_id = ? AND hotel_id = ?',
      [userId, hotelId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json(errorResponse('未找到该收藏记录'));
    }

    return res.json(successResponse(null, '取消收藏成功'));
  } catch (error: any) {
    logger.error('取消收藏失败:', error.message);
    return res.status(500).json(errorResponse('取消收藏失败'));
  }
});

/**
 * @swagger
 * /favorites/check/{hotelId}:
 *   get:
 *     summary: 查询酒店是否已收藏
 *     tags: [Favorites]
 *     parameters:
 *       - in: path
 *         name: hotelId
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: 成功返回状态
 */
// 公开路由 - 游客也可访问
router.get('/check/:hotelId', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.id;
    // 游客模式：未登录用户默认未收藏
    if (!userId) {
      return res.json(successResponse({ is_favorite: false }, '查询成功'));
    }

    const hotelId = req.params.hotelId;

    const [rows] = await pool.query<RowDataPacket[]>(
      'SELECT id FROM user_favorites WHERE user_id = ? AND hotel_id = ?',
      [userId, hotelId]
    );

    return res.json(successResponse({ is_favorite: rows.length > 0 }, '查询成功'));
  } catch (error: any) {
    logger.error('查询收藏状态失败:', error.message);
    return res.status(500).json(errorResponse('查询收藏状态失败'));
  }
});

// 合并路由
router.use(authenticatedRouter);

export default router;
