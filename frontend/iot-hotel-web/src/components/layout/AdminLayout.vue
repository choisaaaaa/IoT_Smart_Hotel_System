<template>
  <a-layout class="admin-layout">
    <a-layout-sider
      v-model:collapsed="collapsed"
      :trigger="null"
      collapsible
      width="260"
      theme="dark"
      class="admin-sider"
    >
      <div class="sider-header" @click="$router.push('/hotel-admin/dashboard')">
        <div class="sider-logo">
          <img src="/logo-small.png" alt="Logo" class="logo-img" />
        </div>
        <div v-show="!collapsed" class="sider-brand">
          <span class="brand-title">管理后台</span>
          <span class="brand-sub">慧宿智联</span>
        </div>
      </div>

      <div class="sider-menu-wrapper">
        <a-menu
          v-model:selectedKeys="selectedKeys"
          mode="inline"
          theme="dark"
          @click="handleMenuClick"
          class="admin-menu"
        >
          <a-menu-item key="/hotel-admin/dashboard">
            <template #icon><DashboardOutlined /></template>
            <span>管理总览</span>
          </a-menu-item>

          <a-sub-menu key="hotel-management">
            <template #icon><BankOutlined /></template>
            <template #title>酒店管理</template>
            <a-menu-item key="/hotel-admin/hotel/info">酒店信息</a-menu-item>
            <a-menu-item key="/hotel-admin/hotel/price-calendar">价格日历</a-menu-item>
            <a-menu-item key="/hotel-admin/hotel/coupons">优惠券管理</a-menu-item>
          </a-sub-menu>

          <a-sub-menu key="room-management">
            <template #icon><HomeOutlined /></template>
            <template #title>客房管理</template>
            <a-menu-item key="/hotel-admin/rooms/edit">客房列表</a-menu-item>
            <a-menu-item key="/hotel-admin/rooms/types">房型管理</a-menu-item>
            <a-menu-item key="/hotel-admin/rooms/floors">楼层管理</a-menu-item>
          </a-sub-menu>

          <a-sub-menu key="user-management">
            <template #icon><TeamOutlined /></template>
            <template #title>用户管理</template>
            <a-menu-item key="/hotel-admin/users">用户管理</a-menu-item>
          </a-sub-menu>

          <a-sub-menu key="device-management">
            <template #icon><ControlOutlined /></template>
            <template #title>设备管理</template>
            <a-menu-item key="/hotel-admin/devices">设备监控</a-menu-item>
            <a-menu-item key="/hotel-admin/device-types">设备类型</a-menu-item>
            <a-menu-item key="/hotel-admin/device-logs">设备日志</a-menu-item>
            <a-menu-item key="/hotel-admin/pending-devices">待审核设备</a-menu-item>
            <a-menu-item key="/hotel-admin/environment">环境监测</a-menu-item>
          </a-sub-menu>

          <a-sub-menu key="service-management">
            <template #icon><FileTextOutlined /></template>
            <template #title>服务管理</template>
            <a-menu-item key="/hotel-admin/reviews">评价管理</a-menu-item>
            <a-menu-item key="/hotel-admin/knowledge-base">AI知识库</a-menu-item>
          </a-sub-menu>

          <a-sub-menu key="system-settings">
            <template #icon><ToolOutlined /></template>
            <template #title>系统设置</template>
            <a-menu-item key="/hotel-admin/mqtt">MQTT通信管理</a-menu-item>
          </a-sub-menu>

          <a-menu-item key="/hotel-admin/reports">
            <template #icon><BarChartOutlined /></template>
            <span>数据报表</span>
          </a-menu-item>
        </a-menu>
      </div>

      <div class="sider-footer-wrapper">
        <div class="sider-footer" :class="{ collapsed: collapsed }">
          <div v-if="!collapsed" class="system-info">
            <span class="version">系统版本 v2.2.0</span>
            <span class="status online">运行正常</span>
          </div>
          <div v-else class="system-info-collapsed">
            <span class="status-dot online"></span>
          </div>
        </div>
      </div>
    </a-layout-sider>

    <a-layout>
      <a-layout-header class="admin-header" :style="{ marginLeft: collapsed ? '80px' : '260px' }">
        <div class="header-left">
          <MenuUnfoldOutlined v-if="collapsed" class="trigger" @click="collapsed = false" />
          <MenuFoldOutlined v-else class="trigger" @click="collapsed = true" />
          <a-breadcrumb class="breadcrumb">
            <a-breadcrumb-item v-for="(item, idx) in breadcrumbs" :key="idx">
              {{ item }}
            </a-breadcrumb-item>
          </a-breadcrumb>
        </div>
        
        <div class="header-right">
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
                <span class="user-name">{{ appStore.userInfo?.username || '管理员' }}</span>
                <span class="user-role">{{ getRoleText(appStore.userInfo?.role) }}</span>
              </div>
              <DownOutlined class="dropdown-icon" />
            </div>
            <template #overlay>
              <a-menu class="profile-menu">
                <a-menu-item key="profile" @click="$router.push('/guest/profile')">
                  <UserOutlined /> 个人资料
                </a-menu-item>
                <a-menu-item key="settings" @click="$router.push('/reception/dashboard')">
                  <CustomerServiceOutlined /> 切换前台端
                </a-menu-item>
                <a-menu-item 
                  v-if="appStore.userInfo?.role === 'system_admin'" 
                  key="system" 
                  @click="$router.push('/system/dashboard')"
                >
                  <SwapOutlined /> 切换系统端
                </a-menu-item>
                <a-menu-item key="guest" @click="$router.push('/guest/booking')">
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

      <a-layout-content class="admin-content" :style="{ marginLeft: collapsed ? '96px' : '276px' }">
        <router-view />
      </a-layout-content>

      <a-layout-footer class="admin-footer" :style="{ marginLeft: collapsed ? '80px' : '260px' }">
        <div class="footer-inner">
          <span class="footer-text">慧宿智联 · 智慧酒店管理系统</span>
          <span class="footer-divider">|</span>
          <span class="footer-version">管理后台 v2.2.0</span>
        </div>
      </a-layout-footer>
    </a-layout>
  </a-layout>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  SettingOutlined,
  DashboardOutlined,
  BankOutlined,
  HomeOutlined,
  TeamOutlined,
  FileTextOutlined,
  ControlOutlined,
  ToolOutlined,
  BarChartOutlined,
  HistoryOutlined,
  MenuFoldOutlined,
  MenuUnfoldOutlined,
  UserOutlined,
  LogoutOutlined,
  DownOutlined,
  WifiOutlined,
  DisconnectOutlined
} from '@ant-design/icons-vue'
import { message } from 'ant-design-vue'
import { useAppStore } from '@/stores/app'
import { authService } from '@/api/auth'

const route = useRoute()
const router = useRouter()
const appStore = useAppStore()

appStore.initUserInfo()

const collapsed = ref(false)
const selectedKeys = ref<string[]>([route.path])

const breadcrumbs = computed(() => {
  const matched = route.matched
  return matched.slice(1).map(m => m.meta?.title || m.name).filter(Boolean)
})

watch(() => route.path, (path) => {
  selectedKeys.value = [path]
})

function handleMenuClick({ key }: { key: string }) {
  router.push(key)
}

function getRoleText(role?: string) {
  const roleMap: Record<string, string> = {
    'system_admin': '系统管理员',
    'hotel_admin': '酒店管理员',
    'staff': '员工',
    'customer': '顾客'
  }
  return roleMap[role || ''] || '管理员'
}

async function handleLogout() {
  await authService.logout()
  router.push('/guest/booking')
}

onMounted(() => {
  // 检查权限
  const userRole = appStore.userInfo?.role
  if (!userRole || (userRole !== 'system_admin' && userRole !== 'hotel_admin')) {
    message.warning('您没有权限访问管理后台')
    router.push('/guest/booking')
  }
})
</script>

<style scoped>
.admin-layout {
  min-height: 100vh;
  background: var(--hotel-bg);
}

.admin-sider {
  position: fixed;
  left: 0;
  top: 0;
  bottom: 0;
  z-index: 100;
  box-shadow: 2px 0 12px rgba(0, 0, 0, 0.2);
}

.admin-sider :deep(.ant-layout-sider-children) {
  display: flex;
  flex-direction: column;
  height: 100%;
}

.sider-header {
  height: 72px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  cursor: pointer;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
  padding: 0 20px;
  transition: all 0.3s;
}

.sider-header:hover {
  background: rgba(255, 255, 255, 0.05);
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
  color: #fff;
}

.brand-sub {
  font-size: 12px;
  color: rgba(255, 255, 255, 0.6);
}

.admin-menu {
  background: transparent;
  border-right: none;
  padding: 12px 0;
}

.admin-menu :deep(.ant-menu-item) {
  margin: 4px 12px;
  border-radius: var(--hotel-radius-sm);
}

.admin-menu :deep(.ant-menu-item-selected) {
  background: var(--hotel-gold) !important;
  color: #fff !important;
}

.admin-menu :deep(.ant-menu-submenu-title) {
  margin: 4px 12px;
  border-radius: var(--hotel-radius-sm);
}

.admin-menu :deep(.ant-menu-sub) {
  background: rgba(0, 0, 0, 0.2) !important;
}

.sider-menu-wrapper {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
  min-height: 0;
}

.sider-menu-wrapper::-webkit-scrollbar {
  width: 4px;
}

.sider-menu-wrapper::-webkit-scrollbar-track {
  background: transparent;
}

.sider-menu-wrapper::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.2);
  border-radius: 2px;
}

.sider-menu-wrapper::-webkit-scrollbar-thumb:hover {
  background: rgba(255, 255, 255, 0.3);
}

.sider-footer-wrapper {
  flex-shrink: 0;
  background: #001529;
  position: relative;
  z-index: 10;
}

.sider-footer {
  padding: 16px 20px;
  border-top: 1px solid rgba(255, 255, 255, 0.1);
}

.sider-footer.collapsed {
  padding: 16px 0;
  display: flex;
  justify-content: center;
  align-items: center;
}

.system-info {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.system-info-collapsed {
  display: flex;
  justify-content: center;
  align-items: center;
}

.version {
  font-size: 12px;
  color: rgba(255, 255, 255, 0.5);
}

.status {
  font-size: 12px;
  display: flex;
  align-items: center;
  gap: 6px;
}

.status.online {
  color: var(--hotel-success);
}

.status::before {
  content: '';
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: currentColor;
}

.status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  display: block;
}

.status-dot.online {
  background: var(--hotel-success);
}

.admin-header {
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

.admin-content {
  margin: 24px;
  margin-left: 284px;
  min-height: calc(100vh - 72px - 80px);
  transition: margin-left 0.2s;
}

.admin-footer {
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
</style>
