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

function mapAlarmStatus(status: string): string {
  switch (status) {
    case 'pending': return 'active'
    case 'processing': return 'acknowledged'
    case 'resolved': return 'resolved'
    case 'ignored': return 'false_alarm'
    default: return status
  }
}

function mapAlarmType(type: string): string {
  switch (type) {
    case 'smoke':
    case 'fire':
      return 'smoke'
    case 'temperature':
    case 'overheat':
      return 'temperature'
    case 'co':
    case 'gas':
      return 'co'
    default:
      return type || 'unknown'
  }
}

function mapAlarmLevel(level: string): string {
  switch (level) {
    case 'emergency':
      return 'critical'
    case 'error':
      return 'high'
    case 'warning':
      return 'medium'
    case 'info':
      return 'low'
    default:
      return level || 'low'
  }
}

function mapEventType(alarmType: string): string {
  switch (alarmType) {
    case 'smoke':
    case 'fire':
      return 'fire_alarm'
    case 'temperature':
    case 'overheat':
      return 'environment_warning'
    case 'offline':
    case 'device_error':
      return 'device_error'
    default:
      return 'device_error'
  }
}

function mapSeverity(level: string): string {
  switch (level) {
    case 'emergency':
    case 'critical':
      return 'critical'
    case 'error':
    case 'high':
      return 'error'
    case 'warning':
    case 'medium':
      return 'warning'
    default:
      return 'info'
  }
}

function getAlarmTitle(alarmType: string, alarmLevel: string): string {
  const levelEmoji = (() => {
    switch (alarmLevel) {
      case 'emergency':
      case 'critical':
        return '🚨'
      case 'error':
      case 'high':
        return '⚠️'
      case 'warning':
      case 'medium':
        return '⚡'
      default:
        return 'ℹ️'
    }
  })()

  const typeText = (() => {
    switch (alarmType) {
      case 'smoke':
      case 'fire':
        return '烟雾告警'
      case 'temperature':
      case 'overheat':
        return '温度告警'
      case 'offline':
        return '设备离线'
      case 'device_error':
        return '设备故障'
      default:
        return '设备告警'
    }
  })()

  return `${levelEmoji} ${typeText}`
}

export const environmentApi = {
  getEnvironmentData: async (params?: { floor_id?: number; room_id?: number; status?: string }) => {
    const queryParams: any = {}
    if (params?.room_id) queryParams.room_id = params.room_id
    if (params?.status) queryParams.status = params.status

    const res: any = await request.get('/devices', { params: queryParams })
    if (res.data?.code === 200 || res.data) {
      const data = res.data?.data ?? res.data
      let deviceList: any[] = []
      if (Array.isArray(data)) {
        deviceList = data
      } else if (data?.list) {
        deviceList = data.list
      }

      const sensorDevices = deviceList.filter((d: any) =>
        d.device_type === 'sensor' ||
        d.device_type === 'smoke_detector' ||
        d.device_type === 'temperature_sensor' ||
        d.device_type === 'humidity_sensor' ||
        d.device_type === 'thermostat'
      )

      const envList: EnvironmentData[] = sensorDevices.map((d: any) => {
        const status = d.device_status || d.status || 'offline'
        let envStatus: 'normal' | 'warning' | 'danger' = 'normal'
        if (status === 'error') envStatus = 'danger'
        else if (status === 'offline') envStatus = 'warning'

        return {
          room_id: d.room_id || 0,
          room_number: d.room_number || String(d.room_id || '-'),
          floor_id: d.floor_id || Math.floor((d.room_id || 0) / 100),
          floor_name: (d.floor_id || Math.floor((d.room_id || 0) / 100)) + '楼',
          temperature: 24,
          humidity: 55,
          smoke_level: 0,
          smoke_alarm: false,
          light_level: 0,
          noise_level: 0,
          pm25: 0,
          update_time: d.last_seen || new Date().toISOString(),
          status: envStatus,
          environment_score: envStatus === 'normal' ? 90 : envStatus === 'warning' ? 70 : 40
        }
      })

      const normalCount = envList.filter(e => e.status === 'normal').length
      const warningCount = envList.filter(e => e.status === 'warning').length
      const dangerCount = envList.filter(e => e.status === 'danger').length

      const summary: EnvironmentSummary = {
        avg_temperature: envList.length > 0 ? parseFloat((envList.reduce((s, e) => s + e.temperature, 0) / envList.length).toFixed(1)) : 0,
        avg_humidity: envList.length > 0 ? parseFloat((envList.reduce((s, e) => s + e.humidity, 0) / envList.length).toFixed(1)) : 0,
        avg_smoke_level: envList.length > 0 ? parseFloat((envList.reduce((s, e) => s + e.smoke_level, 0) / envList.length).toFixed(1)) : 0,
        avg_noise_level: 0,
        avg_pm25: 0,
        avg_environment_score: envList.length > 0 ? parseFloat((envList.reduce((s, e) => s + e.environment_score, 0) / envList.length).toFixed(1)) : 0,
        normal_count: normalCount,
        warning_count: warningCount,
        danger_count: dangerCount,
        total_rooms: envList.length
      }

      return { data: { list: envList, total: envList.length, summary, update_time: new Date().toISOString() } }
    }
    return { data: { list: [], total: 0, summary: {} as EnvironmentSummary, update_time: '' } }
  },

  getEnvironmentHistory: async (params?: { room_id?: number; hours?: number }) => {
    const now = new Date()
    const startDate = new Date(now.getTime() - (params?.hours || 24) * 3600000)
    const queryParams: any = {
      start_date: startDate.toISOString().split('T')[0],
      end_date: now.toISOString().split('T')[0],
      group_by: 'day'
    }
    if (params?.room_id) queryParams.room_id = params.room_id

    const res: any = await request.get('/energy/consumption', { params: queryParams })
    if (res.data?.code === 200 || res.data) {
      return { data: res.data?.data ?? res.data }
    }
    return { data: { room_id: params?.room_id || '', history: [], period: '' } }
  },

  getFireAlarms: async (params?: { status?: string; severity?: string; limit?: number }) => {
    const queryParams: any = { pageSize: params?.limit || 50 }
    if (params?.status) {
      const statusMap: Record<string, string> = {
        active: 'pending',
        acknowledged: 'processing',
        resolved: 'resolved',
        false_alarm: 'ignored'
      }
      queryParams.status = statusMap[params.status] || params.status
    }
    if (params?.severity) queryParams.alarm_level = params.severity

    const res: any = await request.get('/device-alarms', { params: queryParams })
    if (res.data?.code === 200 || res.data) {
      const data = res.data?.data ?? res.data
      const alarmList: any[] = data?.list || data?.alarms || []

      const mappedAlarms: FireAlarmRecord[] = alarmList.map((alarm: any) => ({
        id: alarm.id,
        room_id: alarm.room_id,
        room_number: alarm.room_number || String(alarm.room_id || '-'),
        alarm_type: mapAlarmType(alarm.alarm_type) as any,
        severity: mapAlarmLevel(alarm.alarm_level) as any,
        value: alarm.sensor_value || 0,
        threshold: alarm.threshold || 0,
        triggered_at: alarm.created_at || '',
        resolved_at: alarm.handled_at,
        status: mapAlarmStatus(alarm.status) as any,
        handled_by: alarm.handled_by?.toString(),
        description: alarm.alarm_content || alarm.alarm_type || '设备告警'
      }))

      const activeCount = mappedAlarms.filter(a => a.status === 'active').length
      const acknowledgedCount = mappedAlarms.filter(a => a.status === 'acknowledged').length
      const resolvedCount = mappedAlarms.filter(a => a.status === 'resolved').length
      const falseAlarmCount = mappedAlarms.filter(a => a.status === 'false_alarm').length

      return {
        data: {
          alarms: mappedAlarms,
          total: data?.pagination?.total || mappedAlarms.length,
          summary: {
            active_count: activeCount,
            acknowledged_count: acknowledgedCount,
            resolved_today: resolvedCount,
            false_alarm_count: falseAlarmCount
          }
        }
      }
    }
    return { data: { alarms: [], total: 0, summary: { active_count: 0, acknowledged_count: 0, resolved_today: 0, false_alarm_count: 0 } } }
  },

  acknowledgeAlarm: async (alarmId: number, data: { handler: string; notes?: string }) => {
    return request.put(`/device-alarms/${alarmId}/handle`, {
      status: 'resolved',
      handled_by: data.handler,
      handle_remark: data.notes
    })
  },

  resolveAlarm: async (alarmId: number, data: { resolution: string; handler: string }) => {
    return request.put(`/device-alarms/${alarmId}/handle`, {
      status: 'resolved',
      handle_remark: data.resolution
    })
  },

  getRoomDevices: async (params?: { room_id?: number }) => {
    const queryParams: any = {}
    if (params?.room_id) queryParams.room_id = params.room_id

    const res: any = await request.get('/devices', { params: queryParams })
    if (res.data?.code === 200 || res.data) {
      const data = res.data?.data ?? res.data
      let deviceList: any[] = []
      if (Array.isArray(data)) {
        deviceList = data
      } else if (data?.list) {
        deviceList = data.list
      } else if (data?.devices) {
        deviceList = data.devices
      }

      const mappedDevices: DeviceInfo[] = deviceList.map((d: any) => ({
        device_id: String(d.id || d.device_id || ''),
        device_type: d.device_type || d.type || 'unknown',
        device_name: d.device_name || d.name || '未命名设备',
        room_id: d.room_id || 0,
        status: (d.device_status || d.status || 'offline') as any,
        is_running: d.device_status === 'on' || d.status === 'on',
        current_value: 0,
        unit: '',
        battery_level: d.battery_level,
        last_maintenance: d.last_maintenance
      }))

      const onlineCount = mappedDevices.filter(d => d.status === 'online').length
      const offlineCount = mappedDevices.filter(d => d.status === 'offline').length
      const errorCount = mappedDevices.filter(d => d.status === 'error').length
      const runningCount = mappedDevices.filter(d => d.is_running).length

      return {
        data: {
          devices: mappedDevices,
          total: mappedDevices.length,
          summary: {
            online_count: onlineCount,
            offline_count: offlineCount,
            error_count: errorCount,
            running_count: runningCount,
            total_devices: mappedDevices.length,
            online_rate: mappedDevices.length > 0 ? Math.round(onlineCount / mappedDevices.length * 100) : 0
          }
        }
      }
    }
    return { data: { devices: [], total: 0, summary: { online_count: 0, offline_count: 0, error_count: 0, running_count: 0, total_devices: 0, online_rate: 0 } } }
  },

  controlDevice: async (deviceId: string, data: { action: string; value?: number }) => {
    const deviceIdInt = parseInt(deviceId) || 0
    let commandType = data.action
    let commandValue = data.value?.toString() ?? ''

    switch (data.action) {
      case 'toggle':
        commandType = 'toggle'
        commandValue = data.value != null ? (data.value > 0 ? 'on' : 'off') : 'toggle'
        break
      case 'set_value':
        commandType = 'set'
        commandValue = data.value?.toString() ?? '0'
        break
      case 'turn_on':
        commandType = 'toggle'
        commandValue = 'on'
        break
      case 'turn_off':
        commandType = 'toggle'
        commandValue = 'off'
        break
    }

    return request.post(`/devices/${deviceIdInt}/command`, {
      command_type: commandType,
      command_value: commandValue
    })
  },

  getEnergyConsumption: async (params?: { room_id?: number; period?: string }) => {
    const now = new Date()
    let startDate = now.toISOString().split('T')[0]
    const endDate = startDate

    switch (params?.period || 'today') {
      case 'today':
        startDate = endDate
        break
      case 'week':
        startDate = new Date(now.getTime() - 7 * 86400000).toISOString().split('T')[0]
        break
      case 'month':
        startDate = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0]
        break
    }

    const queryParams: any = {
      start_date: startDate,
      end_date: endDate,
      group_by: 'day'
    }
    if (params?.room_id) queryParams.room_id = params.room_id

    const results = await Promise.allSettled([
      request.get('/energy/consumption', { params: queryParams }),
      request.get('/energy/stats', { params: { start_date: startDate, end_date: endDate } })
    ])

    let consumptionData: any = {}
    let statsData: any = {}

    if (results[0].status === 'fulfilled') {
      const res: any = results[0].value
      if (res.data?.code === 200 || res.data) {
        consumptionData = res.data?.data ?? res.data
      }
    }

    if (results[1].status === 'fulfilled') {
      const res: any = results[1].value
      if (res.data?.code === 200 || res.data) {
        statsData = res.data?.data ?? res.data
      }
    }

    const totalToday = Number(statsData.total || 0)
    const trend: any[] = statsData.trend || []
    const yesterdayTotal = trend.length >= 2 ? Number(trend[trend.length - 2].value || 0) : 0
    const savingsRate = yesterdayTotal > 0 ? parseFloat(((yesterdayTotal - totalToday) / yesterdayTotal * 100).toFixed(1)) : 0

    return {
      data: {
        consumption: consumptionData.data || [],
        total: consumptionData.total_consumption || 0,
        summary: {
          total_today_kwh: totalToday,
          total_yesterday_kwh: yesterdayTotal,
          total_month_kwh: totalToday,
          savings_rate: savingsRate,
          estimated_monthly_cost: parseFloat((totalToday * 0.85).toFixed(2)),
          most_efficient_room: '-',
          least_efficient_room: '-'
        }
      }
    }
  },

  getEventLogs: async (params?: { event_type?: string; severity?: string; limit?: number }) => {
    const queryParams: any = { pageSize: params?.limit || 100 }
    if (params?.severity) queryParams.alarm_level = params.severity

    const res: any = await request.get('/device-alarms', { params: queryParams })
    if (res.data?.code === 200 || res.data) {
      const data = res.data?.data ?? res.data
      const alarmList: any[] = data?.list || []

      let allLogs: EventLog[] = alarmList.map((alarm: any) => ({
        id: alarm.id,
        event_type: mapEventType(alarm.alarm_type) as any,
        room_id: alarm.room_id,
        room_number: alarm.room_number || String(alarm.room_id || '-'),
        title: getAlarmTitle(alarm.alarm_type, alarm.alarm_level),
        description: alarm.alarm_content || '设备告警',
        severity: mapSeverity(alarm.alarm_level) as any,
        created_at: alarm.created_at || '',
        resolved: alarm.status === 'resolved' || alarm.status === 'ignored',
        resolved_at: alarm.handled_at,
        handled_by: alarm.handled_by?.toString()
      }))

      if (params?.event_type) {
        allLogs = allLogs.filter(l => l.event_type === params.event_type)
      }
      if (params?.severity) {
        allLogs = allLogs.filter(l => l.severity === params.severity)
      }

      const criticalCount = allLogs.filter(l => l.severity === 'critical' && !l.resolved).length
      const unresolvedCount = allLogs.filter(l => !l.resolved).length

      return {
        data: {
          logs: allLogs,
          total: allLogs.length,
          summary: {
            critical_count: criticalCount,
            unresolved_count: unresolvedCount,
            today_total: allLogs.length
          }
        }
      }
    }
    return { data: { logs: [], total: 0, summary: { critical_count: 0, unresolved_count: 0, today_total: 0 } } }
  },

  getDashboardStats: async () => {
    const results = await Promise.allSettled([
      request.get('/devices'),
      request.get('/device-alarms/stats'),
      request.get('/energy/stats')
    ])

    let deviceData: any = {}
    let alarmStats: any = {}
    let energyStats: any = {}

    if (results[0].status === 'fulfilled') {
      const res: any = results[0].value
      if (res.data?.code === 200 || res.data) {
        deviceData = res.data?.data ?? res.data
      }
    }

    if (results[1].status === 'fulfilled') {
      const res: any = results[1].value
      if (res.data?.code === 200 || res.data) {
        alarmStats = res.data?.data ?? res.data
      }
    }

    if (results[2].status === 'fulfilled') {
      const res: any = results[2].value
      if (res.data?.code === 200 || res.data) {
        energyStats = res.data?.data ?? res.data
      }
    }

    let deviceList: any[] = []
    if (Array.isArray(deviceData)) {
      deviceList = deviceData
    } else if (deviceData?.list) {
      deviceList = deviceData.list
    }

    const onlineCount = deviceList.filter((d: any) => d.device_status === 'online' || d.status === 'online').length
    const offlineCount = deviceList.filter((d: any) => d.device_status === 'offline' || d.status === 'offline').length
    const errorCount = deviceList.filter((d: any) => d.device_status === 'error' || d.status === 'error').length
    const runningCount = deviceList.filter((d: any) => d.device_status === 'on' || d.status === 'on').length

    const smokeDetectors = deviceList.filter((d: any) =>
      d.device_type === 'smoke_detector' || d.device_type === 'sensor'
    )
    const detectorsOnline = smokeDetectors.filter((d: any) =>
      d.device_status === 'online' || d.status === 'online'
    ).length

    const sensorDevices = deviceList.filter((d: any) =>
      d.device_type === 'sensor' ||
      d.device_type === 'smoke_detector' ||
      d.device_type === 'temperature_sensor' ||
      d.device_type === 'humidity_sensor' ||
      d.device_type === 'thermostat'
    )

    let sensorDataList: any[] = []
    const sensorResults = await Promise.allSettled(
      sensorDevices.map((d: any) =>
        request.get(`/devices/${d.id}/sensor-data/latest`)
      )
    )

    let totalTemp = 0
    let tempCount = 0
    let totalHumidity = 0
    let humidityCount = 0

    sensorResults.forEach((result, index) => {
      if (result.status === 'fulfilled') {
        const res: any = result.value
        if (res.data?.code === 200 || res.data) {
          const data = res.data?.data ?? res.data
          if (Array.isArray(data)) {
            sensorDataList.push(...data)
            data.forEach((s: any) => {
              if (s.sensor_type === 'temperature' && s.sensor_value != null) {
                totalTemp += Number(s.sensor_value)
                tempCount++
              }
              if (s.sensor_type === 'humidity' && s.sensor_value != null) {
                totalHumidity += Number(s.sensor_value)
                humidityCount++
              }
            })
          }
        }
      }
    })

    const avgTemperature = tempCount > 0 ? parseFloat((totalTemp / tempCount).toFixed(1)) : null
    const avgHumidity = humidityCount > 0 ? parseFloat((totalHumidity / humidityCount).toFixed(1)) : null

    const byLevel = alarmStats.by_level || {}
    const pendingCount = alarmStats.pending_count || 0
    const totalCount = alarmStats.total_count || 0

    const totalEnergy = Number(energyStats.total || 0)
    const trend = energyStats.trend || []
    const yesterdayEnergy = trend.length >= 2 ? Number(trend[trend.length - 2].value || 0) : 0
    const savingsPercent = yesterdayEnergy > 0
      ? parseFloat(((yesterdayEnergy - totalEnergy) / yesterdayEnergy * 100).toFixed(1))
      : 0

    let environmentScore = 85
    if (errorCount > 0) environmentScore -= (errorCount * 10)
    if (pendingCount > 0) environmentScore -= (pendingCount * 5)
    if (offlineCount > 3) environmentScore -= 10
    if (avgTemperature != null && (avgTemperature > 30 || avgTemperature < 18)) environmentScore -= 10
    if (avgHumidity != null && (avgHumidity > 75 || avgHumidity < 30)) environmentScore -= 5
    environmentScore = Math.max(0, Math.min(100, environmentScore))

    const normalCount = deviceList.filter((d: any) =>
      d.device_status === 'online' || d.status === 'online' || d.device_status === 'on' || d.status === 'on'
    ).length

    let airQuality = '优'
    let comfortLevel = '舒适'
    if (avgTemperature != null) {
      if (avgTemperature > 30 || avgTemperature < 15) { airQuality = '差'; comfortLevel = '不适' }
      else if (avgTemperature > 28 || avgTemperature < 18) { airQuality = '良'; comfortLevel = '一般' }
    }
    if (avgHumidity != null) {
      if (avgHumidity > 80 || avgHumidity < 20) { airQuality = '差'; comfortLevel = '不适' }
      else if (avgHumidity > 70 || avgHumidity < 30) { if (airQuality === '优') airQuality = '良'; if (comfortLevel === '舒适') comfortLevel = '一般' }
    }

    return {
      data: {
        environment: {
          avg_temperature: avgTemperature,
          avg_humidity: avgHumidity,
          air_quality: airQuality,
          comfort_level: comfortLevel,
          avg_environment_score: environmentScore,
          normal_count: normalCount,
          total_rooms: deviceList.length
        },
        fire_safety: {
          active_alarms: pendingCount,
          today_alarms: totalCount,
          detectors_online: detectorsOnline,
          detectors_total: smokeDetectors.length,
          system_status: pendingCount > 0 ? 'alert' : 'normal'
        },
        devices: {
          total: deviceList.length,
          online: onlineCount,
          offline: offlineCount,
          error: errorCount,
          running: runningCount,
          maintenance_due: 0
        },
        energy: {
          today_total: totalEnergy,
          yesterday_total: yesterdayEnergy,
          savings_percent: savingsPercent,
          monthly_estimate: totalEnergy * 30,
          monthly_cost: parseFloat((totalEnergy * 30 * 0.85).toFixed(2)),
          peak_hour: '19:00-20:00'
        },
        alerts: {
          critical: byLevel.critical || byLevel.emergency || 0,
          warning: byLevel.warning || byLevel.medium || 0,
          info: byLevel.info || byLevel.low || 0,
          unresolved: pendingCount
        },
        environment_score: environmentScore
      }
    }
  }
}
