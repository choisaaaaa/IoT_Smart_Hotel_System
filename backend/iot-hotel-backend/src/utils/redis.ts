import { createClient, RedisClientType } from 'redis';
import config from '../config';
import logger from './logger';

class RedisClient {
  private client: RedisClientType | null = null;
  private isConnected = false;
  private connectAttempted = false;

  async connect(): Promise<void> {
    if (!config.redis.enabled) {
      logger.info('Redis缓存已禁用');
      return;
    }

    if (this.isConnected && this.client) {
      return;
    }

    if (this.connectAttempted && !this.isConnected) {
      return;
    }

    this.connectAttempted = true;

    try {
      this.client = createClient({
        socket: {
          host: config.redis.host,
          port: config.redis.port,
          reconnectStrategy: false,
        },
        password: config.redis.password,
        database: config.redis.db,
      });

      this.client.on('error', (err) => {
        if (!this.isConnected) {
          logger.error('Redis连接失败，已禁用缓存功能:', err.message);
          this.client = null;
        } else {
          logger.error('Redis客户端错误:', err.message);
          this.isConnected = false;
        }
      });

      this.client.on('connect', () => {
        logger.info('Redis连接成功');
        this.isConnected = true;
      });

      this.client.on('disconnect', () => {
        logger.warn('Redis连接断开');
        this.isConnected = false;
      });

      await this.client.connect();
    } catch (error) {
      logger.error('Redis连接失败，已禁用缓存功能:', error.message);
      this.client = null;
      this.isConnected = false;
    }
  }

  async disconnect(): Promise<void> {
    if (this.client) {
      await this.client.disconnect();
      this.client = null;
      this.isConnected = false;
      logger.info('Redis连接已关闭');
    }
  }

  private getKey(key: string): string {
    return `${config.redis.keyPrefix}${key}`;
  }

  async get<T>(key: string): Promise<T | null> {
    if (!this.isConnected || !this.client) {
      return null;
    }

    try {
      const value = await this.client.get(this.getKey(key));
      if (!value) {
        return null;
      }
      return JSON.parse(value) as T;
    } catch (error) {
      logger.error(`Redis获取缓存失败 [${key}]:`, error.message);
      return null;
    }
  }

  async set(key: string, value: unknown, ttl?: number): Promise<void> {
    if (!this.isConnected || !this.client) {
      return;
    }

    try {
      const serializedValue = JSON.stringify(value);
      const expireTime = ttl || config.redis.defaultTTL;
      await this.client.setEx(this.getKey(key), expireTime, serializedValue);
    } catch (error) {
      logger.error(`Redis设置缓存失败 [${key}]:`, error.message);
    }
  }

  async del(key: string): Promise<void> {
    if (!this.isConnected || !this.client) {
      return;
    }

    try {
      await this.client.del(this.getKey(key));
    } catch (error) {
      logger.error(`Redis删除缓存失败 [${key}]:`, error.message);
    }
  }

  async delPattern(pattern: string): Promise<void> {
    if (!this.isConnected || !this.client) {
      return;
    }

    try {
      const keys = await this.client.keys(this.getKey(pattern));
      if (keys.length > 0) {
        await this.client.del(keys);
      }
    } catch (error) {
      logger.error(`Redis批量删除缓存失败 [${pattern}]:`, error.message);
    }
  }

  async exists(key: string): Promise<boolean> {
    if (!this.isConnected || !this.client) {
      return false;
    }

    try {
      const result = await this.client.exists(this.getKey(key));
      return result === 1;
    } catch (error) {
      logger.error(`Redis检查缓存存在失败 [${key}]:`, error.message);
      return false;
    }
  }

  async expire(key: string, seconds: number): Promise<void> {
    if (!this.isConnected || !this.client) {
      return;
    }

    try {
      await this.client.expire(this.getKey(key), seconds);
    } catch (error) {
      logger.error(`Redis设置过期时间失败 [${key}]:`, error.message);
    }
  }

  async ttl(key: string): Promise<number> {
    if (!this.isConnected || !this.client) {
      return -1;
    }

    try {
      return await this.client.ttl(this.getKey(key));
    } catch (error) {
      logger.error(`Redis获取TTL失败 [${key}]:`, error.message);
      return -1;
    }
  }

  async flush(): Promise<void> {
    if (!this.isConnected || !this.client) {
      return;
    }

    try {
      const keys = await this.client.keys(`${config.redis.keyPrefix}*`);
      if (keys.length > 0) {
        await this.client.del(keys);
        logger.info(`已清空 ${keys.length} 个缓存键`);
      }
    } catch (error) {
      logger.error('Redis清空缓存失败:', error.message);
    }
  }

  async healthCheck(): Promise<boolean> {
    if (!this.isConnected || !this.client) {
      return false;
    }

    try {
      await this.client.ping();
      return true;
    } catch {
      return false;
    }
  }

  getClient(): RedisClientType | null {
    return this.client;
  }

  isReady(): boolean {
    return this.isConnected && this.client !== null;
  }
}

export const redisClient = new RedisClient();
export default redisClient;
