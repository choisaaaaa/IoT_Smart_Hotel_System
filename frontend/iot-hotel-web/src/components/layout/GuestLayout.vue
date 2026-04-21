<template>
  <div class="guest-layout">
    <a-layout>
      <!-- 顶部导航 -->
      <a-layout-header class="guest-header">
        <div class="header-left">
          <div class="logo" @click="$router.push('/guest/booking')">
            <div class="logo-icon">
              <HomeOutlined />
            </div>
            <div class="logo-text">
              <span class="brand-name">慧宿智联</span>
              <span class="brand-tagline">智慧酒店服务</span>
            </div>
          </div>
        </div>
        
        <div class="header-nav">
          <a-button
            type="text"
            :class="{ active: isActive('/guest/booking') }"
            @click="$router.push('/guest/booking')"
          >
            <CompassOutlined />
            探索旅程
          </a-button>
          <a-button
            v-if="appStore.userStatus?.is_checked_in"
            type="text"
            :class="{ active: isActive('/guest/room') }"
            @click="$router.push('/guest/room')"
          >
            <AppstoreOutlined />
            客房服务
          </a-button>
          <a-button
            v-else
            type="text"
            :class="{ active: isActive('/guest/checkin-online') }"
            @click="$router.push('/guest/checkin-online')"
          >
            <IdcardOutlined />
            预入住
          </a-button>
          <a-button
            type="text"
            :class="{ active: isActive('/guest/orders') }"
            @click="$router.push('/guest/orders')"
          >
            <FileTextOutlined />
            我的订单
          </a-button>
          <a-button
            type="text"
            :class="{ active: isActive('/guest/profile') }"
            @click="$router.push('/guest/profile')"
          >
            <UserOutlined />
            个人中心
          </a-button>
        </div>
        
        <div class="header-right">
          <div class="connection-status" :class="{ online: appStore.connected }">
            <span class="status-dot"></span>
            <span class="status-text">{{ appStore.connected ? '服务在线' : '连接中' }}</span>
          </div>
          
          <template v-if="!userInfo">
            <a-button type="primary" class="login-btn" @click="appStore.showLoginModal = true">
              <UserOutlined /> 登录 / 注册
            </a-button>
          </template>
          <template v-else>
            <div class="user-status-tags" v-if="appStore.userStatus">
              <a-tag 
                v-if="appStore.userStatus.is_member && memberLevelInfo" 
                class="member-tag"
                :style="{ background: memberLevelInfo.color, color: '#fff', border: 'none' }"
              >
                <CrownOutlined />
                {{ memberLevelInfo.label }}
              </a-tag>
              <a-tag v-if="appStore.userStatus.is_checked_in" class="checkin-tag">
                <CheckCircleOutlined />
                已入住
              </a-tag>
            </div>

            <a-button
              v-if="userInfo.role && userInfo.role !== CANONICAL_ROLES.CUSTOMER"
              type="link"
              class="switch-side-btn"
              @click="$router.push('/reception/dashboard')"
            >
              <SwapOutlined />
              管理后台
            </a-button>

            <a-dropdown placement="bottomRight">
              <a class="user-dropdown-wrapper" @click.prevent>
                <a-avatar :size="36" :src="userInfo.avatar" class="header-avatar">
                  <template #icon><UserOutlined /></template>
                </a-avatar>
                <span class="header-username">{{ userInfo.username }}</span>
                <DownOutlined class="dropdown-arrow" />
              </a>
              <template #overlay>
                <a-menu class="user-dropdown-menu">
                  <a-menu-item key="profile" @click="$router.push('/guest/profile')">
                    <UserOutlined /> 个人中心
                  </a-menu-item>
                  <a-menu-divider />
                  <a-menu-item key="logout" @click="handleLogout" class="logout-item">
                    <LogoutOutlined /> 退出登录
                  </a-menu-item>
                </a-menu>
              </template>
            </a-dropdown>
          </template>
        </div>
      </a-layout-header>

      <!-- 主内容区 -->
      <a-layout-content class="guest-content">
        <router-view />
      </a-layout-content>

      <!-- 页脚 -->
      <a-layout-footer class="guest-footer">
        <div class="footer-content">
          <div class="footer-brand">
            <HomeOutlined class="footer-logo" />
            <span>慧宿智联</span>
          </div>
          <div class="footer-links">
            <a href="#">关于我们</a>
            <a href="#">服务条款</a>
            <a href="#">隐私政策</a>
            <a href="#">联系客服</a>
          </div>
          <div class="footer-copyright">
            <p>2026 慧宿智联 · 云边端一体化智能酒店物联网解决方案</p>
            <p class="footer-sub">让每一次入住都成为美好回忆</p>
          </div>
        </div>
      </a-layout-footer>
    </a-layout>

    <!-- 登录弹窗 -->
    <a-modal
      v-model:open="appStore.showLoginModal"
      :footer="null"
      :closable="true"
      width="440px"
      class="login-modal"
      @cancel="handleLoginCancel"
    >
      <div class="login-modal-header">
        <div class="login-logo">
          <HomeOutlined />
        </div>
        <h3>欢迎回到慧宿智联</h3>
        <p>开启您的智慧酒店之旅</p>
      </div>

      <a-tabs v-model:activeKey="activeTab" class="login-tabs" centered>
        <a-tab-pane key="password" tab="密码登录">
          <a-form
            ref="loginFormRef"
            :model="loginForm"
            :rules="loginRules"
            layout="vertical"
            @finish="handleLogin"
            class="login-form"
          >
            <a-form-item name="phone" label="手机号码">
              <a-input
                v-model:value="loginForm.phone"
                placeholder="请输入手机号"
                size="large"
              >
                <template #prefix>
                  <MobileOutlined />
                </template>
              </a-input>
            </a-form-item>

            <a-form-item name="password" label="登录密码">
              <a-input-password
                v-model:value="loginForm.password"
                placeholder="请输入密码"
                size="large"
              >
                <template #prefix>
                  <LockOutlined />
                </template>
              </a-input-password>
            </a-form-item>

            <a-form-item>
              <a-button
                type="primary"
                html-type="submit"
                size="large"
                block
                :loading="loginLoading"
                class="submit-btn"
              >
                登录
              </a-button>
            </a-form-item>

            <div class="form-footer">
              <span>还没有账号？</span>
              <a @click="showRegisterModal = true" class="register-link">立即注册</a>
            </div>
          </a-form>
        </a-tab-pane>

        <a-tab-pane key="scan" tab="扫码登录">
          <div class="scan-login-container">
            <div v-if="!scanToken" class="scan-intro">
              <div class="scan-icon-wrapper">
                <QrcodeOutlined />
              </div>
              <p class="scan-tip">请使用慧宿智联 APP 扫码登录</p>
              <a-button
                type="primary"
                @click="handleGenerateQrToken"
                :loading="generatingToken"
                block
                size="large"
                class="generate-btn"
              >
                生成登录二维码
              </a-button>
            </div>

            <div v-else class="scan-waiting">
              <div class="qr-code-wrapper">
                <canvas ref="qrCanvasRef"></canvas>
                <div v-if="qrExpired" class="qr-expired-overlay">
                  <p>二维码已失效</p>
                  <a-button type="primary" @click="handleResetScan" size="small">
                    点击刷新
                  </a-button>
                </div>
              </div>
              <div class="scan-status">
                <a-spin v-if="!qrExpired" size="small" />
                <span v-if="!qrExpired">等待 APP 扫码...</span>
                <span v-else class="expired-text">二维码已过期，请刷新</span>
              </div>
              <a-statistic-countdown
                v-if="!qrExpired"
                :value="tokenExpireTime"
                format="mm:ss"
                @finish="handleCountdownFinish"
                class="countdown"
              />
            </div>
          </div>
        </a-tab-pane>
      </a-tabs>
    </a-modal>

    <!-- 注册弹窗 -->
    <a-modal
      v-model:open="showRegisterModal"
      title="注册新账号"
      @ok="handleRegister"
      :confirmLoading="registerLoading"
      cancelText="取消"
      okText="确定注册"
      class="register-modal"
      width="440px"
    >
      <a-form
        ref="registerFormRef"
        :model="registerForm"
        :rules="registerRules"
        layout="vertical"
        class="register-form"
      >
        <a-form-item name="username" label="用户昵称">
          <a-input
            v-model:value="registerForm.username"
            placeholder="请设置您的昵称"
            size="large"
          >
            <template #prefix>
              <UserOutlined />
            </template>
          </a-input>
        </a-form-item>

        <a-form-item name="phone" label="手机号码">
          <a-input
            v-model:value="registerForm.phone"
            placeholder="请输入手机号"
            size="large"
          >
            <template #prefix>
              <MobileOutlined />
            </template>
          </a-input>
        </a-form-item>

        <a-form-item name="password" label="设置密码">
          <a-input-password
            v-model:value="registerForm.password"
            placeholder="请设置密码"
            size="large"
          >
            <template #prefix>
              <LockOutlined />
            </template>
          </a-input-password>
        </a-form-item>

        <a-form-item name="confirmPassword" label="确认密码">
          <a-input-password
            v-model:value="registerForm.confirmPassword"
            placeholder="请再次输入密码"
            size="large"
          >
            <template #prefix>
              <LockOutlined />
            </template>
          </a-input-password>
        </a-form-item>

        <a-form-item name="email" label="电子邮箱 (选填)">
          <a-input
            v-model:value="registerForm.email"
            placeholder="请输入邮箱"
            size="large"
          >
            <template #prefix>
              <MailOutlined />
            </template>
          </a-input>
        </a-form-item>

        <a-alert
          message="温馨提示"
          description="您正在注册顾客账号，酒店员工账号请联系管理员开通。"
          type="info"
          show-icon
          class="register-tip"
        />
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, watch, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { message } from 'ant-design-vue'
import type { Rule } from 'ant-design-vue/es/form'
import {
  HomeOutlined,
  UserOutlined,
  LockOutlined,
  MailOutlined,
  MobileOutlined,
  LogoutOutlined,
  SwapOutlined,
  QrcodeOutlined,
  DownOutlined,
  CompassOutlined,
  AppstoreOutlined,
  IdcardOutlined,
  FileTextOutlined,
  CrownOutlined,
  CheckCircleOutlined
} from '@ant-design/icons-vue'
import { useAppStore } from '@/stores/app'
import { authService, normalizeRole, CANONICAL_ROLES } from '@/api/auth'
import { initWebSocket } from '@/utils/websocket'
import QRCode from 'qrcode'

const route = useRoute()
const router = useRouter()
const appStore = useAppStore()

// 用户信息
const userInfo = computed(() => appStore.userInfo)

// 会员等级逻辑
const memberLevelInfo = computed(() => {
  if (!appStore.userStatus?.is_member || !appStore.userStatus?.member_info) {
    return null
  }
  const scheme = appStore.systemConfigs.member_scheme
  const member = appStore.userStatus.member_info

  if (member?.level_label) {
    return {
      label: member.level_label,
      color: appStore.getLevelInfo(member.member_level, member.experience).color || '#C9A962',
      textColor: '#fff'
    }
  }

  const info = appStore.getLevelInfo(member.member_level, member.experience)
  return {
    label: info.label,
    color: info.color || '#C9A962',
    textColor: '#fff'
  }
})

// 初始化
appStore.initUserInfo()

// 获取用户状态
const fetchUserStatus = async () => {
  if (appStore.userInfo) {
    try {
      const status = await authService.getUserStatus()
      appStore.setUserStatus(status)
    } catch (error) {
      console.error('获取用户状态失败:', error)
    }
  }
}

onMounted(() => {
  fetchUserStatus()
  if (route.query.login === '1') {
    appStore.showLoginModal = true
  }
})

watch(() => route.query.login, (newVal) => {
  if (newVal === '1') {
    appStore.showLoginModal = true
  }
})

watch(() => appStore.userInfo, (newVal) => {
  if (newVal) {
    fetchUserStatus()
  } else {
    appStore.setUserStatus(null)
  }
})

// 登录相关
const showRegisterModal = ref(false)
const activeTab = ref('password')
const loginLoading = ref(false)
const loginFormRef = ref()
const loginForm = reactive({
  phone: '',
  password: ''
})

const loginRules: Record<string, Rule[]> = {
  phone: [
    { required: true, message: '请输入手机号', trigger: 'blur' },
    { pattern: /^1[3-9]\d{9}$/, message: '请输入正确的手机号', trigger: 'blur' }
  ],
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 6, message: '密码长度至少 6 位', trigger: 'blur' }
  ]
}

// 扫码登录相关
const generatingToken = ref(false)
const scanToken = ref('')
const tokenExpireTime = ref(0)
const qrExpired = ref(false)
const qrCanvasRef = ref<HTMLCanvasElement>()
let pollTimer: ReturnType<typeof setTimeout> | null = null

// 注册相关
const registerLoading = ref(false)
const registerFormRef = ref()
const registerForm = reactive({
  username: '',
  password: '',
  confirmPassword: '',
  email: '',
  phone: ''
})

const registerRules: Record<string, Rule[]> = {
  username: [
    { required: true, message: '请输入昵称', trigger: 'blur' },
    { min: 2, max: 20, message: '昵称长度在 2-20 个字符', trigger: 'blur' }
  ],
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 6, message: '密码长度至少 6 位', trigger: 'blur' }
  ],
  confirmPassword: [
    { required: true, message: '请确认密码', trigger: 'blur' },
    {
      validator: (_rule: Rule, value: string) => {
        if (value && value !== registerForm.password) {
          return Promise.reject('两次输入的密码不一致')
        }
        return Promise.resolve()
      },
      trigger: 'blur'
    }
  ],
  phone: [
    { required: true, message: '请输入手机号', trigger: 'blur' },
    { pattern: /^1[3-9]\d{9}$/, message: '请输入11位手机号', trigger: 'blur' }
  ]
}

function isActive(path: string): boolean {
  return route.path.startsWith(path)
}

function redirectByRole(rawRole?: string) {
  const role = normalizeRole(rawRole)
  if (role === CANONICAL_ROLES.SYSTEM_ADMIN) {
    router.push('/system/dashboard')
  } else if (role === CANONICAL_ROLES.HOTEL_ADMIN) {
    router.push('/hotel-admin/dashboard')
  } else if (role === CANONICAL_ROLES.STAFF) {
    router.push('/reception/dashboard')
  } else {
    router.push('/guest/booking')
  }
}

const handleLoginCancel = () => {
  appStore.showLoginModal = false
  if (route.query.login === '1') {
    const query = { ...route.query }
    delete query.login
    router.replace({ query })
  }
}

// 登录处理
const handleLogin = async () => {
  try {
    loginLoading.value = true
    const { user } = await authService.login(loginForm)

    appStore.showLoginModal = false
    message.success('欢迎回来，登录成功')

    const redirect = route.query.redirect as string
    if (redirect) {
      router.push(redirect)
    } else {
      const role = normalizeRole(user.role)
      switch (role) {
        case CANONICAL_ROLES.SYSTEM_ADMIN: router.push('/system/dashboard'); break
        case CANONICAL_ROLES.HOTEL_ADMIN: router.push('/hotel-admin/dashboard'); break
        case CANONICAL_ROLES.STAFF: router.push('/reception/dashboard'); break
        default: fetchUserStatus()
      }
    }
  } catch (error) {
    console.error('登录失败:', error)
  } finally {
    loginLoading.value = false
  }
}

// 生成扫码登录二维码
const handleGenerateQrToken = async () => {
  try {
    generatingToken.value = true
    qrExpired.value = false
    const { token, expiresAt } = await authService.qrGenerate()

    scanToken.value = token
    tokenExpireTime.value = new Date(expiresAt).getTime()

    await nextTick()
    if (qrCanvasRef.value) {
      await QRCode.toCanvas(qrCanvasRef.value, token, {
        width: 200,
        margin: 2,
        color: { dark: '#1A2B4A', light: '#ffffff' }
      })
    }

    pollQrStatus(token)
    message.success('二维码已生成')
  } catch (error) {
    console.error('生成二维码失败:', error)
  } finally {
    generatingToken.value = false
  }
}

// 轮询扫码状态
const pollQrStatus = async (token: string) => {
  try {
    await new Promise(resolve => setTimeout(resolve, 3000))
    const result = await authService.qrStatus(token)

    if (result.status === 'confirmed' && result.token && result.user) {
      const normalizedUser = { ...result.user, role: normalizeRole(result.user.role) }
      localStorage.setItem('auth_token', result.token)
      appStore.setUserInfo(normalizedUser)
      initWebSocket()
      message.success('扫码登录成功')
      appStore.showLoginModal = false
      redirectByRole(normalizedUser.role)
      return
    }

    if (result.status === 'expired') {
      qrExpired.value = true
      return
    }

    if (scanToken.value === token) {
      pollQrStatus(token)
    }
  } catch (error: any) {
    if (scanToken.value === token && !qrExpired.value) {
      pollQrStatus(token)
    }
  }
}

// 倒计时结束
const handleCountdownFinish = () => {
  qrExpired.value = true
  message.warning('二维码已过期，请刷新')
}

// 重置扫码
const handleResetScan = () => {
  if (pollTimer) {
    clearTimeout(pollTimer)
    pollTimer = null
  }
  scanToken.value = ''
  tokenExpireTime.value = 0
  qrExpired.value = false
}

// 处理注册
const handleRegister = async () => {
  try {
    registerLoading.value = true
    await authService.register({
      username: registerForm.username,
      password: registerForm.password,
      email: registerForm.email || undefined,
      phone: registerForm.phone
    })

    message.success('注册成功，请登录')
    showRegisterModal.value = false

    registerForm.username = ''
    registerForm.password = ''
    registerForm.confirmPassword = ''
    registerForm.email = ''
    registerForm.phone = ''

    activeTab.value = 'password'
  } catch (error) {
    console.error('注册失败:', error)
  } finally {
    registerLoading.value = false
  }
}

// 处理登出
const handleLogout = async () => {
  try {
    await authService.logout()
    message.success('已安全退出')
    router.push('/guest/booking')
  } catch (error) {
    console.error('登出失败:', error)
  }
}
</script>

<style scoped>
.guest-layout {
  min-height: 100vh;
  background: var(--hotel-bg);
}

/* 顶部导航 */
.guest-header {
  background: #fff;
  box-shadow: var(--hotel-shadow-sm);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 48px;
  height: 72px;
  position: sticky;
  top: 0;
  z-index: 100;
}

.header-left {
  display: flex;
  align-items: center;
}

.logo {
  display: flex;
  align-items: center;
  gap: 12px;
  cursor: pointer;
  transition: opacity 0.3s;
}

.logo:hover {
  opacity: 0.8;
}

.logo-icon {
  width: 44px;
  height: 44px;
  background: linear-gradient(135deg, var(--hotel-primary) 0%, var(--hotel-primary-light) 100%);
  border-radius: var(--hotel-radius);
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-size: 22px;
}

.logo-text {
  display: flex;
  flex-direction: column;
  line-height: 1.3;
}

.brand-name {
  font-size: 20px;
  font-weight: 700;
  color: var(--hotel-primary);
  letter-spacing: 1px;
}

.brand-tagline {
  font-size: 12px;
  color: var(--hotel-text-muted);
}

/* 导航菜单 */
.header-nav {
  display: flex;
  gap: 8px;
}

.header-nav .ant-btn {
  font-size: 15px;
  padding: 8px 20px;
  border-radius: var(--hotel-radius-sm);
  font-weight: 500;
  color: var(--hotel-text-secondary);
  display: flex;
  align-items: center;
  gap: 6px;
  transition: all 0.3s;
}

.header-nav .ant-btn:hover {
  color: var(--hotel-primary);
  background: var(--hotel-bg-secondary);
}

.header-nav .ant-btn.active {
  background: var(--hotel-primary);
  color: #fff;
}

/* 右侧区域 */
.header-right {
  display: flex;
  align-items: center;
  gap: 16px;
}

.connection-status {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  color: var(--hotel-text-muted);
  padding: 6px 12px;
  background: var(--hotel-bg-secondary);
  border-radius: 20px;
}

.connection-status.online {
  color: var(--hotel-success);
}

.status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--hotel-text-muted);
}

.connection-status.online .status-dot {
  background: var(--hotel-success);
  animation: pulse 2s infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

.login-btn {
  border-radius: var(--hotel-radius-sm);
  font-weight: 500;
  padding: 0 24px;
  height: 40px;
}

.user-status-tags {
  display: flex;
  gap: 8px;
  align-items: center;
}

.member-tag,
.checkin-tag {
  border-radius: 20px;
  font-size: 12px;
  padding: 2px 10px;
  display: flex;
  align-items: center;
  gap: 4px;
}

.checkin-tag {
  background: rgba(39, 174, 96, 0.1);
  color: var(--hotel-success);
  border: 1px solid rgba(39, 174, 96, 0.3);
}

.switch-side-btn {
  font-weight: 500;
  color: var(--hotel-gold);
  display: flex;
  align-items: center;
  gap: 4px;
}

.switch-side-btn:hover {
  color: var(--hotel-gold-dark);
}

.user-dropdown-wrapper {
  display: flex;
  align-items: center;
  gap: 10px;
  cursor: pointer;
  padding: 6px 12px;
  border-radius: var(--hotel-radius);
  transition: background 0.3s;
  border: 1px solid var(--hotel-border);
}

.user-dropdown-wrapper:hover {
  background: var(--hotel-bg-secondary);
}

.header-avatar {
  border: 2px solid var(--hotel-gold);
}

.header-username {
  font-size: 14px;
  color: var(--hotel-text);
  font-weight: 500;
  max-width: 100px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dropdown-arrow {
  font-size: 12px;
  color: var(--hotel-text-muted);
}

.user-dropdown-menu {
  border-radius: var(--hotel-radius);
}

.logout-item {
  color: var(--hotel-error);
}

/* 主内容区 */
.guest-content {
  max-width: 1440px;
  width: 100%;
  margin: 0 auto;
  padding: 32px 48px;
  min-height: calc(100vh - 72px - 200px);
}

/* 页脚 */
.guest-footer {
  background: var(--hotel-primary);
  padding: 48px 48px 32px;
  color: rgba(255, 255, 255, 0.8);
}

.footer-content {
  max-width: 1440px;
  margin: 0 auto;
  text-align: center;
}

.footer-brand {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  margin-bottom: 24px;
}

.footer-logo {
  font-size: 32px;
  color: var(--hotel-gold);
}

.footer-brand span {
  font-size: 24px;
  font-weight: 700;
  color: #fff;
  letter-spacing: 2px;
}

.footer-links {
  display: flex;
  justify-content: center;
  gap: 32px;
  margin-bottom: 32px;
}

.footer-links a {
  color: rgba(255, 255, 255, 0.7);
  font-size: 14px;
  transition: color 0.3s;
}

.footer-links a:hover {
  color: var(--hotel-gold);
}

.footer-copyright {
  border-top: 1px solid rgba(255, 255, 255, 0.1);
  padding-top: 24px;
}

.footer-copyright p {
  margin: 0;
  font-size: 13px;
  color: rgba(255, 255, 255, 0.5);
}

.footer-sub {
  margin-top: 8px !important;
  font-size: 12px !important;
  color: var(--hotel-gold) !important;
  font-style: italic;
}

/* 登录弹窗 */
.login-modal :deep(.ant-modal-content) {
  border-radius: var(--hotel-radius-lg);
  overflow: hidden;
}

.login-modal-header {
  text-align: center;
  padding: 32px 0 24px;
}

.login-logo {
  width: 64px;
  height: 64px;
  background: linear-gradient(135deg, var(--hotel-primary) 0%, var(--hotel-primary-light) 100%);
  border-radius: var(--hotel-radius);
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 16px;
  color: #fff;
  font-size: 32px;
}

.login-modal-header h3 {
  font-size: 22px;
  font-weight: 600;
  color: var(--hotel-primary);
  margin: 0 0 8px;
}

.login-modal-header p {
  font-size: 14px;
  color: var(--hotel-text-muted);
  margin: 0;
}

.login-tabs :deep(.ant-tabs-nav) {
  margin-bottom: 24px;
}

.login-tabs :deep(.ant-tabs-tab) {
  font-size: 15px;
  padding: 12px 24px;
}

.login-form,
.register-form {
  padding: 0 8px;
}

.login-form :deep(.ant-form-item-label) {
  font-weight: 500;
  color: var(--hotel-text);
}

.submit-btn {
  height: 44px;
  font-size: 16px;
  font-weight: 500;
  border-radius: var(--hotel-radius-sm);
  margin-top: 8px;
}

.form-footer {
  text-align: center;
  margin-top: 20px;
  color: var(--hotel-text-secondary);
  font-size: 14px;
}

.register-link {
  color: var(--hotel-gold);
  font-weight: 500;
  margin-left: 4px;
  cursor: pointer;
}

.register-link:hover {
  color: var(--hotel-gold-dark);
}

/* 扫码登录 */
.scan-login-container {
  padding: 20px 0;
  text-align: center;
}

.scan-intro {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 20px;
}

.scan-icon-wrapper {
  width: 80px;
  height: 80px;
  background: var(--hotel-bg-secondary);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--hotel-primary);
  font-size: 40px;
}

.scan-tip {
  color: var(--hotel-text-secondary);
  margin: 0;
  font-size: 14px;
}

.generate-btn {
  height: 44px;
  font-weight: 500;
}

.scan-waiting {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 16px;
}

.qr-code-wrapper {
  position: relative;
  display: inline-block;
  border: 2px solid var(--hotel-border);
  border-radius: var(--hotel-radius);
  padding: 16px;
  background: #fff;
}

.qr-expired-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(255, 255, 255, 0.95);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  border-radius: var(--hotel-radius-sm);
  gap: 12px;
}

.qr-expired-overlay p {
  margin: 0;
  color: var(--hotel-error);
  font-size: 14px;
}

.scan-status {
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--hotel-text-secondary);
  font-size: 14px;
}

.expired-text {
  color: var(--hotel-error);
}

.countdown :deep(.ant-statistic-content) {
  font-size: 14px;
  color: var(--hotel-gold);
}

/* 注册弹窗 */
.register-modal :deep(.ant-modal-content) {
  border-radius: var(--hotel-radius-lg);
}

.register-modal :deep(.ant-modal-header) {
  border-bottom: 1px solid var(--hotel-border);
  padding: 20px 24px;
}

.register-modal :deep(.ant-modal-title) {
  font-size: 18px;
  font-weight: 600;
  color: var(--hotel-primary);
}

.register-form :deep(.ant-form-item-label) {
  font-weight: 500;
  color: var(--hotel-text);
}

.register-tip {
  margin-top: 8px;
}

.register-tip :deep(.ant-alert-message) {
  font-weight: 500;
  color: var(--hotel-primary);
}

/* 响应式 */
@media (max-width: 1024px) {
  .guest-header {
    padding: 0 24px;
  }
  
  .header-nav {
    display: none;
  }
  
  .guest-content {
    padding: 24px;
  }
  
  .footer-links {
    flex-wrap: wrap;
    gap: 16px 32px;
  }
}

@media (max-width: 768px) {
  .guest-header {
    padding: 0 16px;
    height: 64px;
  }
  
  .brand-tagline {
    display: none;
  }
  
  .connection-status .status-text {
    display: none;
  }
  
  .user-status-tags {
    display: none;
  }
  
  .guest-content {
    padding: 16px;
  }
  
  .guest-footer {
    padding: 32px 16px;
  }
}
</style>
