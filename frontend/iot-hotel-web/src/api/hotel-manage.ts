import request from './request'
import type { ApiResponse } from '@/types'

export interface HotelManageInfo {
  id: number
  hotel_name: string
  hotel_code: string
  hotel_address: string
  city: string
  hotel_phone: string
  hotel_star: number
  total_rooms: number
  occupied_rooms: number
  occupancy_rate: string
  logo: string | null
  description: string
  created_at: string
  updated_at: string
}

export const hotelManageApi = {
  // 获取当前登录用户所属酒店的信息
  getHotelInfo: (params?: { hotel_id?: number }) =>
    request.get<ApiResponse<HotelManageInfo>>('/hotel', { params }),

  // 获取所有酒店列表 (仅 System 角色)
  getAllHotels: () =>
    request.get<ApiResponse<HotelManageInfo[]>>('/hotel/all'),

  // 创建新酒店 (仅 System 角色)
  createHotel: (data: Partial<HotelManageInfo>) =>
    request.post<ApiResponse<{ id: number }>>('/hotel', data),

  // 更新酒店信息 (可指定 ID)
  updateHotelInfo: (id: number | null, data: Partial<HotelManageInfo>) => {
    const url = id ? `/hotel/${id}` : '/hotel'
    return request.put<ApiResponse<any>>(url, data)
  },

  // 删除酒店 (仅 System 角色)
  deleteHotel: (id: number) =>
    request.delete<ApiResponse<any>>(`/hotel/${id}`)
}
