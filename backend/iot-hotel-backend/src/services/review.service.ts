import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';

export interface Review extends RowDataPacket {
  id: number;
  order_id: number;
  order_type: string;
  member_id: number;
  score: number;
  content: string;
  photos: string;
  created_at: Date;
  member_name?: string;
  member_phone?: string;
}

export interface ReviewListResponse {
  list: Review[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

export class ReviewService {
  static async getReviews(params: {
    page?: number;
    pageSize?: number;
    order_type?: string;
  }): Promise<ReviewListResponse> {
    try {
      const { page = 1, pageSize = 10, order_type } = params;
      const offset = (Number(page) - 1) * Number(pageSize);
      
      let whereClause = 'WHERE 1=1';
      const paramsArray: any[] = [];
      
      if (order_type) {
        whereClause += ' AND r.order_type = ?';
        paramsArray.push(order_type);
      }
      
      const [totalRows] = await pool.query<RowDataPacket[]>(`SELECT COUNT(*) as total FROM reviews r ${whereClause}`, paramsArray);
      const total = (totalRows[0] as any).total;
      
      const [rows] = await pool.query<RowDataPacket[]>(
        `SELECT r.*, m.name as member_name, m.phone as member_phone FROM reviews r LEFT JOIN members m ON r.member_id = m.id ${whereClause} ORDER BY r.id DESC LIMIT ? OFFSET ?`,
        [...paramsArray, Number(pageSize), offset]
      );
      
      return {
        list: rows as Review[],
        total,
        page: Number(page),
        pageSize: Number(pageSize),
        totalPages: Math.ceil(total / Number(pageSize))
      };
    } catch (error) {
      logger.error('获取评价列表失败:', error.message);
      throw new Error('获取评价列表失败');
    }
  }

  static async getReviewById(id: number): Promise<Review | null> {
    try {
      const [rows] = await pool.query<RowDataPacket[]>(
        'SELECT r.*, m.name as member_name, m.phone as member_phone FROM reviews r LEFT JOIN members m ON r.member_id = m.id WHERE r.id = ?',
        [id]
      );
      return (rows[0] as Review) || null;
    } catch (error) {
      logger.error('获取评价详情失败:', error.message);
      throw new Error('获取评价详情失败');
    }
  }

  static async createReview(data: {
    order_id: number;
    order_type: string;
    member_id: number;
    score: number;
    content: string;
    photos: string[];
  }): Promise<number> {
    try {
      const { order_id, order_type, member_id, score, content, photos } = data;
      
      const [result] = await pool.query<ResultSetHeader>(
        'INSERT INTO reviews (order_id, order_type, member_id, score, content, photos) VALUES (?, ?, ?, ?, ?, ?)',
        [order_id, order_type, member_id, score, content, JSON.stringify(photos || [])]
      );
      
      return result.insertId;
    } catch (error) {
      logger.error('创建评价失败:', error.message);
      throw new Error('创建评价失败');
    }
  }
}
