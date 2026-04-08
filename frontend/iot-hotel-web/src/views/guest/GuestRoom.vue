<template>
  <div class="guest-room">
    <a-tabs v-model:activeKey="activeTab" centered size="large">
      <a-tab-pane v-if="isCheckedIn" key="butler" tab="🤖 AI 客房管家">
        <div class="chat-container">
          <div class="chat-messages" ref="chatContainerRef">
            <div v-for="(msg, idx) in chatMessages" :key="idx" :class="['message', msg.role]">
              <div class="avatar">
                <a-avatar :style="{ backgroundColor: msg.role === 'assistant' ? '#1890ff' : '#52c41a', fontSize: 18 }">
                  {{ msg.role === 'assistant' ? 'AI' : '我' }}
                </a-avatar>
              </div>
              <div class="bubble">{{ msg.content }}</div>
            </div>
            <div v-if="aiThinking" class="message assistant">
              <div class="avatar"><a-avatar style="background-color: #1890ff; font-size: 18px;">AI</a-avatar></div>
              <div class="bubble thinking"><a-spin size="small" /> AI 正在思考...</div>
            </div>
          </div>
          <div class="chat-input">
            <a-input
              v-model:value="inputText"
              placeholder="输入您的问题，例如：帮我开空调、送两瓶水、叫醒服务等..."
              size="large"
              @pressEnter="sendMessage"
              :disabled="aiThinking"
            >
              <template #suffix>
                <a-button type="primary" shape="circle" :loading="aiThinking" @click="sendMessage">
                  <SendOutlined />
                </a-button>
              </template>
            </a-input>
            <div class="quick-actions">
              <a-tag v-for="q in quickQuestions" :key="q" color="blue" style="cursor: pointer; margin-top: 4px;" @click="askQuick(q)">
                {{ q }}
              </a-tag>
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
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, nextTick, computed, onMounted } from 'vue'
import { message } from 'ant-design-vue'
import {
  SendOutlined, PhoneOutlined, MessageOutlined,
  CarOutlined, MedicineBoxOutlined, ScissorOutlined,
  WifiOutlined, ThunderboltOutlined, SafetyCertificateOutlined
} from '@ant-design/icons-vue'

// 检查是否已办理入住
const isCheckedIn = computed(() => {
  const guestInfo = localStorage.getItem('guest_checkin_info')
  return !!guestInfo
})

const activeTab = ref('butler')
const inputText = ref('')
const aiThinking = ref(false)
const chatContainerRef = ref<HTMLDivElement>()
const messageModalVisible = ref(false)
const msgContent = ref('')
const deliveryLoading = ref(false)

// 页面加载时检查入住状态
onMounted(() => {
  if (!isCheckedIn.value) {
    message.info('您还未办理入住，部分功能可能受限')
  }
})

const chatMessages = ref<{ role: string; content: string }[]>([
  { role: 'assistant', content: '您好！我是智联酒店的 AI 管家 🤖。我可以帮您控制房间设备、请求送物、联系前台等。请问有什么可以帮您的？' }
])

const quickQuestions = ['帮我打开空调', '送两瓶矿泉水', '现在几点了', '明天天气怎么样', '我想续住一晚']

const deliveryForm = reactive({ category: 'beverage', item_name: '', quantity: 1, note: '' })

const hotlines = [
  { name: '总机前台', desc: '24小时服务', icon: PhoneOutlined, number: '010-12345678' },
  { name: '客房服务中心', desc: '送物、清洁等服务', icon: SendOutlined, number: '分机 8001' },
  { name: '紧急救援', desc: '紧急情况专用', icon: SafetyCertificateOutlined, number: '110 / 120' }
]

const extraServices = [
  { key: 'taxi', name: '叫车服务', icon: '🚗', desc: '预约出租车/专车' },
  { key: 'laundry', name: '洗衣服务', icon: '🧺', desc: '衣物清洗熨烫' },
  { key: 'wake', name: '叫醒服务', icon: '⏰', desc: '定时叫醒' },
  { key: 'parking', name: '停车服务', icon: '🅿️', desc: '代客泊车' },
  { key: 'maintenance', name: '报修服务', icon: '🔧', desc: '设备故障报修' },
  { key: 'extend', name: '续住申请', icon: '📅', desc: '延长住宿时间' }
]

async function sendMessage() {
  const text = inputText.value.trim()
  if (!text) return
  chatMessages.value.push({ role: 'user', content: text })
  inputText.value = ''
  aiThinking.value = true
  await nextTick()
  scrollToBottom()

  await new Promise(r => setTimeout(r, 800 + Math.random() * 1200))

  let reply = ''
  if (text.includes('空调') || text.includes('温度')) {
    reply = '好的，已为您将空调设置为制冷模式，温度调至 24°C。如果需要调整温度，随时告诉我哦~'
  } else if (text.includes('水') || text.includes('饮料') || text.includes('送物')) {
    reply = '已为您安排送物服务，矿泉水将在 5-10 分钟内送达您的房间。还需要其他东西吗？'
  } else if (text.includes('时间') || text.includes('几点')) {
    reply = `现在是 ${new Date().toLocaleTimeString('zh-CN')}。需要为您设置叫醒服务吗？`
  } else if (text.includes('天气')) {
    reply = '今天北京天气晴朗，气温 18-26°C，空气质量优。适合外出活动哦~'
  } else if (text.includes('续住')) {
    reply = '好的，我来帮您处理续住事宜。请问您想延长几晚呢？我可以帮您联系前台确认。'
  } else {
    reply = '收到您的需求，我已经转达给相关服务人员。如有其他需要，随时告诉我！😊'
  }

  aiThinking.value = false
  chatMessages.value.push({ role: 'assistant', content: reply })
  await nextTick()
  scrollToBottom()
}

function askQuick(q: string) {
  inputText.value = q
  sendMessage()
}

function scrollToBottom() {
  if (chatContainerRef.value) {
    chatContainerRef.value.scrollTop = chatContainerRef.value.scrollHeight
  }
}

async function requestDelivery() {
  if (!deliveryForm.item_name) { message.warning('请填写物品名称'); return }
  deliveryLoading.value = true
  try {
    await new Promise(r => setTimeout(r, 800))
    message.success(`送物请求已提交！${deliveryForm.item_name} x${deliveryForm.quantity} 将尽快送达`)
    Object.assign(deliveryForm, { category: 'beverage', item_name: '', quantity: 1, note: '' })
  } finally {
    deliveryLoading.value = false
  }
}

function callFrontDesk() { message.info('正在呼叫前台...') }
function showMessagePanel() { messageModalVisible.value = true }
async function sendMsgToReception() {
  if (!msgContent.value.trim()) { message.warning('请输入留言内容'); return }
  message.success('消息已发送至前台')
  msgContent.value = ''
  messageModalVisible.value = false
}
function handleService(svc: any) {
  if (svc.key === 'wake') { activeTab.value = 'butler'; inputText.value = '设置叫醒服务'; sendMessage(); return }
  if (svc.key === 'extend') { activeTab.value = 'butler'; inputText.value = '我想续住'; sendMessage(); return }
  if (svc.key === 'maintenance') { activeTab.value = 'butler'; inputText.value = '报修房间设施'; sendMessage(); return }
  message.info(`${svc.name}功能：${svc.desc}`)
}
</script>

<style scoped>
.chat-container { display: flex; flex-direction: column; height: 500px; border: 1px solid #f0f0f0; border-radius: 8px; overflow: hidden; }
.chat-messages { flex: 1; overflow-y: auto; padding: 16px; display: flex; flex-direction: column; gap: 12px; background: #fafafa; }
.message { display: flex; gap: 10px; max-width: 80%; }
.message.user { align-self: flex-end; flex-direction: row-reverse; }
.bubble {
  padding: 10px 14px;
  border-radius: 12px;
  font-size: 14px;
  line-height: 1.5;
  word-break: break-word;
}
.message.assistant .bubble { background: #fff; border: 1px solid #e8e8e8; border-radius: 12px 12px 12px 4px; }
.message.user .bubble { background: #1890ff; color: #fff; border-radius: 12px 12px 4px 12px; }
.thinking { color: #999; font-size: 13px; }
.chat-input { padding: 12px 16px; border-top: 1px solid #f0f0f0; background: #fff; }
.quick-actions { display: flex; gap: 6px; flex-wrap: wrap; margin-top: 6px; }
.contact-card { text-align: center; cursor: pointer; transition: transform .2s; }
.contact-card:hover { transform: translateY(-4px); }
.contact-card h3 { margin: 12px 0 4px; }
.contact-card p { color: rgba(0,0,0,0.45); font-size: 13px; margin-bottom: 12px; }
.service-tile { text-align: center; cursor: pointer; transition: transform .2s; }
.service-tile:hover { transform: translateY(-3px); }
.service-tile h4 { margin: 8px 0 4px; font-size: 14px; }
</style>