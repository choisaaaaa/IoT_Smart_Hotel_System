import request from './request'
import type { RoomInfo, PaginatedResponse, ApiResponse } from '@/types'

export const roomApi = {
  getRoomList: (params?: { page?: number; pageSize?: number; status?: string; floor?: number; type?: string; groupBy?: string }) =>
    request.get<PaginatedResponse<RoomInfo>>('/rooms', { params }),

  getRoomsByFloor: () =>
    request.get<ApiResponse<{ floor: number; rooms: RoomInfo[] }[]>>('/rooms', { params: { groupBy: 'floor' } }),

  getRoomDetail: (id: number) =>
    request.get<ApiResponse<RoomInfo>>(`/rooms/${id}`),

  createRoom: (data: Partial<RoomInfo>) =>
    request.post<ApiResponse<{ id: number }>>('/rooms', data),

  updateRoom: (id: number, data: Partial<RoomInfo>) =>
    request.put<ApiResponse<any>>(`/rooms/${id}`, data),

  deleteRoom: (id: number) =>
    request.delete<ApiResponse<any>>(`/rooms/${id}`),

  updateRoomStatus: (id: number, status: string) =>
    request.patch<ApiResponse<RoomInfo>>(`/rooms/${id}/status`, { status })
}