<template>
  <div class="voice-calls-container">
    <!-- 统计卡片 -->
    <a-row :gutter="[16, 16]" class="stat-row">
      <a-col :xs="24" :sm="6">
        <a-card size="small" class="stat-card">
          <a-statistic title="活跃通话" :value="activeCalls.length" :value-style="{ color: '#1890ff' }" />
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="6">
        <a-card size="small" class="stat-card">
          <a-statistic title="在线终端" :value="onlineCount" :value-style="{ color: '#52c41a' }" />
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="6">
        <a-card size="small" class="stat-card">
          <a-statistic title="接通率" :value="Number((stats.answer_rate || 0) * 100)" suffix="%" :precision="0" :value-style="{ color: '#faad14' }" />
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="6">
        <a-card size="small" class="stat-card">
          <div class="registration-status">
            <div class="reg-info">
              <span class="label">当前身份:</span>
              <span class="value">{{ appStore.isRegistered ? appStore.clientDisplayName : '未上线' }}</span>
            </div>
            <a-tag :color="appStore.isRegistered ? 'success' : 'warning'">
              {{ appStore.isRegistered ? '已自动上线' : '连接中' }}
            </a-tag>
          </div>
        </a-card>
      </a-col>
    </a-row>

    <!-- 当前通话 (统一由 App.vue 处理，这里仅保留挂断快捷键或隐藏) -->
    <!-- 移除了本地 redundant current-call-section -->

    <!-- 呼叫网格与调度面板 -->
    <div class="calls-main-layout">
      <!-- 调度面板 -->
      <a-card class="duty-management-card" title="话务调度面板" :bodyStyle="{ padding: '16px' }">
        <template #extra>
          <div style="display: flex; align-items: center; gap: 8px;">
            <a-button type="primary" size="small" @click="openBroadcastModal">
              <template #icon><SoundOutlined /></template>
              房间广播
            </a-button>
            <a-badge :status="appStore.userStatus?.isOnDuty ? 'success' : 'default'" :text="appStore.userStatus?.isOnDuty ? '值班中' : '休息中'" />
          </div>
        </template>

        <div class="duty-controls">
          <div class="control-item">
            <span class="label">接听状态:</span>
            <a-switch
              :checked="appStore.userStatus?.isOnDuty"
              @change="handleDutySwitch"
              checked-children="在岗"
              un-checked-children="离岗"
            />
          </div>

          <div class="control-item" v-if="appStore.userStatus?.isOnDuty">
            <span class="label">当值岗位:</span>
            <a-select v-model:value="currentDutyRole" @change="handleRoleChange" style="width: 130px">
              <a-select-option value="reception">客服前台</a-select-option>
              <a-select-option value="manager">值班经理</a-select-option>
              <a-select-option value="security">安保中心</a-select-option>
              <a-select-option value="cleaning">保洁调度</a-select-option>
            </a-select>
          </div>

          <a-divider style="margin: 8px 0" />

          <div class="mic-check-section">
            <a-button
              block
              :type="micStatus === 'success' ? 'default' : 'primary'"
              @click="checkMicPermission"
              :loading="micChecking"
            >
              <template #icon>
                <AudioOutlined v-if="micStatus !== 'success'" />
                <CheckCircleOutlined v-else style="color: #52c41a" />
              </template>
              {{ micStatus === 'success' ? '麦克风已就绪' : '检测麦克风权限' }}
            </a-button>
            <div v-if="micStatus === 'error'" class="mic-error-tip">
              <WarningOutlined /> 麦克风未授权或设备不可用
            </div>
          </div>
        </div>

        <a-divider style="margin: 16px 0" />

        <div class="online-staff-section">
          <div class="section-header">
            <span class="title">当前值班 ({{ onDutyStaff.length }})</span>
            <span class="subtitle">仅在岗人员可接收公共呼叫</span>
          </div>
          <div class="staff-list-mini">
            <div v-for="staff in onDutyStaff" :key="staff.id" class="staff-item-mini">
              <a-avatar size="small" :src="staff.avatar">{{ staff.name[0] }}</a-avatar>
              <span class="staff-name">{{ staff.name }}</span>
              <a-tag size="small" color="blue">{{ getRoleLabel(staff.dutyRole) }}</a-tag>
            </div>
            <a-empty v-if="onDutyStaff.length === 0" description="暂无值班人员" :image="Empty.PRESENTED_IMAGE_SIMPLE" />
          </div>
        </div>
      </a-card>

      <!-- 呼叫面板 -->
      <a-tabs v-model:activeKey="activeTab" class="call-tabs">
      <a-tab-pane key="all" title="全部">
        <template #tab><span><AppstoreOutlined /> 全部</span></template>
        <div class="grid-scroll">
          <div class="call-grid">
            <div
              v-for="target in callableTargets"
              :key="target.id + target.type"
              class="call-card"
              :class="[target.type, target.status]"
              @click="handleCardClick(target)"
            >
              <div class="card-status-dot" :class="{ online: target.isOnline }"></div>
              <div class="card-icon">
                <HomeOutlined v-if="target.type === 'room'" />
                <UserOutlined v-else />
              </div>
              <div class="card-name">{{ target.name }}</div>
              <div class="card-desc">{{ target.desc }}</div>
              <div class="card-action-hint">点击呼叫</div>
            </div>
          </div>
        </div>
      </a-tab-pane>
      <a-tab-pane key="room" title="客房">
        <template #tab><span><HomeOutlined /> 客房硬件</span></template>
        <div class="call-grid">
          <div
            v-for="target in callableTargets.filter(t => t.type === 'room')"
            :key="target.id"
            class="call-card room"
            @click="handleCardClick(target)"
          >
            <div class="card-name">{{ target.name }}</div>
            <div class="card-desc">{{ target.desc }}</div>
          </div>
        </div>
      </a-tab-pane>
      <a-tab-pane key="staff" title="前台/员工">
        <template #tab><span><TeamOutlined /> 前台/员工</span></template>
        <div class="call-grid">
          <div
            v-for="target in callableTargets.filter(t => t.type === 'front_desk' || t.type === 'app')"
            :key="target.id"
            class="call-card staff"
            @click="handleCardClick(target)"
          >
            <div class="card-name">{{ target.name }}</div>
            <div class="card-desc">{{ target.roleName }}</div>
          </div>
        </div>
      </a-tab-pane>
      <a-tab-pane key="history" title="通话记录">
        <template #tab><span><HistoryOutlined /> 通话记录</span></template>
        <a-table :columns="historyColumns" :data-source="history" :pagination="{ pageSize: 10 }" row-key="call_id" size="small" />
      </a-tab-pane>
    </a-tabs>
    </div> <!-- 关闭 calls-main-layout -->

    <!-- 正在呼叫弹窗 -->
    <a-modal
      :open="outgoingCallModal.visible"
      :footer="null"
      :closable="false"
      :maskClosable="false"
      centered
      width="320px"
    >
      <div class="outgoing-call-content">
        <a-avatar :size="64" icon="user" />
        <h2 style="margin-top: 16px">{{ outgoingCallModal.targetName }}</h2>
        <p>正在呼叫中...</p>
        <a-button danger shape="circle" size="large" @click="handleOutgoingCancel">
          <template #icon><CloseOutlined /></template>
        </a-button>
      </div>
    </a-modal>
    <!-- 房间广播弹窗 -->
    <a-modal v-model:open="broadcastVisible" title="📢 发起房间语音广播" @ok="handleBroadcast" :confirmLoading="broadcasting">
      <a-form layout="vertical">
        <a-form-item label="目标房间" required>
          <a-select v-model:value="broadcastForm.room_id" placeholder="选择或输入房间号" show-search>
            <a-select-option v-for="room in roomList" :key="room.room_id" :value="room.room_id">
              {{ room.room_id }} ({{ room.display_name }})
            </a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item label="广播内容 (由AI自动朗读)" required>
          <a-textarea v-model:value="broadcastForm.text" placeholder="请输入要广播的内容，如：尊敬的客人，您的外卖已送达前台，请注意查收。" :rows="4" />
        </a-form-item>
        <a-alert message="AI 自动朗读" description="下发后，客房内的 AI 管家将自动把文字转为语音播放。此功能用于非实时通话的紧急提醒或温馨提示。" type="info" show-icon />
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { onMounted, onUnmounted, reactive, ref, computed } from 'vue'
import { message, Modal, Empty } from 'ant-design-vue'
import {
  PhoneOutlined, CloseOutlined, HomeOutlined, UserOutlined,
  TeamOutlined, HistoryOutlined, AppstoreOutlined, AudioOutlined, CheckCircleOutlined, WarningOutlined,
  SoundOutlined
} from '@ant-design/icons-vue'
import { callApi } from '@/api/call'
import { aiButlerApi } from '@/api/ai-butler'
import type { RoomInfo } from '@/types'
import request from '@/api/request'
import { getSocket, initWebSocket } from '@/utils/websocket'
import { useAppStore } from '@/stores/app'
import { useHotelStore } from '@/stores/hotel'
import { CANONICAL_ROLES } from '@/api/auth'

const appStore = useAppStore()
const hotelStore = useHotelStore()
const calling = ref(false)
const activeCalls = ref<any[]>([])
const history = ref<any[]>([])
const stats = reactive({
  answer_rate: 0,
  avg_duration_sec: 0
})
const users = ref<any[]>([])
const activeTab = ref('all')
const onlineStatus = ref<{ web: any[], rooms: any[] }>({ web: [], rooms: [] })
const fetchCallsTimer = ref<NodeJS.Timeout | null>(null)

// 房间列表用于广播选择
const roomList = computed(() => {
  return (hotelStore.rooms as RoomInfo[])
    .filter((r: RoomInfo) => appStore.userInfo?.role === 'system' || r.hotel_id === appStore.userInfo?.hotel_id)
    .map((r: RoomInfo) => ({
      room_id: r.room_number,
      display_name: `${r.room_name} - ${r.room_status === 'occupied' ? '已入住' : '未入住'}`
    }))
})

// 麦克风检测状态
const micChecking = ref(false)
const micStatus = ref<'idle' | 'success' | 'error'>('idle')

  // 房间广播
  const broadcastVisible = ref(false)
  const broadcastForm = reactive({
    room_id: '',
    text: ''
  })
  const broadcasting = ref(false)

  const openBroadcastModal = () => {
    broadcastForm.room_id = ''
    broadcastForm.text = ''
    broadcastVisible.value = true
  }

  const handleBroadcast = async () => {
    if (!broadcastForm.room_id) {
      message.warning('请选择房间')
      return
    }
    if (!broadcastForm.text) {
      message.warning('请输入广播内容')
      return
    }

    broadcasting.value = true
    try {
      await aiButlerApi.broadcast(broadcastForm.room_id, broadcastForm.text)
      message.success(`广播已成功下发至 ${broadcastForm.room_id} 房间`)
      broadcastVisible.value = false
    } catch (err: any) {
      message.error(err.response?.data?.message || '广播下发失败')
    } finally {
      broadcasting.value = false
    }
  }

// 值班状态管理
const currentDutyRole = ref('reception')
const onDutyStaff = computed(() => {
  return onlineStatus.value.web.filter(s => s.isOnDuty)
})

const getRoleLabel = (role: string) => {
  const roles: any = {
    reception: '客服前台',
    manager: '值班经理',
    security: '安保中心',
    cleaning: '保洁调度'
  }
  return roles[role] || '前台'
}

function handleDutySwitch(checked: boolean) {
  const socket = getSocket()
  if (socket) {
    socket.emit('set_duty_status', {
      isOnDuty: checked,
      dutyRole: currentDutyRole.value
    })
    // 同步更新本地状态，增强 UI 响应速度
    appStore.setUserStatus({
      ...appStore.userStatus,
      isOnDuty: checked
    })
  }
}

function handleRoleChange(value: string) {
  const socket = getSocket()
  if (socket) {
    socket.emit('set_duty_status', {
      isOnDuty: appStore.userStatus?.isOnDuty,
      dutyRole: value
    })
  }
}

async function checkMicPermission() {
  micChecking.value = true
  micStatus.value = 'idle'

  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    // 成功获取流，说明权限 OK
    micStatus.value = 'success'
    message.success('麦克风权限已就绪，您可以正常通话')

    // 释放测试流
    stream.getTracks().forEach(track => track.stop())
  } catch (error: any) {
    console.error('[MicCheck] 权限检测失败:', error)
    micStatus.value = 'error'

    if (error.name === 'NotAllowedError' || error.name === 'PermissionDeniedError') {
      message.error('麦克风权限已被拒绝，请在浏览器地址栏左侧点击“锁”图标开启权限')
    } else if (error.name === 'NotFoundError' || error.name === 'DevicesNotFoundError') {
      message.error('未检测到麦克风设备，请检查硬件连接')
    } else {
      message.error('麦克风检测异常: ' + error.message)
    }
  } finally {
    micChecking.value = false
  }
}

const isRegistered = computed(() => appStore.isRegistered)
const clientDisplayName = computed(() => appStore.clientDisplayName)

const outgoingCallModal = reactive({
  visible: false,
  targetId: '',
  targetName: '',
  callId: '',
  status: 'calling' as 'calling' | 'connected'
})

// 当前通话时长
const currentCallDuration = ref('00:00')
const callDurationTimer = ref<NodeJS.Timeout | null>(null)
const callStartTime = ref<number | null>(null)

// 组合可呼叫目标
const callableTargets = computed(() => {
  const list: any[] = []

  // 1. 添加房间 (仅显示在线且通过 MQTT 接入的硬件终端)
  hotelStore.rooms.forEach(room => {
    // 隔离：只能看到本店房间
    if (appStore.userInfo?.role !== 'system' && room.hotel_id !== appStore.userInfo?.hotel_id) {
      return
    }
    // 检查在线状态 (根据数据库 ID 或 房号匹配)
    const isOnline = onlineStatus.value.rooms.some((r: any) => 
      String(r.id) === String(room.id) || String(r.room_number) === String(room.room_number)
    )
    
    // 优化：仅在语音通话清单显示在线硬件
    if (isOnline) {
      list.push({
        id: room.id,
        clientId: String(room.id),
        name: `房间 ${room.room_number}`,
        desc: room.room_name,
        type: 'room',
        status: room.room_status,
        isOnline: true
      })
    }
  })

  // 2. 添加员工 (过滤掉自己并过滤掉 user 角色)
  console.log('[VoiceCalls] 当前用户:', appStore.userInfo?.username)
  console.log('[VoiceCalls] 用户列表:', users.value)
  users.value.forEach(user => {
    console.log('[VoiceCalls] 检查用户:', user.username, '角色:', user.role)
    // 隔离：只能看到本店员工 (除非是系统管理员)，且不能看到角色为 user 的用户
    const isSameHotel = appStore.userInfo?.role === CANONICAL_ROLES.SYSTEM_ADMIN || user.hotel_id === appStore.userInfo?.hotel_id
    const isNotSelf = user.username !== appStore.userInfo?.username
    const isNotUserRole = user.role !== CANONICAL_ROLES.CUSTOMER

    if (isNotSelf && isSameHotel && isNotUserRole) {
      const isOnline = onlineStatus.value.web.some((w: any) => w.id === user.username)
      list.push({
        id: user.id,
        clientId: user.username,
        name: user.username,
        desc: user.role === CANONICAL_ROLES.HOTEL_ADMIN ? '管理员' : '前台',
        type: 'front_desk',
        status: 'available',
        isOnline
      })
    }
  })

  console.log('[VoiceCalls] 可呼叫目标:', list.length, '个')
  return list.sort((a, b) => a.name.localeCompare(b.name))
})

const onlineCount = computed(() => callableTargets.value.filter(t => t.isOnline).length)

async function fetchCalls() {
  try {
    const [activeRes, historyRes] = await Promise.all([
      callApi.getActive(),
      callApi.getHistory({ page: 1, limit: 50 })
    ])
    activeCalls.value = (activeRes as any).data?.items || []
    history.value = (historyRes as any).data?.items || []
  } catch (error) {
    console.error('获取通话记录失败:', error)
  }
}

async function fetchUsers() {
  try {
    const res: any = await request.get('/users?limit=100')
    // API 返回结构: { code: 200, data: { users: [], total, page, limit } }
    users.value = res.data?.users || []
    console.log('[VoiceCalls] 获取到用户列表:', users.value.length, '个用户', res)
  } catch (error) {
    console.error('获取用户列表失败:', error)
  }
}

async function fetchStats() {
  try {
    const res: any = await callApi.getStats()
    const data = res.data
    stats.answer_rate = data.answer_rate || 0
    stats.avg_duration_sec = data.avg_duration_sec || 0
  } catch (error) {
    console.error('获取统计失败:', error)
  }
}

function handleCardClick(target: any) {
  const socket = getSocket()
  if (!socket || !socket.connected) {
    message.error('通信服务未连接，请稍后再试')
    return
  }

  outgoingCallModal.targetId = target.clientId
  outgoingCallModal.targetName = target.name
  startCall(target)
}

async function startCall(target: any) {
  calling.value = true
  console.log('[VoiceCalls] 发起呼叫:', {
    caller_id: appStore.userInfo?.username || 'FD-01',
    callee_type: target.type,
    callee_id: target.clientId
  })
  try {
    const res = await callApi.outbound({
      caller_id: appStore.userInfo?.username || 'FD-01',
      callee_type: target.type,
      callee_id: target.clientId,
      caller_type: 'front_desk'
    })

    const callData = (res as any).data
    outgoingCallModal.callId = callData.call_id
    outgoingCallModal.visible = true

    // 设置全局当前通话，让悬浮窗显示
    appStore.setCurrentCall({
      call_id: callData.call_id,
      caller_id: appStore.userInfo?.username || 'FD-01',
      caller_type: 'front_desk',
      callee_id: target.clientId,
      callee_type: target.type,
      caller_name: target.name,
      status: 'calling'
    })

    console.log('[VoiceCalls] 等待对方接听，全局通话已设置')

    await fetchCalls()
  } catch (error) {
    message.error('发起呼叫失败')
  } finally {
    calling.value = false
  }
}

function handleOutgoingCancel() {
  if (outgoingCallModal.callId) {
    callApi.hangup(outgoingCallModal.callId)
  }
  outgoingCallModal.visible = false
  // 清除全局通话状态
  appStore.clearCurrentCall()
}

// 挂断当前通话
function hangupCurrentCall() {
  if (appStore.currentCall?.call_id) {
    callApi.hangup(appStore.currentCall.call_id)
    const socket = getSocket()
    if (socket) {
      socket.emit('hangup_call', { call_id: appStore.currentCall.call_id })
    }
  }
  stopCallDurationTimer()
}

// 启动通话时长计时
function startCallDurationTimer() {
  callStartTime.value = Date.now()
  callDurationTimer.value = setInterval(() => {
    if (callStartTime.value) {
      const elapsed = Math.floor((Date.now() - callStartTime.value) / 1000)
      const minutes = Math.floor(elapsed / 60).toString().padStart(2, '0')
      const seconds = (elapsed % 60).toString().padStart(2, '0')
      currentCallDuration.value = `${minutes}:${seconds}`
    }
  }, 1000)
}

// 停止通话时长计时
function stopCallDurationTimer() {
  if (callDurationTimer.value) {
    clearInterval(callDurationTimer.value)
    callDurationTimer.value = null
  }
  callStartTime.value = null
  currentCallDuration.value = '00:00'
}

async function toggleRegister() {
  // 此函数已废弃，现在由 websocket.ts 自动处理登录即上线
  message.info('系统已自动为您接通在线状态')
}

// 使用命名函数以便正确移除监听器
const handleOnlineStatus = (data: any) => {
  onlineStatus.value = data
}

const handleCallAnswered = (data: any) => {
  console.log('[VoiceCalls] 收到call_answered:', data)

  // 处理外呼通话
  if (data.call_id === outgoingCallModal.callId) {
    outgoingCallModal.visible = false
    message.success('对方已接听')
  }

  // 更新全局通话状态为已连接（包括来电）
  if (appStore.currentCall?.call_id === data.call_id) {
    appStore.setCurrentCall({
      ...appStore.currentCall,
      status: 'connected'
    })
    // 启动通话时长计时
    startCallDurationTimer()
    message.success('通话已连接')
  }

  fetchCalls()
}

const handleCallRejected = (data: any) => {
  if (data.call_id === outgoingCallModal.callId) {
    outgoingCallModal.visible = false
    message.warning('通话被拒接')
    appStore.clearCurrentCall()
    stopCallDurationTimer()
    fetchCalls()
  } else if (appStore.currentCall?.call_id === data.call_id) {
    appStore.clearCurrentCall()
    stopCallDurationTimer()
    message.warning('通话被拒接')
    fetchCalls()
  }
}

const handleCallHungup = (data: any) => {
  if (data.call_id === outgoingCallModal.callId) {
    outgoingCallModal.visible = false
    message.info('通话已挂断')
    appStore.clearCurrentCall()
    stopCallDurationTimer()
    fetchCalls()
  } else if (appStore.currentCall?.call_id === data.call_id) {
    appStore.clearCurrentCall()
    stopCallDurationTimer()
    message.info('对方已挂断')
    fetchCalls()
  }
}

// 处理来电（包括AI转接）
const handleIncomingCall = (data: any) => {
  console.log('[VoiceCalls] 收到来电:', data)

  // 设置来电信息
  appStore.setIncomingCall({
    call_id: data.call_id,
    caller_id: data.caller_id,
    caller_type: data.caller_type,
    caller_name: data.caller_name || data.caller_id,
    callee_id: data.callee_id,
    callee_type: data.callee_type,
    isTransfer: data.isTransfer,
    transferReason: data.transferReason
  })

  // 显示来电提醒
  if (data.isTransfer) {
    message.info(`AI管家转接: ${data.transferReason || '客人要求转人工'}`)
  }
}

function setupSignalingListeners() {
  const socket = getSocket()
  if (!socket) return

  // 先移除旧的监听器，避免重复
  socket.off('online_status', handleOnlineStatus)
  socket.off('call_answered', handleCallAnswered)
  socket.off('call_rejected', handleCallRejected)
  socket.off('call_hungup', handleCallHungup)
  socket.off('incoming_call', handleIncomingCall)

  // 添加新的监听器
  socket.on('online_status', handleOnlineStatus)
  socket.on('call_answered', handleCallAnswered)
  socket.on('call_rejected', handleCallRejected)
  socket.on('call_hungup', handleCallHungup)
  socket.on('incoming_call', handleIncomingCall)
}

onMounted(async () => {
  await Promise.all([fetchCalls(), fetchUsers(), hotelStore.fetchRooms({ pageSize: 300 }), fetchStats()])

  const socket = initWebSocket()
  if (socket) {
    setupSignalingListeners()

    socket.on('connect', () => {
      socket.emit('get_online_status')
    })

    if (socket.connected) {
      socket.emit('get_online_status')
    }
  }

  // 定时刷新
  fetchCallsTimer.value = setInterval(fetchCalls, 10000)
})

onUnmounted(() => {
  const socket = getSocket()
  if (socket) {
    // 只移除当前组件添加的特定监听器
    socket.off('online_status', handleOnlineStatus)
    socket.off('call_answered', handleCallAnswered)
    socket.off('call_rejected', handleCallRejected)
    socket.off('call_hungup', handleCallHungup)
  }
  if (fetchCallsTimer.value) {
    clearInterval(fetchCallsTimer.value)
  }
})

const historyColumns = [
  { title: '主叫', dataIndex: 'caller_id', width: 120 },
  { title: '被叫', dataIndex: 'callee_id', width: 120 },
  { title: '状态', dataIndex: 'status', key: 'status', width: 100 },
  { title: '时长', dataIndex: 'duration_sec', key: 'duration', width: 100 },
  { title: '时间', dataIndex: 'started_at', width: 180 }
]
</script>

<style scoped>
/* 话务调度面板样式 */
.calls-main-layout {
  display: flex;
  gap: 16px;
  align-items: flex-start;
}

.duty-management-card {
  width: 320px;
  flex-shrink: 0;
  border-radius: 12px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.05);
}

.duty-controls {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.control-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.control-item .label {
  color: #595959;
  font-weight: 500;
}

.mic-check-section {
  margin-top: 8px;
}

.mic-error-tip {
  margin-top: 8px;
  font-size: 12px;
  color: #ff4d4f;
  text-align: center;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 4px;
}

.section-header {
  margin-bottom: 12px;
}

.section-header .title {
  display: block;
  font-weight: 600;
  font-size: 14px;
}

.section-header .subtitle {
  font-size: 12px;
  color: #bfbfbf;
}

.staff-list-mini {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.staff-item-mini {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px;
  background: #fafafa;
  border-radius: 8px;
}

.staff-name {
  flex: 1;
  font-size: 14px;
}

.call-tabs {
  flex: 1;
  background: #fff;
  padding: 16px;
  border-radius: 12px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.05);
}

.voice-calls-container { padding: 0; }
.stat-row { margin-bottom: 16px; }
.stat-card { border-radius: 8px; }
.registration-status { display: flex; flex-direction: column; gap: 8px; }
.reg-info { font-size: 12px; }
.reg-info .value { font-weight: bold; margin-left: 4px; color: #1890ff; }

/* 当前通话区域 */
.current-call-section {
  margin-bottom: 16px;
}
.current-call-card {
  border: 2px solid #1890ff;
  border-radius: 8px;
}
.current-call-card.connected {
  border-color: #52c41a;
}
.current-call-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}
.current-call-header .call-icon {
  color: #1890ff;
  font-size: 18px;
}
.current-call-card.connected .call-icon {
  color: #52c41a;
}
.current-call-header .call-title {
  font-weight: 500;
  flex: 1;
}
.current-call-info {
  margin-bottom: 12px;
}
.current-call-info .caller-name {
  font-size: 16px;
  font-weight: 600;
  color: #333;
}
.current-call-info .call-duration {
  font-size: 14px;
  color: #666;
  margin-top: 4px;
}
.current-call-actions {
  display: flex;
  justify-content: flex-end;
}

.call-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  gap: 16px;
  padding: 16px 0;
}

.call-card {
  background: #fff;
  border: 1px solid #f0f0f0;
  border-radius: 12px;
  padding: 20px;
  cursor: pointer;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  position: relative;
  text-align: center;
  box-shadow: 0 2px 8px rgba(0,0,0,0.04);
}

.call-card.room.vacant { border-left: 4px solid #52c41a; }
.call-card.room.occupied { border-left: 4px solid #ff4d4f; }
.call-card.room.cleaning { border-left: 4px solid #1890ff; }
.call-card.room.maintenance { border-left: 4px solid #faad14; }
.call-card.staff { border-left: 4px solid #722ed1; }

.call-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 24px rgba(0,0,0,0.12);
}

.card-status-dot {
  position: absolute;
  top: 12px;
  right: 12px;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #d9d9d9;
}
.card-status-dot.online {
  background: #52c41a;
  box-shadow: 0 0 8px rgba(82, 196, 26, 0.6);
}

.card-icon {
  font-size: 32px;
  color: #8c8c8c;
  margin-bottom: 12px;
}

.call-card.room .card-icon { color: #1890ff; }
.call-card.front_desk .card-icon { color: #722ed1; }

.card-name { font-size: 18px; font-weight: bold; color: #262626; margin-bottom: 4px; }
.card-desc { font-size: 12px; color: #8c8c8c; }

.card-action-hint {
  margin-top: 12px;
  font-size: 12px;
  color: #1890ff;
  opacity: 0;
  transition: opacity 0.3s;
}
.call-card:hover .card-action-hint { opacity: 1; }

.outgoing-call-content { text-align: center; padding: 32px 0; }

.grid-scroll { max-height: calc(100vh - 300px); overflow-y: auto; padding-right: 8px; }
</style>
