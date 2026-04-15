<template>
  <a-layout class="reception-layout">
    <a-layout-sider
      v-model:collapsed="collapsed"
      :trigger="null"
      collapsible
      width="220"
      theme="light"
      class="reception-sider"
    >
      <div class="logo" @click="$router.push('/reception/dashboard')">
        <CustomerServiceOutlined style="font-size: 24px; color: #1890ff;" />
        <div v-show="!collapsed" class="logo-wrapper">
          <span class="logo-text">前台端</span>
          <span class="hotel-tag">{{ hotelStore.hotelInfo?.hotel_name || '智联酒店' }}</span>
        </div>
      </div>
      <a-menu
        v-model:selectedKeys="selectedKeys"
        mode="inline"
        theme="light"
        @click="handleMenuClick"
      >
        <a-menu-item key="/reception/dashboard">
          <template #icon><DashboardOutlined /></template>
          <span>前台总览</span>
        </a-menu-item>
        <a-menu-item key="/reception/reception-center">
          <template #icon>
            <span style="font-size: 12px;">🛎️</span>
          </template>
          <span>接待中心</span>
        </a-menu-item>
        <a-menu-item key="/reception/device-management">
          <template #icon><ControlOutlined /></template>
          <span>主控设备管理</span>
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
          <template #icon><CalendarOutlined /></template>
          <span>价格日历</span>
        </a-menu-item>
        <a-menu-item key="/reception/coupons">
          <template #icon><TagOutlined /></template>
          <span>优惠券管理</span>
        </a-menu-item>
        <a-menu-item key="/reception/bills">
          <template #icon><DollarOutlined /></template>
          <span>账单报表</span>
        </a-menu-item>
      </a-menu>
    </a-layout-sider>

    <a-layout>
      <a-layout-header class="reception-header" :style="{ marginLeft: collapsed ? '80px' : '220px' }">
        <div class="header-left">
          <MenuUnfoldOutlined v-if="collapsed" class="trigger" @click="collapsed = false" />
          <MenuFoldOutlined v-else class="trigger" @click="collapsed = true" />
          <a-breadcrumb>
            <a-breadcrumb-item><CustomerServiceOutlined /> 前台端</a-breadcrumb-item>
            <a-breadcrumb-item>{{ currentTitle }}</a-breadcrumb-item>
          </a-breadcrumb>
        </div>
        <div class="header-right">
          <a-popover v-model:open="notificationVisible" trigger="click" placement="bottomRight" :overlayStyle="{ width: '360px' }">
            <template #content>
              <div class="notification-panel">
                <div class="notification-header">
                  <span class="notification-title">消息通知</span>
                  <a-button type="link" size="small" @click="clearAllNotifications">全部已读</a-button>
                </div>
                <a-divider style="margin: 8px 0;" />
                <div v-if="notificationItems.length === 0" class="notification-empty">
                  <CheckCircleOutlined style="font-size: 32px; color: #d9d9d9;" />
                  <p>暂无新消息</p>
                </div>
                <div v-else class="notification-list">
                  <div
                    v-for="item in notificationItems"
                    :key="item.id"
                    class="notification-item"
                    @click="handleNotificationClick(item)"
                  >
                    <div class="notification-item-icon">
                      <ToolOutlined v-if="item.type === 'maintenance'" style="color: #faad14;" />
                      <SendOutlined v-if="item.type === 'delivery'" style="color: #1890ff;" />
                      <AlertOutlined v-if="item.type === 'environment'" style="color: #ff4d4f;" />
                    </div>
                    <div class="notification-item-content">
                      <div class="notification-item-title">{{ item.title }}</div>
                      <div class="notification-item-desc">{{ item.desc }}</div>
                    </div>
                    <div class="notification-item-badge" v-if="!item.read">
                      <a-badge dot />
                    </div>
                  </div>
                </div>
              </div>
            </template>
            <a-badge :count="unreadCount" :offset="[-2, 4]">
              <BellOutlined class="header-icon" :style="{ color: unreadCount > 0 ? '#ff4d4f' : undefined }" />
            </a-badge>
          </a-popover>
          <a-tag :color="appStore.connected ? 'success' : 'error'">{{ appStore.connected ? '在线' : '离线' }}</a-tag>
          <a-dropdown :overlay-style="{ minWidth: '160px' }">
            <span class="user-action" style="cursor: pointer; display: flex; align-items: center; gap: 8px;">
              <a-avatar :src="appStore.resolveImageUrl(appStore.userInfo?.avatar)" style="background-color: #1890ff;">
                <template #icon v-if="!appStore.userInfo?.avatar"><UserOutlined /></template>
              </a-avatar>
              <span v-if="appStore.userInfo?.username">{{ appStore.userInfo.username }}</span>
            </span>
            <template #overlay>
              <a-menu>
                <a-menu-item key="profile" @click="$router.push('/guest/profile')">
                  <UserOutlined /> 个人资料
                </a-menu-item>
                <a-menu-item v-if="appStore.userInfo?.role === CANONICAL_ROLES.SYSTEM_ADMIN || appStore.userInfo?.role === CANONICAL_ROLES.HOTEL_ADMIN" key="hotel-admin" @click="$router.push('/hotel-admin')">
                  <SettingOutlined /> 进入管理端
                </a-menu-item>
                <a-menu-item v-if="appStore.userInfo?.role === CANONICAL_ROLES.SYSTEM_ADMIN" key="system" @click="returnToSystem">
                  <SwapOutlined /> 返回系统端
                </a-menu-item>
                <a-menu-divider />
                <a-menu-item key="logout" @click="handleLogout">
                  <LogoutOutlined /> 退出登录
                </a-menu-item>
              </a-menu>
            </template>
          </a-dropdown>
        </div>
      </a-layout-header>

      <a-layout-content class="reception-content" :style="{ marginLeft: collapsed ? '96px' : '236px' }">
        <router-view />
      </a-layout-content>

      <a-layout-footer class="reception-footer" :style="{ marginLeft: collapsed ? '80px' : '220px' }">
        智慧酒店物联网控制系统 ©2026 - 前台端
      </a-layout-footer>
    </a-layout>
  </a-layout>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  CustomerServiceOutlined, DashboardOutlined, LoginOutlined,
  CalendarOutlined, ApartmentOutlined, ToolOutlined, SendOutlined,
  PhoneOutlined, TagsOutlined, DollarOutlined, MenuFoldOutlined, MenuUnfoldOutlined,
  BellOutlined, LogoutOutlined, EnvironmentOutlined, TagOutlined,
  CheckCircleOutlined, AlertOutlined, UserOutlined, SwapOutlined,
  ControlOutlined
} from '@ant-design/icons-vue'
import { message } from 'ant-design-vue'
import { useAppStore } from '@/stores/app'
import { useHotelStore } from '@/stores/hotel'
import { authService, CANONICAL_ROLES } from '@/api/auth'
import { maintenanceApi } from '@/api/maintenance'
import { deliveryApi } from '@/api/delivery'
import { environmentApi } from '@/api/environment'
import { getSocket, initWebSocket } from '@/utils/websocket'
import request from '@/api/request'

const route = useRoute()
const router = useRouter()
const appStore = useAppStore()
const hotelStore = useHotelStore()

// 初始化用户信息
appStore.initUserInfo()

const collapsed = ref(false)
const selectedKeys = ref<string[]>([route.path])
const notificationVisible = ref(false)

async function handleLogout() {
  await authService.logout()
  router.push('/guest/booking')
}

async function returnToSystem() {
  try {
    const res = await request.post('/auth/switch-hotel', {
      hotel_id: 0
    })

    if (res.data.token) {
      localStorage.setItem('auth_token', res.data.token)
      
      // 更新用户信息中的酒店 ID 和名称
      if (appStore.userInfo) {
        appStore.setUserInfo({
          ...appStore.userInfo,
          hotel_id: 0,
          hotel_name: '智联酒店集团总部'
        })
      }
      
      hotelStore.setCurrentHotelId(0)
      router.push('/system/dashboard')
    }
  } catch (error) {
    router.push('/system/dashboard')
  }
}

// WebSocket 全局监听来电
function setupGlobalWebSocket() {
  const socket = initWebSocket()
  if (!socket) return

  // 注册逻辑已在 websocket.ts 的 connect 回调中自动处理
}

onUnmounted(() => {
  // WebSocket 监听器现在主要由 App.vue 处理
})

interface NotificationItem {
  id: string
  type: 'maintenance' | 'delivery' | 'environment'
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
  // 检查用户角色，只有前台员工才加载通知
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
          title: `未处理维修工单 (${total})`,
          desc: list[0]?.fault_description?.substring(0, 30) || `共${total}条待处理工单`,
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
          title: `待处理送物订单 (${total})`,
          desc: list[0]?.item_name || `共${total}条待处理送物`,
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
            title: `环境异常告警 (${unresolved.length})`,
            desc: unresolved[0]?.title || `${unresolved.length}条环境异常`,
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
  // 只有非顾客角色才启动定时刷新
  const userRole = appStore.userInfo?.role
  if (userRole && userRole !== 'customer') {
    setInterval(loadNotifications, 30000)
  }
})
</script>

<style scoped>
.reception-layout { min-height: 100vh; background: #f5f7fa; }
.reception-sider { position: fixed; left: 0; top: 0; bottom: 0; z-index: 10; box-shadow: 2px 0 6px rgba(0,21,41,.04); overflow-y: auto; }
.logo {
  height: 64px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  cursor: pointer;
  border-bottom: 1px solid #f0f0f0;
  padding: 0 16px;
}
.logo-wrapper {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  line-height: 1.2;
}
.logo-text { 
  font-size: 16px;
  font-weight: 600;
  background: linear-gradient(135deg, #1890ff, #722ed1); 
  background-clip: text; 
  -webkit-background-clip: text; 
  -webkit-text-fill-color: transparent; 
}
.hotel-tag {
  font-size: 10px;
  color: #8c8c8c;
  font-weight: normal;
  max-width: 120px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.reception-header {
  background: #fff;
  padding: 0 24px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  box-shadow: 0 1px 4px rgba(0,21,41,.06);
  z-index: 9;
  margin-left: 220px;
  transition: margin-left .2s;
}
.header-left { display: flex; align-items: center; gap: 16px; }
.header-right { display: flex; align-items: center; gap: 14px; }
.trigger { font-size: 18px; cursor: pointer; padding: 0 8px; }
.header-icon { font-size: 18px; cursor: pointer; }
.reception-content {
  margin: 16px;
  margin-left: 236px;
  padding: 20px;
  background: #fff;
  border-radius: 8px;
  min-height: calc(100vh - 56px - 48px - 69px);
  overflow-y: auto;
  transition: margin-left .2s;
}
.reception-footer {
  text-align: center;
  color: rgba(0,0,0,0.45);
  margin-left: 220px;
  transition: margin-left .2s;
}
.notification-panel { margin: -12px -16px; }
.notification-header { display: flex; justify-content: space-between; align-items: center; padding: 0 4px; }
.notification-title { font-weight: 600; font-size: 15px; }
.notification-empty { text-align: center; padding: 24px 0; color: #999; }
.notification-empty p { margin-top: 8px; }
.notification-list { max-height: 320px; overflow-y: auto; }
.notification-item {
  display: flex; align-items: center; gap: 12px;
  padding: 10px 12px; cursor: pointer; border-radius: 6px;
  transition: background .2s;
}
.notification-item:hover { background: #f5f5f5; }
.notification-item-icon { font-size: 20px; flex-shrink: 0; }
.notification-item-content { flex: 1; min-width: 0; }
.notification-item-title { font-size: 14px; font-weight: 500; }
.notification-item-desc { font-size: 12px; color: #999; margin-top: 2px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.notification-item-badge { flex-shrink: 0; }
</style>
