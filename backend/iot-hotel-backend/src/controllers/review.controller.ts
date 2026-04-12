import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';

export const get = async (req: AuthRequest, res: Response) => {
  try {
    const { page = 1, pageSize = 10, hotel_id } = req.query;
    const offset = (Number(page) - 1) * Number(pageSize);
    
    // 检查 reviews 表是否存在
    const [tables]: any = await pool.query("SHOW TABLES LIKE 'reviews'");
    if (tables.length === 0) {
      // 表不存在时返回空列表，避免 500 错误
      return res.json(successResponse({
        list: [], total: 0, page: Number(page), pageSize: Number(pageSize), totalPages: 0
      }, '获取评价列表成功(暂无评价数据)'));
    }

    let whereClause = 'WHERE 1=1';
    const params: any[] = [];
    
    if (hotel_id) {
      whereClause += ' AND r.hotel_id = ?';
      params.push(hotel_id);
    }
    
    const [totalRows] = await pool.query<RowDataPacket[]>(`SELECT COUNT(*) as total FROM reviews r ${whereClause}`, params);
    const total = (totalRows[0] as any).total;
    
    const [rows] = await pool.query<RowDataPacket[]>(
      `SELECT r.*, m.name as member_name, m.phone as member_phone FROM reviews r LEFT JOIN members m ON r.member_id = m.id ${whereClause} ORDER BY r.id DESC LIMIT ? OFFSET ?`,
      [...params, Number(pageSize), offset]
    );
    
    res.json(successResponse({
      list: rows,
      total,
      page: Number(page),
      pageSize: Number(pageSize),
      totalPages: Math.ceil(total / Number(pageSize))
    }, '获取评价列表成功'));
  } catch (error) {
    logger.error('获取评价列表失败:', error.message);
    res.status(500).json(errorResponse('获取评价列表失败'));
  }
};

export const getById = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    
    const [rows] = await pool.query<RowDataPacket[]>(
      'SELECT r.*, m.name as member_name, m.phone as member_phone FROM reviews r LEFT JOIN members m ON r.member_id = m.id WHERE r.id = ?',
      [id]
    );
    
    if (rows.length === 0) {
      res.status(404).json(errorResponse('评价不存在'));
      return;
    }
    
    res.json(successResponse(rows[0], '获取评价详情成功'));
  } catch (error) {
    logger.error('获取评价详情失败:', error.message);
    res.status(500).json(errorResponse('获取评价详情失败'));
  }
};

export const create = async (req: AuthRequest, res: Response) => {
  try {
    const { order_id, order_type, member_id, score, content, photos } = req.body;
    
    const [result] = await pool.query<ResultSetHeader>(
      'INSERT INTO reviews (order_id, order_type, member_id, score, content, photos) VALUES (?, ?, ?, ?, ?, ?)',
      [order_id, order_type, member_id, score, content, JSON.stringify(photos || [])]
    );
    
    res.json(successResponse({ id: result.insertId }, '创建评价成功'));
  } catch (error) {
    logger.error('创建评价失败:', error.message);
    res.status(500).json(errorResponse('创建评价失败'));
  }
};