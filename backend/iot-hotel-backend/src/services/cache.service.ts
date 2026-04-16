import redisClient from '../utils/redis';
import logger from '../utils/logger';

export interface CacheOptions {
  ttl?: number;
  key?: string;
}

export class CacheService {
  /**
   * 获取缓存数据，如果不存在则执行函数并缓存结果
   */
  static async getOrSet<T>(
    key: string,
    factory: () => Promise<T>,
    options?: CacheOptions
  ): Promise<T> {
    try {
      const cached = await redisClient.get<T>(key);
      if (cached !== null) {
        return cached;
      }
    } catch (error) {
      logger.warn(`读取缓存失败 [${key}]:`, error.message);
    }

    const result = await factory();

    try {
      await redisClient.set(key, result, options?.ttl);
    } catch (error) {
      logger.warn(`写入缓存失败 [${key}]:`, error.message);
    }

    return result;
  }

  /**
   * 直接获取缓存
   */
  static async get<T>(key: string): Promise<T | null> {
    return redisClient.get<T>(key);
  }

  /**
   * 设置缓存
   */
  static async set(key: string, value: any, ttl?: number): Promise<void> {
    return redisClient.set(key, value, ttl);
  }

  /**
   * 删除缓存
   */
  static async delete(key: string): Promise<void> {
    return redisClient.del(key);
  }

  /**
   * 根据模式删除缓存
   */
  static async deletePattern(pattern: string): Promise<void> {
    return redisClient.delPattern(pattern);
  }

  /**
   * 清空所有缓存
   */
  static async clear(): Promise<void> {
    return redisClient.flush();
  }

  /**
   * 检查缓存是否存在
   */
  static async exists(key: string): Promise<boolean> {
    return redisClient.exists(key);
  }

  /**
   * 生成缓存键
   */
  static generateKey(...parts: (string | number)[]): string {
    return parts.join(':');
  }

  /**
   * 生成酒店相关缓存键
   */
  static hotelKeys = {
    info: (hotelId: number) => `hotel:info:${hotelId}`,
    list: () => 'hotel:list',
    stats: (hotelId: number) => `hotel:stats:${hotelId}`,
  };

  /**
   * 生成房间相关缓存键
   */
  static roomKeys = {
    info: (roomId: number) => `room:info:${roomId}`,
    list: (hotelId: number) => `room:list:${hotelId}`,
    types: (hotelId: number) => `room:types:${hotelId}`,
    availability: (hotelId: number, date: string) => `room:availability:${hotelId}:${date}`,
    stats: (hotelId: number) => `room:stats:${hotelId}`,
  };

  /**
   * 生成设备相关缓存键
   */
  static deviceKeys = {
    info: (deviceId: number) => `device:info:${deviceId}`,
    list: (hotelId: number) => `device:list:${hotelId}`,
    status: (deviceId: string) => `device:status:${deviceId}`,
    pending: () => 'device:pending',
  };

  /**
   * 生成预订相关缓存键
   */
  static bookingKeys = {
    info: (bookingId: number) => `booking:info:${bookingId}`,
    list: (hotelId: number) => `booking:list:${hotelId}`,
    byNumber: (bookingNumber: string) => `booking:number:${bookingNumber}`,
  };

  /**
   * 生成知识库相关缓存键
   */
  static knowledgeBaseKeys = {
    article: (id: number) => `kb:article:${id}`,
    list: () => 'kb:list',
    categories: () => 'kb:categories',
    search: (query: string) => `kb:search:${query}`,
  };

  /**
   * 生成用户会话相关缓存键
   */
  static sessionKeys = {
    tokenBlacklist: (token: string) => `session:blacklist:${token}`,
    userSession: (userId: number) => `session:user:${userId}`,
  };
}

export default CacheService;
