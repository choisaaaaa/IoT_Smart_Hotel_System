<template>
  <div class="room-messages-page">
    <div class="messages-layout">
      <div class="conversations-panel">
        <div class="panel-header">
          <h3>客房留言</h3>
          <a-badge :count="totalUnread" :offset="[6, 0]">
            <a-button size="small" @click="loadConversations">
              <ReloadOutlined /> 刷新
            </a-button>
          </a-badge>
        </div>
        <div class="conversations-list">
          <a-spin :spinning="loadingConversations">
            <div v-if="conversations.length === 0" class="empty-list">
              <MessageOutlined style="font-size: 32px; color: #ccc;" />
              <p>暂无客房留言</p>
            </div>
            <div
              v-for="conv in conversations"
              :key="conv.room_id"
              :class="['conversation-item', { active: selectedRoomId === conv.room_id }]"
              @click="selectConversation(conv)"
            >
              <div class="conv-avatar">
                <HomeOutlined />
              </div>
              <div class="conv-info">
                <div class="conv-top">
                  <span class="conv-room">{{ conv.room_number }}号房</span>
                  <span class="conv-time">{{ formatConvTime(conv.last_message_time) }}</span>
                </div>
                <div class="conv-bottom">
                  <span class="conv-last-msg">{{ conv.last_message || '暂无消息' }}</span>
                  <a-badge v-if="conv.unread_count > 0" :count="conv.unread_count" />
                </div>
              </div>
            </div>
          </a-spin>
        </div>
      </div>

      <div class="chat-panel">
        <div v-if="!selectedRoomId" class="no-chat-selected">
          <CustomerServiceOutlined style="font-size: 48px; color: #ddd;" />
          <p>选择一个房间开始回复留言</p>
        </div>
        <template v-else>
          <div class="chat-header">
            <div class="chat-room-info">
              <HomeOutlined />
              <span>{{ selectedRoomNumber }}号房</span>
              <a-tag v-if="selectedGuestName" color="blue">{{ selectedGuestName }}</a-tag>
            </div>
            <div class="chat-header-actions">
              <a-button size="small" @click="markRoomAllRead" :disabled="selectedUnread === 0">
                全部已读
              </a-button>
              <a-popconfirm title="确定清空该房间的所有留言？" @confirm="clearRoomMessages" ok-text="确定" cancel-text="取消">
                <a-button size="small" danger :disabled="currentMessages.length === 0">
                  <DeleteOutlined /> 清空
                </a-button>
              </a-popconfirm>
            </div>
          </div>
          <div class="chat-body" ref="chatBodyRef">
            <div v-if="loadingMessages" class="chat-loading">
              <a-spin />
            </div>
            <template v-else>
              <div v-if="currentMessages.length === 0" class="chat-empty">
                <p>暂无消息记录</p>
              </div>
              <template v-for="(msg, idx) in currentMessages" :key="msg.id || idx">
                <div v-if="shouldShowTimeSeparator(idx)" class="chat-time-sep">
                  {{ formatMsgTime(msg.created_at) }}
                </div>
                <div :class="['chat-msg-row', msg.sender_type === 'front_desk' ? 'is-me' : 'is-other']">
                  <div v-if="msg.sender_type !== 'front_desk'" class="chat-avatar other-avatar">
                    <UserOutlined />
                  </div>
                  <div class="chat-bubble-wrap">
                    <div v-if="msg.sender_type !== 'front_desk' && msg.sender_name" class="chat-sender-name">
                      {{ msg.sender_name }}
                    </div>
                    <div :class="['chat-bubble', msg.sender_type === 'front_desk' ? 'bubble-me' : 'bubble-other']">
                      {{ msg.content }}
                    </div>
                  </div>
                  <div v-if="msg.sender_type === 'front_desk'" class="chat-avatar me-avatar">
                    <CustomerServiceOutlined />
                  </div>
                </div>
              </template>
            </template>
          </div>
          <div class="chat-input-area">
            <a-textarea
              v-model:value="replyContent"
              :rows="2"
              placeholder="输入回复内容..."
              @pressEnter="handleReplyEnter"
              class="reply-input"
            />
            <a-button type="primary" @click="sendReply" :loading="replySending" class="reply-btn">
              发送
            </a-button>
          </div>
        </template>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, nextTick } from 'vue'
import { $notify } from '@/utils/notify'
import {
  HomeOutlined,
  MessageOutlined,
  UserOutlined,
  CustomerServiceOutlined,
  ReloadOutlined,
  DeleteOutlined,
} from '@ant-design/icons-vue'
import { useAppStore } from '@/stores/app'
import { messageApi, type RoomMessage, type RoomConversation } from '@/api/message'
import { getSocket } from '@/utils/websocket'

const appStore = useAppStore()

const conversations = ref<RoomConversation[]>([])
const loadingConversations = ref(false)
const selectedRoomId = ref<number | null>(null)
const selectedRoomNumber = ref('')
const selectedGuestName = ref('')
const currentMessages = ref<RoomMessage[]>([])
const loadingMessages = ref(false)
const replyContent = ref('')
const replySending = ref(false)
const chatBodyRef = ref<HTMLDivElement>()

let socket: any = null

const totalUnread = computed(() => conversations.value.reduce((sum, c) => sum + (c.unread_count || 0), 0))
const selectedUnread = computed(() => {
  const conv = conversations.value.find(c => c.room_id === selectedRoomId.value)
  return conv?.unread_count || 0
})

onMounted(async () => {
  await loadConversations()
  initSocketListeners()
})

onUnmounted(() => {
  if (socket) {
    socket.off('front_desk_new_message', handleFrontDeskNewMessage)
    socket.off('new_room_message', handleNewRoomMessage)
  }
})

function initSocketListeners() {
  socket = getSocket()
  if (socket) {
    socket.on('front_desk_new_message', handleFrontDeskNewMessage)
    socket.on('new_room_message', handleNewRoomMessage)
  }
}

function handleFrontDeskNewMessage(data: any) {
  const msg = data.message || data
  if (!msg) return
  updateConversationFromMsg(msg)
  if (msg.room_id === selectedRoomId.value) {
    const exists = currentMessages.value.some(m => m.id === msg.id)
    if (!exists) {
      currentMessages.value.push(msg)
      nextTick(() => scrollChatToBottom())
    }
  }
}

function handleNewRoomMessage(data: any) {
  const msg = data.message || data
  if (!msg) return
  updateConversationFromMsg(msg)
  if (msg.room_id === selectedRoomId.value) {
    const exists = currentMessages.value.some(m => m.id === msg.id)
    if (!exists) {
      currentMessages.value.push(msg)
      nextTick(() => scrollChatToBottom())
    }
  }
}

function updateConversationFromMsg(msg: any) {
  const idx = conversations.value.findIndex(c => c.room_id === msg.room_id)
  if (idx >= 0) {
    const conv = { ...conversations.value[idx] }
    conv.last_message = msg.content
    conv.last_message_time = msg.created_at
    if (msg.sender_type === 'guest') {
      conv.unread_count = (conv.unread_count || 0) + 1
    }
    conversations.value.splice(idx, 1)
    conversations.value.unshift(conv)
  } else {
    loadConversations()
  }
}

async function loadConversations() {
  loadingConversations.value = true
  try {
    const hotelId = appStore.userInfo?.hotel_id
    const res: any = await messageApi.getConversations({ hotel_id: hotelId })
    if (res.code === 200 && res.data) {
      conversations.value = res.data || []
    }
  } catch (e) {
    console.error('加载会话列表失败:', e)
  } finally {
    loadingConversations.value = false
  }
}

async function selectConversation(conv: RoomConversation) {
  selectedRoomId.value = conv.room_id
  selectedRoomNumber.value = conv.room_number
  selectedGuestName.value = conv.guest_name || ''
  await loadMessages()
  if (conv.unread_count > 0) {
    await markRoomAllRead()
  }
}

async function loadMessages() {
  if (!selectedRoomId.value) return
  loadingMessages.value = true
  try {
    const res: any = await messageApi.getMessages({ room_id: selectedRoomId.value, pageSize: 200 })
    if (res.code === 200 && res.data) {
      currentMessages.value = res.data.list || []
      nextTick(() => scrollChatToBottom())
    }
  } catch (e) {
    console.error('加载消息失败:', e)
  } finally {
    loadingMessages.value = false
  }
}

async function markRoomAllRead() {
  if (!selectedRoomId.value) return
  try {
    await messageApi.markAllAsRead({ room_id: selectedRoomId.value })
    const idx = conversations.value.findIndex(c => c.room_id === selectedRoomId.value)
    if (idx >= 0) {
      conversations.value[idx].unread_count = 0
    }
  } catch (e) {
    console.error('标记已读失败:', e)
  }
}

async function clearRoomMessages() {
  if (!selectedRoomId.value) return
  try {
    await messageApi.deleteRoomMessages(selectedRoomId.value)
    currentMessages.value = []
    const idx = conversations.value.findIndex(c => c.room_id === selectedRoomId.value)
    if (idx >= 0) {
      conversations.value.splice(idx, 1)
    }
    selectedRoomId.value = null
    selectedRoomNumber.value = ''
    selectedGuestName.value = ''
    $notify.success({ title: '清空成功', description: '房间留言已清空' })
  } catch (e) {
    $notify.error({ title: '清空失败', description: '清空留言失败，请重试' })
  }
}

function handleReplyEnter(e: any) {
  if (e.shiftKey) return
  e.preventDefault()
  sendReply()
}

async function sendReply() {
  const text = replyContent.value.trim()
  if (!text || replySending.value || !selectedRoomId.value) return

  replySending.value = true
  try {
    const res: any = await messageApi.send({
      room_id: selectedRoomId.value,
      sender_type: 'front_desk',
      content: text,
      sender_name: appStore.userInfo?.username || '前台',
    })
    if (res.code === 200 && res.data) {
      currentMessages.value.push(res.data)
      replyContent.value = ''
      nextTick(() => scrollChatToBottom())
      const idx = conversations.value.findIndex(c => c.room_id === selectedRoomId.value)
      if (idx >= 0) {
        conversations.value[idx].last_message = text
        conversations.value[idx].last_message_time = res.data.created_at
      }
    }
  } catch (e) {
    $notify.error({ title: '发送失败', description: '回复发送失败，请重试' })
  } finally {
    replySending.value = false
  }
}

function scrollChatToBottom() {
  if (chatBodyRef.value) {
    chatBodyRef.value.scrollTop = chatBodyRef.value.scrollHeight
  }
}

function formatMsgTime(timeStr: string | null | undefined) {
  if (!timeStr) return ''
  try {
    const dt = new Date(timeStr)
    const now = new Date()
    const diff = now.getTime() - dt.getTime()
    const hours = dt.getHours().toString().padStart(2, '0')
    const mins = dt.getMinutes().toString().padStart(2, '0')
    if (diff < 86400000 && dt.getDate() === now.getDate()) return `${hours}:${mins}`
    if (diff < 172800000) return `昨天 ${hours}:${mins}`
    return `${dt.getMonth() + 1}/${dt.getDate()} ${hours}:${mins}`
  } catch { return '' }
}

function formatConvTime(timeStr: string | null | undefined) {
  if (!timeStr) return ''
  try {
    const dt = new Date(timeStr)
    const now = new Date()
    const diff = now.getTime() - dt.getTime()
    const hours = dt.getHours().toString().padStart(2, '0')
    const mins = dt.getMinutes().toString().padStart(2, '0')
    if (diff < 60000) return '刚刚'
    if (diff < 3600000) return `${Math.floor(diff / 60000)}分钟前`
    if (diff < 86400000 && dt.getDate() === now.getDate()) return `${hours}:${mins}`
    if (diff < 172800000) return `昨天 ${hours}:${mins}`
    return `${dt.getMonth() + 1}/${dt.getDate()}`
  } catch { return '' }
}

function shouldShowTimeSeparator(idx: number) {
  if (idx === 0) return true
  const cur = currentMessages.value[idx]?.created_at
  const prev = currentMessages.value[idx - 1]?.created_at
  if (!cur || !prev) return false
  try {
    return new Date(cur).getTime() - new Date(prev).getTime() > 300000
  } catch { return false }
}
</script>

<style scoped>
.room-messages-page {
  height: calc(100vh - 160px);
}

.messages-layout {
  display: flex;
  height: 100%;
  background: #fff;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.08);
}

.conversations-panel {
  width: 300px;
  border-right: 1px solid #f0f0f0;
  display: flex;
  flex-direction: column;
}

.panel-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px;
  border-bottom: 1px solid #f0f0f0;
}

.panel-header h3 {
  margin: 0;
  font-size: 16px;
}

.conversations-list {
  flex: 1;
  overflow-y: auto;
}

.empty-list {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 60px 20px;
  color: #999;
  gap: 12px;
}

.empty-list p {
  margin: 0;
  font-size: 14px;
}

.conversation-item {
  display: flex;
  align-items: center;
  padding: 12px 16px;
  cursor: pointer;
  transition: background 0.2s;
  border-bottom: 1px solid #f5f5f5;
}

.conversation-item:hover {
  background: #f5f5f5;
}

.conversation-item.active {
  background: #e6f7ff;
}

.conv-avatar {
  width: 40px;
  height: 40px;
  border-radius: 6px;
  background: #e6f7ff;
  color: #1890ff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
  flex-shrink: 0;
  margin-right: 12px;
}

.conv-info {
  flex: 1;
  min-width: 0;
}

.conv-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 4px;
}

.conv-room {
  font-weight: 500;
  font-size: 14px;
}

.conv-time {
  font-size: 12px;
  color: #999;
}

.conv-bottom {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.conv-last-msg {
  font-size: 12px;
  color: #999;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 180px;
}

.chat-panel {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.no-chat-selected {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: #999;
  gap: 16px;
}

.no-chat-selected p {
  margin: 0;
  font-size: 14px;
}

.chat-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 20px;
  border-bottom: 1px solid #f0f0f0;
  background: #fafafa;
}

.chat-room-info {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 15px;
  font-weight: 500;
}

.chat-header-actions {
  display: flex;
  gap: 8px;
}

.chat-body {
  flex: 1;
  overflow-y: auto;
  padding: 16px 20px;
  background: #EDEDED;
}

.chat-loading,
.chat-empty {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: #999;
}

.chat-time-sep {
  text-align: center;
  margin: 12px 0;
  font-size: 12px;
  color: #999;
}

.chat-msg-row {
  display: flex;
  align-items: flex-start;
  margin-bottom: 16px;
  gap: 8px;
}

.chat-msg-row.is-me {
  justify-content: flex-end;
}

.chat-avatar {
  width: 36px;
  height: 36px;
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 18px;
}

.other-avatar {
  background: #1890ff;
  color: #fff;
}

.me-avatar {
  background: #95EC69;
  color: #fff;
}

.chat-bubble-wrap {
  max-width: 60%;
}

.chat-sender-name {
  font-size: 11px;
  color: #999;
  margin-bottom: 2px;
  padding-left: 4px;
}

.is-me .chat-sender-name {
  text-align: right;
  padding-right: 4px;
}

.chat-bubble {
  padding: 10px 14px;
  font-size: 14px;
  line-height: 1.5;
  word-break: break-word;
}

.bubble-other {
  background: #fff;
  color: #1a1a1a;
  border-radius: 0 8px 8px 8px;
}

.bubble-me {
  background: #95EC69;
  color: #1a1a1a;
  border-radius: 8px 0 8px 8px;
}

.chat-input-area {
  display: flex;
  align-items: flex-end;
  gap: 8px;
  padding: 12px 16px;
  background: #F7F7F7;
  border-top: 1px solid #e0e0e0;
}

.reply-input {
  flex: 1;
  resize: none !important;
  border: none !important;
  box-shadow: none !important;
  background: #fff !important;
  border-radius: 4px !important;
  padding: 8px 12px !important;
  font-size: 14px !important;
}

.reply-input:focus {
  box-shadow: none !important;
}

.reply-btn {
  height: 36px;
  border-radius: 4px;
}
</style>
