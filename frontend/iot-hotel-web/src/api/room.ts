import request from './request'
import type { RoomInfo, PaginatedResponse, ApiResponse } from '@/types'

export const roomApi = {
  getRoomList: (params?: { 
    page?: number; 
    pageSize?: number; 
    status?: string; 
    floor?: number; 
    type?: string; 
    groupBy?: string; 
    hotel_id?: number;
    room_type_id?: number;
  }) =>
    request.get<PaginatedResponse<RoomInfo>>('/rooms', { params }),

  getRoomsByFloor: (hotelId?: number) =>
    request.get<ApiResponse<{ floor: number; rooms: RoomInfo[] }[]>>('/rooms', { params: { groupBy: 'floor', hotel_id: hotelId } }),

  getRoomDetail: (id: number, hotelId?: number) =>
    request.get<ApiResponse<RoomInfo>>(`/rooms/${id}`, { params: hotelId ? { hotel_id: hotelId } : {} }),

  createRoom: (data: Partial<RoomInfo> & { hotel_id: number }) =>
    request.post<ApiResponse<{ id: number }>>('/rooms', data),

  updateRoom: (id: number, data: Partial<RoomInfo>, hotelId?: number) =>
    request.put<ApiResponse<any>>(`/rooms/${id}`, { ...data, ...(hotelId ? { hotel_id: hotelId } : {}) }),

  deleteRoom: (id: number, hotelId?: number) =>
    request.delete<ApiResponse<any>>(`/rooms/${id}`, { data: hotelId ? { hotel_id: hotelId } : {} }),

  updateRoomStatus: (id: number, status: string, hotelId?: number) =>
    request.patch<ApiResponse<RoomInfo>>(`/rooms/${id}/status`, { status, ...(hotelId ? { hotel_id: hotelId } : {}) }),

  getStats: () =>
    request.get<ApiResponse<any>>('/rooms/stats')
}