import CacheService from '../services/cache.service';
import logger from '../utils/logger';

export interface CacheableOptions {
  key?: string;
  ttl?: number;
  keyGenerator?: (...args: any[]) => string;
}

/**
 * 缓存装饰器 - 自动缓存方法返回结果
 * @param options 缓存配置选项
 */
export function Cacheable(options: CacheableOptions = {}) {
  return function (
    target: any,
    propertyName: string,
    descriptor: PropertyDescriptor
  ) {
    const originalMethod = descriptor.value;

    descriptor.value = async function (...args: any[]) {
      try {
        let cacheKey: string;

        if (options.keyGenerator) {
          cacheKey = options.keyGenerator(...args);
        } else if (options.key) {
          cacheKey = options.key;
        } else {
          const className = target.constructor.name;
          const argsHash = args.map(arg =>
            typeof arg === 'object' ? JSON.stringify(arg) : String(arg)
          ).join(':');
          cacheKey = `${className}:${propertyName}:${argsHash}`;
        }

        return await CacheService.getOrSet(
          cacheKey,
          () => originalMethod.apply(this, args),
          { ttl: options.ttl }
        );
      } catch (error) {
        logger.warn(`缓存装饰器执行失败 [${propertyName}]:`, error.message);
        return originalMethod.apply(this, args);
      }
    };

    return descriptor;
  };
}

/**
 * 清除缓存装饰器 - 方法执行后清除指定缓存
 * @param keyPattern 要清除的缓存键或模式
 */
export function CacheEvict(keyPattern: string | ((...args: any[]) => string)) {
  return function (
    target: any,
    propertyName: string,
    descriptor: PropertyDescriptor
  ) {
    const originalMethod = descriptor.value;

    descriptor.value = async function (...args: any[]) {
      const result = await originalMethod.apply(this, args);

      try {
        const pattern = typeof keyPattern === 'function'
          ? keyPattern(...args)
          : keyPattern;

        if (pattern.includes('*')) {
          await CacheService.deletePattern(pattern);
        } else {
          await CacheService.delete(pattern);
        }
      } catch (error) {
        logger.warn(`清除缓存失败 [${propertyName}]:`, error.message);
      }

      return result;
    };

    return descriptor;
  };
}

/**
 * 更新缓存装饰器 - 方法执行后更新指定缓存
 * @param key 缓存键或键生成函数
 * @param ttl 过期时间（秒）
 */
export function CachePut(key: string | ((...args: any[]) => string), ttl?: number) {
  return function (
    target: any,
    propertyName: string,
    descriptor: PropertyDescriptor
  ) {
    const originalMethod = descriptor.value;

    descriptor.value = async function (...args: any[]) {
      const result = await originalMethod.apply(this, args);

      try {
        const cacheKey = typeof key === 'function'
          ? key(...args)
          : key;

        await CacheService.set(cacheKey, result, ttl);
      } catch (error) {
        logger.warn(`更新缓存失败 [${propertyName}]:`, error.message);
      }

      return result;
    };

    return descriptor;
  };
}
