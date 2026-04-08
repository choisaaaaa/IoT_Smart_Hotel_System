import request from './request'
import type { ApiResponse, PaginatedResponse } from '@/types'

export interface DeliveryOrder {
  id: number
  order_no: string
  room_id: number
  room_number?: string
  item_category: 'beverage' | 'food' | 'daily' | 'other'
  item_name: string
  quantity: number
  note?: string
  status: 'pending' | 'delivering' | 'completed'
  created_at: string
  completed_at?: string
}

export const deliveryApi = {
  getList: (params?: { page?: number; pageSize?: number; status?: string; item_category?: string }) =>
    request.get<PaginatedResponse<DeliveryOrder>>('/delivery', { params }),

  create: (data: {
    room_id: number
    item_category: 'beverage' | 'food' | 'daily' | 'other'
    item_name: string
    quantity: number
    note?: string
  }) =>
    request.post<ApiResponse<{ id: number; order_no: string }>>('/delivery', data),

  complete: (id: number) =>
    request.put<ApiResponse<any>>(`/delivery/${id}/complete`)
}
