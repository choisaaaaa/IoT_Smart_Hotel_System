<template>
  <a-config-provider :locale="zhCN">
    <router-view />
    
    <!-- 全局来电弹窗 -->
    <IncomingCallModal />
    
    <!-- 全局通话中悬浮窗 -->
    <div v-if="currentCallVisible && route.path !== '/guest/room'" class="global-call-window">
      <div class="call-header">
        <PhoneOutlined class="call-icon-mini" />
        <span class="caller-name-mini">{{ currentCallInfo?.caller_name || currentCallInfo?.caller_id }}</span>
        <div class="connection-status" :class="connectionState">
          {{ connectionStateText }}
        </div>
      </div>
      <div class="call-duration">{{ currentDuration }}</div>
      
      <!-- 通话状态 -->
      <div class="call-status-banner" :class="connectionState">
        <span class="status-dot"></span>
        <span class="status-text">{{ callStatusText }}</span>
      </div>
      
      <!-- 音频电平指示器 -->
      <div class="audio-indicators">
        <div class="audio-indicator" :class="{ speaking: localSpeaking }">
          <div class="indicator-label">
            <span class="indicator-icon">🎤</span>
            <span class="indicator-text">我</span>
            <span class="indicator-status" :class="{ active: inputVolume > 5, speaking: localSpeaking }">{{ localSpeaking ? '说话中' : (inputVolume > 5 ? '正常' : '静音') }}</span>
          </div>
          <div class="level-bar-container">
            <div class="level-bar" :style="{ height: inputVolume + '%' }"></div>
          </div>
        </div>
        <div class="audio-indicator" :class="{ speaking: remoteSpeaking }">
          <div class="indicator-label">
            <span class="indicator-icon">🔊</span>
            <span class="indicator-text">对方</span>
            <span class="indicator-status" :class="{ active: outputVolume > 5, speaking: remoteSpeaking }">{{ remoteSpeaking ? '说话中' : (outputVolume > 5 ? '正常' : '静音') }}</span>
          </div>
          <div class="level-bar-container">
            <div class="level-bar output" :style="{ height: outputVolume + '%' }"></div>
          </div>
        </div>
      </div>
      
      <!-- 连接质量 -->
      <div class="connection-quality" v-if="connectionState === 'connected'">
        <div class="quality-item">
          <span class="quality-label">连接:</span>
          <span class="quality-value" :class="connectionState">{{ connectionStateText }}</span>
        </div>
        <div class="quality-item" v-if="remoteAddress">
          <span class="quality-label">网络:</span>
          <span class="quality-value">{{ remoteAddress }}</span>
        </div>
      </div>
      
      <a-button danger size="small" @click="handleHangup" class="hangup-btn" block>
        <template #icon><CloseOutlined /></template> 挂断
      </a-button>
    </div>

    <!-- 远程音频元素 -->
    <audio ref="remoteAudioRef" autoplay style="display: none;"></audio>
  </a-config-provider>
</template>

<script setup lang="ts">
import { onMounted, onUnmounted, computed, ref, reactive, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { PhoneOutlined, CloseOutlined } from '@ant-design/icons-vue'
import { message } from 'ant-design-vue'
import zhCN from 'ant-design-vue/es/locale/zh_CN'
import IncomingCallModal from '@/components/common/IncomingCallModal.vue'
import { useAppStore } from '@/stores/app'
import { getSocket, initWebSocket } from '@/utils/websocket'
import { callApi } from '@/api/call'

const route = useRoute()
const router = useRouter()
const appStore = useAppStore()

// ============ 通话中悬浮窗 ============
const currentCallInfo = computed(() => appStore.currentCall)
const currentCallVisible = computed(() => !!appStore.currentCall)
const currentDuration = ref('00:00')
const durationTimer = ref<NodeJS.Timeout | null>(null)
const callStartTime = ref<number | null>(null)

// 通话状态检测
const connectionState = ref('new')
const iceConnectionState = ref('new')
const remoteAddress = ref('')
const inputVolume = ref(0)
const outputVolume = ref(0)
const showStats = ref(false)
const audioAnalyser = ref<AnalyserNode | null>(null)
const outputAudioAnalyser = ref<AnalyserNode | null>(null)
const volumeCheckInterval = ref<NodeJS.Timeout | null>(null)

// 通话双方状态
const localSpeaking = ref(false)
const remoteSpeaking = ref(false)
const lastLocalSpeakTime = ref(0)
const lastRemoteSpeakTime = ref(0)

const connectionStateText = computed(() => {
  const stateMap: Record<string, string> = {
    'new': '初始化',
    'connecting': '连接中',
    'connected': '已连接',
    'disconnected': '断开',
    'failed': '失败',
    'closed': '关闭'
  }
  return stateMap[connectionState.value] || connectionState.value
})

// 通话状态文本
const callStatusText = computed(() => {
  if (connectionState.value === 'connected') {
    if (remoteSpeaking.value && localSpeaking.value) {
      return '双向通话中'
    } else if (remoteSpeaking.value) {
      return '对方正在说话'
    } else if (localSpeaking.value) {
      return '您正在说话'
    } else {
      return '通话中 - 静音'
    }
  } else if (connectionState.value === 'connecting') {
    return '建立连接中...'
  } else if (connectionState.value === 'new') {
    return '等待接听...'
  } else {
    return '连接异常'
  }
})

function toggleStats() {
  showStats.value = !showStats.value
}

// 初始化输入音量检测（麦克风）
function initInputVolumeDetection(stream: MediaStream) {
  try {
    const audioContext = new (window.AudioContext || (window as any).webkitAudioContext)()
    audioAnalyser.value = audioContext.createAnalyser()
    audioAnalyser.value.fftSize = 256
    const source = audioContext.createMediaStreamSource(stream)
    source.connect(audioAnalyser.value)
    
    const dataArray = new Uint8Array(audioAnalyser.value.frequencyBinCount)
    
    volumeCheckInterval.value = setInterval(() => {
      if (audioAnalyser.value) {
        audioAnalyser.value.getByteFrequencyData(dataArray)
        let sum = 0
        for (let i = 0; i < dataArray.length; i++) {
          sum += dataArray[i]
        }
        const average = sum / dataArray.length
        inputVolume.value = Math.min(100, Math.round((average / 128) * 100))
        
        // 检测本地是否在说话（音量超过阈值）
        const SPEAKING_THRESHOLD = 10
        if (inputVolume.value > SPEAKING_THRESHOLD) {
          localSpeaking.value = true
          lastLocalSpeakTime.value = Date.now()
        } else if (Date.now() - lastLocalSpeakTime.value > 500) {
          localSpeaking.value = false
        }

        // 同步到全局 store
        appStore.setCallState({
          inputVolume: inputVolume.value,
          localSpeaking: localSpeaking.value
        })
      }
    }, 100)
  } catch (e) {
    console.error('[Audio] 输入音量检测初始化失败:', e)
  }
}

// 初始化输出音量检测（远端音频）
function initOutputVolumeDetection(stream: MediaStream) {
  try {
    const audioContext = new (window.AudioContext || (window as any).webkitAudioContext)()
    outputAudioAnalyser.value = audioContext.createAnalyser()
    outputAudioAnalyser.value.fftSize = 256
    const source = audioContext.createMediaStreamSource(stream)
    source.connect(outputAudioAnalyser.value)
    
    const dataArray = new Uint8Array(outputAudioAnalyser.value.frequencyBinCount)
    
    // 使用单独的 interval 检测输出音量
    const outputInterval = setInterval(() => {
      if (outputAudioAnalyser.value && appStore.currentCall) {
        outputAudioAnalyser.value.getByteFrequencyData(dataArray)
        let sum = 0
        for (let i = 0; i < dataArray.length; i++) {
          sum += dataArray[i]
        }
        const average = sum / dataArray.length
        outputVolume.value = Math.min(100, Math.round((average / 128) * 100))
        
        // 检测远端是否在说话（音量超过阈值）
        const SPEAKING_THRESHOLD = 10
        if (outputVolume.value > SPEAKING_THRESHOLD) {
          remoteSpeaking.value = true
          lastRemoteSpeakTime.value = Date.now()
        } else if (Date.now() - lastRemoteSpeakTime.value > 500) {
          remoteSpeaking.value = false
        }

        // 同步到全局 store
        appStore.setCallState({
          outputVolume: outputVolume.value,
          remoteSpeaking: remoteSpeaking.value
        })
      } else {
        clearInterval(outputInterval)
      }
    }, 100)
  } catch (e) {
    console.error('[Audio] 输出音量检测初始化失败:', e)
  }
}

function stopVolumeDetection() {
  if (volumeCheckInterval.value) {
    clearInterval(volumeCheckInterval.value)
    volumeCheckInterval.value = null
  }
  audioAnalyser.value = null
  outputAudioAnalyser.value = null
  inputVolume.value = 0
  outputVolume.value = 0
}

watch(() => appStore.currentCall, (newCall) => {
  if (newCall) {
    callStartTime.value = Date.now()
    currentDuration.value = '00:00'
    if (durationTimer.value) clearInterval(durationTimer.value)
    durationTimer.value = setInterval(() => {
      if (callStartTime.value) {
        const elapsed = Math.floor((Date.now() - callStartTime.value) / 1000)
        const minutes = Math.floor(elapsed / 60)
        const seconds = elapsed % 60
        currentDuration.value = `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`
        appStore.setCallState({ duration: currentDuration.value })
      }
    }, 1000)
  } else {
    if (durationTimer.value) {
      clearInterval(durationTimer.value)
      durationTimer.value = null
    }
    callStartTime.value = null
    currentDuration.value = '00:00'
  }
})

async function handleHangup() {
  if (appStore.currentCall) {
    try {
      await callApi.hangup(appStore.currentCall.call_id)
      cleanupWebRTC()
      appStore.clearCurrentCall()
      message.success('通话已挂断')
    } catch (error) {
      message.error('挂断失败')
    }
  }
}

// ============ WebRTC ============
const remoteAudioRef = ref<HTMLAudioElement | null>(null)
const peerConnection = ref<RTCPeerConnection | null>(null)
const localStream = ref<MediaStream | null>(null)
const pendingOffer = ref<{ offer: any; from_type: string; from_id: string; call_id: string } | null>(null)
const pendingIceCandidates = ref<any[]>([])

const iceServers = {
  iceServers: [{ urls: 'stun:stun.l.google.com:19302' }]
}

async function initWebRTC(callId: string, targetType: string, targetId: string) {
  console.log('[WebRTC] 初始化:', { callId, targetType, targetId })
  
  try {
    // 获取本地音频流
    localStream.value = await navigator.mediaDevices.getUserMedia({ audio: true, video: false })
    console.log('[WebRTC] 已获取本地音频流')
    
    // 启动输入音量检测（麦克风）
    initInputVolumeDetection(localStream.value)

    // 创建 RTCPeerConnection
    peerConnection.value = new RTCPeerConnection(iceServers)

    // 添加本地流到连接
    localStream.value.getTracks().forEach(track => {
      if (localStream.value && peerConnection.value) {
        peerConnection.value.addTrack(track, localStream.value)
      }
    })

    // 监听远程流
    peerConnection.value.ontrack = (event) => {
      console.log('[WebRTC] 收到远程流:', event.streams)
      
      if (event.streams && event.streams[0]) {
        const remoteStream = event.streams[0]
        console.log('[WebRTC] 远程流轨道数:', remoteStream.getTracks().length)
        
        if (remoteAudioRef.value) {
          remoteAudioRef.value.srcObject = remoteStream
          console.log('[WebRTC] 已设置srcObject')
          
          // 尝试播放（处理自动播放策略）
          const playPromise = remoteAudioRef.value.play()
          if (playPromise !== undefined) {
            playPromise.then(() => {
              console.log('[WebRTC] 远程音频播放成功')
            }).catch(e => {
              console.error('[WebRTC] 自动播放失败:', e)
              // 显示提示让用户点击
              message.info('请点击页面任意位置以启用通话音频')
            })
          }
          
          // 启动输出音量检测
          initOutputVolumeDetection(remoteStream)
        }
      }
    }

    // 监听连接状态变化
    peerConnection.value.onconnectionstatechange = () => {
      if (peerConnection.value) {
        connectionState.value = peerConnection.value.connectionState
        console.log('[WebRTC] 连接状态变化:', connectionState.value)
        
        // 同步到全局 store
        appStore.setCallState({ connectionState: connectionState.value })

        // 获取远端地址信息
        if (peerConnection.value.connectionState === 'connected') {
          peerConnection.value.getStats().then(stats => {
            stats.forEach(report => {
              if (report.type === 'candidate-pair' && report.state === 'succeeded') {
                remoteAddress.value = report.remoteCandidate?.address || ''
              }
            })
          })
        }
      }
    }

    // 监听 ICE 连接状态
    peerConnection.value.oniceconnectionstatechange = () => {
      if (peerConnection.value) {
        iceConnectionState.value = peerConnection.value.iceConnectionState
        console.log('[WebRTC] ICE 状态变化:', iceConnectionState.value)
      }
    }

    // 监听 ICE 候选
    peerConnection.value.onicecandidate = (event) => {
      if (event.candidate) {
        const socket = getSocket()
        if (socket) {
          socket.emit('webrtc_ice_candidate', {
            target_type: targetType,
            target_id: targetId,
            candidate: event.candidate,
            call_id: callId
          })
        }
      }
    }

    // 被叫方：如果有待处理的 offer，处理它
    if (pendingOffer.value && pendingOffer.value.call_id === callId) {
      console.log('[WebRTC] 处理待处理的 offer')
      await handleOffer(pendingOffer.value)
      pendingOffer.value = null
    }

    return true
  } catch (error) {
    console.error('[WebRTC] 初始化失败:', error)
    message.error('无法访问麦克风')
    return false
  }
}

async function handleOffer(data: { offer: any; from_type: string; from_id: string; call_id: string }) {
  if (!peerConnection.value) {
    console.log('[WebRTC] 连接未初始化，保存 offer 等待后续处理')
    pendingOffer.value = data
    return
  }

  try {
    await peerConnection.value.setRemoteDescription(new RTCSessionDescription(data.offer))
    console.log('[WebRTC] 已设置 remote description')

    const answer = await peerConnection.value.createAnswer()
    await peerConnection.value.setLocalDescription(answer)
    console.log('[WebRTC] 已创建并设置 local description (answer)')

    const socket = getSocket()
    if (socket) {
      socket.emit('webrtc_answer', {
        target_type: data.from_type,
        target_id: data.from_id,
        answer,
        call_id: data.call_id
      })
      console.log('[WebRTC] 已发送 answer')
    }

    // 处理待处理的 ICE 候选
    while (pendingIceCandidates.value.length > 0) {
      const candidate = pendingIceCandidates.value.shift()
      await peerConnection.value.addIceCandidate(new RTCIceCandidate(candidate))
    }
  } catch (e) {
    console.error('[WebRTC] 处理 offer 失败:', e)
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
  pendingIceCandidates.value = []
  pendingOffer.value = null
  // 重置状态
  connectionState.value = 'new'
  iceConnectionState.value = 'new'
  remoteAddress.value = ''
  localSpeaking.value = false
  remoteSpeaking.value = false
  stopVolumeDetection()
}

// ============ WebSocket 监听 ============
// 使用命名函数以便正确管理监听器
const handleConnect = () => {
  console.log('[App] WebSocket 已连接')
  appStore.setConnected(true)
  
  // 注册逻辑已在 websocket.ts 的 connect 回调中通过 userInfo 自动处理
  // 这里不再需要硬编码为 front_desk 的注册
}

const handleRegistered = (data: any) => {
  console.log('[App] 注册成功:', data)
  appStore.setRegistration(true, data.clientName)
}

const handleDisconnect = () => {
  console.log('[App] WebSocket 已断开')
  appStore.setConnected(false)
  // 注意：断开时不清除注册状态，因为会自动重连
}

const handleIncomingCall = (data: any) => {
  console.log('[App] 收到来电:', data)
  
  const myUsername = appStore.userInfo?.username
  if (data.caller_id === myUsername) {
    console.log('[App] 忽略自己发起的 incoming_call')
    return
  }
  
  if (data.broadcast && data.callee_id !== myUsername) {
    console.log('[App] 忽略广播来电，不是给我的')
    return
  }
  
  // 如果正在通话中，忽略新的来电
  if (appStore.currentCall) {
    console.log('[App] 正在通话中，忽略新的来电')
    return
  }
  
  appStore.setIncomingCall(data)
}

const handleWebRTCOffer = async (data: any) => {
  console.log('[WebRTC] 收到 offer')
  if (!peerConnection.value) {
    pendingOffer.value = {
      offer: data.offer,
      from_type: data.from_type,
      from_id: data.from_id,
      call_id: data.call_id
    }
    return
  }
  await handleOffer(data)
}

const handleWebRTCAnswer = async (data: any) => {
  console.log('[WebRTC] 收到 answer')
  if (peerConnection.value && peerConnection.value.signalingState === 'have-local-offer') {
    try {
      await peerConnection.value.setRemoteDescription(new RTCSessionDescription(data.answer))
      console.log('[WebRTC] 已设置 remote description (answer)')
    } catch (e) {
      console.error('[WebRTC] 设置 answer 失败:', e)
    }
  }
}

const handleWebRTCIceCandidate = async (data: any) => {
  console.log('[WebRTC] 收到 ICE 候选:', data.candidate)
  console.log('[WebRTC] 当前连接状态:', peerConnection.value?.connectionState)
  console.log('[WebRTC] remoteDescription是否存在:', !!peerConnection.value?.remoteDescription)
  
  if (peerConnection.value && peerConnection.value.remoteDescription) {
    try {
      await peerConnection.value.addIceCandidate(new RTCIceCandidate(data.candidate))
      console.log('[WebRTC] ICE候选添加成功')
    } catch (e) {
      console.error('[WebRTC] 添加 ICE 候选失败:', e)
    }
  } else {
    console.log('[WebRTC] ICE候选已缓存，等待remoteDescription')
    pendingIceCandidates.value.push(data.candidate)
  }
}

const handleCallHungup = (data: any) => {
  console.log('[App] 通话被挂断:', data)
  if (appStore.incomingCall?.call_id === data.call_id) {
    appStore.clearIncomingCall()
  }
  if (appStore.currentCall?.call_id === data.call_id) {
    cleanupWebRTC()
    appStore.clearCurrentCall()
    message.info('对方已挂断')
  }
}

const handleCallRejected = (data: any) => {
  console.log('[App] 通话被拒接:', data)
  if (appStore.currentCall?.call_id === data.call_id) {
    cleanupWebRTC()
    appStore.clearCurrentCall()
    message.warning('通话被拒接')
  }
}

const handleCallAnswered = async (data: any) => {
  console.log('[App] 收到 call_answered 事件:', data)

  // 如果当前有这个来电，说明是被别人接听了，清除来电弹窗
  if (appStore.incomingCall?.call_id === data.call_id) {
    console.log('[App] 该来电已被他人接听，清除弹窗')
    appStore.clearIncomingCall()
    return
  }

  if (appStore.currentCall?.call_id === data.call_id) {
    // 更新通话状态
    appStore.setCurrentCall({
      ...appStore.currentCall,
      status: 'connected'
    })
    
    // 判断当前端是主叫还是被叫
    // 主叫需要发起 offer，被叫只需要 initWebRTC 并等待 offer
    const myUsername = appStore.userInfo?.username
    // 注意：room_id 可能来自 appStore.userStatus.checkin_info
    const myRoomId = appStore.userStatus?.checkin_info?.room_id ? String(appStore.userStatus.checkin_info.room_id) : ''
    const isCaller = String(data.caller_id) === myUsername || String(data.caller_id) === myRoomId
    
    console.log(`[App] 身份识别: ${isCaller ? '主叫' : '被叫'}, 我是: ${myUsername || myRoomId || 'unknown'}, 对方是: ${isCaller ? data.callee_id : data.caller_id}, data.caller_id: ${data.caller_id}`)
    
    const targetType = isCaller ? data.callee_type : data.caller_type
    const targetId = isCaller ? data.callee_id : data.caller_id
    
    await initWebRTC(data.call_id, targetType, targetId)
    
    // 只有主叫方发送 offer
    if (isCaller && peerConnection.value) {
      try {
        const offer = await peerConnection.value.createOffer()
        await peerConnection.value.setLocalDescription(offer)
        console.log('[WebRTC] 主叫方已创建并发送 offer')
        
        const socket = getSocket()
        if (socket) {
          socket.emit('webrtc_offer', {
            target_type: targetType,
            target_id: targetId,
            offer: offer,
            call_id: data.call_id
          })
        }
      } catch (e) {
        console.error('[WebRTC] 创建 offer 失败:', e)
      }
    } else {
      console.log('[WebRTC] 被叫方等待主叫方发送 offer')
    }
  }
}

function setupGlobalWebSocket() {
  const socket = getSocket() || initWebSocket()
  if (!socket) return

  // 先移除旧的监听器（避免重复）
  socket.off('connect', handleConnect)
  socket.off('registered', handleRegistered)
  socket.off('disconnect', handleDisconnect)
  socket.off('incoming_call', handleIncomingCall)
  socket.off('call_answered', handleCallAnswered)
  socket.off('webrtc_offer', handleWebRTCOffer)
  socket.off('webrtc_answer', handleWebRTCAnswer)
  socket.off('webrtc_ice_candidate', handleWebRTCIceCandidate)
  socket.off('call_hungup', handleCallHungup)
  socket.off('call_rejected', handleCallRejected)

  // 添加新的监听器
  socket.on('connect', handleConnect)
  socket.on('registered', handleRegistered)
  socket.on('disconnect', handleDisconnect)
  socket.on('incoming_call', handleIncomingCall)
  socket.on('call_answered', handleCallAnswered)
  socket.on('webrtc_offer', handleWebRTCOffer)
  socket.on('webrtc_answer', handleWebRTCAnswer)
  socket.on('webrtc_ice_candidate', handleWebRTCIceCandidate)
  socket.on('call_hungup', handleCallHungup)
  socket.on('call_rejected', handleCallRejected)
}

onMounted(() => {
  if (localStorage.getItem('auth_token')) {
    setupGlobalWebSocket()
  }
})

// 注意：不要在 onUnmounted 中移除 WebSocket 监听器
// 因为 App.vue 是全局根组件，WebSocket 应该始终保持连接和监听
// 只有页面刷新或关闭时才真正断开
window.addEventListener('beforeunload', () => {
  cleanupWebRTC()
  if (durationTimer.value) {
    clearInterval(durationTimer.value)
  }
})
</script>

<style>
/* 来电弹窗样式 */
.global-incoming-call-modal .ant-modal-content {
  border-radius: 16px;
  overflow: hidden;
}

.incoming-call-content { 
  text-align: center; 
  padding: 32px 24px; 
}

.pulse-container { 
  position: relative; 
  width: 80px; 
  height: 80px; 
  margin: 0 auto 24px; 
}

.call-icon { 
  font-size: 48px; 
  color: #52c41a; 
  position: relative; 
  z-index: 2; 
  line-height: 80px; 
}

.pulse-ring {
  position: absolute; 
  width: 100%; 
  height: 100%; 
  border-radius: 50%;
  background: #52c41a; 
  opacity: 0.2; 
  animation: pulse 1.5s infinite;
}

@keyframes pulse {
  0% { transform: scale(1); opacity: 0.4; }
  100% { transform: scale(1.8); opacity: 0; }
}

.caller-name { 
  font-size: 24px; 
  font-weight: bold; 
  margin-bottom: 8px;
  color: #262626;
}

.caller-id { 
  color: #8c8c8c; 
  margin-bottom: 32px;
  font-size: 14px;
}

.modal-actions { 
  padding: 0 8px; 
}

.accept-btn { 
  background: #52c41a !important; 
  border-color: #52c41a !important;
  height: 44px;
  font-size: 16px;
}

.accept-btn:hover { 
  background: #73d13d !important; 
  border-color: #73d13d !important; 
}

.reject-btn { 
  background: #fff !important; 
  border-color: #ff4d4f !important;
  color: #ff4d4f !important;
  height: 44px;
  font-size: 16px;
}

.reject-btn:hover { 
  background: #fff1f0 !important; 
  border-color: #ff7875 !important; 
  color: #ff7875 !important;
}

/* 通话中悬浮窗 */
.global-call-window {
  position: fixed;
  bottom: 20px;
  right: 20px;
  width: 200px;
  background: #fff;
  border-radius: 12px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
  padding: 16px;
  z-index: 9999;
  text-align: center;
  border: 2px solid #52c41a;
}

.call-header {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  margin-bottom: 8px;
}

.call-icon-mini {
  font-size: 20px;
  color: #52c41a;
}

.caller-name-mini {
  font-size: 14px;
  font-weight: bold;
  color: #262626;
}

.call-duration {
  font-size: 24px;
  font-weight: bold;
  color: #52c41a;
  margin: 12px 0;
  font-family: monospace;
}

.hangup-btn {
  background: #ff4d4f !important;
  border-color: #ff4d4f !important;
  color: #fff !important;
  margin-top: 12px;
}

.hangup-btn:hover {
  background: #ff7875 !important;
  border-color: #ff7875 !important;
}

/* 音频电平指示器 */
.audio-indicators {
  display: flex;
  justify-content: center;
  gap: 24px;
  margin: 12px 0;
  padding: 12px;
  background: #f5f5f5;
  border-radius: 8px;
}

.audio-indicator {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
}

.indicator-label {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
}

.indicator-icon {
  font-size: 16px;
}

.indicator-text {
  font-size: 11px;
  color: #8c8c8c;
}

.indicator-status {
  font-size: 10px;
  padding: 1px 6px;
  border-radius: 4px;
  background: #d9d9d9;
  color: #8c8c8c;
  transition: all 0.3s;
}

.indicator-status.active {
  background: #52c41a;
  color: #fff;
}

.level-bar-container {
  width: 12px;
  height: 60px;
  background: #e8e8e8;
  border-radius: 6px;
  overflow: hidden;
  position: relative;
}

.level-bar {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  background: linear-gradient(to top, #52c41a, #95de64);
  border-radius: 6px;
  transition: height 0.1s ease;
  min-height: 2px;
}

.level-bar.output {
  background: linear-gradient(to top, #1890ff, #69c0ff);
}

/* 连接状态 */
.connection-info {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  margin-bottom: 8px;
  font-size: 12px;
  color: #8c8c8c;
}

.connection-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #d9d9d9;
}

.connection-dot.connected {
  background: #52c41a;
  box-shadow: 0 0 4px #52c41a;
}

.connection-dot.connecting {
  background: #faad14;
  animation: blink 1s infinite;
}

.connection-dot.failed,
.connection-dot.disconnected {
  background: #ff4d4f;
}

@keyframes blink {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

/* 通话状态横幅 */
.call-status-banner {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 8px 12px;
  border-radius: 6px;
  margin-bottom: 12px;
  font-size: 13px;
  font-weight: 500;
  transition: all 0.3s;
}

.call-status-banner.connected {
  background: #f6ffed;
  color: #52c41a;
  border: 1px solid #b7eb8f;
}

.call-status-banner.connecting {
  background: #fffbe6;
  color: #faad14;
  border: 1px solid #ffe58f;
}

.call-status-banner.new {
  background: #e6f7ff;
  color: #1890ff;
  border: 1px solid #91d5ff;
}

.call-status-banner.failed,
.call-status-banner.disconnected {
  background: #fff1f0;
  color: #ff4d4f;
  border: 1px solid #ffa39e;
}

.status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: currentColor;
  animation: pulse-dot 1.5s infinite;
}

@keyframes pulse-dot {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.6; transform: scale(1.2); }
}

/* 音频指示器说话状态 */
.audio-indicator.speaking {
  transform: scale(1.05);
  transition: transform 0.2s;
}

.audio-indicator.speaking .level-bar-container {
  box-shadow: 0 0 8px rgba(82, 196, 26, 0.4);
}

.indicator-status.speaking {
  background: #52c41a !important;
  color: #fff !important;
  animation: pulse-status 1s infinite;
}

@keyframes pulse-status {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.7; }
}

/* 连接质量 */
.connection-quality {
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 8px 12px;
  background: #fafafa;
  border-radius: 6px;
  margin-bottom: 12px;
  font-size: 11px;
}

.quality-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.quality-label {
  color: #8c8c8c;
}

.quality-value {
  color: #262626;
  font-weight: 500;
}

.quality-value.connected {
  color: #52c41a;
}
</style>
