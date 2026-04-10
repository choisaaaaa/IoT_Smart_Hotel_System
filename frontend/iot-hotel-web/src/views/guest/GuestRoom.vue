<template>
  <div class="guest-room">
    <a-tabs v-model:activeKey="activeTab" centered size="large">
      <a-tab-pane v-if="isCheckedIn" key="butler" tab="🤖 AI 客房管家">
        <div class="ai-butler-container">
          <div class="chat-messages" ref="chatContainerRef">
            <div v-if="chatMessages.length === 0" class="welcome-hint">
              <p>您好，我是AI管家小智，可以帮您控制设备、查询信息、安排服务</p>
            </div>
            <div v-for="(msg, idx) in chatMessages" :key="idx" :class="['message', msg.type]">
              <div class="avatar">
                <a-avatar :style="{ backgroundColor: msg.type === 'ai' ? '#1890ff' : '#52c41a', fontSize: 16 }">
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
                <div v-if="msg.type === 'ai' && idx === chatMessages.length - 1 && isPlayingAudio" class="audio-indicator">
                  <SoundOutlined :spin="isPlayingAudio" />
                  <span>正在播放...</span>
                  <a-button type="link" size="small" @click="toggleAudio">{{ isPlayingAudio ? '暂停' : '播放' }}</a-button>
                </div>
              </div>
            </div>
            <div v-if="aiThinking" class="message ai">
              <div class="avatar"><a-avatar style="background-color: #1890ff; font-size: 16px;"><template #icon><RobotOutlined /></template></a-avatar></div>
              <div class="bubble thinking"><a-spin size="small" /> AI 正在思考...</div>
            </div>
            <div v-if="suggestions.length > 0 && !aiThinking && !isTyping" class="suggestions">
              <span class="suggestion-label">💡 您可能还想问：</span>
              <div class="suggestion-chips">
                <span v-for="(s, sIdx) in suggestions.slice(0, 3)" :key="sIdx" class="suggestion-chip" @click="askQuick(s)">{{ s }}</span>
              </div>
            </div>
          </div>
          <div class="chat-input-area">
            <div v-if="chatMessages.length === 0" class="quick-chips">
              <span v-for="chip in quickChips" :key="chip.text" class="chip" @click="askQuick(chip.text)">
                {{ chip.icon }} {{ chip.label }}
              </span>
            </div>
            <div class="input-row">
              <a-input
                v-model:value="inputText"
                placeholder="输入您的问题，如：打开灯光、需要保洁、查询WiFi..."
                size="large"
                @pressEnter="sendMessage"
                :disabled="aiThinking"
              >
                <template #prefix><EditOutlined style="color: #999;" /></template>
              </a-input>
              <a-button type="primary" size="large" class="send-btn" :loading="aiThinking" :disabled="!inputText.trim() || aiThinking" @click="sendMessage">
                <SendOutlined />
              </a-button>
            </div>
          </div>
        </div>
      </a-tab-pane>

      <a-tab-pane key="delivery" tab="📦 客房送物">
        <a-alert
          v-if="!isCheckedIn"
          message="温馨提示"
          description="请先办理入住手续后再使用客房送物服务"
          type="info"
          show-icon
          style="margin-bottom: 16px;"
        />
        <a-card title="请求配送物品到房间" :bordered="false" :disabled="!isCheckedIn">
          <div v-if="!isCheckedIn" style="position: absolute; top: 0; left: 0; right: 0; bottom: 0; background: rgba(255,255,255,0.8); z-index: 10; display: flex; align-items: center; justify-content: center;">
            <a-button type="primary" @click="$router.push('/guest/checkin-online')">去办理入住</a-button>
          </div>
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
              <a-input v-model:value="deliveryForm.item_name" placeholder="如：矿泉水、方便面、毛巾..." />
            </a-form-item>
            <a-form-item label="数量">
              <a-input-number v-model:value="deliveryForm.quantity" :min="1" :max="20" style="width: 150px;" />
            </a-form-item>
            <a-form-item label="备注">
              <a-textarea v-model:value="deliveryForm.note" :rows="2" placeholder="特殊要求，如：冰镇的、送到床头柜上..." />
            </a-form-item>
            <a-form-item>
              <a-button type="primary" size="large" @click="requestDelivery" :loading="deliveryLoading">
                <SendOutlined /> 提交送物请求
              </a-button>
            </a-form-item>
          </a-form>
        </a-card>
      </a-tab-pane>

      <a-tab-pane key="contact" tab="📞 联系前台">
        <a-alert
          v-if="!isCheckedIn"
          message="温馨提示"
          description="请先办理入住手续后再使用联系前台服务"
          type="info"
          show-icon
          style="margin-bottom: 16px;"
        />
        <div :style="{ opacity: !isCheckedIn ? 0.5 : 1, pointerEvents: !isCheckedIn ? 'none' : 'auto' }">
          <a-row :gutter="[16, 16]">
            <a-col :xs="24" :md="12">
              <a-card hoverable @click="callFrontDesk" class="contact-card">
                <PhoneOutlined style="font-size: 36px; color: #1890ff;" />
                <h3>呼叫前台</h3>
                <p>一键拨打前台电话，即时沟通</p>
                <a-button type="primary" block>立即呼叫</a-button>
              </a-card>
            </a-col>
            <a-col :xs="24" :md="12">
              <a-card hoverable @click="showMessagePanel" class="contact-card">
                <MessageOutlined style="font-size: 36px; color: #52c41a;" />
                <h3>在线留言</h3>
                <p>发送文字消息给前台工作人员</p>
                <a-button block>发送消息</a-button>
              </a-card>
            </a-col>
          </a-row>

          <a-card title="常用服务热线" :bordered="false" style="margin-top: 16px;">
            <a-list :data-source="hotlines" size="small">
              <template #renderItem="{ item }">
                <a-list-item>
                  <a-list-item-meta :title="item.name" :description="item.desc">
                    <template #avatar><component :is="item.icon" style="font-size: 22px; color: #1890ff;" /></template>
                  </a-list-item-meta>
                  <a-tag color="blue">{{ item.number }}</a-tag>
                </a-list-item>
              </template>
            </a-list>
          </a-card>
        </div>
      </a-tab-pane>

      <a-tab-pane key="services" tab="⚙️ 更多服务">
        <a-alert
          v-if="!isCheckedIn"
          message="温馨提示"
          description="请先办理入住手续后再使用更多服务"
          type="info"
          show-icon
          style="margin-bottom: 16px;"
        />
        <div :style="{ opacity: !isCheckedIn ? 0.5 : 1, pointerEvents: !isCheckedIn ? 'none' : 'auto' }">
          <a-row :gutter="[16, 16]">
            <a-col :xs="12" :sm="8" v-for="svc in extraServices" :key="svc.key">
              <a-card hoverable size="small" class="service-tile" @click="handleService(svc)">
                <div style="font-size: 32px; text-align: center; margin-bottom: 8px;">{{ svc.icon }}</div>
                <h4 style="text-align: center;">{{ svc.name }}</h4>
                <p style="text-align: center; font-size: 12px; color: rgba(0,0,0,0.45);">{{ svc.desc }}</p>
              </a-card>
            </a-col>
          </a-row>
        </div>
      </a-tab-pane>
    </a-tabs>

    <a-modal v-model:open="messageModalVisible" title="给前台留言" @ok="sendMsgToReception">
      <a-textarea v-model:value="msgContent" :rows="4" placeholder="请输入您想对前台说的话..." />
    </a-modal>

    <a-modal
      v-model:open="transferModal.visible"
      :footer="null"
      :closable="false"
      :maskClosable="false"
      centered
      width="320px"
    >
      <div style="text-align: center; padding: 20px;">
        <PhoneOutlined style="font-size: 36px; color: #1890ff;" />
        <h3>{{ transferModal.statusText }}</h3>
        <p style="color: #666;">{{ transferModal.statusDesc }}</p>
        <a-button type="primary" danger @click="cancelTransfer">取消呼叫</a-button>
      </div>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, nextTick, computed, onMounted, onUnmounted } from 'vue'
import { message } from 'ant-design-vue'
import {
  SendOutlined, PhoneOutlined, MessageOutlined,
  CarOutlined, MedicineBoxOutlined, ScissorOutlined,
  WifiOutlined, ThunderboltOutlined, SafetyCertificateOutlined,
  RobotOutlined, UserOutlined, EditOutlined, SoundOutlined
} from '@ant-design/icons-vue'
import { useRoute, useRouter } from 'vue-router'
import { useAppStore } from '@/stores/app'
import { useHotelStore } from '@/stores/hotel'
import { deliveryApi } from '@/api/delivery'
import { callApi } from '@/api/call'
import { getSocket } from '@/utils/websocket'
import request from '@/api/request'

const route = useRoute()
const router = useRouter()
const appStore = useAppStore()

const isCheckedIn = computed(() => {
  return !!appStore.userStatus?.is_checked_in
})

function getRoomId(): string {
  if (appStore.userStatus?.is_checked_in) {
    const info = appStore.userStatus.checkin_info
    if (info.room_number) return String(info.room_number)
    if (info.room_id) return String(info.room_id)
  }

  // 兼容逻辑
  try {
    const raw = localStorage.getItem('guest_checkin_info')
    if (raw) {
      const info = JSON.parse(raw)
      if (info.room_number) return String(info.room_number)
      if (info.room_id) return String(info.room_id)
    }
  } catch {}
  return route.params.roomId as string || '101'
}

const hotelStore = useHotelStore()
const activeTab = ref('butler')
const inputText = ref('')
const aiThinking = ref(false)
const chatContainerRef = ref<HTMLDivElement>()
const messageModalVisible = ref(false)
const msgContent = ref('')
const deliveryLoading = ref(false)

const chatMessages = ref<{ type: 'user' | 'ai'; text: string; time: string; typing?: boolean }[]>([])
const isTyping = ref(false)
const displayedText = ref('')
const suggestions = ref<string[]>([])

const quickChips = [
  { icon: '💡', label: '开灯', text: '打开灯光' },
  { icon: '🏠', label: '房间状态', text: '查询房间状态' },
  { icon: '🧹', label: '保洁', text: '需要保洁服务' },
  { icon: '☕', label: '送餐', text: '需要送餐服务' },
  { icon: '📶', label: 'WiFi密码', text: '查询酒店WiFi密码' },
  { icon: '👨‍💼', label: '转人工', text: '转接人工' }
]

const suggestionMap: Record<string, string[]> = {
  '灯光': ['调暗一点', '关闭灯光', '打开所有灯'],
  '空调': ['调到26度', '开启制冷模式', '关闭空调'],
  '保洁': ['现在就来', '1小时后', '只整理床铺'],
  '送餐': ['查看菜单', '30分钟后送达', '素食套餐'],
  'WiFi': ['连接不上怎么办', '密码是什么', '网速太慢'],
  '维修': ['空调不制冷', '水管漏水', '电视没信号'],
  '默认': ['还需要什么帮助？', '查询酒店设施', '叫醒服务']
}

const transferModal = ref({
  visible: false,
  statusText: '正在为您转接前台...',
  statusDesc: '正在呼叫前台，请稍候...',
  frontDeskCount: 0,
  callId: ''
})

const deliveryForm = reactive({ category: 'beverage', item_name: '', quantity: 1, note: '' })

const hotlines = computed(() => [
  { name: '总机前台', desc: '24小时服务', icon: PhoneOutlined, number: hotelStore.hotelInfo?.hotel_phone || '010-12345678' },
  { name: '客房服务中心', desc: '送物、清洁等服务', icon: SendOutlined, number: '分机 8001' },
  { name: '紧急救援', desc: '紧急情况专用', icon: SafetyCertificateOutlined, number: '110 / 120' }
])

const extraServices = [
  { key: 'taxi', name: '叫车服务', icon: '🚗', desc: '预约出租车/专车' },
  { key: 'laundry', name: '洗衣服务', icon: '🧺', desc: '衣物清洗熨烫' },
  { key: 'wake', name: '叫醒服务', icon: '⏰', desc: '定时叫醒' },
  { key: 'parking', name: '停车服务', icon: '🅿️', desc: '代客泊车' },
  { key: 'maintenance', name: '报修服务', icon: '🔧', desc: '设备故障报修' },
  { key: 'extend', name: '续住申请', icon: '📅', desc: '延长住宿时间' }
]

let socket: any = null

onMounted(async () => {
  if (!appStore.userInfo) {
    message.warning('请先登录以查看客房服务')
    appStore.showLoginModal = true
    router.push('/guest/booking')
    return
  }
  if (!isCheckedIn.value) {
    message.info('您还未办理入住，部分功能可能受限')
  }
  await hotelStore.fetchHotelInfo()
  initWebSocket()
})

onUnmounted(() => {
  if (socket) {
    socket.off('incoming_call')
    socket.off('call_answered')
    socket.off('call_hungup')
  }
})

function initWebSocket() {
  socket = getSocket()
  if (socket && socket.connected) {
    socket.emit('register_client', { clientType: 'room', clientId: getRoomId() })
  }
  if (socket) {
    socket.on('connect', () => {
      socket.emit('register_client', { clientType: 'room', clientId: getRoomId() })
    })
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

function updateSuggestions(lastUserMessage: string) {
  let matchedKey = '默认'
  for (const key of Object.keys(suggestionMap)) {
    if (lastUserMessage.includes(key)) { matchedKey = key; break }
  }
  suggestions.value = suggestionMap[matchedKey] || suggestionMap['默认']
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
    const res: any = await request.post('/ai-butler/chat', {
      room_id: getRoomId(),
      text: text,
      session_id: `${getRoomId()}_${Date.now()}`
    })

    if (res.code === 200) {
      const aiResponse = res.data
      const aiText = aiResponse.text || '抱歉，我没有理解您的意思，请换个说法试试？'

      chatMessages.value.push({
        type: 'ai',
        text: aiText,
        time: new Date().toLocaleTimeString(),
        typing: true
      })

      typeWriterEffect(aiText, () => {
        updateSuggestions(text)
        const lastMsg = chatMessages.value[chatMessages.value.length - 1]
        if (lastMsg) lastMsg.typing = false
        if (aiResponse.audioUrl) playAudio(aiResponse.audioUrl)
      })

      scrollToBottom()

      if (aiResponse.action === 'transfer') {
        setTimeout(() => {
          transferModal.value.visible = true
          transferModal.value.callId = aiResponse.callId || ''
          chatMessages.value.push({
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
    chatMessages.value.push({
      type: 'ai',
      text: '🤔 我好像遇到了点问题，不过您可以继续问我其他问题哦~',
      time: new Date().toLocaleTimeString()
    })
    scrollToBottom()
  } finally {
    aiThinking.value = false
  }
}

const audioPlayer = ref<HTMLAudioElement | null>(null)
const isPlayingAudio = ref(false)

function playAudio(base64Audio: string) {
  try {
    if (audioPlayer.value) { audioPlayer.value.pause(); audioPlayer.value = null }
    const audio = new Audio(`data:audio/mp3;base64,${base64Audio}`)
    audioPlayer.value = audio
    isPlayingAudio.value = true
    audio.onended = () => { isPlayingAudio.value = false }
    audio.onerror = () => { isPlayingAudio.value = false }
    const playPromise = audio.play()
    if (playPromise !== undefined) {
      playPromise.catch(() => { isPlayingAudio.value = false })
    }
  } catch { isPlayingAudio.value = false }
}

function toggleAudio() {
  if (!audioPlayer.value) return
  if (isPlayingAudio.value) { audioPlayer.value.pause(); isPlayingAudio.value = false }
  else { audioPlayer.value.play(); isPlayingAudio.value = true }
}

function cancelTransfer() {
  transferModal.value.visible = false
  if (transferModal.value.callId) {
    socket?.emit('hangup_call', { call_id: transferModal.value.callId })
  }
}

function scrollToBottom() {
  nextTick(() => {
    if (chatContainerRef.value) {
      chatContainerRef.value.scrollTop = chatContainerRef.value.scrollHeight
    }
  })
}

function getCheckinInfo(): any | null {
  try {
    const raw = localStorage.getItem('guest_checkin_info')
    return raw ? JSON.parse(raw) : null
  } catch { return null }
}

async function requestDelivery() {
  if (!deliveryForm.item_name) { message.warning('请填写物品名称'); return }
  const parsedInfo = getCheckinInfo()
  if (!parsedInfo?.room_id) { message.warning('未获取到房间信息，请重新办理入住'); return }
  deliveryLoading.value = true
  try {
    await deliveryApi.create({
      room_id: Number(parsedInfo.room_id),
      item_category: deliveryForm.category as 'beverage' | 'food' | 'daily' | 'other',
      item_name: deliveryForm.item_name,
      quantity: deliveryForm.quantity,
      note: deliveryForm.note
    })
    message.success(`送物请求已提交！${deliveryForm.item_name} x${deliveryForm.quantity} 将尽快送达`)
    Object.assign(deliveryForm, { category: 'beverage', item_name: '', quantity: 1, note: '' })
  } catch (error: any) {
    message.error(error?.response?.data?.message || '送物请求提交失败')
  } finally {
    deliveryLoading.value = false
  }
}

async function callFrontDesk() {
  const parsedInfo = getCheckinInfo()
  if (!parsedInfo?.room_id) { message.warning('未获取到房间信息，请重新办理入住'); return }
  try {
    await callApi.outbound({
      caller_type: 'app',
      caller_id: String(parsedInfo.room_id),
      callee_type: 'front_desk',
      callee_id: 'front-desk',
      type: 'voice'
    })
    message.success('已向前台发起呼叫请求')
  } catch (error: any) {
    message.error(error?.response?.data?.message || '呼叫失败，请稍后重试')
  }
}

function showMessagePanel() { messageModalVisible.value = true }
async function sendMsgToReception() {
  if (!msgContent.value.trim()) { message.warning('请输入留言内容'); return }
  message.success('消息已发送至前台')
  msgContent.value = ''
  messageModalVisible.value = false
}

function handleService(svc: any) {
  if (['wake', 'extend', 'maintenance'].includes(svc.key)) {
    activeTab.value = 'butler'
    const map: Record<string, string> = { wake: '设置叫醒服务', extend: '我想续住', maintenance: '报修房间设施' }
    askQuick(map[svc.key])
    return
  }
  message.info(`${svc.name}功能：${svc.desc}`)
}
</script>

<style scoped>
.ai-butler-container { display: flex; flex-direction: column; height: 520px; border: 1px solid #f0f0f0; border-radius: 8px; overflow: hidden; }
.chat-messages { flex: 1; overflow-y: auto; padding: 16px; display: flex; flex-direction: column; gap: 12px; background: #fafafa; }
.welcome-hint { text-align: center; color: #999; padding: 40px 20px; }
.message { display: flex; gap: 10px; max-width: 85%; }
.message.user { align-self: flex-end; flex-direction: row-reverse; }
.bubble { padding: 10px 14px; border-radius: 12px; font-size: 14px; line-height: 1.5; word-break: break-word; }
.message.ai .bubble { background: #fff; border: 1px solid #e8e8e8; border-radius: 12px 12px 12px 4px; }
.message.user .bubble { background: #1890ff; color: #fff; border-radius: 12px 12px 4px 12px; }
.bubble.typing .cursor { display: inline-block; color: #1890ff; font-weight: bold; animation: blink 0.8s infinite; }
@keyframes blink { 0%, 50% { opacity: 1; } 51%, 100% { opacity: 0; } }
.thinking { color: #999; font-size: 13px; }
.bubble-wrapper { display: flex; flex-direction: column; gap: 6px; }
.audio-indicator { display: flex; align-items: center; gap: 8px; padding: 4px 10px; background: #f0f5ff; border-radius: 20px; font-size: 12px; color: #1890ff; }
.suggestions { margin-top: 12px; padding: 10px 14px; background: #f8f9ff; border-radius: 10px; }
.suggestion-label { display: block; font-size: 12px; color: #666; margin-bottom: 6px; }
.suggestion-chips { display: flex; flex-wrap: wrap; gap: 6px; }
.suggestion-chip { padding: 4px 12px; background: #fff; border: 1px solid #e0e5ff; border-radius: 16px; font-size: 12px; color: #5568a3; cursor: pointer; transition: all .2s; }
.suggestion-chip:hover { background: #1890ff; color: #fff; border-color: #1890ff; }
.chat-input-area { padding: 12px 16px; border-top: 1px solid #f0f0f0; background: #fff; }
.quick-chips { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 8px; justify-content: center; }
.chip { padding: 4px 12px; background: linear-gradient(135deg, #667eea, #764ba2); color: #fff; border-radius: 16px; font-size: 12px; cursor: pointer; transition: all .2s; }
.chip:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(102,126,234,.3); }
.input-row { display: flex; gap: 8px; align-items: center; }
.input-row .ant-input { flex: 1; }
.send-btn { border-radius: 50% !important; width: 40px; height: 40px; display: flex; align-items: center; justify-content: center; }
.contact-card { text-align: center; cursor: pointer; transition: transform .2s; }
.contact-card:hover { transform: translateY(-4px); }
.contact-card h3 { margin: 12px 0 4px; }
.contact-card p { color: rgba(0,0,0,0.45); font-size: 13px; margin-bottom: 12px; }
.service-tile { text-align: center; cursor: pointer; transition: transform .2s; }
.service-tile:hover { transform: translateY(-3px); }
.service-tile h4 { margin: 8px 0 4px; font-size: 14px; }
</style>
