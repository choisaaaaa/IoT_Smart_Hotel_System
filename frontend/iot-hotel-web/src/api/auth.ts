import axios from 'axios'
import type { AxiosInstance, AxiosRequestConfig, AxiosResponse } from 'axios'
import { message } from 'ant-design-vue'
import { useAppStore } from '@/stores/app'
import type { ApiResponse } from '@/types'

export interface LoginParams {
  username: string
  password: string
}

export interface RegisterParams {
  username: string
  password: string
  email?: string
  hotel_id: number
}

export interface UserInfo {
  id: number
  username: string
  email?: string
  role: string
  hotel_id: number
  permissions: string[]
}

class AuthService {
  private api: AxiosInstance

  constructor() {
    this.api = axios.create({
      baseURL: 'http://localhost:9000/api/v1',
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
    
    // 保存 token 和用户信息
    localStorage.setItem('auth_token', jwtToken)
    const appStore = useAppStore()
    appStore.setUserInfo(user)
    
    return { token: jwtToken, user }
  }

  // 用户名密码登录
  async login(params: LoginParams): Promise<{ token: string; user: UserInfo }> {
    const res = await this.api.post<any, ApiResponse<{ token: string; sessionToken: string; user: UserInfo }>>(
      '/auth/login',
      params
    )
    const { token: jwtToken, user } = res.data!
    
    // 保存 token 和用户信息
    localStorage.setItem('auth_token', jwtToken)
    const appStore = useAppStore()
    appStore.setUserInfo(user)
    
    return { token: jwtToken, user }
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
      // 清除本地存储
      const appStore = useAppStore()
      appStore.setUserInfo(null)
    }
  }

  // 获取当前用户信息
  async getCurrentUser(): Promise<UserInfo> {
    const res = await this.api.get<any, ApiResponse<{ user: UserInfo; role: string; permissions: string[] }>>(
      '/auth/me'
    )
    return res.data! as any
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
    
    const roles = Array.isArray(role) ? role : [role]
    return roles.includes(user.role)
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
