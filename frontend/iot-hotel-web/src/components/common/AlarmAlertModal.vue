<template>
  <div>
    <!-- 紧急报警弹窗 -->
    <a-modal
      v-model:open="alarmModalVisible"
      :title="null"
      :footer="null"
      :closable="false"
      :maskClosable="false"
      width="520px"
      :centered="true"
      :class="['alarm-modal', currentAlarm?.level === 'critical' ? 'critical-alarm' : '']"
    >
      <div class="alarm-content">
        <div class="alarm-icon-wrapper" :class="{ 'animate-pulse': countdown > 0 }">
          <WarningFilled class="alarm-icon" />
        </div>
        
        <h2 class="alarm-title">
          {{ currentAlarm?.level === 'critical' ? '🔥 紧急火警警报' : '🚨 安全警报' }}
        </h2>
        
        <div class="alarm-info">
          <p class="alarm-location">
            <EnvironmentOutlined /> 报警位置: <strong>{{ currentAlarm?.location || '未知位置' }}</strong>
          </p>
          <p class="alarm-device">
            <ToolOutlined /> 
            设备类型: {{ getDeviceTypeText(currentAlarm?.deviceId) }} | 
            设备ID: {{ currentAlarm?.deviceId || '未知设备' }}
          </p>
          <p class="alarm-time">
            <ClockCircleOutlined /> 触发时间: {{ formatTime(currentAlarm?.timestamp) }}
          </p>
          <p class="alarm-message">{{ currentAlarm?.message || '检测到异常情况，请立即处理！' }}</p>
        </div>
        
        <div v-if="countdown > 0" class="countdown-section">
          <a-progress
            :percent="(countdown / 5) * 100"
            :show-info="false"
            :stroke-color="countdown <= 2 ? '#ff4d4f' : '#faad14'"
            :trail-color="'#f0f0f0'"
            class="countdown-progress"
          />
          <p class="countdown-text">
            <span class="countdown-number">{{ countdown }}</span> 秒后自动触发全局报警
          </p>
        </div>
        
        <div v-else class="global-alarm-active">
          <FireFilled class="global-alarm-icon" />
          <p class="global-alarm-text">全局报警已触发！</p>
          <p class="global-alarm-sub">所有设备已联动响应</p>
        </div>
        
        <div class="alarm-actions">
          <a-button
            type="primary"
            size="large"
            danger
            class="ack-btn"
            :loading="acknowledging"
            @click="handleAcknowledge"
          >
            <SafetyOutlined /> 立即确认并消警
          </a-button>
          <a-button
            size="large"
            class="detail-btn"
            @click="showAlarmDetail"
          >
            <EyeOutlined /> 查看详情
          </a-button>
        </div>
      </div>
    </a-modal>

    <!-- 报警详情抽屉 -->
    <a-drawer
      v-model:open="detailDrawerVisible"
      title="报警详情"
      placement="right"
      width="480"
    >
      <a-descriptions :column="1" bordered v-if="currentAlarm">
        <a-descriptions-item label="报警ID">{{ currentAlarm.id }}</a-descriptions-item>
        <a-descriptions-item label="报警类型">
          <a-tag :color="getAlarmColor(currentAlarm.type)">{{ getAlarmTypeText(currentAlarm.type) }}</a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="严重程度">
          <a-tag :color="currentAlarm.level === 'critical' ? 'red' : 'orange'">
            {{ currentAlarm.level === 'critical' ? '严重' : '一般' }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="设备ID">{{ currentAlarm.deviceId }}</a-descriptions-item>
        <a-descriptions-item label="位置">{{ currentAlarm.location }}</a-descriptions-item>
        <a-descriptions-item label="触发时间">{{ formatDateTime(currentAlarm.timestamp) }}</a-descriptions-item>
        <a-descriptions-item label="报警详情">{{ currentAlarm.message }}</a-descriptions-item>
      </a-descriptions>
      
      <div class="drawer-actions">
        <a-button type="primary" danger block size="large" @click="handleAcknowledge">
          <SafetyOutlined /> 确认并消警
        </a-button>
      </div>
    </a-drawer>

    <!-- 全局报警遮罩 -->
    <div v-if="globalAlarmActive" class="global-alarm-overlay">
      <div class="overlay-content">
        <FireFilled class="overlay-icon" />
        <h1 class="overlay-title">全局报警中</h1>
        <p class="overlay-subtitle">请立即前往前台确认并处理</p>
        <a-button
          type="primary"
          size="large"
          danger
          class="overlay-ack-btn"
          :loading="acknowledging"
          @click="handleAcknowledge"
        >
          <SafetyOutlined /> 立即确认并消警
        </a-button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, onUnmounted, onMounted } from 'vue'
import { $notify, NotifyPreset } from '@/utils/notify'
import { Modal } from 'ant-design-vue'
import {
  WarningFilled,
  EnvironmentOutlined,
  ToolOutlined,
  ClockCircleOutlined,
  SafetyOutlined,
  EyeOutlined,
  FireFilled
} from '@ant-design/icons-vue'
import dayjs from 'dayjs'
import { useAppStore } from '@/stores/app'
import request from '@/api/request'
import { environmentApi } from '@/api/environment'
import { formatTimeHHmmss, formatDateTimeSec } from '@/utils/date'

interface AlarmInfo {
  id: string
  type: 'fire_alarm' | 'sos_alarm' | 'smoke' | 'temperature' | 'manual'
  level: 'critical' | 'high' | 'medium' | 'low'
  deviceId: string
  deviceName?: string
  location: string
  message: string
  timestamp: string
  floorId?: string
  roomId?: string
  acknowledged?: boolean
}

const appStore = useAppStore()

const alarmModalVisible = ref(false)
const detailDrawerVisible = ref(false)
const currentAlarm = ref<AlarmInfo | null>(null)
const countdown = ref(5)
const countdownTimer = ref<NodeJS.Timeout | null>(null)
const acknowledging = ref(false)
const globalAlarmActive = ref(false)
const alarmAudio = ref<HTMLAudioElement | null>(null)

// 监听报警事件
watch(() => appStore.currentAlarm, (alarm) => {
  console.log('[AlarmAlertModal] 收到报警:', alarm)
  if (alarm && !alarm.acknowledged) {
    showAlarmModal(alarm)
  }
}, { immediate: true })

// 监听消警事件
onMounted(() => {
  window.addEventListener('fire-alarm-cleared', handleAlarmCleared as EventListener)
})

onUnmounted(() => {
  window.removeEventListener('fire-alarm-cleared', handleAlarmCleared as EventListener)
  // 清除定时器
  if (countdownTimer.value) {
    clearInterval(countdownTimer.value)
  }
  // 停止报警声音
  stopAlarmSound()
})

// 处理消警事件
function handleAlarmCleared(event: CustomEvent) {
  console.log('[AlarmAlertModal] 收到消警事件:', event.detail)
  
  const clearedDeviceId = event.detail?.deviceId
  
  // 如果当前显示的报警是来自同一设备，关闭弹窗
  if (currentAlarm.value && currentAlarm.value.deviceId === clearedDeviceId) {
    console.log('[AlarmAlertModal] 关闭当前报警弹窗')
    
    // 清除定时器
    if (countdownTimer.value) {
      clearInterval(countdownTimer.value)
      countdownTimer.value = null
    }
    
    // 关闭弹窗和遮罩
    alarmModalVisible.value = false
    detailDrawerVisible.value = false
    globalAlarmActive.value = false
    
    // 停止报警声音
    stopAlarmSound()
    
    // 标记报警已处理
    currentAlarm.value.acknowledged = true
    
    $notify.success({ title: '报警已解除', description: event.detail?.message || '火警已自动解除' })
  }
}

// 停止报警声音
function stopAlarmSound() {
  if (alarmAudio.value) {
    alarmAudio.value.pause()
    alarmAudio.value.currentTime = 0
    alarmAudio.value = null
  }
}

function showAlarmModal(alarm: AlarmInfo) {
  console.log('[AlarmAlertModal] showAlarmModal 被调用:', alarm)
  currentAlarm.value = alarm
  alarmModalVisible.value = true
  console.log('[AlarmAlertModal] alarmModalVisible 设置为:', alarmModalVisible.value)
  countdown.value = 5
  globalAlarmActive.value = false
  
  // 开始倒计时
  startCountdown()
}

function startCountdown() {
  // 清除之前的定时器
  if (countdownTimer.value) {
    clearInterval(countdownTimer.value)
  }
  
  countdownTimer.value = setInterval(() => {
    countdown.value--
    
    if (countdown.value <= 0) {
      // 倒计时结束，触发全局报警
      triggerGlobalAlarm()
    }
  }, 1000)
}

function triggerGlobalAlarm() {
  if (countdownTimer.value) {
    clearInterval(countdownTimer.value)
    countdownTimer.value = null
  }
  
  globalAlarmActive.value = true
  
  // 发送全局报警指令到所有设备
  if (currentAlarm.value) {
    sendGlobalAlarmCommand()
  }
  
  // 播放警报声音（如果浏览器支持）
  playAlarmSound()
}

async function sendGlobalAlarmCommand() {
  try {
    await request.post('/mqtt/send', {
      topic: 'hotel/security/global_alarm',
      payload: {
        event_type: 'global_alarm',
        level: 'critical',
        source_alarm: currentAlarm.value,
        timestamp: new Date().toISOString(),
        message: '全局报警已触发，所有设备联动响应'
      }
    })
  } catch (error) {
    console.error('发送全局报警指令失败:', error)
  }
}

function playAlarmSound() {
  try {
    // 先停止之前的声音
    stopAlarmSound()
    
    alarmAudio.value = new Audio('/alarm-sound.mp3')
    alarmAudio.value.loop = true
    alarmAudio.value.play().catch(() => {
      // 自动播放可能被浏览器阻止
    })
  } catch (error) {
    console.error('播放警报声音失败:', error)
  }
}

async function handleAcknowledge() {
  if (!currentAlarm.value) return
  
  acknowledging.value = true
  
  try {
    // 调用后端API确认报警
    const alarmId = parseInt(currentAlarm.value.id)
    if (!isNaN(alarmId)) {
      await environmentApi.acknowledgeAlarm(alarmId, {
        handler: appStore.userInfo?.username || '前台工作人员',
        notes: '通过报警弹窗确认处理'
      })
    }
    
    // 发送消警指令到设备
    await sendResetCommand()
    
    // 清除定时器
    if (countdownTimer.value) {
      clearInterval(countdownTimer.value)
      countdownTimer.value = null
    }
    
    // 关闭弹窗
    alarmModalVisible.value = false
    detailDrawerVisible.value = false
    globalAlarmActive.value = false
    
    // 停止报警声音
    stopAlarmSound()
    
    // 标记报警已处理
    if (currentAlarm.value) {
      currentAlarm.value.acknowledged = true
    }
    
    $notify.success({ title: '报警已确认', description: '报警已确认并消除 🔥' })
    
    // 刷新报警列表
    appStore.refreshAlarmList()
  } catch (error) {
    NotifyPreset.operationFailed('消警失败')
  } finally {
    acknowledging.value = false
  }
}

async function sendResetCommand() {
  if (!currentAlarm.value) return
  
  try {
    // 发送全局消警指令到所有设备类型
    const resetPayload = {
      device_id: 'global_reset',
      command_type: 'alarm_reset',
      command_value: 'reset',
      timestamp: new Date().toISOString(),
      source_alarm: currentAlarm.value.id
    }
    
    // 发送给楼控
    await request.post('/mqtt/send', {
      topic: `hotel/device/command/floor/all`,
      payload: resetPayload
    }).catch(() => {}) // 忽略错误
    
    // 发送给前台
    await request.post('/mqtt/send', {
      topic: `hotel/device/command/front_desk/all`,
      payload: resetPayload
    }).catch(() => {})
    
    // 发送给客房
    await request.post('/mqtt/send', {
      topic: `hotel/device/command/room/all`,
      payload: resetPayload
    }).catch(() => {})
    
    // 同时发送给触发报警的特定设备
    const deviceType = currentAlarm.value.deviceId?.includes('FLO') ? 'floor' : 
                       currentAlarm.value.deviceId?.includes('FRO') ? 'front_desk' : 'room'
    
    await request.post('/mqtt/send', {
      topic: `hotel/device/command/${deviceType}/${currentAlarm.value.deviceId}`,
      payload: {
        device_id: currentAlarm.value.deviceId,
        command_type: 'alarm_reset',
        command_value: 'reset',
        timestamp: new Date().toISOString()
      }
    })
    
    console.log('[AlarmAlertModal] 全局消警指令已发送')
  } catch (error) {
    console.error('发送消警指令失败:', error)
  }
}

function showAlarmDetail() {
  detailDrawerVisible.value = true
}

function getAlarmColor(type: string): string {
  const colors: Record<string, string> = {
    fire_alarm: 'red',
    sos_alarm: 'orange',
    smoke: 'volcano',
    temperature: 'orange',
    manual: 'gold'
  }
  return colors[type] || 'default'
}

function getAlarmTypeText(type: string): string {
  const texts: Record<string, string> = {
    fire_alarm: '消防报警',
    sos_alarm: 'SOS报警',
    smoke: '烟雾探测',
    temperature: '温度异常',
    manual: '手动报警'
  }
  return texts[type] || type
}

function getDeviceTypeText(deviceId: string | undefined): string {
  if (!deviceId) return '未知设备'
  if (deviceId.includes('FLO')) return '楼控节点'
  if (deviceId.includes('FRO')) return '前台管理'
  if (deviceId.includes('ROO') || deviceId.includes('room')) return '客房终端'
  return '其他设备'
}

function formatTime(timestamp: string): string {
  if (!timestamp) return '-'
  return formatTimeHHmmss(timestamp)
}

function formatDateTime(timestamp: string): string {
  if (!timestamp) return '-'
  return formatDateTimeSec(timestamp)
}
</script>

<style scoped>
.alarm-modal :deep(.ant-modal-content) {
  border-radius: 16px;
  overflow: hidden;
}

.alarm-modal.critical-alarm :deep(.ant-modal-content) {
  border: 3px solid #ff4d4f;
  box-shadow: 0 0 30px rgba(255, 77, 79, 0.4);
}

.alarm-content {
  text-align: center;
  padding: 24px;
}

.alarm-icon-wrapper {
  width: 100px;
  height: 100px;
  border-radius: 50%;
  background: linear-gradient(135deg, #ff4d4f 0%, #ff7875 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 24px;
  box-shadow: 0 8px 24px rgba(255, 77, 79, 0.3);
}

.alarm-icon-wrapper.animate-pulse {
  animation: pulse-red 1s infinite;
}

@keyframes pulse-red {
  0%, 100% { transform: scale(1); box-shadow: 0 8px 24px rgba(255, 77, 79, 0.3); }
  50% { transform: scale(1.05); box-shadow: 0 12px 32px rgba(255, 77, 79, 0.5); }
}

.alarm-icon {
  font-size: 48px;
  color: white;
}

.alarm-title {
  font-size: 24px;
  font-weight: 700;
  color: #ff4d4f;
  margin-bottom: 20px;
}

.alarm-info {
  background: #fff1f0;
  border-radius: 12px;
  padding: 20px;
  margin-bottom: 24px;
  text-align: left;
}

.alarm-info p {
  margin: 8px 0;
  font-size: 14px;
  color: #595959;
}

.alarm-info strong {
  color: #262626;
  font-size: 16px;
}

.alarm-message {
  margin-top: 16px !important;
  padding-top: 16px;
  border-top: 1px dashed #ffccc7;
  color: #ff4d4f !important;
  font-weight: 600;
  font-size: 15px !important;
}

.countdown-section {
  margin-bottom: 24px;
}

.countdown-progress {
  margin-bottom: 12px;
}

.countdown-text {
  font-size: 16px;
  color: #faad14;
  font-weight: 500;
}

.countdown-number {
  font-size: 32px;
  font-weight: 700;
  color: #ff4d4f;
}

.global-alarm-active {
  background: linear-gradient(135deg, #ff4d4f 0%, #ff7875 100%);
  border-radius: 12px;
  padding: 24px;
  margin-bottom: 24px;
  color: white;
  animation: shake 0.5s infinite;
}

@keyframes shake {
  0%, 100% { transform: translateX(0); }
  25% { transform: translateX(-5px); }
  75% { transform: translateX(5px); }
}

.global-alarm-icon {
  font-size: 48px;
  margin-bottom: 12px;
}

.global-alarm-text {
  font-size: 24px;
  font-weight: 700;
  margin-bottom: 8px;
}

.global-alarm-sub {
  font-size: 14px;
  opacity: 0.9;
}

.alarm-actions {
  display: flex;
  gap: 16px;
  justify-content: center;
}

.ack-btn {
  min-width: 180px;
  height: 48px;
  font-size: 16px;
  font-weight: 600;
}

.detail-btn {
  min-width: 120px;
  height: 48px;
}

.drawer-actions {
  margin-top: 24px;
  padding-top: 24px;
  border-top: 1px solid #f0f0f0;
}

/* 全局报警遮罩 */
.global-alarm-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(255, 77, 79, 0.95);
  z-index: 9999;
  display: flex;
  align-items: center;
  justify-content: center;
  animation: fade-in 0.3s ease;
}

@keyframes fade-in {
  from { opacity: 0; }
  to { opacity: 1; }
}

.overlay-content {
  text-align: center;
  color: white;
}

.overlay-icon {
  font-size: 80px;
  margin-bottom: 24px;
  animation: pulse-white 1s infinite;
}

@keyframes pulse-white {
  0%, 100% { transform: scale(1); opacity: 1; }
  50% { transform: scale(1.1); opacity: 0.8; }
}

.overlay-title {
  font-size: 48px;
  font-weight: 700;
  margin-bottom: 16px;
}

.overlay-subtitle {
  font-size: 20px;
  opacity: 0.9;
  margin-bottom: 32px;
}

.overlay-ack-btn {
  min-width: 200px;
  height: 56px;
  font-size: 18px;
  font-weight: 600;
  background: white !important;
  color: #ff4d4f !important;
  border: none;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.2);
}

.overlay-ack-btn:hover {
  background: #f5f5f5 !important;
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(0, 0, 0, 0.3);
}
</style>
