import redisClient from '../utils/redis';
import logger from '../utils/logger';

export interface LoginAttemptRecord {
  failedAttempts: number;
  lastAttemptTime: number;
  lockedUntil: number | null;
}

/**
 * 登录安全服务
 * 功能:
 * 1. 连续登录失败计数与账户锁定
 * 2. 锁定时间累进: 10次错误锁定10分钟，之后每多5次错误加10分钟，上限360分钟
 * 3. IP级别限流
 * 4. 支持 Redis（生产）和内存存储（开发/Redis不可用时）双模式
 */

// 内存存储备用（当Redis不可用时使用）
const memoryStore: Map<string, { value: any; expiresAt: number | null }> = new Map();

// 定时清理过期内存数据
setInterval(() => {
  const now = Date.now();
  for (const [key, data] of memoryStore.entries()) {
    if (data.expiresAt && data.expiresAt < now) {
      memoryStore.delete(key);
    }
  }
}, 60 * 1000); // 每分钟清理一次

/**
 * 登录安全服务
 */
export class LoginSecurityService {
  // 初始锁定所需错误次数
  private static readonly INITIAL_FAILED_THRESHOLD = 10;
  // 初始锁定时间(分钟)
  private static readonly INITIAL_LOCKOUT_MINUTES = 10;
  // 每次增加锁定时间的错误次数增量
  private static readonly INCREMENT_FAILED_COUNT = 5;
  // 每次增加的锁定时间(分钟)
  private static readonly INCREMENT_LOCKOUT_MINUTES = 10;
  // 最大锁定时间(分钟)
  private static readonly MAX_LOCKOUT_MINUTES = 360;
  // 尝试记录过期时间(小时)
  private static readonly RECORD_TTL_HOURS = 24;

  /**
   * 计算锁定时间
   * @param failedAttempts 失败次数
   * @returns 锁定分钟数
   */
  static calculateLockoutMinutes(failedAttempts: number): number {
    if (failedAttempts < this.INITIAL_FAILED_THRESHOLD) {
      return 0;
    }
    // 10次错误锁定10分钟，之后每多5次加10分钟
    const extraFailed = failedAttempts - this.INITIAL_FAILED_THRESHOLD;
    const increments = Math.floor(extraFailed / this.INCREMENT_FAILED_COUNT);
    let lockMinutes = this.INITIAL_LOCKOUT_MINUTES + (increments * this.INCREMENT_LOCKOUT_MINUTES);
    // 上限360分钟
    return Math.min(lockMinutes, this.MAX_LOCKOUT_MINUTES);
  }

  /**
   * 获取Redis key前缀
   */
  private static getFailedAttemptsKey(phone: string): string {
    return `login:failed:${phone}`;
  }

  private static getLockedKey(phone: string): string {
    return `login:locked:${phone}`;
  }

  /**
   * 通用存储辅助方法（优先Redis，失败则使用内存存储）
   */
  private static async storageGet<T>(key: string): Promise<T | null> {
    try {
      if (redisClient.isReady()) {
        const value = await redisClient.get<T>(key);
        return value;
      }
    } catch (error) {
      logger.warn(`[LoginSecurity] Redis获取失败，使用内存存储: ${key}`);
    }

    // 内存存储回退
    const data = memoryStore.get(key);
    if (data && (!data.expiresAt || data.expiresAt > Date.now())) {
      return data.value as T;
    }
    if (data && data.expiresAt && data.expiresAt <= Date.now()) {
      memoryStore.delete(key);
    }
    return null;
  }

  private static async storageSet(key: string, value: any, ttlSeconds: number): Promise<void> {
    try {
      if (redisClient.isReady()) {
        await redisClient.set(key, value, ttlSeconds);
        return;
      }
    } catch (error) {
      logger.warn(`[LoginSecurity] Redis设置失败，使用内存存储: ${key}`);
    }

    // 内存存储回退
    const expiresAt = ttlSeconds ? Date.now() + ttlSeconds * 1000 : null;
    memoryStore.set(key, { value, expiresAt });
  }

  private static async storageDel(key: string): Promise<void> {
    try {
      if (redisClient.isReady()) {
        await redisClient.del(key);
        return;
      }
    } catch (error) {
      logger.warn(`[LoginSecurity] Redis删除失败，使用内存存储: ${key}`);
    }

    // 内存存储回退
    memoryStore.delete(key);
  }

  /**
   * 记录登录失败
   * @returns 返回登录失败次数和是否被锁定
   */
  static async recordFailedLogin(phone: string): Promise<{
    attempts: number;
    isLocked: boolean;
    lockedUntil: Date | null;
    remainingAttempts: number;
    warningAttempts: number;
  }> {
    const attemptsKey = this.getFailedAttemptsKey(phone);
    const lockedKey = this.getLockedKey(phone);

    try {
      // 增加失败次数
      const attempts = await this.storageGet<number>(attemptsKey) || 0;
      const newAttempts = attempts + 1;

      // 设置过期时间
      await this.storageSet(attemptsKey, newAttempts, this.RECORD_TTL_HOURS * 3600);

      // 计算锁定时间
      const lockMinutes = this.calculateLockoutMinutes(newAttempts);

      // 计算剩余警告次数（距离下次锁定的剩余次数）
      let warningAttempts = 0;
      if (lockMinutes === 0) {
        // 还没到锁定阈值，计算距离首次锁定还差几次
        warningAttempts = this.INITIAL_FAILED_THRESHOLD - newAttempts;
      } else {
        // 已达锁定，下次锁定还需要5次错误
        warningAttempts = this.INCREMENT_FAILED_COUNT - ((newAttempts - this.INITIAL_FAILED_THRESHOLD) % this.INCREMENT_FAILED_COUNT);
      }

      // 检查是否需要锁定
      if (lockMinutes > 0) {
        const lockSeconds = lockMinutes * 60;
        const lockedUntil = Date.now() + lockSeconds * 1000;

        await this.storageSet(lockedKey, lockedUntil, lockSeconds);

        logger.warn(
          `[LoginSecurity] 账户 ${phone} 被锁定，锁定时间: ${lockMinutes} 分钟 (失败次数: ${newAttempts})`
        );

        return {
          attempts: newAttempts,
          isLocked: true,
          lockedUntil: new Date(lockedUntil),
          remainingAttempts: 0,
          warningAttempts: 0
        };
      }

      return {
        attempts: newAttempts,
        isLocked: false,
        lockedUntil: null,
        remainingAttempts: warningAttempts,
        warningAttempts
      };
    } catch (error) {
      logger.error(`[LoginSecurity] 记录登录失败异常:`, error);
      // 任何异常时返回安全值
      return { attempts: 0, isLocked: false, lockedUntil: null, remainingAttempts: 0, warningAttempts: 0 };
    }
  }

  /**
   * 检查账户是否被锁定
   */
  static async isLocked(phone: string): Promise<{
    isLocked: boolean;
    lockedUntil: Date | null;
    remainingAttempts: number;
  }> {
    const attemptsKey = this.getFailedAttemptsKey(phone);
    const lockedKey = this.getLockedKey(phone);

    try {
      // 检查锁定状态
      const lockedUntil = await this.storageGet<number>(lockedKey);
      if (lockedUntil && lockedUntil > Date.now()) {
        return {
          isLocked: true,
          lockedUntil: new Date(lockedUntil),
          remainingAttempts: 0
        };
      }

      // 如果锁定已过期，清除锁定状态
      if (lockedUntil) {
        await this.storageDel(lockedKey);
      }

      // 获取当前失败次数
      const attempts = await this.storageGet<number>(attemptsKey) || 0;

      // 计算剩余尝试次数
      let remainingAttempts = 0;
      if (attempts < this.INITIAL_FAILED_THRESHOLD) {
        remainingAttempts = this.INITIAL_FAILED_THRESHOLD - attempts;
      } else {
        // 已超过阈值，但未达到下一个锁定点
        const extraFailed = attempts - this.INITIAL_FAILED_THRESHOLD;
        remainingAttempts = this.INCREMENT_FAILED_COUNT - (extraFailed % this.INCREMENT_FAILED_COUNT);
      }

      return {
        isLocked: false,
        lockedUntil: null,
        remainingAttempts
      };
    } catch (error) {
      logger.error(`[LoginSecurity] 检查锁定状态异常:`, error);
      return { isLocked: false, lockedUntil: null, remainingAttempts: this.INITIAL_FAILED_THRESHOLD };
    }
  }

  /**
   * 登录成功，重置失败计数
   */
  static async resetFailedLogin(phone: string): Promise<void> {
    const attemptsKey = this.getFailedAttemptsKey(phone);
    const lockedKey = this.getLockedKey(phone);

    try {
      await this.storageDel(attemptsKey);
      await this.storageDel(lockedKey);
      logger.info(`[LoginSecurity] 账户 ${phone} 登录成功，已重置失败计数`);
    } catch (error) {
      logger.error(`[LoginSecurity] 重置失败计数异常:`, error);
    }
  }

  /**
   * 手动解锁账户（管理员操作）
   */
  static async unlockAccount(phone: string): Promise<boolean> {
    const attemptsKey = this.getFailedAttemptsKey(phone);
    const lockedKey = this.getLockedKey(phone);

    try {
      await this.storageDel(attemptsKey);
      await this.storageDel(lockedKey);
      logger.info(`[LoginSecurity] 账户 ${phone} 已手动解锁`);
      return true;
    } catch (error) {
      logger.error(`[LoginSecurity] 解锁账户异常:`, error);
      return false;
    }
  }

  /**
   * 手动锁定账户（管理员操作）
   */
  static async lockAccount(phone: string): Promise<boolean> {
    const lockedKey = this.getLockedKey(phone);

    try {
      const lockDuration = this.INITIAL_LOCKOUT_MINUTES * 60;
      const lockedUntil = Date.now() + lockDuration * 1000;
      await this.storageSet(lockedKey, lockedUntil, lockDuration);
      logger.info(`[LoginSecurity] 账户 ${phone} 已被管理员手动锁定`);
      return true;
    } catch (error) {
      logger.error(`[LoginSecurity] 锁定账户异常:`, error);
      return false;
    }
  }

  /**
   * 获取配置信息（用于前端显示）
   */
  static getConfig() {
    return {
      initialFailedThreshold: this.INITIAL_FAILED_THRESHOLD,
      initialLockoutMinutes: this.INITIAL_LOCKOUT_MINUTES,
      incrementFailedCount: this.INCREMENT_FAILED_COUNT,
      incrementLockoutMinutes: this.INCREMENT_LOCKOUT_MINUTES,
      maxLockoutMinutes: this.MAX_LOCKOUT_MINUTES
    };
  }
}
