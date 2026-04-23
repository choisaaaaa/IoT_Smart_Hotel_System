<template>
  <div class="device-monitor-container">
    <!-- Header Section -->
    <div class="page-header">
      <div class="header-left">
        <h2 class="page-title">设备监控中心</h2>
        <p class="page-subtitle">实时监控门店 IoT 设备状态与审核新接入终端</p>
      </div>
      <div class="header-right">
        <a-space size="middle">
          <a-statistic title="在线设备" :value="stats.online" :value-style="{ color: '#3f8600' }">
            <template #prefix><CheckCircleOutlined /></template>
          </a-statistic>
          <a-statistic title="离线设备" :value="stats.offline" :value-style="{ color: '#cf1322' }">
            <template #prefix><CloseCircleOutlined /></template>
          </a-statistic>
          <a-statistic title="待审核" :value="stats.pending" :value-style="{ color: '#faad14' }">
            <template #prefix><ClockCircleOutlined /></template>
          </a-statistic>
          <a-button type="primary" shape="round" @click="fetchDevices" :loading="loading">
            <template #icon><SyncOutlined /></template>
            刷新数据
          </a-button>
        </a-space>
      </div>
    </div>

    <!-- Alert for login status -->
    <a-alert v-if="!isLoggedIn" type="warning" show-icon class="mb-4">
      <template #message>
        <span>登录状态异常，请 <a @click="goToLogin">重新登录</a> 以确保操作权限。</span>
      </template>
    </a-alert>

    <!-- Main Content -->
    <div class="content-wrapper">
      <a-tabs v-model:activeKey="activeTab" type="line" size="large">
        <!-- Active Devices Tab -->
        <a-tab-pane key="active">
          <template #tab>
            <span><DesktopOutlined /> 已激活设备</span>
          </template>

          <div class="filter-bar">
            <a-input-search
              v-model:value="searchQuery"
              placeholder="搜索设备名称、ID或房间号..."
              style="width: 300px"
              @search="handleSearch"
            />
            <a-radio-group v-model:value="filterStatus" @change="handleSearch">
              <a-radio-button value="all">全部</a-radio-button>
              <a-radio-button value="online">在线</a-radio-button>
              <a-radio-button value="offline">离线</a-radio-button>
            </a-radio-group>
            <a-button @click="showDebugInfo = !showDebugInfo" type="text">
              <template #icon><BugOutlined /></template>
              {{ showDebugInfo ? '隐藏' : '显示' }}调试
            </a-button>
          </div>

          <!-- Debug Panel -->
          <a-collapse v-if="showDebugInfo" class="mb-4">
            <a-collapse-panel key="debug" header="开发者调试信息">
              <div class="debug-content">
                <p><strong>当前 Token:</strong> <code>{{ authToken.substring(0, 20) }}...</code></p>
                <p><strong>API 响应:</strong></p>
                <pre>{{ debugInfo }}</pre>
              </div>
            </a-collapse-panel>
          </a-collapse>

          <a-skeleton :loading="loading" active>
            <a-row :gutter="[16, 16]">
              <a-col :xs="24" :sm="12" :md="8" :lg="6" v-for="device in filteredActiveDevices" :key="device.id">
                <a-card hoverable class="modern-device-card">
                  <template #cover>
                    <div :class="['card-banner', device.device_status]">
                      <div class="status-indicator">
                        <span class="dot"></span>
                        {{ statusText(device.device_status) }}
                      </div>
                      <component :is="getDeviceIcon(device.device_type)" class="device-icon-large" />
                    </div>
                  </template>

                  <div class="card-body">
                    <div class="device-title">
                      <h3 class="name">{{ device.device_name }}</h3>
                      <a-tag :color="getTypeColor(device.device_type)">{{ device.device_type }}</a-tag>
                    </div>
                    <div class="device-meta">
                      <div class="meta-item">
                        <span class="label">设备ID</span>
                        <span class="value"><code>{{ device.device_id }}</code></span>
                      </div>
                      <div class="meta-item">
                        <span class="label">所属区域</span>
                        <span class="value">{{ device.room_number || device.area || '未分配' }}</span>
                      </div>
                      <div class="meta-item">
                        <span class="label">最后在线</span>
                        <span class="value">{{ formatTime(device.last_seen) }}</span>
                      </div>
                    </div>
                  </div>

                  <template #actions>
                    <a-tooltip title="发送控制指令">
                      <ControlOutlined @click="sendCommand(device)" :class="{ disabled: device.device_status !== 'online' }" />
                    </a-tooltip>
                    <a-tooltip title="设备二次分配/修改">
                      <EditOutlined @click="openEditModal(device)" />
                    </a-tooltip>
                    <a-tooltip title="仿真调试控制台">
                      <ExperimentOutlined @click="openDebugTerminal(device)" />
                    </a-tooltip>
                    <a-tooltip title="查看实时数据">
                      <LineChartOutlined @click="viewData(device)" />
                    </a-tooltip>
                    <a-popconfirm title="确定要移除此设备吗？" @confirm="deleteDevice(device.id)">
                      <DeleteOutlined style="color: #ff4d4f" />
                    </a-popconfirm>
                  </template>
                </a-card>
              </a-col>
            </a-row>
            <a-empty v-if="!filteredActiveDevices.length && !loading" :description="searchQuery ? '未找到匹配的设备' : '暂无活跃设备'" />
          </a-skeleton>
        </a-tab-pane>

        <!-- Pending Audit Tab -->
        <a-tab-pane key="audit">
          <template #tab>
            <a-badge :count="stats.pending" :offset="[10, -5]">
              <span><SafetyCertificateOutlined /> 待审核清单</span>
            </a-badge>
          </template>

          <div class="audit-section">
            <div class="audit-header">
              <a-alert message="新设备接入提示" description="以下设备正尝试连接系统，请确认其物理位置并分配对应的房间号或区域名称。" type="info" show-icon />
            </div>

            <a-table
              :dataSource="pendingDevices"
              :columns="auditColumns"
              :loading="loading"
              class="modern-table"
              :pagination="{ pageSize: 10 }"
            >
              <template #bodyCell="{ column, record }">
                <template v-if="column.key === 'type'">
                  <a-tag :color="getTypeColor(record.device_type)">{{ record.device_type }}</a-tag>
                </template>
                <template v-if="column.key === 'network'">
                  <div class="network-info">
                    <span>IP: {{ record.ip_address || '127.0.0.1' }}</span>
                    <span>MAC: {{ record.mac_address || 'N/A' }}</span>
                  </div>
                </template>
                <template v-if="column.key === 'action'">
                  <a-button type="primary" ghost @click="openAuditModal(record)">
                    <template #icon><AuditOutlined /></template>
                    立即审核
                  </a-button>
                </template>
              </template>
            </a-table>
          </div>
        </a-tab-pane>
      </a-tabs>
    </div>

    <!-- Audit & Reassign Modal -->
    <a-modal 
      v-model:open="auditModalVisible" 
      :title="isReassign ? '设备配置二次分配' : '设备准入审核'" 
      @ok="confirmAudit" 
      :confirmLoading="auditLoading" 
      width="600px"
    >
      <div class="modal-intro" :class="{ reassign: isReassign }">
        <div class="intro-icon">
          <component :is="isReassign ? EditOutlined : SafetyOutlined" />
        </div>
        <div class="intro-text">
          <h4>{{ isReassign ? '重新配置设备资产' : `正在为 ${currentAudit.device_id} 分配权限` }}</h4>
          <p>{{ isReassign ? '修改设备关联的房间、位置或显示名称。' : '审核通过后，系统将下发加密通讯密钥至该物理终端。' }}</p>
        </div>
      </div>

      <a-form layout="vertical" class="mt-4">
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="设备显示名称">
              <a-input v-model:value="currentAudit.device_name" placeholder="例如：301室智能终端" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="设备类型">
              <a-tag :color="getTypeColor(currentAudit.device_type)">{{ currentAudit.device_type }}</a-tag>
            </a-form-item>
          </a-col>
        </a-row>

        <!-- Smart fields based on device type -->
        <div class="smart-assignment-box">
          <div v-if="currentAudit.device_type === 'room'" class="type-assignment">
            <div class="assignment-header"><HomeOutlined /> 客房资产分配</div>
            <a-form-item label="关联房间">
              <a-select v-model:value="currentAudit.room_id" placeholder="搜索并选择关联房间" allowClear show-search option-filter-prop="label">
                <a-select-option v-for="room in rooms" :key="room.id" :value="room.id" :label="room.room_number">
                  <div class="room-option">
                    <span class="room-num">{{ room.room_number }}</span>
                    <span class="room-type">{{ room.room_type }}</span>
                  </div>
                </a-select-option>
              </a-select>
            </a-form-item>
          </div>

          <div v-else-if="currentAudit.device_type === 'floor'" class="type-assignment">
            <div class="assignment-header"><ClusterOutlined /> 楼层/公共区域分配</div>
            <a-form-item label="所在楼层/区域">
              <a-select v-model:value="currentAudit.area" placeholder="选择或输入所在位置" allowClear show-search mode="combobox">
                <a-select-option value="Floor 1">1层大厅</a-select-option>
                <a-select-option value="Floor 2">2层客房区</a-select-option>
                <a-select-option value="Floor 3">3层客房区</a-select-option>
                <a-select-option value="Gym">健身房</a-select-option>
                <a-select-option value="Restaurant">餐厅</a-select-option>
              </a-select>
            </a-form-item>
          </div>

          <div v-else-if="currentAudit.device_type === 'front_desk'" class="type-assignment">
            <div class="assignment-header"><TeamOutlined /> 前台/管理点分配</div>
            <a-form-item label="前台编号/名称">
              <a-input v-model:value="currentAudit.area" placeholder="如：主楼前台 01" />
            </a-form-item>
          </div>

          <div v-else class="type-assignment">
            <div class="assignment-header"><SettingOutlined /> 通用位置分配</div>
            <a-form-item label="地理位置/区域">
              <a-input v-model:value="currentAudit.area" placeholder="请输入设备安装的具体位置" />
            </a-form-item>
          </div>
        </div>

        <a-form-item v-if="!isReassign" label="审核决策">
          <a-radio-group v-model:value="currentAudit.status" button-style="solid">
            <a-radio-button value="approved">准许接入</a-radio-button>
            <a-radio-button value="rejected">拒绝接入</a-radio-button>
          </a-radio-group>
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- Debug Terminal Modal -->
    <a-modal 
      v-model:open="debugTerminalVisible" 
      :title="`设备仿真调试控制台 - ${currentDebug.deviceId}`" 
      width="850px"
      :footer="null"
      @cancel="closeDebugTerminal"
    >
      <div class="debug-terminal">
        <!-- Sidebar: Device Info & Simulation Tools -->
        <div class="terminal-sidebar">
          <div class="device-card-mini">
            <component :is="getDeviceIcon(currentDebug.deviceType)" class="mini-icon" />
            <div class="mini-info">
              <div class="name">{{ currentDebug.deviceName }}</div>
              <a-tag :color="getTypeColor(currentDebug.deviceType)">{{ currentDebug.deviceType }}</a-tag>
            </div>
          </div>

          <a-divider>模拟指令下发</a-divider>
          <div class="simulation-tools">
            <a-button-group vertical block>
              <a-button v-for="sim in simulationCommands" :key="sim.label" @click="sendSimulationCommand(sim)">
                {{ sim.label }}
              </a-button>
            </a-button-group>
            
            <div class="custom-send mt-4">
              <p class="small-label">自定义 MQTT 消息</p>
              <a-input v-model:value="customMqtt.topic" placeholder="Topic" size="small" class="mb-2" />
              <a-textarea v-model:value="customMqtt.payload" placeholder="Payload (JSON)" :rows="4" size="small" class="mb-2" />
              <a-button type="primary" block size="small" @click="sendCustomMqtt">
                <template #icon><SendOutlined /></template> 发送
              </a-button>
            </div>
          </div>
        </div>

        <!-- Main: Message Logs -->
        <div class="terminal-main">
          <div class="terminal-header">
            <span class="title"><HistoryOutlined /> 通信日志流水</span>
            <a-space>
              <a-checkbox v-model:checked="autoScroll">自动滚动</a-checkbox>
              <a-button size="small" @click="fetchMqttLogs(true)">
                <template #icon><SyncOutlined /></template> 刷新
              </a-button>
              <a-button size="small" @click="mqttLogs = []">
                <template #icon><ClearOutlined /></template> 清屏
              </a-button>
            </a-space>
          </div>
          <div class="log-container" ref="logContainerRef">
            <div v-for="log in mqttLogs" :key="log.id" class="log-item" :class="log.direction">
              <div class="log-time">{{ formatTime(log.timestamp) }}</div>
              <div class="log-topic"><code>{{ log.topic }}</code></div>
              <div class="log-payload">
                <pre>{{ formatPayload(log.payload) }}</pre>
              </div>
            </div>
            <div v-if="mqttLogs.length === 0" class="log-empty">等待通信数据中...</div>
          </div>
        </div>
      </div>
    </a-modal>

    <!-- Command Modal -->
    <a-modal v-model:open="cmdModalVisible" title="远程指令控制" @ok="confirmCommand" :confirmLoading="cmdLoading">
      <div class="command-panel">
        <div class="target-info">
          <component :is="getDeviceIcon(currentCmd.deviceType)" class="cmd-icon" />
          <div>
            <div class="name">{{ currentCmd.deviceName }}</div>
            <div class="id">{{ currentCmd.deviceId }}</div>
          </div>
        </div>

        <a-divider />

        <a-form layout="vertical">
          <a-form-item label="选择指令类型">
            <a-select v-model:value="currentCmd.commandType">
              <a-select-option value="ping">Ping 连通性测试</a-select-option>
              <a-select-option value="restart">远程重启终端</a-select-option>
              <a-select-option value="status_query">全状态同步查询</a-select-option>
              <a-select-option value="firmware_update">OTA 固件升级</a-select-option>
            </a-select>
          </a-form-item>
          <a-form-item label="指令参数 (可选)">
            <a-input v-model:value="currentCmd.commandValue" placeholder="请输入指令所需参数" />
          </a-form-item>
        </a-form>
      </div>
    </a-modal>

    <!-- Sensor Data Modal -->
    <a-modal 
      v-model:open="sensorModalVisible" 
      :title="`实时数据 - ${currentSensor.deviceName}`" 
      width="700px"
      :footer="null"
    >
      <a-spin :spinning="sensorLoading">
        <div v-if="sensorData.length === 0 && !sensorLoading" style="text-align: center; padding: 40px; color: #8c8c8c;">
          <LineChartOutlined style="font-size: 48px; color: #d9d9d9; margin-bottom: 16px;" />
          <p>暂无传感器数据</p>
          <p style="font-size: 12px;">设备可能未上报数据或尚未配置传感器</p>
        </div>
        <div v-else>
          <a-row :gutter="[12, 12]">
            <a-col :xs="24" :sm="12" v-for="sensor in sensorData" :key="sensor.sensor_type">
              <a-card size="small" :class="['sensor-card', getSensorStatus(sensor)]">
                <div class="sensor-header">
                  <span class="sensor-type">{{ getSensorTypeName(sensor.sensor_type) }}</span>
                  <a-tag :color="getSensorStatusColor(sensor)" size="small">{{ getSensorStatusText(sensor) }}</a-tag>
                </div>
                <div class="sensor-value">
                  {{ sensor.sensor_value ?? '--' }}
                  <span class="sensor-unit">{{ sensor.unit || '' }}</span>
                </div>
                <div class="sensor-meta">
                  <span>更新: {{ formatTime(sensor.created_at) }}</span>
                </div>
              </a-card>
            </a-col>
          </a-row>
        </div>
      </a-spin>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { message } from 'ant-design-vue'
import {
  SyncOutlined, CheckCircleOutlined, CloseCircleOutlined, ClockCircleOutlined,
  DesktopOutlined, SafetyCertificateOutlined, BugOutlined, ControlOutlined,
  LineChartOutlined, DeleteOutlined, AuditOutlined, SafetyOutlined,
  BulbOutlined, LayoutOutlined, UserOutlined, SettingOutlined, EditOutlined,
  HomeOutlined, ClusterOutlined, TeamOutlined, ExperimentOutlined,
  SendOutlined, ClearOutlined, HistoryOutlined
} from '@ant-design/icons-vue'
import type { DeviceInfo, RoomInfo } from '@/types'
import { deviceApi } from '@/api/device'
import { roomApi } from '@/api/room'
import request from '@/api/request'
import dayjs from 'dayjs'
import relativeTime from 'dayjs/plugin/relativeTime'
import { formatDotDateTime } from '@/utils/date'

dayjs.extend(relativeTime)

const router = useRouter()

// UI State
const activeTab = ref('active')
const loading = ref(false)
const searchQuery = ref('')
const filterStatus = ref('all')
const showDebugInfo = ref(false)
const debugInfo = ref('')

// Data State
const devices = ref<any[]>([])
const rooms = ref<RoomInfo[]>([])

// Computed Stats
const stats = computed(() => ({
  online: devices.value.filter(d => d.device_status === 'online' && d.audit_status === 'approved').length,
  offline: devices.value.filter(d => d.device_status !== 'online' && d.audit_status === 'approved').length,
  pending: devices.value.filter(d => d.audit_status === 'pending').length
}))

// Auth State
const isLoggedIn = computed(() => !!localStorage.getItem('auth_token'))
const authToken = computed(() => localStorage.getItem('auth_token') || '')

const goToLogin = () => {
  router.push('/guest/booking?login=1')
}

// Device Filtering
const filteredActiveDevices = computed(() => {
  let list = devices.value.filter(d => d.audit_status === 'approved')

  if (filterStatus.value !== 'all') {
    list = list.filter(d => d.device_status === filterStatus.value)
  }

  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase()
    list = list.filter(d =>
      d.device_name.toLowerCase().includes(q) ||
      d.device_id.toLowerCase().includes(q) ||
      (d.room_number && d.room_number.toLowerCase().includes(q))
    )
  }

  return list
})

const pendingDevices = computed(() => devices.value.filter(d => d.audit_status === 'pending'))

const auditColumns = [
  { title: '终端识别码 (Device ID)', dataIndex: 'device_id', key: 'device_id' },
  { title: '类型', key: 'type', width: 120 },
  { title: '网络指纹', key: 'network' },
  { title: '首次上报时间', dataIndex: 'created_at', key: 'created_at', customRender: ({ text }: any) => formatDotDateTime(text) },
  { title: '操作', key: 'action', fixed: 'right', width: 150 }
]

// Modal States
const auditModalVisible = ref(false)
const auditLoading = ref(false)
const isReassign = ref(false)
const currentAudit = reactive({
  id: 0,
  device_id: '',
  device_name: '',
  device_type: '',
  room_id: undefined as number | undefined,
  area: '',
  status: 'approved' as 'approved' | 'rejected'
})

const cmdModalVisible = ref(false)
const cmdLoading = ref(false)
const currentCmd = reactive({
  id: 0,
  deviceId: '',
  deviceName: '',
  deviceType: '',
  commandType: 'ping',
  commandValue: ''
})

const sensorModalVisible = ref(false)
const sensorLoading = ref(false)
const sensorData = ref<any[]>([])
const currentSensor = reactive({
  id: 0,
  deviceId: '',
  deviceName: '',
  deviceType: ''
})

// Debug Terminal State
const debugTerminalVisible = ref(false)
const mqttLogs = ref<any[]>([])
const autoScroll = ref(true)
const logContainerRef = ref<HTMLElement | null>(null)
const logTimer = ref<any>(null)
const currentDebug = reactive({
  id: 0,
  deviceId: '',
  deviceName: '',
  deviceType: ''
})
const customMqtt = reactive({
  topic: '',
  payload: ''
})

const simulationCommands = computed(() => {
  const type = currentDebug.deviceType
  const deviceId = currentDebug.deviceId
  const roomId = deviceId.includes('_') 
    ? deviceId.split('_').pop() 
    : deviceId
    
  if (type === 'room') {
    return [
      { label: '💡 开灯', topic: `hotel/device/command/room/room_${roomId}`, payload: { device_id: `room_${roomId}`, command_type: 'light', command_value: 'on' } },
      { label: '💡 关灯', topic: `hotel/device/command/room/room_${roomId}`, payload: { device_id: `room_${roomId}`, command_type: 'light', command_value: 'off' } },
      { label: '🚪 开锁', topic: `hotel/device/command/room/room_${roomId}`, payload: { device_id: `room_${roomId}`, command_type: 'door', command_value: 'unlock' } },
      { label: '🚪 上锁', topic: `hotel/device/command/room/room_${roomId}`, payload: { device_id: `room_${roomId}`, command_type: 'door', command_value: 'lock' } },
      { label: '🌙 睡眠模式', topic: `hotel/room/${roomId}/scene`, payload: { scene: 'sleep', device_id: `room_${roomId}` } },
      { label: '👋 欢迎模式', topic: `hotel/room/${roomId}/scene`, payload: { scene: 'welcome', device_id: `room_${roomId}` } },
      { label: '📞 模拟来电', topic: `hotel/device/command/room/room_${roomId}`, payload: { device_id: `room_${roomId}`, command_type: 'incoming_call', call_id: `call_${Date.now()}`, broadcast_text: '前台呼叫' } }
    ]
  } else if (type === 'floor') {
    return [
      { label: '💡 走廊照明-开', topic: `hotel/device/command/floor/${deviceId}`, payload: { device_id: deviceId, command_type: 'light', command_value: 'on' } },
      { label: '💡 走廊照明-关', topic: `hotel/device/command/floor/${deviceId}`, payload: { device_id: deviceId, command_type: 'light', command_value: 'off' } },
      { label: '📢 开始广播', topic: `hotel/device/command/floor/${deviceId}`, payload: { device_id: deviceId, command_type: 'broadcast_start' } },
      { label: '🔇 停止广播', topic: `hotel/device/command/floor/${deviceId}`, payload: { device_id: deviceId, command_type: 'broadcast_stop' } },
      { label: '🚨 触发消防报警', topic: `hotel/security/event`, payload: { device_id: deviceId, event_type: 'fire_alarm', level: 'critical', data: { floor_id: roomId, message: '消防报警测试' } } },
      { label: '✅ 确认报警', topic: `hotel/device/command/floor/${deviceId}`, payload: { device_id: deviceId, command_type: 'alarm_ack' } },
      { label: '🔄 复位报警', topic: `hotel/device/command/floor/${deviceId}`, payload: { device_id: deviceId, command_type: 'alarm_reset' } },
      { label: '🔄 系统复位', topic: `hotel/device/command/floor/${deviceId}`, payload: { device_id: deviceId, command_type: 'floor_reset' } }
    ]
  } else if (type === 'front_desk') {
    return [
      { label: '🆕 开卡-房间301', topic: `hotel/device/command/front_desk/${deviceId}`, payload: { device_id: deviceId, command_type: 'room_card_op', command_value: { action: 'issue', room_number: '301', booking_id: 'BK001' } } },
      { label: '🆕 开卡-房间302', topic: `hotel/device/command/front_desk/${deviceId}`, payload: { device_id: deviceId, command_type: 'room_card_op', command_value: { action: 'issue', room_number: '302', booking_id: 'BK002' } } },
      { label: '🔍 验卡', topic: `hotel/device/command/front_desk/${deviceId}`, payload: { device_id: deviceId, command_type: 'verify_card' } },
      { label: '📟 刷卡', topic: `hotel/device/command/front_desk/${deviceId}`, payload: { device_id: deviceId, command_type: 'swipe_card' } },
      { label: '🗑️ 退卡', topic: `hotel/device/command/front_desk/${deviceId}`, payload: { device_id: deviceId, command_type: 'room_card_op', command_value: { action: 'revoke', room_number: '301' } } },
      { label: '📞 广播呼叫301', topic: `hotel/device/command/room/room_301`, payload: { device_id: deviceId, command_type: 'incoming_call', call_id: `call_${Date.now()}`, broadcast_text: '前台呼叫房间301' } },
      { label: '🔇 挂断通话', topic: `hotel/device/command/room/room_301`, payload: { device_id: deviceId, command_type: 'hangup_call', call_id: 'call_latest' } }
    ]
  }
  return []
})

function openDebugTerminal(device: any) {
  Object.assign(currentDebug, {
    id: device.id,
    deviceId: device.device_id,
    deviceName: device.device_name,
    deviceType: device.device_type
  })
  debugTerminalVisible.value = true
  fetchMqttLogs()
  logTimer.value = setInterval(() => fetchMqttLogs(), 3000)
}

function closeDebugTerminal() {
  if (logTimer.value) clearInterval(logTimer.value)
  debugTerminalVisible.value = false
}

async function fetchMqttLogs(isManual = false) {
  try {
    const res: any = await request.get('/mqtt/logs', { 
      params: { device_id: currentDebug.deviceId, limit: 50 } 
    })
    if (res.success) {
      mqttLogs.value = res.data
      if (autoScroll.value && logContainerRef.value) {
        setTimeout(() => {
          logContainerRef.value!.scrollTop = logContainerRef.value!.scrollHeight
        }, 100)
      }
    }
  } catch (err) {
    if (isManual) message.error('刷新日志失败')
  }
}

function formatPayload(p: any) {
  if (typeof p === 'string') {
    try { return JSON.stringify(JSON.parse(p), null, 2) }
    catch { return p }
  }
  return JSON.stringify(p, null, 2)
}

async function sendSimulationCommand(sim: any) {
  try {
    // 添加时间戳和命令ID
    const payload = {
      ...sim.payload,
      timestamp: new Date().toISOString(),
      command_id: Date.now()
    }
    
    await request.post('/mqtt/send', {
      topic: sim.topic,
      payload: payload,
      qos: 1
    })
    message.success(`指令已发送: ${sim.label}`)
    fetchMqttLogs(true)
  } catch (err) {
    message.error('发送失败')
  }
}

async function sendCustomMqtt() {
  if (!customMqtt.topic || !customMqtt.payload) return
  try {
    let payload = customMqtt.payload
    try { payload = JSON.parse(customMqtt.payload) } catch {}
    
    await request.post('/mqtt/send', {
      topic: customMqtt.topic,
      payload
    })
    message.success('消息已发布')
    fetchMqttLogs(true)
  } catch (err) {
    message.error('发送失败')
  }
}

// UI Helpers
const getDeviceIcon = (type: string) => {
  const map: Record<string, any> = {
    'room': LayoutOutlined,
    'front_desk': UserOutlined,
    'sensor': BulbOutlined,
    'gateway': SettingOutlined
  }
  return map[type] || DesktopOutlined
}

const getTypeColor = (type: string) => {
  const map: Record<string, string> = {
    'room': 'purple',
    'front_desk': 'blue',
    'sensor': 'orange',
    'gateway': 'cyan'
  }
  return map[type] || 'default'
}

const statusText = (s: string) => ({ online: '在线', offline: '离线', error: '异常' } as any)[s] || '未知'

const formatTime = (t: string) => t ? dayjs(t).fromNow() : '从未连接'

// API Actions
async function fetchDevices() {
  loading.value = true
  try {
    const res: any = await deviceApi.getDeviceList()
    // 兼容多种响应格式: { success: true, data: [...] } 或 { code: 200, data: [...] }
    if (res && res.success && Array.isArray(res.data)) {
      devices.value = res.data
    } else if (res && Array.isArray(res.data)) {
      devices.value = res.data
    } else if (Array.isArray(res)) {
      devices.value = res
    } else {
      devices.value = []
    }
    // 实时更新调试信息，展示完整的 API 原始响应
    debugInfo.value = JSON.stringify({
      timestamp: new Date().toISOString(),
      url: '/api/v1/devices',
      status: 'success',
      count: devices.value.length,
      raw_data: res
    }, null, 2)
  } catch (err: any) {
    message.error('同步设备状态失败')
    debugInfo.value = JSON.stringify({
      timestamp: new Date().toISOString(),
      status: 'error',
      message: err.message,
      stack: err.stack
    }, null, 2)
    console.error(err)
  } finally {
    loading.value = false
  }
}

async function fetchRooms() {
  try {
    const res: any = await roomApi.getRoomList({ pageSize: 1000 })
    // 兼容多种响应格式: { success: true, data: { list: [...] } } 或 { code: 200, data: { list: [...] } }
    const responseData = res.data || res
    if (responseData && responseData.list) {
      rooms.value = responseData.list
    } else if (Array.isArray(responseData)) {
      rooms.value = responseData
    } else if (responseData && Array.isArray(responseData.data)) {
      rooms.value = responseData.data
    }
  } catch (err) {
    console.error('获取房源信息失败', err)
  }
}

function handleSearch() {
  // Computed property handles this
}

function openAuditModal(record: any) {
  isReassign.value = false
  Object.assign(currentAudit, {
    id: record.id,
    device_id: record.device_id,
    device_name: record.device_name || '',
    device_type: record.device_type,
    room_id: record.room_id || undefined,
    area: record.area || '',
    status: 'approved'
  })
  auditModalVisible.value = true
}

function openEditModal(record: any) {
  isReassign.value = true
  Object.assign(currentAudit, {
    id: record.id,
    device_id: record.device_id,
    device_name: record.device_name || '',
    device_type: record.device_type,
    room_id: record.room_id || undefined,
    area: record.area || '',
    status: record.audit_status || 'approved'
  })
  auditModalVisible.value = true
}

async function confirmAudit() {
  auditLoading.value = true
  try {
    await deviceApi.auditDevice(currentAudit.id, {
      status: currentAudit.status,
      room_id: currentAudit.room_id,
      area: currentAudit.area,
      device_name: currentAudit.device_name
    })
    message.success('审核操作已提交')
    auditModalVisible.value = false
    fetchDevices()
  } catch (err) {
    message.error('审核处理失败')
  } finally {
    auditLoading.value = false
  }
}

async function deleteDevice(id: number) {
  try {
    await deviceApi.deleteDevice(id)
    message.success('设备已成功移除')
    fetchDevices()
  } catch (err) {
    message.error('移除失败')
  }
}

function sendCommand(device: any) {
  if (device.device_status !== 'online') return
  Object.assign(currentCmd, {
    id: device.id,
    deviceId: device.device_id,
    deviceName: device.device_name,
    deviceType: device.device_type,
    commandType: 'ping',
    commandValue: ''
  })
  cmdModalVisible.value = true
}

async function confirmCommand() {
  cmdLoading.value = true
  try {
    await deviceApi.sendCommand(currentCmd.id, currentCmd.commandType, currentCmd.commandValue)
    message.success(`控制指令已送达 ${currentCmd.deviceId}`)
    cmdModalVisible.value = false
  } catch (err) {
    message.error('指令发送失败')
  } finally {
    cmdLoading.value = false
  }
}

function viewData(device: any) {
  Object.assign(currentSensor, {
    id: device.id,
    deviceId: device.device_id,
    deviceName: device.device_name,
    deviceType: device.device_type
  })
  sensorModalVisible.value = true
  fetchSensorData(device.id)
}

async function fetchSensorData(deviceId: number) {
  sensorLoading.value = true
  try {
    const res: any = await request.get(`/devices/${deviceId}/sensor-data/latest`)
    if (res && res.success && Array.isArray(res.data)) {
      sensorData.value = res.data
    } else {
      sensorData.value = []
    }
  } catch (err) {
    sensorData.value = []
  } finally {
    sensorLoading.value = false
  }
}

function getSensorTypeName(type: string): string {
  const map: Record<string, string> = {
    temperature: '温度',
    humidity: '湿度',
    smoke_level: '烟雾浓度',
    light_level: '光照强度',
    noise_level: '噪音',
    pm25: 'PM2.5',
    co2: 'CO2',
    motion: '人体感应',
    door: '门磁',
    lock: '门锁',
    power: '功率',
    voltage: '电压',
    current: '电流'
  }
  return map[type] || type
}

function getSensorStatus(sensor: any): string {
  const val = parseFloat(sensor.sensor_value)
  if (isNaN(val)) return 'normal'
  const type = sensor.sensor_type
  if (type === 'temperature' && (val > 35 || val < 10)) return 'warning'
  if (type === 'humidity' && (val > 80 || val < 20)) return 'warning'
  if (type === 'smoke_level' && val > 50) return 'danger'
  if (type === 'pm25' && val > 150) return 'danger'
  if (type === 'pm25' && val > 75) return 'warning'
  return 'normal'
}

function getSensorStatusColor(sensor: any): string {
  const status = getSensorStatus(sensor)
  return { normal: 'green', warning: 'orange', danger: 'red' }[status] || 'default'
}

function getSensorStatusText(sensor: any): string {
  const status = getSensorStatus(sensor)
  return { normal: '正常', warning: '预警', danger: '报警' }[status] || '未知'
}

onMounted(() => {
  fetchDevices()
  fetchRooms()
})
</script>

<style scoped>
.device-monitor-container {
  padding: 24px;
  background: #f0f2f5;
  min-height: calc(100vh - 64px);
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
  background: #fff;
  padding: 20px 24px;
  border-radius: 8px;
  box-shadow: 0 1px 4px rgba(0,21,41,.08);
}

.page-title { margin: 0; font-size: 20px; font-weight: 600; }
.page-subtitle { margin: 4px 0 0; color: #8c8c8c; }

.content-wrapper {
  background: #fff;
  padding: 24px;
  border-radius: 8px;
  box-shadow: 0 1px 4px rgba(0,21,41,.08);
}

.filter-bar {
  display: flex;
  gap: 16px;
  margin-bottom: 24px;
  align-items: center;
}

.modern-device-card {
  border-radius: 12px;
  overflow: hidden;
  transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
  border: none;
  box-shadow: 0 2px 8px rgba(0,0,0,0.06);
}

.modern-device-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 12px 20px rgba(0,0,0,0.1);
}

.card-banner {
  height: 100px;
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
  background: #f5f5f5;
}

.card-banner.online { background: linear-gradient(135deg, #f6ffed 0%, #d9f7be 100%); }
.card-banner.offline { background: linear-gradient(135deg, #f5f5f5 0%, #e8e8e8 100%); }
.card-banner.error { background: linear-gradient(135deg, #fff1f0 0%, #ffccc7 100%); }

.status-indicator {
  position: absolute;
  top: 12px;
  left: 12px;
  font-size: 12px;
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 4px 10px;
  border-radius: 20px;
  background: rgba(255,255,255,0.8);
}

.online .dot { width: 8px; height: 8px; background: #52c41a; border-radius: 50%; box-shadow: 0 0 8px #52c41a; }
.offline .dot { width: 8px; height: 8px; background: #bfbfbf; border-radius: 50%; }

.device-icon-large { font-size: 48px; color: rgba(0,0,0,0.25); }
.online .device-icon-large { color: #52c41a; }

.card-body { padding: 16px; }
.device-title { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 16px; }
.device-title .name { margin: 0; font-size: 16px; font-weight: 600; flex: 1; }

.device-meta { display: flex; flex-direction: column; gap: 8px; }
.meta-item { display: flex; justify-content: space-between; font-size: 12px; }
.meta-item .label { color: #8c8c8c; }
.meta-item .value { font-weight: 500; }
.meta-item code { background: #f5f5f5; padding: 2px 4px; border-radius: 4px; }

.audit-section { padding: 8px 0; }
.audit-header { margin-bottom: 20px; }
.network-info { display: flex; flex-direction: column; font-size: 12px; color: #595959; }

.modal-intro {
  display: flex;
  gap: 16px;
  background: #e6f7ff;
  padding: 16px;
  border-radius: 8px;
  align-items: center;
}
.intro-icon { font-size: 32px; color: #1890ff; }
.intro-text h4 { margin: 0; font-size: 16px; }
.intro-text p { margin: 4px 0 0; color: #595959; }

.modal-intro.reassign { background: #f6ffed; }
.modal-intro.reassign .intro-icon { color: #52c41a; }

.smart-assignment-box {
  margin: 20px 0;
  padding: 16px;
  border: 1px dashed #d9d9d9;
  border-radius: 8px;
  background: #fafafa;
}

.type-assignment .assignment-header {
  font-weight: 600;
  margin-bottom: 12px;
  color: #595959;
  display: flex;
  align-items: center;
  gap: 8px;
}

.room-option { display: flex; justify-content: space-between; width: 100%; }
.room-type { color: #8c8c8c; font-size: 12px; }

/* Debug Terminal Styles */
.debug-terminal {
  display: flex;
  height: 550px;
  background: #fff;
  border: 1px solid #f0f0f0;
  border-radius: 8px;
  overflow: hidden;
}

.terminal-sidebar {
  width: 250px;
  border-right: 1px solid #f0f0f0;
  padding: 16px;
  display: flex;
  flex-direction: column;
  background: #fafafa;
}

.device-card-mini {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  background: #fff;
  border-radius: 8px;
  border: 1px solid #e8e8e8;
  margin-bottom: 16px;
}

.mini-icon { font-size: 24px; color: #1890ff; }
.mini-info .name { font-weight: 600; font-size: 13px; }

.simulation-tools { flex: 1; overflow-y: auto; }
.small-label { font-size: 12px; color: #8c8c8c; margin-bottom: 8px; }

.terminal-main {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.terminal-header {
  padding: 12px 16px;
  border-bottom: 1px solid #f0f0f0;
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: #fff;
}

.terminal-header .title { font-weight: 600; color: #595959; }

.log-container {
  flex: 1;
  background: #1e1e1e;
  padding: 16px;
  overflow-y: auto;
  font-family: 'Consolas', 'Monaco', monospace;
}

.log-item {
  margin-bottom: 16px;
  padding-bottom: 16px;
  border-bottom: 1px solid #333;
}

.log-item.in { border-left: 3px solid #52c41a; padding-left: 12px; }
.log-item.out { border-left: 3px solid #1890ff; padding-left: 12px; }

.log-time { color: #8c8c8c; font-size: 11px; margin-bottom: 4px; }
.log-topic { color: #d4d4d4; font-size: 12px; margin-bottom: 8px; }
.log-topic code { background: #333; padding: 2px 6px; border-radius: 4px; color: #569cd6; }

.log-payload pre {
  margin: 0;
  padding: 8px;
  background: #2d2d2d;
  color: #ce9178;
  font-size: 12px;
  border-radius: 4px;
  white-space: pre-wrap;
}

.log-empty {
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #595959;
  font-style: italic;
}

.mb-2 { margin-bottom: 8px; }

.command-panel { padding: 10px 0; }
.target-info { display: flex; align-items: center; gap: 16px; }
.cmd-icon { font-size: 40px; color: #1890ff; background: #e6f7ff; padding: 10px; border-radius: 8px; }
.target-info .name { font-size: 18px; font-weight: 600; }
.target-info .id { color: #8c8c8c; font-size: 12px; }

.mb-4 { margin-bottom: 16px; }
.mt-4 { margin-top: 16px; }
.disabled { cursor: not-allowed; opacity: 0.3; }

.sensor-card {
  border-radius: 8px;
  transition: all 0.3s;
}
.sensor-card.normal { border-left: 3px solid #52c41a; }
.sensor-card.warning { border-left: 3px solid #faad14; }
.sensor-card.danger { border-left: 3px solid #ff4d4f; }
.sensor-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}
.sensor-type { font-weight: 600; font-size: 13px; color: #595959; }
.sensor-value {
  font-size: 28px;
  font-weight: 700;
  color: #1890ff;
  line-height: 1.2;
}
.sensor-unit { font-size: 14px; font-weight: 400; color: #8c8c8c; margin-left: 4px; }
.sensor-meta { font-size: 11px; color: #bfbfbf; margin-top: 8px; }

:deep(.ant-tabs-nav) { margin-bottom: 24px; }
:deep(.ant-card-actions) { background: #fafafa; }
</style>
