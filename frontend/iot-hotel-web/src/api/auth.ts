import axios from 'axios'
import type { AxiosInstance, AxiosRequestConfig, AxiosResponse } from 'axios'
import { message } from 'ant-design-vue'
import { useAppStore } from '@/stores/app'
import { initWebSocket, disconnectWebSocket } from '@/utils/websocket'
import type { ApiResponse } from '@/types'

export function normalizeRole(role?: string): string {
  const value = String(role || '').trim().toLowerCase()
  const compact = value.replace(/[\s_-]+/g, '')
  if (value === 'system' || compact === 'systemadmin' || compact === 'sysadmin' || compact === 'superadmin' || compact === 'platformadmin') {
    return 'system'
  }
  if (value === 'staff' || value === 'receptionist' || compact === 'frontdesk') {
    return 'staff'
  }
  if (value === 'manager' || value === 'hotelmanager' || value === 'hoteladmin') {
    return 'manager'
  }
  if (value === 'admin') {
    return 'admin'
  }
  return value
}

export interface LoginParams {
  phone: string
  password: string
}

export interface RegisterParams {
  username: string
  password: string
  email?: string
  phone: string
}

export interface UserInfo {
  id: number
  username: string
  email?: string
  phone?: string
  uid?: string
  role: string
  hotel_id?: number
  hotel_name?: string
  permissions: string[]
}

class AuthService {
  private api: AxiosInstance

  constructor() {
    // 使用相对路径，让Vite代理处理请求
    const baseURL = '/api/v1'

    this.api = axios.create({
      baseURL,
      timeout: 10000,
      headers: {
        'Content-Type': 'application/json'
      }
    })

    // 请求拦截器
    this.api.interceptors.request.use(
      (config) => {
        const token = localStorage.getItem('auth_token')
        if (token) {
          config.headers.Authorization = `Bearer ${token}`
        }
        return config
      },
      (error) => {
        return Promise.reject(error)
      }
    )

    // 响应拦截器
    this.api.interceptors.response.use(
      (response: AxiosResponse) => {
        return response.data
      },
      (error) => {
        console.error('API Error:', error)
        const errorMsg = error.response?.data?.message || '网络错误，请稍后重试'
        message.error(errorMsg)
        return Promise.reject(error)
      }
    )
  }

  // 生成 API Token (用于扫码登录)
  async generateToken(params: LoginParams): Promise<{ token: string; expiresAt: string }> {
    const res = await this.api.post<any, ApiResponse<{ token: string; expiresAt: string }>>(
      '/auth/generate-token',
      params
    )
    return res.data!
  }

  // 扫码登录
  async scanLogin(token: string): Promise<{ token: string; user: UserInfo }> {
    const res = await this.api.post<any, ApiResponse<{ token: string; sessionToken: string; user: UserInfo }>>(
      '/auth/scan-login',
      { token }
    )
    const { token: jwtToken, user } = res.data!
    const normalizedUser = { ...user, role: normalizeRole(user.role) }

    // 保存 token 和用户信息
    localStorage.setItem('auth_token', jwtToken)
    const appStore = useAppStore()
    appStore.setUserInfo(normalizedUser)

    // 初始化 WebSocket 并自动上线
    initWebSocket()

    return { token: jwtToken, user: normalizedUser }
  }

  // 用户名密码登录
  async login(params: LoginParams): Promise<{ token: string; user: UserInfo }> {
    const res = await this.api.post<any, ApiResponse<{ token: string; sessionToken: string; user: UserInfo }>>(
      '/auth/login',
      params
    )
    const { token: jwtToken, user } = res.data!
    const normalizedUser = { ...user, role: normalizeRole(user.role) }

    // 保存 token 和用户信息
    localStorage.setItem('auth_token', jwtToken)
    const appStore = useAppStore()
    appStore.setUserInfo(normalizedUser)

    // 初始化 WebSocket 并自动上线
    initWebSocket()

    return { token: jwtToken, user: normalizedUser }
  }

  // 用户注册
  async register(params: RegisterParams): Promise<void> {
    await this.api.post('/auth/register', params)
  }

  // 登出
  async logout(): Promise<void> {
    try {
      await this.api.post('/auth/logout')
    } catch (error) {
      console.error('登出失败:', error)
    } finally {
      // 断开 WebSocket 连接
      disconnectWebSocket()
      // 清除本地存储
      const appStore = useAppStore()
      appStore.setUserInfo(null)
      appStore.setRegistration(false, '')
    }
  }

  // 获取当前用户信息
  async getCurrentUser(): Promise<UserInfo> {
    const res = await this.api.get<any, ApiResponse<{ user: UserInfo; role: string; permissions: string[] }>>(
      '/auth/me'
    )
    const payload: any = res.data
    const normalizedRole = normalizeRole(payload?.role || payload?.user?.role)
    return {
      ...(payload?.user || {}),
      role: normalizedRole,
      permissions: payload?.permissions || payload?.user?.permissions || []
    } as UserInfo
  }

  // 获取用户会员和入住状态
  async getUserStatus(): Promise<{ phone: string; is_member: boolean; member_info: any; is_checked_in: boolean; checkin_info: any }> {
    const res = await this.api.get<any, ApiResponse<{ phone: string; is_member: boolean; member_info: any; is_checked_in: boolean; checkin_info: any }>>(
      '/members/status'
    )
    return res.data!
  }

  // 检查是否已登录
  isAuthenticated(): boolean {
    return !!localStorage.getItem('auth_token')
  }

  // 获取用户信息
  getUserInfo(): UserInfo | null {
    const userInfo = localStorage.getItem('user_info')
    return userInfo ? JSON.parse(userInfo) : null
  }

  // 检查用户角色
  hasRole(role: string | string[]): boolean {
    const user = this.getUserInfo()
    if (!user) return false

    const roles = (Array.isArray(role) ? role : [role]).map(normalizeRole)
    return roles.includes(normalizeRole(user.role))
  }

  // 检查用户权限
  hasPermission(permission: string | string[]): boolean {
    const user = this.getUserInfo()
    if (!user) return false

    const permissions = Array.isArray(permission) ? permission : [permission]
    return permissions.some(p => user.permissions.includes(p))
  }
}

export const authService = new AuthService()
