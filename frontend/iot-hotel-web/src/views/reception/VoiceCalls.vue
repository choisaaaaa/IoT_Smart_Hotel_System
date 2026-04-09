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
      :mask="incomingCallModal.status !== 'connected'"
      :centered="incomingCallModal.status !== 'connected'"
      :wrap-class-name="incomingCallModal.status === 'connected' ? 'incoming-call-modal-wrap mini-call-window' : 'incoming-call-modal-wrap'"
      :width="incomingCallModal.status === 'connected' ? '200px' : '320px'"
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
          <div class="mini-call-content">
            <div class="mini-call-header">
              <PhoneOutlined class="call-icon-mini" style="color: #52c41a;" />
              <span class="caller-name-mini">{{ incomingCallModal.callerName }}</span>
            </div>
            <p class="call-duration-mini">{{ currentDuration }}</p>
            <a-button danger size="small" @click="handleIncomingReject" class="hangup-btn-mini">
              <template #icon><CloseOutlined /></template> 挂断
            </a-button>
          </div>
        </template>
      </div>
    </a-modal>

    <!-- 正在呼叫/通话中弹窗 -->
    <a-modal
      v-model:visible="outgoingCallModal.visible"
      :footer="null"
      :closable="false"
      :maskClosable="false"
      :mask="outgoingCallModal.status !== 'connected'"
      :centered="outgoingCallModal.status !== 'connected'"
      :wrap-class-name="outgoingCallModal.status === 'connected' ? 'outgoing-call-modal-wrap mini-call-window' : 'outgoing-call-modal-wrap'"
      :width="outgoingCallModal.status === 'connected' ? '200px' : '320px'"
      @cancel="handleOutgoingCancel"
    >
      <div class="outgoing-call-content">
        <!-- 呼叫中状态 -->
        <template v-if="outgoingCallModal.status === 'calling'">
          <a-avatar :size="64" icon="user" />
          <h2 style="margin-top: 16px">{{ outgoingCallModal.targetName }}</h2>
          <p>正在呼叫中...</p>
          <a-button danger shape="circle" size="large" @click="handleOutgoingCancel">
            <template #icon><CloseOutlined /></template>
          </a-button>
        </template>
        
        <!-- 通话中状态 -->
        <template v-else-if="outgoingCallModal.status === 'connected'">
          <div class="mini-call-content">
            <div class="mini-call-header">
              <PhoneOutlined class="call-icon-mini" style="color: #52c41a;" />
              <span class="caller-name-mini">{{ outgoingCallModal.targetName }}</span>
            </div>
            <p class="call-duration-mini">{{ currentDuration }}</p>
            <a-button danger size="small" @click="handleOutgoingCancel" class="hangup-btn-mini">
              <template #icon><CloseOutlined /></template> 挂断
            </a-button>
          </div>
        </template>
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
const listenersSetup = ref(false)
const activeTab = ref('all')
const onlineStatus = ref<{ web: any[], rooms: any[] }>({ web: [], rooms: [] })
const fetchCallsTimer = ref<NodeJS.Timeout | null>(null)
const lastFetchTime = ref(0)

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

// 保存待处理的 WebRTC offer（等待用户接听）
const pendingOffer = ref<{ offer: any; from_type: string; from_id: string; call_id: string } | null>(null)

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
  callId: '',
  status: 'calling' as 'calling' | 'connected',
  startTime: 0
})

// 组合可呼叫目标
const callableTargets = computed(() => {
  const list: any[] = []
  
  console.log('[VoiceCalls] 当前用户:', appStore.userInfo?.username, '在线状态:', onlineStatus.value)
  
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
    console.log('[VoiceCalls] 检查用户:', user.username, '当前用户:', appStore.userInfo?.username)
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

const lastFetchUsersTime = ref(0)

async function fetchUsers() {
  // 防抖：如果 2 秒内已经请求过，则跳过
  const now = Date.now()
  if (now - lastFetchUsersTime.value < 2000) {
    console.log('[VoiceCalls] fetchUsers 被防抖跳过')
    return
  }
  lastFetchUsersTime.value = now
  
  try {
    const res = await request.get('/users', { params: { limit: 100 } })
    users.value = (res as any).data?.users || []
  } catch (error: any) {
    if (error.response?.status === 429) {
      console.warn('[VoiceCalls] 获取用户列表请求过于频繁')
    } else {
      console.error('获取用户列表失败')
    }
  }
}

async function fetchCalls() {
  // 防抖：如果 2 秒内已经请求过，则跳过
  const now = Date.now()
  if (now - lastFetchTime.value < 2000) {
    console.log('[VoiceCalls] fetchCalls 被防抖跳过')
    return
  }
  lastFetchTime.value = now
  
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
  } catch (error: any) {
    if (error.response?.status === 429) {
      console.warn('[VoiceCalls] 请求过于频繁，跳过错误提示')
    } else {
      message.error('获取通话数据失败')
    }
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

// 保存主叫方的呼叫信息，等待对方接听后再初始化 WebRTC
const pendingCall = ref<{ callId: string; targetType: string; targetId: string } | null>(null)

async function startCall(target: any) {
  calling.value = true
  console.log('[VoiceCalls] 发起呼叫:', {
    caller_id: appStore.userInfo?.username || 'FD-01',
    callee_type: target.type,
    callee_id: target.clientId,
    target
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
    
    // 保存呼叫信息，等待对方接听后再初始化 WebRTC
    pendingCall.value = {
      callId: callData.call_id,
      targetType: target.type,
      targetId: callData.callee_id
    }
    console.log('[VoiceCalls] 等待对方接听，暂不初始化 WebRTC')
    
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
  outgoingCallModal.status = 'calling'
  outgoingCallModal.startTime = 0
  if (durationTimer.value) {
    clearInterval(durationTimer.value)
    durationTimer.value = null
  }
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
const pendingIceCandidates = ref<RTCIceCandidateInit[]>([])

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
    console.log('[WebRTC] 收到远程音频流:', event.streams[0])
    if (!remoteAudio.value) remoteAudio.value = new Audio()
    remoteAudio.value.srcObject = event.streams[0]
    remoteAudio.value.autoplay = true
    remoteAudio.value.play().then(() => {
      console.log('[WebRTC] 音频播放成功')
    }).catch(e => console.error('[WebRTC] 音频播放失败:', e))
  }
  peerConnection.value.onicecandidate = (event) => {
    if (event.candidate) {
      console.log('[WebRTC] 发送 ICE candidate')
      getSocket()?.emit('webrtc_ice_candidate', {
        target_type: targetType,
        target_id: targetId,
        candidate: event.candidate,
        call_id: callId
      })
    }
  }
  peerConnection.value.onconnectionstatechange = () => {
    console.log('[WebRTC] 连接状态变化:', peerConnection.value?.connectionState)
  }
  peerConnection.value.oniceconnectionstatechange = () => {
    console.log('[WebRTC] ICE 连接状态变化:', peerConnection.value?.iceConnectionState)
  }
  return true
}

function cleanupWebRTC() {
  if (peerConnection.value) { peerConnection.value.close(); peerConnection.value = null; }
  if (localStream.value) { localStream.value.getTracks().forEach(track => track.stop()); localStream.value = null; }
  if (remoteAudio.value) { remoteAudio.value.pause(); remoteAudio.value.srcObject = null; remoteAudio.value = null; }
  pendingIceCandidates.value = []
  pendingOffer.value = null
}

function setupSignalingListeners() {
  const socket = getSocket()
  if (!socket) return
  if (listenersSetup.value) return // 防止重复设置
  listenersSetup.value = true
  
  console.log('[WS] 设置信令监听器')
  
  socket.on('incoming_call', (data) => {
    console.log('[WS] 收到 incoming_call:', data)
    
    // 如果是广播消息，检查是否是给自己的
    if (data.broadcast) {
      const myUsername = appStore.userInfo?.username
      if (data.callee_id !== myUsername) {
        console.log('[WS] 忽略广播来电，不是给我的:', myUsername)
        return
      }
    }
    
    // 检查是否是自己发起的呼叫（避免主叫方收到自己的 incoming_call）
    const myUsername = appStore.userInfo?.username
    if (data.caller_id === myUsername) {
      console.log('[WS] 忽略自己发起的 incoming_call:', myUsername)
      return
    }
    
    // 如果已经有进行中的通话，忽略新的 incoming_call
    if (incomingCallModal.visible || outgoingCallModal.visible) {
      console.log('[WS] 已有进行中的通话，忽略 incoming_call')
      return
    }
    
    incomingCallModal.callId = data.call_id
    incomingCallModal.callerId = data.caller_id
    incomingCallModal.callerName = data.caller_name || data.caller_id
    incomingCallModal.callerType = data.caller_type
    incomingCallModal.status = 'ringing'
    incomingCallModal.startTime = null
    incomingCallModal.visible = true
    
    // 注意：不要在这里初始化 WebRTC，等待用户点击接听后再初始化
    
    fetchCalls()
  })
  socket.on('online_status', (data: any) => {
    console.log('[WS] 收到在线状态:', data)
    onlineStatus.value = data
  })
  socket.on('webrtc_offer', async (data) => {
    console.log('[WebRTC] 收到 offer，当前状态:', peerConnection.value?.signalingState)
    
    // 如果还没有初始化 WebRTC（用户还没点击接听），保存 offer 等待后续处理
    if (!peerConnection.value) {
      console.log('[WebRTC] 保存 offer 等待用户接听')
      pendingOffer.value = {
        offer: data.offer,
        from_type: data.from_type,
        from_id: data.from_id,
        call_id: data.call_id
      }
      return
    }
    
    // 被叫方：收到 offer 后设置 remote desc，创建 answer，发送回去
    if (peerConnection.value.signalingState === 'stable') {
      try {
        await peerConnection.value.setRemoteDescription(new RTCSessionDescription(data.offer))
        console.log('[WebRTC] 已设置 remote description')
        
        const answer = await peerConnection.value.createAnswer()
        await peerConnection.value.setLocalDescription(answer)
        console.log('[WebRTC] 已创建并设置 local description (answer)')
        
        socket.emit('webrtc_answer', { 
          target_type: data.from_type, 
          target_id: data.from_id, 
          answer, 
          call_id: data.call_id 
        })
        console.log('[WebRTC] 已发送 answer')
      } catch (e) {
        console.error('[WebRTC] 处理 offer 失败:', e)
      }
    } else {
      console.log('[WebRTC] 无法处理 offer，当前状态:', peerConnection.value?.signalingState)
    }
  })
  socket.on('webrtc_answer', async (data) => {
    if (peerConnection.value) {
      await peerConnection.value.setRemoteDescription(new RTCSessionDescription(data.answer))
      console.log('[WebRTC] 收到 answer，已设置 remote description')
      
      // 处理之前保存的 ICE candidate
      if (pendingIceCandidates.value.length > 0) {
        console.log(`[WebRTC] 处理 ${pendingIceCandidates.value.length} 个待处理的 ICE candidate`)
        for (const candidate of pendingIceCandidates.value) {
          try {
            await peerConnection.value?.addIceCandidate(new RTCIceCandidate(candidate))
          } catch (e) {
            console.error('[WebRTC] 添加待处理的 ICE candidate 失败:', e)
          }
        }
        pendingIceCandidates.value = []
      }
    }
    // WebRTC 连接已建立，弹窗保持显示（小窗模式）
    console.log('[WebRTC] 连接建立')
  })
  socket.on('webrtc_ice_candidate', async (data) => {
    console.log('[WebRTC] 收到 ICE candidate')
    if (peerConnection.value && peerConnection.value.remoteDescription) {
      // 如果已经有 remote description，直接添加
      try { 
        await peerConnection.value.addIceCandidate(new RTCIceCandidate(data.candidate)) 
        console.log('[WebRTC] ICE candidate 已添加')
      } catch (e) {
        console.error('[WebRTC] 添加 ICE candidate 失败:', e)
      }
    } else {
      // 否则保存到待处理列表
      console.log('[WebRTC] 保存 ICE candidate 到待处理列表')
      pendingIceCandidates.value.push(data.candidate)
    }
  })
  socket.on('call_answered', async (data: any) => { 
    message.success('通话已接通')
    
    // 主叫方：收到对方接听通知后，初始化 WebRTC 并发送 offer
    if (pendingCall.value) {
      console.log('[WebRTC] 对方已接听，主叫方初始化 WebRTC')
      const { callId, targetType, targetId } = pendingCall.value
      
      if (await initWebRTC(callId, targetType, targetId)) {
        const offer = await peerConnection.value?.createOffer()
        await peerConnection.value?.setLocalDescription(offer)
        
        socket.emit('webrtc_offer', {
          target_type: targetType,
          target_id: targetId,
          offer,
          call_id: callId
        })
        console.log('[WebRTC] 主叫方已发送 offer')
      }
      
      pendingCall.value = null
      
      // 主叫方：更新状态为通话中，显示小窗
      outgoingCallModal.status = 'connected'
      outgoingCallModal.startTime = Date.now()
      
      // 启动定时器更新通话时长
      if (durationTimer.value) clearInterval(durationTimer.value)
      durationTimer.value = setInterval(() => {
        currentDuration.value = formatDuration(outgoingCallModal.startTime)
      }, 1000)
    }
    
    // 被叫方：初始化 WebRTC 并处理可能已保存的 offer
    if (incomingCallModal.status === 'ringing') {
      console.log('[WebRTC] 被叫方收到 call_answered，初始化 WebRTC')
      await initWebRTC(incomingCallModal.callId, incomingCallModal.callerType, incomingCallModal.callerId)
      
      // 如果有保存的 offer，立即处理
      if (pendingOffer.value) {
        console.log('[WebRTC] 处理保存的 offer')
        const offerData = pendingOffer.value
        
        try {
          await peerConnection.value?.setRemoteDescription(new RTCSessionDescription(offerData.offer))
          console.log('[WebRTC] 已设置 remote description')
          
          // 处理之前保存的 ICE candidate
          if (pendingIceCandidates.value.length > 0) {
            console.log(`[WebRTC] 处理 ${pendingIceCandidates.value.length} 个待处理的 ICE candidate`)
            for (const candidate of pendingIceCandidates.value) {
              try {
                await peerConnection.value?.addIceCandidate(new RTCIceCandidate(candidate))
              } catch (e) {
                console.error('[WebRTC] 添加待处理的 ICE candidate 失败:', e)
              }
            }
            pendingIceCandidates.value = []
          }
          
          const answer = await peerConnection.value?.createAnswer()
          await peerConnection.value?.setLocalDescription(answer)
          console.log('[WebRTC] 已创建并设置 local description (answer)')
          
          socket.emit('webrtc_answer', { 
            target_type: offerData.from_type, 
            target_id: offerData.from_id, 
            answer, 
            call_id: offerData.call_id 
          })
          console.log('[WebRTC] 已发送 answer')
        } catch (e) {
          console.error('[WebRTC] 处理 offer 失败:', e)
        }
        
        pendingOffer.value = null
      }
      
      // 被叫方：更新弹窗状态为通话中
      incomingCallModal.status = 'connected'
      incomingCallModal.startTime = Date.now()
      
      // 启动定时器更新通话时长
      if (durationTimer.value) clearInterval(durationTimer.value)
      durationTimer.value = setInterval(() => {
        currentDuration.value = formatDuration(incomingCallModal.startTime)
      }, 1000)
    }
    
    fetchCalls()
  })
  socket.on('call_rejected', () => { 
    message.warning('通话被拒接')
    if (durationTimer.value) { clearInterval(durationTimer.value); durationTimer.value = null }
    cleanupWebRTC()
    incomingCallModal.visible = false
    // 清理主叫方状态
    outgoingCallModal.visible = false
    outgoingCallModal.status = 'calling'
    outgoingCallModal.startTime = 0
    fetchCalls()
  })
  socket.on('call_hungup', () => { 
    message.info('通话已挂断')
    if (durationTimer.value) { clearInterval(durationTimer.value); durationTimer.value = null }
    cleanupWebRTC()
    incomingCallModal.visible = false
    // 清理主叫方状态
    outgoingCallModal.visible = false
    outgoingCallModal.status = 'calling'
    outgoingCallModal.startTime = 0
    fetchCalls()
  })
}

async function handleIncomingAccept() {
  // 发送接听请求到服务器（服务器会通知主叫方）
  await answer(incomingCallModal.callId)
  
  // 注意：WebRTC 初始化移到 call_answered 事件处理中
  // 等待主叫方收到 call_answered 后发送 offer，我们再处理
}

async function handleIncomingReject() {
  await hangup(incomingCallModal.callId)
  incomingCallModal.visible = false
}

function toggleRegister() {
  // 初始化 WebSocket（如果已存在且连接中则复用，否则创建新的）
  const socket = initWebSocket()
  
  if (!socket || !socket.connected) { 
    message.error('WebSocket 连接中...')
    return
  }
  
  // 确保事件监听已设置
  setupSignalingListeners()
  
  if (isRegistered.value) {
    isRegistered.value = false
    clientDisplayName.value = ''
    message.info('已下线')
  } else {
    const id = appStore.userInfo?.username || 'FD-01'
    console.log('[VoiceCalls] 注册客户端:', id, '当前用户信息:', appStore.userInfo)
    socket.emit('register_client', { clientType: 'front_desk', clientId: id })
    socket.once('registered', (data: any) => {
      console.log('[VoiceCalls] 注册成功:', data)
      isRegistered.value = true
      clientDisplayName.value = data.clientName
      message.success(`欢迎，${data.clientName}`)
      socket.emit('get_online_status')
    })
  }
}

onMounted(async () => {
  await Promise.all([fetchCalls(), fetchUsers(), hotelStore.fetchRooms({ pageSize: 300 })])
  
  // 初始化 WebSocket（如果已存在且连接中则复用，否则创建新的）
  const socket = initWebSocket()
  
  if (socket) {
    socketConnected.value = socket.connected
    
    // 无论是否已连接，都先设置监听
    setupSignalingListeners()
    
    socket.on('connect', () => { 
      socketConnected.value = true
      console.log('[VoiceCalls] WebSocket 已连接')
      // 重新连接时重新设置监听
      listenersSetup.value = false
      setupSignalingListeners()
      socket.emit('get_online_status')
    })
    
    socket.on('disconnect', () => { 
      socketConnected.value = false
      isRegistered.value = false
      console.log('[VoiceCalls] WebSocket 已断开')
    })
    
    if (socket.connected) {
      console.log('[VoiceCalls] WebSocket 已连接，获取在线状态')
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
  listenersSetup.value = false
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

/* 小窗通话样式 */
.mini-call-window :deep(.ant-modal-content) {
  position: fixed !important;
  bottom: 20px !important;
  right: 20px !important;
  top: auto !important;
  left: auto !important;
  margin: 0 !important;
}
.mini-call-window :deep(.ant-modal-wrap) {
  position: fixed;
  top: auto !important;
  bottom: 0;
  right: 0;
  left: auto !important;
  width: auto !important;
  height: auto !important;
}
.mini-call-content {
  padding: 12px;
  text-align: center;
}
.mini-call-header {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  margin-bottom: 8px;
}
.call-icon-mini {
  font-size: 20px;
}
.caller-name-mini {
  font-size: 14px;
  font-weight: bold;
}
.call-duration-mini {
  font-size: 18px;
  font-weight: bold;
  color: #52c41a;
  margin: 8px 0;
}
.hangup-btn-mini {
  width: 100%;
}

.outgoing-call-content { text-align: center; padding: 32px 0; }

.grid-scroll { max-height: calc(100vh - 300px); overflow-y: auto; padding-right: 8px; }
</style>
