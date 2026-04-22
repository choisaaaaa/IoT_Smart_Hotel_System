<template>
  <a-layout class="reception-layout">
    <a-layout-sider
      v-model:collapsed="collapsed"
      :trigger="null"
      collapsible
      width="240"
      theme="light"
      class="reception-sider"
    >
      <div class="sider-header" @click="$router.push('/reception/dashboard')">
        <div class="sider-logo">
          <CustomerServiceOutlined />
        </div>
        <div v-show="!collapsed" class="sider-brand">
          <span class="brand-title">前台工作台</span>
          <span class="brand-hotel">{{ hotelStore.hotelInfo?.hotel_name || '慧宿智联' }}</span>
        </div>
      </div>
      
      <a-menu
        v-model:selectedKeys="selectedKeys"
        mode="inline"
        theme="light"
        @click="handleMenuClick"
        class="reception-menu"
      >
        <a-menu-item key="/reception/dashboard">
          <template #icon><DashboardOutlined /></template>
          <span>前台总览</span>
        </a-menu-item>
        
        <a-menu-item key="/reception/reception-center">
          <template #icon><BellOutlined /></template>
          <span>接待中心</span>
        </a-menu-item>
        
        <a-menu-item key="/reception/device-management">
          <template #icon><ControlOutlined /></template>
          <span>设备管理</span>
        </a-menu-item>
        
        <a-menu-item key="/reception/bookings">
          <template #icon><CalendarOutlined /></template>
          <span>预订管理</span>
        </a-menu-item>
        
        <a-menu-item key="/reception/room-availability">
          <template #icon><ApartmentOutlined /></template>
          <span>客房余量</span>
        </a-menu-item>
        
        <a-menu-item key="/reception/workorders">
          <template #icon><ToolOutlined /></template>
          <span>工单处理</span>
        </a-menu-item>
        
        <a-menu-item key="/reception/delivery">
          <template #icon><SendOutlined /></template>
          <span>客房送物</span>
        </a-menu-item>
        
        <a-menu-item key="/reception/voice-calls">
          <template #icon><PhoneOutlined /></template>
          <span>语音通话</span>
        </a-menu-item>
        
        <a-menu-item key="/reception/environment">
          <template #icon><EnvironmentOutlined /></template>
          <span>环境监测</span>
        </a-menu-item>
        
        <a-menu-item key="/reception/price-calendar">
          <template #icon><DollarOutlined /></template>
          <span>价格日历</span>
        </a-menu-item>
        
        <a-menu-item key="/reception/coupons">
          <template #icon><TagOutlined /></template>
          <span>优惠券</span>
        </a-menu-item>
        
        <a-menu-item key="/reception/bills">
          <template #icon><FileTextOutlined /></template>
          <span>账单报表</span>
        </a-menu-item>
      </a-menu>
      
      <div v-show="!collapsed" class="sider-footer">
        <div class="work-status">
          <span class="status-indicator online"></span>
          <span class="status-text">工作中</span>
        </div>
        <div class="work-time">{{ currentTime }}</div>
      </div>
    </a-layout-sider>

    <a-layout>
      <a-layout-header class="reception-header" :style="{ marginLeft: collapsed ? '80px' : '240px' }">
        <div class="header-left">
          <MenuUnfoldOutlined v-if="collapsed" class="trigger" @click="collapsed = false" />
          <MenuFoldOutlined v-else class="trigger" @click="collapsed = true" />
          <a-breadcrumb class="breadcrumb">
            <a-breadcrumb-item>{{ currentTitle }}</a-breadcrumb-item>
          </a-breadcrumb>
        </div>
        
        <div class="header-right">
          <!-- 报警通知按钮 - 醒目显示 -->
          <a-popover 
            v-model:open="alarmNotificationVisible" 
            trigger="click" 
            placement="bottomRight" 
            :overlayStyle="{ width: '420px' }"
            class="alarm-notification-popover"
          >
            <template #content>
              <div class="alarm-notification-panel">
                <div class="alarm-notification-header">
                  <span class="alarm-notification-title">
                    <WarningFilled class="alarm-title-icon" /> 报警通知
                  </span>
                  <a-button type="link" size="small" @click="clearAllAlarms">
                    全部标记已读
                  </a-button>
                </div>
                <a-divider style="margin: 12px 0;" />
                <div v-if="alarmNotifications.length === 0" class="alarm-notification-empty">
                  <CheckCircleOutlined class="empty-icon" />
                  <p>暂无报警</p>
                </div>
                <div v-else class="alarm-notification-list">
                  <div
                    v-for="item in alarmNotifications"
                    :key="item.id"
                    class="alarm-notification-item"
                    :class="{ 
                      unread: !item.read, 
                      critical: item.level === 'critical',
                      'animate-pulse': item.level === 'critical' && !item.read 
                    }"
                    @click="handleAlarmClick(item)"
                  >
                    <div class="alarm-notification-icon" :class="item.level">
                      <FireFilled v-if="item.type === 'fire_alarm'" />
                      <AlertFilled v-else-if="item.type === 'sos_alarm'" />
                      <WarningFilled v-else />
                    </div>
                    <div class="alarm-notification-content">
                      <div class="alarm-notification-title-text">
                        {{ item.title }}
                        <a-tag v-if="item.level === 'critical'" color="red" size="small">紧急</a-tag>
                      </div>
                      <div class="alarm-notification-desc">{{ item.desc }}</div>
                      <div class="alarm-notification-time">{{ item.time }}</div>
                    </div>
                    <div v-if="!item.read" class="alarm-notification-dot"></div>
                  </div>
                </div>
                <div v-if="alarmNotifications.length > 0" class="alarm-notification-footer">
                  <a-button type="primary" danger block @click="goToAlarmPanel">
                    <SafetyOutlined /> 前往报警处理中心
                  </a-button>
                </div>
              </div>
            </template>
            <a-badge :count="unreadAlarmCount" :offset="[-2, 4]">
              <div class="header-icon-btn alarm-btn" :class="{ 
                active: unreadAlarmCount > 0,
                'alarm-critical': hasCriticalAlarm 
              }">
                <WarningFilled v-if="hasCriticalAlarm" />
                <BellOutlined v-else />
              </div>
            </a-badge>
          </a-popover>

          <!-- 普通消息通知 -->
          <a-popover 
            v-model:open="notificationVisible" 
            trigger="click" 
            placement="bottomRight" 
            :overlayStyle="{ width: '380px' }"
            class="notification-popover"
          >
            <template #content>
              <div class="notification-panel">
                <div class="notification-header">
                  <span class="notification-title">
                    <BellOutlined /> 消息通知
                  </span>
                  <a-button type="link" size="small" @click="clearAllNotifications">
                    全部已读
                  </a-button>
                </div>
                <a-divider style="margin: 12px 0;" />
                <div v-if="notificationItems.length === 0" class="notification-empty">
                  <CheckCircleOutlined class="empty-icon" />
                  <p>暂无新消息</p>
                </div>
                <div v-else class="notification-list">
                  <div
                    v-for="item in notificationItems"
                    :key="item.id"
                    class="notification-item"
                    :class="{ unread: !item.read }"
                    @click="handleNotificationClick(item)"
                  >
                    <div class="notification-icon" :class="item.type">
                      <ToolOutlined v-if="item.type === 'maintenance'" />
                      <SendOutlined v-else-if="item.type === 'delivery'" />
                      <AlertOutlined v-else-if="item.type === 'environment'" />
                      <InfoCircleOutlined v-else />
                    </div>
                    <div class="notification-content">
                      <div class="notification-title-text">{{ item.title }}</div>
                      <div class="notification-desc">{{ item.desc }}</div>
                    </div>
                    <div v-if="!item.read" class="notification-dot"></div>
                  </div>
                </div>
              </div>
            </template>
            <a-badge :count="unreadCount" :offset="[-2, 4]">
              <div class="header-icon-btn" :class="{ active: unreadCount > 0 }">
                <BellOutlined />
              </div>
            </a-badge>
          </a-popover>
          
          <div class="connection-badge" :class="{ online: appStore.connected }">
            <WifiOutlined v-if="appStore.connected" />
            <DisconnectOutlined v-else />
            <span>{{ appStore.connected ? '在线' : '离线' }}</span>
          </div>
          
          <a-dropdown placement="bottomRight" :overlayStyle="{ minWidth: '180px' }">
            <div class="user-profile">
              <a-avatar 
                :src="appStore.resolveImageUrl(appStore.userInfo?.avatar)" 
                class="user-avatar"
              >
                <template #icon><UserOutlined /></template>
              </a-avatar>
              <div v-if="!collapsed" class="user-info">
                <span class="user-name">{{ appStore.userInfo?.username || '前台员工' }}</span>
                <span class="user-role">{{ appStore.userInfo?.role === CANONICAL_ROLES.SYSTEM_ADMIN ? '系统管理员' : '前台接待' }}</span>
              </div>
              <DownOutlined class="dropdown-icon" />
            </div>
            <template #overlay>
              <a-menu class="profile-menu">
                <a-menu-item key="profile" @click="$router.push('/guest/profile')">
                  <UserOutlined /> 个人资料
                </a-menu-item>
                <a-menu-item 
                  v-if="appStore.userInfo?.role === CANONICAL_ROLES.SYSTEM_ADMIN || appStore.userInfo?.role === CANONICAL_ROLES.HOTEL_ADMIN" 
                  key="hotel-admin" 
                  @click="$router.push('/hotel-admin')"
                >
                  <SettingOutlined /> 管理后台
                </a-menu-item>
                <a-menu-item 
                  v-if="appStore.userInfo?.role === CANONICAL_ROLES.SYSTEM_ADMIN" 
                  key="system" 
                  @click="$router.push('/system/dashboard')"
                >
                  <SwapOutlined /> 切换系统端
                </a-menu-item>
                <a-menu-item 
                  v-if="appStore.userInfo?.role === CANONICAL_ROLES.SYSTEM_ADMIN || appStore.userInfo?.role === CANONICAL_ROLES.HOTEL_ADMIN" 
                  key="guest" 
                  @click="$router.push('/guest/booking')"
                >
                  <HomeOutlined /> 切换顾客端
                </a-menu-item>
                <a-menu-divider />
                <a-menu-item key="logout" @click="handleLogout" class="logout-item">
                  <LogoutOutlined /> 退出登录
                </a-menu-item>
              </a-menu>
            </template>
          </a-dropdown>
        </div>
      </a-layout-header>

      <a-layout-content class="reception-content" :style="{ marginLeft: collapsed ? '96px' : '256px' }">
        <router-view />
      </a-layout-content>

      <a-layout-footer class="reception-footer" :style="{ marginLeft: collapsed ? '80px' : '240px' }">
        <div class="footer-inner">
          <span class="footer-text">慧宿智联 · 智慧酒店管理系统</span>
          <span class="footer-divider">|</span>
          <span class="footer-version">前台端 v2.2.0</span>
        </div>
      </a-layout-footer>
    </a-layout>
  </a-layout>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  CustomerServiceOutlined,
  DashboardOutlined,
  CalendarOutlined,
  ApartmentOutlined,
  ToolOutlined,
  SendOutlined,
  PhoneOutlined,
  MenuFoldOutlined,
  MenuUnfoldOutlined,
  BellOutlined,
  LogoutOutlined,
  EnvironmentOutlined,
  TagOutlined,
  DollarOutlined,
  CheckCircleOutlined,
  AlertOutlined,
  UserOutlined,
  SwapOutlined,
  ControlOutlined,
  FileTextOutlined,
  DownOutlined,
  SettingOutlined,
  WifiOutlined,
  DisconnectOutlined,
  InfoCircleOutlined,
  WarningFilled,
  FireFilled,
  AlertFilled,
  SafetyOutlined
} from '@ant-design/icons-vue'
import { message } from 'ant-design-vue'
import { useAppStore } from '@/stores/app'
import { useHotelStore } from '@/stores/hotel'
import { authService, CANONICAL_ROLES } from '@/api/auth'
import { maintenanceApi } from '@/api/maintenance'
import { deliveryApi } from '@/api/delivery'
import { environmentApi } from '@/api/environment'
import { initWebSocket } from '@/utils/websocket'
import request from '@/api/request'
import dayjs from 'dayjs'

const route = useRoute()
const router = useRouter()
const appStore = useAppStore()
const hotelStore = useHotelStore()

appStore.initUserInfo()

const collapsed = ref(false)
const selectedKeys = ref<string[]>([route.path])
const notificationVisible = ref(false)
const alarmNotificationVisible = ref(false)
const currentTime = ref(dayjs().format('HH:mm'))

let timeInterval: ReturnType<typeof setInterval>

onMounted(() => {
  timeInterval = setInterval(() => {
    currentTime.value = dayjs().format('HH:mm')
  }, 60000)
})

onUnmounted(() => {
  if (timeInterval) clearInterval(timeInterval)
})

async function handleLogout() {
  await authService.logout()
  router.push('/guest/booking')
}

async function returnToSystem() {
  try {
    const res = await request.post('/auth/switch-hotel', { hotel_id: 0 })
    if (res.data.token) {
      localStorage.setItem('auth_token', res.data.token)
      if (appStore.userInfo) {
        appStore.setUserInfo({
          ...appStore.userInfo,
          hotel_id: 0,
          hotel_name: '慧宿智联集团总部'
        })
      }
      hotelStore.setCurrentHotelId(0)
      router.push('/system/dashboard')
    }
  } catch (error) {
    router.push('/system/dashboard')
  }
}

function setupGlobalWebSocket() {
  initWebSocket()
}

onUnmounted(() => {})

interface NotificationItem {
  id: string
  type: 'maintenance' | 'delivery' | 'environment' | 'info'
  title: string
  desc: string
  route: string
  read: boolean
}

interface AlarmNotificationItem {
  id: string
  type: 'fire_alarm' | 'sos_alarm' | 'smoke' | 'temperature' | 'manual'
  level: 'critical' | 'high' | 'medium' | 'low'
  title: string
  desc: string
  time: string
  read: boolean
  deviceId?: string
  location?: string
}

const notificationItems = ref<NotificationItem[]>([])
const alarmNotifications = ref<AlarmNotificationItem[]>([])

const unreadCount = computed(() => notificationItems.value.filter(n => !n.read).length)
const unreadAlarmCount = computed(() => alarmNotifications.value.filter(n => !n.read).length)
const hasCriticalAlarm = computed(() => alarmNotifications.value.some(n => n.level === 'critical' && !n.read))
const currentTitle = computed(() => (route.meta.title as string) || '')

watch(() => route.path, (path) => {
  selectedKeys.value = [path]
})

function handleMenuClick({ key }: { key: string }) {
  router.push(key)
}

onMounted(async () => {
  try {
    await hotelStore.fetchHotelInfo()
    setupGlobalWebSocket()
  } catch (error) {}
})

async function loadNotifications() {
  const userInfo = appStore.userInfo
  const userRole = userInfo?.role
  if (!userRole || userRole === 'customer') {
    notificationItems.value = []
    return
  }

  try {
    const [maintenanceRes, deliveryRes, envRes] = await Promise.allSettled([
      maintenanceApi.getList({ status: 'pending', pageSize: 5 }),
      deliveryApi.getList({ status: 'pending', pageSize: 5 }),
      environmentApi.getEventLogs({ severity: 'warning', limit: 5 })
    ])

    const items: NotificationItem[] = []

    if (maintenanceRes.status === 'fulfilled') {
      const res = maintenanceRes.value as any
      const list = res.data?.list || res.data?.data?.list || []
      const total = Number(res.data?.total || res.data?.data?.total || 0)
      if (total > 0) {
        items.push({
          id: 'maintenance-pending',
          type: 'maintenance',
          title: `维修工单 (${total})`,
          desc: list[0]?.fault_description?.substring(0, 30) || `共${total}条待处理`,
          route: '/reception/workorders',
          read: false
        })
      }
    }

    if (deliveryRes.status === 'fulfilled') {
      const res = deliveryRes.value as any
      const list = res.data?.list || res.data?.data?.list || []
      const total = Number(res.data?.total || res.data?.data?.total || 0)
      if (total > 0) {
        items.push({
          id: 'delivery-pending',
          type: 'delivery',
          title: `送物订单 (${total})`,
          desc: list[0]?.item_name || `共${total}条待处理`,
          route: '/reception/delivery',
          read: false
        })
      }
    }

    if (envRes.status === 'fulfilled') {
      try {
        const res = envRes.value as any
        const logs = res.data?.logs || res.data?.data?.logs || []
        const unresolved = logs.filter((l: any) => !l.resolved)
        if (unresolved.length > 0) {
          items.push({
            id: 'environment-warning',
            type: 'environment',
            title: `环境告警 (${unresolved.length})`,
            desc: unresolved[0]?.title || `${unresolved.length}条异常`,
            route: '/reception/environment',
            read: false
          })
        }
      } catch (_) {}
    }

    notificationItems.value = items
  } catch (error) {
    notificationItems.value = []
  }
}

function handleNotificationClick(item: NotificationItem) {
  item.read = true
  notificationVisible.value = false
  router.push(item.route)
}

function clearAllNotifications() {
  notificationItems.value.forEach(n => n.read = true)
}

function clearAllAlarms() {
  alarmNotifications.value.forEach(n => n.read = true)
}

function handleAlarmClick(item: AlarmNotificationItem) {
  item.read = true
  alarmNotificationVisible.value = false
  // 显示报警弹窗
  appStore.showAlarmModal({
    id: item.id,
    type: item.type,
    level: item.level,
    deviceId: item.deviceId,
    location: item.location,
    message: item.desc,
    timestamp: new Date().toISOString()
  })
}

function goToAlarmPanel() {
  alarmNotificationVisible.value = false
  router.push('/reception/environment')
}

// 加载报警通知
async function loadAlarmNotifications() {
  try {
    const res: any = await environmentApi.getFireAlarms({ status: 'active' })
    const alarms = res.data?.alarms || []
    
    alarmNotifications.value = alarms.map((alarm: any) => ({
      id: String(alarm.id),
      type: alarm.alarm_type || 'fire_alarm',
      level: alarm.severity || 'high',
      title: `${alarm.room_number || '未知房间'} - ${getAlarmTypeText(alarm.alarm_type)}`,
      desc: alarm.description || '检测到异常情况',
      time: dayjs(alarm.triggered_at).fromNow(),
      read: false,
      deviceId: alarm.device_id,
      location: alarm.room_number
    }))
  } catch (error) {
    console.error('加载报警通知失败:', error)
  }
}

function getAlarmTypeText(type: string): string {
  const texts: Record<string, string> = {
    fire_alarm: '消防报警',
    sos_alarm: 'SOS报警',
    smoke: '烟雾探测',
    temperature: '温度异常',
    manual: '手动报警'
  }
  return texts[type] || type
}

// WebSocket消息处理
function handleWebSocketMessage(data: any) {
  if (data.event_type === 'fire_alarm' || data.event_type === 'sos_alarm') {
    // 添加新的报警通知
    const newAlarm: AlarmNotificationItem = {
      id: data.alarm_id || Date.now().toString(),
      type: data.event_type,
      level: data.level || 'critical',
      title: `${data.data?.room_number || data.data?.floor_id || '未知位置'} - ${getAlarmTypeText(data.event_type)}`,
      desc: data.data?.message || '紧急报警',
      time: '刚刚',
      read: false,
      deviceId: data.device_id,
      location: data.data?.room_number || data.data?.floor_id
    }
    
    // 插入到最前面
    alarmNotifications.value.unshift(newAlarm)
    
    // 显示报警弹窗
    appStore.showAlarmModal({
      id: newAlarm.id,
      type: newAlarm.type,
      level: newAlarm.level,
      deviceId: newAlarm.deviceId,
      location: newAlarm.location,
      message: newAlarm.desc,
      timestamp: new Date().toISOString()
    })
    
    // 播放提示音
    playNotificationSound()
  }
}

function playNotificationSound() {
  try {
    const audio = new Audio('/notification.mp3')
    audio.play().catch(() => {})
  } catch (error) {}
}

onMounted(() => {
  loadNotifications()
  loadAlarmNotifications()
  const userRole = appStore.userInfo?.role
  if (userRole && userRole !== 'customer') {
    setInterval(loadNotifications, 30000)
    setInterval(loadAlarmNotifications, 10000) // 报警检查更频繁
  }
})
</script>

<style scoped>
.reception-layout {
  min-height: 100vh;
  background: var(--hotel-bg);
}

.reception-sider {
  position: fixed;
  left: 0;
  top: 0;
  bottom: 0;
  z-index: 100;
  box-shadow: 2px 0 12px rgba(26, 43, 74, 0.08);
  background: #fff;
}

.sider-header {
  height: 72px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  cursor: pointer;
  border-bottom: 1px solid var(--hotel-border);
  padding: 0 20px;
  transition: all 0.3s;
}

.sider-header:hover {
  background: var(--hotel-bg-secondary);
}

.sider-logo {
  width: 44px;
  height: 44px;
  background: linear-gradient(135deg, var(--hotel-primary) 0%, var(--hotel-primary-light) 100%);
  border-radius: var(--hotel-radius);
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-size: 22px;
  flex-shrink: 0;
}

.sider-brand {
  display: flex;
  flex-direction: column;
  line-height: 1.3;
  overflow: hidden;
}

.brand-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--hotel-primary);
}

.brand-hotel {
  font-size: 12px;
  color: var(--hotel-text-muted);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.reception-menu {
  border-right: none;
  padding: 12px 0;
}

.reception-menu :deep(.ant-menu-item) {
  margin: 4px 12px;
  border-radius: var(--hotel-radius-sm);
  height: 44px;
  line-height: 44px;
}

.reception-menu :deep(.ant-menu-item-selected) {
  background: var(--hotel-primary) !important;
  color: #fff !important;
  border-right: none !important;
}

.reception-menu :deep(.ant-menu-item-selected .anticon) {
  color: #fff;
}

.sider-footer {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  padding: 16px 20px;
  border-top: 1px solid var(--hotel-border);
  background: var(--hotel-bg-secondary);
}

.work-status {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 4px;
}

.status-indicator {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--hotel-text-muted);
}

.status-indicator.online {
  background: var(--hotel-success);
  animation: pulse 2s infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

.status-text {
  font-size: 13px;
  font-weight: 500;
  color: var(--hotel-text);
}

.work-time {
  font-size: 12px;
  color: var(--hotel-text-muted);
  padding-left: 16px;
}

.reception-header {
  background: #fff;
  padding: 0 24px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  box-shadow: var(--hotel-shadow-sm);
  z-index: 99;
  height: 72px;
  position: sticky;
  top: 0;
  transition: margin-left 0.2s;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 16px;
}

.trigger {
  font-size: 18px;
  cursor: pointer;
  padding: 8px;
  border-radius: var(--hotel-radius-sm);
  color: var(--hotel-text-secondary);
  transition: all 0.3s;
}

.trigger:hover {
  background: var(--hotel-bg-secondary);
  color: var(--hotel-primary);
}

.breadcrumb {
  font-size: 14px;
}

.breadcrumb :deep(.ant-breadcrumb-link) {
  display: flex;
  align-items: center;
  gap: 6px;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 16px;
}

.header-icon-btn {
  width: 40px;
  height: 40px;
  border-radius: var(--hotel-radius-sm);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 18px;
  color: var(--hotel-text-secondary);
  cursor: pointer;
  transition: all 0.3s;
}

.header-icon-btn:hover,
.header-icon-btn.active {
  background: var(--hotel-bg-secondary);
  color: var(--hotel-primary);
}

.connection-badge {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 12px;
  background: var(--hotel-bg-secondary);
  border-radius: 20px;
  font-size: 13px;
  color: var(--hotel-text-muted);
}

.connection-badge.online {
  color: var(--hotel-success);
}

.user-profile {
  display: flex;
  align-items: center;
  gap: 10px;
  cursor: pointer;
  padding: 6px 12px;
  border-radius: var(--hotel-radius);
  transition: all 0.3s;
  border: 1px solid var(--hotel-border);
}

.user-profile:hover {
  background: var(--hotel-bg-secondary);
}

.user-avatar {
  border: 2px solid var(--hotel-gold);
}

.user-info {
  display: flex;
  flex-direction: column;
  line-height: 1.3;
}

.user-name {
  font-size: 14px;
  font-weight: 500;
  color: var(--hotel-text);
}

.user-role {
  font-size: 12px;
  color: var(--hotel-text-muted);
}

.dropdown-icon {
  font-size: 12px;
  color: var(--hotel-text-muted);
}

.profile-menu {
  border-radius: var(--hotel-radius);
}

.logout-item {
  color: var(--hotel-error);
}

.reception-content {
  margin: 24px;
  margin-left: 264px;
  min-height: calc(100vh - 72px - 80px);
  transition: margin-left 0.2s;
}

.reception-footer {
  text-align: center;
  padding: 20px;
  transition: margin-left 0.2s;
}

.footer-inner {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  color: var(--hotel-text-muted);
  font-size: 13px;
}

.footer-divider {
  color: var(--hotel-border);
}

/* 通知面板 */
.notification-panel {
  margin: -12px -16px;
}

.notification-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0 4px;
}

.notification-title {
  font-weight: 600;
  font-size: 15px;
  color: var(--hotel-primary);
  display: flex;
  align-items: center;
  gap: 8px;
}

.notification-empty {
  text-align: center;
  padding: 40px 0;
  color: var(--hotel-text-muted);
}

.empty-icon {
  font-size: 48px;
  color: var(--hotel-border);
  margin-bottom: 12px;
}

.notification-list {
  max-height: 360px;
  overflow-y: auto;
}

.notification-item {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 14px;
  cursor: pointer;
  border-radius: var(--hotel-radius-sm);
  transition: all 0.3s;
  position: relative;
}

.notification-item:hover {
  background: var(--hotel-bg-secondary);
}

.notification-item.unread {
  background: rgba(201, 169, 98, 0.05);
}

.notification-icon {
  width: 36px;
  height: 36px;
  border-radius: var(--hotel-radius-sm);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 16px;
  flex-shrink: 0;
}

.notification-icon.maintenance {
  background: rgba(243, 156, 18, 0.1);
  color: var(--hotel-warning);
}

.notification-icon.delivery {
  background: rgba(52, 152, 219, 0.1);
  color: var(--hotel-info);
}

.notification-icon.environment {
  background: rgba(231, 76, 60, 0.1);
  color: var(--hotel-error);
}

.notification-icon.info {
  background: rgba(201, 169, 98, 0.1);
  color: var(--hotel-gold);
}

.notification-content {
  flex: 1;
  min-width: 0;
}

.notification-title-text {
  font-size: 14px;
  font-weight: 500;
  color: var(--hotel-text);
  margin-bottom: 4px;
}

.notification-desc {
  font-size: 12px;
  color: var(--hotel-text-muted);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.notification-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--hotel-gold);
  flex-shrink: 0;
  margin-top: 4px;
}

/* 报警通知样式 */
.alarm-btn {
  position: relative;
}

.alarm-btn.alarm-critical {
  background: #ff4d4f !important;
  color: white !important;
  animation: alarm-pulse 1s infinite;
}

@keyframes alarm-pulse {
  0%, 100% { 
    background: #ff4d4f;
    box-shadow: 0 0 0 0 rgba(255, 77, 79, 0.7);
  }
  50% { 
    background: #ff7875;
    box-shadow: 0 0 0 10px rgba(255, 77, 79, 0);
  }
}

.alarm-notification-panel {
  margin: -12px -16px;
}

.alarm-notification-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0 4px;
}

.alarm-notification-title {
  font-weight: 600;
  font-size: 15px;
  color: #ff4d4f;
  display: flex;
  align-items: center;
  gap: 8px;
}

.alarm-title-icon {
  font-size: 18px;
}

.alarm-notification-empty {
  text-align: center;
  padding: 40px 0;
  color: var(--hotel-text-muted);
}

.alarm-notification-list {
  max-height: 360px;
  overflow-y: auto;
}

.alarm-notification-item {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 14px;
  cursor: pointer;
  border-radius: var(--hotel-radius-sm);
  transition: all 0.3s;
  position: relative;
  border-left: 3px solid transparent;
}

.alarm-notification-item:hover {
  background: var(--hotel-bg-secondary);
}

.alarm-notification-item.unread {
  background: rgba(255, 77, 79, 0.05);
  border-left-color: #ff4d4f;
}

.alarm-notification-item.critical {
  background: rgba(255, 77, 79, 0.1);
}

.alarm-notification-item.animate-pulse {
  animation: item-pulse 2s infinite;
}

@keyframes item-pulse {
  0%, 100% { background: rgba(255, 77, 79, 0.1); }
  50% { background: rgba(255, 77, 79, 0.2); }
}

.alarm-notification-icon {
  width: 40px;
  height: 40px;
  border-radius: var(--hotel-radius-sm);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
  flex-shrink: 0;
}

.alarm-notification-icon.critical {
  background: rgba(255, 77, 79, 0.15);
  color: #ff4d4f;
}

.alarm-notification-icon.high {
  background: rgba(250, 173, 20, 0.15);
  color: #faad14;
}

.alarm-notification-icon.medium,
.alarm-notification-icon.low {
  background: rgba(52, 152, 219, 0.15);
  color: #3498db;
}

.alarm-notification-content {
  flex: 1;
  min-width: 0;
}

.alarm-notification-title-text {
  font-size: 14px;
  font-weight: 600;
  color: var(--hotel-text);
  margin-bottom: 4px;
  display: flex;
  align-items: center;
  gap: 8px;
}

.alarm-notification-desc {
  font-size: 12px;
  color: var(--hotel-text-muted);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  margin-bottom: 4px;
}

.alarm-notification-time {
  font-size: 11px;
  color: #999;
}

.alarm-notification-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: #ff4d4f;
  flex-shrink: 0;
  margin-top: 4px;
  animation: dot-pulse 1s infinite;
}

@keyframes dot-pulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.5; transform: scale(1.2); }
}

.alarm-notification-footer {
  padding: 16px;
  border-top: 1px solid #f0f0f0;
}
</style>
