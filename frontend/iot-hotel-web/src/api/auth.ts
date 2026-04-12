import axios from 'axios'
import type { AxiosInstance, AxiosRequestConfig, AxiosResponse } from 'axios'
import { message } from 'ant-design-vue'
import { useAppStore } from '@/stores/app'
import { initWebSocket, disconnectWebSocket } from '@/utils/websocket'
import type { ApiResponse } from '@/types'

export const CANONICAL_ROLES = {
  SYSTEM_ADMIN: 'system_admin',
  HOTEL_ADMIN: 'hotel_admin',
  STAFF: 'staff',
  CUSTOMER: 'customer',
} as const

export function normalizeRole(role?: string): string {
  const value = String(role || '').trim().toLowerCase()
  const compact = value.replace(/[\s_-]+/g, '')
  if (value === 'system' || compact === 'systemadmin' || compact === 'sysadmin' || compact === 'superadmin' || compact === 'platformadmin') {
    return CANONICAL_ROLES.SYSTEM_ADMIN
  }
  if (value === 'admin' || compact === 'hoteladmin' || value === 'manager' || compact === 'hotelmanager') {
    return CANONICAL_ROLES.HOTEL_ADMIN
  }
  if (value === 'staff' || value === 'receptionist' || value === 'reception' || compact === 'frontdesk') {
    return CANONICAL_ROLES.STAFF
  }
  if (value === 'user' || value === 'customer' || value === 'guest') {
    return CANONICAL_ROLES.CUSTOMER
  }
  return value
}

export function isSystemAdmin(role?: string): boolean {
  return normalizeRole(role) === CANONICAL_ROLES.SYSTEM_ADMIN
}

export function isHotelAdmin(role?: string): boolean {
  return normalizeRole(role) === CANONICAL_ROLES.HOTEL_ADMIN
}

export function isStaff(role?: string): boolean {
  return normalizeRole(role) === CANONICAL_ROLES.STAFF
}

export function isCustomer(role?: string): boolean {
  return normalizeRole(role) === CANONICAL_ROLES.CUSTOMER
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
  avatar?: string
  uid?: string
  role: string
  hotel_id?: number
  hotel_name?: string
  permissions: string[]
}

class AuthService {
  private api: AxiosInstance

  constructor() {
    const baseURL = '/api/v1'

    this.api = axios.create({
      baseURL,
      timeout: 10000,
      headers: {
        'Content-Type': 'application/json'
      }
    })

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

  async generateToken(params: LoginParams): Promise<{ token: string; expiresAt: string }> {
    const res = await this.api.post<any, ApiResponse<{ token: string; expiresAt: string }>>(
      '/auth/generate-token',
      params
    )
    return res.data!
  }

  async scanLogin(token: string): Promise<{ token: string; user: UserInfo }> {
    const res = await this.api.post<any, ApiResponse<{ token: string; sessionToken: string; user: UserInfo }>>(
      '/auth/scan-login',
      { token }
    )
    const { token: jwtToken, user } = res.data!
    const normalizedUser = { ...user, role: normalizeRole(user.role) }

    localStorage.setItem('auth_token', jwtToken)
    const appStore = useAppStore()
    appStore.setUserInfo(normalizedUser)

    initWebSocket()

    return { token: jwtToken, user: normalizedUser }
  }

  async login(params: LoginParams): Promise<{ token: string; user: UserInfo }> {
    const res = await this.api.post<any, ApiResponse<{ token: string; sessionToken: string; user: UserInfo }>>(
      '/auth/login',
      params
    )
    const { token: jwtToken, user } = res.data!
    const normalizedUser = { ...user, role: normalizeRole(user.role) }

    localStorage.setItem('auth_token', jwtToken)
    const appStore = useAppStore()
    appStore.setUserInfo(normalizedUser)

    initWebSocket()

    return { token: jwtToken, user: normalizedUser }
  }

  async register(params: RegisterParams): Promise<void> {
    await this.api.post('/auth/register', params)
  }

  async logout(): Promise<void> {
    try {
      await this.api.post('/auth/logout')
    } catch (error) {
      console.error('登出失败:', error)
    } finally {
      disconnectWebSocket()
      const appStore = useAppStore()
      appStore.setUserInfo(null)
      appStore.setRegistration(false, '')
    }
  }

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

  async getUserStatus(): Promise<{ phone: string; is_member: boolean; member_info: any; is_checked_in: boolean; checkin_info: any }> {
    const res = await this.api.get<any, ApiResponse<{ phone: string; is_member: boolean; member_info: any; is_checked_in: boolean; checkin_info: any }>>(
      '/members/status'
    )
    return res.data!
  }

  isAuthenticated(): boolean {
    return !!localStorage.getItem('auth_token')
  }

  getUserInfo(): UserInfo | null {
    const userInfo = localStorage.getItem('user_info')
    return userInfo ? JSON.parse(userInfo) : null
  }

  hasRole(role: string | string[]): boolean {
    const user = this.getUserInfo()
    if (!user) return false

    const roles = (Array.isArray(role) ? role : [role]).map(normalizeRole)
    return roles.includes(normalizeRole(user.role))
  }

  hasPermission(permission: string | string[]): boolean {
    const user = this.getUserInfo()
    if (!user) return false

    const permissions = Array.isArray(permission) ? permission : [permission]
    return permissions.some(p => user.permissions.includes(p))
  }
}

export const authService = new AuthService()
