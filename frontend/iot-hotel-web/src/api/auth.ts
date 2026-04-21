import request from './request'
import { message } from 'ant-design-vue'
import { useAppStore } from '@/stores/app'
import { initWebSocket, disconnectWebSocket } from '@/utils/websocket'
import type { ApiResponse } from '@/types'

export const CANONICAL_ROLES = {
  SYSTEM_ADMIN: 'system_admin',
  HOTEL_ADMIN: 'hotel_admin',
  STAFF: 'staff',
  CUSTOMER: 'customer',
  GUEST: 'guest',
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
  if (value === 'user' || value === 'customer') {
    return CANONICAL_ROLES.CUSTOMER
  }
  if (value === 'guest' || value === 'visitor') {
    return CANONICAL_ROLES.GUEST
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

export function isGuest(role?: string): boolean {
  return normalizeRole(role) === CANONICAL_ROLES.GUEST
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
  async generateToken(params: LoginParams): Promise<{ token: string; expiresAt: string }> {
    const res = await request.post<ApiResponse<{ token: string; expiresAt: string }>>(
      '/auth/generate-token',
      params
    )
    return res.data!
  }

  async qrGenerate(): Promise<{ token: string; expiresAt: string }> {
    const res = await request.post<ApiResponse<{ token: string; expiresAt: string }>>(
      '/auth/qr-generate'
    )
    return res.data!
  }

  async qrStatus(token: string): Promise<{ status: string; token?: string; sessionToken?: string; user?: UserInfo }> {
    const res = await request.get<ApiResponse<{ status: string; token?: string; sessionToken?: string; user?: UserInfo }>>(
      '/auth/qr-status',
      { params: { token } }
    )
    return res.data!
  }

  async scanLogin(token: string): Promise<{ token: string; user: UserInfo }> {
    const res = await request.post<ApiResponse<{ token: string; sessionToken: string; user: UserInfo }>>(
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
    const res = await request.post<ApiResponse<{ token: string; sessionToken: string; user: UserInfo }>>(
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
    await request.post('/auth/register', params)
  }

  async logout(): Promise<void> {
    try {
      await request.post('/auth/logout')
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
    const res = await request.get<ApiResponse<{ user: UserInfo; role: string; permissions: string[] }>>(
      '/auth/me'
    )
    const payload: any = res.data
    return payload as UserInfo
  }

  async getUserStatus(): Promise<{ phone: string; is_member: boolean; member_info: any; is_checked_in: boolean; checkin_info: any }> {
    const res = await request.get<ApiResponse<{ phone: string; is_member: boolean; member_info: any; is_checked_in: boolean; checkin_info: any }>>(
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
