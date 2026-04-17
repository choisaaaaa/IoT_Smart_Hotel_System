import { io, Socket } from 'socket.io-client'
import { useDeviceStore } from '@/stores/device'
import { useAppStore } from '@/stores/app'

let socket: Socket | null = null

function doAutoRegister(s: Socket) {
  const appStore = useAppStore()
  const userInfo = appStore.userInfo
  if (userInfo && userInfo.username) {
    const isStaff = ['admin', 'staff', 'manager', 'reception', 'hotel_admin', 'system_admin'].includes(userInfo.role)
    const clientType = isStaff ? 'front_desk' : 'app'
    const clientId = userInfo.username

    console.log(`[WS] 自动注册客户端: ${clientId} as ${clientType}`)
    s.emit('register_client', { clientType, clientId })
    s.once('registered', (data: any) => {
      console.log('[WS] 自动注册成功:', data)
      appStore.setRegistration(true, data.clientName)
    })
  }
}

export function initWebSocket(roomId?: string): Socket {
  if (socket?.connected) {
    doAutoRegister(socket)
    return socket
  }

  if (socket && !socket.connected) {
    socket.connect()
    doAutoRegister(socket)
    return socket
  }

  const socketUrl = window.location.origin

  socket = io(socketUrl, {
    transports: ['websocket', 'polling'],
    reconnection: true,
    reconnectionAttempts: Infinity,
    reconnectionDelay: 1000,
    reconnectionDelayMax: 5000,
    timeout: 10000
  })

  const deviceStore = useDeviceStore()
  const appStore = useAppStore()

  socket.on('connect', () => {
    console.log('[WS] 已连接到服务器')
    appStore.setConnected(true)

    if (roomId && socket) {
      socket.emit('join_room', roomId)
    }

    doAutoRegister(socket!)
  })

  socket.on('disconnect', (reason: string) => {
    console.log('[WS] 与服务器断开连接:', reason)
    appStore.setConnected(false)
  })

  socket.on('reconnect', (attemptNumber: number) => {
    console.log('[WS] 重连成功，第', attemptNumber, '次尝试')
  })

  socket.on('reconnect_attempt', (attemptNumber: number) => {
    console.log('[WS] 尝试重连... 第', attemptNumber, '次')
  })

  socket.on('reconnect_error', (error: any) => {
    console.error('[WS] 重连失败:', error)
  })

  socket.on('reconnect_failed', () => {
    console.error('[WS] 重连最终失败')
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
