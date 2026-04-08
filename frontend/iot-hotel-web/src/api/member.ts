import request from './request'
import type { ApiResponse, PaginatedResponse } from '@/types'

export interface MemberInfo {
  id: number
  phone: string
  name: string
  member_level: string
  points: number
  balance: number
}

export const memberApi = {
  getMemberList: (params?: { page?: number; pageSize?: number; level?: string }) =>
    request.get<PaginatedResponse<MemberInfo>>('/members', { params }),

  createMember: (data: { phone: string; password: string; name: string; id_number: string }) =>
    request.post<ApiResponse<{ id: number }>>('/members', data)
}
