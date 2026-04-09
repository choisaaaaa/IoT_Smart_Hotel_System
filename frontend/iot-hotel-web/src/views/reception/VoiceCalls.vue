<template>
  <div class="voice-calls">
    <a-row :gutter="[16, 16]">
      <a-col :xs="24" :sm="8">
        <a-card size="small">
          <a-statistic title="活跃通话" :value="activeCalls.length" :value-style="{ color: '#1890ff' }" />
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="8">
        <a-card size="small">
          <a-statistic title="接通率" :value="Number((stats.answer_rate || 0) * 100)" suffix="%" :precision="0" :value-style="{ color: '#52c41a' }" />
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="8">
        <a-card size="small">
          <a-statistic title="平均通话时长" :value="stats.avg_duration_sec || 0" suffix="秒" :value-style="{ color: '#722ed1' }" />
        </a-card>
      </a-col>
    </a-row>

    <a-card title="前台分机设置" style="margin-bottom: 16px;">
      <a-form layout="inline">
        <a-form-item label="当前分机 ID">
          <a-input v-model:value="callForm.caller_id" placeholder="例如 FD-01" style="width: 160px;" :disabled="isRegistered" />
        </a-form-item>
        <a-form-item>
          <a-button :type="isRegistered ? 'default' : 'primary'" @click="toggleRegister">
            {{ isRegistered ? '退出/修改' : '上线注册' }}
          </a-button>
          <a-tag v-if="isRegistered" color="success" style="margin-left: 8px;">
            在线: {{ clientDisplayName }}
          </a-tag>
        </a-form-item>
      </a-form>
    </a-card>

    <a-card title="发起语音通话">
      <a-form layout="inline">
        <a-form-item label="目标类型">
          <a-select v-model:value="callForm.callee_type" style="width: 120px;">
            <a-select-option value="room">客房硬件</a-select-option>
            <a-select-option value="front_desk">前台管理</a-select-option>
            <a-select-option value="app">手机APP</a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item label="目标 ID">
          <a-input v-model:value="callForm.callee_id" placeholder="输入房号或用户ID" style="width: 180px;" />
        </a-form-item>
        <a-form-item>
          <a-button type="primary" @click="startCall" :loading="calling" :disabled="!isRegistered">发起呼叫</a-button>
        </a-form-item>
      </a-form>
    </a-card>

    <a-card title="当前通话" style="margin-top: 16px;">
      <a-table :columns="activeColumns" :data-source="activeCalls" :pagination="false" row-key="call_id" size="middle">
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'caller'">
            {{ record.caller_name || record.caller_id }}
          </template>
          <template v-if="column.key === 'status'">
            <a-tag :color="statusColor(record.status)">{{ statusText(record.status) }}</a-tag>
          </template>
          <template v-if="column.key === 'action'">
            <a-space>
              <a-button type="link" size="small" v-if="['calling', 'outgoing', 'ringing'].includes(record.status)" @click="answer(record.call_id)">接听</a-button>
              <a-button type="link" danger size="small" @click="hangup(record.call_id)">挂断</a-button>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

    <a-card title="通话记录" style="margin-top: 16px;">
      <a-table :columns="historyColumns" :data-source="history" :pagination="{ pageSize: 8 }" row-key="call_id" size="middle">
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'status'">
            <a-tag :color="statusColor(record.status)">{{ statusText(record.status) }}</a-tag>
          </template>
          <template v-if="column.key === 'duration'">
            {{ record.duration_sec || 0 }} 秒
          </template>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { onMounted, onUnmounted, reactive, ref } from 'vue'
import { message } from 'ant-design-vue'
import { callApi } from '@/api/call'
import { getSocket } from '@/utils/websocket'

const calling = ref(false)
const activeCalls = ref<any[]>([])
const history = ref<any[]>([])
const stats = reactive({
  answer_rate: 0,
  avg_duration_sec: 0
})

type CallTargetType = 'room' | 'front_desk' | 'ai' | 'app'

const callForm = reactive({
  caller_id: 'FD-01',
  callee_id: '',
  callee_type: 'front_desk' as CallTargetType // 显式指定类型以修复 TS 错误
})

const isRegistered = ref(false)
const clientDisplayName = ref('')

function toggleRegister() {
  const socket = getSocket()
  if (!socket) {
    message.error('WebSocket 未连接')
    return
  }

  if (isRegistered.value) {
    isRegistered.value = false
    clientDisplayName.value = ''
    message.info('已下线，分机号已释放')
  } else {
    if (!callForm.caller_id) {
      message.warning('请输入分机 ID 或用户名')
      return
    }
    // 向后端发送注册请求
    socket.emit('register_client', {
      clientType: 'front_desk',
      clientId: callForm.caller_id
    })
    
    // 监听注册结果
    socket.once('registered', (data: any) => {
      isRegistered.value = true
      clientDisplayName.value = data.clientName
      message.success(`欢迎回来，${data.clientName}`)
    })

    socket.once('error', (err: any) => {
      message.error(err.message || '注册失败')
    })
  }
}

// WebRTC 状态
const peerConnection = ref<RTCPeerConnection | null>(null)
const localStream = ref<MediaStream | null>(null)
const remoteAudio = ref<HTMLAudioElement | null>(null)

const activeColumns = [
  { title: '通话 ID', dataIndex: 'call_id', width: 200 },
  { title: '主叫', key: 'caller', width: 150 },
  { title: '被叫', dataIndex: 'callee_id', width: 120 },
  { title: '状态', dataIndex: 'status', key: 'status', width: 100 },
  { title: '开始时间', dataIndex: 'started_at', width: 180 },
  { title: '操作', key: 'action', width: 140 }
]

const historyColumns = [
  { title: '通话 ID', dataIndex: 'call_id', width: 200 },
  { title: '主叫', dataIndex: 'caller_id', width: 120 },
  { title: '被叫', dataIndex: 'callee_id', width: 120 },
  { title: '状态', dataIndex: 'status', key: 'status', width: 100 },
  { title: '时长', dataIndex: 'duration_sec', key: 'duration', width: 100 },
  { title: '开始时间', dataIndex: 'started_at', width: 180 }
]

function statusColor(status: string): string {
  return ({
    calling: 'processing',
    outgoing: 'processing',
    ringing: 'warning',
    connected: 'success',
    ended: 'default',
    rejected: 'error'
  } as Record<string, string>)[status] || 'default'
}

function statusText(status: string): string {
  return ({
    calling: '呼叫中',
    outgoing: '外呼中',
    ringing: '振铃中',
    connected: '已接通',
    ended: '已结束',
    rejected: '已拒接'
  } as Record<string, string>)[status] || status
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

// --- WebRTC Logic ---

const iceServers = {
  iceServers: [{ urls: 'stun:stun.l.google.com:19302' }]
}

async function initWebRTC(callId: string, targetType: string, targetId: string) {
  if (peerConnection.value) {
    peerConnection.value.close()
  }

  peerConnection.value = new RTCPeerConnection(iceServers)

  // 获取本地音频
  try {
    localStream.value = await navigator.mediaDevices.getUserMedia({ audio: true })
    localStream.value.getTracks().forEach(track => {
      peerConnection.value?.addTrack(track, localStream.value!)
    })
  } catch (err) {
    message.error('无法访问麦克风，请检查权限设置')
    return false
  }

  // 接收远程音频流
  peerConnection.value.ontrack = (event) => {
    if (!remoteAudio.value) {
      remoteAudio.value = new Audio()
    }
    remoteAudio.value.srcObject = event.streams[0]
    remoteAudio.value.play().catch(e => console.error('音频播放失败:', e))
  }

  // 转发 ICE 候选
  peerConnection.value.onicecandidate = (event) => {
    if (event.candidate) {
      const socket = getSocket()
      socket?.emit('webrtc_ice_candidate', {
        target_type: targetType,
        target_id: targetId,
        candidate: event.candidate,
        call_id: callId
      })
    }
  }

  return true
}

async function startCall() {
  if (!callForm.caller_id || !callForm.callee_id) {
    message.warning('请输入前台分机和目标 ID')
    return
  }
  calling.value = true
  try {
    const res = await callApi.outbound({
      caller_id: callForm.caller_id,
      callee_type: callForm.callee_type,
      callee_id: callForm.callee_id,
      caller_type: 'front_desk'
    })
    
    const callData = (res as any).data
    message.success('已发起语音呼叫')
    
    // 初始化 WebRTC 并发送 Offer
    if (await initWebRTC(callData.call_id, callForm.callee_type, callData.callee_id)) {
      const offer = await peerConnection.value?.createOffer()
      await peerConnection.value?.setLocalDescription(offer)
      
      const socket = getSocket()
      socket?.emit('webrtc_offer', {
        target_type: 'room',
        target_id: callData.callee_id,
        offer,
        call_id: callData.call_id
      })
    }
    
    callForm.callee_id = ''
    await fetchCalls()
  } catch (error) {
    message.error('发起呼叫失败')
  } finally {
    calling.value = false
  }
}

async function answer(callId: string) {
  try {
    await callApi.answer(callId)
    message.success('已接听')
    
    const call = activeCalls.value.find(c => c.call_id === callId)
    if (call) {
      // 被叫接听，初始化 WebRTC 等待 Offer
      await initWebRTC(callId, call.caller_type, call.caller_id)
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

function cleanupWebRTC() {
  if (peerConnection.value) {
    peerConnection.value.close()
    peerConnection.value = null
  }
  if (localStream.value) {
    localStream.value.getTracks().forEach(track => track.stop())
    localStream.value = null
  }
  if (remoteAudio.value) {
    remoteAudio.value.pause()
    remoteAudio.value.srcObject = null
    remoteAudio.value = null
  }
}

// 注册信令监听
function setupSignalingListeners() {
  const socket = getSocket()
  if (!socket) return

  socket.on('incoming_call', (data) => {
    message.info(`收到来自 ${data.caller_name || data.caller_id} 的呼叫`)
    fetchCalls()
  })

  socket.on('webrtc_offer', async (data) => {
    console.log('收到 WebRTC Offer:', data)
    if (!peerConnection.value) {
      await initWebRTC(data.call_id, data.from_type, data.from_id)
    }
    
    await peerConnection.value?.setRemoteDescription(new RTCSessionDescription(data.offer))
    const answer = await peerConnection.value?.createAnswer()
    await peerConnection.value?.setLocalDescription(answer)
    
    socket.emit('webrtc_answer', {
      target_type: data.from_type,
      target_id: data.from_id,
      answer,
      call_id: data.call_id
    })
  })

  socket.on('webrtc_answer', async (data) => {
    console.log('收到 WebRTC Answer:', data)
    if (peerConnection.value) {
      await peerConnection.value.setRemoteDescription(new RTCSessionDescription(data.answer))
    }
  })

  socket.on('webrtc_ice_candidate', async (data) => {
    console.log('收到 WebRTC ICE Candidate:', data)
    if (peerConnection.value) {
      try {
        await peerConnection.value.addIceCandidate(new RTCIceCandidate(data.candidate))
      } catch (e) {
        console.error('添加 ICE Candidate 失败:', e)
      }
    }
  })

  socket.on('call_answered', (data) => {
    message.success('通话已接通')
    fetchCalls()
  })

  socket.on('call_rejected', (data) => {
    message.warning('通话被拒接')
    cleanupWebRTC()
    fetchCalls()
  })

  socket.on('call_hungup', (data) => {
    message.info('通话已挂断')
    cleanupWebRTC()
    fetchCalls()
  })
}

onMounted(() => {
  fetchCalls()
  setupSignalingListeners()
})

onUnmounted(() => {
  cleanupWebRTC()
  const socket = getSocket()
  if (socket) {
    socket.off('incoming_call')
    socket.off('webrtc_offer')
    socket.off('webrtc_answer')
    socket.off('webrtc_ice_candidate')
    socket.off('call_answered')
    socket.off('call_rejected')
    socket.off('call_hungup')
  }
})
</script>
