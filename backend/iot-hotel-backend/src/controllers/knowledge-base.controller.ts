import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import { KnowledgeBaseService } from '../services/knowledge-base.service';
import pool, { RowDataPacket } from '../config/database';
import logger from '../utils/logger';
import { isHotelAdmin, isSystemAdmin, normalizeRole, CANONICAL_ROLES } from '../utils/role';

export const getAll = async (req: AuthRequest, res: Response) => {
  try {
    let hotelId = req.user?.hotel_id;
    const userRole = normalizeRole(req.user?.role);

    // 系统管理员可以指定查看某个酒店的知识库
    if (isSystemAdmin(userRole)) {
      const queryHotelId = req.query.hotel_id;
      if (queryHotelId) {
        hotelId = parseInt(queryHotelId as string);
      }
    }

    if (!hotelId && !isSystemAdmin(userRole)) {
      return res.status(400).json(errorResponse('未关联酒店'));
    }

    // 如果是系统管理员且 hotelId 为 0/未指定，则默认显示全部或提示选择
    if (isSystemAdmin(userRole) && !hotelId) {
      // 也可以选择返回所有酒店的知识库，但目前先要求指定或使用切换后的上下文
      // 为了兼容性，如果没有指定且已经切换了上下文，hotelId 已经是切换后的值
    }

    const filters: any = {};
    
    if (req.query.category) {
      filters.category = req.query.category as string;
    }
    
    if (req.query.is_active !== undefined) {
      filters.is_active = parseInt(req.query.is_active as string);
    }

    const knowledgeList = await KnowledgeBaseService.getByHotelId(hotelId, filters);
    
    res.json(successResponse(knowledgeList, '获取知识库列表成功'));
  } catch (error) {
    logger.error('获取知识库列表失败:', error.message);
    res.status(500).json(errorResponse('获取知识库列表失败'));
  }
};

export const getById = async (req: AuthRequest, res: Response) => {
  try {
    const id = parseInt(req.params.id);
    const knowledge = await KnowledgeBaseService.getById(id);

    if (!knowledge) {
      return res.status(404).json(errorResponse('知识条目不存在'));
    }

    const userRole = normalizeRole(req.user?.role);
    const hotelId = req.user?.hotel_id;

    if (!isSystemAdmin(userRole) && knowledge.hotel_id !== hotelId) {
      return res.status(403).json(errorResponse('无权访问该知识条目'));
    }

    res.json(successResponse(knowledge, '获取知识条目成功'));
  } catch (error) {
    logger.error('获取知识条目失败:', error.message);
    res.status(500).json(errorResponse('获取知识条目失败'));
  }
};

export const createOrUpdate = async (req: AuthRequest, res: Response) => {
  try {
    const category = req.params.category;
    let hotelId = req.user?.hotel_id;
    const userId = req.user?.id;
    const userRole = normalizeRole(req.user?.role);

    // 系统管理员可以指定为某个酒店操作
    if (isSystemAdmin(userRole)) {
      const bodyHotelId = req.body.hotel_id;
      if (bodyHotelId) {
        hotelId = parseInt(bodyHotelId as string);
      }
    }

    if (!hotelId) {
      return res.status(400).json(errorResponse('未关联酒店'));
    }

    const validCategories = ['restaurant', 'gym', 'wifi', 'nearby', 'checkout', 'breakfast', 'room_service', 'policy', 'other'];
    if (!validCategories.includes(category)) {
      return res.status(400).json(errorResponse(`无效的分类：${category}，可选值：${validCategories.join(', ')}`));
    }

    const { title, content, keywords, is_active, sort_order } = req.body;

    if (!title || !content) {
      return res.status(400).json(errorResponse('标题和内容不能为空'));
    }

    const result = await KnowledgeBaseService.createOrUpdate(
      hotelId,
      category,
      { title, content, keywords, is_active, sort_order },
      userId
    );

    res.json(successResponse(result, '知识条目更新成功'));
  } catch (error) {
    logger.error('更新知识条目失败:', error.message);
    res.status(500).json(errorResponse(error.message || '更新知识条目失败'));
  }
};

export const toggleActive = async (req: AuthRequest, res: Response) => {
  try {
    const id = parseInt(req.params.id);
    const userId = req.user?.id;

    const existing = await KnowledgeBaseService.getById(id);
    if (!existing) {
      return res.status(404).json(errorResponse('知识条目不存在'));
    }

    const userRole = normalizeRole(req.user?.role);
    const hotelId = req.user?.hotel_id;

    if (!isSystemAdmin(userRole) && existing.hotel_id !== hotelId) {
      return res.status(403).json(errorResponse('无权操作该知识条目'));
    }

    const result = await KnowledgeBaseService.toggleActive(id);

    logger.info(`用户 ${userId} 切换知识条目 ${id} 状态为 ${result.is_active ? '启用' : '禁用'}`);

    res.json(successResponse(result, '状态更新成功'));
  } catch (error) {
    logger.error('切换知识条目状态失败:', error.message);
    res.status(500).json(errorResponse(error.message || '切换状态失败'));
  }
};

export const remove = async (req: AuthRequest, res: Response) => {
  try {
    const id = parseInt(req.params.id);
    const userRole = normalizeRole(req.user?.role);

    if (!isSystemAdmin(userRole)) {
      return res.status(403).json(errorResponse('仅系统管理员可删除知识条目'));
    }

    const success = await KnowledgeBaseService.delete(id);

    if (!success) {
      return res.status(404).json(errorResponse('知识条目不存在'));
    }

    logger.info(`系统管理员删除知识条目 ID=${id}`);

    res.json(successResponse(null, '知识条目删除成功'));
  } catch (error) {
    logger.error('删除知识条目失败:', error.message);
    res.status(500).json(errorResponse('删除知识条目失败'));
  }
};

export const initDefault = async (req: AuthRequest, res: Response) => {
  try {
    let hotelId = req.user?.hotel_id;
    const userId = req.user?.id;
    const userRole = normalizeRole(req.user?.role);

    // 系统管理员可以指定为某个酒店初始化
    if (isSystemAdmin(userRole)) {
      const bodyHotelId = req.body.hotel_id;
      if (bodyHotelId) {
        hotelId = parseInt(bodyHotelId as string);
      }
    }

    if (!hotelId) {
      return res.status(400).json(errorResponse('未关联酒店'));
    }

    if (!isHotelAdmin(userRole) && !isSystemAdmin(userRole)) {
      return res.status(403).json(errorResponse('仅门店经理或系统管理员可初始化知识库'));
    }

    const count = await KnowledgeBaseService.initDefaultKnowledge(hotelId, userId);

    logger.info(`酒店 ${hotelId} 初始化默认知识库，创建 ${count} 条记录`);

    res.json(successResponse({ count }, `知识库初始化成功，已创建${count}个默认条目`));
  } catch (error) {
    logger.error('初始化知识库失败:', error.message);
    res.status(400).json(errorResponse(error.message || '初始化知识库失败'));
  }
};

export const getForAI = async (hotelId: number): Promise<any[]> => {
  try {
    return await KnowledgeBaseService.getActiveByHotel(hotelId);
  } catch (error) {
    logger.error('获取AI知识库数据失败:', error.message);
    return [];
  }
};
