import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { isSystemAdmin, isHotelAdmin, isCustomer, isStaff } from '../utils/role';

export const get = async (req: AuthRequest, res: Response) => {
  try {
    const { page = 1, pageSize = 10, hotel_id, user_id } = req.query;
    const offset = (Number(page) - 1) * Number(pageSize);

    let whereClause = 'WHERE r.is_deleted = 0';
    const params: any[] = [];

    if (hotel_id) {
      whereClause += ' AND r.hotel_id = ?';
      params.push(Number(hotel_id));
    }

    if (user_id) {
      whereClause += ' AND r.user_id = ?';
      params.push(Number(user_id));
    }

    const [totalRows] = await pool.query<RowDataPacket[]>(
      `SELECT COUNT(*) as total FROM reviews r ${whereClause}`,
      params
    );
    const total = (totalRows[0] as any).total;

    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT r.*, m.name as member_name, m.phone as member_phone,
        h.hotel_name, rt.name as room_type_name,
        u.avatar as user_avatar
      FROM reviews r
      LEFT JOIN members m ON r.member_id = m.id
      LEFT JOIN users u ON r.user_id = u.id
      LEFT JOIN hotels h ON r.hotel_id = h.id
      LEFT JOIN room_types rt ON r.room_type_id = rt.id
      ${whereClause} ORDER BY r.id DESC LIMIT ? OFFSET ?`,
      [...params, Number(pageSize), offset]
    );

    res.json(successResponse({
      list: rows,
      total,
      page: Number(page),
      pageSize: Number(pageSize),
      totalPages: Math.ceil(total / Number(pageSize))
    }, '获取评价列表成功'));
  } catch (error: any) {
    logger.error('获取评价列表失败:', error.message);
    res.status(500).json(errorResponse('获取评价列表失败'));
  }
};

export const getById = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;

    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT r.*, m.name as member_name, m.phone as member_phone,
        h.hotel_name, rt.name as room_type_name,
        u.avatar as user_avatar
      FROM reviews r
      LEFT JOIN members m ON r.member_id = m.id
      LEFT JOIN users u ON r.user_id = u.id
      LEFT JOIN hotels h ON r.hotel_id = h.id
      LEFT JOIN room_types rt ON r.room_type_id = rt.id
      WHERE r.id = ? AND r.is_deleted = 0`,
      [id]
    );

    if (rows.length === 0) {
      res.status(404).json(errorResponse('评价不存在'));
      return;
    }

    res.json(successResponse(rows[0], '获取评价详情成功'));
  } catch (error: any) {
    logger.error('获取评价详情失败:', error.message);
    res.status(500).json(errorResponse('获取评价详情失败'));
  }
};

export const create = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.id;
    const userRole = req.user?.role;
    const userPhone = req.user?.phone || req.user?.username;

    if (!userId) {
      return res.status(401).json(errorResponse('请先登录'));
    }

    const {
      order_id,
      hotel_id,
      room_type_id,
      score,
      environment_rating,
      facility_rating,
      comfort_rating,
      content,
      photos
    } = req.body;

    if (!order_id) {
      return res.status(400).json(errorResponse('缺少订单ID'));
    }
    if (!score || score < 1 || score > 5) {
      return res.status(400).json(errorResponse('评分需在1-5之间'));
    }
    if (!content || content.trim().length === 0) {
      return res.status(400).json(errorResponse('请填写评价内容'));
    }

    const [existingReviews] = await pool.query<RowDataPacket[]>(
      'SELECT id FROM reviews WHERE order_id = ? AND is_deleted = 0',
      [order_id]
    );
    if (existingReviews.length > 0) {
      return res.status(400).json(errorResponse('该订单已评价，不能重复评价'));
    }

    const [bookings] = await pool.query<RowDataPacket[]>(
      'SELECT id, user_id, hotel_id, room_type_id, status FROM bookings WHERE id = ?',
      [order_id]
    );
    if (bookings.length === 0) {
      return res.status(404).json(errorResponse('订单不存在'));
    }

    const booking = bookings[0];
    if (booking.status !== 'checked_out') {
      return res.status(400).json(errorResponse('只有已退房的订单才能评价'));
    }

    if (isCustomer(userRole) && booking.user_id !== userId) {
      return res.status(403).json(errorResponse('只能评价自己的订单'));
    }

    let memberId = null;
    if (userPhone) {
      const [members] = await pool.query<RowDataPacket[]>(
        'SELECT id FROM members WHERE phone = ?',
        [userPhone]
      );
      if (members.length > 0) {
        memberId = members[0].id;
      }
    }

    const finalHotelId = hotel_id || booking.hotel_id;
    const finalRoomTypeId = room_type_id || booking.room_type_id;

    const [result] = await pool.query<ResultSetHeader>(
      `INSERT INTO reviews (order_id, order_type, member_id, hotel_id, room_type_id, user_id, score, environment_rating, facility_rating, comfort_rating, content, photos)
       VALUES (?, 'booking', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        order_id,
        memberId,
        finalHotelId,
        finalRoomTypeId,
        userId,
        score,
        environment_rating || 5,
        facility_rating || 5,
        comfort_rating || 5,
        content.trim(),
        JSON.stringify(photos || [])
      ]
    );

    await updateHotelRating(finalHotelId);

    res.json(successResponse({ id: result.insertId }, '评价提交成功'));
  } catch (error: any) {
    logger.error('创建评价失败:', error.message);
    res.status(500).json(errorResponse('创建评价失败'));
  }
};

export const update = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const userId = req.user?.id;
    const { score, environment_rating, facility_rating, comfort_rating, content, photos } = req.body;

    const [rows] = await pool.query<RowDataPacket[]>(
      'SELECT * FROM reviews WHERE id = ? AND is_deleted = 0',
      [id]
    );
    if (rows.length === 0) {
      return res.status(404).json(errorResponse('评价不存在'));
    }

    const review = rows[0];
    if (review.user_id !== userId && !isSystemAdmin(req.user?.role)) {
      return res.status(403).json(errorResponse('无权修改此评价'));
    }

    const photosValue = photos != null ? JSON.stringify(photos) : (typeof review.photos === 'string' ? review.photos : JSON.stringify(review.photos || []));

    await pool.query(
      `UPDATE reviews SET score = ?, environment_rating = ?, facility_rating = ?, comfort_rating = ?, content = ?, photos = ? WHERE id = ?`,
      [
        score ?? review.score,
        environment_rating ?? review.environment_rating,
        facility_rating ?? review.facility_rating,
        comfort_rating ?? review.comfort_rating,
        content?.trim() ?? review.content,
        photosValue,
        id
      ]
    );

    await updateHotelRating(review.hotel_id);

    res.json(successResponse(null, '评价修改成功'));
  } catch (error: any) {
    logger.error('修改评价失败:', error);
    res.status(500).json(errorResponse('修改评价失败'));
  }
};

export const remove = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const userId = req.user?.id;
    const userRole = req.user?.role;

    const [rows] = await pool.query<RowDataPacket[]>(
      'SELECT * FROM reviews WHERE id = ? AND is_deleted = 0',
      [id]
    );
    if (rows.length === 0) {
      return res.status(404).json(errorResponse('评价不存在'));
    }

    const review = rows[0];

    if (isCustomer(userRole)) {
      if (review.user_id !== userId) {
        return res.status(403).json(errorResponse('无权删除此评价'));
      }
    } else if (isSystemAdmin(userRole)) {
      // ok
    } else {
      return res.status(403).json(errorResponse('无权删除此评价'));
    }

    await pool.query('UPDATE reviews SET is_deleted = 1 WHERE id = ?', [id]);

    await updateHotelRating(review.hotel_id);

    res.json(successResponse(null, '评价删除成功'));
  } catch (error: any) {
    logger.error('删除评价失败:', error.message);
    res.status(500).json(errorResponse('删除评价失败'));
  }
};

export const getMyReviews = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json(errorResponse('请先登录'));
    }

    const { page = 1, pageSize = 10 } = req.query;
    const offset = (Number(page) - 1) * Number(pageSize);

    const [totalRows] = await pool.query<RowDataPacket[]>(
      'SELECT COUNT(*) as total FROM reviews WHERE user_id = ? AND is_deleted = 0',
      [userId]
    );
    const total = (totalRows[0] as any).total;

    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT r.*, h.hotel_name, rt.name as room_type_name
      FROM reviews r
      LEFT JOIN hotels h ON r.hotel_id = h.id
      LEFT JOIN room_types rt ON r.room_type_id = rt.id
      WHERE r.user_id = ? AND r.is_deleted = 0
      ORDER BY r.id DESC LIMIT ? OFFSET ?`,
      [userId, Number(pageSize), offset]
    );

    res.json(successResponse({
      list: rows,
      total,
      page: Number(page),
      pageSize: Number(pageSize),
      totalPages: Math.ceil(total / Number(pageSize))
    }, '获取我的评价成功'));
  } catch (error: any) {
    logger.error('获取我的评价失败:', error.message);
    res.status(500).json(errorResponse('获取我的评价失败'));
  }
};

export const getStats = async (req: AuthRequest, res: Response) => {
  try {
    const { hotel_id } = req.query;
    if (!hotel_id) {
      return res.status(400).json(errorResponse('缺少酒店ID'));
    }

    const [stats] = await pool.query<RowDataPacket[]>(
      `SELECT
        COUNT(*) as total_reviews,
        AVG(score) as avg_score,
        AVG(environment_rating) as avg_environment,
        AVG(facility_rating) as avg_facility,
        AVG(comfort_rating) as avg_comfort,
        SUM(CASE WHEN score >= 4 THEN 1 ELSE 0 END) as good_count,
        SUM(CASE WHEN score = 3 THEN 1 ELSE 0 END) as medium_count,
        SUM(CASE WHEN score <= 2 THEN 1 ELSE 0 END) as bad_count
      FROM reviews WHERE hotel_id = ? AND is_deleted = 0`,
      [Number(hotel_id)]
    );

    const [distribution] = await pool.query<RowDataPacket[]>(
      `SELECT score, COUNT(*) as count FROM reviews
      WHERE hotel_id = ? AND is_deleted = 0 GROUP BY score ORDER BY score DESC`,
      [Number(hotel_id)]
    );

    const stat = stats[0] as any;
    res.json(successResponse({
      total_reviews: stat.total_reviews || 0,
      avg_score: Number(stat.avg_score || 0).toFixed(1),
      avg_environment: Number(stat.avg_environment || 0).toFixed(1),
      avg_facility: Number(stat.avg_facility || 0).toFixed(1),
      avg_comfort: Number(stat.avg_comfort || 0).toFixed(1),
      good_count: stat.good_count || 0,
      medium_count: stat.medium_count || 0,
      bad_count: stat.bad_count || 0,
      distribution
    }, '获取评价统计成功'));
  } catch (error: any) {
    logger.error('获取评价统计失败:', error.message);
    res.status(500).json(errorResponse('获取评价统计失败'));
  }
};

export const reply = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { reply: replyContent } = req.body;
    const userRole = req.user?.role;

    if (!isHotelAdmin(userRole) && !isSystemAdmin(userRole) && !isStaff(userRole)) {
      return res.status(403).json(errorResponse('无权回复评价'));
    }

    if (!replyContent || replyContent.trim().length === 0) {
      return res.status(400).json(errorResponse('请填写回复内容'));
    }

    const [rows] = await pool.query<RowDataPacket[]>(
      'SELECT * FROM reviews WHERE id = ? AND is_deleted = 0',
      [id]
    );
    if (rows.length === 0) {
      return res.status(404).json(errorResponse('评价不存在'));
    }

    await pool.query(
      'UPDATE reviews SET reply = ?, replied_at = NOW() WHERE id = ?',
      [replyContent.trim(), id]
    );

    res.json(successResponse(null, '回复成功'));
  } catch (error: any) {
    logger.error('回复评价失败:', error.message);
    res.status(500).json(errorResponse('回复评价失败'));
  }
};

// ==================== 申诉相关 ====================

export const createAppeal = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.id;
    const userRole = req.user?.role;
    const { review_id, appeal_reason } = req.body;

    if (!isHotelAdmin(userRole) && !isStaff(userRole)) {
      return res.status(403).json(errorResponse('只有酒店管理员或前台可以申诉'));
    }

    if (!review_id || !appeal_reason || appeal_reason.trim().length === 0) {
      return res.status(400).json(errorResponse('缺少评价ID或申诉理由'));
    }

    const [reviews] = await pool.query<RowDataPacket[]>(
      'SELECT * FROM reviews WHERE id = ? AND is_deleted = 0',
      [review_id]
    );
    if (reviews.length === 0) {
      return res.status(404).json(errorResponse('评价不存在'));
    }

    const review = reviews[0];
    const hotelId = req.user?.hotel_id || review.hotel_id;

    const [existing] = await pool.query<RowDataPacket[]>(
      'SELECT id FROM review_appeals WHERE review_id = ? AND status = ?',
      [review_id, 'pending']
    );
    if (existing.length > 0) {
      return res.status(400).json(errorResponse('该评价已有待处理的申诉'));
    }

    const [result] = await pool.query<ResultSetHeader>(
      'INSERT INTO review_appeals (review_id, hotel_id, appellant_id, appeal_reason) VALUES (?, ?, ?, ?)',
      [review_id, hotelId, userId, appeal_reason.trim()]
    );

    res.json(successResponse({ id: result.insertId }, '申诉提交成功'));
  } catch (error: any) {
    logger.error('创建申诉失败:', error.message);
    res.status(500).json(errorResponse('创建申诉失败'));
  }
};

export const getAppeals = async (req: AuthRequest, res: Response) => {
  try {
    const { page = 1, pageSize = 10, hotel_id, status } = req.query;
    const offset = (Number(page) - 1) * Number(pageSize);
    const userRole = req.user?.role;
    const userHotelId = req.user?.hotel_id;

    let whereClause = 'WHERE 1=1';
    const params: any[] = [];

    if (hotel_id) {
      whereClause += ' AND a.hotel_id = ?';
      params.push(Number(hotel_id));
    } else if ((isHotelAdmin(userRole) || isStaff(userRole)) && userHotelId) {
      whereClause += ' AND a.hotel_id = ?';
      params.push(userHotelId);
    }

    if (status) {
      whereClause += ' AND a.status = ?';
      params.push(status);
    }

    const [totalRows] = await pool.query<RowDataPacket[]>(
      `SELECT COUNT(*) as total FROM review_appeals a ${whereClause}`,
      params
    );
    const total = (totalRows[0] as any).total;

    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT a.*, r.score, r.content as review_content, r.environment_rating, r.facility_rating, r.comfort_rating,
        r.member_name as reviewer_name, r.member_phone as reviewer_phone,
        h.hotel_name,
        u1.name as appellant_name,
        u2.name as handler_name
      FROM review_appeals a
      LEFT JOIN reviews r ON a.review_id = r.id
      LEFT JOIN hotels h ON a.hotel_id = h.id
      LEFT JOIN users u1 ON a.appellant_id = u1.id
      LEFT JOIN users u2 ON a.handler_id = u2.id
      ${whereClause} ORDER BY a.id DESC LIMIT ? OFFSET ?`,
      [...params, Number(pageSize), offset]
    );

    res.json(successResponse({
      list: rows,
      total,
      page: Number(page),
      pageSize: Number(pageSize),
      totalPages: Math.ceil(total / Number(pageSize))
    }, '获取申诉列表成功'));
  } catch (error: any) {
    logger.error('获取申诉列表失败:', error.message);
    res.status(500).json(errorResponse('获取申诉列表失败'));
  }
};

export const handleAppeal = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { action, handle_reason } = req.body;
    const userId = req.user?.id;
    const userRole = req.user?.role;

    if (!isSystemAdmin(userRole)) {
      return res.status(403).json(errorResponse('只有系统管理员可以处理申诉'));
    }

    if (!action || !['approved', 'rejected'].includes(action)) {
      return res.status(400).json(errorResponse('无效的操作类型'));
    }

    const [appeals] = await pool.query<RowDataPacket[]>(
      'SELECT * FROM review_appeals WHERE id = ?',
      [id]
    );
    if (appeals.length === 0) {
      return res.status(404).json(errorResponse('申诉不存在'));
    }

    const appeal = appeals[0];
    if (appeal.status !== 'pending') {
      return res.status(400).json(errorResponse('该申诉已处理'));
    }

    await pool.query(
      'UPDATE review_appeals SET status = ?, handler_id = ?, handle_reason = ?, handled_at = NOW() WHERE id = ?',
      [action, userId, handle_reason || '', id]
    );

    if (action === 'approved') {
      await pool.query('UPDATE reviews SET is_deleted = 1 WHERE id = ?', [appeal.review_id]);
      const [reviewRows] = await pool.query<RowDataPacket[]>(
        'SELECT hotel_id FROM reviews WHERE id = ?',
        [appeal.review_id]
      );
      if (reviewRows.length > 0) {
        await updateHotelRating(reviewRows[0].hotel_id);
      }
    }

    res.json(successResponse(null, action === 'approved' ? '申诉通过，评价已删除' : '申诉已驳回'));
  } catch (error: any) {
    logger.error('处理申诉失败:', error.message);
    res.status(500).json(errorResponse('处理申诉失败'));
  }
};

// ==================== 内部工具函数 ====================

async function updateHotelRating(hotelId: number | null) {
  if (!hotelId) return;

  try {
    const [stats] = await pool.query<RowDataPacket[]>(
      `SELECT AVG(score) as avg_score, COUNT(*) as total FROM reviews WHERE hotel_id = ? AND is_deleted = 0`,
      [hotelId]
    );
    const avgScore = Number((stats[0] as any).avg_score || 0).toFixed(1);
    const total = (stats[0] as any).total || 0;

    await pool.query(
      'UPDATE hotels SET rating = ?, review_count = ? WHERE id = ?',
      [avgScore, total, hotelId]
    );
  } catch (error: any) {
    logger.error('更新酒店评分失败:', error.message);
  }
}
