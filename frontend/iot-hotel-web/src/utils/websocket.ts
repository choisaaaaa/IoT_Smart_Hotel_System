import { io, Socket } from 'socket.io-client'
import { useDeviceStore } from '@/stores/device'
import { useAppStore } from '@/stores/app'

let socket: Socket | null = null

export function initWebSocket(roomId?: string): Socket {
  if (socket?.connected) {
    return socket
  }

  // 使用相对路径以便通过 Vite/Nginx 代理，或显式指定后端端口
  const isDev = import.meta.env.DEV
  const socketUrl = isDev ? 'http://localhost:9000' : window.location.origin

  socket = io(socketUrl, {
    transports: ['websocket', 'polling'], // 允许回退到 polling 以提高兼容性
    reconnection: true,
    reconnectionAttempts: 10,
    reconnectionDelay: 1000,
    timeout: 10000, // 增加超时时间到 10s
    autoConnect: true
  })

  const deviceStore = useDeviceStore()
  const appStore = useAppStore()

  socket.on('connect', () => {
    console.log('[WS] 已连接到服务器')
    appStore.setConnected(true)

    if (roomId && socket) {
      socket.emit('join_room', roomId)
    }
  })

  socket.on('disconnect', () => {
    console.log('[WS] 与服务器断开连接')
    appStore.setConnected(false)
  })

  socket.on('device_status_changed', (data: any) => {
    console.log('[WS] 设备状态变更:', data)
    deviceStore.updateDevice(data.device_id, data)
    appStore.addNotification('info', `设备 ${data.device_id} 状态变更为 ${data.status}`)
  })

  socket.on('sensor_data_update', (data: any) => {
    console.log('[WS] 传感器数据更新:', data)
    deviceStore.addSensorData(data)
  })

  socket.on('command_result', (data: any) => {
    console.log('[WS] 指令执行结果:', data)
    deviceStore.addCommandResult(data)
    appStore.addNotification(
      data.result === 'success' ? 'success' : 'warning',
      `指令 ${data.command_id} 执行${data.result === 'success' ? '成功' : '失败'}`
    )
  })

  socket.on('security_event', (data: any) => {
    console.log('[WS] 安防事件:', data)
    appStore.addNotification('error', `安防事件: ${data.event_type || '未知'} - ${data.description}`)
  })

  socket.on('room_status_update', (data: any) => {
    console.log('[WS] 房间状态更新:', data)
  })

  socket.on('error', (err: any) => {
    console.error('[WS] 错误:', err)
  })

  return socket
}

export function joinRoom(roomId: string) {
  if (socket?.connected) {
    socket.emit('join_room', roomId)
  }
}

export function leaveRoom(roomId: string) {
  if (socket?.connected) {
    socket.emit('leave_room', roomId)
  }
}

export function sendDeviceCommand(deviceId: string, commandType: string, commandValue: string) {
  if (socket?.connected) {
    socket.emit('control_device', { deviceId, commandType, commandValue })
  }
}

export function disconnectWebSocket() {
  if (socket) {
    socket.disconnect()
    socket = null
  }
}

export function getSocket(): Socket | null {
  return socket
}