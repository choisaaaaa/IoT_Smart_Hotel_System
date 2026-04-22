<template>
  <a-config-provider :locale="zhCN">
    <router-view />
    
    <!-- 全局来电弹窗 -->
    <IncomingCallModal />
    
    <!-- 全局通话界面 (统一全系统) -->
    <template v-if="currentCallVisible">
      <!-- 全屏 Modal 模式 (GuestRoom 页面或点击展开时显示) -->
      <a-modal
        :open="isCallModalFullscreen"
        :footer="null"
        :closable="false"
        :maskClosable="false"
        centered
        width="360px"
        class="unified-call-modal"
      >
        <div class="call-content-modal">
          <div class="call-header-modal">
            <div class="caller-avatar">
              <CustomerServiceOutlined v-if="otherPartyType === 'front_desk'" />
              <HomeOutlined v-else />
            </div>
            <h3>{{ remoteDisplayName }}</h3>
            <div class="call-status-tag" :class="connectionState">
              {{ connectionStateText }}
            </div>
            <div style="margin-top: 12px;">
              <a-button size="small" type="link" @click="refreshCallStatus">
                <template #icon><ReloadOutlined /></template>
                同步状态
              </a-button>
            </div>
          </div>

          <div class="call-body-modal">
            <div class="duration-display">{{ currentDuration }}</div>
            
            <div class="voice-waves-container">
              <!-- 本地声浪 (左) -->
              <div class="voice-wave-side local" :class="{ speaking: localSpeaking }">
                <div class="wave-bars">
                  <div v-for="i in 8" :key="'l'+i" class="wave-bar" 
                    :style="{ 
                      height: (localSpeaking ? (10 + Math.random() * (inputVolume * 0.8)) : 4) + 'px',
                      opacity: 0.3 + (inputVolume / 100)
                    }">
                  </div>
                </div>
                <span class="wave-label">您</span>
              </div>

              <div class="wave-divider">
                <div class="pulse-center" :class="connectionState"></div>
              </div>

              <!-- 远端声浪 (右) -->
              <div class="voice-wave-side remote" :class="{ speaking: remoteSpeaking }">
                <div class="wave-bars">
                  <div v-for="i in 8" :key="'r'+i" class="wave-bar" 
                    :style="{ 
                      height: (remoteSpeaking ? (10 + Math.random() * (outputVolume * 0.8)) : 4) + 'px',
                      opacity: 0.3 + (outputVolume / 100)
                    }">
                  </div>
                </div>
                <span class="wave-label">对方</span>
              </div>
            </div>
          </div>

          <div class="call-footer-modal">
            <div class="modal-action-buttons">
              <a-button type="primary" danger shape="round" size="large" @click="handleHangup" class="hangup-btn-large">
                <template #icon><CloseOutlined /></template> 挂断
              </a-button>
              <a-button shape="round" size="large" @click="minimizeCall" v-if="route.path !== '/guest/room'">
                <template #icon><FullscreenExitOutlined /></template> 最小化
              </a-button>
            </div>
          </div>
        </div>
      </a-modal>

      <!-- 悬浮窗口模式 (其他页面显示) -->
      <div v-if="!isCallModalFullscreen" class="global-call-window" @click="expandCall">
        <div class="call-header">
          <PhoneOutlined class="call-icon-mini" />
          <span class="caller-name-mini">{{ remoteDisplayName }}</span>
          <a-button type="link" size="small" @click.stop="refreshCallStatus" style="padding: 0; height: auto;">
            <template #icon><ReloadOutlined /></template>
          </a-button>
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
        
        <!-- 简易音频电平 -->
        <div class="mini-audio-indicators">
          <div class="mini-level-bar" :style="{ height: (inputVolume / 2) + 'px', background: localSpeaking ? '#52c41a' : '#ddd' }"></div>
          <div class="mini-level-bar" :style="{ height: (outputVolume / 2) + 'px', background: remoteSpeaking ? '#1890ff' : '#ddd' }"></div>
        </div>
        
        <a-button danger size="small" @click.stop="handleHangup" class="hangup-btn" block>
          <template #icon><CloseOutlined /></template> 挂断
        </a-button>
      </div>
    </template>

    <!-- 远程音频元素 -->
    <audio ref="remoteAudioRef" autoplay style="display: none;"></audio>
  </a-config-provider>
</template>

<script setup lang="ts">
import { onMounted, onUnmounted, computed, ref, reactive, watch, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { 
  PhoneOutlined, CloseOutlined, FullscreenExitOutlined, 
  CustomerServiceOutlined, HomeOutlined, ReloadOutlined 
} from '@ant-design/icons-vue'
import { message } from 'ant-design-vue'
import zhCN from 'ant-design-vue/es/locale/zh_CN'
import IncomingCallModal from '@/components/common/IncomingCallModal.vue'
import { useAppStore } from '@/stores/app'
import { getSocket, initWebSocket } from '@/utils/websocket'
import { callApi } from '@/api/call'
import { systemConfigApi } from '@/api/system-config'

const route = useRoute()
const router = useRouter()
const appStore = useAppStore()

// 统一通话界面模式控制
const isMinimized = ref(false)
const isCallModalFullscreen = computed(() => {
  // 如果在 GuestRoom 页面，强制全屏 Modal
  if (route.path === '/guest/room') return true
  // 其他页面，根据用户手动切换状态
  return !isMinimized.value
})

function minimizeCall() {
  isMinimized.value = true
}

function expandCall() {
  isMinimized.value = false
}

// 刷新通话状态（强制同步）
function refreshCallStatus() {
  const socket = getSocket()
  if (socket) {
    socket.emit('get_online_status')
    message.success('已发起状态同步')
  }
}

// ============ 通话中悬浮窗 ============
const currentCallInfo = computed(() => appStore.currentCall)
const currentCallVisible = computed(() => !!appStore.currentCall)

// 计算我是不是主叫 (Caller)
const isCallerToMe = computed(() => {
  if (!appStore.currentCall) return false
  
  // 1. 优先通过 appStore.currentCall 里的信息判断 (如果是自己发起的，这里会有记录)
  const myId = appStore.userInfo?.username
  const myRoomId = appStore.userStatus?.checkin_info?.room_id ? String(appStore.userStatus.checkin_info.room_id) : ''
  
  return String(appStore.currentCall.caller_id) === myId || 
         String(appStore.currentCall.caller_id) === myRoomId
})

const otherPartyType = computed(() => {
  if (!appStore.currentCall) return null
  return isCallerToMe.value ? appStore.currentCall.callee_type : appStore.currentCall.caller_type
})

// 计算对方显示的名称
const remoteDisplayName = computed(() => {
  if (!appStore.currentCall) return '通话中'
  
  const id = isCallerToMe.value ? appStore.currentCall.callee_id : appStore.currentCall.caller_id
  const name = isCallerToMe.value ? appStore.currentCall.callee_name : appStore.currentCall.caller_name
  
  if (id === 'all' || id === 'front_desk') return '前台'
  return name || id || '访客'
})

// 统一通话界面模式控制
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
  // 整合 connectionState 和 iceConnectionState，提高状态感知的灵敏度
  const state = connectionState.value
  const iceState = iceConnectionState.value

  // 如果 ICE 已经连通，但 connectionState 还在 connecting，认为已连通
  if (iceState === 'connected' || iceState === 'completed' || state === 'connected') {
    return '已连接'
  }

  switch (state) {
    case 'new': return '初始化...'
    case 'connecting': return '连接中...'
    case 'disconnected': return '连接断开'
    case 'failed': return '连接失败'
    case 'closed': return '通话结束'
    default: 
      return iceState === 'checking' ? '连接中...' : '连接中'
  }
})

// 通话状态文本
const callStatusText = computed(() => {
  const isConnected = connectionState.value === 'connected' || 
                      iceConnectionState.value === 'connected' || 
                      iceConnectionState.value === 'completed'

  if (isConnected) {
    if (remoteSpeaking.value && localSpeaking.value) {
      return '双向通话中'
    } else if (remoteSpeaking.value) {
      return '对方正在说话'
    } else if (localSpeaking.value) {
      return '您正在说话'
    } else {
      return '通话中 - 静音'
    }
  } else if (connectionState.value === 'connecting' || iceConnectionState.value === 'checking') {
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
    isMinimized.value = false // 新通话开始时默认不最小化
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
    const callId = appStore.currentCall.call_id
    const socket = getSocket()
    if (socket) {
      socket.emit('hangup_call', { call_id: callId })
    }
    try {
      await callApi.hangup(callId)
    } catch (error: any) {
      if (error?.response?.status === 409) {
        console.log('[App] 通话已结束，清理本地状态')
      }
    }
    cleanupWebRTC()
    stopAudioCapture()
    appStore.clearCurrentCall()
    message.success('通话已挂断')
  }
}

// ============ Audio Streaming (Hardware Bridge) ============
const audioContext = ref<AudioContext | null>(null)
const audioChunkTimer = ref<any>(null)
const nextStartTime = ref(0) // 记录下一段音频开始播放的时间戳

// 播放收到的二进制音频片段
const playAudioChunk = async (chunk: ArrayBuffer) => {
  if (!audioContext.value) {
    audioContext.value = new (window.AudioContext || (window as any).webkitAudioContext)({ sampleRate: 16000 })
  }
  
  const ctx = audioContext.value
  if (ctx.state === 'suspended') {
    await ctx.resume()
  }

  const int16Data = new Int16Array(chunk)
  
  // 为硬件通话计算远端音量
  let sum = 0
  for (let i = 0; i < int16Data.length; i++) {
    sum += Math.abs(int16Data[i])
  }
  const average = sum / int16Data.length
  outputVolume.value = Math.min(100, Math.round((average / 1000) * 100)) 
  
  if (outputVolume.value > 5) {
    remoteSpeaking.value = true
    lastRemoteSpeakTime.value = Date.now()
  } else if (Date.now() - lastRemoteSpeakTime.value > 500) {
    remoteSpeaking.value = false
  }
  
  appStore.setCallState({
    outputVolume: outputVolume.value,
    remoteSpeaking: remoteSpeaking.value
  })

  // 转换数据为 Float32
  const float32Data = new Float32Array(int16Data.length)
  for (let i = 0; i < int16Data.length; i++) {
    float32Data[i] = int16Data[i] / 32768.0
  }
  
  const buffer = ctx.createBuffer(1, float32Data.length, 16000)
  buffer.getChannelData(0).set(float32Data)
  
  const source = ctx.createBufferSource()
  source.buffer = buffer
  source.connect(ctx.destination)

  // 关键优化：精确调度播放时间，防止卡顿和爆音
  const currentTime = ctx.currentTime
  
  // 如果当前时间已经超过了预定的开始时间，或者预定时间还没初始化
  if (nextStartTime.value < currentTime) {
    // 增加一小段延迟（50ms）作为初始缓冲，防止网络抖动
    nextStartTime.value = currentTime + 0.05
  }
  
  source.start(nextStartTime.value)
  
  // 更新下一次播放的开始时间 (buffer 时长 = samples / sampleRate)
  nextStartTime.value += buffer.duration
}

// 开始采集并发送音频片段
const startAudioCapture = async (callId: string, targetType: string, targetId: string) => {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: { sampleRate: 16000, channelCount: 1 } })
    
    // 初始化本地音量检测
    initInputVolumeDetection(stream)

    const ctx = new AudioContext({ sampleRate: 16000 })
    const source = ctx.createMediaStreamSource(stream)
    const processor = ctx.createScriptProcessor(2048, 1, 1)

    source.connect(processor)
    processor.connect(ctx.destination)

    processor.onaudioprocess = (e) => {
      if (!appStore.currentCall) {
        stream.getTracks().forEach(t => t.stop())
        ctx.close()
        return
      }

      const inputData = e.inputBuffer.getChannelData(0)
      const int16Data = new Int16Array(inputData.length)
      for (let i = 0; i < inputData.length; i++) {
        int16Data[i] = Math.max(-1, Math.min(1, inputData[i])) * 0x7FFF
      }
      
      const socket = getSocket()
      if (socket) {
        socket.emit('audio_chunk', {
          call_id: callId,
          target_type: targetType,
          target_id: targetId,
          chunk: int16Data.buffer
        })
      }
    }
    
    audioChunkTimer.value = { stream, ctx }
  } catch (err) {
    console.error('Failed to capture audio:', err)
  }
}

const stopAudioCapture = () => {
  if (audioChunkTimer.value) {
    audioChunkTimer.value.stream.getTracks().forEach((t: any) => t.stop())
    audioChunkTimer.value.ctx.close()
    audioChunkTimer.value = null
  }
}

// ============ WebRTC ============
const remoteAudioRef = ref<HTMLAudioElement | null>(null)
const peerConnection = ref<RTCPeerConnection | null>(null)
const localStream = ref<MediaStream | null>(null)
const pendingOffer = ref<{ offer: any; from_type: string; from_id: string; call_id: string } | null>(null)
const pendingIceCandidates = ref<any[]>([])
const processedCallAnswered = ref(new Set<string>())
let isProcessingOffer = false
let initWebRTCPromise: Promise<boolean> | null = null

const iceServers = {
  iceServers: [{ urls: 'stun:stun.l.google.com:19302' }]
}

async function initWebRTC(callId: string, targetType: string, targetId: string) {
  if (peerConnection.value) {
    console.log('[WebRTC] 连接已存在，跳过初始化')
    return true
  }

  if (initWebRTCPromise) {
    console.log('[WebRTC] 初始化进行中，等待完成')
    return initWebRTCPromise
  }

  initWebRTCPromise = _doInitWebRTC(callId, targetType, targetId)
  try {
    return await initWebRTCPromise
  } finally {
    initWebRTCPromise = null
  }
}

async function _doInitWebRTC(callId: string, targetType: string, targetId: string) {
  console.log('[WebRTC] 初始化:', { callId, targetType, targetId })
  
  cleanupWebRTC()
  
  try {
    await nextTick()
    
    localStream.value = await navigator.mediaDevices.getUserMedia({ audio: true, video: false })
    console.log('[WebRTC] 已获取本地音频流, 轨道状态:', localStream.value.getAudioTracks().map(t => ({ enabled: t.enabled, state: t.readyState })))
    
    initInputVolumeDetection(localStream.value)

    peerConnection.value = new RTCPeerConnection(appStore.webrtcConfig)

    localStream.value.getTracks().forEach(track => {
      if (localStream.value && peerConnection.value) {
        peerConnection.value.addTrack(track, localStream.value)
      }
    })

    peerConnection.value.ontrack = (event) => {
      console.log('[WebRTC] 收到远程流:', event.streams)
      
      if (event.streams && event.streams[0]) {
        const remoteStream = event.streams[0]
        console.log('[WebRTC] 远程流轨道状态:', remoteStream.getAudioTracks().map(t => ({ enabled: t.enabled, state: t.readyState })))
        
        if (remoteAudioRef.value) {
          remoteAudioRef.value.srcObject = remoteStream
          console.log('[WebRTC] 已绑定 remoteAudioRef')
          
          const playPromise = remoteAudioRef.value.play()
          if (playPromise !== undefined) {
            playPromise.then(() => {
              console.log('[WebRTC] 远程音频播放成功')
            }).catch(e => {
              console.error('[WebRTC] 自动播放失败:', e)
              message.info('请点击页面任意位置以启用通话音频')
            })
          }
          
          initOutputVolumeDetection(remoteStream)
        } else {
          console.error('[WebRTC] 错误: remoteAudioRef 为空，无法绑定远程流')
        }
      }
    }

    peerConnection.value.onconnectionstatechange = () => {
      if (peerConnection.value) {
        connectionState.value = peerConnection.value.connectionState
        console.log('[WebRTC] 连接状态变化:', connectionState.value)
        
        appStore.setCallState({ connectionState: connectionState.value })

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

    peerConnection.value.oniceconnectionstatechange = () => {
      if (peerConnection.value) {
        iceConnectionState.value = peerConnection.value.iceConnectionState
        console.log('[WebRTC] ICE 状态变化:', iceConnectionState.value)

        if (iceConnectionState.value === 'connected' || iceConnectionState.value === 'completed') {
          if (remoteAudioRef.value && remoteAudioRef.value.paused) {
            console.log('[WebRTC] ICE 连通，尝试播放音频...')
            remoteAudioRef.value.play().catch(e => {
              console.warn('[WebRTC] ICE 连通后尝试播放失败 (可能由于自动播放策略):', e)
            })
          }
        }
      }
    }

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

  if (isProcessingOffer) {
    console.log('[WebRTC] 正在处理 offer，跳过重复调用')
    return
  }
  isProcessingOffer = true

  try {
    let pc = peerConnection.value

    if (pc.signalingState !== 'stable') {
      console.log('[WebRTC] 信令状态异常:', pc.signalingState, '，重置连接')
      isProcessingOffer = false
      cleanupWebRTC()
      await initWebRTC(data.call_id, data.from_type, data.from_id)
      if (!peerConnection.value) return
      isProcessingOffer = true
      pc = peerConnection.value
    }

    await pc.setRemoteDescription(new RTCSessionDescription(data.offer))
    console.log('[WebRTC] 已设置 remote description, signalingState:', pc.signalingState)

    const answer = await pc.createAnswer()
    await pc.setLocalDescription(answer)
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

    if (pc.remoteDescription && pc === peerConnection.value) {
      while (pendingIceCandidates.value.length > 0) {
        const candidate = pendingIceCandidates.value.shift()
        if (!candidate || pc !== peerConnection.value) break
        try {
          await pc.addIceCandidate(new RTCIceCandidate(candidate))
        } catch (iceErr) {
          console.warn('[WebRTC] 添加缓存的ICE候选失败:', iceErr)
        }
      }
    }
  } catch (e) {
    console.error('[WebRTC] 处理 offer 失败:', e)
  } finally {
    isProcessingOffer = false
  }
}

function cleanupWebRTC() {
  isProcessingOffer = false
  initWebRTCPromise = null
  if (peerConnection.value) {
    peerConnection.value.close()
    peerConnection.value = null
  }
  if (localStream.value) {
    localStream.value.getTracks().forEach(track => track.stop())
    localStream.value = null
  }
  stopAudioCapture()
  pendingIceCandidates.value = []
  pendingOffer.value = null
  processedCallAnswered.value.clear()
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
  // 保存服务器下发的 WebRTC 配置（含 STUN/TURN）
  if (data.webrtcConfig) {
    console.log('[App] 收到服务器 WebRTC 配置:', data.webrtcConfig)
    appStore.setWebrtcConfig(data.webrtcConfig)
  }
}

const handleDisconnect = () => {
  console.log('[App] WebSocket 已断开')
  appStore.setConnected(false)
  // 注意：断开时不清除注册状态，因为会自动重连
}

const handleIncomingCall = (data: any) => {
  console.log('[App] 收到来电:', data)
  
  // 发送收到信号的确认，防止丢包
  const socket = getSocket()
  if (socket) {
    socket.emit('call_signal_ack', { call_id: data.call_id, signal_type: 'incoming_call' })
  }

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
  console.log('[WebRTC] 收到 offer, call_id:', data.call_id)
  if (!peerConnection.value) {
    if (appStore.currentCall?.call_id === data.call_id) {
      const isCaller = String(data.caller_id) === appStore.userInfo?.username
      const targetType = isCaller ? data.callee_type : data.caller_type
      const targetId = isCaller ? data.callee_id : data.caller_id
      console.log('[WebRTC] peerConnection不存在，自动初始化WebRTC')
      await initWebRTC(data.call_id, targetType || data.from_type, targetId || data.from_id)
      if (!peerConnection.value) {
        console.log('[WebRTC] 初始化失败，保存 offer 等待后续处理')
        pendingOffer.value = {
          offer: data.offer,
          from_type: data.from_type,
          from_id: data.from_id,
          call_id: data.call_id
        }
        return
      }
    } else {
      pendingOffer.value = {
        offer: data.offer,
        from_type: data.from_type,
        from_id: data.from_id,
        call_id: data.call_id
      }
      return
    }
  }
  await handleOffer(data)
}

const handleWebRTCAnswer = async (data: any) => {
  console.log('[WebRTC] 收到 answer')
  const pc = peerConnection.value
  if (pc && pc.signalingState === 'have-local-offer') {
    try {
      await pc.setRemoteDescription(new RTCSessionDescription(data.answer))
      console.log('[WebRTC] 已设置 remote description (answer)')

      if (pc === peerConnection.value && pc.remoteDescription) {
        while (pendingIceCandidates.value.length > 0) {
          const candidate = pendingIceCandidates.value.shift()
          if (!candidate || pc !== peerConnection.value) break
          try {
            await pc.addIceCandidate(new RTCIceCandidate(candidate))
          } catch (iceErr) {
            console.warn('[WebRTC] 添加缓存的ICE候选失败:', iceErr)
          }
        }
      }
    } catch (e) {
      console.error('[WebRTC] 设置 answer 失败:', e)
    }
  }
}

const handleWebRTCIceCandidate = async (data: any) => {
  const pc = peerConnection.value
  if (pc && pc.remoteDescription && pc.signalingState !== 'closed') {
    try {
      await pc.addIceCandidate(new RTCIceCandidate(data.candidate))
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
  const isRelevantCall = appStore.currentCall?.call_id === data.call_id || appStore.incomingCall?.call_id === data.call_id
  if (!isRelevantCall && !peerConnection.value) {
    return
  }
  if (appStore.incomingCall?.call_id === data.call_id) {
    appStore.clearIncomingCall()
  }
  cleanupWebRTC()
  if (appStore.currentCall?.call_id === data.call_id) {
    appStore.clearCurrentCall()
  }
  message.info('通话已结束')
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

  if (processedCallAnswered.value.has(data.call_id)) {
    console.log('[App] 忽略重复的 call_answered 事件')
    return
  }
  processedCallAnswered.value.add(data.call_id)

  // 发送信号确认
  const socket = getSocket()
  if (socket) {
    socket.emit('call_signal_ack', { call_id: data.call_id, signal_type: 'call_answered' })
  }

  // 更新通话状态为已接通
  if (appStore.currentCall?.call_id === data.call_id) {
    appStore.setCurrentCall({
      ...appStore.currentCall,
      status: 'connected',
      callee_id: data.callee_id || appStore.currentCall.callee_id,
      callee_name: data.callee_name || appStore.currentCall.callee_name,
      caller_id: data.caller_id || appStore.currentCall.caller_id,
      caller_name: data.caller_name || appStore.currentCall.caller_name
    })
  }

  // 如果当前有这个来电弹窗（被叫方），清除它
  if (appStore.incomingCall?.call_id === data.call_id) {
    console.log('[App] 该来电已被接听，清除弹窗')
    appStore.clearIncomingCall()
    // 被叫方逻辑继续执行，不要在此处 return，否则无法初始化 WebRTC
  }

  if (appStore.currentCall?.call_id === data.call_id) {
    // 更加鲁棒的身份识别：检查所有可能的 ID 匹配
    const myUsername = appStore.userInfo?.username
    const myRoomId = appStore.userStatus?.checkin_info?.room_id ? String(appStore.userStatus.checkin_info.room_id) : ''
    const myRoomNum = appStore.userStatus?.checkin_info?.room_number ? String(appStore.userStatus.checkin_info.room_number) : ''
    
    // 主叫判定：data.caller_id 匹配我的用户名、我的房间 ID 或我的房间号
    const isCaller = String(data.caller_id) === myUsername || 
                     String(data.caller_id) === myRoomId || 
                     String(data.caller_id) === myRoomNum
    
    console.log(`[App] 身份识别结果: ${isCaller ? '主叫 (Caller)' : '被叫 (Callee)'}`)
    console.log(`[App] 我的标识集: {user: ${myUsername}, room_id: ${myRoomId}, room_num: ${myRoomNum}}, 对方标识: ${data.caller_id}`)
    
    const targetType = isCaller ? data.callee_type : data.caller_type
    const targetId = isCaller ? data.callee_id : data.caller_id
    
    if (isCaller) {
      if (targetType === 'room') {
        console.log('[App] 目标是房间（硬件），开启原始音频流捕获')
        connectionState.value = 'connected'
        appStore.setCallState({ connectionState: 'connected' })
        await startAudioCapture(data.call_id, targetType, targetId)
      } else {
        await initWebRTC(data.call_id, targetType, targetId)
        
        if (peerConnection.value) {
          const pc = peerConnection.value
          try {
            const offer = await pc.createOffer()
            await pc.setLocalDescription(offer)
            console.log('[WebRTC] 主叫方发起 Offer')
            
            if (pc !== peerConnection.value) {
              console.log('[WebRTC] 创建 Offer 后连接被替换，中止发送')
              return
            }

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
            console.error('[WebRTC] 创建 Offer 失败:', e)
          }
        }
      }
    } else {
      if (data.caller_type === 'room') {
        console.log('[App] 呼叫方是房间（硬件），开启原始音频流捕获')
        connectionState.value = 'connected'
        appStore.setCallState({ connectionState: 'connected' })
        await startAudioCapture(data.call_id, data.caller_type, data.caller_id)
      } else {
        if (peerConnection.value) {
          console.log('[WebRTC] 被叫方连接已存在，等待 Offer...')
        } else if (pendingOffer.value && pendingOffer.value.call_id === data.call_id) {
          console.log('[WebRTC] 被叫方发现待处理 offer，初始化连接')
          await initWebRTC(data.call_id, targetType, targetId)
        } else {
          console.log('[WebRTC] 被叫方就绪，等待 Offer...')
        }
      }
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
  socket.off('audio_chunk')

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
  socket.on('audio_chunk', (data: { call_id: string, chunk: ArrayBuffer }) => {
    if (appStore.currentCall && appStore.currentCall.call_id === data.call_id) {
      playAudioChunk(data.chunk)
    }
  })
}

const fetchSystemConfigs = async () => {
  try {
    const res = await systemConfigApi.getAllConfigs()
    if (res.data) {
      appStore.setSystemConfigs(res.data)
    }
  } catch (error) {
    console.error('[App] 获取系统配置失败:', error)
  }
}

onMounted(() => {
  appStore.initUserInfo() // 确保 userInfo 加载
  // 只有已登录用户才获取系统配置
  if (localStorage.getItem('auth_token')) {
    fetchSystemConfigs() // 获取系统全局配置
    setupGlobalWebSocket()
  }
})

onUnmounted(() => {
  cleanupWebRTC()
  if (durationTimer.value) {
    clearInterval(durationTimer.value)
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

  /* 统一通话 Modal 样式 */
  .unified-call-modal .ant-modal-content {
    border-radius: 20px;
    overflow: hidden;
    padding: 0;
  }
  
  .call-content-modal {
    padding: 32px 24px;
    text-align: center;
  }
  
  .call-header-modal {
    margin-bottom: 24px;
  }
  
  .caller-avatar {
    width: 80px;
    height: 80px;
    background: #e6f7ff;
    color: #1890ff;
    border-radius: 50%;
    margin: 0 auto 16px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 40px;
  }
  
  .call-header-modal h3 {
    margin: 0 0 8px;
    font-size: 22px;
    font-weight: 600;
  }
  
  .call-status-tag {
    display: inline-block;
    padding: 4px 12px;
    border-radius: 12px;
    font-size: 13px;
    background: #f5f5f5;
    color: #8c8c8c;
  }
  
  .call-status-tag.connected {
    background: #f6ffed;
    color: #52c41a;
  }
  
  .call-status-tag.connecting {
    background: #fffbe6;
    color: #faad14;
  }
  
  .duration-display {
    font-size: 56px;
    font-weight: 700;
    font-family: 'SF Pro Display', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    margin-bottom: 40px;
    color: #1a1a1a;
    letter-spacing: -1px;
  }
  
  .voice-waves-container {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 30px 20px;
    background: linear-gradient(145deg, #f0f2f5, #ffffff);
    border-radius: 24px;
    margin-bottom: 40px;
    box-shadow: inset 0 2px 10px rgba(0,0,0,0.05);
    height: 120px;
  }

  .voice-wave-side {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
    flex: 1;
  }

  .wave-bars {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 3px;
    height: 60px;
  }

  .wave-bar {
    width: 4px;
    border-radius: 2px;
    background: #bfbfbf;
    transition: all 0.15s cubic-bezier(0.4, 0, 0.2, 1);
  }

  .local .wave-bar { background: #52c41a; }
  .remote .wave-bar { background: #1890ff; }

  .voice-wave-side:not(.speaking) .wave-bar {
    background: #d9d9d9 !important;
    height: 4px !important;
  }

  .wave-label {
    font-size: 12px;
    color: #8c8c8c;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 1px;
  }

  .wave-divider {
    width: 40px;
    display: flex;
    justify-content: center;
  }

  .pulse-center {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #d9d9d9;
    position: relative;
  }

  .pulse-center.connected {
    background: #52c41a;
    box-shadow: 0 0 0 0 rgba(82, 196, 26, 0.4);
    animation: pulse-green 2s infinite;
  }

  @keyframes pulse-green {
    0% { box-shadow: 0 0 0 0 rgba(82, 196, 26, 0.4); }
    70% { box-shadow: 0 0 0 10px rgba(82, 196, 26, 0); }
    100% { box-shadow: 0 0 0 0 rgba(82, 196, 26, 0); }
  }
  
  .call-footer-modal .modal-action-buttons {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  
  .hangup-btn-large {
    height: 50px;
    font-size: 18px;
  }
  
  /* 悬浮窗迷你指示器 */
  .mini-audio-indicators {
    display: flex;
    justify-content: center;
    gap: 8px;
    margin-bottom: 12px;
    height: 50px;
    align-items: flex-end;
    padding-bottom: 5px;
    background: #f5f5f5;
    border-radius: 8px;
  }
  
  .mini-level-bar {
    width: 8px;
    border-radius: 4px;
    transition: height 0.1s ease;
    min-height: 4px;
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
