import request from './request'
import type { DeviceInfo, ApiResponse } from '@/types'

export const deviceApi = {
  getDeviceList: (params?: { status?: string; audit_status?: string; room_id?: number }) =>
    request.get<ApiResponse<DeviceInfo[]>>('/devices', { params }),

  getDeviceDetail: (id: number) =>
    request.get<ApiResponse<DeviceInfo>>(`/devices/${id}`),

  auditDevice: (id: number, data: { status: 'approved' | 'rejected'; room_id?: number; area?: string; device_name?: string }) =>
    request.put<ApiResponse<any>>(`/devices/${id}/audit`, data),

  deleteDevice: (id: number) =>
    request.delete<ApiResponse<any>>(`/devices/${id}`),

  sendCommand: (id: number, commandType: string, commandValue: string) =>
    request.post<ApiResponse<any>>(`/devices/${id}/command`, {
      command_type: commandType,
      command_value: commandValue
    }),

  getDeviceStatusHistory: (deviceId: string, params?: { limit?: number }) =>
    request.get<ApiResponse<any[]>>(`/devices/${deviceId}/history`, { params })
}
