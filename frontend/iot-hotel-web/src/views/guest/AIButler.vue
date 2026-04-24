<template>
  <div class="ai-butler-page" @click="handlePageClick">
    <!-- 顶部状态栏 -->
    <div class="status-bar">
      <div class="hotel-info">
        <span class="hotel-name">{{ currentHotelName }}</span>
      </div>
      <div class="room-info">
        <HomeOutlined />
        <a-select
          v-if="roomList.length > 1"
          v-model:value="roomId"
          class="room-selector"
          @change="handleRoomChange"
          size="small"
          :bordered="false"
          :dropdown-style="{ minWidth: '100px' }"
        >
          <a-select-option v-for="room in roomList" :key="room" :value="room">
            房间 {{ room }}
          </a-select-option>
        </a-select>
        <span v-else>房间 {{ roomId }}</span>
      </div>
      <div class="connection-status" :class="{ online: isConnected }">
        <WifiOutlined />
        <span>{{ isConnected ? '已连接' : '连接中...' }}</span>
      </div>
      <div class="front-desk-status" :class="{ online: frontDeskCount > 0 }">
        <CustomerServiceOutlined />
        <span>前台{{ frontDeskCount > 0 ? `在线(${frontDeskCount})` : '离线' }}</span>
      </div>
    </div>

    <!-- 主内容区 -->
    <div class="main-content">
      <!-- AI形象 -->
      <div class="ai-avatar-container" :class="{ listening: isListening, speaking: isSpeaking, thinking: isLoading }">
        <div class="ai-avatar">
          <LoadingOutlined v-if="isLoading" spin />
          <RobotOutlined v-else />
        </div>
        <div class="voice-waves" v-if="isListening || isSpeaking">
          <span v-for="i in 5" :key="i" :style="{ animationDelay: `${i * 0.1}s` }"></span>
        </div>
        <!-- 思考中的脉冲动画 -->
        <div class="thinking-pulse" v-if="isLoading"></div>
      </div>

      <!-- 对话内容 -->
      <div class="chat-container" ref="chatContainer">
        <div v-if="messages.length === 0" class="welcome-message">
          <h2>您好，我是AI管家小智</h2>
          <p>我可以帮您控制房间设备、查询信息、安排服务</p>
          <p class="example-text">试试问我："打开灯光"、"需要保洁"、"WiFi密码是多少"</p>
        </div>
        
        <div v-else class="messages">
          <div 
            v-for="(msg, index) in messages" 
            :key="index"
            class="message"
            :class="msg.type"
          >
            <div class="message-content">
              <span class="avatar">
                <UserOutlined v-if="msg.type === 'user'" />
                <RobotOutlined v-else />
              </span>
              <div class="bubble-wrapper">
                <!-- 打字机效果：显示已打出的文字 + 光标 -->
                <div 
                  class="bubble" 
                  :class="{ 
                    'with-audio': msg.type === 'ai',
                    'typing': msg.typing && isTyping && index === messages.length - 1
                  }"
                >
                  <template v-if="msg.typing && isTyping && index === messages.length - 1">
                    {{ displayedText }}<span class="cursor">|</span>
                  </template>
                  <template v-else>
                    {{ msg.text }}
                  </template>
                </div>
                
                <!-- AI消息的语音控制按钮 -->
                <div v-if="msg.type === 'ai' && index === messages.length - 1 && isPlayingAudio" class="audio-indicator">
                  <SoundOutlined :spin="isPlayingAudio" />
                  <span>正在播放...</span>
                  <a-button type="link" size="small" @click="toggleAudio">
                    {{ isPlayingAudio ? '暂停' : '播放' }}
                  </a-button>
                </div>
              </div>
            </div>
            <div class="message-time">{{ msg.time }}</div>
          </div>
          
          <!-- 智能建议（最后一条AI消息后显示） -->
          <div v-if="suggestions.length > 0 && !isLoading && !isTyping" class="suggestions">
            <span class="suggestion-label">💡 您可能还想问：</span>
            <div class="suggestion-chips">
              <span 
                v-for="(suggestion, sIdx) in suggestions.slice(0, 3)" 
                :key="sIdx"
                class="suggestion-chip"
                @click="handleQuickAction(suggestion)"
              >
                {{ suggestion }}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 底部控制区 - 文字+语音输入 -->
    <div class="input-area">
      <!-- 快捷功能按钮 -->
      <div class="quick-chips" v-if="messages.length === 0">
        <span 
          v-for="chip in quickChips" 
          :key="chip.text"
          class="chip"
          @click="handleQuickAction(chip.text)"
        >
          {{ chip.icon }} {{ chip.label }}
        </span>
      </div>
      
      <!-- 语音输入中提示 -->
      <div v-if="isListening" class="voice-input-status">
        <div class="voice-waves-large">
          <span v-for="i in 7" :key="i" :style="{ animationDelay: `${i * 0.1}s` }"></span>
        </div>
        <p class="voice-hint">正在聆听...</p>
        <p class="voice-sub-hint">松开结束语音输入</p>
        <!-- 停止语音输入按钮 -->
        <a-button
          type="primary"
          size="large"
          class="stop-voice-btn"
          @click="stopListening"
        >
          <PauseCircleOutlined />
          <span>停止录音</span>
        </a-button>
      </div>
      
      <!-- 输入框 -->
      <div class="input-box" v-show="!isListening">
        <a-input
          v-model:value="userInput"
          :placeholder="isLoading ? 'AI正在思考中...' : '输入您的问题，如：打开灯光、需要保洁、查询WiFi...'"
          :disabled="isLoading"
          size="large"
          @pressEnter="sendMessage"
          allow-clear
        >
          <template #prefix>
            <EditOutlined style="color: #999;" />
          </template>
        </a-input>
        
        <!-- 发送按钮 -->
        <a-button 
          type="primary" 
          size="large"
          class="send-btn"
          :loading="isLoading"
          :disabled="!userInput.trim() || isLoading"
          @click="sendMessage"
        >
          <SendOutlined />
        </a-button>
        
        <!-- 语音输入大按钮 -->
        <a-button 
          shape="circle" 
          size="large"
          class="voice-btn-large"
          :class="{ 
            listening: isListening, 
            'voice-btn-disabled': !microphonePermission 
        }"
          @mousedown="microphonePermission ? startListening() : requestMicrophonePermission()"
          @mouseup="microphonePermission ? stopListening() : null"
          @mouseleave="microphonePermission ? stopListening() : null"
          @touchstart="microphonePermission ? startListening() : requestMicrophonePermission()"
          @touchend="microphonePermission ? stopListening() : null"
          :title="microphonePermission ? '按住说话' : '点击启用麦克风'"
        >
          <AudioOutlined v-if="microphonePermission" />
          <AudioMutedOutlined v-else />
        </a-button>
      </div>
      
      <!-- 提示文字 -->
      <p class="hint-text" v-show="!isListening">
        {{ isLoading ? `正在为您${currentAction}...` : '按 Enter 发送，或按住麦克风使用语音' }}
      </p>
    </div>

    <!-- 转接中弹窗 -->
    <a-modal
      v-model:open="transferModal.visible"
      :footer="null"
      :closable="false"
      :maskClosable="false"
      centered
      width="320px"
      class="transfer-modal"
    >
      <div class="transfer-content">
        <!-- 转接中动画 -->
        <div v-if="transferModal.step === 'calling'" class="phone-animation">
          <div class="pulse-ring"></div>
          <div class="pulse-ring"></div>
          <div class="pulse-ring"></div>
          <PhoneOutlined class="phone-icon" />
        </div>
        
        <!-- 连接中动画 -->
        <div v-if="transferModal.step === 'connecting'" class="connecting-animation">
          <div class="connecting-spinner"></div>
          <CheckCircleOutlined class="connecting-icon" />
        </div>
        
        <h3>{{ transferModal.statusText }}</h3>
        <p class="status-desc">{{ transferModal.statusDesc }}</p>
        
        <!-- 进度指示器 -->
        <div class="transfer-progress">
          <div class="progress-step" :class="{ active: transferModal.step === 'calling', completed: transferModal.step !== 'calling' }">
            <div class="step-dot">1</div>
            <span class="step-text">呼叫前台</span>
          </div>
          <div class="progress-line" :class="{ completed: transferModal.step !== 'calling' }"></div>
          <div class="progress-step" :class="{ active: transferModal.step === 'connecting' }">
            <div class="step-dot">2</div>
            <span class="step-text">建立连接</span>
          </div>
        </div>
        
        <div class="transfer-info" v-if="transferModal.frontDeskCount > 0">
          <span class="online-badge">●</span>
          <span>{{ transferModal.frontDeskCount }}位前台在线</span>
        </div>
        
        <div class="transfer-actions">
          <a-button type="primary" danger shape="round" size="large" block @click="cancelTransfer">
            <CloseOutlined /> {{ transferModal.step === 'calling' ? '取消呼叫' : '结束通话' }}
          </a-button>
        </div>
      </div>
    </a-modal>

    <!-- 通话中弹窗 -->
    <a-modal
      v-model:open="callModal.visible"
      :footer="null"
      :closable="false"
      :maskClosable="false"
      centered
      width="340px"
      class="call-modal"
    >
      <div class="call-content-modal">
        <div class="call-header-modal">
          <div class="caller-avatar">
            <CustomerServiceOutlined />
          </div>
          <h3>{{ callModal.callerName }}</h3>
          <div class="call-status-tag" :class="callModal.connectionState">
            {{ callModal.connectionStateText }}
          </div>
        </div>

        <div class="call-body-modal">
          <div class="duration-display">{{ callModal.duration }}</div>
          
          <!-- 音频波形/电平指示 -->
          <div class="audio-visualizer">
            <div class="visualizer-item">
              <span class="vis-label">您的声音</span>
              <div class="level-meter">
                <div class="level-bar" :style="{ width: callModal.inputVolume + '%', background: callModal.localSpeaking ? '#52c41a' : '#bfbfbf' }"></div>
              </div>
            </div>
            <div class="visualizer-item">
              <span class="vis-label">前台声音</span>
              <div class="level-meter">
                <div class="level-bar" :style="{ width: callModal.outputVolume + '%', background: callModal.remoteSpeaking ? '#1890ff' : '#bfbfbf' }"></div>
              </div>
            </div>
          </div>
        </div>

        <div class="call-footer-modal">
          <a-button type="primary" danger shape="round" size="large" block @click="hangupCall">
            <template #icon><CloseOutlined /></template> 挂断
          </a-button>
        </div>
      </div>
    </a-modal>

    <!-- 工单详情弹窗 -->
    <a-modal
      v-model:open="ticketModal.visible"
      :footer="null"
      centered
      width="340px"
      class="ticket-modal"
      title="服务请求详情"
    >
      <div class="ticket-detail">
        <div class="ticket-header">
          <CheckCircleOutlined class="success-icon" />
          <h3>请求已提交</h3>
        </div>
        <div class="ticket-info">
          <div class="info-item">
            <span class="label">工单单号:</span>
            <span class="value">{{ ticketModal.data.ticketNo }}</span>
          </div>
          <div class="info-item">
            <span class="label">服务类型:</span>
            <span class="value">{{ ticketModal.data.type }}</span>
          </div>
          <div class="info-item">
            <span class="label">房间号码:</span>
            <span class="value">{{ ticketModal.data.roomNumber }}</span>
          </div>
          <div class="info-item">
            <span class="label">服务描述:</span>
            <span class="value">{{ ticketModal.data.description }}</span>
          </div>
          <div class="info-item">
            <span class="label">紧急程度:</span>
            <span class="value" :class="{ 'urgent-text': ticketModal.data.urgency !== '普通' }">{{ ticketModal.data.urgency }}</span>
          </div>
          <div class="info-item">
            <span class="label">创建时间:</span>
            <span class="value">{{ ticketModal.data.createdAt }}</span>
          </div>
        </div>
        <div class="ticket-footer">
          <p>工作人员将尽快为您处理</p>
          <a-button type="primary" block @click="ticketModal.visible = false">知道了</a-button>
        </div>
      </div>
    </a-modal>

    <!-- 远程音频元素 -->
    <audio ref="remoteAudioRef" autoplay style="display: none;"></audio>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import { $notify, NotifyPreset } from '@/utils/notify'
import {
  RobotOutlined,
  HomeOutlined,
  WifiOutlined,
  AudioOutlined,
  AudioMutedOutlined,
  PauseCircleOutlined,
  LoadingOutlined,
  UserOutlined,
  CustomerServiceOutlined,
  ToolOutlined,
  PhoneOutlined,
  CloseOutlined,
  CheckCircleOutlined,
  BulbOutlined,
  ThunderboltOutlined,
  ClearOutlined,
  CoffeeOutlined,
  SendOutlined,
  EditOutlined,
  SoundOutlined
} from '@ant-design/icons-vue'
import { useRoute, useRouter } from 'vue-router'
import { getSocket, initWebSocket as initWebSocketFromUtil } from '@/utils/websocket'
import request from '@/api/request'
import { now } from '@/utils/date'

const route = useRoute()
const router = useRouter()
const roomId = ref(route.query.room as string || '101')
const roomList = ref<string[]>([]) // 房间列表（一客多房）
const frontDeskCount = ref(0) // 在线前台数量
const currentHotelName = ref('智联酒店') // 当前酒店名称

// 状态
const isConnected = ref(false)
const isListening = ref(false)
const isSpeaking = ref(false)
const isLoading = ref(false)  // AI处理中的加载状态
const currentAction = ref('')   // 当前正在执行的操作
const userInput = ref('')       // 用户输入的文字
const microphonePermission = ref(false)
const messages = ref<{ type: 'user' | 'ai'; text: string; time: string; typing?: boolean }[]>([])
const chatContainer = ref<HTMLElement>()
const isTyping = ref(false)      // 打字机效果状态
const displayedText = ref('')     // 当前显示的文字（打字机用）
const suggestions = ref<string[]>([])  // 智能建议

// 快捷功能标签
const quickChips = [
  { icon: '💡', label: '开灯', text: '打开灯光' },
  { icon: '🏠', label: '房间状态', text: '查询房间状态' },
  { icon: '🧹', label: '保洁', text: '需要保洁服务' },
  { icon: '☕', label: '送餐', text: '需要送餐服务' },
  { icon: '📶', label: 'WiFi密码', text: '查询酒店WiFi密码' },
  { icon: '👨‍💼', label: '转人工', text: '转接人工' }
]

// 智能建议映射（根据上下文推荐）
const suggestionMap: Record<string, string[]> = {
  '灯光': ['调暗一点', '关闭灯光', '打开所有灯'],
  '空调': ['调到26度', '开启制冷模式', '关闭空调'],
  '保洁': ['现在就来', '1小时后', '只整理床铺'],
  '送餐': ['查看菜单', '30分钟后送达', '素食套餐'],
  'WiFi': ['连接不上怎么办', '密码是什么', '网速太慢'],
  '维修': ['空调不制冷', '水管漏水', '电视没信号'],
  '默认': ['还需要什么帮助？', '查询酒店设施', '叫醒服务']
}

// 转接弹窗
const transferModal = ref({
  visible: false,
  step: 'calling', // 'calling' | 'connecting'
  statusText: '正在为您转接前台...',
  statusDesc: '正在呼叫前台，请稍候...',
  frontDeskCount: 0,
  callId: ''
})

// 通话中弹窗
const callModal = ref({
  visible: false,
  callerName: '前台',
  duration: '00:00',
  connectionState: 'connecting',
  connectionStateText: '连接中',
  statusText: '正在建立连接...',
  localSpeaking: false,
  remoteSpeaking: false,
  inputVolume: 0,
  outputVolume: 0,
  callId: ''
})

// 工单详情弹窗
const ticketModal = ref({
  visible: false,
  data: {
    ticketNo: '',
    type: '',
    description: '',
    urgency: '',
    roomNumber: '',
    createdAt: ''
  }
})

// 通话计时器
const durationTimer = ref<NodeJS.Timeout | null>(null)
const callStartTime = ref<number | null>(null)
const remoteAudioRef = ref<HTMLAudioElement | null>(null)

// WebRTC相关
let peerConnection: RTCPeerConnection | null = null
let localStream: MediaStream | null = null
const pendingIceCandidates: RTCIceCandidateInit[] = []

// WebSocket
let socket: any = null

// 语音识别
let recognition: any = null
let recognitionTimeout: any = null
let isRecognitionActive = false

onMounted(() => {
  initWebSocket()
  initSpeechRecognition()
  verifyAccess()
  
  // 尝试自动获取麦克风权限
  requestMicrophonePermission()
})

onUnmounted(() => {
  if (socket) {
    socket.off('connect', handleConnect)
    socket.off('disconnect', handleDisconnect)
    socket.off('incoming_call', handleIncomingCall)
    socket.off('call_initiated', handleCallInitiated)
    socket.off('call_answered', handleCallAnswered)
    socket.off('call_rejected', handleCallRejected)
    socket.off('call_hungup', handleCallHungup)
    socket.off('webrtc_offer', handleWebRTCOffer)
    socket.off('webrtc_answer', handleWebRTCAnswer)
    socket.off('webrtc_ice_candidate', handleWebRTCIceCandidate)
    socket.off('online_status', handleOnlineStatus)
    // BUG-056修复：断开WebSocket连接
    socket.disconnect()
  }
})

function registerAsRoom() {
  if (socket && socket.connected) {
    console.log(`[AIButler] 注册为房间客户端: room/${roomId.value}`)
    socket.emit('register_client', {
      clientType: 'room',
      clientId: roomId.value
    })
  }
}

// 初始化WebSocket
function initWebSocket() {
  const existingSocket = getSocket()
  if (!existingSocket) {
    console.warn('[AIButler] WebSocket未初始化，尝试初始化...')
    initWebSocketFromUtil()
  }

  socket = getSocket()
  if (!socket) {
    console.error('[AIButler] 无法获取WebSocket连接')
    return
  }

  isConnected.value = socket.connected

  if (socket.connected) {
    registerAsRoom()
  }

  socket.on('connect', handleConnect)
  socket.on('disconnect', handleDisconnect)
  socket.on('online_status', handleOnlineStatus)
  socket.on('incoming_call', handleIncomingCall)
  socket.on('call_initiated', handleCallInitiated)
  socket.on('call_answered', handleCallAnswered)
  socket.on('webrtc_offer', handleWebRTCOffer)
  socket.on('webrtc_answer', handleWebRTCAnswer)
  socket.on('webrtc_ice_candidate', handleWebRTCIceCandidate)
  socket.on('call_rejected', handleCallRejected)
  socket.on('call_hungup', handleCallHungup)
}

function handleConnect() {
  console.log('[AIButler] WebSocket已连接')
  isConnected.value = true
  registerAsRoom()
}

function handleDisconnect() {
  console.log('[AIButler] WebSocket已断开')
  isConnected.value = false
}

function handleOnlineStatus(data: any) {
  if (data.rooms && Array.isArray(data.rooms)) {
    const isOnline = data.rooms.some((r: any) => String(r.id) === String(roomId.value) || r.id === roomId.value)
    if (isOnline && !isConnected.value && socket?.connected) {
      isConnected.value = true
    }
  }
  if (data.web && Array.isArray(data.web)) {
    frontDeskCount.value = data.web.filter((w: any) => w.isOnDuty).length || data.web.length
  }
}

function handleIncomingCall(data: any) {
  console.log('[AIButler] 收到来电:', data)
  transferModal.value.visible = true
  transferModal.value.callId = data.call_id
  if (!data.isTransfer) {
    transferModal.value.statusText = '来电...'
    transferModal.value.statusDesc = `来自${data.caller_type === 'front_desk' ? '前台' : data.caller_id}的呼叫`
  }
}

function handleCallInitiated(data: any) {
  console.log('[AIButler] 收到call_initiated:', data)
  // 关键修复：当AI转接发起通话时，后端会发送此事件
  // 我们需要保存callId以便后续匹配call_answered事件
  if (data.call_id) {
    transferModal.value.callId = data.call_id
    console.log('[AIButler] 已保存callId:', data.call_id)
  }
}

function handleCallAnswered(data: any) {
  console.log('[AIButler] 收到call_answered:', data)
  console.log('[AIButler] 当前transferModal.callId:', transferModal.value.callId)
  
  if (!transferModal.value.callId && data.call_id) {
    console.log('[AIButler] 恢复callId:', data.call_id)
    transferModal.value.callId = data.call_id
  }
  
  if (data.call_id === transferModal.value.callId) {
    console.log('[AIButler] callId匹配，更新UI')
    transferModal.value.step = 'connecting'
    transferModal.value.statusText = '前台已接听'
    transferModal.value.statusDesc = '正在建立语音连接...'
    $notify.success({ title: '前台已接听', description: '正在建立语音连接，请稍候 📞' })
    
    setTimeout(() => {
      transferModal.value.visible = false
      showCallModal(data.call_id)
      initWebRTC(data.call_id)
    }, 1500)
  } else {
    console.log('[AIButler] callId不匹配，忽略')
  }
}

async function handleWebRTCOffer(data: any) {
  console.log('[AIButler] 收到webrtc_offer:', data)
  console.log('[AIButler] 当前callModal.callId:', callModal.value.callId, 'transferModal.callId:', transferModal.value.callId)
  
  const currentCallId = callModal.value.callId || transferModal.value.callId
  if (data.call_id !== currentCallId) {
    console.log('[AIButler] call_id不匹配，忽略')
    return
  }
  
  if (!peerConnection) {
    console.log('[AIButler] peerConnection不存在，无法处理offer')
    return
  }
  
  try {
    await peerConnection.setRemoteDescription(new RTCSessionDescription(data.offer))
    console.log('[AIButler] 已设置remote description (offer)')
    
    const answer = await peerConnection.createAnswer()
    await peerConnection.setLocalDescription(answer)
    console.log('[AIButler] 已创建并设置local description (answer)')
    
    socket.emit('webrtc_answer', {
      target_type: 'front_desk',
      target_id: 'all',
      answer: answer,
      call_id: data.call_id
    })
    console.log('[AIButler] 已发送answer')
    
    processPendingIceCandidates()
  } catch (e) {
    console.error('[AIButler] 处理offer失败:', e)
  }
}

async function handleWebRTCAnswer(data: any) {
  console.log('[AIButler] 收到webrtc_answer:', data.call_id)
  if (data.call_id === callModal.value.callId && peerConnection) {
    try {
      await peerConnection.setRemoteDescription(new RTCSessionDescription(data.answer))
      console.log('[AIButler] 已设置remote description (answer)')
      processPendingIceCandidates()
    } catch (e) {
      console.error('[AIButler] 处理answer失败:', e)
    }
  }
}

async function handleWebRTCIceCandidate(data: any) {
  console.log('[AIButler] 收到ICE候选')
  if (data.call_id === callModal.value.callId && peerConnection) {
    try {
      if (peerConnection.remoteDescription) {
        await peerConnection.addIceCandidate(new RTCIceCandidate(data.candidate))
        console.log('[AIButler] 已添加ICE候选')
      } else {
        pendingIceCandidates.push(data.candidate)
        console.log('[AIButler] ICE候选已缓存')
      }
    } catch (e) {
      console.error('[AIButler] 添加ICE候选失败:', e)
    }
  }
}

function handleCallRejected(data: any) {
  if (data.call_id === transferModal.value.callId) {
    transferModal.value.statusText = '呼叫被拒绝'
    transferModal.value.statusDesc = '前台暂时无法接听，请稍后再试'
    $notify.warning({ title: '前台暂时无法接听', description: '请稍后再试或使用文字留言' })
    setTimeout(() => {
      transferModal.value.visible = false
      resetTransferModal()
    }, 3000)
  }
}

function handleCallHungup(data: any) {
  if (data.call_id === callModal.value.callId) {
    $notify.info({ title: '通话已结束', description: '与前台通话已结束' })
    closeCallModal()
  }
}

// 验证入住权限
async function verifyAccess() {
  try {
    const res: any = await request.post('/ai-butler/verify', {
      room_id: roomId.value
    })
    
    if (res.data?.code === 403) {
        $notify.error({ title: '无法使用AI管家', description: '该房间暂无入住记录，请先办理入住 🏨' })
      } else if (res.data?.data?.accessible) {
        $notify.success({ title: '欢迎', description: `${res.data.data.guestName}，我是您的AI管家小智 🤖` })
        // 更新酒店名称
        if (res.data.data.hotelName) {
          currentHotelName.value = res.data.data.hotelName
        }
        // 更新房间列表，支持一客多房切换
        if (res.data.data.roomList && res.data.data.roomList.length > 0) {
          roomList.value = res.data.data.roomList
        } else {
          roomList.value = [roomId.value]
        }
        // 更新前台在线数量
        frontDeskCount.value = res.data.data.frontDeskCount || 0
      }
  } catch (error) {
    console.error('验证失败:', error)
  }
}

// 切换房间（处理一客多房）
function handleRoomChange(newRoomId: string) {
  roomId.value = newRoomId
  // 更新URL查询参数，方便刷新后保持状态
  router.replace({ query: { ...route.query, room: newRoomId } })
  // 重新注册WebSocket
  if (socket && socket.connected) {
    socket.emit('register_client', {
      clientType: 'room',
      clientId: roomId.value
    })
  }
  // 清空当前对话（可选，这里选择清空以防混淆）
  messages.value = []
  $notify.success({ title: '已切换房间', description: `已切换到房间 ${newRoomId} 🏠` })
  // 重新验证权限并加载新房间状态
  verifyAccess()
}

// 初始化语音识别
function initSpeechRecognition() {
  const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition
  
  if (!SpeechRecognition) {
    $notify.warning({ title: '浏览器不支持', description: '您的浏览器不支持语音识别，请使用 Chrome 或 Edge 浏览器 🌐' })
    return
  }

  recognition = new SpeechRecognition()
  recognition.lang = 'zh-CN'
  recognition.continuous = false
  recognition.interimResults = true  // 启用中间结果，提供更好的反馈
  // maxAlternatives 默认为 1，足够；交给浏览器选最佳候选

  recognition.onstart = () => {
    isListening.value = true
    isRecognitionActive = true
    console.log('[语音识别] 开始聆听')

    // 录音前若 AI 还在播放上一段语音，先暂停，避免回授被识别
    if (audioPlayer.value && !audioPlayer.value.paused) {
      audioPlayer.value.pause()
      audioPlayer.value.currentTime = 0
      isPlayingAudio.value = false
    }

    // 设置最大聆听时间（15 秒，覆盖较长的请求）
    recognitionTimeout = setTimeout(() => {
      if (isRecognitionActive) {
        console.log('[语音识别] 达到最大聆听时间，自动停止')
        stopListening()
      }
    }, 15000)
  }

  recognition.onend = () => {
    isListening.value = false
    isRecognitionActive = false
    
    // 清除超时定时器
    if (recognitionTimeout) {
      clearTimeout(recognitionTimeout)
      recognitionTimeout = null
    }
    
    console.log('[语音识别] 聆听结束')
  }

  recognition.onresult = (event: any) => {
    let finalTranscript = ''
    let interimTranscript = ''

    for (let i = event.resultIndex; i < event.results.length; i++) {
      const transcript = event.results[i][0].transcript
      if (event.results[i].isFinal) {
        finalTranscript += transcript
      } else {
        interimTranscript += transcript
      }
    }

    // 有最终结果：先停止录音，再走与文字输入完全一致的 AI 链路（避免出现「识别出文字但 AI 不回应」）
    if (finalTranscript) {
      const said = finalTranscript.trim()
      console.log('[语音识别] 识别结果:', said)
      stopListening()
      // 清空临时显示在输入框的中间结果
      userInput.value = ''

      if (said) {
        // 走 handleQuickAction 同一通道：会插入用户气泡 + 加载提示 + 调用 sendToAI
        // 这样即可保证识别完成后 AI 一定会回答并走 TTS。
        handleQuickAction(said)
      }
    } else if (interimTranscript) {
      userInput.value = interimTranscript
      console.log('[语音识别] 临时结果:', interimTranscript)
    }
  }

  recognition.onerror = (event: any) => {
    console.error('[语音识别] 错误:', event.error)
    isListening.value = false
    isRecognitionActive = false
    
    // 清除超时定时器
    if (recognitionTimeout) {
      clearTimeout(recognitionTimeout)
      recognitionTimeout = null
    }
    
    // 根据错误类型显示不同提示
    switch (event.error) {
      case 'no-speech':
        $notify.info({ title: '未检测到语音', description: '没有检测到语音输入，请再试一次 🎤' })
        break
      case 'audio-capture':
        $notify.error({ title: '麦克风访问失败', description: '无法访问麦克风，请检查设备连接 🎤' })
        break
      case 'not-allowed':
        $notify.error({ title: '权限被拒绝', description: '麦克风权限被拒绝，请在浏览器设置中允许 🔒' })
        microphonePermission.value = false
        break
      case 'network':
        NotifyPreset.networkError()
        break
      default:
        NotifyPreset.operationFailed('语音识别失败，请重试')
    }
  }
}

// 开始监听
function startListening() {
  if (!recognition) {
    $notify.warning({ title: '语音识别未初始化', description: '请刷新页面后重试 🔄' })
    return
  }
  
  // 如果已经在监听，先停止
  if (isRecognitionActive) {
    try {
      recognition.stop()
    } catch (e) {
      // 忽略停止错误
    }
    // 稍微延迟后重新启动，确保状态重置
    setTimeout(() => doStartListening(), 100)
  } else {
    doStartListening()
  }
}

function doStartListening() {
  // 开始识别前，停止所有可能正在播放的AI语音，避免声音回授被识别
  // 同时清空播放队列，避免上一段未播完的音频之后再继续播放干扰新对话
  audioQueue.length = 0
  if (audioPlayer.value) {
    try { audioPlayer.value.pause() } catch { /* ignore */ }
    audioPlayer.value.currentTime = 0
    isPlayingAudio.value = false
  }

  try {
    recognition.start()
  } catch (e: any) {
    console.error('[语音识别] 启动失败:', e)
    if (e.name === 'NotAllowedError') {
      $notify.error({ title: '权限被拒绝', description: '麦克风权限被拒绝，请在浏览器设置中允许访问 🔒' })
      microphonePermission.value = false
    } else {
      NotifyPreset.operationFailed('语音识别启动失败')
    }
    isListening.value = false
    isRecognitionActive = false
  }
}

// 停止监听
function stopListening() {
  if (recognition && isRecognitionActive) {
    try {
      recognition.stop()
      console.log('[语音识别] 手动停止')
    } catch (e) {
      console.error('[语音识别] 停止失败:', e)
    }
  }
  
  // 清除超时定时器
  if (recognitionTimeout) {
    clearTimeout(recognitionTimeout)
    recognitionTimeout = null
  }
}

// 处理用户输入
async function handleUserInput(text: string) {
  // 添加到消息列表
  messages.value.push({
    type: 'user',
    text,
    time: now().format('HH:mm')
  })
  
  scrollToBottom()

  // 检查唤醒词
  if (text.includes('小智') || text.includes('管家')) {
    // 发送给AI处理
    await sendToAI(text)
  } else if (text.includes('转人工') || text.includes('前台')) {
    await sendToAI(text)
  } else {
    // 未唤醒，提示用户
    messages.value.push({
      type: 'ai',
      text: '请说"小智小智"唤醒我，或者点击下方的快捷按钮',
      time: now().format('HH:mm')
    })
    scrollToBottom()
  }
}

// 打字机效果
function typeWriterEffect(text: string, callback?: () => void) {
  isTyping.value = true
  displayedText.value = ''
  let index = 0
  
  const typeChar = () => {
    if (index < text.length) {
      displayedText.value += text.charAt(index)
      index++
      scrollToBottom()
      setTimeout(typeChar, 30 + Math.random() * 20) // 随机速度，更自然
    } else {
      isTyping.value = false
      if (callback) callback()
    }
  }
  
  typeChar()
}

// 更新智能建议
function updateSuggestions(lastUserMessage: string) {
  let matchedKey = '默认'
  
  for (const key of Object.keys(suggestionMap)) {
    if (lastUserMessage.includes(key)) {
      matchedKey = key
      break
    }
  }
  
  suggestions.value = suggestionMap[matchedKey] || suggestionMap['默认']
}

// 发送文字消息
async function sendMessage() {
  const text = userInput.value.trim()
  if (!text || isLoading.value) return
  
  userInput.value = ''
  await handleQuickAction(text)
}

// 快捷操作
async function handleQuickAction(text: string) {
  // 显示用户消息
  messages.value.push({
    type: 'user',
    text,
    time: now().format('HH:mm')
  })
  scrollToBottom()
  
  // 设置加载状态
  isLoading.value = true
  currentAction.value = text
  
  // 添加"正在处理"提示
  messages.value.push({
    type: 'ai',
    text: `⏳ 正在为您${text}...`,
    time: now().format('HH:mm')
  })
  scrollToBottom()
  
  try {
    await sendToAI(text)
  } finally {
    isLoading.value = false
    currentAction.value = ''
  }
}

// 发送给AI处理
async function sendToAI(text: string) {
  try {
    isSpeaking.value = true
    
    const res: any = await request.post('/ai-butler/chat', {
      room_id: roomId.value,
      text: text,
      session_id: `${roomId.value}_${Date.now()}`
    })

    if (res.code === 200) {
      const aiResponse = res.data
      
      // 移除"正在处理"的提示消息（保留最后一条）
      const loadingMsgIndex = messages.value.findIndex(m => m.text.startsWith('⏳ 正在为您'))
      if (loadingMsgIndex !== -1) {
        messages.value.splice(loadingMsgIndex, 1)
      }
      
      const aiText = aiResponse.text || '抱歉，我没有理解您的意思，请换个说法试试？'

      messages.value.push({
        type: 'ai',
        text: aiText,
        time: now().format('HH:mm'),
        typing: true
      })

      typeWriterEffect(aiText, () => {
        updateSuggestions(text)

        const lastMsg = messages.value[messages.value.length - 1]
        if (lastMsg) {
          lastMsg.typing = false
        }

        if (aiResponse.audioUrl) {
          playAudio(aiResponse.audioUrl)
        }
      })
      
      scrollToBottom()

      // 如果有工单详情，弹出弹窗
      if (aiResponse.ticketData) {
        setTimeout(() => {
          ticketModal.value.data = aiResponse.ticketData
          ticketModal.value.visible = true
        }, 1500) // 等待打字机效果开始后弹出
      }

      // 如果需要转接
      if (aiResponse.action === 'transfer') {
        setTimeout(() => {
          transferModal.value.visible = true
          transferModal.value.statusText = '正在为您转接前台...'
          transferModal.value.statusDesc = '正在呼叫前台，请稍候...'
          transferModal.value.frontDeskCount = aiResponse.frontDeskCount || 0
          transferModal.value.callId = aiResponse.callId || ''
          
          messages.value.push({
            type: 'ai',
            text: `📞 正在为您转接前台...${aiResponse.frontDeskCount ? `（${aiResponse.frontDeskCount}位前台在线）` : ''}`,
            time: now().format('HH:mm')
          })
          scrollToBottom()
        }, 1000)
      }
    } else {
      throw new Error(res.data?.message || 'AI服务返回异常')
    }
  } catch (error) {
    console.error('AI请求失败:', error)
    
    // 移除加载提示
    const loadingMsgIndex = messages.value.findIndex(m => m.text.startsWith('⏳ 正在为您'))
    if (loadingMsgIndex !== -1) {
      messages.value.splice(loadingMsgIndex, 1)
    }
    
    // 添加友好的错误消息
    messages.value.push({
      type: 'ai',
      text: '🤔 我好像遇到了点问题，不过您可以继续问我其他问题哦~',
      time: now().format('HH:mm')
    })
    scrollToBottom()
  } finally {
    isSpeaking.value = false
  }
}

// 请求麦克风权限
async function requestMicrophonePermission() {
  // 检查是否已经有权限
  if (microphonePermission.value) {
    return
  }
  
  try {
    // 检查浏览器是否支持 getUserMedia
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      $notify.warning({ title: '浏览器不支持', description: '您的浏览器不支持语音输入功能 🌐' })
      return
    }
    
    // 请求麦克风权限
    const stream = await navigator.mediaDevices.getUserMedia({ 
      audio: {
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true
      } 
    })
    
    // 立即释放流，只是测试权限
    stream.getTracks().forEach(track => track.stop())
    
    microphonePermission.value = true
    $notify.success({ title: '麦克风已就绪', description: '麦克风权限已获取，可以开始使用语音输入了 🎤' })
    
    // 如果是iOS Safari，需要用户交互后才能初始化语音识别
    if (/iPad|iPhone|iPod/.test(navigator.userAgent)) {
      $notify.info({ title: 'iOS提示', description: '请按住麦克风按钮开始语音对话 📱' })
    }
    
    console.log('[麦克风] 权限获取成功')
  } catch (error: any) {
    console.error('[麦克风] 权限获取失败:', error)
    microphonePermission.value = false
    
    // 显示详细的错误信息
    if (error instanceof DOMException) {
      switch (error.name) {
        case 'NotAllowedError':
        case 'PermissionDeniedError':
          $notify.error({ title: '权限被拒绝', description: '麦克风权限被拒绝，请点击麦克风图标重新授权 🔒' })
          break
        case 'NotFoundError':
        case 'DevicesNotFoundError':
          $notify.error({ title: '未找到麦克风', description: '未找到麦克风设备，请检查硬件连接 🎤' })
          break
        case 'NotReadableError':
        case 'TrackStartError':
          $notify.error({ title: '麦克风被占用', description: '麦克风被其他应用占用，请关闭其他使用麦克风的程序 🎤' })
          break
        default:
          $notify.error({ title: '麦克风权限获取失败', description: '无法获取麦克风权限，请检查浏览器设置 🔒' })
      }
    } else {
      $notify.error({ title: '麦克风权限获取失败', description: '无法获取麦克风权限，请检查浏览器设置 🔒' })
    }
  }
}

// 播放AI语音回复
const audioPlayer = ref<HTMLAudioElement | null>(null)
const isPlayingAudio = ref(false)

// 播放队列：保证多段 AI 回复按顺序完整播放，不会被新回复打断
const audioQueue: string[] = []
let isFlushingAudio = false

function enqueueAudio(base64Audio: string) {
  if (!base64Audio) {return}
  audioQueue.push(base64Audio)
  void flushAudioQueue()
}

async function flushAudioQueue() {
  if (isFlushingAudio) {return}
  isFlushingAudio = true
  try {
    while (audioQueue.length > 0) {
      const next = audioQueue.shift()!
      await playSingleAudio(next)
    }
  } finally {
    isFlushingAudio = false
  }
}

function playSingleAudio(base64Audio: string): Promise<void> {
  return new Promise((resolve) => {
    try {
      // 旧的 audio 仍在播则先等它结束（队列保证不会并发，这里只是兜底）
      if (audioPlayer.value && !audioPlayer.value.paused) {
        try { audioPlayer.value.pause() } catch { /* ignore */ }
      }

      const audio = new Audio(`data:audio/mp3;base64,${base64Audio}`)
      audioPlayer.value = audio
      isPlayingAudio.value = true

      let resolved = false
      const finish = () => {
        if (resolved) {return}
        resolved = true
        isPlayingAudio.value = false
        resolve()
      }

      audio.onended = () => {
        console.log('[AIButler] 语音段播放完成')
        finish()
      }

      audio.onerror = (e) => {
        console.error('[AIButler] 语音播放失败:', e)
        message.warning('语音播放失败，请检查音量设置')
        finish()
      }

      // 兜底：1MB 的 mp3 大约 60 秒，给 90 秒最大时长，防止 onended 漏触发卡死队列
      const safety = setTimeout(() => {
        if (!resolved) {
          console.warn('[AIButler] 播放安全超时，强制结束当前段')
          try { audio.pause() } catch { /* ignore */ }
          finish()
        }
      }, 90000)
      audio.onended = () => {
        clearTimeout(safety)
        console.log('[AIButler] 语音段播放完成')
        finish()
      }

      const playPromise = audio.play()
      if (playPromise !== undefined) {
        playPromise.then(() => {
          console.log('[AIButler] 语音段开始播放')
        }).catch((error) => {
          console.warn('[AIButler] 自动播放被阻止:', error)
          message.info('🔊 点击页面任意位置播放AI语音')
          const playOnce = () => {
            audio.play().then(() => {
              isPlayingAudio.value = true
            }).catch(() => finish())
          }
          // 一次性绑定页面点击触发播放，结束后由 onended/onerror 收尾
          document.addEventListener('click', playOnce, { once: true })
        })
      }
    } catch (e) {
      console.error('[AIButler] 创建音频对象失败:', e)
      isPlayingAudio.value = false
      resolve()
    }
  })
}

function playAudio(base64Audio: string) {
  // 兼容旧调用：实际走入队保证完整播放
  enqueueAudio(base64Audio)
}

// 手动停止/播放语音
function toggleAudio() {
  if (!audioPlayer.value) return
  
  if (isPlayingAudio.value) {
    audioPlayer.value.pause()
    isPlayingAudio.value = false
  } else {
    audioPlayer.value.play()
    isPlayingAudio.value = true
  }
}

// 取消转接
function cancelTransfer() {
  transferModal.value.visible = false
  // 挂断通话
  if (transferModal.value.callId) {
    socket?.emit('hangup_call', { call_id: transferModal.value.callId })
  }
  resetTransferModal()
}

// 重置转接弹窗状态
function resetTransferModal() {
  transferModal.value.step = 'calling'
  transferModal.value.statusText = '正在为您转接前台...'
  transferModal.value.statusDesc = '正在呼叫前台，请稍候...'
  transferModal.value.frontDeskCount = 0
  transferModal.value.callId = ''
}

// 显示通话弹窗
function showCallModal(callId: string) {
  callModal.value.visible = true
  callModal.value.callId = callId
  callModal.value.callerName = '前台工作人员'
  callModal.value.connectionState = 'connecting'
  callModal.value.connectionStateText = '连接中'
  callModal.value.statusText = '正在建立连接...'
  callModal.value.duration = '00:00'
  callStartTime.value = Date.now()
  
  // 开始计时
  durationTimer.value = setInterval(() => {
    if (callStartTime.value) {
      const elapsed = Math.floor((Date.now() - callStartTime.value) / 1000)
      const minutes = Math.floor(elapsed / 60).toString().padStart(2, '0')
      const seconds = (elapsed % 60).toString().padStart(2, '0')
      callModal.value.duration = `${minutes}:${seconds}`
    }
  }, 1000)
}

// 处理页面点击（用于解决自动播放策略）
async function handlePageClick() {
  // 如果正在通话中且音频被暂停，尝试恢复播放
  if (callModal.value.visible && remoteAudioRef.value) {
    if (remoteAudioRef.value.paused) {
      try {
        await remoteAudioRef.value.play()
        console.log('[AIButler] 用户交互后音频播放成功')
      } catch (e) {
        console.error('[AIButler] 播放失败:', e)
      }
    }
  }
}

// 挂断通话
function hangupCall() {
  if (callModal.value.callId) {
    socket?.emit('hangup_call', { call_id: callModal.value.callId })
  }
  closeCallModal()
}

// 关闭通话弹窗
function closeCallModal() {
  callModal.value.visible = false
  if (durationTimer.value) {
    clearInterval(durationTimer.value)
    durationTimer.value = null
  }
  // 关闭WebRTC连接
  if (peerConnection) {
    peerConnection.close()
    peerConnection = null
  }
  if (localStream) {
    localStream.getTracks().forEach(track => track.stop())
    localStream = null
  }
}

// 处理挂起的ICE候选
async function processPendingIceCandidates() {
  if (!peerConnection) return
  while (pendingIceCandidates.length > 0) {
    const candidate = pendingIceCandidates.shift()
    if (candidate) {
      try {
        await peerConnection.addIceCandidate(new RTCIceCandidate(candidate))
        console.log('[AIButler] 已添加挂起的ICE候选')
      } catch (e) {
        console.error('[AIButler] 添加挂起ICE候选失败:', e)
      }
    }
  }
}

// 更新连接状态
function updateConnectionStatus(state: string | undefined) {
  if (!state) return
  
  console.log('[AIButler] 更新连接状态:', state, '当前状态:', callModal.value.connectionState)
  
  if (state === 'connected' || state === 'completed') {
    // 使用Object.assign确保响应式更新
    Object.assign(callModal.value, {
      connectionState: 'connected',
      connectionStateText: '已连接',
      statusText: '通话中'
    })
    console.log('[AIButler] UI状态已更新为: 已连接/通话中')
  } else if (state === 'disconnected' || state === 'failed') {
    Object.assign(callModal.value, {
      connectionState: 'disconnected',
      connectionStateText: '已断开',
      statusText: '连接已断开'
    })
  } else if (state === 'connecting') {
    Object.assign(callModal.value, {
      connectionState: 'connecting',
      connectionStateText: '连接中',
      statusText: '正在建立连接...'
    })
  }
}

// 初始化WebRTC
async function initWebRTC(callId: string) {
  try {
    // 获取本地音频流（带错误处理）
    try {
      localStream = await navigator.mediaDevices.getUserMedia({ 
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true
        } 
      })
    } catch (mediaError) {
      console.error('[WebRTC] 获取麦克风失败:', mediaError)
      $notify.error({ title: '麦克风访问失败', description: '无法访问麦克风，请检查权限设置 🎤' })
      throw mediaError
    }
    
    // 创建RTCPeerConnection
    peerConnection = new RTCPeerConnection({
      iceServers: [{ urls: 'stun:stun.l.google.com:19302' }]
    })
    
    // 添加本地流
    localStream.getTracks().forEach(track => {
      peerConnection?.addTrack(track, localStream!)
    })
    
    // 监听ICE候选并发送
    peerConnection.onicecandidate = (event) => {
      if (event.candidate && socket) {
        console.log('[AIButler] 发送ICE候选:', event.candidate)
        // 广播给所有前台（集体呼叫模式）
        socket.emit('webrtc_ice_candidate', {
          target_type: 'front_desk',
          target_id: 'all',
          candidate: event.candidate,
          call_id: callId
        })
      }
    }
    
    // 监听远程流
    peerConnection.ontrack = (event) => {
      console.log('[AIButler] 收到远程流:', event.streams)
      
      if (event.streams && event.streams[0]) {
        const remoteStream = event.streams[0]
        console.log('[AIButler] 远程流轨道数:', remoteStream.getTracks().length)
        remoteStream.getTracks().forEach((track, i) => {
          console.log(`[AIButler] 远程轨道${i}:`, track.kind, track.enabled, track.muted)
        })
        
        // 使用audio元素播放
        if (remoteAudioRef.value) {
          remoteAudioRef.value.srcObject = remoteStream
          console.log('[AIButler] 已设置srcObject')
          
          // 尝试播放
          const playPromise = remoteAudioRef.value.play()
          if (playPromise !== undefined) {
            playPromise.then(() => {
              console.log('[AIButler] 远程音频播放成功')
            }).catch(e => {
              console.error('[AIButler] 播放远程音频失败:', e)
              // 如果是自动播放策略问题，尝试在用户交互后播放
              $notify.info({ title: '启用音频', description: '请点击页面以启用音频播放 🔊' })
            })
          }
        } else {
          console.error('[AIButler] remoteAudioRef不存在')
        }
        
        // 收到远程流表示连接已建立
        updateConnectionStatus('connected')
      }
    }
    
    // 监听ICE连接状态
    peerConnection.oniceconnectionstatechange = () => {
      const state = peerConnection?.iceConnectionState
      console.log('[AIButler] ICE连接状态:', state)
      updateConnectionStatus(state)
    }
    
    // 监听连接状态（备用）
    peerConnection.onconnectionstatechange = () => {
      const state = peerConnection?.connectionState
      console.log('[AIButler] 连接状态:', state)
      if (state === 'connected') {
        updateConnectionStatus('connected')
      }
    }
    
    // 启动音量检测
    startVolumeDetection()
    
    // 创建并发送Offer（关键步骤！）
    try {
      console.log('[AIButler] 正在创建WebRTC Offer...')
      const offer = await peerConnection.createOffer()
      await peerConnection.setLocalDescription(offer)
      console.log('[AIButler] 已创建并设置Local Description (Offer)')
      
      socket.emit('webrtc_offer', {
        target_type: 'front_desk',
        target_id: 'all',
        offer: offer,
        call_id: callId
      })
      console.log('[AIButler] 已发送Offer到前台')
    } catch (e) {
      console.error('[AIButler] 创建Offer失败:', e)
    }
  } catch (error) {
    console.error('[WebRTC] 初始化失败:', error)
  }
}

// 音量检测
function startVolumeDetection() {
  if (!localStream) return
  
  const audioContext = new (window.AudioContext || (window as any).webkitAudioContext)()
  const source = audioContext.createMediaStreamSource(localStream)
  const analyser = audioContext.createAnalyser()
  analyser.fftSize = 256
  source.connect(analyser)
  
  const bufferLength = analyser.frequencyBinCount
  const dataArray = new Uint8Array(bufferLength)
  
  const checkVolume = () => {
    if (!callModal.value.visible) {
      audioContext.close()
      return
    }
    
    analyser.getByteFrequencyData(dataArray)
    let sum = 0
    for (let i = 0; i < bufferLength; i++) {
      sum += dataArray[i]
    }
    const average = sum / bufferLength
    callModal.value.inputVolume = Math.min(100, average * 2)
    callModal.value.localSpeaking = average > 10
    
    requestAnimationFrame(checkVolume)
  }
  
  checkVolume()
}

// 滚动到底部
function scrollToBottom() {
  nextTick(() => {
    if (chatContainer.value) {
      chatContainer.value.scrollTop = chatContainer.value.scrollHeight
    }
  })
}
</script>

<style scoped>
.ai-butler-page {
  height: 100vh;
  display: flex;
  flex-direction: column;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.status-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 20px;
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(10px);
  color: white;
}

.hotel-info {
  display: flex;
  align-items: center;
}

.hotel-name {
  font-size: 16px;
  font-weight: bold;
  background: linear-gradient(to right, #ffffff, #8cc8ff);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}

.room-info, .connection-status {
  display: flex;
  align-items: center;
  gap: 8px;
}

.room-selector {
  color: white !important;
  font-weight: 500;
  cursor: pointer;
}

.room-selector :deep(.ant-select-selection-item) {
  color: white !important;
}

.room-selector :deep(.ant-select-arrow) {
  color: white !important;
}

.connection-status.online {
  color: #52c41a;
}

.front-desk-status {
  display: flex;
  align-items: center;
  gap: 8px;
  color: #bfbfbf;
}

.front-desk-status.online {
  color: #52c41a;
}

.main-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  padding: 20px;
  overflow: hidden;
}

.ai-avatar-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  margin-bottom: 20px;
  position: relative;
}

.ai-avatar {
  width: 100px;
  height: 100px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.2);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 48px;
  color: white;
  transition: all 0.3s ease;
}

.ai-avatar-container.listening .ai-avatar {
  transform: scale(1.1);
  background: rgba(255, 255, 255, 0.3);
  box-shadow: 0 0 30px rgba(255, 255, 255, 0.5);
}

/* AI思考中状态 */
.ai-avatar-container.thinking .ai-avatar {
  background: rgba(100, 181, 246, 0.4);
  box-shadow: 0 0 30px rgba(100, 181, 246, 0.6);
  animation: thinking-pulse 1.5s ease-in-out infinite;
}

.thinking-pulse {
  position: absolute;
  width: 120px;
  height: 120px;
  border-radius: 50%;
  border: 2px solid rgba(100, 181, 246, 0.4);
  animation: pulse-ring 1.5s ease-out infinite;
}

@keyframes thinking-pulse {
  0%, 100% { transform: scale(1); opacity: 1; }
  50% { transform: scale(1.05); opacity: 0.8; }
}

@keyframes pulse-ring {
  0% { transform: scale(1); opacity: 1; }
  100% { transform: scale(1.5); opacity: 0; }
}

.voice-waves {
  display: flex;
  align-items: center;
  gap: 4px;
  height: 20px;
  margin-top: 10px;
}

.voice-waves span {
  width: 3px;
  height: 100%;
  background: #fff;
  border-radius: 2px;
  animation: wave 1s infinite ease-in-out;
}

@keyframes wave {
  0%, 100% { height: 5px; }
  50% { height: 20px; }
}

.chat-container {
  flex: 1;
  overflow-y: auto;
  padding-right: 10px;
  display: flex;
  flex-direction: column;
}

.welcome-message {
  text-align: center;
  color: white;
  margin-top: 40px;
}

.welcome-message h2 {
  color: white;
  margin-bottom: 16px;
}

.example-text {
  opacity: 0.7;
  font-size: 14px;
}

.messages {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.message {
  display: flex;
  flex-direction: column;
  max-width: 85%;
}

.message.user {
  align-self: flex-end;
}

.message.ai {
  align-self: flex-start;
}

.message-content {
  display: flex;
  gap: 12px;
  align-items: flex-start;
}

.message.user .message-content {
  flex-direction: row-reverse;
}

.avatar {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.2);
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  flex-shrink: 0;
}

.bubble-wrapper {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.bubble {
  padding: 12px 16px;
  border-radius: 16px;
  font-size: 15px;
  line-height: 1.5;
  word-break: break-all;
}

.message.user .bubble {
  background: #1890ff;
  color: white;
  border-top-right-radius: 4px;
}

.message.ai .bubble {
  background: white;
  color: #333;
  border-top-left-radius: 4px;
}

.message-time {
  font-size: 11px;
  color: rgba(255, 255, 255, 0.5);
  margin-top: 4px;
}

.message.user .message-time {
  text-align: right;
}

.input-area {
  padding: 20px;
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(10px);
  border-top: 1px solid rgba(255, 255, 255, 0.1);
}

.quick-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  justify-content: center;
  margin-bottom: 20px;
}

.chip {
  padding: 6px 12px;
  background: rgba(255, 255, 255, 0.2);
  color: white;
  border-radius: 20px;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.3s ease;
}

.chip:hover {
  background: rgba(255, 255, 255, 0.3);
}

.input-box {
  display: flex;
  gap: 12px;
  align-items: center;
}

.input-box :deep(.ant-input) {
  background: rgba(255, 255, 255, 0.9);
  border: none;
  border-radius: 24px;
}

.send-btn {
  border-radius: 50%;
  width: 44px;
  height: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.voice-btn-large {
  width: 48px !important;
  height: 48px !important;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%) !important;
  color: white !important;
  border: 2px solid rgba(255, 255, 255, 0.3) !important;
  flex-shrink: 0;
  font-size: 20px;
  transition: all 0.3s ease;
}

.voice-btn-large:hover {
  transform: scale(1.05);
  box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);
}

.voice-btn-large:active {
  transform: scale(0.95);
}

.voice-btn-large.listening {
  background: #52c41a !important;
  border-color: #52c41a !important;
  animation: pulse-green 1.5s infinite;
}

.voice-btn-disabled {
  background: rgba(255, 255, 255, 0.1) !important;
  color: rgba(255, 255, 255, 0.5) !important;
  border: 2px dashed rgba(255, 255, 255, 0.3) !important;
}

.voice-btn-disabled:hover {
  background: rgba(255, 255, 255, 0.15) !important;
  transform: scale(1.02);
}

@keyframes pulse-green {
  0% { box-shadow: 0 0 0 0 rgba(82, 196, 26, 0.7); }
  70% { box-shadow: 0 0 0 15px rgba(82, 196, 26, 0); }
  100% { box-shadow: 0 0 0 0 rgba(82, 196, 26, 0); }
}

/* 语音输入状态 */
.voice-input-status {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 20px;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 16px;
  margin-bottom: 16px;
  animation: fade-in 0.3s ease;
}

@keyframes fade-in {
  from { opacity: 0; transform: translateY(10px); }
  to { opacity: 1; transform: translateY(0); }
}

.voice-waves-large {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  height: 60px;
  margin-bottom: 16px;
}

.voice-waves-large span {
  width: 6px;
  height: 20px;
  background: linear-gradient(to top, #667eea, #764ba2);
  border-radius: 3px;
  animation: wave-large 1s infinite ease-in-out;
}

.voice-waves-large span:nth-child(1),
.voice-waves-large span:nth-child(7) {
  height: 15px;
}

.voice-waves-large span:nth-child(2),
.voice-waves-large span:nth-child(6) {
  height: 30px;
}

.voice-waves-large span:nth-child(3),
.voice-waves-large span:nth-child(5) {
  height: 45px;
}

.voice-waves-large span:nth-child(4) {
  height: 60px;
}

@keyframes wave-large {
  0%, 100% { transform: scaleY(0.5); opacity: 0.5; }
  50% { transform: scaleY(1); opacity: 1; }
}

.voice-hint {
  color: white;
  font-size: 18px;
  font-weight: 500;
  margin: 0 0 8px 0;
}

.voice-sub-hint {
  color: rgba(255, 255, 255, 0.6);
  font-size: 14px;
  margin: 0 0 16px 0;
}

/* 停止录音按钮 */
.stop-voice-btn {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 24px;
  background: linear-gradient(135deg, #ff6b6b 0%, #ee5a5a 100%) !important;
  border: none !important;
  border-radius: 12px;
  font-size: 16px;
  font-weight: 500;
  transition: all 0.3s ease;
  box-shadow: 0 4px 15px rgba(255, 107, 107, 0.4);
}

.stop-voice-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(255, 107, 107, 0.5);
}

.stop-voice-btn:active {
  transform: scale(0.95);
}

.hint-text {
  color: rgba(255, 255, 255, 0.5);
  font-size: 12px;
  margin-top: 12px;
  text-align: center;
}

/* 弹窗样式 */
.transfer-content {
  text-align: center;
  padding: 20px 0;
}

.phone-animation {
  position: relative;
  width: 80px;
  height: 80px;
  margin: 0 auto 30px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.phone-icon {
  font-size: 32px;
  color: #1890ff;
  z-index: 2;
  animation: shake 0.5s infinite;
}

.phone-animation .pulse-ring {
  position: absolute;
  width: 100%;
  height: 100%;
  border-radius: 50%;
  border: 2px solid #1890ff;
  animation: pulse-ring 2s infinite;
}

.phone-animation .pulse-ring:nth-child(2) { animation-delay: 0.5s; }
.phone-animation .pulse-ring:nth-child(3) { animation-delay: 1s; }

@keyframes shake {
  0%, 100% { transform: rotate(0); }
  25% { transform: rotate(-15deg); }
  75% { transform: rotate(15deg); }
}

@keyframes pulse-ring {
  0% { transform: scale(0.5); opacity: 1; }
  100% { transform: scale(1.5); opacity: 0; }
}

.connecting-animation {
  width: 80px;
  height: 80px;
  margin: 0 auto 30px;
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
}

.connecting-spinner {
  position: absolute;
  width: 100%;
  height: 100%;
  border: 4px solid #f0f0f0;
  border-top-color: #52c41a;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

.connecting-icon {
  font-size: 32px;
  color: #52c41a;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.transfer-progress {
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 30px 0;
  gap: 10px;
}

.progress-step {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  width: 60px;
}

.step-dot {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  background: #f0f0f0;
  color: #bfbfbf;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  font-weight: bold;
}

.progress-step.active .step-dot {
  background: #1890ff;
  color: white;
}

.progress-step.completed .step-dot {
  background: #52c41a;
  color: white;
}

.step-text {
  font-size: 11px;
  color: #999;
}

.progress-line {
  width: 40px;
  height: 2px;
  background: #f0f0f0;
  margin-top: -20px;
}

.progress-line.completed {
  background: #52c41a;
}

.transfer-info {
  margin-bottom: 20px;
  font-size: 13px;
  color: #666;
}

.online-badge {
  color: #52c41a;
  margin-right: 4px;
}

/* 通话中弹窗 */
.call-content-modal {
  text-align: center;
  padding: 10px 0;
}

.call-header-modal {
  margin-bottom: 30px;
}

.caller-avatar {
  width: 70px;
  height: 70px;
  border-radius: 50%;
  background: #e6f7ff;
  color: #1890ff;
  font-size: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 15px;
}

.call-status-tag {
  display: inline-block;
  padding: 2px 12px;
  border-radius: 12px;
  font-size: 12px;
  margin-top: 8px;
}

.call-status-tag.connecting { background: #fff7e6; color: #fa8c16; }
.call-status-tag.connected { background: #f6ffed; color: #52c41a; }
.call-status-tag.disconnected { background: #fff1f0; color: #f5222d; }

.duration-display {
  font-size: 36px;
  font-weight: 300;
  color: #333;
  margin-bottom: 30px;
  font-family: monospace;
}

.audio-visualizer {
  display: flex;
  flex-direction: column;
  gap: 15px;
  margin-bottom: 40px;
  padding: 0 20px;
}

.visualizer-item {
  display: flex;
  align-items: center;
  gap: 12px;
}

.vis-label {
  font-size: 12px;
  color: #999;
  width: 60px;
  text-align: left;
}

.level-meter {
  flex: 1;
  height: 6px;
  background: #f5f5f5;
  border-radius: 3px;
  overflow: hidden;
}

.level-bar {
  height: 100%;
  width: 0;
  transition: width 0.1s ease, background 0.3s ease;
}

/* 工单详情 */
.ticket-detail {
  text-align: center;
  padding: 10px 0;
}

.ticket-header {
  margin-bottom: 24px;
}

.success-icon {
  font-size: 48px;
  color: #52c41a;
  margin-bottom: 12px;
}

.ticket-info {
  background: #fafafa;
  border-radius: 12px;
  padding: 20px;
  text-align: left;
  margin-bottom: 24px;
}

.info-item {
  display: flex;
  justify-content: space-between;
  margin-bottom: 12px;
}

.info-item:last-child { margin-bottom: 0; }

.info-item .label { color: #999; font-size: 13px; }
.info-item .value { color: #333; font-size: 13px; font-weight: 500; }

.urgent-text { color: #f5222d; }

.ticket-footer p {
  color: #999;
  font-size: 12px;
  margin-bottom: 16px;
}

.suggestions {
  margin-top: 10px;
}

.suggestion-label {
  color: rgba(255, 255, 255, 0.7);
  font-size: 12px;
  margin-bottom: 8px;
  display: block;
}

.suggestion-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.suggestion-chip {
  padding: 4px 10px;
  background: rgba(255, 255, 255, 0.1);
  color: #8cc8ff;
  border: 1px solid rgba(140, 200, 255, 0.3);
  border-radius: 12px;
  font-size: 12px;
  cursor: pointer;
}

.audio-indicator {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  color: #1890ff;
  margin-top: 4px;
}

.cursor {
  display: inline-block;
  width: 2px;
  height: 15px;
  background: #1890ff;
  margin-left: 2px;
  animation: blink 1s infinite;
}

@keyframes blink {
  0%, 100% { opacity: 1; }
  50% { opacity: 0; }
}
</style>
