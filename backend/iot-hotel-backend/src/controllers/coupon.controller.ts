import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';

export const get = async (req: Request, res: Response) => {
  try {
    const { page = 1, pageSize = 10, status } = req.query;
    const offset = (Number(page) - 1) * Number(pageSize);
    
    let whereClause = 'WHERE 1=1';
    const params: any[] = [];
    
    if (status) {
      whereClause += ' AND status = ?';
      params.push(status);
    }
    
    const [totalRows] = await pool.query<RowDataPacket[]>(`SELECT COUNT(*) as total FROM coupons ${whereClause}`, params);
    const total = (totalRows[0] as any).total;
    
    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT * FROM coupons ${whereClause} ORDER BY id DESC LIMIT ? OFFSET ?`,
      [...params, Number(pageSize), offset]
    );
    
    res.json(successResponse({
      list: rows,
      total,
      page: Number(page),
      pageSize: Number(pageSize),
      totalPages: Math.ceil(total / Number(pageSize))
    }, '获取优惠券列表成功'));
  } catch (error) {
    logger.error('获取优惠券列表失败:', error);
    res.status(500).json(errorResponse('获取优惠券列表失败'));
  }
};

export const getById = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    
    const [rows] = await pool.query<RowDataPacket[]>('SELECT * FROM coupons WHERE id = ?', [id]);
    
    if (rows.length === 0) {
      res.status(404).json(errorResponse('优惠券不存在'));
      return;
    }
    
    res.json(successResponse(rows[0], '获取优惠券详情成功'));
  } catch (error) {
    logger.error('获取优惠券详情失败:', error);
    res.status(500).json(errorResponse('获取优惠券详情失败'));
  }
};

export const getMe = async (req: AuthRequest, res: Response) => {
  try {
    if (!req.user) return res.status(401).json(errorResponse('未认证'));
    
    // 查找会员ID
    const [members] = await pool.query<RowDataPacket[]>('SELECT id FROM members WHERE user_id = ? OR phone = ?', [req.user.id, req.user.username]);
    
    if (members.length === 0) {
      return res.json(successResponse([], '获取优惠券成功'));
    }
    
    const memberId = members[0].id;
    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT c.*, mc.status as my_status, mc.created_at as received_at 
       FROM member_coupons mc
       JOIN coupons c ON mc.coupon_id = c.id
       WHERE mc.member_id = ? AND mc.status = 'unused' AND c.valid_to >= NOW()`,
      [memberId]
    );
    
    res.json(successResponse(rows, '获取优惠券成功'));
  } catch (error) {
    logger.error('获取会员优惠券失败:', error);
    res.status(500).json(errorResponse('获取优惠券失败'));
  }
};

export const create = async (req: AuthRequest, res: Response) => {
  try {
    const { coupon_name, coupon_type, discount_value, min_amount, total_count, valid_from, valid_to } = req.body;
    
    const [result] = await pool.query<ResultSetHeader>(
      'INSERT INTO coupons (coupon_name, coupon_type, discount_value, min_amount, total_count, received_count, valid_from, valid_to) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [coupon_name, coupon_type, discount_value, min_amount, total_count, 0, valid_from, valid_to]
    );
    
    res.json(successResponse({ id: result.insertId }, '创建优惠券成功'));
  } catch (error) {
    logger.error('创建优惠券失败:', error);
    res.status(500).json(errorResponse('创建优惠券失败'));
  }
};

export const update = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { coupon_name, coupon_type, discount_value, min_amount, total_count, valid_from, valid_to } = req.body;
    
    const [result] = await pool.query<ResultSetHeader>(
      'UPDATE coupons SET coupon_name = ?, coupon_type = ?, discount_value = ?, min_amount = ?, total_count = ?, valid_from = ?, valid_to = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      [coupon_name, coupon_type, discount_value, min_amount, total_count, valid_from, valid_to, id]
    );
    
    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('优惠券不存在'));
      return;
    }
    
    res.json(successResponse(null, '更新优惠券成功'));
  } catch (error) {
    logger.error('更新优惠券失败:', error);
    res.status(500).json(errorResponse('更新优惠券失败'));
  }
};

export const remove = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    
    const [result] = await pool.query<ResultSetHeader>('DELETE FROM coupons WHERE id = ?', [id]);
    
    if (result.affectedRows === 0) {
      res.status(404).json(errorResponse('优惠券不存在'));
      return;
    }
    
    res.json(successResponse(null, '删除优惠券成功'));
  } catch (error) {
    logger.error('删除优惠券失败:', error);
    res.status(500).json(errorResponse('删除优惠券失败'));
  }
};

export const receive = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { member_id } = req.body;
    
    const [couponRows] = await pool.query<RowDataPacket[]>('SELECT * FROM coupons WHERE id = ?', [id]);
    
    if (couponRows.length === 0) {
      res.status(404).json(errorResponse('优惠券不存在'));
      return;
    }
    
    const coupon = couponRows[0];
    
    if ((coupon as any).received_count >= (coupon as any).total_count) {
      res.status(400).json(errorResponse('优惠券已领完'));
      return;
    }
    
    const [result] = await pool.query<ResultSetHeader>(
      'INSERT INTO member_coupons (member_id, coupon_id, status) VALUES (?, ?, ?)',
      [member_id, id, 'unused']
    );
    
    await pool.query<ResultSetHeader>('UPDATE coupons SET received_count = received_count + 1 WHERE id = ?', [id]);
    
    res.json(successResponse({ id: result.insertId }, '领取优惠券成功'));
  } catch (error) {
    logger.error('领取优惠券失败:', error);
    res.status(500).json(errorResponse('领取优惠券失败'));
  }
};