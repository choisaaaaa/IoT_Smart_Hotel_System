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
              <span class="value">{{ isRegistered ? clientDisplayName : '未上线' }}</span>
            </div>
            <a-button :type="isRegistered ? 'default' : 'primary'" size="small" @click="toggleRegister">
              {{ isRegistered ? '注销' : '上线' }}
            </a-button>
          </div>
        </a-card>
      </a-col>
    </a-row>

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

    <!-- 来电提醒弹窗 (全局级最高优先级) -->
    <a-modal
      v-model:visible="incomingCallModal.visible"
      :footer="null"
      :closable="false"
      :maskClosable="false"
      centered
      wrap-class-name="incoming-call-modal-wrap"
      width="320px"
    >
      <div class="incoming-call-content">
        <!-- 响铃中状态 -->
        <template v-if="incomingCallModal.status === 'ringing'">
          <div class="pulse-container">
            <div class="pulse-ring"></div>
            <PhoneOutlined class="call-icon" />
          </div>
          <h2 class="caller-name">{{ incomingCallModal.callerName }}</h2>
          <p class="caller-id">{{ incomingCallModal.callerId }} 正在呼叫...</p>
          
          <div class="modal-actions">
            <a-button type="primary" shape="round" size="large" block @click="handleIncomingAccept" class="accept-btn">
              <template #icon><PhoneOutlined /></template> 接听
            </a-button>
            <a-button danger shape="round" size="large" block @click="handleIncomingReject" class="reject-btn" style="margin-top: 12px">
              <template #icon><CloseOutlined /></template> 挂断
            </a-button>
          </div>
        </template>
        
        <!-- 通话中状态 -->
        <template v-else-if="incomingCallModal.status === 'connected'">
          <div class="pulse-container">
            <PhoneOutlined class="call-icon" style="color: #52c41a;" />
          </div>
          <h2 class="caller-name">{{ incomingCallModal.callerName }}</h2>
          <p class="caller-id">通话中...</p>
          <p class="call-duration">{{ currentDuration }}</p>
          
          <div class="modal-actions">
            <a-button danger shape="round" size="large" block @click="handleIncomingReject" class="reject-btn">
              <template #icon><CloseOutlined /></template> 挂断
            </a-button>
          </div>
        </template>
      </div>
    </a-modal>

    <!-- 正在呼叫弹窗 -->
    <a-modal
      v-model:visible="outgoingCallModal.visible"
      :footer="null"
      centered
      width="320px"
      @cancel="handleOutgoingCancel"
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
import { onMounted, onUnmounted, reactive, ref, computed, watch } from 'vue'
import { message, Modal } from 'ant-design-vue'
import {
  PhoneOutlined, CloseOutlined, HomeOutlined, UserOutlined,
  TeamOutlined, HistoryOutlined, AppstoreOutlined
} from '@ant-design/icons-vue'
import { callApi } from '@/api/call'
import { getSocket, initWebSocket } from '@/utils/websocket'
import { useAppStore } from '@/stores/app'
import { useHotelStore } from '@/stores/hotel'
import request from '@/api/request'

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
const durationTimer = ref<NodeJS.Timeout | null>(null)
const currentDuration = ref('00:00')
const activeTab = ref('all')
const onlineStatus = ref<{ web: any[], rooms: any[] }>({ web: [], rooms: [] })

const isRegistered = ref(false)
const clientDisplayName = ref('')
const socketConnected = ref(false)

const incomingCallModal = reactive({
  visible: false,
  callId: '',
  callerId: '',
  callerName: '',
  callerType: '',
  status: 'ringing' as 'ringing' | 'connected' | 'ended',
  startTime: null as number | null
})

// 监听全局通话状态变化
watch(() => appStore.currentCall, (newCall: any) => {
  if (newCall && !peerConnection.value) {
    console.log('[Page] 处理当前通话:', newCall)
    answer(newCall.call_id)
  }
}, { immediate: true })

const outgoingCallModal = reactive({
  visible: false,
  targetId: '',
  targetName: '',
  callId: ''
})

// 组合可呼叫目标
const callableTargets = computed(() => {
  const list: any[] = []
  
  // 1. 添加房间
  hotelStore.rooms.forEach(room => {
    const isOnline = onlineStatus.value.rooms.some((r: any) => r.id === String(room.room_number))
    list.push({
      id: room.id,
      clientId: String(room.room_number),
      name: `房间 ${room.room_number}`,
      desc: room.room_name,
      type: 'room',
      status: room.room_status,
      isOnline
    })
  })
  
  // 2. 添加员工 (过滤掉自己)
  users.value.forEach(user => {
    if (user.username !== appStore.userInfo?.username) {
      const isOnline = onlineStatus.value.web.some((w: any) => w.id === user.username)
      list.push({
        id: user.id,
        clientId: user.username,
        name: user.username,
        desc: user.role === 'admin' ? '管理员' : '前台',
        type: 'front_desk',
        status: 'available',
        isOnline
      })
    }
  })
  
  return list.sort((a, b) => a.name.localeCompare(b.name))
})

const onlineCount = computed(() => callableTargets.value.filter(t => t.isOnline).length)

async function fetchUsers() {
  try {
    const res = await request.get('/users', { params: { limit: 100 } })
    users.value = (res as any).data?.users || []
  } catch (error) {
    console.error('获取用户列表失败')
  }
}

async function fetchCalls() {
  try {
    const [activeRes, historyRes, statsRes] = await Promise.all([
      callApi.getActive(),
      callApi.getHistory({ limit: 50 }),
      callApi.getStats()
    ])
    activeCalls.value = (activeRes as any).data?.items || []
    history.value = (historyRes as any).data?.items || []
    stats.answer_rate = (statsRes as any).data?.answer_rate || 0
    stats.avg_duration_sec = (statsRes as any).data?.avg_duration_sec || 0
  } catch (error) {
    message.error('获取通话数据失败')
  }
}

function handleCardClick(target: any) {
  if (!isRegistered.value) {
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
    
    if (await initWebRTC(callData.call_id, target.type, callData.callee_id)) {
      const offer = await peerConnection.value?.createOffer()
      await peerConnection.value?.setLocalDescription(offer)
      
      const socket = getSocket()
      socket?.emit('webrtc_offer', {
        target_type: target.type,
        target_id: callData.callee_id,
        offer,
        call_id: callData.call_id
      })
    }
    await fetchCalls()
  } catch (error) {
    message.error('发起呼叫失败')
  } finally {
    calling.value = false
  }
}

function handleOutgoingCancel() {
  if (outgoingCallModal.callId) {
    hangup(outgoingCallModal.callId)
  }
  outgoingCallModal.visible = false
}

async function answer(callId: string) {
  try {
    await callApi.answer(callId)
    message.success('通话已接通')
    
    // 如果 store 中没有详情，尝试从活跃列表中找
    const callDetail = appStore.currentCall || activeCalls.value.find(c => c.call_id === callId)
    if (callDetail) {
      const targetType = callDetail.caller_type || callDetail.from_type
      const targetId = callDetail.caller_id || callDetail.from_id
      await initWebRTC(callId, targetType, targetId)
    }
    await fetchCalls()
  } catch (error) {
    message.error('接听失败')
  }
}

async function hangup(callId: string) {
  try {
    await callApi.hangup(callId)
    cleanupWebRTC()
    message.success('已挂断')
    await fetchCalls()
  } catch (error) {
    message.error('挂断失败')
  }
}

// ... WebRTC Logic ...
const iceServers = {
  iceServers: [{ urls: 'stun:stun.l.google.com:19302' }]
}

const peerConnection = ref<RTCPeerConnection | null>(null)
const localStream = ref<MediaStream | null>(null)
const remoteAudio = ref<HTMLAudioElement | null>(null)

async function initWebRTC(callId: string, targetType: string, targetId: string) {
  cleanupWebRTC()
  peerConnection.value = new RTCPeerConnection(iceServers)
  try {
    localStream.value = await navigator.mediaDevices.getUserMedia({ audio: true })
    localStream.value.getTracks().forEach(track => {
      peerConnection.value?.addTrack(track, localStream.value!)
    })
  } catch (err) {
    message.error('无法访问麦克风，请检查权限设置')
    return false
  }
  peerConnection.value.ontrack = (event) => {
    if (!remoteAudio.value) remoteAudio.value = new Audio()
    remoteAudio.value.srcObject = event.streams[0]
    remoteAudio.value.play().catch(e => console.error('音频播放失败:', e))
  }
  peerConnection.value.onicecandidate = (event) => {
    if (event.candidate) {
      getSocket()?.emit('webrtc_ice_candidate', {
        target_type: targetType,
        target_id: targetId,
        candidate: event.candidate,
        call_id: callId
      })
    }
  }
  return true
}

function cleanupWebRTC() {
  if (peerConnection.value) { peerConnection.value.close(); peerConnection.value = null; }
  if (localStream.value) { localStream.value.getTracks().forEach(track => track.stop()); localStream.value = null; }
  if (remoteAudio.value) { remoteAudio.value.pause(); remoteAudio.value.srcObject = null; remoteAudio.value = null; }
}

function setupSignalingListeners() {
  const socket = getSocket()
  if (!socket) return
  socket.on('incoming_call', (data) => {
    incomingCallModal.callId = data.call_id
    incomingCallModal.callerId = data.caller_id
    incomingCallModal.callerName = data.caller_name || data.caller_id
    incomingCallModal.callerType = data.caller_type
    incomingCallModal.status = 'ringing'
    incomingCallModal.startTime = null
    incomingCallModal.visible = true
    fetchCalls()
  })
  socket.on('online_status', (data: any) => {
    console.log('[WS] 收到在线状态:', data)
    onlineStatus.value = data
  })
  socket.on('webrtc_offer', async (data) => {
    // 只有在已创建 peerConnection 的情况下才处理（即用户已点击接听）
    if (peerConnection.value) {
      await peerConnection.value?.setRemoteDescription(new RTCSessionDescription(data.offer))
      const answer = await peerConnection.value?.createAnswer()
      await peerConnection.value?.setLocalDescription(answer)
      socket.emit('webrtc_answer', { target_type: data.from_type, target_id: data.from_id, answer, call_id: data.call_id })
    }
  })
  socket.on('webrtc_answer', async (data) => {
    if (peerConnection.value) await peerConnection.value.setRemoteDescription(new RTCSessionDescription(data.answer))
    outgoingCallModal.visible = false // 接通后关闭呼叫中弹窗
  })
  socket.on('webrtc_ice_candidate', async (data) => {
    if (peerConnection.value) try { await peerConnection.value.addIceCandidate(new RTCIceCandidate(data.candidate)) } catch (e) {}
  })
  socket.on('call_answered', () => { 
    message.success('通话已接通')
    incomingCallModal.status = 'connected'
    incomingCallModal.startTime = Date.now()
    // 启动定时器更新通话时长
    durationTimer.value = setInterval(() => {
      currentDuration.value = formatDuration(incomingCallModal.startTime)
    }, 1000)
    fetchCalls()
  })
  socket.on('call_rejected', () => { 
    message.warning('通话被拒接')
    if (durationTimer.value) { clearInterval(durationTimer.value); durationTimer.value = null }
    cleanupWebRTC()
    incomingCallModal.visible = false
    fetchCalls()
  })
  socket.on('call_hungup', () => { 
    message.info('通话已挂断')
    if (durationTimer.value) { clearInterval(durationTimer.value); durationTimer.value = null }
    cleanupWebRTC()
    incomingCallModal.visible = false
    fetchCalls()
  })
}

async function handleIncomingAccept() {
  await answer(incomingCallModal.callId)
  incomingCallModal.visible = false
}

async function handleIncomingReject() {
  await hangup(incomingCallModal.callId)
  incomingCallModal.visible = false
}

function toggleRegister() {
  let socket = getSocket()
  if (!socket || !socket.connected) socket = initWebSocket()
  if (!socket || !socket.connected) { message.error('WebSocket 连接中...'); return; }
  if (isRegistered.value) {
    isRegistered.value = false
    clientDisplayName.value = ''
    message.info('已下线')
  } else {
    const id = appStore.userInfo?.username || 'FD-01'
    socket.emit('register_client', { clientType: 'front_desk', clientId: id })
    socket.once('registered', (data: any) => {
      isRegistered.value = true
      clientDisplayName.value = data.clientName
      message.success(`欢迎，${data.clientName}`)
      socket.emit('get_online_status')
    })
  }
}

onMounted(async () => {
  await Promise.all([fetchCalls(), fetchUsers(), hotelStore.fetchRooms({ pageSize: 300 })])
  let socket = getSocket()
  if (!socket || !socket.connected) socket = initWebSocket()
  if (socket) {
    socketConnected.value = socket.connected
    socket.on('connect', () => { socketConnected.value = true; setupSignalingListeners(); })
    socket.on('disconnect', () => { socketConnected.value = false; isRegistered.value = false; })
    if (socket.connected) {
      setupSignalingListeners()
      socket.emit('get_online_status')
    }
  }
})

onUnmounted(() => {
  cleanupWebRTC()
  if (durationTimer.value) { clearInterval(durationTimer.value); durationTimer.value = null }
  const socket = getSocket()
  if (socket) {
    socket.off('incoming_call'); socket.off('webrtc_offer'); socket.off('webrtc_answer');
    socket.off('webrtc_ice_candidate'); socket.off('call_answered'); socket.off('call_rejected'); socket.off('call_hungup');
  }
})

const historyColumns = [
  { title: '主叫', dataIndex: 'caller_id', width: 120 },
  { title: '被叫', dataIndex: 'callee_id', width: 120 },
  { title: '状态', dataIndex: 'status', key: 'status', width: 100 },
  { title: '时长', dataIndex: 'duration_sec', key: 'duration', width: 100 },
  { title: '时间', dataIndex: 'started_at', width: 180 }
]

function statusColor(status: string) {
  return ({ calling: 'processing', connected: 'success', ended: 'default', rejected: 'error' } as any)[status] || 'default'
}

function statusText(status: string) {
  return ({ calling: '呼叫中', connected: '已接通', ended: '已结束', rejected: '已拒接' } as any)[status] || status
}

// 格式化通话时长
function formatDuration(startTime: number | null): string {
  if (!startTime) return '00:00'
  const elapsed = Math.floor((Date.now() - startTime) / 1000)
  const minutes = Math.floor(elapsed / 60)
  const seconds = elapsed % 60
  return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`
}
</script>

<style scoped>
.voice-calls-container { padding: 0; }
.stat-row { margin-bottom: 16px; }
.stat-card { border-radius: 8px; }
.registration-status { display: flex; flex-direction: column; gap: 8px; }
.reg-info { font-size: 12px; }
.reg-info .value { font-weight: bold; margin-left: 4px; color: #1890ff; }

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

/* 仿照房间状态的颜色 */
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

/* 来电弹窗样式 */
.incoming-call-content { text-align: center; padding: 24px 0; }
.pulse-container { position: relative; width: 80px; height: 80px; margin: 0 auto 24px; }
.call-icon { font-size: 48px; color: #52c41a; position: relative; z-index: 2; line-height: 80px; }
.pulse-ring {
  position: absolute; width: 100%; height: 100%; border-radius: 50%;
  background: #52c41a; opacity: 0.2; animation: pulse 1.5s infinite;
}
@keyframes pulse {
  0% { transform: scale(1); opacity: 0.4; }
  100% { transform: scale(1.8); opacity: 0; }
}
.caller-name { font-size: 24px; font-weight: bold; margin-bottom: 8px; }
.caller-id { color: #8c8c8c; margin-bottom: 32px; }

.outgoing-call-content { text-align: center; padding: 32px 0; }

.grid-scroll { max-height: calc(100vh - 300px); overflow-y: auto; padding-right: 8px; }
</style>
