import request from './request'
import type { RoomTypeInfo, ApiResponse } from '@/types'

export const roomTypeApi = {
  getRoomTypeList: () =>
    request.get<ApiResponse<RoomTypeInfo[]>>('/room-types'),

  getRoomTypeDetail: (id: number) =>
    request.get<ApiResponse<RoomTypeInfo>>(`/room-types/${id}`),

  createRoomType: (data: Partial<RoomTypeInfo>) =>
    request.post<ApiResponse<{ id: number }>>('/room-types', data),

  updateRoomType: (id: number, data: Partial<RoomTypeInfo>) =>
    request.put<ApiResponse<any>>(`/room-types/${id}`, data),

  deleteRoomType: (id: number) =>
    request.delete<ApiResponse<any>>(`/room-types/${id}`)
}
