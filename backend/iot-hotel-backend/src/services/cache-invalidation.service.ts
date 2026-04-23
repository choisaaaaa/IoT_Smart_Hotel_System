import logger from '../utils/logger';
import CacheService from './cache.service';
import { eventBus, EVENT_TYPES } from '../utils/event-bus';

/**
 * 缓存失效服务
 * 监听各种事件并清除相关缓存，确保数据一致性
 */
export class CacheInvalidationService {
  private static instance: CacheInvalidationService;

  private constructor() {
    this.setupEventListeners();
  }

  public static getInstance(): CacheInvalidationService {
    if (!CacheInvalidationService.instance) {
      CacheInvalidationService.instance = new CacheInvalidationService();
    }
    return CacheInvalidationService.instance;
  }

  /**
   * 设置事件监听器
   */
  private setupEventListeners(): void {
    // 监听订单状态变更事件
    eventBus.on(EVENT_TYPES.BOOKING_STATUS_CHANGED, async (data) => {
      await this.handleBookingStatusChanged(data);
    });

    // 监听设备状态变更事件
    eventBus.on(EVENT_TYPES.DEVICE_STATUS_CHANGED, async (data) => {
      await this.handleDeviceStatusChanged(data);
    });

    // 监听送物订单更新事件
    eventBus.on(EVENT_TYPES.DELIVERY_ORDER_UPDATED, async (data) => {
      await this.handleDeliveryOrderUpdated(data);
    });

    // 监听维修工单更新事件
    eventBus.on(EVENT_TYPES.MAINTENANCE_TICKET_UPDATED, async (data) => {
      await this.handleMaintenanceTicketUpdated(data);
    });

    // 监听房间状态变更事件
    eventBus.on(EVENT_TYPES.ROOM_STATUS_CHANGED, async (data) => {
      await this.handleRoomStatusChanged(data);
    });

    logger.info('缓存失效事件监听器已设置');
  }

  /**
   * 处理订单状态变更事件
   */
  private async handleBookingStatusChanged(data: any): Promise<void> {
    const { bookingId, hotelId, bookingNumber, status } = data;
    
    try {
      // 清除房间相关缓存（因为订单状态变更可能影响房间状态）
      await CacheService.deletePattern(`room:list:${hotelId}*`);
      await CacheService.deletePattern(`room:info:*`);
      
      // 清除送物订单相关缓存
      await CacheService.deletePattern(`delivery:list:${hotelId}*`);
      
      // 清除维修工单相关缓存
      await CacheService.deletePattern(`maintenance:list:${hotelId}*`);
      
      logger.info(`[缓存失效] 订单 ${bookingId} 状态变更为 ${status}，已清除相关缓存`);
    } catch (error) {
      logger.error(`[缓存失效] 处理订单状态变更事件失败:`, error.message);
    }
  }

  /**
   * 处理设备状态变更事件
   */
  private async handleDeviceStatusChanged(data: any): Promise<void> {
    const { deviceId, hotelId, roomId } = data;
    
    try {
      // 清除设备列表缓存
      await CacheService.deletePattern(`device:list:${hotelId}*`);
      
      // 清除设备详情缓存
      await CacheService.delete(CacheService.deviceKeys.info(deviceId));
      
      // 如果设备关联了房间，清除房间相关缓存
      if (roomId) {
        await CacheService.delete(CacheService.roomKeys.info(roomId));
        await CacheService.deletePattern(`room:list:${hotelId}*`);
      }
      
      logger.info(`[缓存失效] 设备 ${deviceId} 状态变更，已清除相关缓存`);
    } catch (error) {
      logger.error(`[缓存失效] 处理设备状态变更事件失败:`, error.message);
    }
  }

  /**
   * 处理送物订单更新事件
   */
  private async handleDeliveryOrderUpdated(data: any): Promise<void> {
    const { orderId, hotelId, roomId } = data;
    
    try {
      // 清除送物订单列表缓存
      await CacheService.deletePattern(`delivery:list:${hotelId}*`);
      
      // 清除送物订单详情缓存
      await CacheService.delete(CacheService.deliveryKeys.info(orderId));
      
      // 清除房间相关缓存
      if (roomId) {
        await CacheService.delete(CacheService.roomKeys.info(roomId));
      }
      
      logger.info(`[缓存失效] 送物订单 ${orderId} 更新，已清除相关缓存`);
    } catch (error) {
      logger.error(`[缓存失效] 处理送物订单更新事件失败:`, error.message);
    }
  }

  /**
   * 处理维修工单更新事件
   */
  private async handleMaintenanceTicketUpdated(data: any): Promise<void> {
    const { ticketId, hotelId, roomId } = data;
    
    try {
      // 清除维修工单列表缓存
      await CacheService.deletePattern(`maintenance:list:${hotelId}*`);
      
      // 清除维修工单详情缓存
      await CacheService.delete(CacheService.maintenanceKeys.info(ticketId));
      
      // 清除房间相关缓存
      if (roomId) {
        await CacheService.delete(CacheService.roomKeys.info(roomId));
        await CacheService.deletePattern(`room:list:${hotelId}*`);
      }
      
      logger.info(`[缓存失效] 维修工单 ${ticketId} 更新，已清除相关缓存`);
    } catch (error) {
      logger.error(`[缓存失效] 处理维修工单更新事件失败:`, error.message);
    }
  }

  /**
   * 处理房间状态变更事件
   */
  private async handleRoomStatusChanged(data: any): Promise<void> {
    const { roomId, hotelId } = data;
    
    try {
      // 清除房间详情缓存
      await CacheService.delete(CacheService.roomKeys.info(roomId));
      
      // 清除房间列表缓存
      await CacheService.deletePattern(`room:list:${hotelId}*`);
      
      // 清除设备列表缓存（因为设备可能关联房间）
      await CacheService.deletePattern(`device:list:${hotelId}*`);
      
      logger.info(`[缓存失效] 房间 ${roomId} 状态变更，已清除相关缓存`);
    } catch (error) {
      logger.error(`[缓存失效] 处理房间状态变更事件失败:`, error.message);
    }
  }

  /**
   * 手动触发缓存失效
   */
  public async invalidateCache(pattern: string): Promise<void> {
    try {
      await CacheService.deletePattern(pattern);
      logger.info(`[缓存失效] 手动清除缓存模式: ${pattern}`);
    } catch (error) {
      logger.error(`[缓存失效] 手动清除缓存失败:`, error.message);
    }
  }
}

// 导出单例实例
export const cacheInvalidationService = CacheInvalidationService.getInstance();