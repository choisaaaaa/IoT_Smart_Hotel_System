import request from './request'
import type { ApiResponse } from '@/types'

export interface EnvironmentData {
  room_id: number
  room_number: string
  floor_id: number
  floor_name: string
  temperature: number
  humidity: number
  smoke_level: number
  smoke_alarm: boolean
  light_level: number
  noise_level: number
  pm25: number
  update_time: string
  status: 'normal' | 'warning' | 'danger'
  environment_score: number
}

export interface EnvironmentSummary {
  avg_temperature: number
  avg_humidity: number
  avg_smoke_level: number
  avg_noise_level: number
  avg_pm25: number
  avg_environment_score: number
  normal_count: number
  warning_count: number
  danger_count: number
  total_rooms: number
}

export interface EnvironmentResponse {
  list: EnvironmentData[]
  total: number
  summary: EnvironmentSummary
  update_time: string
}

export interface EnvironmentHistoryItem {
  time: string
  temperature: number
  humidity: number
  smoke_level: number
  noise_level: number
  pm25: number
}

export interface FireAlarmRecord {
  id: number
  room_id: number
  room_number: string
  alarm_type: 'smoke' | 'temperature' | 'manual'
  severity: 'low' | 'medium' | 'high' | 'critical'
  value: number
  threshold: number
  triggered_at: string
  resolved_at?: string
  status: 'active' | 'acknowledged' | 'resolved' | 'false_alarm'
  handled_by?: string
  description: string
}

export interface DeviceInfo {
  device_id: string
  device_type: string
  device_name: string
  room_id: number
  status: 'online' | 'offline' | 'error'
  is_running: boolean
  current_value: number
  unit: string
  battery_level?: number
  last_maintenance?: string
}

export interface EnergyConsumption {
  room_id: number
  room_number: string
  floor_id: number
  today_kwh: number
  yesterday_kwh: number
  this_month_kwh: number
  peak_usage: number
  peak_time: string
  devices_count: number
  efficiency_rating: 'A' | 'B' | 'C' | 'D' | 'F'
}

export interface EventLog {
  id: number
  event_type: 'fire_alarm' | 'device_error' | 'environment_warning' | 'device_control' | 'maintenance' | 'energy_alert'
  room_id: number
  room_number: string
  title: string
  description: string
  severity: 'info' | 'warning' | 'error' | 'critical'
  created_at: string
  resolved: boolean
  resolved_at?: string
  handled_by?: string
}

export const environmentApi = {
  getEnvironmentData: (params?: { floor_id?: number; room_id?: number; status?: string }) =>
    request.get<ApiResponse<EnvironmentResponse>>('/environment', { params }),

  getEnvironmentHistory: (params?: { room_id?: number; hours?: number }) =>
    request.get<ApiResponse<{ room_id: string | number; history: EnvironmentHistoryItem[]; period: string }>>('/environment/history', { params }),

  getFireAlarms: (params?: { status?: string; severity?: string; limit?: number }) =>
    request.get<ApiResponse<{ alarms: FireAlarmRecord[]; total: number; summary: any }>>('/environment/fire-alarms', { params }),

  acknowledgeAlarm: (alarmId: number, data: { handler: string; notes?: string }) =>
    request.put<ApiResponse<any>>(`/environment/fire-alarms/${alarmId}/acknowledge`, data),

  resolveAlarm: (alarmId: number, data: { resolution: string; handler: string }) =>
    request.put<ApiResponse<any>>(`/environment/fire-alarms/${alarmId}/resolve`, data),

  getRoomDevices: (params?: { room_id?: number }) =>
    request.get<ApiResponse<{ devices: DeviceInfo[]; total: number; summary: any }>>('/environment/devices', { params }),

  controlDevice: (deviceId: string, data: { action: string; value?: number }) =>
    request.post<ApiResponse<any>>(`/environment/devices/${deviceId}/control`, data),

  getEnergyConsumption: (params?: { room_id?: number; period?: string }) =>
    request.get<ApiResponse<{ consumption: EnergyConsumption[]; total: number; summary: any }>>('/environment/energy', { params }),

  getEventLogs: (params?: { event_type?: string; severity?: string; limit?: number }) =>
    request.get<ApiResponse<{ logs: EventLog[]; total: number; summary: any }>>('/environment/event-logs', { params }),

  getDashboardStats: () =>
    request.get<ApiResponse<any>>('/environment/dashboard')
}
