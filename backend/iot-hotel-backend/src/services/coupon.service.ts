import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { v4 as uuidv4 } from 'uuid';

export interface Coupon extends RowDataPacket {
  id: number;
  hotel_id: number;
  hotel_ids?: string; // 适用门店ID列表，逗号分隔，如 "1,2,3"
  coupon_name: string;
  coupon_type: string;
  discount_value: number;
  min_amount: number;
  total_count: number;
  received_count: number;
  valid_from: Date;
  valid_to: Date;
  created_at: Date;
  updated_at: Date;
}

export interface CouponListResponse {
  list: Coupon[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

export class CouponService {
  static async getCoupons(params: {
    page?: number;
    pageSize?: number;
    status?: string;
  }): Promise<CouponListResponse> {
    try {
      const { page = 1, pageSize = 10, status } = params;
      const offset = (Number(page) - 1) * Number(pageSize);
      
      let whereClause = 'WHERE 1=1';
      const paramsArray: any[] = [];
      
      if (status) {
        whereClause += ' AND status = ?';
        paramsArray.push(status);
      }
      
      const [totalRows] = await pool.query<RowDataPacket[]>(`SELECT COUNT(*) as total FROM coupons ${whereClause}`, paramsArray);
      const total = (totalRows[0] as any).total;
      
      const [rows] = await pool.query<RowDataPacket[]>(
        `SELECT * FROM coupons ${whereClause} ORDER BY id DESC LIMIT ? OFFSET ?`,
        [...paramsArray, Number(pageSize), offset]
      );
      
      return {
        list: rows as Coupon[],
        total,
        page: Number(page),
        pageSize: Number(pageSize),
        totalPages: Math.ceil(total / Number(pageSize))
      };
    } catch (error) {
      logger.error('获取优惠券列表失败:', error.message);
      throw new Error('获取优惠券列表失败');
    }
  }

  static async getCouponById(id: number): Promise<Coupon | null> {
    try {
      const [rows] = await pool.query<RowDataPacket[]>('SELECT * FROM coupons WHERE id = ?', [id]);
      return (rows[0] as Coupon) || null;
    } catch (error) {
      logger.error('获取优惠券详情失败:', error.message);
      throw new Error('获取优惠券详情失败');
    }
  }

  static async createCoupon(data: {
    coupon_name: string;
    coupon_type: string;
    discount_value: number;
    min_amount: number;
    total_count: number;
    valid_from: string;
    valid_to: string;
  }): Promise<number> {
    try {
      const { coupon_name, coupon_type, discount_value, min_amount, total_count, valid_from, valid_to } = data;
      
      const [result] = await pool.query<ResultSetHeader>(
        'INSERT INTO coupons (coupon_name, coupon_type, discount_value, min_amount, total_count, received_count, valid_from, valid_to) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [coupon_name, coupon_type, discount_value, min_amount, total_count, 0, valid_from, valid_to]
      );
      
      return result.insertId;
    } catch (error) {
      logger.error('创建优惠券失败:', error.message);
      throw new Error('创建优惠券失败');
    }
  }

  static async updateCoupon(id: number, data: Partial<Coupon>): Promise<boolean> {
    try {
      const { coupon_name, coupon_type, discount_value, min_amount, total_count, valid_from, valid_to } = data;
      
      const [result] = await pool.query<ResultSetHeader>(
        'UPDATE coupons SET coupon_name = ?, coupon_type = ?, discount_value = ?, min_amount = ?, total_count = ?, valid_from = ?, valid_to = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        [coupon_name, coupon_type, discount_value, min_amount, total_count, valid_from, valid_to, id]
      );
      
      return result.affectedRows > 0;
    } catch (error) {
      logger.error('更新优惠券失败:', error.message);
      throw new Error('更新优惠券失败');
    }
  }

  static async deleteCoupon(id: number): Promise<boolean> {
    try {
      const [result] = await pool.query<ResultSetHeader>('DELETE FROM coupons WHERE id = ?', [id]);
      return result.affectedRows > 0;
    } catch (error) {
      logger.error('删除优惠券失败:', error.message);
      throw new Error('删除优惠券失败');
    }
  }

  static async receiveCoupon(member_id: number, coupon_id: number): Promise<{ id: number }> {
    try {
      const [couponRows] = await pool.query<RowDataPacket[]>('SELECT * FROM coupons WHERE id = ?', [coupon_id]);
      
      if (couponRows.length === 0) {
        throw new Error('优惠券不存在');
      }
      
      const coupon = couponRows[0];
      
      if ((coupon as any).received_count >= (coupon as any).total_count) {
        throw new Error('优惠券已领完');
      }
      
      const [result] = await pool.query<ResultSetHeader>(
        'INSERT INTO member_coupons (member_id, coupon_id, status) VALUES (?, ?, ?)',
        [member_id, coupon_id, 'unused']
      );
      
      await pool.query<ResultSetHeader>('UPDATE coupons SET received_count = received_count + 1 WHERE id = ?', [coupon_id]);
      
      return { id: result.insertId };
    } catch (error) {
      logger.error('领取优惠券失败:', error.message);
      throw new Error('领取优惠券失败');
    }
  }
}
