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
          <img :src="getLogoUrl(hotelStore.hotelInfo?.logo)" alt="Logo" class="logo-img" />
        </div>
        <div v-show="!collapsed" class="sider-brand">
          <span class="brand-title">前台工作台</span>
          <span class="brand-hotel">{{ hotelStore.hotelInfo?.hotel_name || '慧宿智联' }}</span>
        </div>
      </div>
      
      <div class="sider-menu-wrapper">
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
            <template #icon>
              <a-badge :count="notificationStore.moduleUnreadCounts['/reception/reception-center']" :offset="[10, 0]">
                <BellOutlined />
              </a-badge>
            </template>
            <span>接待中心</span>
          </a-menu-item>
          
          <a-menu-item key="/reception/device-management">
            <template #icon><ControlOutlined /></template>
            <span>设备管理</span>
          </a-menu-item>
          
          <a-menu-item key="/reception/bookings">
            <template #icon>
              <a-badge :count="notificationStore.moduleUnreadCounts['/reception/bookings']" :offset="[10, 0]">
                <CalendarOutlined />
              </a-badge>
            </template>
            <span>预订管理</span>
          </a-menu-item>
          
          <a-menu-item key="/reception/room-availability">
            <template #icon><ApartmentOutlined /></template>
            <span>客房余量</span>
          </a-menu-item>
          
          <a-menu-item key="/reception/workorders">
            <template #icon>
              <a-badge :count="notificationStore.moduleUnreadCounts['/reception/workorders']" :offset="[10, 0]">
                <ToolOutlined />
              </a-badge>
            </template>
            <span>工单处理</span>
          </a-menu-item>
          
          <a-menu-item key="/reception/delivery">
            <template #icon>
              <a-badge :count="notificationStore.moduleUnreadCounts['/reception/delivery']" :offset="[10, 0]">
                <SendOutlined />
              </a-badge>
            </template>
            <span>客房送物</span>
          </a-menu-item>
          
          <a-menu-item key="/reception/voice-calls">
            <template #icon>
              <a-badge :count="notificationStore.moduleUnreadCounts['/reception/voice-calls']" :offset="[10, 0]">
                <PhoneOutlined />
              </a-badge>
            </template>
            <span>语音通话</span>
          </a-menu-item>
          
          <a-menu-item key="/reception/environment">
            <template #icon>
              <a-badge :count="notificationStore.moduleUnreadCounts['/reception/environment']" :offset="[10, 0]">
                <EnvironmentOutlined />
              </a-badge>
            </template>
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
          
          <a-menu-item key="/reception/privilege-card">
            <template #icon><SafetyOutlined /></template>
            <span>特权卡发放</span>
          </a-menu-item>
        </a-menu>
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
          <!-- 消息中心 - 整合所有通知 -->
          <a-popover 
            v-model:open="notificationVisible" 
            trigger="click" 
            placement="bottomRight" 
            :overlayStyle="{ width: '400px' }"
            class="notification-popover"
          >
            <template #content>
              <div class="notification-panel">
                <div class="notification-header">
                  <span class="notification-title">
                  <BellOutlined /> 消息通知
                </span>
                <div class="header-actions">
                  <a-button type="link" size="small" @click="clearAllNotifications">
                    全部标记已读
                  </a-button>
                </div>
                </div>
                <a-divider style="margin: 12px 0;" />
                <div v-if="notifications.length === 0" class="notification-empty">
                  <CheckCircleOutlined class="empty-icon" />
                  <p>暂无新消息</p>
                </div>
                <div v-else class="notification-list">
                  <div
                    v-for="item in notifications"
                    :key="item.id"
                    class="notification-item"
                    :class="{ 
                      unread: !item.read,
                      critical: item.type === 'alarm' && item.level === 'critical'
                    }"
                    @click="handleNotificationClick(item)"
                  >
                    <div class="notification-icon" :class="item.type">
                      <ToolOutlined v-if="item.type === 'maintenance'" />
                      <SendOutlined v-else-if="item.type === 'delivery'" />
                      <AlertOutlined v-else-if="item.type === 'environment' || item.type === 'alarm'" />
                      <CalendarOutlined v-else-if="item.type === 'booking'" />
                      <PhoneOutlined v-else-if="item.type === 'call'" />
                      <InfoCircleOutlined v-else />
                    </div>
                    <div class="notification-content">
                      <div class="notification-title-text">
                        {{ item.title }}
                        <a-tag v-if="item.type === 'alarm'" color="red" size="small">紧急告警</a-tag>
                      </div>
                      <div class="notification-desc">{{ item.desc }}</div>
                      <div class="notification-time">{{ item.time }}</div>
                    </div>
                    <div v-if="!item.read" class="notification-dot"></div>
                  </div>
                </div>
              </div>
            </template>
            <a-badge :count="unreadCount" :offset="[-2, 4]">
              <div class="header-icon-btn" :class="{ 
                active: unreadCount > 0,
                'alarm-critical': hasCriticalAlarm 
              }">
                <WarningFilled v-if="hasCriticalAlarm" />
                <BellOutlined v-else />
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
import { useAppStore } from '@/stores/app'
import { useHotelStore } from '@/stores/hotel'
import { useNotificationStore } from '@/stores/notification'
import { authService, CANONICAL_ROLES } from '@/api/auth'
import { initWebSocket } from '@/utils/websocket'
import request from '@/api/request'
import dayjs from 'dayjs'

const route = useRoute()
const router = useRouter()
const appStore = useAppStore()
const hotelStore = useHotelStore()
const notificationStore = useNotificationStore()

const getLogoUrl = (url?: string) => {
  return appStore.resolveImageUrl(url) || '/logo-small.png'
}

appStore.initUserInfo()

const collapsed = ref(false)
const selectedKeys = ref<string[]>([route.path])
const notificationVisible = ref(false)
const currentTime = ref(dayjs().format('HH:mm'))

let timeInterval: ReturnType<typeof setInterval>

onMounted(async () => {
  try {
    await hotelStore.fetchHotelInfo()
    setupGlobalWebSocket()
    // 初始加载
    notificationStore.fetchAllUnreadCounts()
    notificationStore.fetchAlarmNotifications()
  } catch (error) {}
  
  timeInterval = setInterval(() => {
    currentTime.value = dayjs().format('HH:mm')
    // 定期刷新未读数
    notificationStore.fetchAllUnreadCounts()
  }, 60000)
})

onUnmounted(() => {
  if (timeInterval) clearInterval(timeInterval)
})

async function handleLogout() {
  await authService.logout()
  router.push('/guest/booking')
}

function setupGlobalWebSocket() {
  initWebSocket()
}

const unreadCount = computed(() => notificationStore.unreadCount)
const notifications = computed(() => notificationStore.notifications)
const hasCriticalAlarm = computed(() => notificationStore.hasCriticalAlarm)
const currentTitle = computed(() => (route.meta.title as string) || '')

watch(() => route.path, (path) => {
  selectedKeys.value = [path]
  // 切换路由时刷新未读数
  notificationStore.fetchAllUnreadCounts()
})

function handleMenuClick({ key }: { key: string }) {
  router.push(key)
}

function handleNotificationClick(item: any) {
  notificationStore.markNotificationRead(item.id)
  notificationVisible.value = false
  
  if (item.type === 'alarm') {
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
  } else if (item.route) {
    router.push(item.route)
  }
}

function clearAllNotifications() {
  notificationStore.clearAllNotifications()
}

function playNotificationSound() {
  try {
    const audio = new Audio('/notification.mp3')
    audio.play().catch(() => {})
  } catch (error) {}
}
</script>

<style scoped>
.reception-layout {
  min-height: 100vh;
  background: var(--hotel-bg);
  overflow-x: hidden; /* 防止水平滚动条 */
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

.reception-sider :deep(.ant-layout-sider-children) {
  display: flex;
  flex-direction: column;
  height: 100%;
}

.sider-menu-wrapper {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
}

.sider-menu-wrapper::-webkit-scrollbar {
  width: 4px;
}

.sider-menu-wrapper::-webkit-scrollbar-thumb {
  background: rgba(26, 43, 74, 0.1);
  border-radius: 2px;
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
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.logo-img {
  width: 100%;
  height: 100%;
  object-fit: contain;
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
  min-height: calc(100vh - 72px - 80px); /* 减去 header 和 footer 高度 */
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
