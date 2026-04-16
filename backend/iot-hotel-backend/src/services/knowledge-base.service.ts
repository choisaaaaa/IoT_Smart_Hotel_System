import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { KnowledgeBase, KnowledgeBaseInput } from '../models/knowledge-base.model';
import { KNOWLEDGE_BASE_CONFIG } from '../config/knowledge-base.config';
import CacheService from './cache.service';

export class KnowledgeBaseService {
  static async getByHotelId(hotelId: number, filters?: { category?: string; is_active?: number }): Promise<KnowledgeBase[]> {
    try {
      const cacheKey = CacheService.generateKey(
        CacheService.knowledgeBaseKeys.list(),
        hotelId,
        JSON.stringify(filters || {})
      );

      return await CacheService.getOrSet(
        cacheKey,
        async () => {
          let sql = `SELECT * FROM ai_knowledge_base WHERE hotel_id = ?`;
          const params: unknown[] = [hotelId];

          if (filters?.category) {
            sql += ` AND category = ?`;
            params.push(filters.category);
          }

          if (filters?.is_active !== undefined) {
            sql += ` AND is_active = ?`;
            params.push(filters.is_active);
          }

          sql += ` ORDER BY sort_order DESC, created_at ASC`;

          const [rows] = await pool.query<RowDataPacket[]>(sql, params);
          return rows as KnowledgeBase[];
        },
        { ttl: 1800 } // 知识库缓存30分钟
      );
    } catch (error) {
      logger.error('查询知识库失败:', (error as Error).message);
      throw error;
    }
  }

  static async getById(id: number): Promise<KnowledgeBase | null> {
    try {
      return await CacheService.getOrSet(
        CacheService.knowledgeBaseKeys.article(id),
        async () => {
          const [rows] = await pool.query<RowDataPacket[]>(
            'SELECT * FROM ai_knowledge_base WHERE id = ?',
            [id]
          );
          return (rows as KnowledgeBase[])[0] || null;
        },
        { ttl: 1800 }
      );
    } catch (error) {
      logger.error('查询知识条目失败:', (error as Error).message);
      throw error;
    }
  }

  static async getByHotelAndCategory(hotelId: number, category: string): Promise<KnowledgeBase | null> {
    try {
      const [rows] = await pool.query<RowDataPacket[]>(
        'SELECT * FROM ai_knowledge_base WHERE hotel_id = ? AND category = ?',
        [hotelId, category]
      );
      return (rows as KnowledgeBase[])[0] || null;
    } catch (error) {
      logger.error('查询知识条目失败:', error.message);
      throw error;
    }
  }

  static async createOrUpdate(hotelId: number, category: string, data: KnowledgeBaseInput, userId?: number): Promise<KnowledgeBase> {
    const connection = await pool.getConnection();
    
    try {
      await connection.beginTransaction();

      const existing = await connection.query<RowDataPacket[]>(
        'SELECT id FROM ai_knowledge_base WHERE hotel_id = ? AND category = ? FOR UPDATE',
        [hotelId, category]
      );

      let result: KnowledgeBase;

      if ((existing[0] as RowDataPacket[]).length > 0) {
        const existingId = (existing[0][0] as any).id;
        
        const updateFields: string[] = [];
        const updateParams: any[] = [];

        if (data.title !== undefined) {
          updateFields.push('title = ?');
          updateParams.push(data.title);
        }
        if (data.content !== undefined) {
          updateFields.push('content = ?');
          updateParams.push(data.content);
        }
        if (data.keywords !== undefined) {
          updateFields.push('keywords = ?');
          updateParams.push(data.keywords);
        }
        if (data.is_active !== undefined) {
          updateFields.push('is_active = ?');
          updateParams.push(data.is_active);
        }
        if (data.sort_order !== undefined) {
          updateFields.push('sort_order = ?');
          updateParams.push(data.sort_order);
        }

        updateFields.push('updated_by = ?');
        updateParams.push(userId);

        updateParams.push(existingId);

        await connection.query(
          `UPDATE ai_knowledge_base SET ${updateFields.join(', ')} WHERE id = ?`,
          updateParams
        );

        const [updatedRows] = await connection.query<RowDataPacket[]>(
          'SELECT * FROM ai_knowledge_base WHERE id = ?',
          [existingId]
        );
        result = (updatedRows as KnowledgeBase[])[0];
      } else {
        const [insertResult] = await connection.query<ResultSetHeader>(
          `INSERT INTO ai_knowledge_base (hotel_id, category, title, content, keywords, is_active, sort_order, created_by, updated_by)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            hotelId,
            category,
            data.title || '',
            data.content || '',
            data.keywords || null,
            data.is_active ?? 1,
            data.sort_order ?? 0,
            userId,
            userId
          ]
        );

        const [newRows] = await connection.query<RowDataPacket[]>(
          'SELECT * FROM ai_knowledge_base WHERE id = ?',
          [insertResult.insertId]
        );
        result = (newRows as KnowledgeBase[])[0];
      }

      await connection.commit();

      // 清除相关缓存
      await CacheService.delete(CacheService.knowledgeBaseKeys.article(result.id));
      await CacheService.deletePattern('kb:list:*');
      if (hotelId) {
        await CacheService.delete(`kb:active:${hotelId}`);
      }

      return result;
    } catch (error) {
      await connection.rollback();
      logger.error('创建/更新知识条目失败:', error.message);
      throw error;
    } finally {
      connection.release();
    }
  }

  static async toggleActive(id: number): Promise<{ is_active: number }> {
    try {
      const [result] = await pool.query<RowDataPacket[]>(
        'UPDATE ai_knowledge_base SET is_active = NOT is_active WHERE id = ?',
        [id]
      );

      if ((result as unknown as ResultSetHeader).affectedRows === 0) {
        throw new Error('知识条目不存在');
      }

      // 清除相关缓存
      await CacheService.delete(CacheService.knowledgeBaseKeys.article(id));
      await CacheService.deletePattern('kb:list:*');
      await CacheService.deletePattern('kb:active:*');

      const [updated] = await pool.query<RowDataPacket[]>(
        'SELECT is_active FROM ai_knowledge_base WHERE id = ?',
        [id]
      );

      return { is_active: (updated[0] as { is_active: number }).is_active };
    } catch (error) {
      logger.error('切换知识条目状态失败:', (error as Error).message);
      throw error;
    }
  }

  static async delete(id: number): Promise<boolean> {
    try {
      const [result] = await pool.query<ResultSetHeader>(
        'DELETE FROM ai_knowledge_base WHERE id = ?',
        [id]
      );

      if ((result as ResultSetHeader).affectedRows > 0) {
        // 清除相关缓存
        await CacheService.delete(CacheService.knowledgeBaseKeys.article(id));
        await CacheService.deletePattern('kb:list:*');
        await CacheService.deletePattern('kb:active:*');
      }

      return (result as ResultSetHeader).affectedRows > 0;
    } catch (error) {
      logger.error('删除知识条目失败:', (error as Error).message);
      throw error;
    }
  }

  static async initDefaultKnowledge(hotelId: number, userId?: number): Promise<number> {
    const connection = await pool.getConnection();

    try {
      await connection.beginTransaction();

      const [existing] = await connection.query<RowDataPacket[]>(
        'SELECT COUNT(*) as count FROM ai_knowledge_base WHERE hotel_id = ?',
        [hotelId]
      );

      if ((existing[0] as any).count > 0) {
        throw new Error('该酒店已有知识库数据，无法初始化');
      }

      // 使用配置化的默认内容模板
      for (const config of KNOWLEDGE_BASE_CONFIG) {
        const keywords = config.fields.map(f => f.label).join(',');
        
        await connection.query(
          `INSERT INTO ai_knowledge_base (hotel_id, category, title, content, keywords, is_active, sort_order, created_by, updated_by)
           VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?)`,
          [hotelId, config.category, config.title, config.defaultContent, keywords, config.fields.length * 10, userId, userId]
        );
      }

      await connection.commit();
      return KNOWLEDGE_BASE_CONFIG.length;
    } catch (error) {
      await connection.rollback();
      logger.error('初始化默认知识库失败:', error.message);
      throw error;
    } finally {
      connection.release();
    }
  }

  static async getActiveByHotel(hotelId: number): Promise<KnowledgeBase[]> {
    try {
      return await CacheService.getOrSet(
        `kb:active:${hotelId}`,
        async () => {
          const [rows] = await pool.query<RowDataPacket[]>(
            `SELECT * FROM ai_knowledge_base 
             WHERE hotel_id = ? AND is_active = 1 
             ORDER BY sort_order DESC, created_at ASC`,
            [hotelId]
          );
          return rows as KnowledgeBase[];
        },
        { ttl: 1800 }
      );
    } catch (error) {
      logger.error('查询活跃知识库失败:', (error as Error).message);
      throw error;
    }
  }
}
