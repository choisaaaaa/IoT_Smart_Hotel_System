<template>
  <a-layout class="admin-layout">
    <a-layout-sider
      v-model:collapsed="collapsed"
      :trigger="null"
      collapsible
      width="240"
      theme="dark"
      class="admin-sider"
    >
      <div class="logo" @click="$router.push('/hotel-admin/dashboard')">
        <SettingOutlined style="font-size: 24px;" />
        <span v-show="!collapsed" class="logo-text">智联酒店 · 管理端</span>
      </div>
      <a-menu
        v-model:selectedKeys="selectedKeys"
        mode="inline"
        theme="dark"
        @click="handleMenuClick"
      >
        <a-menu-item key="/hotel-admin/dashboard">
          <template #icon><DashboardOutlined /></template>
          <span>总览仪表盘</span>
        </a-menu-item>
        <a-menu-item key="/hotel-admin/devices">
          <template #icon><MonitorOutlined /></template>
          <span>设备监控</span>
        </a-menu-item>
        <a-menu-item key="/hotel-admin/environment">
          <template #icon><EnvironmentOutlined /></template>
          <span>环境监测</span>
        </a-menu-item>
        <a-sub-menu key="info-manage">
          <template #title><EditOutlined /><span v-show="!collapsed">房间管理</span></template>
          <a-menu-item key="/hotel-admin/rooms/edit"><HomeOutlined /> 房间列表</a-menu-item>
          <a-menu-item key="/hotel-admin/rooms/types"><TagsOutlined /> 房型维护</a-menu-item>
          <a-menu-item key="/hotel-admin/rooms/floors"><BarsOutlined /> 楼层管理</a-menu-item>
        </a-sub-menu>
        <a-menu-item key="/hotel-admin/hotel/info">
          <template #icon><BankOutlined /></template>
          <span>酒店信息</span>
        </a-menu-item>
        <a-menu-item key="/hotel-admin/reports">
          <template #icon><FileTextOutlined /></template>
          <span>账单报表</span>
        </a-menu-item>
        <a-menu-item key="/hotel-admin/users">
          <template #icon><UserOutlined /></template>
          <span>用户管理</span>
        </a-menu-item>
      </a-menu>
    </a-layout-sider>

    <a-layout>
      <a-layout-header class="admin-header">
        <div class="header-left">
          <MenuUnfoldOutlined v-if="collapsed" class="trigger" @click="collapsed = false" />
          <MenuFoldOutlined v-else class="trigger" @click="collapsed = true" />
          <a-breadcrumb class="breadcrumb">
            <a-breadcrumb-item><SettingOutlined /> 管理端</a-breadcrumb-item>
            <a-breadcrumb-item>{{ currentTitle }}</a-breadcrumb-item>
          </a-breadcrumb>
        </div>
        <div class="header-right">
          <a-tag v-if="hotelInfoLoading" color="processing" class="hotel-tag">分店信息加载中</a-tag>
          <a-tag v-else-if="resolvedHotelName" color="blue" class="hotel-tag">
            <BankOutlined /> {{ resolvedHotelName }}
          </a-tag>
          <a-tag v-else color="warning" class="hotel-tag">未绑定分店</a-tag>
          <a-badge :count="appStore.notificationCount" :offset="[-2, 4]">
            <BellOutlined class="header-icon" />
          </a-badge>
          <a-tag :color="appStore.connected ? 'success' : 'error'" class="ws-status">
            {{ appStore.connected ? '系统正常' : '连接异常' }}
          </a-tag>
          <a-dropdown>
            <span class="user-action" style="cursor: pointer; display: flex; align-items: center; gap: 8px;">
              <a-avatar style="background-color: #722ed1;">管</a-avatar>
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

      <a-layout-content class="admin-content">
        <router-view />
      </a-layout-content>

      <a-layout-footer class="admin-footer">
        智慧酒店物联网控制系统 ©2026 - 管理端
      </a-layout-footer>
    </a-layout>
  </a-layout>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  SettingOutlined, DashboardOutlined, MonitorOutlined,
  HomeOutlined, BankOutlined, FileTextOutlined, EditOutlined,
  MenuFoldOutlined, MenuUnfoldOutlined,
  BellOutlined,
  TagsOutlined, BarsOutlined, UserOutlined, LogoutOutlined,
  EnvironmentOutlined
} from '@ant-design/icons-vue'
import { useAppStore } from '@/stores/app'
import { authService } from '@/api/auth'
import { hotelManageApi } from '@/api/hotel-manage'

const route = useRoute()
const router = useRouter()
const appStore = useAppStore()

// 初始化用户信息
appStore.initUserInfo()

const collapsed = ref(false)
const selectedKeys = ref<string[]>([route.path])
const hotelInfoLoading = ref(false)
const hotelName = ref('')

const currentTitle = computed(() => (route.meta.title as string) || '')
const resolvedHotelName = computed(() => hotelName.value || appStore.userInfo?.hotel_name || '')

watch(() => route.path, (path) => {
  selectedKeys.value = [path]
})

function handleMenuClick({ key }: { key: string }) {
  router.push(key)
}

async function loadHotelInfo() {
  if (appStore.userInfo?.role !== 'admin') {
    return
  }
  hotelInfoLoading.value = true
  try {
    const res: any = await hotelManageApi.getHotelInfo()
    const data = res?.data
    if (data?.hotel_name) {
      hotelName.value = data.hotel_name
      appStore.setUserInfo({
        ...appStore.userInfo,
        hotel_name: data.hotel_name
      })
    }
  } finally {
    hotelInfoLoading.value = false
  }
}

onMounted(() => {
  loadHotelInfo()
})

async function handleLogout() {
  await authService.logout()
  router.push('/login')
}
</script>

<style scoped>
.admin-layout { min-height: 100vh; }
.admin-sider { position: fixed; left: 0; top: 0; bottom: 0; z-index: 10; }
.logo {
  height: 64px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  cursor: pointer;
  color: #fff;
  font-size: 16px;
  font-weight: bold;
  border-bottom: 1px solid rgba(255,255,255,0.1);
}
.admin-header {
  background: #fff;
  padding: 0 24px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  box-shadow: 0 1px 4px rgba(0,21,41,.08);
  z-index: 9;
  margin-left: 240px;
  transition: margin-left .2s;
}
.header-left { display: flex; align-items: center; gap: 16px; }
.header-right { display: flex; align-items: center; gap: 16px; }
.trigger { font-size: 18px; cursor: pointer; padding: 0 8px; }
.trigger:hover { color: #1890ff; }
.breadcrumb { font-size: 14px; }
.header-icon { font-size: 18px; cursor: pointer; }
.ws-status { border-radius: 12px; }
.hotel-tag { display: inline-flex; align-items: center; gap: 6px; border-radius: 12px; }
.admin-content {
  margin: 16px;
  margin-left: 256px;
  padding: 24px;
  background: #fff;
  border-radius: 8px;
  min-height: calc(100vh - 64px - 48px - 69px);
  overflow-y: auto;
  transition: margin-left .2s;
}
.admin-footer {
  text-align: center;
  color: rgba(0,0,0,0.45);
  margin-left: 240px;
  transition: margin-left .2s;
}
</style>
