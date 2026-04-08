import request from './request'
import type { ApiResponse, PaginatedResponse } from '@/types'

export interface MaintenanceTicket {
  id: number
  ticket_no?: string
  room_id: number
  room_number?: string
  fault_type: string
  fault_description: string
  priority: 'low' | 'medium' | 'high' | 'urgent'
  status: 'pending' | 'processing' | 'completed'
  created_at: string
  updated_at: string
}

export const maintenanceApi = {
  getList: (params?: { page?: number; pageSize?: number; status?: string; fault_type?: string; priority?: string }) =>
    request.get<PaginatedResponse<MaintenanceTicket>>('/maintenance', { params }),

  create: (data: {
    room_id: number
    fault_type: string
    fault_description: string
    priority: 'low' | 'medium' | 'high' | 'urgent'
  }) =>
    request.post<ApiResponse<{ id: number }>>('/maintenance', data),

  assign: (id: number, staff_id: number) =>
    request.put<ApiResponse<any>>(`/maintenance/${id}/assign`, { staff_id }),

  complete: (id: number) =>
    request.put<ApiResponse<any>>(`/maintenance/${id}/complete`)
}
