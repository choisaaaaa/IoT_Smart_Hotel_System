<template>
  <div class="ai-butler-page" @click="handlePageClick">
    <!-- 顶部状态栏 -->
    <div class="status-bar">
      <div class="room-info">
        <HomeOutlined />
        <span>房间 {{ roomId }}</span>
      </div>
      <div class="connection-status" :class="{ online: isConnected }">
        <WifiOutlined />
        <span>{{ isConnected ? '已连接' : '连接中...' }}</span>
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
      
      <!-- 输入框 -->
      <div class="input-box">
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
        
        <!-- 语音按钮（可选） -->
        <a-button 
          v-if="microphonePermission"
          shape="circle" 
          size="large"
          class="voice-btn-small"
          :class="{ listening: isListening }"
          @mousedown="startListening"
          @mouseup="stopListening"
          @touchstart="startListening"
          @touchend="stopListening"
        >
          <AudioOutlined />
        </a-button>
      </div>
      
      <!-- 提示文字 -->
      <p class="hint-text">
        {{ isLoading ? `正在为您${currentAction}...` : '按 Enter 发送，或点击麦克风使用语音' }}
      </p>
    </div>

    <!-- 麦克风权限请求（首次） -->
    <div v-if="!microphonePermission && messages.length > 0" class="permission-hint">
      <a-button type="link" size="small" @click="requestMicrophonePermission">
        <AudioOutlined /> 启用语音输入
      </a-button>
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

    <!-- 通话中悬浮窗 -->
    <div v-if="callModal.visible" class="call-window">
      <div class="call-header">
        <PhoneOutlined class="call-icon-mini" />
        <span class="caller-name-mini">{{ callModal.callerName }}</span>
        <div class="connection-status" :class="callModal.connectionState">
          {{ callModal.connectionStateText }}
        </div>
      </div>
      <div class="call-duration">{{ callModal.duration }}</div>
      
      <!-- 通话状态 -->
      <div class="call-status-banner" :class="callModal.connectionState">
        <span class="status-dot"></span>
        <span class="status-text">{{ callModal.statusText }}</span>
      </div>
      
      <!-- 音频电平指示器 -->
      <div class="audio-indicators">
        <div class="audio-indicator" :class="{ speaking: callModal.localSpeaking }">
          <div class="indicator-label">
            <span class="indicator-icon">🎤</span>
            <span class="indicator-text">我</span>
            <span class="indicator-status" :class="{ active: callModal.inputVolume > 5, speaking: callModal.localSpeaking }">
              {{ callModal.localSpeaking ? '说话中' : (callModal.inputVolume > 5 ? '正常' : '静音') }}
            </span>
          </div>
          <div class="level-bar-container">
            <div class="level-bar" :style="{ height: callModal.inputVolume + '%' }"></div>
          </div>
        </div>
        <div class="audio-indicator" :class="{ speaking: callModal.remoteSpeaking }">
          <div class="indicator-label">
            <span class="indicator-icon">🔊</span>
            <span class="indicator-text">对方</span>
            <span class="indicator-status" :class="{ active: callModal.outputVolume > 5, speaking: callModal.remoteSpeaking }">
              {{ callModal.remoteSpeaking ? '说话中' : (callModal.outputVolume > 5 ? '正常' : '静音') }}
            </span>
          </div>
          <div class="level-bar-container">
            <div class="level-bar output" :style="{ height: callModal.outputVolume + '%' }"></div>
          </div>
        </div>
      </div>
      
      <a-button danger size="large" @click="hangupCall" class="hangup-btn" block>
        <template #icon><CloseOutlined /></template> 挂断
      </a-button>
    </div>

    <!-- 远程音频元素 -->
    <audio ref="remoteAudioRef" autoplay style="display: none;"></audio>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import { message } from 'ant-design-vue'
import {
  RobotOutlined,
  HomeOutlined,
  WifiOutlined,
  AudioOutlined,
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
import { useRoute } from 'vue-router'
import { getSocket } from '@/utils/websocket'
import request from '@/api/request'

const route = useRoute()
const roomId = ref(route.query.room as string || '101')

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

onMounted(() => {
  initWebSocket()
  initSpeechRecognition()
  verifyAccess()
})

onUnmounted(() => {
  if (socket) {
    socket.off('incoming_call')
    socket.off('call_answered')
    socket.off('call_rejected')
    socket.off('call_hungup')
    socket.off('webrtc_offer')
    socket.off('webrtc_answer')
    socket.off('webrtc_ice_candidate')
  }
})

// 初始化WebSocket
function initWebSocket() {
  socket = getSocket()
  if (socket) {
    isConnected.value = socket.connected
    
    // 如果已经连接，立即注册
    if (socket.connected) {
      socket.emit('register_client', {
        clientType: 'room',
        clientId: roomId.value
      })
    }
    
    socket.on('connect', () => {
      isConnected.value = true
      // 注册为房间客户端
      socket.emit('register_client', {
        clientType: 'room',
        clientId: roomId.value
      })
    })

    socket.on('disconnect', () => {
      isConnected.value = false
    })

    // 监听来电（转接时）
    socket.on('incoming_call', (data: any) => {
      if (data.isTransfer) {
        transferModal.value.visible = true
        transferModal.value.callId = data.call_id
      }
    })

    socket.on('call_answered', (data: any) => {
      console.log('[AIButler] 收到call_answered:', data)
      console.log('[AIButler] 当前transferModal.callId:', transferModal.value.callId)
      
      // 如果没有设置callId，尝试从data中恢复
      if (!transferModal.value.callId && data.call_id) {
        console.log('[AIButler] 恢复callId:', data.call_id)
        transferModal.value.callId = data.call_id
      }
      
      if (data.call_id === transferModal.value.callId) {
        console.log('[AIButler] callId匹配，更新UI')
        // 更新转接弹窗为连接中状态
        transferModal.value.step = 'connecting'
        transferModal.value.statusText = '前台已接听'
        transferModal.value.statusDesc = '正在建立语音连接...'
        message.success('前台已接听，正在连接...')
        
        // 2秒后切换到通话弹窗
        setTimeout(() => {
          transferModal.value.visible = false
          // 显示通话中弹窗
          showCallModal(data.call_id)
          // 初始化WebRTC（主叫方等待被叫方的offer）
          initWebRTC(data.call_id)
        }, 1500)
      } else {
        console.log('[AIButler] callId不匹配，忽略')
      }
    })
    
    // 监听WebRTC信令事件
    socket.on('webrtc_offer', async (data: any) => {
      console.log('[AIButler] 收到webrtc_offer:', data)
      console.log('[AIButler] 当前callModal.callId:', callModal.value.callId, 'transferModal.callId:', transferModal.value.callId)
      
      // 检查call_id是否匹配（可能是callModal或transferModal中的callId）
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
        
        // 创建answer
        const answer = await peerConnection.createAnswer()
        await peerConnection.setLocalDescription(answer)
        console.log('[AIButler] 已创建并设置local description (answer)')
        
        // 发送answer
        socket.emit('webrtc_answer', {
          target_type: 'front_desk',
          target_id: 'all',
          answer: answer,
          call_id: data.call_id
        })
        console.log('[AIButler] 已发送answer')
        
        // 处理挂起的ICE候选
        processPendingIceCandidates()
      } catch (e) {
        console.error('[AIButler] 处理offer失败:', e)
      }
    })
    
    socket.on('webrtc_answer', async (data: any) => {
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
    })
    
    socket.on('webrtc_ice_candidate', async (data: any) => {
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
    })

    socket.on('call_rejected', (data: any) => {
      if (data.call_id === transferModal.value.callId) {
        transferModal.value.statusText = '呼叫被拒绝'
        transferModal.value.statusDesc = '前台暂时无法接听，请稍后再试'
        message.warning('前台暂时无法接听')
        setTimeout(() => {
          transferModal.value.visible = false
          resetTransferModal()
        }, 3000)
      }
    })

    // 监听通话挂断
    socket.on('call_hungup', (data: any) => {
      if (data.call_id === callModal.value.callId) {
        message.info('通话已结束')
        closeCallModal()
      }
    })
  }
}

// 验证入住权限
async function verifyAccess() {
  try {
    const res: any = await request.post('/ai-butler/verify', {
      room_id: roomId.value
    })
    
    if (res.data?.code === 403) {
      message.error('该房间暂无入住记录，无法使用AI管家')
    } else if (res.data?.data?.accessible) {
      message.success(`欢迎${res.data.data.guestName}，我是您的AI管家小智`)
    }
  } catch (error) {
    console.error('验证失败:', error)
  }
}

// 初始化语音识别
function initSpeechRecognition() {
  const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition
  
  if (!SpeechRecognition) {
    message.warning('您的浏览器不支持语音识别')
    return
  }

  recognition = new SpeechRecognition()
  recognition.lang = 'zh-CN'
  recognition.continuous = false
  recognition.interimResults = false

  recognition.onstart = () => {
    isListening.value = true
  }

  recognition.onend = () => {
    isListening.value = false
  }

  recognition.onresult = (event: any) => {
    const text = event.results[0][0].transcript
    handleUserInput(text)
  }

  recognition.onerror = (event: any) => {
    console.error('语音识别错误:', event.error)
    isListening.value = false
    message.error('语音识别失败，请重试')
  }
}

// 开始监听
function startListening() {
  if (!recognition) {
    message.warning('语音识别未初始化')
    return
  }
  
  try {
    recognition.start()
  } catch (e) {
    console.error('启动识别失败:', e)
  }
}

// 停止监听
function stopListening() {
  if (recognition) {
    recognition.stop()
  }
}

// 处理用户输入
async function handleUserInput(text: string) {
  // 添加到消息列表
  messages.value.push({
    type: 'user',
    text,
    time: new Date().toLocaleTimeString()
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
      time: new Date().toLocaleTimeString()
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
    time: new Date().toLocaleTimeString()
  })
  scrollToBottom()
  
  // 设置加载状态
  isLoading.value = true
  currentAction.value = text
  
  // 添加"正在处理"提示
  messages.value.push({
    type: 'ai',
    text: `⏳ 正在为您${text}...`,
    time: new Date().toLocaleTimeString()
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
      
      // 播放语音回复（如果有）
      if (aiResponse.audioUrl) {
        playAudio(aiResponse.audioUrl)
      }
      
      // 使用打字机效果显示AI回复
      const aiText = aiResponse.text || '抱歉，我没有理解您的意思，请换个说法试试？'
      
      // 先添加占位消息
      messages.value.push({
        type: 'ai',
        text: aiText,  // 完整文本保存
        time: new Date().toLocaleTimeString(),
        typing: true   // 标记为打字中
      })
      
      // 启动打字机效果
      typeWriterEffect(aiText, () => {
        // 打字完成后更新智能建议
        updateSuggestions(text)
        
        // 标记消息完成
        const lastMsg = messages.value[messages.value.length - 1]
        if (lastMsg) {
          lastMsg.typing = false
        }
      })
      
      scrollToBottom()

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
            time: new Date().toLocaleTimeString()
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
      time: new Date().toLocaleTimeString()
    })
    scrollToBottom()
  } finally {
    isSpeaking.value = false
  }
}

// 请求麦克风权限
async function requestMicrophonePermission() {
  try {
    // 请求麦克风权限
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    // 立即释放流，只是测试权限
    stream.getTracks().forEach(track => track.stop())
    microphonePermission.value = true
    message.success('麦克风权限已获取')
    
    // 如果是iOS Safari，需要用户交互后才能初始化语音识别
    if (/iPad|iPhone|iPod/.test(navigator.userAgent)) {
      message.info('iOS设备：请点击麦克风按钮开始语音对话')
    }
  } catch (error) {
    console.error('获取麦克风权限失败:', error)
    message.error('无法获取麦克风权限，请检查浏览器设置')
    
    // 显示详细的错误信息
    if (error instanceof DOMException) {
      if (error.name === 'NotAllowedError') {
        message.error('麦克风权限被拒绝，请在浏览器设置中允许访问麦克风')
      } else if (error.name === 'NotFoundError') {
        message.error('未找到麦克风设备')
      }
    }
  }
}

// 播放AI语音回复
const audioPlayer = ref<HTMLAudioElement | null>(null)
const isPlayingAudio = ref(false)

function playAudio(base64Audio: string) {
  try {
    // 停止之前的音频
    if (audioPlayer.value) {
      audioPlayer.value.pause()
      audioPlayer.value = null
    }
    
    // 创建新的音频对象
    const audio = new Audio(`data:audio/mp3;base64,${base64Audio}`)
    audioPlayer.value = audio
    
    // 设置播放状态
    isPlayingAudio.value = true
    
    audio.onended = () => {
      isPlayingAudio.value = false
      console.log('[AIButler] 语音播放完成')
    }
    
    audio.onerror = (e) => {
      isPlayingAudio.value = false
      console.error('[AIButler] 语音播放失败:', e)
      message.warning('语音播放失败，请检查音量设置')
    }
    
    // 尝试播放（处理自动播放策略）
    const playPromise = audio.play()
    
    if (playPromise !== undefined) {
      playPromise.then(() => {
        console.log('[AIButler] 语音开始播放')
      }).catch((error) => {
        isPlayingAudio.value = false
        console.warn('[AIButler] 自动播放被阻止:', error)
        
        // 显示提示让用户点击启用
        message.info('🔊 点击页面任意位置播放AI语音')
        
        // 监听一次用户点击来播放
        const playOnce = () => {
          audio.play().then(() => {
            isPlayingAudio.value = true
            document.removeEventListener('click', playOnce)
          })
        }
        
        setTimeout(() => {
          document.addEventListener('click', playOnce, { once: true })
        }, 100)
      })
    }
  } catch (e) {
    isPlayingAudio.value = false
    console.error('创建音频对象失败:', e)
  }
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
      message.error('无法访问麦克风，请检查权限设置')
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
              message.info('请点击页面以启用音频')
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
      console.log('[AIButler] 已设置本地描述(Offer)')
      
      // 发送offer给所有前台
      if (socket) {
        socket.emit('webrtc_offer', {
          target_type: 'front_desk',
          target_id: 'all',
          offer: peerConnection.localDescription,
          call_id: callId
        })
        console.log('[AIButler] 已发送WebRTC Offer给前台')
      }
    } catch (offerError) {
      console.error('[AIButler] 创建或发送Offer失败:', offerError)
      message.error('无法建立通话连接')
    }
    
  } catch (error) {
    console.error('WebRTC初始化失败:', error)
    message.error('无法访问麦克风')
  }
}

// 启动音量检测
function startVolumeDetection() {
  if (!localStream) return
  
  const audioContext = new (window.AudioContext || (window as any).webkitAudioContext)()
  const analyser = audioContext.createAnalyser()
  const microphone = audioContext.createMediaStreamSource(localStream)
  microphone.connect(analyser)
  analyser.fftSize = 256
  
  const dataArray = new Uint8Array(analyser.frequencyBinCount)
  
  const checkVolume = () => {
    if (!callModal.value.visible) return
    
    analyser.getByteFrequencyData(dataArray)
    const average = dataArray.reduce((a, b) => a + b) / dataArray.length
    callModal.value.inputVolume = Math.min(100, average * 2)
    callModal.value.localSpeaking = average > 20
    
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

.room-info, .connection-status {
  display: flex;
  align-items: center;
  gap: 8px;
}

.connection-status.online {
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
  gap: 4px;
  margin-top: 10px;
  height: 20px;
  align-items: center;
}

.voice-waves span {
  width: 4px;
  height: 100%;
  background: white;
  border-radius: 2px;
  animation: wave 0.5s ease-in-out infinite;
}

@keyframes wave {
  0%, 100% { height: 20%; }
  50% { height: 100%; }
}

.chat-container {
  flex: 1;
  overflow-y: auto;
  background: rgba(255, 255, 255, 0.95);
  border-radius: 16px;
  padding: 20px;
}

.welcome-message {
  text-align: center;
  padding: 40px 20px;
}

.welcome-message h2 {
  color: #333;
  margin-bottom: 10px;
}

.welcome-message p {
  color: #666;
  margin-bottom: 10px;
}

.welcome-message .example-text {
  color: #999;
  font-size: 13px;
  font-style: italic;
}

.quick-actions {
  display: flex;
  flex-direction: column;
  gap: 12px;
  justify-content: center;
}

.loading-indicator {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 12px;
  background: rgba(255, 255, 255, 0.15);
  border-radius: 12px;
  backdrop-filter: blur(10px);
  animation: fadeIn 0.3s ease;
}

.loading-indicator p {
  color: white;
  font-size: 14px;
  margin: 0;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(-10px); }
  to { opacity: 1; transform: translateY(0); }
}

.action-row {
  display: flex;
  gap: 10px;
  justify-content: center;
  flex-wrap: wrap;
}

.action-btn {
  border-radius: 20px !important;
  padding: 8px 16px !important;
  font-size: 13px !important;
  background: rgba(255, 255, 255, 0.4) !important;
  border: 1px solid rgba(255, 255, 255, 0.6) !important;
  color: #1a1a2e !important;
  font-weight: 500 !important;
  backdrop-filter: blur(10px);
  transition: all 0.3s ease;
}

.action-btn:hover {
  background: rgba(255, 255, 255, 0.6) !important;
  border-color: rgba(255, 255, 255, 0.8) !important;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.action-btn.danger {
  background: rgba(255, 77, 79, 0.5) !important;
  border-color: rgba(255, 77, 79, 0.7) !important;
  color: white !important;
}

.action-btn.danger:hover {
  background: rgba(255, 77, 79, 0.7) !important;
}

.messages {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.message {
  display: flex;
  flex-direction: column;
}

.message.user {
  align-items: flex-end;
}

.message.ai {
  align-items: flex-start;
}

.message-content {
  display: flex;
  align-items: flex-start;
  gap: 8px;
}

.message.user .message-content {
  flex-direction: row-reverse;
}

.avatar {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: #1890ff;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
}

.message.ai .avatar {
  background: #52c41a;
}

.bubble {
  max-width: 70%;
  padding: 12px 16px;
  border-radius: 16px;
  background: #f0f0f0;
  word-wrap: break-word;
}

.message.user .bubble {
  background: #1890ff;
  color: white;
}

/* 气泡包装器（用于添加语音控制） */
.bubble-wrapper {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.bubble.with-audio {
  position: relative;
}

/* 语音播放指示器 */
.audio-indicator {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 4px 10px;
  background: linear-gradient(135deg, #667eea15, #764ba215);
  border-radius: 20px;
  font-size: 12px;
  color: #667eea;
  animation: fadeInUp 0.3s ease;
}

.audio-indicator .anticon {
  color: #667eea;
  font-size: 14px;
}

.audio-indicator span {
  font-weight: 500;
}

.audio-indicator .ant-btn-link {
  padding: 0 4px;
  height: auto;
  font-size: 11px;
  color: #764ba2;
}

@keyframes fadeInUp {
  from {
    opacity: 0;
    transform: translateY(-5px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* 打字机光标效果 */
.bubble.typing .cursor {
  display: inline-block;
  color: #667eea;
  font-weight: bold;
  animation: blink 0.8s infinite;
}

@keyframes blink {
  0%, 50% { opacity: 1; }
  51%, 100% { opacity: 0; }
}

/* 智能建议区域 */
.suggestions {
  margin-top: 16px;
  padding: 12px 16px;
  background: linear-gradient(135deg, #f8f9ff, #f0f4ff);
  border-radius: 12px;
  animation: slideUp 0.3s ease;
}

.suggestion-label {
  display: block;
  font-size: 13px;
  color: #666;
  margin-bottom: 8px;
  font-weight: 500;
}

.suggestion-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.suggestion-chip {
  padding: 6px 14px;
  background: white;
  border: 1px solid #e0e5ff;
  border-radius: 20px;
  font-size: 13px;
  color: #5568a3;
  cursor: pointer;
  transition: all 0.2s ease;
  user-select: none;
}

.suggestion-chip:hover {
  background: linear-gradient(135deg, #667eea, #764ba2);
  color: white;
  border-color: transparent;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.25);
}

@keyframes slideUp {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.message-time {
  font-size: 12px;
  color: #999;
  margin-top: 4px;
}

/* 输入区域 */
.input-area {
  padding: 20px;
  background: white;
  border-radius: 16px 16px 0 0;
  box-shadow: 0 -4px 15px rgba(0, 0, 0, 0.05);
}

.quick-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-bottom: 12px;
  justify-content: center;
}

.chip {
  padding: 6px 14px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border-radius: 20px;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.3s ease;
  user-select: none;
}

.chip:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
}

.input-box {
  display: flex;
  gap: 10px;
  align-items: center;
  padding: 8px;
  background: #f5f7fa;
  border-radius: 12px;
  border: 1px solid #e1e4e8;
  transition: all 0.3s ease;
}

.input-box:focus-within {
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.input-box .ant-input {
  flex: 1;
  border: none !important;
  background: transparent !important;
  font-size: 15px;
  box-shadow: none !important;
}

.send-btn {
  width: 48px;
  height: 48px;
  border-radius: 50% !important;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%) !important;
  border: none !important;
  font-size: 18px;
  transition: all 0.3s ease;
}

.send-btn:hover:not(:disabled) {
  transform: scale(1.1);
  box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);
}

.send-btn:disabled {
  background: #ccc !important;
  color: #999 !important;
}

.voice-btn-small {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  border: 1px solid #e1e4e8;
  background: white;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.3s ease;
}

.voice-btn-small:hover {
  border-color: #667eea;
  color: #667eea;
}

.voice-btn-small.listening {
  background: #ff4d4f;
  color: white;
  border-color: #ff4d4f;
  animation: pulse 1s infinite;
}

.hint-text {
  text-align: center;
  color: #999;
  font-size: 12px;
  margin: 8px 0 0 0;
}

.permission-hint {
  text-align: center;
  padding: 8px;
  background: #f0f9ff;
  border-top: 1px solid #e6f7ff;
}

.control-bar, .permission-bar {
  padding: 20px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
}

.voice-btn {
  width: 70px;
  height: 70px;
  font-size: 28px;
  background: white;
  border: none;
  box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2);
}

.voice-btn.listening {
  background: #ff4d4f;
  color: white;
  animation: pulse 1s infinite;
}

@keyframes pulse {
  0% { transform: scale(1); }
  50% { transform: scale(1.05); }
  100% { transform: scale(1); }
}

.hint {
  color: white;
  margin: 0;
}

.transfer-content {
  text-align: center;
  padding: 30px 20px;
}

.phone-animation {
  position: relative;
  width: 80px;
  height: 80px;
  margin: 0 auto 20px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.pulse-ring {
  position: absolute;
  width: 100%;
  height: 100%;
  border-radius: 50%;
  background: rgba(24, 144, 255, 0.3);
  animation: pulse-ring 2s ease-out infinite;
}

.pulse-ring:nth-child(2) {
  animation-delay: 0.5s;
}

.pulse-ring:nth-child(3) {
  animation-delay: 1s;
}

@keyframes pulse-ring {
  0% {
    transform: scale(1);
    opacity: 1;
  }
  100% {
    transform: scale(2);
    opacity: 0;
  }
}

.phone-icon {
  font-size: 36px;
  color: #1890ff;
  z-index: 1;
}

.transfer-content h3 {
  font-size: 18px;
  color: #333;
  margin-bottom: 8px;
}

.status-desc {
  color: #666;
  font-size: 14px;
  margin-bottom: 16px;
}

.transfer-info {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: 8px 16px;
  background: #f6ffed;
  border: 1px solid #b7eb8f;
  border-radius: 20px;
  margin-bottom: 20px;
  font-size: 13px;
  color: #52c41a;
}

.online-badge {
  animation: blink 1.5s infinite;
}

@keyframes blink {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

.transfer-actions {
  margin-top: 10px;
}

/* 连接中动画 */
.connecting-animation {
  position: relative;
  width: 80px;
  height: 80px;
  margin: 0 auto 20px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.connecting-spinner {
  position: absolute;
  width: 100%;
  height: 100%;
  border-radius: 50%;
  border: 4px solid #e8e8e8;
  border-top-color: #52c41a;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.connecting-icon {
  font-size: 32px;
  color: #52c41a;
  z-index: 1;
}

/* 进度指示器 */
.transfer-progress {
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 20px 0;
  padding: 0 20px;
}

.progress-step {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
}

.progress-step .step-dot {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: #d9d9d9;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  font-weight: 500;
  transition: all 0.3s ease;
}

.progress-step.active .step-dot {
  background: #1890ff;
  animation: pulse-dot 1.5s infinite;
}

.progress-step.completed .step-dot {
  background: #52c41a;
}

@keyframes pulse-dot {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.1); }
}

.progress-step .step-text {
  font-size: 12px;
  color: #999;
  transition: all 0.3s ease;
}

.progress-step.active .step-text {
  color: #1890ff;
  font-weight: 500;
}

.progress-step.completed .step-text {
  color: #52c41a;
}

.progress-line {
  width: 60px;
  height: 2px;
  background: #d9d9d9;
  margin: 0 10px;
  position: relative;
  top: -12px;
  transition: all 0.3s ease;
}

.progress-line.completed {
  background: #52c41a;
}

/* 通话中弹窗样式 */
.call-window {
  position: fixed;
  bottom: 20px;
  right: 20px;
  width: 300px;
  background: white;
  border-radius: 16px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.15);
  padding: 20px;
  z-index: 1000;
}

.call-header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 12px;
}

.call-icon-mini {
  font-size: 20px;
  color: #1890ff;
}

.caller-name-mini {
  flex: 1;
  font-weight: 500;
  font-size: 16px;
}

.connection-status {
  font-size: 12px;
  padding: 2px 8px;
  border-radius: 10px;
  background: #f0f0f0;
  color: #666;
}

.connection-status.connecting {
  background: #fff7e6;
  color: #fa8c16;
}

.connection-status.connected {
  background: #f6ffed;
  color: #52c41a;
}

.connection-status.disconnected {
  background: #fff1f0;
  color: #ff4d4f;
}

.call-duration {
  font-size: 32px;
  font-weight: 300;
  text-align: center;
  color: #333;
  margin-bottom: 12px;
  font-variant-numeric: tabular-nums;
}

.call-status-banner {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: 8px;
  border-radius: 8px;
  background: #f5f5f5;
  margin-bottom: 16px;
}

.call-status-banner.connecting {
  background: #fff7e6;
}

.call-status-banner.connected {
  background: #f6ffed;
}

.status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #999;
  animation: blink 1.5s infinite;
}

.call-status-banner.connected .status-dot {
  background: #52c41a;
}

.call-status-banner.connecting .status-dot {
  background: #fa8c16;
}

.status-text {
  font-size: 13px;
  color: #666;
}

.audio-indicators {
  display: flex;
  gap: 12px;
  margin-bottom: 16px;
}

.audio-indicator {
  flex: 1;
  background: #f5f5f5;
  border-radius: 8px;
  padding: 10px;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.audio-indicator.speaking {
  background: #e6f7ff;
  border: 1px solid #91d5ff;
}

.indicator-label {
  display: flex;
  align-items: center;
  gap: 4px;
  margin-bottom: 8px;
  font-size: 12px;
}

.indicator-icon {
  font-size: 14px;
}

.indicator-text {
  color: #333;
}

.indicator-status {
  font-size: 10px;
  padding: 2px 6px;
  border-radius: 4px;
  background: #d9d9d9;
  color: #666;
}

.indicator-status.active {
  background: #b7eb8f;
  color: #389e0d;
}

.indicator-status.speaking {
  background: #91d5ff;
  color: #096dd9;
  animation: pulse 0.5s infinite;
}

.level-bar-container {
  width: 100%;
  height: 40px;
  background: #e8e8e8;
  border-radius: 4px;
  overflow: hidden;
  position: relative;
}

.level-bar {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  background: #52c41a;
  border-radius: 4px;
  transition: height 0.1s ease;
}

.level-bar.output {
  background: #1890ff;
}

.hangup-btn {
  margin-top: 8px;
}
</style>
