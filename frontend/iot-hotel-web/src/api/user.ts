import request from './request'
import type { ApiResponse } from '../types'

export interface UserProfile {
  id: number
  username: string
  email: string | null
  phone: string | null
  avatar: string | null
  role: string
  hotel_id: number | null
}

export const userApi = {
  // 更新个人资料
  updateProfile: (data: { username?: string; email?: string; phone?: string; code?: string; avatar?: string }) =>
    request.put<ApiResponse<{ user: UserProfile }>>('/users/profile', data),

  // 发送验证码
  sendCode: (phone: string) =>
    request.post<ApiResponse<any>>('/users/send-code', { phone }),

  // 修改密码
  updatePassword: (id: number, data: any) =>
    request.put<ApiResponse<any>>(`/users/${id}/password`, data)
}
