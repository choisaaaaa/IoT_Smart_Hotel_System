<template>
  <div class="voice-calls-container">
    <!-- 统计卡片 -->
    <a-row :gutter="[16, 16]" class="stat-row">
      <a-col :xs="24" :sm="6">
        <a-card size="small" class="stat-card">
          <a-statistic title="活跃通话" :value="activeCalls.length" :value-style="{ color: '#1890ff' }" />
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="6">
        <a-card size="small" class="stat-card">
          <a-statistic title="在线终端" :value="onlineCount" :value-style="{ color: '#52c41a' }" />
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="6">
        <a-card size="small" class="stat-card">
          <a-statistic title="接通率" :value="Number((stats.answer_rate || 0) * 100)" suffix="%" :precision="0" :value-style="{ color: '#faad14' }" />
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="6">
        <a-card size="small" class="stat-card">
          <div class="registration-status">
            <div class="reg-info">
              <span class="label">当前身份:</span>
              <span class="value">{{ appStore.isRegistered ? appStore.clientDisplayName : '未上线' }}</span>
            </div>
            <a-button :type="appStore.isRegistered ? 'default' : 'primary'" size="small" @click="toggleRegister">
              {{ appStore.isRegistered ? '注销' : '上线' }}
            </a-button>
          </div>
        </a-card>
      </a-col>
    </a-row>

    <!-- 当前通话 -->
    <div v-if="appStore.currentCall" class="current-call-section">
      <a-card size="small" class="current-call-card" :class="appStore.currentCall.status">
        <div class="current-call-header">
          <PhoneOutlined class="call-icon" />
          <span class="call-title">当前通话</span>
          <a-tag :color="appStore.currentCall.status === 'connected' ? 'success' : 'processing'">
            {{ appStore.currentCall.status === 'connected' ? '通话中' : '连接中...' }}
          </a-tag>
        </div>
        <div class="current-call-info">
          <div class="caller-name">{{ appStore.currentCall.caller_name || appStore.currentCall.caller_id }}</div>
          <div class="call-duration" v-if="appStore.currentCall.status === 'connected'">
            通话时长: {{ currentCallDuration }}
          </div>
        </div>
        <div class="current-call-actions">
          <a-button danger size="small" @click="hangupCurrentCall">
            <CloseOutlined /> 挂断
          </a-button>
        </div>
      </a-card>
    </div>

    <!-- 呼叫网格 -->
    <a-tabs v-model:activeKey="activeTab" class="call-tabs">
      <a-tab-pane key="all" title="全部">
        <template #tab><span><AppstoreOutlined /> 全部</span></template>
        <div class="grid-scroll">
          <div class="call-grid">
            <div
              v-for="target in callableTargets"
              :key="target.id + target.type"
              class="call-card"
              :class="[target.type, target.status]"
              @click="handleCardClick(target)"
            >
              <div class="card-status-dot" :class="{ online: target.isOnline }"></div>
              <div class="card-icon">
                <HomeOutlined v-if="target.type === 'room'" />
                <UserOutlined v-else />
              </div>
              <div class="card-name">{{ target.name }}</div>
              <div class="card-desc">{{ target.desc }}</div>
              <div class="card-action-hint">点击呼叫</div>
            </div>
          </div>
        </div>
      </a-tab-pane>
      <a-tab-pane key="room" title="客房">
        <template #tab><span><HomeOutlined /> 客房硬件</span></template>
        <div class="call-grid">
          <div
            v-for="target in callableTargets.filter(t => t.type === 'room')"
            :key="target.id"
            class="call-card room"
            @click="handleCardClick(target)"
          >
            <div class="card-name">{{ target.name }}</div>
            <div class="card-desc">{{ target.desc }}</div>
          </div>
        </div>
      </a-tab-pane>
      <a-tab-pane key="staff" title="前台/员工">
        <template #tab><span><TeamOutlined /> 前台/员工</span></template>
        <div class="call-grid">
          <div
            v-for="target in callableTargets.filter(t => t.type === 'front_desk' || t.type === 'app')"
            :key="target.id"
            class="call-card staff"
            @click="handleCardClick(target)"
          >
            <div class="card-name">{{ target.name }}</div>
            <div class="card-desc">{{ target.roleName }}</div>
          </div>
        </div>
      </a-tab-pane>
      <a-tab-pane key="history" title="通话记录">
        <template #tab><span><HistoryOutlined /> 通话记录</span></template>
        <a-table :columns="historyColumns" :data-source="history" :pagination="{ pageSize: 10 }" row-key="call_id" size="small" />
      </a-tab-pane>
    </a-tabs>

    <!-- 正在呼叫弹窗 -->
    <a-modal
      :open="outgoingCallModal.visible"
      :footer="null"
      :closable="false"
      :maskClosable="false"
      centered
      width="320px"
    >
      <div class="outgoing-call-content">
        <a-avatar :size="64" icon="user" />
        <h2 style="margin-top: 16px">{{ outgoingCallModal.targetName }}</h2>
        <p>正在呼叫中...</p>
        <a-button danger shape="circle" size="large" @click="handleOutgoingCancel">
          <template #icon><CloseOutlined /></template>
        </a-button>
      </div>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { onMounted, onUnmounted, reactive, ref, computed } from 'vue'
import { message, Modal } from 'ant-design-vue'
import {
  PhoneOutlined, CloseOutlined, HomeOutlined, UserOutlined,
  TeamOutlined, HistoryOutlined, AppstoreOutlined
} from '@ant-design/icons-vue'
import { callApi } from '@/api/call'
import request from '@/api/request'
import { getSocket, initWebSocket } from '@/utils/websocket'
import { useAppStore } from '@/stores/app'
import { useHotelStore } from '@/stores/hotel'
import { CANONICAL_ROLES } from '@/api/auth'

const appStore = useAppStore()
const hotelStore = useHotelStore()
const calling = ref(false)
const activeCalls = ref<any[]>([])
const history = ref<any[]>([])
const stats = reactive({
  answer_rate: 0,
  avg_duration_sec: 0
})
const users = ref<any[]>([])
const activeTab = ref('all')
const onlineStatus = ref<{ web: any[], rooms: any[] }>({ web: [], rooms: [] })
const fetchCallsTimer = ref<NodeJS.Timeout | null>(null)

const isRegistered = computed(() => appStore.isRegistered)
const clientDisplayName = computed(() => appStore.clientDisplayName)

const outgoingCallModal = reactive({
  visible: false,
  targetId: '',
  targetName: '',
  callId: '',
  status: 'calling' as 'calling' | 'connected'
})

// 当前通话时长
const currentCallDuration = ref('00:00')
const callDurationTimer = ref<NodeJS.Timeout | null>(null)
const callStartTime = ref<number | null>(null)

// 组合可呼叫目标
const callableTargets = computed(() => {
  const list: any[] = []

  // 1. 添加房间
  hotelStore.rooms.forEach(room => {
    // 隔离：只能看到本店房间
    if (appStore.userInfo?.role !== 'system' && room.hotel_id !== appStore.userInfo?.hotel_id) {
      return
    }
    // 改用数据库ID判断在线状态，避免多门店同房间号冲突
    const isOnline = onlineStatus.value.rooms.some((r: any) => String(r.id) === String(room.id))
    list.push({
      id: room.id,
      clientId: String(room.id), // 使用唯一ID呼叫
      name: `房间 ${room.room_number}`,
      desc: room.room_name,
      type: 'room',
      status: room.room_status,
      isOnline
    })
  })

  // 2. 添加员工 (过滤掉自己并过滤掉 user 角色)
  console.log('[VoiceCalls] 当前用户:', appStore.userInfo?.username)
  console.log('[VoiceCalls] 用户列表:', users.value)
  users.value.forEach(user => {
    console.log('[VoiceCalls] 检查用户:', user.username, '角色:', user.role)
    // 隔离：只能看到本店员工 (除非是系统管理员)，且不能看到角色为 user 的用户
    const isSameHotel = appStore.userInfo?.role === CANONICAL_ROLES.SYSTEM_ADMIN || user.hotel_id === appStore.userInfo?.hotel_id
    const isNotSelf = user.username !== appStore.userInfo?.username
    const isNotUserRole = user.role !== CANONICAL_ROLES.CUSTOMER

    if (isNotSelf && isSameHotel && isNotUserRole) {
      const isOnline = onlineStatus.value.web.some((w: any) => w.id === user.username)
      list.push({
        id: user.id,
        clientId: user.username,
        name: user.username,
        desc: user.role === CANONICAL_ROLES.HOTEL_ADMIN ? '管理员' : '前台',
        type: 'front_desk',
        status: 'available',
        isOnline
      })
    }
  })

  console.log('[VoiceCalls] 可呼叫目标:', list.length, '个')
  return list.sort((a, b) => a.name.localeCompare(b.name))
})

const onlineCount = computed(() => callableTargets.value.filter(t => t.isOnline).length)

async function fetchCalls() {
  try {
    const [activeRes, historyRes] = await Promise.all([
      callApi.getActive(),
      callApi.getHistory({ page: 1, limit: 50 })
    ])
    activeCalls.value = (activeRes as any).data?.items || []
    history.value = (historyRes as any).data?.items || []
  } catch (error) {
    console.error('获取通话记录失败:', error)
  }
}

async function fetchUsers() {
  try {
    const res: any = await request.get('/users?limit=100')
    // API 返回结构: { code: 200, data: { users: [], total, page, limit } }
    users.value = res.data?.users || []
    console.log('[VoiceCalls] 获取到用户列表:', users.value.length, '个用户', res)
  } catch (error) {
    console.error('获取用户列表失败:', error)
  }
}

async function fetchStats() {
  try {
    const res: any = await callApi.getStats()
    const data = res.data
    stats.answer_rate = data.answer_rate || 0
    stats.avg_duration_sec = data.avg_duration_sec || 0
  } catch (error) {
    console.error('获取统计失败:', error)
  }
}

function handleCardClick(target: any) {
  if (!appStore.isRegistered) {
    Modal.confirm({
      title: '提示',
      content: '您尚未上线，无法发起呼叫。是否现在上线？',
      onOk: toggleRegister
    })
    return
  }

  outgoingCallModal.targetId = target.clientId
  outgoingCallModal.targetName = target.name
  startCall(target)
}

async function startCall(target: any) {
  calling.value = true
  console.log('[VoiceCalls] 发起呼叫:', {
    caller_id: appStore.userInfo?.username || 'FD-01',
    callee_type: target.type,
    callee_id: target.clientId
  })
  try {
    const res = await callApi.outbound({
      caller_id: appStore.userInfo?.username || 'FD-01',
      callee_type: target.type,
      callee_id: target.clientId,
      caller_type: 'front_desk'
    })

    const callData = (res as any).data
    outgoingCallModal.callId = callData.call_id
    outgoingCallModal.visible = true

    // 设置全局当前通话，让悬浮窗显示
    appStore.setCurrentCall({
      call_id: callData.call_id,
      caller_id: appStore.userInfo?.username || 'FD-01',
      caller_type: 'front_desk',
      callee_id: target.clientId,
      callee_type: target.type,
      caller_name: target.name,
      status: 'calling'
    })

    console.log('[VoiceCalls] 等待对方接听，全局通话已设置')

    await fetchCalls()
  } catch (error) {
    message.error('发起呼叫失败')
  } finally {
    calling.value = false
  }
}

function handleOutgoingCancel() {
  if (outgoingCallModal.callId) {
    callApi.hangup(outgoingCallModal.callId)
  }
  outgoingCallModal.visible = false
  // 清除全局通话状态
  appStore.clearCurrentCall()
}

// 挂断当前通话
function hangupCurrentCall() {
  if (appStore.currentCall?.call_id) {
    callApi.hangup(appStore.currentCall.call_id)
    // 发送挂断事件
    const socket = getSocket()
    if (socket) {
      socket.emit('hangup_call', { call_id: appStore.currentCall.call_id })
    }
  }
  appStore.clearCurrentCall()
  stopCallDurationTimer()
}

// 启动通话时长计时
function startCallDurationTimer() {
  callStartTime.value = Date.now()
  callDurationTimer.value = setInterval(() => {
    if (callStartTime.value) {
      const elapsed = Math.floor((Date.now() - callStartTime.value) / 1000)
      const minutes = Math.floor(elapsed / 60).toString().padStart(2, '0')
      const seconds = (elapsed % 60).toString().padStart(2, '0')
      currentCallDuration.value = `${minutes}:${seconds}`
    }
  }, 1000)
}

// 停止通话时长计时
function stopCallDurationTimer() {
  if (callDurationTimer.value) {
    clearInterval(callDurationTimer.value)
    callDurationTimer.value = null
  }
  callStartTime.value = null
  currentCallDuration.value = '00:00'
}

async function toggleRegister() {
  const socket = getSocket()
  if (!socket || !socket.connected) {
    message.error('WebSocket 连接中...')
    return
  }

  if (appStore.isRegistered) {
    // 注销
    appStore.setRegistration(false, '')
    message.info('已下线')
  } else {
    // 上线
    const id = appStore.userInfo?.username || 'FD-01'
    socket.emit('register_client', { clientType: 'front_desk', clientId: id })
    socket.once('registered', (data: any) => {
      appStore.setRegistration(true, data.clientName)
      message.success(`欢迎，${data.clientName}`)
      socket.emit('get_online_status')
    })
  }
}

// 使用命名函数以便正确移除监听器
const handleOnlineStatus = (data: any) => {
  onlineStatus.value = data
}

const handleCallAnswered = (data: any) => {
  console.log('[VoiceCalls] 收到call_answered:', data)

  // 处理外呼通话
  if (data.call_id === outgoingCallModal.callId) {
    outgoingCallModal.visible = false
    message.success('对方已接听')
  }

  // 更新全局通话状态为已连接（包括来电）
  if (appStore.currentCall?.call_id === data.call_id) {
    appStore.setCurrentCall({
      ...appStore.currentCall,
      status: 'connected'
    })
    // 启动通话时长计时
    startCallDurationTimer()
    message.success('通话已连接')
  }

  fetchCalls()
}

const handleCallRejected = (data: any) => {
  if (data.call_id === outgoingCallModal.callId) {
    outgoingCallModal.visible = false
    message.warning('通话被拒接')
    // 清除全局通话状态
    appStore.clearCurrentCall()
    fetchCalls()
  }
}

const handleCallHungup = (data: any) => {
  if (data.call_id === outgoingCallModal.callId) {
    outgoingCallModal.visible = false
    message.info('通话已挂断')
    // 清除全局通话状态
    appStore.clearCurrentCall()
    stopCallDurationTimer()
    fetchCalls()
  }
}

// 处理来电（包括AI转接）
const handleIncomingCall = (data: any) => {
  console.log('[VoiceCalls] 收到来电:', data)

  // 设置来电信息
  appStore.setIncomingCall({
    call_id: data.call_id,
    caller_id: data.caller_id,
    caller_type: data.caller_type,
    caller_name: data.caller_name || data.caller_id,
    callee_id: data.callee_id,
    callee_type: data.callee_type,
    isTransfer: data.isTransfer,
    transferReason: data.transferReason
  })

  // 显示来电提醒
  if (data.isTransfer) {
    message.info(`AI管家转接: ${data.transferReason || '客人要求转人工'}`)
  }
}

function setupSignalingListeners() {
  const socket = getSocket()
  if (!socket) return

  // 先移除旧的监听器，避免重复
  socket.off('online_status', handleOnlineStatus)
  socket.off('call_answered', handleCallAnswered)
  socket.off('call_rejected', handleCallRejected)
  socket.off('call_hungup', handleCallHungup)
  socket.off('incoming_call', handleIncomingCall)

  // 添加新的监听器
  socket.on('online_status', handleOnlineStatus)
  socket.on('call_answered', handleCallAnswered)
  socket.on('call_rejected', handleCallRejected)
  socket.on('call_hungup', handleCallHungup)
  socket.on('incoming_call', handleIncomingCall)
}

onMounted(async () => {
  await Promise.all([fetchCalls(), fetchUsers(), hotelStore.fetchRooms({ pageSize: 300 }), fetchStats()])

  const socket = initWebSocket()
  if (socket) {
    setupSignalingListeners()

    socket.on('connect', () => {
      socket.emit('get_online_status')
    })

    if (socket.connected) {
      socket.emit('get_online_status')
    }
  }

  // 定时刷新
  fetchCallsTimer.value = setInterval(fetchCalls, 10000)
})

onUnmounted(() => {
  const socket = getSocket()
  if (socket) {
    // 只移除当前组件添加的特定监听器
    socket.off('online_status', handleOnlineStatus)
    socket.off('call_answered', handleCallAnswered)
    socket.off('call_rejected', handleCallRejected)
    socket.off('call_hungup', handleCallHungup)
  }
  if (fetchCallsTimer.value) {
    clearInterval(fetchCallsTimer.value)
  }
})

const historyColumns = [
  { title: '主叫', dataIndex: 'caller_id', width: 120 },
  { title: '被叫', dataIndex: 'callee_id', width: 120 },
  { title: '状态', dataIndex: 'status', key: 'status', width: 100 },
  { title: '时长', dataIndex: 'duration_sec', key: 'duration', width: 100 },
  { title: '时间', dataIndex: 'started_at', width: 180 }
]
</script>

<style scoped>
.voice-calls-container { padding: 0; }
.stat-row { margin-bottom: 16px; }
.stat-card { border-radius: 8px; }
.registration-status { display: flex; flex-direction: column; gap: 8px; }
.reg-info { font-size: 12px; }
.reg-info .value { font-weight: bold; margin-left: 4px; color: #1890ff; }

/* 当前通话区域 */
.current-call-section {
  margin-bottom: 16px;
}
.current-call-card {
  border: 2px solid #1890ff;
  border-radius: 8px;
}
.current-call-card.connected {
  border-color: #52c41a;
}
.current-call-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}
.current-call-header .call-icon {
  color: #1890ff;
  font-size: 18px;
}
.current-call-card.connected .call-icon {
  color: #52c41a;
}
.current-call-header .call-title {
  font-weight: 500;
  flex: 1;
}
.current-call-info {
  margin-bottom: 12px;
}
.current-call-info .caller-name {
  font-size: 16px;
  font-weight: 600;
  color: #333;
}
.current-call-info .call-duration {
  font-size: 14px;
  color: #666;
  margin-top: 4px;
}
.current-call-actions {
  display: flex;
  justify-content: flex-end;
}

.call-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  gap: 16px;
  padding: 16px 0;
}

.call-card {
  background: #fff;
  border: 1px solid #f0f0f0;
  border-radius: 12px;
  padding: 20px;
  cursor: pointer;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  position: relative;
  text-align: center;
  box-shadow: 0 2px 8px rgba(0,0,0,0.04);
}

.call-card.room.vacant { border-left: 4px solid #52c41a; }
.call-card.room.occupied { border-left: 4px solid #ff4d4f; }
.call-card.room.cleaning { border-left: 4px solid #1890ff; }
.call-card.room.maintenance { border-left: 4px solid #faad14; }
.call-card.staff { border-left: 4px solid #722ed1; }

.call-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 24px rgba(0,0,0,0.12);
}

.card-status-dot {
  position: absolute;
  top: 12px;
  right: 12px;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #d9d9d9;
}
.card-status-dot.online {
  background: #52c41a;
  box-shadow: 0 0 8px rgba(82, 196, 26, 0.6);
}

.card-icon {
  font-size: 32px;
  color: #8c8c8c;
  margin-bottom: 12px;
}

.call-card.room .card-icon { color: #1890ff; }
.call-card.front_desk .card-icon { color: #722ed1; }

.card-name { font-size: 18px; font-weight: bold; color: #262626; margin-bottom: 4px; }
.card-desc { font-size: 12px; color: #8c8c8c; }

.card-action-hint {
  margin-top: 12px;
  font-size: 12px;
  color: #1890ff;
  opacity: 0;
  transition: opacity 0.3s;
}
.call-card:hover .card-action-hint { opacity: 1; }

.outgoing-call-content { text-align: center; padding: 32px 0; }

.grid-scroll { max-height: calc(100vh - 300px); overflow-y: auto; padding-right: 8px; }
</style>
