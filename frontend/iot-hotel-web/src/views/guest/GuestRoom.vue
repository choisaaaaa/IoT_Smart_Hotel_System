<template>
  <div class="guest-room-new">
    <div class="ota-content-wrapper with-padding">
      <a-row :gutter="24">
        <!-- 左侧：AI 管家交互区 -->
        <a-col :xs="24" :lg="16">
          <div class="ai-interaction-card">
            <div class="card-header-modern">
              <div class="room-status-badge">
                <HomeOutlined /> 房间 {{ roomIdDisplay }}
              </div>
              <div class="ai-title">🤖 AI 智慧管家</div>
              <div class="connection-status" :class="{ online: socket?.connected }">
                {{ socket?.connected ? '在线' : '连接中...' }}
              </div>
            </div>

            <div class="ai-chat-body">
              <div class="chat-messages" ref="chatContainerRef">
                <div v-if="chatMessages.length === 0" class="welcome-section">
                  <div class="ai-avatar-large" :class="{ pulsing: aiThinking }">
                    <RobotOutlined />
                  </div>
                  <h2>您好，我是您的 AI 管家小智</h2>
                  <p>您可以直接跟我说话，或者点击下方的快捷功能</p>
                </div>

                <div v-for="(msg, idx) in chatMessages" :key="idx" :class="['message-row', msg.type]">
                  <div class="avatar">
                    <a-avatar :size="36" :style="{ backgroundColor: msg.type === 'ai' ? '#1890ff' : '#52c41a' }">
                      <template #icon><RobotOutlined v-if="msg.type === 'ai'" /><UserOutlined v-else /></template>
                    </a-avatar>
                  </div>
                  <div class="bubble-wrapper">
                    <div class="bubble" :class="{ typing: msg.typing && isTyping && idx === chatMessages.length - 1 }">
                      <template v-if="msg.typing && isTyping && idx === chatMessages.length - 1">
                        {{ displayedText }}<span class="cursor">|</span>
                      </template>
                      <template v-else>
                        {{ msg.text }}
                      </template>
                    </div>
                    <div v-if="msg.type === 'ai' && idx === chatMessages.length - 1 && isPlayingAudio" class="audio-mini-player">
                      <SoundOutlined :spin="isPlayingAudio" />
                      <span>正在播放 AI 语音</span>
                      <a-button type="link" size="small" @click="toggleAudio">{{ isPlayingAudio ? '暂停' : '播放' }}</a-button>
                    </div>
                  </div>
                </div>

                <div v-if="aiThinking" class="message-row ai">
                  <div class="avatar"><a-avatar :size="36" style="background-color: #1890ff;"><template #icon><RobotOutlined /></template></a-avatar></div>
                  <div class="bubble thinking"><a-spin size="small" /> 正在思考中...</div>
                </div>

                <!-- 智能建议 -->
                <div v-if="suggestions.length > 0 && !aiThinking && !isTyping" class="suggestions-area">
                  <div class="suggestion-label">💡 猜您想问：</div>
                  <div class="suggestion-list">
                    <span v-for="(s, sIdx) in suggestions.slice(0, 3)" :key="sIdx" class="suggestion-item" @click="askQuick(s)">{{ s }}</span>
                  </div>
                </div>
              </div>

              <div class="chat-input-panel">
                <div v-if="chatMessages.length === 0" class="pre-chips">
                  <span v-for="chip in quickChips" :key="chip.text" class="quick-chip" @click="askQuick(chip.text)">
                    {{ chip.icon }} {{ chip.label }}
                  </span>
                </div>
                <div class="input-container">
                  <a-input
                    v-model:value="inputText"
                    placeholder="输入您的问题，如：打开灯光、需要保洁..."
                    size="large"
                    @pressEnter="sendMessage"
                    :disabled="aiThinking"
                    class="modern-input"
                  >
                    <template #prefix><EditOutlined style="color: #bfbfbf;" /></template>
                  </a-input>
                  <a-button type="primary" size="large" class="modern-send-btn" :loading="aiThinking" :disabled="!inputText.trim() || aiThinking" @click="sendMessage">
                    <SendOutlined />
                  </a-button>
                </div>
              </div>
            </div>
          </div>
        </a-col>

        <!-- 右侧：服务中心 -->
        <a-col :xs="24" :lg="8">
          <div class="service-center-card">
            <div class="section-title-modern">服务中心</div>
            
            <div class="service-grid">
              <div class="service-item-card" @click="showDeliveryModal = true">
                <div class="icon-box delivery"><ShoppingOutlined /></div>
                <div class="info">
                  <div class="name">送物服务</div>
                  <div class="desc">配送饮品、日用品</div>
                </div>
                <RightOutlined class="arrow" />
              </div>

              <div class="service-item-card" @click="callFrontDesk">
                <div class="icon-box call"><PhoneOutlined /></div>
                <div class="info">
                  <div class="name">呼叫前台</div>
                  <div class="desc">语音通话即时沟通</div>
                </div>
                <RightOutlined class="arrow" />
              </div>

              <div class="service-item-card" @click="showMessagePanel">
                <div class="icon-box message"><MessageOutlined /></div>
                <div class="info">
                  <div class="name">在线留言</div>
                  <div class="desc">给工作人员留言</div>
                </div>
                <RightOutlined class="arrow" />
              </div>

              <div class="service-item-card" @click="showMaintenanceModal = true">
                <div class="icon-box repair"><ToolOutlined /></div>
                <div class="info">
                  <div class="name">设施报修</div>
                  <div class="desc">房间设备故障报修</div>
                </div>
                <RightOutlined class="arrow" />
              </div>

              <div class="service-item-card" @click="askQuick('需要保洁服务')">
                <div class="icon-box cleaning"><ClearOutlined /></div>
                <div class="info">
                  <div class="name">申请保洁</div>
                  <div class="desc">打扫房间、整理床铺</div>
                </div>
                <RightOutlined class="arrow" />
              </div>
            </div>

            <!-- 常用热线 -->
            <div class="hotlines-section">
              <div class="sub-title">服务热线</div>
              <div class="hotline-list">
                <div v-for="item in hotlines" :key="item.name" class="hotline-item">
                  <div class="h-info">
                    <div class="h-name">{{ item.name }}</div>
                    <div class="h-number">{{ item.number }}</div>
                  </div>
                  <a-button type="link" size="small"><PhoneOutlined /></a-button>
                </div>
              </div>
            </div>
          </div>
        </a-col>
      </a-row>
    </div>

    <!-- 送物弹窗 -->
    <a-modal v-model:open="showDeliveryModal" title="申请送物" @ok="requestDelivery" :confirmLoading="deliveryLoading">
      <a-form :model="deliveryForm" layout="vertical">
        <a-form-item label="物品类别" required>
          <a-select v-model:value="deliveryForm.category">
            <a-select-option value="beverage">🍶 饮品（矿泉水、饮料等）</a-select-option>
            <a-select-option value="food">🍕 食品（方便面、零食等）</a-select-option>
            <a-select-option value="daily">🧴 日用品（毛巾、洗漱用品等）</a-select-option>
            <a-select-option value="other">📦 其他物品</a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item label="物品名称" required>
          <a-input v-model:value="deliveryForm.item_name" placeholder="如：矿泉水、毛巾..." />
        </a-form-item>
        <a-form-item label="数量">
          <a-input-number v-model:value="deliveryForm.quantity" :min="1" :max="20" style="width: 100%;" />
        </a-form-item>
        <a-form-item label="备注">
          <a-textarea v-model:value="deliveryForm.note" :rows="2" placeholder="特殊要求..." />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 报修弹窗 -->
    <a-modal v-model:open="showMaintenanceModal" title="设施报修" @ok="requestMaintenance" :confirmLoading="maintenanceLoading">
      <a-form :model="maintenanceForm" layout="vertical">
        <a-form-item label="故障类型" required>
          <a-select v-model:value="maintenanceForm.fault_type">
            <a-select-option value="electric">🔌 电力/灯光</a-select-option>
            <a-select-option value="water">🚰 水路/卫浴</a-select-option>
            <a-select-option value="ac">❄️ 空调/暖气</a-select-option>
            <a-select-option value="network">🌐 网络/电视</a-select-option>
            <a-select-option value="other">🔧 其他故障</a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item label="故障描述" required>
          <a-textarea v-model:value="maintenanceForm.fault_description" :rows="3" placeholder="请详细描述故障情况，以便维修人员准备工具..." />
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
    <a-modal v-model:open="messageModalVisible" title="给前台留言" @ok="sendMsgToReception">
      <a-textarea v-model:value="msgContent" :rows="4" placeholder="请输入您想对前台说的话..." />
    </a-modal>

    <!-- 通话转接弹窗 -->
    <a-modal
      v-model:open="transferModal.visible"
      :footer="null"
      :closable="false"
      :maskClosable="false"
      centered
      width="320px"
      class="modern-call-modal"
    >
      <div class="call-modal-content">
        <div class="phone-pulse">
          <PhoneOutlined />
        </div>
        <h3>{{ transferModal.statusText }}</h3>
        <p>{{ transferModal.statusDesc }}</p>
        <a-button type="primary" danger shape="round" size="large" @click="cancelTransfer" block>
          取消呼叫
        </a-button>
      </div>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, nextTick, computed, onMounted, onUnmounted } from 'vue'
import { message } from 'ant-design-vue'
import {
  SendOutlined, PhoneOutlined, MessageOutlined,
  ShoppingOutlined, ToolOutlined, ClearOutlined,
  RightOutlined, RobotOutlined, UserOutlined, 
  EditOutlined, SoundOutlined, HomeOutlined,
  SafetyCertificateOutlined
} from '@ant-design/icons-vue'
import { useRoute, useRouter } from 'vue-router'
import { useAppStore } from '@/stores/app'
import { useHotelStore } from '@/stores/hotel'
import { deliveryApi } from '@/api/delivery'
import { maintenanceApi } from '@/api/maintenance'
import { callApi } from '@/api/call'
import { getSocket } from '@/utils/websocket'
import request from '@/api/request'

const route = useRoute()
const router = useRouter()
const appStore = useAppStore()
const hotelStore = useHotelStore()

// 基础状态
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

const messageModalVisible = ref(false)
const msgContent = ref('')

const transferModal = ref({
  visible: false,
  statusText: '正在为您转接前台...',
  statusDesc: '正在呼叫前台，请稍候...',
  callId: ''
})

const quickChips = [
  { icon: '💡', label: '开灯', text: '打开灯光' },
  { icon: '🧹', label: '保洁', text: '需要保洁服务' },
  { icon: '☕', label: '送餐', text: '需要送餐服务' },
  { icon: '📶', label: 'WiFi', text: '查询酒店WiFi密码' },
  { icon: '👨‍💼', label: '人工', text: '转接人工' }
]

const suggestionMap: Record<string, string[]> = {
  '灯光': ['调暗一点', '关闭灯光', '打开所有灯'],
  '保洁': ['现在就来', '1小时后', '只整理床铺'],
  'WiFi': ['连接不上', '密码是什么', '网速太慢'],
  '默认': ['还需要什么帮助？', '查询酒店设施', '叫醒服务']
}

const hotlines = computed(() => [
  { name: '前台总机', icon: PhoneOutlined, number: hotelStore.hotelInfo?.hotel_phone || '010-12345678' },
  { name: '紧急救援', icon: SafetyCertificateOutlined, number: '110 / 120' }
])

let socket: any = null

onMounted(async () => {
  if (!appStore.userInfo) {
    message.warning('请先登录以查看客房服务')
    appStore.showLoginModal = true
    router.push('/guest/booking')
    return
  }
  await hotelStore.fetchHotelInfo()
  initWebSocket()
})

onUnmounted(() => {
  if (socket) {
    socket.off('call_answered')
    socket.off('call_hungup')
  }
})

function initWebSocket() {
  socket = getSocket()
  const roomId = appStore.userStatus?.checkin_info?.room_id || appStore.userStatus?.checkin_info?.room_number || '101'
  if (socket && socket.connected) {
    socket.emit('register_client', { clientType: 'room', clientId: String(roomId) })
  }
  if (socket) {
    socket.on('call_answered', (data: any) => {
      if (data.call_id === transferModal.value.callId) {
        transferModal.value.visible = false
        message.success('前台已接听')
      }
    })
    socket.on('call_hungup', () => {
      transferModal.value.visible = false
    })
  }
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
  chatMessages.value.push({ type: 'user', text, time: new Date().toLocaleTimeString() })
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

      chatMessages.value.push({ type: 'ai', text: aiText, time: new Date().toLocaleTimeString(), typing: true })

      typeWriterEffect(aiText, () => {
        let matchedKey = '默认'
        for (const key of Object.keys(suggestionMap)) { if (text.includes(key)) { matchedKey = key; break } }
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
    chatMessages.value.push({ type: 'ai', text: '🤔 抱歉，我现在有点忙，请稍后再试。', time: new Date().toLocaleTimeString() })
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
  const roomId = appStore.userStatus?.checkin_info?.room_id
  if (!roomId) return message.warning('请先办理入住')
  try {
    await callApi.outbound({
      caller_type: 'app',
      caller_id: String(roomId),
      callee_type: 'front_desk',
      callee_id: 'front-desk',
      type: 'voice'
    })
    transferModal.value.visible = true
    transferModal.value.statusText = '正在呼叫前台'
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

function cancelTransfer() {
  transferModal.value.visible = false
  if (transferModal.value.callId) socket?.emit('hangup_call', { call_id: transferModal.value.callId })
}

function scrollToBottom() {
  nextTick(() => { if (chatContainerRef.value) chatContainerRef.value.scrollTop = chatContainerRef.value.scrollHeight })
}
</script>

<style scoped>
.guest-room-new {
  min-height: calc(100vh - 60px);
  background: #f5f7fa;
}

/* AI Interaction Card */
.ai-interaction-card {
  background: #fff;
  border-radius: 16px;
  box-shadow: 0 4px 20px rgba(0,0,0,0.05);
  display: flex;
  flex-direction: column;
  height: 750px;
  overflow: hidden;
}

.card-header-modern {
  padding: 20px 24px;
  background: linear-gradient(135deg, #1890ff, #722ed1);
  color: #fff;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.room-status-badge {
  background: rgba(255,255,255,0.2);
  padding: 4px 12px;
  border-radius: 20px;
  font-size: 13px;
  display: flex;
  align-items: center;
  gap: 6px;
}

.ai-title {
  font-size: 18px;
  font-weight: 700;
}

.connection-status {
  font-size: 12px;
  opacity: 0.8;
  display: flex;
  align-items: center;
  gap: 4px;
}
.connection-status.online::before {
  content: '';
  width: 8px;
  height: 8px;
  background: #52c41a;
  border-radius: 50%;
}

.ai-chat-body {
  flex: 1;
  display: flex;
  flex-direction: column;
  background: #f9f9f9;
  overflow: hidden;
}

.chat-messages {
  flex: 1;
  overflow-y: auto;
  padding: 24px;
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.welcome-section {
  text-align: center;
  padding: 60px 20px;
}

.ai-avatar-large {
  width: 100px;
  height: 100px;
  background: #e6f7ff;
  color: #1890ff;
  border-radius: 50%;
  margin: 0 auto 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 48px;
  position: relative;
}

.ai-avatar-large.pulsing::after {
  content: '';
  position: absolute;
  top: -10px; left: -10px; right: -10px; bottom: -10px;
  border: 2px solid #1890ff;
  border-radius: 50%;
  animation: pulse 1.5s infinite;
}

@keyframes pulse {
  0% { transform: scale(0.9); opacity: 1; }
  100% { transform: scale(1.3); opacity: 0; }
}

.welcome-section h2 { margin-bottom: 12px; font-weight: 700; }
.welcome-section p { color: #8c8c8c; }

.message-row { display: flex; gap: 12px; max-width: 85%; }
.message-row.user { align-self: flex-end; flex-direction: row-reverse; }

.bubble {
  padding: 12px 16px;
  border-radius: 12px;
  font-size: 15px;
  line-height: 1.6;
  box-shadow: 0 2px 8px rgba(0,0,0,0.05);
}

.ai .bubble { background: #fff; border-radius: 4px 16px 16px 16px; border: 1px solid #f0f0f0; }
.user .bubble { background: #1890ff; color: #fff; border-radius: 16px 4px 16px 16px; }

.bubble.typing .cursor { display: inline-block; width: 2px; height: 1em; background: #1890ff; margin-left: 2px; animation: blink 0.8s infinite; }
@keyframes blink { 0%, 50% { opacity: 1; } 51%, 100% { opacity: 0; } }

.audio-mini-player {
  margin-top: 8px;
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12px;
  color: #1890ff;
  background: #f0f5ff;
  padding: 4px 12px;
  border-radius: 20px;
}

.suggestions-area { margin-top: 12px; }
.suggestion-label { font-size: 13px; color: #8c8c8c; margin-bottom: 8px; }
.suggestion-list { display: flex; flex-wrap: wrap; gap: 8px; }
.suggestion-item {
  padding: 6px 16px;
  background: #fff;
  border: 1px solid #d9d9d9;
  border-radius: 20px;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.2s;
}
.suggestion-item:hover { color: #1890ff; border-color: #1890ff; background: #f0f7ff; }

.chat-input-panel {
  padding: 20px 24px;
  background: #fff;
  border-top: 1px solid #f0f0f0;
}

.pre-chips { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 16px; justify-content: center; }
.quick-chip {
  padding: 6px 14px;
  background: #f5f5f5;
  border-radius: 20px;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.2s;
}
.quick-chip:hover { background: #e6f7ff; color: #1890ff; }

.input-container { display: flex; gap: 12px; align-items: center; }
.modern-input { border-radius: 24px; }
.modern-send-btn { border-radius: 50%; width: 44px; height: 44px; display: flex; align-items: center; justify-content: center; }

/* Service Center Card */
.service-center-card {
  background: #fff;
  border-radius: 16px;
  padding: 24px;
  box-shadow: 0 4px 20px rgba(0,0,0,0.05);
  height: 750px;
  display: flex;
  flex-direction: column;
}

.section-title-modern {
  font-size: 20px;
  font-weight: 800;
  margin-bottom: 24px;
  color: #1a1a1a;
}

.service-grid { display: flex; flex-direction: column; gap: 16px; flex: 1; }

.service-item-card {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 16px;
  background: #f9f9f9;
  border-radius: 12px;
  cursor: pointer;
  transition: all 0.2s;
  border: 1px solid transparent;
}

.service-item-card:hover {
  background: #fff;
  border-color: #1890ff;
  transform: translateX(4px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.05);
}

.icon-box {
  width: 48px;
  height: 48px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 22px;
}

.icon-box.delivery { background: #e6f7ff; color: #1890ff; }
.icon-box.call { background: #f6ffed; color: #52c41a; }
.icon-box.message { background: #fff7e6; color: #fa8c16; }
.icon-box.repair { background: #fff1f0; color: #ff4d4f; }
.icon-box.cleaning { background: #f9f0ff; color: #722ed1; }

.service-item-card .info { flex: 1; }
.service-item-card .name { font-weight: 700; font-size: 15px; margin-bottom: 2px; }
.service-item-card .desc { font-size: 12px; color: #8c8c8c; }
.service-item-card .arrow { font-size: 12px; color: #bfbfbf; }

.hotlines-section { margin-top: 32px; padding-top: 24px; border-top: 1px solid #f0f0f0; }
.hotlines-section .sub-title { font-size: 14px; font-weight: 700; color: #8c8c8c; margin-bottom: 16px; }
.hotline-item { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; }
.h-name { font-size: 14px; font-weight: 600; }
.h-number { font-size: 13px; color: #1890ff; font-family: monospace; }

/* Call Modal */
.call-modal-content { text-align: center; padding: 24px 0; }
.phone-pulse {
  width: 80px;
  height: 80px;
  background: #1890ff;
  color: #fff;
  border-radius: 50%;
  margin: 0 auto 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 36px;
  position: relative;
}
.phone-pulse::after {
  content: '';
  position: absolute;
  width: 100%; height: 100%;
  border: 4px solid #1890ff;
  border-radius: 50%;
  animation: pulse 1.5s infinite;
}

.call-modal-content h3 { font-size: 20px; font-weight: 700; margin-bottom: 8px; }
.call-modal-content p { color: #8c8c8c; margin-bottom: 32px; }
</style>
