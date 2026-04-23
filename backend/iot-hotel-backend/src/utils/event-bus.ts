import logger from './logger';

/**
 * 简单的事件总线实现
 * 用于实现事件驱动的缓存失效机制
 */
export interface EventListener {
  (data: any): Promise<void>;
}

export class EventBus {
  private listeners: Map<string, EventListener[]> = new Map();

  /**
   * 订阅事件
   */
  on(event: string, listener: EventListener): void {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, []);
    }
    this.listeners.get(event)!.push(listener);
  }

  /**
   * 发布事件
   */
  async emit(event: string, data: any): Promise<void> {
    const eventListeners = this.listeners.get(event) || [];
    
    if (eventListeners.length === 0) {
      return;
    }

    logger.debug(`[EventBus] 发布事件: ${event}`, data);

    // 并行执行所有监听器
    const promises = eventListeners.map(async (listener, index) => {
      try {
        await listener(data);
      } catch (error) {
        logger.error(`[EventBus] 事件监听器执行失败 [${event}#${index}]:`, error.message);
      }
    });

    await Promise.all(promises);
  }

  /**
   * 取消订阅
   */
  off(event: string, listener: EventListener): void {
    const eventListeners = this.listeners.get(event);
    if (!eventListeners) return;

    const index = eventListeners.indexOf(listener);
    if (index > -1) {
      eventListeners.splice(index, 1);
    }
  }

  /**
   * 获取事件监听器数量
   */
  getListenerCount(event: string): number {
    return this.listeners.get(event)?.length || 0;
  }
}

// 全局事件总线实例
export const eventBus = new EventBus();

// 预定义事件类型
export const EVENT_TYPES = {
  // 订单相关事件
  BOOKING_STATUS_CHANGED: 'booking.status.changed',
  BOOKING_CHECKED_IN: 'booking.checked_in',
  BOOKING_CHECKED_OUT: 'booking.checked_out',
  BOOKING_CANCELLED: 'booking.cancelled',
  
  // 设备相关事件
  DEVICE_STATUS_CHANGED: 'device.status.changed',
  DEVICE_REGISTERED: 'device.registered',
  
  // 送物订单事件
  DELIVERY_ORDER_UPDATED: 'delivery.order.updated',
  
  // 维修工单事件
  MAINTENANCE_TICKET_UPDATED: 'maintenance.ticket.updated',
  
  // 房间相关事件
  ROOM_STATUS_CHANGED: 'room.status.changed'
} as const;