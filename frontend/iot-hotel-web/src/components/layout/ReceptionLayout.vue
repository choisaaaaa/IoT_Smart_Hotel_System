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
        <span v-show="!collapsed" class="logo-text">前台端</span>
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
        <a-menu-item key="/reception/checkinout">
          <template #icon><LoginOutlined /></template>
          <span>入住退房</span>
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
        <a-menu-item key="/reception/price-settings">
          <template #icon><TagsOutlined /></template>
          <span>房价设置</span>
        </a-menu-item>
        <a-menu-item key="/reception/bills">
          <template #icon><DollarOutlined /></template>
          <span>账单报表</span>
        </a-menu-item>
      </a-menu>
    </a-layout-sider>

    <a-layout>
      <a-layout-header class="reception-header">
        <div class="header-left">
          <MenuUnfoldOutlined v-if="collapsed" class="trigger" @click="collapsed = false" />
          <MenuFoldOutlined v-else class="trigger" @click="collapsed = true" />
          <a-breadcrumb>
            <a-breadcrumb-item><CustomerServiceOutlined /> 前台端</a-breadcrumb-item>
            <a-breadcrumb-item>{{ currentTitle }}</a-breadcrumb-item>
          </a-breadcrumb>
        </div>
        <div class="header-right">
          <a-badge :count="pendingOrders" :offset="[-2, 4]">
            <BellOutlined class="header-icon" />
          </a-badge>
          <a-tag :color="appStore.connected ? 'success' : 'error'">{{ appStore.connected ? '在线' : '离线' }}</a-tag>
          <a-dropdown>
            <span class="user-action" style="cursor: pointer; display: flex; align-items: center; gap: 8px;">
              <a-avatar style="background-color: #1890ff;">前</a-avatar>
              <span v-if="appStore.userInfo?.username">{{ appStore.userInfo.username }}</span>
            </span>
            <template #overlay>
              <a-menu>
                <a-menu-item key="logout" @click="handleLogout">
                  <LogoutOutlined /> 退出登录
                </a-menu-item>
              </a-menu>
            </template>
          </a-dropdown>
        </div>
      </a-layout-header>

      <a-layout-content class="reception-content">
        <router-view />
      </a-layout-content>

      <a-layout-footer class="reception-footer">
        智慧酒店物联网控制系统 ©2026 - 前台端
      </a-layout-footer>
    </a-layout>
  </a-layout>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  CustomerServiceOutlined, DashboardOutlined, LoginOutlined,
  CalendarOutlined, ApartmentOutlined, ToolOutlined, SendOutlined,
  PhoneOutlined, TagsOutlined, DollarOutlined, MenuFoldOutlined, MenuUnfoldOutlined,
  BellOutlined, LogoutOutlined, EnvironmentOutlined
} from '@ant-design/icons-vue'
import { useAppStore } from '@/stores/app'
import { authService } from '@/api/auth'
import { maintenanceApi } from '@/api/maintenance'
import { deliveryApi } from '@/api/delivery'

const route = useRoute()
const router = useRouter()
const appStore = useAppStore()

// 初始化用户信息
appStore.initUserInfo()

const collapsed = ref(false)
const selectedKeys = ref<string[]>([route.path])
const pendingOrders = ref(0)

const currentTitle = computed(() => (route.meta.title as string) || '')

watch(() => route.path, (path) => {
  selectedKeys.value = [path]
})

function handleMenuClick({ key }: { key: string }) {
  router.push(key)
}

async function handleLogout() {
  await authService.logout()
  router.push('/login')
}

async function loadPending() {
  const cacheRaw = sessionStorage.getItem('reception_pending_cache')
  if (cacheRaw) {
    try {
      const cache = JSON.parse(cacheRaw)
      if (Date.now() - Number(cache.ts || 0) < 5000) {
        pendingOrders.value = Number(cache.count || 0)
        return
      }
    } catch (error) {}
  }
  try {
    const [maintenanceRes, deliveryRes] = await Promise.all([
      maintenanceApi.getList({ status: 'pending', pageSize: 1 }),
      deliveryApi.getList({ status: 'pending', pageSize: 1 })
    ])
    const maintenanceTotal = Number((maintenanceRes as any).data?.total || (maintenanceRes as any).data?.data?.total || 0)
    const deliveryTotal = Number((deliveryRes as any).data?.total || (deliveryRes as any).data?.data?.total || 0)
    pendingOrders.value = maintenanceTotal + deliveryTotal
    sessionStorage.setItem('reception_pending_cache', JSON.stringify({
      count: pendingOrders.value,
      ts: Date.now()
    }))
  } catch (error) {
    pendingOrders.value = 0
  }
}

onMounted(() => {
  loadPending()
})
</script>

<style scoped>
.reception-layout { min-height: 100vh; background: #f5f7fa; }
.reception-sider { position: fixed; left: 0; top: 0; bottom: 0; z-index: 10; box-shadow: 2px 0 6px rgba(0,21,41,.04); overflow-y: auto; }
.logo {
  height: 56px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  cursor: pointer;
  font-size: 18px;
  font-weight: 600;
  border-bottom: 1px solid #f0f0f0;
}
.logo-text { background: linear-gradient(135deg, #1890ff, #722ed1); background-clip: text; -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
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
</style>
