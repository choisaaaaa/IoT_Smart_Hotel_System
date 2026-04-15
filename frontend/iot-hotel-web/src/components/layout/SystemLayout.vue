<template>
  <a-layout class="system-layout">
    <a-layout-sider v-model:collapsed="collapsed" :trigger="null" collapsible class="sider">
      <div class="logo">
        <BankOutlined style="font-size: 24px; color: #1890ff;" />
        <span v-show="!collapsed">系统管理端</span>
      </div>
      <a-menu v-model:selectedKeys="selectedKeys" theme="dark" mode="inline" @click="handleMenuClick">
        <a-menu-item key="/system/dashboard">
          <template #icon><DashboardOutlined /></template>
          <span>系统概览</span>
        </a-menu-item>
        <a-menu-item key="/system/hotels">
          <template #icon><BankOutlined /></template>
          <span>酒店维护</span>
        </a-menu-item>
        <a-menu-item key="/system/devices">
          <template #icon><MobileOutlined /></template>
          <span>全局设备</span>
        </a-menu-item>
        <a-menu-item key="/system/users">
          <template #icon><UserOutlined /></template>
          <span>账户管理</span>
        </a-menu-item>
        <a-menu-item key="/system/coupons">
          <template #icon><GiftOutlined /></template>
          <span>优惠券管理</span>
        </a-menu-item>
        <a-menu-item key="/system/settings">
          <template #icon><SettingOutlined /></template>
          <span>会员方案配置</span>
        </a-menu-item>
        <a-menu-item key="/system/hotel-access">
          <template #icon><EnterOutlined /></template>
          <span>分店快速进入</span>
        </a-menu-item>
        <a-menu-item key="/system/mqtt">
          <template #icon><ClusterOutlined /></template>
          <span>MQTT 服务管理</span>
        </a-menu-item>
      </a-menu>
    </a-layout-sider>

    <a-layout>
      <a-layout-header class="header">
        <div class="header-left">
          <menu-unfold-outlined v-if="collapsed" class="trigger" @click="() => (collapsed = !collapsed)" />
          <menu-fold-outlined v-else class="trigger" @click="() => (collapsed = !collapsed)" />
          <a-breadcrumb class="breadcrumb">
            <a-breadcrumb-item>首页</a-breadcrumb-item>
            <a-breadcrumb-item>{{ currentTitle }}</a-breadcrumb-item>
          </a-breadcrumb>
        </div>
        <div class="header-right">
          <a-dropdown>
            <span class="user-action">
              <a-avatar size="small" :src="appStore.resolveImageUrl(appStore.userInfo?.avatar)">
                <template #icon v-if="!appStore.userInfo?.avatar"><UserOutlined /></template>
              </a-avatar>
              <span class="username">{{ appStore.userInfo?.username }}</span>
            </span>
            <template #overlay>
              <a-menu>
                <a-menu-item key="profile" @click="$router.push('/guest/profile')">
                  <UserOutlined /> 个人资料
                </a-menu-item>
                <a-menu-divider />
                <a-menu-item key="logout" @click="handleLogout">
                  <logout-outlined /> 退出登录
                </a-menu-item>
              </a-menu>
            </template>
          </a-dropdown>
        </div>
      </a-layout-header>

      <a-layout-content class="content">
        <router-view v-slot="{ Component }">
          <transition name="fade" mode="out-in">
            <component :is="Component" />
          </transition>
        </router-view>
      </a-layout-content>
    </a-layout>
  </a-layout>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAppStore } from '@/stores/app'
import { authService } from '@/api/auth'
import {
  DashboardOutlined, BankOutlined, MobileOutlined,
  UserOutlined, MenuFoldOutlined, GiftOutlined,
  MenuUnfoldOutlined, LogoutOutlined, SettingOutlined,
  ClusterOutlined, EnterOutlined
} from '@ant-design/icons-vue'

const route = useRoute()
const router = useRouter()
const appStore = useAppStore()

// 初始化用户信息
appStore.initUserInfo()

const collapsed = ref(false)
const selectedKeys = ref<string[]>([route.path])

const currentTitle = computed(() => {
  return (route.meta.title as string) || '后台管理'
})

watch(() => route.path, (newPath) => {
  selectedKeys.value = [newPath]
})

function handleMenuClick({ key }: any) {
  router.push(key)
}

async function handleLogout() {
  await authService.logout()
  router.push('/guest/booking')
}
</script>

<style scoped>
.system-layout { height: 100vh; }
.logo { height: 64px; display: flex; align-items: center; justify-content: center; padding: 0 16px; color: #fff; gap: 12px; overflow: hidden; background: #001529; }
.logo span { font-size: 18px; font-weight: bold; white-space: nowrap; color: #fff; }
.header { background: #fff; padding: 0 24px; display: flex; align-items: center; justify-content: space-between; box-shadow: 0 1px 4px rgba(0,21,41,.08); z-index: 1; }
.header-left { display: flex; align-items: center; }
.trigger { font-size: 18px; cursor: pointer; transition: color 0.3s; margin-right: 24px; }
.trigger:hover { color: #1890ff; }
.user-action { cursor: pointer; display: flex; align-items: center; gap: 8px; padding: 0 12px; transition: background 0.3s; }
.user-action:hover { background: rgba(0,0,0,0.025); }
.username { font-size: 14px; }
.content { margin: 24px; min-height: 280px; }
.fade-enter-active, .fade-leave-active { transition: opacity 0.2s ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>
