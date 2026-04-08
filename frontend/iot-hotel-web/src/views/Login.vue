<template>
  <div class="login-container">
    <div class="login-box">
      <div class="login-header">
        <h1 class="login-title">智联酒店</h1>
        <p class="login-subtitle">智慧酒店物联网控制系统</p>
      </div>

      <a-tabs v-model:activeKey="activeTab" class="login-tabs">
        <a-tab-pane key="password" tab="密码登录">
          <a-form
            ref="loginFormRef"
            :model="loginForm"
            :rules="loginRules"
            layout="vertical"
            @finish="handleLogin"
          >
            <a-form-item name="username" label="用户名">
              <a-input
                v-model:value="loginForm.username"
                placeholder="请输入用户名"
                size="large"
              >
                <template #prefix>
                  <UserOutlined />
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
                :loading="loading"
              >
                登录
              </a-button>
            </a-form-item>

            <div class="form-footer">
              <span>还没有账号？</span>
              <a @click="showRegisterModal">立即注册</a>
            </div>
          </a-form>
        </a-tab-pane>

        <a-tab-pane key="scan" tab="扫码登录">
          <div class="scan-login-container">
            <div v-if="!scanToken" class="scan-intro">
              <a-qrcode
                :value="scanUrl"
                :size="200"
                :bg-color="'#ffffff'"
                :color="'#000000'"
                :level="'H'"
              />
              <p class="scan-tip">请使用管理端 APP 扫码登录</p>
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
              <a-countdown
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
    </div>

    <!-- 注册弹窗 -->
    <a-modal
      v-model:visible="registerVisible"
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
        <a-form-item name="username" label="用户名">
          <a-input
            v-model:value="registerForm.username"
            placeholder="请设置用户名"
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

        <a-alert
          message="提示"
          description="注册用户默认为普通用户权限，如需升级请联系管理员。"
          type="info"
          show-icon
        />
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue'
import { useRouter } from 'vue-router'
import { message } from 'ant-design-vue'
import {
  UserOutlined,
  LockOutlined,
  MailOutlined
} from '@ant-design/icons-vue'
import { authService } from '@/api/auth'
import type { Rule } from 'ant-design-vue/es/form'

const router = useRouter()

// 登录相关
const activeTab = ref('password')
const loading = ref(false)
const loginFormRef = ref()
const loginForm = reactive({
  username: '',
  password: ''
})

const loginRules: Record<string, Rule[]> = {
  username: [
    { required: true, message: '请输入用户名', trigger: 'blur' },
    { min: 3, max: 20, message: '用户名长度在 3-20 个字符', trigger: 'blur' }
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
const scanUrl = 'scan-login://iot-hotel-system'

// 注册相关
const registerVisible = ref(false)
const registerLoading = ref(false)
const registerFormRef = ref()
const registerForm = reactive({
  username: '',
  password: '',
  confirmPassword: '',
  email: ''
})

const registerRules: Record<string, Rule[]> = {
  username: [
    { required: true, message: '请输入用户名', trigger: 'blur' },
    { min: 3, max: 20, message: '用户名长度在 3-20 个字符', trigger: 'blur' }
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
  ]
}

// 处理登录
const handleLogin = async () => {
  try {
    loading.value = true
    const { user } = await authService.login(loginForm)
    
    message.success('登录成功')
    
    // 根据角色跳转到不同的页面
    switch (user.role) {
      case 'admin':
        router.push('/admin/dashboard')
        break
      case 'staff':
        router.push('/reception/dashboard')
        break
      case 'user':
        router.push('/guest/booking')
        break
      default:
        router.push('/admin/dashboard')
    }
  } catch (error) {
    console.error('登录失败:', error)
  } finally {
    loading.value = false
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
    
    // 检查 token 是否仍然有效 (未被使用)
    const response = await fetch('http://localhost:9000/api/v1/auth/scan-login', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ token })
    })
    
    const result = await response.json()
    
    if (result.code === 200) {
      // 扫码登录成功
      message.success('扫码登录成功')
      
      // 保存用户信息
      localStorage.setItem('user_info', JSON.stringify(result.data.user))
      
      // 根据角色跳转
      const user = result.data.user
      switch (user.role) {
        case 'admin':
          router.push('/admin/dashboard')
          break
        case 'staff':
          router.push('/reception/dashboard')
          break
        case 'user':
          router.push('/guest/booking')
          break
        default:
          router.push('/admin/dashboard')
      }
    } else if (result.code === 401) {
      // Token 无效或已过期，继续轮询
      pollScanLogin(token)
    }
  } catch (error) {
    // 网络错误，继续轮询
    pollScanLogin(token)
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

// 显示注册弹窗
const showRegisterModal = () => {
  registerVisible.value = true
}

// 处理注册
const handleRegister = async () => {
  try {
    registerLoading.value = true
    await authService.register({
      username: registerForm.username,
      password: registerForm.password,
      email: registerForm.email || undefined
    })
    
    message.success('注册成功，请登录')
    registerVisible.value = false
    
    // 清空表单
    registerForm.username = ''
    registerForm.password = ''
    registerForm.confirmPassword = ''
    registerForm.email = ''
    
    // 切换到密码登录
    activeTab.value = 'password'
  } catch (error) {
    console.error('注册失败:', error)
  } finally {
    registerLoading.value = false
  }
}
</script>

<style scoped>
.login-container {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 20px;
}

.login-box {
  width: 100%;
  max-width: 420px;
  background: #ffffff;
  border-radius: 16px;
  padding: 40px;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.1);
}

.login-header {
  text-align: center;
  margin-bottom: 32px;
}

.login-title {
  font-size: 32px;
  font-weight: 600;
  color: #1a1a1a;
  margin: 0 0 8px 0;
}

.login-subtitle {
  font-size: 14px;
  color: #666;
  margin: 0;
}

.login-tabs {
  margin-top: 24px;
}

.form-footer {
  text-align: center;
  margin-top: 16px;
  color: #666;
}

.form-footer a {
  color: #667eea;
  text-decoration: none;
  margin-left: 8px;
}

.form-footer a:hover {
  text-decoration: underline;
}

.scan-login-container {
  padding: 20px 0;
  text-align: center;
}

.scan-intro {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 16px;
}

.scan-tip {
  color: #666;
  margin: 0;
  font-size: 14px;
}

.scan-waiting {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 16px;
}

.scan-token-display {
  margin-top: 16px;
}

.scan-token-display p {
  margin: 0 0 8px 0;
  color: #666;
  font-size: 14px;
}
</style>
