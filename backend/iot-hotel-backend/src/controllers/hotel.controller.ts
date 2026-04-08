import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import { HotelService } from '../services/hotel.service';
import pool, { ResultSetHeader, RowDataPacket } from '../config/database';
import logger from '../utils/logger';

export const get = async (req: AuthRequest, res: Response) => {
  try {
    const hotelId = req.user?.hotel_id;
    if (!hotelId) {
      return res.status(401).json(errorResponse('未授权，缺少酒店绑定信息'));
    }
    const hotel = await HotelService.getHotelById(hotelId);
    
    if (!hotel) {
      return res.status(404).json(errorResponse('酒店信息不存在'));
    }
    
    res.json(successResponse(hotel, '获取酒店信息成功'));
  } catch (error) {
    logger.error('获取酒店信息失败:', error);
    res.status(500).json(errorResponse('获取酒店信息失败'));
  }
};

/**
 * 获取所有酒店 (仅限 System 角色)
 */
export const getAll = async (req: AuthRequest, res: Response) => {
  try {
    if (req.user?.role !== 'system') {
      return res.status(403).json(errorResponse('无权访问所有酒店列表'));
    }
    const hotels = await HotelService.getAllHotels();
    res.json(successResponse(hotels, '获取所有酒店成功'));
  } catch (error) {
    logger.error('获取所有酒店失败:', error);
    res.status(500).json(errorResponse('获取所有酒店失败'));
  }
};

/**
 * 创建新酒店 (仅限 System 角色)
 */
export const create = async (req: AuthRequest, res: Response) => {
  try {
    if (req.user?.role !== 'system') {
      return res.status(403).json(errorResponse('无权创建酒店'));
    }
    const id = await HotelService.createHotel(req.body);
    res.status(201).json(successResponse({ id }, '酒店创建成功'));
  } catch (error: any) {
    logger.error('创建酒店失败:', error);
    res.status(500).json(errorResponse(error.message || '创建酒店失败'));
  }
};

export const update = async (req: AuthRequest, res: Response) => {
  try {
    let hotelId = req.user?.hotel_id;
    
    // 如果是 system 角色，允许指定修改哪个酒店
    if (req.user?.role === 'system' && req.params.id) {
      hotelId = parseInt(req.params.id);
    }

    if (!hotelId) {
      return res.status(401).json(errorResponse('未授权，缺少酒店信息'));
    }

    const success = await HotelService.updateHotel(hotelId, req.body);
    
    if (!success) {
      res.status(404).json(errorResponse('酒店信息不存在'));
      return;
    }
    
    res.json(successResponse(null, '更新酒店信息成功'));
  } catch (error) {
    logger.error('更新酒店信息失败:', error);
    res.status(500).json(errorResponse('更新酒店信息失败'));
  }
};

/**
 * 删除酒店 (仅限 System 角色)
 */
export const remove = async (req: AuthRequest, res: Response) => {
  try {
    if (req.user?.role !== 'system') {
      return res.status(403).json(errorResponse('无权删除酒店'));
    }
    const id = parseInt(req.params.id);
    const success = await HotelService.deleteHotel(id);
    
    if (!success) {
      return res.status(404).json(errorResponse('酒店不存在'));
    }
    
    res.json(successResponse(null, '酒店删除成功'));
  } catch (error) {
    logger.error('删除酒店失败:', error);
    res.status(500).json(errorResponse('删除酒店失败'));
  }
};