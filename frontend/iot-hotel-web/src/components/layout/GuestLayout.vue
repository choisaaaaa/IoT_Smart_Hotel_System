<template>
  <div class="guest-layout">
    <a-layout>
      <a-layout-header class="guest-header">
        <div class="header-left">
          <MobileOutlined class="header-logo" />
          <h3 @click="$router.push('/guest/booking')">智联酒店</h3>
        </div>
        <div class="header-nav">
          <a-button
            type="text"
            :class="{ active: isActive('/guest/booking') || isActive('/guest/checkin-online') }"
            @click="$router.push('/guest/booking')"
          >预订入住</a-button>
          <a-button
            type="text"
            :class="{ active: isActive('/guest/room') }"
            @click="$router.push('/guest/room')"
          >客房服务</a-button>
          <a-button
            type="text"
            :class="{ active: isActive('/guest/orders') }"
            @click="$router.push('/guest/orders')"
          >我的订单</a-button>
          <a-button
            type="text"
            :class="{ active: isActive('/guest/profile') }"
            @click="$router.push('/guest/profile')"
          >个人中心</a-button>
        </div>
        <div class="header-right">
          <a-tag :color="appStore.connected ? 'success' : 'default'" size="small">
            {{ appStore.connected ? '在线' : '' }}
          </a-tag>
          <template v-if="!userInfo">
            <a-button type="primary" @click="appStore.showLoginModal = true">
              <UserOutlined /> 登录/注册
            </a-button>
          </template>
          <template v-else>
            <div class="user-status-tags" v-if="appStore.userStatus">
              <a-tag v-if="appStore.userStatus.is_member" color="gold">会员</a-tag>
              <a-tag v-if="appStore.userStatus.is_checked_in" color="cyan">已入住</a-tag>
            </div>
            <a-dropdown>
              <a class="user-dropdown" @click.prevent>
                <a-tag color="blue">{{ userInfo.username }}</a-tag>
              </a>
              <template #overlay>
                <a-menu>
                  <a-menu-item key="profile" @click="$router.push('/guest/profile')">
                    <UserOutlined /> 个人中心
                  </a-menu-item>
                  <a-menu-item key="orders" @click="$router.push('/guest/orders')">
                    <OrderedListOutlined /> 我的订单
                  </a-menu-item>
                  <a-menu-divider />
                  <a-menu-item key="logout" @click="handleLogout">
                    <LogoutOutlined /> 退出登录
                  </a-menu-item>
                </a-menu>
              </template>
            </a-dropdown>
          </template>
        </div>
      </a-layout-header>

      <a-layout-content class="guest-content">
        <router-view />
      </a-layout-content>

      <a-layout-footer class="guest-footer">
        <p>©2026 智联酒店 - 智慧酒店物联网控制系统</p>
      </a-layout-footer>
    </a-layout>

    <!-- 登录弹窗 -->
    <a-modal
      v-model:open="appStore.showLoginModal"
      :footer="null"
      :closable="true"
      width="420px"
      @cancel="appStore.showLoginModal = false"
    >
      <template #title>
        <div style="text-align: center; font-size: 18px; font-weight: 600;">
          欢迎登录智联酒店
        </div>
      </template>

      <a-tabs v-model:activeKey="activeTab" class="login-tabs">
        <a-tab-pane key="password" tab="密码登录">
          <a-form
            ref="loginFormRef"
            :model="loginForm"
            :rules="loginRules"
            layout="vertical"
            @finish="handleLogin"
          >
            <a-form-item name="phone" label="手机号">
              <a-input
                v-model:value="loginForm.phone"
                placeholder="请输入手机号"
                size="large"
              >
                <template #prefix>
                  <PhoneOutlined />
                </template>
              </a-input>
            </a-form-item>

            <a-form-item name="password" label="密码">
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
              >
                登录
              </a-button>
            </a-form-item>

            <div class="form-footer">
              <span>还没有账号？</span>
              <a @click="showRegisterModal = true">立即注册</a>
            </div>
          </a-form>
        </a-tab-pane>

        <a-tab-pane key="scan" tab="扫码登录">
          <div class="scan-login-container">
            <div v-if="!scanToken" class="scan-intro">
              <p class="scan-tip">请使用智联酒店 APP 扫码登录</p>
              <a-button
                type="primary"
                @click="handleGenerateToken"
                :loading="generatingToken"
                block
              >
                获取登录码
              </a-button>
            </div>

            <div v-else class="scan-waiting">
              <a-spin size="large" tip="等待扫码中..." />
              <div class="scan-token-display">
                <p>登录码：</p>
                <a-typography-text copyable :copyable-text="scanToken">
                  {{ scanToken.substring(0, 20) }}...
                </a-typography-text>
              </div>
              <a-statistic-countdown
                :value="tokenExpireTime"
                format="mm:ss"
                @finish="handleCountdownFinish"
              />
              <a-button @click="handleResetScan" block style="margin-top: 16px">
                重新获取
              </a-button>
            </div>
          </div>
        </a-tab-pane>
      </a-tabs>
    </a-modal>

    <!-- 注册弹窗 -->
    <a-modal
      v-model:open="showRegisterModal"
      title="用户注册"
      @ok="handleRegister"
      :confirmLoading="registerLoading"
      cancelText="取消"
      okText="确定"
    >
      <a-form
        ref="registerFormRef"
        :model="registerForm"
        :rules="registerRules"
        layout="vertical"
      >
        <a-form-item name="username" label="昵称">
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

        <a-form-item name="password" label="密码">
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

        <a-form-item name="email" label="邮箱 (可选)">
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

        <a-form-item name="phone" label="手机号">
          <a-input
            v-model:value="registerForm.phone"
            placeholder="请输入手机号"
            size="large"
          >
            <template #prefix>
              <PhoneOutlined />
            </template>
          </a-input>
        </a-form-item>

        <a-alert
          message="提示"
          description="注册默认为顾客账号。如需前台员工或酒店管理权限，请在登录后通过APP端申请绑定酒店。"
          type="info"
          show-icon
        />
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { message } from 'ant-design-vue'
import type { Rule } from 'ant-design-vue/es/form'
import {
  MobileOutlined,
  UserOutlined,
  LockOutlined,
  MailOutlined,
  PhoneOutlined,
  LogoutOutlined,
  OrderedListOutlined
} from '@ant-design/icons-vue'
import { useAppStore } from '@/stores/app'
import { authService, normalizeRole } from '@/api/auth'

const route = useRoute()
const router = useRouter()
const appStore = useAppStore()

// 用户信息
const userInfo = computed(() => appStore.userInfo)

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
  if (role === 'system') {
    router.push('/system/dashboard')
  } else if (role === 'admin' || role === 'manager') {
    router.push('/hotel-admin/dashboard')
  } else if (role === 'staff') {
    router.push('/reception/dashboard')
  } else {
    router.push('/guest/booking')
  }
}

// 处理登录
const handleLogin = async () => {
  try {
    loginLoading.value = true
    const { user } = await authService.login(loginForm)

    message.success('登录成功')
    appStore.showLoginModal = false

    // 根据角色跳转
    redirectByRole(user.role)
  } catch (error) {
    console.error('登录失败:', error)
  } finally {
    loginLoading.value = false
  }
}

// 生成扫码 Token
const handleGenerateToken = async () => {
  try {
    generatingToken.value = true
    const { token, expiresAt } = await authService.generateToken(loginForm)

    scanToken.value = token
    tokenExpireTime.value = new Date(expiresAt).getTime()

    // 自动开始扫码登录轮询
    pollScanLogin(token)

    message.success('登录码生成成功，请使用管理端 APP 扫码')
  } catch (error) {
    console.error('生成登录码失败:', error)
  } finally {
    generatingToken.value = false
  }
}

// 轮询扫码登录状态
const pollScanLogin = async (token: string) => {
  try {
    await new Promise(resolve => setTimeout(resolve, 3000))
    const { user } = await authService.scanLogin(token)
    message.success('扫码登录成功')
    appStore.showLoginModal = false

    redirectByRole(user.role)
  } catch (error: any) {
    if (error?.response?.status === 401 || error?.response?.data?.code === 401) {
      pollScanLogin(token)
    }
  }
}

// 倒计时结束
const handleCountdownFinish = () => {
  message.warning('登录码已过期，请重新获取')
  scanToken.value = ''
}

// 重置扫码
const handleResetScan = () => {
  scanToken.value = ''
  tokenExpireTime.value = 0
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

    // 清空表单
    registerForm.username = ''
    registerForm.password = ''
    registerForm.confirmPassword = ''
    registerForm.email = ''
    registerForm.phone = ''

    // 切换到密码登录
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
    message.success('已退出登录')
    router.push('/guest/booking')
  } catch (error) {
    console.error('登出失败:', error)
  }
}
</script>

<style scoped>
.guest-layout { min-height: 100vh; background: linear-gradient(180deg, #f0f5ff 0%, #e6f7ff 100%); }
.guest-header {
  background: #fff;
  box-shadow: 0 2px 8px rgba(0,0,0,.08);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 32px;
  height: 60px;
  position: sticky;
  top: 0;
  z-index: 100;
}
.header-left { display: flex; align-items: center; gap: 10px; cursor: pointer; }
.header-logo { font-size: 26px; color: #1890ff; }
.header-left h3 { margin: 0; font-size: 18px; background: linear-gradient(135deg, #1890ff, #722ed1); -webkit-background-clip: text; background-clip: text; -webkit-text-fill-color: transparent; font-weight: 700; }
.header-nav { display: flex; gap: 4px; }
.header-nav .ant-btn { font-size: 15px; padding: 4px 16px; border-radius: 20px; font-weight: 500; }
.header-nav .ant-btn.active { background: #e6f7ff; color: #1890ff; }
.header-right { display: flex; align-items: center; gap: 12px; }
.user-status-tags { display: flex; gap: 4px; align-items: center; }
.user-dropdown { cursor: pointer; }
.guest-content {
  max-width: 1200px;
  margin: 0 auto;
  padding: 28px 24px;
  min-height: calc(100vh - 60px - 80px);
}
.guest-footer {
  text-align: center;
  padding: 20px;
  color: rgba(0,0,0,0.45);
  background: transparent;
}
.guest-footer p { margin: 4px 0; font-size: 13px; }

.login-tabs { margin-top: 16px; }
.form-footer { text-align: center; margin-top: 16px; color: #666; }
.form-footer a { color: #667eea; text-decoration: none; margin-left: 8px; cursor: pointer; }
.form-footer a:hover { text-decoration: underline; }

.scan-login-container { padding: 20px 0; text-align: center; }
.scan-intro { display: flex; flex-direction: column; align-items: center; gap: 16px; }
.scan-tip { color: #666; margin: 0; font-size: 14px; }
.scan-waiting { display: flex; flex-direction: column; align-items: center; gap: 16px; }
.scan-token-display { margin-top: 16px; }
.scan-token-display p { margin: 0 0 8px 0; color: #666; font-size: 14px; }
</style>
