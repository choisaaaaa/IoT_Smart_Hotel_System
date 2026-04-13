<template>
  <a-modal
    :open="visible"
    :footer="null"
    :closable="false"
    :maskClosable="false"
    centered
    width="320px"
    class="incoming-call-modal"
  >
    <div class="incoming-call-content">
      <div class="call-animation">
        <div class="circle"></div>
        <div class="circle"></div>
        <div class="circle"></div>
        <PhoneOutlined class="phone-icon" />
      </div>
      
      <h2 class="caller-name">{{ incomingCall?.caller_name || incomingCall?.caller_id || '未知来电' }}</h2>
      <div class="hotel-info-tag" v-if="incomingCall?.hotel_name">
        <HomeOutlined /> {{ incomingCall.hotel_name }}
      </div>
      <p class="call-type">
        <template v-if="incomingCall?.isTransfer">
          <a-tag color="orange">AI管家转接</a-tag>
          <div class="transfer-reason">{{ incomingCall?.transferReason || '客人请求人工服务' }}</div>
        </template>
        <template v-else>
          <a-tag color="blue">语音通话</a-tag>
          <div class="room-info" v-if="incomingCall?.caller_type === 'room'">
            来自房间: {{ incomingCall?.caller_id }}
          </div>
        </template>
      </p>

      <div class="call-actions">
        <a-button type="primary" shape="round" size="large" @click="handleAnswer" class="answer-btn">
          <template #icon><PhoneOutlined /></template> 接听
        </a-button>
        <a-button danger shape="round" size="large" @click="handleReject" class="reject-btn">
          <template #icon><CloseOutlined /></template> 拒接
        </a-button>
      </div>
    </div>
  </a-modal>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { PhoneOutlined, CloseOutlined, HomeOutlined } from '@ant-design/icons-vue'
import { useAppStore } from '@/stores/app'
import { getSocket } from '@/utils/websocket'
import { message } from 'ant-design-vue'
import { useRouter } from 'vue-router'

const appStore = useAppStore()
const router = useRouter()

const visible = computed(() => !!appStore.incomingCall)
const incomingCall = computed(() => appStore.incomingCall)

function handleAnswer() {
  if (!appStore.incomingCall) return
  
  const socket = getSocket()
  if (socket) {
    socket.emit('answer_call', { call_id: appStore.incomingCall.call_id })
    
    // 设置为当前通话
    appStore.setCurrentCall({
      ...appStore.incomingCall,
      status: 'connected'
    })
    
    // 清除来电状态
    appStore.clearIncomingCall()
    
    // 跳转到通话页面（如果不在的话）
    router.push('/reception/voice-calls')
    
    message.success('通话已接通')
  }
}

function handleReject() {
  if (!appStore.incomingCall) return
  
  const socket = getSocket()
  if (socket) {
    socket.emit('reject_call', { call_id: appStore.incomingCall.call_id })
    appStore.clearIncomingCall()
    message.info('已拒接来电')
  }
}
</script>

<style scoped>
.incoming-call-content {
  text-align: center;
  padding: 20px 0;
}

.call-animation {
  position: relative;
  width: 100px;
  height: 100px;
  margin: 0 auto 20px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.circle {
  position: absolute;
  width: 100%;
  height: 100%;
  border: 2px solid #1890ff;
  border-radius: 50%;
  animation: pulse 2s infinite;
  opacity: 0;
}

.circle:nth-child(2) {
  animation-delay: 0.6s;
}

.circle:nth-child(3) {
  animation-delay: 1.2s;
}

@keyframes pulse {
  0% { transform: scale(0.5); opacity: 0.8; }
  100% { transform: scale(1.5); opacity: 0; }
}

.phone-icon {
  font-size: 40px;
  color: #1890ff;
  z-index: 1;
}

.caller-name {
  margin: 10px 0 5px;
  font-size: 24px;
}

.hotel-info-tag {
  color: #8c8c8c;
  font-size: 14px;
  margin-bottom: 15px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 4px;
}

.call-type {
  margin-bottom: 30px;
}

.transfer-reason, .room-info {
  margin-top: 8px;
  color: #666;
  font-size: 14px;
}

.call-actions {
  display: flex;
  justify-content: center;
  gap: 20px;
}

.answer-btn {
  background-color: #52c41a;
  border-color: #52c41a;
  min-width: 110px;
}

.answer-btn:hover {
  background-color: #73d13d;
  border-color: #73d13d;
}

.reject-btn {
  min-width: 110px;
}
</style>
