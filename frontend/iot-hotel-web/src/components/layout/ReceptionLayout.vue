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
  InfoCircleOutlined
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

const notificationItems = ref<NotificationItem[]>([])

const unreadCount = computed(() => notificationItems.value.filter(n => !n.read).length)
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

onMounted(() => {
  loadNotifications()
  const userRole = appStore.userInfo?.role
  if (userRole && userRole !== 'customer') {
    setInterval(loadNotifications, 30000)
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
</style>
