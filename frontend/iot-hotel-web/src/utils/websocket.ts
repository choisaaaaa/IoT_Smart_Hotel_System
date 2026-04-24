import { io, Socket } from 'socket.io-client'
import { useDeviceStore } from '@/stores/device'
import { useAppStore } from '@/stores/app'
import { useNotificationStore } from '@/stores/notification'

let socket: Socket | null = null
let lastRoomId: string | null = null

function doAutoRegister(s: Socket) {
  const appStore = useAppStore()
  const userInfo = appStore.userInfo
  if (userInfo && userInfo.username) {
    const isStaffUser = ['hotel_admin', 'system_admin', 'staff'].includes(userInfo.role)
    const clientType = isStaffUser ? 'front_desk' : 'app'
    const clientId = userInfo.username
    const hotelId = userInfo.hotel_id

    console.log(`[WS] 自动注册客户端: ${clientId} as ${clientType}`)
    s.emit('register_client', { clientType, clientId, hotelId })
    s.once('registered', (data: any) => {
      console.log('[WS] 自动注册成功:', data)
      appStore.setRegistration(true, data.clientName)
      
      // 注册成功后，加入酒店前台房间以接收报警消息
      if (isStaffUser && hotelId) {
        const hotelRoom = `front_desk_hotel_${hotelId}`
        s.emit('join_room', hotelRoom)
        console.log(`[WS] 已加入酒店房间: ${hotelRoom}`)
      }
    })
  }
}

export function initWebSocket(roomId?: string): Socket {
  if (roomId) {
    lastRoomId = roomId
  }

  if (socket?.connected) {
    doAutoRegister(socket)
    if (lastRoomId) {
      socket.emit('join_room', lastRoomId)
    }
    return socket
  }

  if (socket && !socket.connected) {
    socket.connect()
    return socket
  }

  // 使用相对路径，让 Vite 代理处理 WebSocket 连接
  // 开发环境通过代理连接，生产环境使用当前域名
  const socketUrl = import.meta.env.DEV ? '' : window.location.origin

  socket = io(socketUrl, {
    transports: ['websocket', 'polling'],
    reconnection: true,
    reconnectionAttempts: Infinity,
    reconnectionDelay: 1000,
    reconnectionDelayMax: 5000,
    timeout: 20000
  })

  const deviceStore = useDeviceStore()
  const appStore = useAppStore()
  const notificationStore = useNotificationStore()

  socket.on('connect', () => {
    console.log('[WS] 已连接到服务器, transport:', socket?.io?.engine?.transport?.name)
    appStore.setConnected(true)

    if (lastRoomId && socket) {
      socket.emit('join_room', lastRoomId)
    }

    doAutoRegister(socket!)
    // 连接成功后刷新一次未读数
    notificationStore.fetchAllUnreadCounts()
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
    
    // 处理消警事件 - 关闭报警弹窗和声音
    if (data.event_type === 'fire_alarm_cleared' || data.event_type === 'alarm_reset') {
      console.log('[WS] 收到消警事件:', data)
      
      // 触发消警事件，让 AlarmAlertModal 组件处理
      window.dispatchEvent(new CustomEvent('fire-alarm-cleared', {
        detail: {
          deviceId: data.device_id,
          message: data.data?.message || '火警已解除',
          timestamp: data.timestamp || new Date().toISOString()
        }
      }))
      
      // 显示消警通知
      appStore.addNotification('success', `🔔 ${data.data?.message || '火警已解除'} - 设备: ${data.device_id}`)
      
      // 刷新报警列表
      notificationStore.fetchAlarmNotifications()
      return
    }
    
    // 处理消防报警和SOS报警，触发弹窗
    if (data.event_type === 'fire_alarm' || data.event_type === 'sos_alarm' ||
        data.event_type === 'fire_alarm_linked' || data.event_type === 'global_alarm' ||
        data.event_type === 'floor_fire_suspected' || data.event_type === 'floor_alarm_pressed' ||
        data.event_type === 'room_sos_pressed' || data.event_type === 'front_alarm_triggered') {
      
      // 提取位置信息 - 支持多种字段名
      const eventData = data.data || {}
      let location = '未知位置'
      if (eventData.floor_id) {
        location = `第${eventData.floor_id}层`
      } else if (eventData.room_number) {
        location = `${eventData.room_number}房间`
      } else if (eventData.location) {
        location = eventData.location
      } else if (eventData.room_id) {
        location = `${eventData.room_id}房间`
      }
      
      // 根据设备ID判断设备类型并显示正确位置
      const deviceId = data.device_id || ''
      if ((deviceId.includes('FLO') || deviceId.startsWith('floor_')) && eventData.floor_id) {
        location = `第${eventData.floor_id}层(楼控)`
      } else if (deviceId.startsWith('floor_')) {
        location = `楼控 ${deviceId}`
      } else if (deviceId.includes('FRO') || deviceId.includes('front_desk')) {
        location = eventData.room_id ? `前台(代客${eventData.room_id})` : '前台'
      } else if (deviceId.includes('ROO') && eventData.room_number) {
        location = `${eventData.room_number}房间`
      }
      
      // 触发报警弹窗
      appStore.showAlarmModal({
        id: data.data?.alarm_id || data.alarm_id || data.device_id || Date.now().toString(),
        type: data.event_type,
        level: data.level || 'critical',
        deviceId: data.device_id,
        deviceName: data.device_name,
        location: location,
        message: eventData.message || data.description || '紧急报警',
        timestamp: data.timestamp || new Date().toISOString(),
        floorId: eventData.floor_id,
        roomId: eventData.room_id || eventData.room_number
      })
      
      // 添加到通知中心
      notificationStore.addAlarm({
        id: data.data?.alarm_id || data.alarm_id || data.device_id || Date.now().toString(),
        type: data.event_type as any,
        level: data.level || 'critical',
        title: `${location} - 报警`,
        desc: eventData.message || data.description || '紧急报警',
        time: '刚刚',
        read: false,
        deviceId: data.device_id,
        location: location
      })
      
      // 播放报警提示音
      try {
        const audio = new Audio('/alarm-notification.mp3')
        audio.play().catch(() => {})
      } catch (e) {}
    } else {
      // 其他安防事件只显示通知
      appStore.addNotification('error', `安防事件: ${data.event_type || '未知'} - ${data.description}`)
    }
    
    // 收到任何相关事件都刷新一次未读数
    notificationStore.fetchAllUnreadCounts()
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
