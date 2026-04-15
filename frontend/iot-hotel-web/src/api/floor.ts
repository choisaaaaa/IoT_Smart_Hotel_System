import request from './request'
import type { FloorInfo, ApiResponse } from '@/types'

export const floorApi = {
  getFloorList: (params?: any) =>
    request.get<ApiResponse<FloorInfo[]>>('/floors', { params }),

  getFloorDetail: (id: number) =>
    request.get<ApiResponse<FloorInfo>>(`/floors/${id}`),

  createFloor: (data: Partial<FloorInfo>) =>
    request.post<ApiResponse<{ id: number }>>('/floors', data),

  updateFloor: (id: number, data: Partial<FloorInfo>) =>
    request.put<ApiResponse<any>>(`/floors/${id}`, data),

  deleteFloor: (id: number) =>
    request.delete<ApiResponse<any>>(`/floors/${id}`)
}
