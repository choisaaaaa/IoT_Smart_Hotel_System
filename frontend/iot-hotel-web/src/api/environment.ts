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
  alarm_type: 'smoke' | 'temperature' | 'manual' | 'co' | 'unknown'
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
  getEnvironmentData: async (params?: { floor_id?: number; room_id?: number; status?: string }) => {
    const queryParams: any = {}
    if (params?.floor_id) queryParams.floor_id = params.floor_id
    if (params?.room_id) queryParams.room_id = params.room_id
    if (params?.status) queryParams.status = params.status

    const res: any = await request.get('/environment', { params: queryParams })
    if (res?.success && res?.data) {
      return { data: res.data }
    }
    return { data: { list: [], total: 0, summary: {} as EnvironmentSummary, update_time: '' } }
  },

  getEnvironmentHistory: async (params?: { room_id?: number; device_id?: string; hours?: number }) => {
    const queryParams: any = {}
    if (params?.room_id) queryParams.room_id = params.room_id
    if (params?.device_id) queryParams.device_id = params.device_id
    if (params?.hours) queryParams.hours = params.hours

    const res: any = await request.get('/environment/history', { params: queryParams })
    if (res?.success && res?.data) {
      return { data: res.data }
    }
    return { data: { room_id: params?.room_id || '', history: [], period: '' } }
  },

  getFireAlarms: async (params?: { status?: string; severity?: string; limit?: number }) => {
    const queryParams: any = {}
    if (params?.status) queryParams.status = params.status
    if (params?.severity) queryParams.severity = params.severity
    if (params?.limit) queryParams.limit = params.limit

    const res: any = await request.get('/environment/fire-alarms', { params: queryParams })
    if (res?.success && res?.data) {
      return { data: res.data }
    }
    return { data: { alarms: [], total: 0, summary: { active_count: 0, acknowledged_count: 0, resolved_today: 0, false_alarm_count: 0 } } }
  },

  acknowledgeAlarm: async (alarmId: number, data: { handler: string; notes?: string }) => {
    return request.put(`/environment/fire-alarms/${alarmId}/acknowledge`, {
      handler: data.handler,
      notes: data.notes
    })
  },

  resolveAlarm: async (alarmId: number, data: { resolution: string; handler: string }) => {
    return request.put(`/environment/fire-alarms/${alarmId}/resolve`, {
      resolution: data.resolution,
      handler: data.handler
    })
  },

  getRoomDevices: async (params?: { room_id?: number }) => {
    const queryParams: any = {}
    if (params?.room_id) queryParams.room_id = params.room_id

    const res: any = await request.get('/environment/devices', { params: queryParams })
    if (res?.success && res?.data) {
      return { data: res.data }
    }
    return { data: { devices: [], total: 0, summary: { online_count: 0, offline_count: 0, error_count: 0, running_count: 0, total_devices: 0, online_rate: 0 } } }
  },

  controlDevice: async (deviceId: string, data: { action: string; value?: number }) => {
    return request.post(`/environment/devices/${deviceId}/control`, {
      action: data.action,
      value: data.value
    })
  },

  getEnergyConsumption: async (params?: { room_id?: number; period?: string }) => {
    const queryParams: any = {}
    if (params?.room_id) queryParams.room_id = params.room_id
    if (params?.period) queryParams.period = params.period

    const res: any = await request.get('/environment/energy', { params: queryParams })
    if (res?.success && res?.data) {
      return { data: res.data }
    }
    return { data: { consumption: [], total: 0, summary: { total_today_kwh: 0, total_yesterday_kwh: 0, total_month_kwh: 0, savings_rate: 0, estimated_monthly_cost: 0, most_efficient_room: '-', least_efficient_room: '-' } } }
  },

  getEventLogs: async (params?: { event_type?: string; severity?: string; limit?: number }) => {
    const queryParams: any = {}
    if (params?.event_type) queryParams.event_type = params.event_type
    if (params?.severity) queryParams.severity = params.severity
    if (params?.limit) queryParams.limit = params.limit

    const res: any = await request.get('/environment/event-logs', { params: queryParams })
    if (res?.success && res?.data) {
      return { data: res.data }
    }
    return { data: { logs: [], total: 0, summary: { critical_count: 0, unresolved_count: 0, today_total: 0 } } }
  },

  getDashboardStats: async () => {
    const res: any = await request.get('/environment/dashboard')
    if (res?.success && res?.data) {
      return { data: res.data }
    }
    return { data: {} }
  }
}
