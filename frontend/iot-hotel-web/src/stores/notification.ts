import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { maintenanceApi } from '@/api/maintenance'
import { deliveryApi } from '@/api/delivery'
import { environmentApi } from '@/api/environment'
import { bookingApi } from '@/api/booking'
import { callApi } from '@/api/call'
import { useAppStore } from '@/stores/app'
import dayjs from 'dayjs'

export interface NotificationItem {
  id: string
  type: 'maintenance' | 'delivery' | 'environment' | 'booking' | 'call' | 'alarm' | 'info'
  level?: 'critical' | 'high' | 'medium' | 'low'
  title: string
  desc: string
  route: string
  read: boolean
  time: string
  date: string 
  createdAt: string // ISO格式时间字符串，用于24小时自动清理逻辑
  deviceId?: string
  location?: string
}

export const useNotificationStore = defineStore('notification', () => {
  const notifications = ref<NotificationItem[]>([])
  
  // 各模块未读数映射
  const moduleUnreadCounts = ref<Record<string, number>>({
    '/reception/workorders': 0,
    '/reception/delivery': 0,
    '/reception/environment': 0,
    '/reception/bookings': 0,
    '/reception/voice-calls': 0,
    '/reception/reception-center': 0
  })

  const totalUnreadCount = computed(() => {
    return Object.values(moduleUnreadCounts.value).reduce((a, b) => a + b, 0)
  })

  const unreadNotifications = computed(() => notifications.value.filter(n => !n.read))
  const unreadCount = computed(() => unreadNotifications.value.length)
  
  const hasCriticalAlarm = computed(() => 
    notifications.value.some(n => n.type === 'alarm' && n.level === 'critical' && !n.read)
  )

  /**
   * 自动清除逻辑：自动移除超过24小时的通知
   */
  function dailyClear() {
    const now = dayjs()
    notifications.value = notifications.value.filter(n => {
      // 如果没有 createdAt，则根据 date 和 time 尝试还原，或者直接保留（兼容旧数据）
      const createTime = n.createdAt ? dayjs(n.createdAt) : dayjs(`${n.date} ${n.time}`)
      return now.diff(createTime, 'hour') < 24
    })
  }

  /**
   * 加载所有模块的未读消息数
   */
  async function fetchAllUnreadCounts() {
    try {
      const appStore = useAppStore()
      const role = appStore.userInfo?.role
      const isStaffOrAdmin = ['hotel_admin', 'system_admin', 'staff'].includes(role)

      const apiCalls: Promise<any>[] = []
      const apiNames: string[] = []

      if (isStaffOrAdmin) {
        apiCalls.push(
          maintenanceApi.getList({ status: 'pending', pageSize: 1 }),
          deliveryApi.getList({ status: 'pending', pageSize: 1 }),
          environmentApi.getEventLogs({ severity: 'warning', limit: 1 }),
          bookingApi.getBookingList({ status: 'pending', pageSize: 1 }),
          callApi.getActive()
        )
        apiNames.push('maintenance', 'delivery', 'environment', 'booking', 'call')
      } else if (role === 'customer' || role === 'guest') {
        apiCalls.push(
          bookingApi.getBookingList({ status: 'pending', pageSize: 1 })
        )
        apiNames.push('booking')
      }

      if (apiCalls.length === 0) return

      const results = await Promise.allSettled(apiCalls)

      for (let i = 0; i < results.length; i++) {
        const result = results[i]
        const name = apiNames[i]
        if (result.status !== 'fulfilled') continue
        const res = result.value as any

        if (name === 'maintenance') {
          moduleUnreadCounts.value['/reception/workorders'] = Number(res.data?.total || res.data?.data?.total || 0)
        } else if (name === 'delivery') {
          moduleUnreadCounts.value['/reception/delivery'] = Number(res.data?.total || res.data?.data?.total || 0)
        } else if (name === 'environment') {
          const logs = res.data?.logs || res.data?.data?.logs || []
          moduleUnreadCounts.value['/reception/environment'] = logs.filter((l: any) => !l.resolved).length
        } else if (name === 'booking') {
          const total = Number(res.data?.total || res.data?.data?.total || 0)
          moduleUnreadCounts.value['/reception/bookings'] = total
          moduleUnreadCounts.value['/reception/reception-center'] = total
        } else if (name === 'call') {
          const activeCalls = res.data?.items || []
          moduleUnreadCounts.value['/reception/voice-calls'] = activeCalls.length
        }
      }

      dailyClear()
      updateNotificationItems()
    } catch (error) {
      console.error('Failed to fetch unread counts:', error)
    }
  }

  /**
   * 更新通知面板中的项 (根据汇总数据生成)
   */
  function updateNotificationItems() {
    // 基础模块汇总通知
    const today = dayjs().format('YYYY-MM-DD')
    const now = dayjs().format('HH:mm')

    const syncModuleNotification = (id: string, type: NotificationItem['type'], title: string, count: number, route: string) => {
      const index = notifications.value.findIndex(n => n.id === id)
      if (count > 0) {
        const item: NotificationItem = {
          id,
          type,
          title: `${title} (${count})`,
          desc: `您有 ${count} 条待处理的${title}`,
          route,
          read: false,
          time: now,
          date: today,
          createdAt: dayjs().toISOString()
        }
        if (index > -1) {
          notifications.value[index] = item
        } else {
          notifications.value.unshift(item)
        }
      } else if (index > -1) {
        notifications.value.splice(index, 1)
      }
    }

    syncModuleNotification('maintenance-pending', 'maintenance', '维修工单', moduleUnreadCounts.value['/reception/workorders'], '/reception/workorders')
    syncModuleNotification('delivery-pending', 'delivery', '送物订单', moduleUnreadCounts.value['/reception/delivery'], '/reception/delivery')
    syncModuleNotification('environment-warning', 'environment', '环境告警', moduleUnreadCounts.value['/reception/environment'], '/reception/environment')
    syncModuleNotification('booking-pending', 'booking', '待办预订', moduleUnreadCounts.value['/reception/bookings'], '/reception/bookings')
    syncModuleNotification('call-active', 'call', '活跃通话', moduleUnreadCounts.value['/reception/voice-calls'], '/reception/voice-calls')
  }

  /**
   * 加载报警通知
   */
  async function fetchAlarmNotifications() {
    try {
      const res: any = await environmentApi.getFireAlarms({ status: 'active' })
      const alarms = res.data?.alarms || []
      const today = dayjs().format('YYYY-MM-DD')
      
      alarms.forEach((alarm: any) => {
        addAlarm({
          id: String(alarm.id),
          type: 'alarm',
          level: alarm.severity || 'high',
          title: `报警: ${alarm.room_number || '未知房间'}`,
          desc: alarm.description || '检测到紧急异常',
          route: '/reception/environment',
          time: dayjs(alarm.triggered_at).format('HH:mm'),
          date: dayjs(alarm.triggered_at).format('YYYY-MM-DD'),
          createdAt: alarm.triggered_at || dayjs().toISOString(),
          read: false,
          deviceId: alarm.device_id,
          location: alarm.room_number
        })
      })
      dailyClear()
    } catch (error) {
      console.error('Failed to fetch alarm notifications:', error)
    }
  }

  function addAlarm(alarm: Partial<NotificationItem>) {
    const today = dayjs().format('YYYY-MM-DD')
    const now = dayjs().format('HH:mm')
    
    const fullAlarm: NotificationItem = {
      id: alarm.id || Date.now().toString(),
      type: 'alarm',
      level: alarm.level || 'high',
      title: alarm.title || '紧急报警',
      desc: alarm.desc || '检测到异常情况',
      route: alarm.route || '/reception/environment',
      read: false,
      time: alarm.time || now,
      date: alarm.date || today,
      createdAt: alarm.createdAt || dayjs().toISOString(),
      deviceId: alarm.deviceId,
      location: alarm.location
    }

    const exists = notifications.value.some(n => n.id === fullAlarm.id)
    if (!exists) {
      notifications.value.unshift(fullAlarm)
      if (notifications.value.length > 100) notifications.value.pop()
    }
  }

  function markNotificationRead(id: string) {
    const item = notifications.value.find(n => n.id === id)
    if (item) item.read = true
  }

  function clearAllNotifications() {
    notifications.value.forEach(n => n.read = true)
  }

  return {
    notifications,
    unreadNotifications,
    unreadCount,
    moduleUnreadCounts,
    totalUnreadCount,
    hasCriticalAlarm,
    fetchAllUnreadCounts,
    fetchAlarmNotifications,
    addAlarm,
    markNotificationRead,
    clearAllNotifications,
    dailyClear
  }
})
