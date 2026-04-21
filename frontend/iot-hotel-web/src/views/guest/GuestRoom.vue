<template>
  <div class="guest-room-page">
    <div class="page-header">
      <div class="room-info">
        <HomeOutlined class="room-icon" />
        <div class="room-details">
          <h1>客房服务</h1>
          <p>房间 {{ roomIdDisplay }}</p>
        </div>
      </div>
      <div class="connection-badge" :class="{ online: socket?.connected }">
        <WifiOutlined v-if="socket?.connected" />
        <LoadingOutlined v-else spin />
        <span>{{ socket?.connected ? '服务在线' : '连接中' }}</span>
      </div>
    </div>

    <a-row :gutter="24">
      <!-- 左侧：AI 管家交互区 -->
      <a-col :xs="24" :lg="16">
        <div class="ai-card">
          <div class="ai-header">
            <div class="ai-title">
              <RobotOutlined class="ai-icon" />
              <span>AI 智慧管家</span>
            </div>
            <a-tag class="ai-status" :class="{ active: socket?.connected }">
              <span class="status-dot"></span>
              {{ socket?.connected ? '在线' : '离线' }}
            </a-tag>
          </div>

          <div class="ai-body">
            <div class="chat-messages" ref="chatContainerRef">
              <div v-if="chatMessages.length === 0" class="welcome-section">
                <div class="welcome-avatar" :class="{ thinking: aiThinking }">
                  <RobotOutlined />
                </div>
                <h2>您好，我是您的 AI 管家</h2>
                <p>您可以直接跟我说话，或者点击下方的快捷功能</p>
              </div>

              <div 
                v-for="(msg, idx) in chatMessages" 
                :key="idx" 
                :class="['message-row', msg.type]"
              >
                <div class="message-avatar">
                  <RobotOutlined v-if="msg.type === 'ai'" />
                  <UserOutlined v-else />
                </div>
                <div class="message-content">
                  <div class="message-bubble" :class="{ typing: msg.typing && isTyping && idx === chatMessages.length - 1 }">
                    <template v-if="msg.typing && isTyping && idx === chatMessages.length - 1">
                      {{ displayedText }}<span class="cursor">|</span>
                    </template>
                    <template v-else>
                      {{ msg.text }}
                    </template>
                  </div>
                  <div v-if="msg.type === 'ai' && idx === chatMessages.length - 1 && isPlayingAudio" class="audio-indicator">
                    <SoundOutlined :spin="isPlayingAudio" />
                    <span>正在播放语音</span>
                    <a-button type="link" size="small" @click="toggleAudio">
                      {{ isPlayingAudio ? '暂停' : '播放' }}
                    </a-button>
                  </div>
                </div>
              </div>

              <div v-if="aiThinking" class="message-row ai">
                <div class="message-avatar">
                  <RobotOutlined />
                </div>
                <div class="message-content">
                  <div class="thinking-indicator">
                    <a-spin size="small" />
                    <span>正在思考中...</span>
                  </div>
                </div>
              </div>

              <!-- 智能建议 -->
              <div v-if="suggestions.length > 0 && !aiThinking && !isTyping" class="suggestions-section">
                <div class="suggestions-label">
                  <BulbOutlined /> 猜您想问
                </div>
                <div class="suggestions-list">
                  <span 
                    v-for="(s, sIdx) in suggestions.slice(0, 3)" 
                    :key="sIdx" 
                    class="suggestion-chip" 
                    @click="askQuick(s)"
                  >
                    {{ s }}
                  </span>
                </div>
              </div>
            </div>

            <div class="chat-input-area">
              <div v-if="chatMessages.length === 0" class="quick-actions">
                <span 
                  v-for="chip in quickChips" 
                  :key="chip.text" 
                  class="action-chip" 
                  @click="askQuick(chip.text)"
                >
                  <component :is="chip.icon" />
                  {{ chip.label }}
                </span>
              </div>
              <div class="input-wrapper">
                <a-input
                  v-model:value="inputText"
                  placeholder="输入您的问题，如：打开灯光、需要保洁..."
                  size="large"
                  @pressEnter="sendMessage"
                  :disabled="aiThinking"
                  class="chat-input"
                >
                  <template #prefix>
                    <EditOutlined class="input-icon" />
                  </template>
                </a-input>
                <a-button 
                  type="primary" 
                  size="large" 
                  class="send-btn" 
                  :loading="aiThinking" 
                  :disabled="!inputText.trim() || aiThinking" 
                  @click="sendMessage"
                >
                  <SendOutlined />
                </a-button>
              </div>
            </div>
          </div>
        </div>
      </a-col>

      <!-- 右侧：服务中心 -->
      <a-col :xs="24" :lg="8">
        <div class="service-card">
          <div class="service-header">
            <CustomerServiceOutlined />
            <span>服务中心</span>
          </div>
          
          <div class="service-list">
            <div class="service-item" @click="showDeliveryModal = true">
              <div class="service-icon delivery">
                <ShoppingOutlined />
              </div>
              <div class="service-info">
                <div class="service-name">送物服务</div>
                <div class="service-desc">配送饮品、日用品</div>
              </div>
              <RightOutlined class="service-arrow" />
            </div>

            <div class="service-item" @click="callFrontDesk">
              <div class="service-icon call">
                <PhoneOutlined />
              </div>
              <div class="service-info">
                <div class="service-name">呼叫前台</div>
                <div class="service-desc">语音通话即时沟通</div>
              </div>
              <RightOutlined class="service-arrow" />
            </div>

            <div class="service-item" @click="showMessagePanel">
              <div class="service-icon message">
                <MessageOutlined />
              </div>
              <div class="service-info">
                <div class="service-name">在线留言</div>
                <div class="service-desc">给工作人员留言</div>
              </div>
              <RightOutlined class="service-arrow" />
            </div>

            <div class="service-item" @click="showMaintenanceModal = true">
              <div class="service-icon repair">
                <ToolOutlined />
              </div>
              <div class="service-info">
                <div class="service-name">设施报修</div>
                <div class="service-desc">房间设备故障报修</div>
              </div>
              <RightOutlined class="service-arrow" />
            </div>

            <div class="service-item" @click="showMyDeliveryRecords">
              <div class="service-icon records">
                <HistoryOutlined />
              </div>
              <div class="service-info">
                <div class="service-name">我的配送</div>
                <div class="service-desc">查看配送订单记录</div>
              </div>
              <RightOutlined class="service-arrow" />
            </div>

            <div class="service-item" @click="showMyMaintenanceRecords">
              <div class="service-icon records">
                <FileTextOutlined />
              </div>
              <div class="service-info">
                <div class="service-name">我的报修</div>
                <div class="service-desc">查看维修工单记录</div>
              </div>
              <RightOutlined class="service-arrow" />
            </div>

            <div class="service-item" @click="askQuick('需要保洁服务')">
              <div class="service-icon cleaning">
                <ClearOutlined />
              </div>
              <div class="service-info">
                <div class="service-name">申请保洁</div>
                <div class="service-desc">打扫房间、整理床铺</div>
              </div>
              <RightOutlined class="service-arrow" />
            </div>
          </div>
        </div>
      </a-col>
    </a-row>

    <!-- 送物弹窗 -->
    <a-modal 
      v-model:open="showDeliveryModal" 
      title="申请送物" 
      @ok="requestDelivery" 
      :confirmLoading="deliveryLoading"
      class="service-modal"
      width="480px"
    >
      <a-form :model="deliveryForm" layout="vertical" class="service-form">
        <a-form-item label="物品类别" required>
          <a-select v-model:value="deliveryForm.category" size="large">
            <a-select-option value="beverage">
              <CoffeeOutlined /> 饮品（矿泉水、饮料等）
            </a-select-option>
            <a-select-option value="food">
              <ShoppingOutlined /> 食品（方便面、零食等）
            </a-select-option>
            <a-select-option value="daily">
              <SkinOutlined /> 日用品（毛巾、洗漱用品等）
            </a-select-option>
            <a-select-option value="other">
              <InboxOutlined /> 其他物品
            </a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item label="物品名称" required>
          <a-input 
            v-model:value="deliveryForm.item_name" 
            placeholder="如：矿泉水、毛巾..."
            size="large"
          />
        </a-form-item>
        <a-form-item label="数量">
          <a-input-number 
            v-model:value="deliveryForm.quantity" 
            :min="1" 
            :max="20" 
            style="width: 100%;"
            size="large"
          />
        </a-form-item>
        <a-form-item label="备注">
          <a-textarea 
            v-model:value="deliveryForm.note" 
            :rows="3" 
            placeholder="特殊要求..."
          />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 报修弹窗 -->
    <a-modal 
      v-model:open="showMaintenanceModal" 
      title="设施报修" 
      @ok="requestMaintenance" 
      :confirmLoading="maintenanceLoading"
      class="service-modal"
      width="480px"
    >
      <a-form :model="maintenanceForm" layout="vertical" class="service-form">
        <a-form-item label="故障类型" required>
          <a-select v-model:value="maintenanceForm.fault_type" size="large">
            <a-select-option value="electric">
              <ThunderboltOutlined /> 电力/灯光
            </a-select-option>
            <a-select-option value="water">
              <InboxOutlined /> 水路/卫浴
            </a-select-option>
            <a-select-option value="ac">
              <CloudOutlined /> 空调/暖气
            </a-select-option>
            <a-select-option value="network">
              <WifiOutlined /> 网络/电视
            </a-select-option>
            <a-select-option value="other">
              <ToolOutlined /> 其他故障
            </a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item label="故障描述" required>
          <a-textarea 
            v-model:value="maintenanceForm.fault_description" 
            :rows="4" 
            placeholder="请详细描述故障情况，以便维修人员准备工具..."
          />
        </a-form-item>
        <a-form-item label="紧急程度">
          <a-radio-group v-model:value="maintenanceForm.priority">
            <a-radio-button value="low">普通</a-radio-button>
            <a-radio-button value="medium">一般</a-radio-button>
            <a-radio-button value="high">紧急</a-radio-button>
          </a-radio-group>
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 留言弹窗 -->
    <a-modal 
      v-model:open="messageModalVisible" 
      title="给前台留言" 
      @ok="sendMsgToReception"
      class="service-modal"
      width="480px"
    >
      <a-textarea 
        v-model:value="msgContent" 
        :rows="5" 
        placeholder="请输入您想对前台说的话..."
      />
    </a-modal>

    <!-- 呼叫中弹窗 -->
    <a-modal
      v-model:open="transferModal.visible"
      :footer="null"
      :closable="false"
      :maskClosable="false"
      centered
      width="360px"
      class="calling-modal"
    >
      <div class="calling-content">
        <div class="calling-animation">
          <div class="pulse-ring"></div>
          <div class="pulse-ring"></div>
          <div class="pulse-ring"></div>
          <PhoneOutlined class="phone-icon" />
        </div>
        <h3>{{ transferModal.statusText }}</h3>
        <p>{{ transferModal.statusDesc }}</p>
        <a-button danger size="large" @click="cancelTransfer" class="cancel-btn">
          <CloseOutlined /> 取消呼叫
        </a-button>
      </div>
    </a-modal>

    <!-- 我的配送记录弹窗 -->
    <a-modal 
      v-model:open="showDeliveryRecordsModal" 
      title="我的配送记录" 
      :footer="null" 
      width="680px"
      class="records-modal"
    >
      <a-table 
        :dataSource="deliveryRecords" 
        :columns="deliveryColumns" 
        :loading="deliveryRecordsLoading" 
        :pagination="{ pageSize: 5 }" 
        size="middle"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'status'">
            <a-tag :color="getDeliveryStatusColor(record.status)">
              {{ getDeliveryStatusText(record.status) }}
            </a-tag>
          </template>
          <template v-if="column.key === 'created_at'">
            {{ formatDotDateTime(record.created_at) }}
          </template>
        </template>
      </a-table>
    </a-modal>

    <!-- 我的维修记录弹窗 -->
    <a-modal 
      v-model:open="showMaintenanceRecordsModal" 
      title="我的维修记录" 
      :footer="null" 
      width="720px"
      class="records-modal"
    >
      <a-table 
        :dataSource="maintenanceRecords" 
        :columns="maintenanceColumns" 
        :loading="maintenanceRecordsLoading" 
        :pagination="{ pageSize: 5 }" 
        size="middle"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'status'">
            <a-tag :color="getMaintenanceStatusColor(record.status)">
              {{ getMaintenanceStatusText(record.status) }}
            </a-tag>
          </template>
          <template v-if="column.key === 'priority'">
            <a-tag :color="getPriorityColor(record.priority)">
              {{ getPriorityText(record.priority) }}
            </a-tag>
          </template>
          <template v-if="column.key === 'created_at'">
            {{ formatDotDateTime(record.created_at) }}
          </template>
        </template>
      </a-table>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, nextTick, computed, onMounted, onUnmounted, watch } from 'vue'
import { message } from 'ant-design-vue'
import {
  SendOutlined,
  PhoneOutlined,
  MessageOutlined,
  ShoppingOutlined,
  ToolOutlined,
  ClearOutlined,
  RightOutlined,
  RobotOutlined,
  UserOutlined,
  EditOutlined,
  SoundOutlined,
  HomeOutlined,
  CloseOutlined,
  FileTextOutlined,
  CustomerServiceOutlined,
  WifiOutlined,
  LoadingOutlined,
  BulbOutlined,
  HistoryOutlined,
  CoffeeOutlined,
  SkinOutlined,
  InboxOutlined,
  ThunderboltOutlined,
  CloudOutlined
} from '@ant-design/icons-vue'
import { useRoute, useRouter } from 'vue-router'
import { useAppStore } from '@/stores/app'
import { useHotelStore } from '@/stores/hotel'
import { deliveryApi } from '@/api/delivery'
import { maintenanceApi } from '@/api/maintenance'
import { callApi } from '@/api/call'
import { getSocket } from '@/utils/websocket'
import request from '@/api/request'
import { formatDotDateTime, now } from '@/utils/date'

const route = useRoute()
const router = useRouter()
const appStore = useAppStore()
const hotelStore = useHotelStore()

let socket: any = null
const isCheckedIn = computed(() => !!appStore.userStatus?.is_checked_in)
const roomIdDisplay = computed(() => {
  if (appStore.userStatus?.is_checked_in) {
    const info = appStore.userStatus.checkin_info
    return info.room_number || info.room_id || '101'
  }
  return '未入住'
})

// AI Butler 状态
const inputText = ref('')
const aiThinking = ref(false)
const chatContainerRef = ref<HTMLDivElement>()
const chatMessages = ref<{ type: 'user' | 'ai'; text: string; time: string; typing?: boolean }[]>([])
const isTyping = ref(false)
const displayedText = ref('')
const suggestions = ref<string[]>([])

// 服务中心状态
const showDeliveryModal = ref(false)
const deliveryLoading = ref(false)
const deliveryForm = reactive({ category: 'beverage', item_name: '', quantity: 1, note: '' })

const showMaintenanceModal = ref(false)
const maintenanceLoading = ref(false)
const maintenanceForm = reactive({ fault_type: 'electric', fault_description: '', priority: 'medium' as any })

// 我的记录状态
const showDeliveryRecordsModal = ref(false)
const deliveryRecordsLoading = ref(false)
const deliveryRecords = ref<any[]>([])

const showMaintenanceRecordsModal = ref(false)
const maintenanceRecordsLoading = ref(false)
const maintenanceRecords = ref<any[]>([])

// 表格列定义
const deliveryColumns = [
  { title: '订单号', dataIndex: 'order_no', key: 'order_no', width: 140 },
  { title: '物品', dataIndex: 'item_name', key: 'item_name' },
  { title: '数量', dataIndex: 'quantity', key: 'quantity', width: 80 },
  { title: '状态', key: 'status', width: 100 },
  { title: '时间', key: 'created_at', width: 160 }
]

const maintenanceColumns = [
  { title: '工单号', dataIndex: 'ticket_no', key: 'ticket_no', width: 140 },
  { title: '故障类型', dataIndex: 'fault_type', key: 'fault_type', width: 120 },
  { title: '描述', dataIndex: 'fault_description', key: 'fault_description', ellipsis: true },
  { title: '优先级', key: 'priority', width: 90 },
  { title: '状态', key: 'status', width: 100 },
  { title: '时间', key: 'created_at', width: 160 }
]

const messageModalVisible = ref(false)
const msgContent = ref('')

const transferModal = ref({
  visible: false,
  statusText: '正在为您转接前台...',
  statusDesc: '正在呼叫前台，请稍候...',
  callId: ''
})

const quickChips = [
  { icon: 'BulbOutlined', label: '开灯', text: '打开灯光' },
  { icon: 'ClearOutlined', label: '保洁', text: '需要保洁服务' },
  { icon: 'CoffeeOutlined', label: '送餐', text: '需要送餐服务' },
  { icon: 'WifiOutlined', label: 'WiFi', text: '查询酒店WiFi密码' },
  { icon: 'CustomerServiceOutlined', label: '人工', text: '转接人工' }
]

const suggestionMap: Record<string, string[]> = {
  '灯光': ['调暗一点', '关闭灯光', '打开所有灯'],
  '保洁': ['现在就来', '1小时后', '只整理床铺'],
  'WiFi': ['连接不上', '密码是什么', '网速太慢'],
  '默认': ['还需要什么帮助？', '查询酒店设施', '叫醒服务']
}

onMounted(async () => {
  if (!appStore.userInfo) {
    message.warning('请先登录以查看客房服务')
    appStore.showLoginModal = true
    router.push('/guest/booking')
    return
  }
  
  if (!appStore.userStatus?.is_checked_in) {
    message.warning('您当前未入住，无法使用客房服务。请先在预入住页面选房或到前台办理。')
    router.push('/guest/checkin-online')
    return
  }

  const hotelId = appStore.userStatus?.checkin_info?.hotel_id
  await hotelStore.fetchHotelInfo(hotelId)
  initWebSocket()
})

onUnmounted(() => {
  if (socket) {
    socket.off('call_answered', handleCallAnswered)
    socket.off('call_hungup', handleCallHungup)
    socket.off('connect', registerAsRoom)
  }
})

function registerAsRoom() {
  const roomId = appStore.userStatus?.checkin_info?.room_id
  if (socket && socket.connected && roomId) {
    socket.emit('register_client', { clientType: 'room', clientId: String(roomId) })
  }
}

function handleCallAnswered(data: any) {
  if (data.call_id === transferModal.value.callId || transferModal.value.visible) {
    transferModal.value.visible = false
    message.success('前台已接听，正在建立连接...')
  }
}

function handleCallHungup(data: any) {
  if (data.call_id === transferModal.value.callId) {
    transferModal.value.visible = false
    message.info('通话已结束')
  }
}

function initWebSocket() {
  socket = getSocket()
  if (socket) {
    socket.on('connect', registerAsRoom)
    if (socket.connected) {
      registerAsRoom()
    }
    socket.on('call_answered', handleCallAnswered)
    socket.on('call_hungup', handleCallHungup)
  }
}

function hangupCall() {
  if (appStore.currentCall?.call_id) {
    socket?.emit('hangup_call', { call_id: appStore.currentCall.call_id })
  }
}

function cancelTransfer() {
  if (transferModal.value.callId) {
    socket?.emit('hangup_call', { call_id: transferModal.value.callId })
    appStore.clearCurrentCall()
  }
  transferModal.value.visible = false
}

// AI Butler Logic
function typeWriterEffect(text: string, callback?: () => void) {
  isTyping.value = true
  displayedText.value = ''
  let index = 0
  const typeChar = () => {
    if (index < text.length) {
      displayedText.value += text.charAt(index)
      index++
      scrollToBottom()
      setTimeout(typeChar, 30 + Math.random() * 20)
    } else {
      isTyping.value = false
      if (callback) callback()
    }
  }
  typeChar()
}

async function sendMessage() {
  const text = inputText.value.trim()
  if (!text || aiThinking.value) return
  inputText.value = ''
  await sendToAI(text)
}

function askQuick(q: string) {
  inputText.value = ''
  sendToAI(q)
}

async function sendToAI(text: string) {
  chatMessages.value.push({ type: 'user', text, time: now().format('HH:mm') })
  scrollToBottom()
  aiThinking.value = true

  try {
    const roomId = appStore.userStatus?.checkin_info?.room_id || appStore.userStatus?.checkin_info?.room_number || '101'
    const res: any = await request.post('/ai-butler/chat', {
      room_id: String(roomId),
      text: text,
      session_id: `${roomId}_${Date.now()}`
    })

    if (res.code === 200) {
      const aiResponse = res.data
      const aiText = aiResponse.text || '抱歉，我没有理解您的意思，请换个说法试试？'

      chatMessages.value.push({ type: 'ai', text: aiText, time: now().format('HH:mm'), typing: true })

      typeWriterEffect(aiText, () => {
        let matchedKey = '默认'
        for (const key of Object.keys(suggestionMap)) { 
          if (text.includes(key)) { matchedKey = key; break } 
        }
        suggestions.value = suggestionMap[matchedKey] || suggestionMap['默认']
        
        const lastMsg = chatMessages.value[chatMessages.value.length - 1]
        if (lastMsg) lastMsg.typing = false
        if (aiResponse.audioUrl) playAudio(aiResponse.audioUrl)
      })

      if (aiResponse.action === 'transfer') {
        setTimeout(() => {
          transferModal.value.visible = true
          transferModal.value.callId = aiResponse.callId || ''
        }, 1000)
      }
    }
  } catch (error) {
    chatMessages.value.push({ type: 'ai', text: '抱歉，我现在有点忙，请稍后再试。', time: now().format('HH:mm') })
  } finally {
    aiThinking.value = false
    scrollToBottom()
  }
}

// Audio Logic
const audioPlayer = ref<HTMLAudioElement | null>(null)
const isPlayingAudio = ref(false)

function playAudio(base64Audio: string) {
  if (audioPlayer.value) { audioPlayer.value.pause(); audioPlayer.value = null }
  const audio = new Audio(`data:audio/mp3;base64,${base64Audio}`)
  audioPlayer.value = audio
  isPlayingAudio.value = true
  audio.onended = () => isPlayingAudio.value = false
  audio.play().catch(() => isPlayingAudio.value = false)
}

function toggleAudio() {
  if (!audioPlayer.value) return
  if (isPlayingAudio.value) { audioPlayer.value.pause(); isPlayingAudio.value = false }
  else { audioPlayer.value.play(); isPlayingAudio.value = true }
}

// Service center actions
async function requestDelivery() {
  if (!deliveryForm.item_name) return message.warning('请填写物品名称')
  const roomId = appStore.userStatus?.checkin_info?.room_id
  if (!roomId) return message.warning('请先办理入住')
  
  deliveryLoading.value = true
  try {
    await deliveryApi.create({
      room_id: Number(roomId),
      item_category: deliveryForm.category as any,
      item_name: deliveryForm.item_name,
      quantity: deliveryForm.quantity,
      note: deliveryForm.note
    })
    message.success('送物请求已提交')
    showDeliveryModal.value = false
    Object.assign(deliveryForm, { category: 'beverage', item_name: '', quantity: 1, note: '' })
  } catch (e) {
    message.error('提交失败')
  } finally {
    deliveryLoading.value = false
  }
}

async function requestMaintenance() {
  if (!maintenanceForm.fault_description) return message.warning('请描述故障情况')
  const roomId = appStore.userStatus?.checkin_info?.room_id
  if (!roomId) return message.warning('请先办理入住')

  maintenanceLoading.value = true
  try {
    await maintenanceApi.create({
      room_id: Number(roomId),
      fault_type: maintenanceForm.fault_type,
      fault_description: maintenanceForm.fault_description,
      priority: maintenanceForm.priority
    })
    message.success('报修申请已提交，维修人员将尽快联系您')
    showMaintenanceModal.value = false
    Object.assign(maintenanceForm, { fault_type: 'electric', fault_description: '', priority: 'medium' })
  } catch (e) {
    message.error('提交失败')
  } finally {
    maintenanceLoading.value = false
  }
}

async function callFrontDesk() {
  const roomId = appStore.userStatus?.checkin_info?.room_id || appStore.userStatus?.checkin_info?.room_number || '101'
  if (!roomId) return message.warning('请先办理入住')
  try {
    const res: any = await callApi.outbound({
      caller_type: 'room',
      caller_id: String(roomId),
      callee_type: 'front_desk',
      callee_id: 'all',
      type: 'voice'
    })
    
    if (res.data?.call_id) {
      const callId = res.data.call_id
      transferModal.value.callId = callId
      transferModal.value.visible = true
      transferModal.value.statusText = '正在呼叫前台'
      transferModal.value.statusDesc = '正在为您接通前台，请稍候...'
      
      appStore.setCurrentCall({
        call_id: callId,
        caller_id: String(roomId),
        caller_type: 'room',
        callee_id: 'all',
        callee_type: 'front_desk',
        status: 'calling'
      })
    } else {
      message.error('呼叫请求失败')
    }
  } catch (e) {
    message.error('呼叫失败')
  }
}

function showMessagePanel() { messageModalVisible.value = true }
async function sendMsgToReception() {
  if (!msgContent.value.trim()) return message.warning('请输入留言内容')
  message.success('消息已发送至前台')
  msgContent.value = ''
  messageModalVisible.value = false
}

// 我的记录方法
async function showMyDeliveryRecords() {
  if (!appStore.userStatus?.is_checked_in) {
    message.warning('请先办理入住')
    return
  }
  showDeliveryRecordsModal.value = true
  deliveryRecordsLoading.value = true
  try {
    const res: any = await deliveryApi.getList({ pageSize: 50 })
    deliveryRecords.value = res.data?.list || res.data?.data?.list || []
  } catch (e) {
    message.error('获取配送记录失败')
  } finally {
    deliveryRecordsLoading.value = false
  }
}

async function showMyMaintenanceRecords() {
  if (!appStore.userStatus?.is_checked_in) {
    message.warning('请先办理入住')
    return
  }
  showMaintenanceRecordsModal.value = true
  maintenanceRecordsLoading.value = true
  try {
    const res: any = await maintenanceApi.getList({ pageSize: 50 })
    maintenanceRecords.value = res.data?.list || res.data?.data?.list || []
  } catch (e) {
    message.error('获取维修记录失败')
  } finally {
    maintenanceRecordsLoading.value = false
  }
}

// 状态转换函数
function getDeliveryStatusColor(status: string) {
  const colorMap: Record<string, string> = {
    pending: 'warning',
    delivering: 'processing',
    completed: 'success'
  }
  return colorMap[status] || 'default'
}

function getDeliveryStatusText(status: string) {
  const textMap: Record<string, string> = {
    pending: '待处理',
    delivering: '配送中',
    completed: '已完成'
  }
  return textMap[status] || status
}

function getMaintenanceStatusColor(status: string) {
  const colorMap: Record<string, string> = {
    pending: 'warning',
    assigned: 'processing',
    processing: 'processing',
    completed: 'success'
  }
  return colorMap[status] || 'default'
}

function getMaintenanceStatusText(status: string) {
  const textMap: Record<string, string> = {
    pending: '待处理',
    assigned: '已分配',
    processing: '处理中',
    completed: '已完成'
  }
  return textMap[status] || status
}

function getPriorityColor(priority: string) {
  const colorMap: Record<string, string> = {
    low: 'success',
    medium: 'processing',
    high: 'warning',
    urgent: 'error'
  }
  return colorMap[priority] || 'default'
}

function getPriorityText(priority: string) {
  const textMap: Record<string, string> = {
    low: '普通',
    medium: '一般',
    high: '紧急',
    urgent: '特急'
  }
  return textMap[priority] || priority
}

function scrollToBottom() {
  nextTick(() => { 
    if (chatContainerRef.value) {
      chatContainerRef.value.scrollTop = chatContainerRef.value.scrollHeight 
    }
  })
}
</script>

<style scoped>
.guest-room-page {
  min-height: calc(100vh - 76px - 220px);
}

/* ==================== 页面头部 ==================== */
.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 28px;
}

.room-info {
  display: flex;
  align-items: center;
  gap: 18px;
}

.room-icon {
  width: 60px;
  height: 60px;
  background: linear-gradient(135deg, var(--hotel-primary) 0%, var(--hotel-primary-light) 100%);
  border-radius: var(--hotel-radius-lg);
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-size: 30px;
  box-shadow: 
    0 6px 20px rgba(26, 43, 74, 0.25),
    0 0 0 2px rgba(201, 169, 98, 0.2);
  position: relative;
  overflow: hidden;
}

.room-icon::before {
  content: '';
  position: absolute;
  top: -50%;
  left: -50%;
  width: 200%;
  height: 200%;
  background: linear-gradient(
    45deg,
    transparent 30%,
    rgba(255, 255, 255, 0.1) 50%,
    transparent 70%
  );
  animation: iconShine 3s ease-in-out infinite;
}

@keyframes iconShine {
  0%, 100% { transform: translateX(-100%) rotate(45deg); }
  50% { transform: translateX(100%) rotate(45deg); }
}

.room-details h1 {
  font-size: 26px;
  font-weight: 800;
  color: var(--hotel-primary);
  margin: 0 0 6px;
}

.room-details p {
  font-size: 14px;
  color: var(--hotel-text-muted);
  margin: 0;
}

.connection-badge {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 20px;
  background: rgba(26, 43, 74, 0.05);
  border-radius: 24px;
  font-size: 14px;
  color: var(--hotel-text-muted);
  border: 1px solid rgba(26, 43, 74, 0.08);
  transition: all 0.3s;
}

.connection-badge:hover {
  background: rgba(26, 43, 74, 0.08);
}

.connection-badge.online {
  color: var(--hotel-success);
  background: rgba(39, 174, 96, 0.1);
  border-color: rgba(39, 174, 96, 0.2);
  box-shadow: 0 0 20px rgba(39, 174, 96, 0.15);
}

/* ==================== AI Card - 炫酷玻璃态 ==================== */
.ai-card {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border-radius: var(--hotel-radius-xl);
  box-shadow: 
    0 8px 32px rgba(26, 43, 74, 0.1),
    0 0 0 1px rgba(201, 169, 98, 0.1);
  overflow: hidden;
  height: calc(100vh - 200px);
  display: flex;
  flex-direction: column;
  border: 1px solid rgba(255, 255, 255, 0.5);
}

.ai-header {
  padding: 22px 28px;
  background: linear-gradient(135deg, var(--hotel-primary) 0%, var(--hotel-primary-light) 100%);
  color: #fff;
  display: flex;
  justify-content: space-between;
  align-items: center;
  position: relative;
  overflow: hidden;
}

.ai-header::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.1), transparent);
  animation: headerShine 4s ease-in-out infinite;
}

@keyframes headerShine {
  0%, 100% { transform: translateX(-100%); }
  50% { transform: translateX(100%); }
}

.ai-title {
  display: flex;
  align-items: center;
  gap: 14px;
  font-size: 19px;
  font-weight: 700;
  position: relative;
  z-index: 1;
}

.ai-icon {
  font-size: 26px;
  filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.2));
}

.ai-status {
  background: rgba(255, 255, 255, 0.2);
  backdrop-filter: blur(8px);
  border: 1px solid rgba(255, 255, 255, 0.3);
  color: #fff;
  border-radius: 24px;
  padding: 6px 16px;
  display: flex;
  align-items: center;
  gap: 8px;
  font-weight: 600;
  position: relative;
  z-index: 1;
}

.ai-status .status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.5);
}

.ai-status.active .status-dot {
  background: #4ade80;
  box-shadow: 0 0 8px #4ade80;
  animation: statusPulse 2s infinite;
}

@keyframes statusPulse {
  0%, 100% { 
    transform: scale(1); 
    box-shadow: 0 0 8px #4ade80;
  }
  50% { 
    transform: scale(1.3); 
    box-shadow: 0 0 16px #4ade80;
  }
}

.ai-body {
  flex: 1;
  display: flex;
  flex-direction: column;
  background: linear-gradient(180deg, var(--hotel-bg) 0%, rgba(250, 248, 245, 0.8) 100%);
}

.chat-messages {
  flex: 1;
  overflow-y: auto;
  padding: 28px;
}

/* ==================== 欢迎区域 ==================== */
.welcome-section {
  text-align: center;
  padding: 70px 24px;
}

.welcome-avatar {
  width: 110px;
  height: 110px;
  background: linear-gradient(135deg, var(--hotel-primary) 0%, var(--hotel-primary-light) 100%);
  color: #fff;
  border-radius: 50%;
  margin: 0 auto 28px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 52px;
  position: relative;
  box-shadow: 
    0 8px 30px rgba(26, 43, 74, 0.25),
    0 0 0 4px rgba(201, 169, 98, 0.15);
}

.welcome-avatar.thinking::after {
  content: '';
  position: absolute;
  top: -12px;
  left: -12px;
  right: -12px;
  bottom: -12px;
  border: 2px solid var(--hotel-gold);
  border-radius: 50%;
  animation: ringPulse 1.5s infinite;
  box-shadow: 0 0 20px rgba(201, 169, 98, 0.3);
}

@keyframes ringPulse {
  0% { transform: scale(1); opacity: 1; }
  100% { transform: scale(1.15); opacity: 0; }
}

.welcome-section h2 {
  font-size: 24px;
  font-weight: 700;
  color: var(--hotel-primary);
  margin-bottom: 10px;
}

.welcome-section p {
  color: var(--hotel-text-muted);
  font-size: 15px;
}

/* ==================== 消息样式 ==================== */
.message-row {
  display: flex;
  gap: 14px;
  margin-bottom: 24px;
  max-width: 85%;
  animation: messageSlideIn 0.3s ease-out;
}

@keyframes messageSlideIn {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.message-row.user {
  margin-left: auto;
  flex-direction: row-reverse;
}

.message-avatar {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
  flex-shrink: 0;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.message-row.ai .message-avatar {
  background: linear-gradient(135deg, var(--hotel-primary) 0%, var(--hotel-primary-light) 100%);
  color: #fff;
}

.message-row.user .message-avatar {
  background: linear-gradient(135deg, var(--hotel-gold-dark) 0%, var(--hotel-gold) 100%);
  color: #fff;
}

.message-content {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.message-bubble {
  padding: 16px 20px;
  border-radius: var(--hotel-radius-lg);
  font-size: 15px;
  line-height: 1.7;
  box-shadow: 0 2px 12px rgba(26, 43, 74, 0.06);
}

.message-row.ai .message-bubble {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(8px);
  border-bottom-left-radius: 6px;
  color: var(--hotel-text);
  border: 1px solid rgba(201, 169, 98, 0.1);
}

.message-row.user .message-bubble {
  background: linear-gradient(135deg, var(--hotel-primary) 0%, var(--hotel-primary-light) 100%);
  color: #fff;
  border-bottom-right-radius: 6px;
}

.message-bubble.typing .cursor {
  display: inline-block;
  width: 2px;
  height: 1em;
  background: var(--hotel-gold);
  margin-left: 3px;
  animation: cursorBlink 0.8s infinite;
}

@keyframes cursorBlink {
  0%, 50% { opacity: 1; }
  51%, 100% { opacity: 0; }
}

.thinking-indicator {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px 20px;
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(8px);
  border-radius: var(--hotel-radius-lg);
  color: var(--hotel-text-muted);
  font-size: 14px;
  border: 1px solid rgba(201, 169, 98, 0.1);
}

.audio-indicator {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 12px;
  color: var(--hotel-primary);
  background: rgba(26, 43, 74, 0.05);
  padding: 8px 16px;
  border-radius: 24px;
  width: fit-content;
  border: 1px solid rgba(26, 43, 74, 0.08);
}

/* ==================== 建议区域 ==================== */
.suggestions-section {
  margin-top: 20px;
}

.suggestions-label {
  font-size: 13px;
  color: var(--hotel-text-muted);
  margin-bottom: 12px;
  display: flex;
  align-items: center;
  gap: 8px;
}

.suggestions-list {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.suggestion-chip {
  padding: 10px 18px;
  background: rgba(255, 255, 255, 0.9);
  border: 1px solid rgba(201, 169, 98, 0.2);
  border-radius: 24px;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.3s;
  font-weight: 500;
}

.suggestion-chip:hover {
  color: var(--hotel-gold);
  border-color: var(--hotel-gold);
  background: rgba(201, 169, 98, 0.08);
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(201, 169, 98, 0.15);
}

/* ==================== 输入区域 ==================== */
.chat-input-area {
  padding: 22px 28px;
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(8px);
  border-top: 1px solid rgba(201, 169, 98, 0.1);
}

.quick-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  margin-bottom: 18px;
  justify-content: center;
}

.action-chip {
  padding: 10px 18px;
  background: linear-gradient(135deg, rgba(26, 43, 74, 0.05) 0%, rgba(201, 169, 98, 0.08) 100%);
  border-radius: 24px;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.3s;
  display: flex;
  align-items: center;
  gap: 8px;
  font-weight: 500;
  border: 1px solid rgba(201, 169, 98, 0.15);
}

.action-chip:hover {
  background: linear-gradient(135deg, var(--hotel-primary) 0%, var(--hotel-primary-light) 100%);
  color: #fff;
  transform: translateY(-2px);
  box-shadow: 0 4px 15px rgba(26, 43, 74, 0.2);
}

.input-wrapper {
  display: flex;
  gap: 14px;
  align-items: center;
}

.chat-input {
  border-radius: var(--hotel-radius-lg);
  border: 1px solid rgba(201, 169, 98, 0.2);
}

.chat-input :deep(.ant-input) {
  border-radius: var(--hotel-radius-lg);
}

.chat-input:focus-within {
  border-color: var(--hotel-gold);
  box-shadow: 0 0 0 3px rgba(201, 169, 98, 0.1);
}

.input-icon {
  color: var(--hotel-text-muted);
}

.send-btn {
  border-radius: var(--hotel-radius-lg);
  width: 52px;
  height: 52px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0;
  background: linear-gradient(135deg, var(--hotel-gold-dark) 0%, var(--hotel-gold) 100%);
  border: none;
  box-shadow: 0 4px 15px rgba(201, 169, 98, 0.4);
  transition: all 0.3s;
}

.send-btn:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(201, 169, 98, 0.5);
}

/* ==================== 服务卡片 ==================== */
.service-card {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(20px);
  border-radius: var(--hotel-radius-xl);
  box-shadow: 
    0 8px 32px rgba(26, 43, 74, 0.1),
    0 0 0 1px rgba(201, 169, 98, 0.1);
  overflow: hidden;
  border: 1px solid rgba(255, 255, 255, 0.5);
}

.service-header {
  padding: 22px 28px;
  background: linear-gradient(135deg, rgba(26, 43, 74, 0.03) 0%, rgba(201, 169, 98, 0.05) 100%);
  border-bottom: 1px solid rgba(201, 169, 98, 0.1);
  display: flex;
  align-items: center;
  gap: 12px;
  font-size: 19px;
  font-weight: 700;
  color: var(--hotel-primary);
}

.service-header :deep(.anticon) {
  font-size: 24px;
  color: var(--hotel-gold);
  filter: drop-shadow(0 2px 4px rgba(201, 169, 98, 0.3));
}

.service-list {
  padding: 18px;
}

.service-item {
  display: flex;
  align-items: center;
  gap: 18px;
  padding: 18px;
  border-radius: var(--hotel-radius-lg);
  cursor: pointer;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  margin-bottom: 10px;
  border: 1px solid transparent;
}

.service-item:last-child {
  margin-bottom: 0;
}

.service-item:hover {
  background: linear-gradient(135deg, rgba(26, 43, 74, 0.03) 0%, rgba(201, 169, 98, 0.05) 100%);
  transform: translateX(6px);
  border-color: rgba(201, 169, 98, 0.2);
  box-shadow: 0 4px 15px rgba(201, 169, 98, 0.1);
}

.service-icon {
  width: 52px;
  height: 52px;
  border-radius: var(--hotel-radius);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 24px;
  flex-shrink: 0;
  transition: all 0.3s;
}

.service-item:hover .service-icon {
  transform: scale(1.1);
}

.service-icon.delivery {
  background: rgba(52, 152, 219, 0.12);
  color: var(--hotel-info);
}

.service-icon.call {
  background: rgba(39, 174, 96, 0.12);
  color: var(--hotel-success);
}

.service-icon.message {
  background: rgba(243, 156, 18, 0.12);
  color: var(--hotel-warning);
}

.service-icon.repair {
  background: rgba(231, 76, 60, 0.12);
  color: var(--hotel-error);
}

.service-icon.cleaning {
  background: rgba(201, 169, 98, 0.15);
  color: var(--hotel-gold);
}

.service-icon.records {
  background: rgba(149, 165, 166, 0.12);
  color: var(--hotel-text-secondary);
}

.service-info {
  flex: 1;
}

.service-name {
  font-weight: 700;
  font-size: 15px;
  color: var(--hotel-text);
  margin-bottom: 4px;
}

.service-desc {
  font-size: 12px;
  color: var(--hotel-text-muted);
}

.service-arrow {
  font-size: 14px;
  color: var(--hotel-text-muted);
  transition: transform 0.3s;
}

.service-item:hover .service-arrow {
  transform: translateX(4px);
  color: var(--hotel-gold);
}

/* ==================== 弹窗样式 ==================== */
.service-modal :deep(.ant-modal-content) {
  border-radius: var(--hotel-radius-xl);
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(20px);
}

.service-modal :deep(.ant-modal-header) {
  border-bottom: 1px solid rgba(201, 169, 98, 0.15);
  padding: 22px 28px;
}

.service-modal :deep(.ant-modal-title) {
  font-size: 20px;
  font-weight: 700;
  color: var(--hotel-primary);
}

.service-form :deep(.ant-form-item-label) {
  font-weight: 600;
  color: var(--hotel-text);
}

.calling-modal :deep(.ant-modal-content) {
  border-radius: var(--hotel-radius-xl);
  overflow: hidden;
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(20px);
}

.calling-content {
  text-align: center;
  padding: 48px 24px;
}

.calling-animation {
  position: relative;
  width: 110px;
  height: 110px;
  margin: 0 auto 28px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.pulse-ring {
  position: absolute;
  width: 100%;
  height: 100%;
  border: 2px solid var(--hotel-gold);
  border-radius: 50%;
  animation: callingPulse 2s infinite;
  opacity: 0;
}

.pulse-ring:nth-child(2) {
  animation-delay: 0.6s;
}

.pulse-ring:nth-child(3) {
  animation-delay: 1.2s;
}

@keyframes callingPulse {
  0% {
    transform: scale(0.5);
    opacity: 0.8;
    box-shadow: 0 0 20px rgba(201, 169, 98, 0.3);
  }
  100% {
    transform: scale(1.5);
    opacity: 0;
    box-shadow: 0 0 40px rgba(201, 169, 98, 0);
  }
}

.phone-icon {
  font-size: 44px;
  color: var(--hotel-gold);
  z-index: 1;
  filter: drop-shadow(0 4px 8px rgba(201, 169, 98, 0.3));
}

.calling-content h3 {
  font-size: 22px;
  font-weight: 700;
  color: var(--hotel-primary);
  margin-bottom: 10px;
}

.calling-content p {
  color: var(--hotel-text-muted);
  margin-bottom: 28px;
}

.cancel-btn {
  min-width: 150px;
  height: 48px;
  border-radius: var(--hotel-radius-lg);
  font-weight: 600;
}

.records-modal :deep(.ant-modal-content) {
  border-radius: var(--hotel-radius-xl);
}

.records-modal :deep(.ant-modal-header) {
  border-bottom: 1px solid rgba(201, 169, 98, 0.15);
}

/* ==================== 响应式 ==================== */
@media (max-width: 992px) {
  .ai-card {
    height: auto;
    min-height: 550px;
    margin-bottom: 28px;
  }
}

@media (max-width: 768px) {
  .page-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 18px;
  }
  
  .connection-badge {
    align-self: flex-end;
  }
  
  .chat-messages {
    padding: 20px;
  }
  
  .chat-input-area {
    padding: 18px;
  }
}
</style>
