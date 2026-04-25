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
                      <a-tag :color="getTypeColor(device.device_type)">{{ getDeviceTypeText(device.device_type) }}</a-tag>
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
                    <a-tooltip title="真实设备调试（MQTT）">
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
                  <a-tag :color="getTypeColor(record.device_type)">{{ getDeviceTypeText(record.device_type) }}</a-tag>
                </template>
                <template v-if="column.key === 'network'">
                  <div class="network-info">
                    <span>IP: {{ record.ip_address || '127.0.0.1' }}</span>
                    <span>MAC: {{ record.mac_address || '无' }}</span>
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
              <a-tag :color="getTypeColor(currentAudit.device_type)">{{ getDeviceTypeText(currentAudit.device_type) }}</a-tag>
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
      :title="`真实设备调试 - ${currentDebug.deviceId}`" 
      width="1000px"
      :footer="null"
      @cancel="closeDebugTerminal"
    >
      <div class="debug-terminal">
        <div class="debug-terminal-top">
          <div class="debug-terminal-top-left">
            <div class="device-card-mini device-card-mini--inline">
              <component :is="getDeviceIcon(currentDebug.deviceType)" class="mini-icon" />
              <div class="mini-info">
                <div class="name">{{ currentDebug.deviceName }}</div>
                <div class="mini-meta-row">
                  <a-tag :color="getTypeColor(currentDebug.deviceType)">{{ getDeviceTypeText(currentDebug.deviceType) }}</a-tag>
                  <span class="mini-id"><code>{{ currentDebug.deviceId }}</code></span>
                </div>
                <div class="runtime-inline">
                  <span>在线 <b>{{ debugRuntime.online ? '是' : '否' }}</b></span>
                  <span class="sep">·</span>
                  <span>最近上报 <b>{{ debugRuntime.lastUpdateText }}</b></span>
                  <span class="sep">·</span>
                  <span>最近下发 <b>{{ debugRuntime.lastCommandResult }}</b></span>
                </div>
              </div>
            </div>
          </div>
          <div class="debug-terminal-top-right">
            <div class="sensor-strip-title">
              <LineChartOutlined /> 传感器（若有）
              <a-button type="link" size="small" class="sensor-refresh" @click="fetchDebugTerminalSensors()">
                <template #icon><SyncOutlined /></template>
              </a-button>
            </div>
            <a-spin :spinning="debugTerminalSensorLoading" size="small">
              <div v-if="debugTerminalSensors.length === 0" class="sensor-strip-empty">
                暂无近期传感器数据
              </div>
              <div v-else class="sensor-chip-row">
                <div
                  v-for="sensor in debugTerminalSensors"
                  :key="`${sensor.sensor_type}-${sensor.device_id || ''}-${sensor.id ?? ''}`"
                  :class="['sensor-chip', getSensorStatus(sensor)]"
                >
                  <span class="chip-label">{{ getSensorTypeName(sensor.sensor_type) }}</span>
                  <span class="chip-value">
                    {{ sensor.sensor_value ?? '--' }}<span class="chip-unit">{{ sensor.unit || '' }}</span>
                  </span>
                </div>
              </div>
            </a-spin>
          </div>
        </div>

        <div class="debug-terminal-body">
          <div class="terminal-command-pane">
            <div class="pane-section-title">图形化指令（MQTT 下发）</div>
            <p v-if="simulationCommands.length === 0" class="no-commands-hint">
              当前设备类型暂无预设指令，请使用下方自定义主题下发。
            </p>
            <div v-else class="command-button-grid">
              <a-button
                v-for="sim in simulationCommands"
                :key="sim.label"
                size="small"
                @click="sendSimulationCommand(sim)"
              >
                {{ sim.label }}
              </a-button>
            </div>

            <a-divider class="compact-divider">自定义 MQTT</a-divider>
            <div class="custom-send custom-send--compact">
              <a-input v-model:value="customMqtt.topic" placeholder="主题" size="small" class="mb-2" />
              <a-textarea v-model:value="customMqtt.payload" placeholder="消息内容 (JSON)" :rows="3" size="small" class="mb-2" />
              <a-button type="primary" block size="small" @click="sendCustomMqtt">
                <template #icon><SendOutlined /></template> 发送
              </a-button>
            </div>

            <div class="telemetry-hint pane-section-title telemetry-hint-title">上报快照（环境与本机状态，来自设备近期上报）</div>
            <div class="telemetry-mini-grid">
              <div class="telemetry-mini"><span>温度</span><b>{{ debugRuntime.temperature }}</b></div>
              <div class="telemetry-mini"><span>湿度</span><b>{{ debugRuntime.humidity }}</b></div>
              <div class="telemetry-mini"><span>烟雾</span><b>{{ debugRuntime.smoke }}</b></div>
              <div class="telemetry-mini"><span>光照</span><b>{{ debugRuntime.light }}</b></div>
              <div class="telemetry-mini"><span>空调</span><b>{{ debugRuntime.acTarget }}</b></div>
              <div class="telemetry-mini"><span>亮度</span><b>{{ debugRuntime.brightness }}</b></div>
              <div class="telemetry-mini"><span>音量</span><b>{{ debugRuntime.volume }}</b></div>
            </div>
          </div>

          <div class="terminal-mqtt-strip">
            <div class="mqtt-strip-header">
              <div class="strip-title-block">
                <span class="title"><HistoryOutlined /> 设备活动流</span>
                <span class="strip-hint">MQTT 入/出站、平台状态与指令历史（按时间倒序）</span>
              </div>
              <a-space size="small">
                <a-checkbox v-model:checked="autoScroll">滚到底</a-checkbox>
                <a-button size="small" @click="refreshDebugActivityPanel">
                  <template #icon><SyncOutlined /></template>
                </a-button>
                <a-button size="small" @click="clearDebugMqttLog">
                  <template #icon><ClearOutlined /></template>
                </a-button>
              </a-space>
            </div>
            <div class="log-container log-container--strip" ref="logContainerRef">
              <template v-for="(row, idx) in debugStreamRows" :key="debugStreamRowKey(row, idx)">
                <div
                  v-if="row.kind === 'status'"
                  class="log-item log-item--compact log-item--synth log-item--status"
                >
                  <div class="log-time">{{ row.data.last_seen ? formatTime(row.data.last_seen) : '—' }}</div>
                  <div class="log-topic"><code>__system/device_register</code></div>
                  <div class="log-payload">
                    <pre>{{ formatStatusForStream(row.data) }}</pre>
                  </div>
                </div>
                <div
                  v-else-if="row.kind === 'command'"
                  class="log-item log-item--compact log-item--synth log-item--command out"
                >
                  <div class="log-time">{{ formatTime(row.data.created_at) }}</div>
                  <div class="log-topic">
                    <code>control_queue / {{ row.data.command_type ?? 'command' }}</code>
                  </div>
                  <div class="log-payload">
                    <pre>{{ formatCommandForStream(row.data) }}</pre>
                  </div>
                </div>
                <div
                  v-else
                  class="log-item log-item--compact"
                  :class="row.data.direction"
                >
                  <div class="log-time">{{ formatTime(row.data.timestamp) }}</div>
                  <div class="log-topic"><code>{{ row.data.topic }}</code></div>
                  <div class="log-payload">
                    <pre>{{ formatPayload(row.data.payload) }}</pre>
                  </div>
                </div>
              </template>
              <div v-if="debugStreamRows.length === 0" class="log-empty">
                暂无可显示记录。若设备已连 MQTT 仍无数据，请点刷新；无「主题」行多半是后台尚未收到该设备 id 的入站报文或通信日志未入库。
              </div>
            </div>
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
import { ref, reactive, computed, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { $notify, NotifyPreset } from '@/utils/notify'
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
import { useAppStore } from '@/stores/app'
import dayjs from 'dayjs'
import relativeTime from 'dayjs/plugin/relativeTime'
import { formatDotDateTime, toTz } from '@/utils/date'

dayjs.extend(relativeTime)

function getDeviceTypeText(type: string): string {
  const types: Record<string, string> = {
    room: '客房终端',
    front_desk: '前台终端',
    sensor: '传感器',
    gateway: '网关',
    floor: '楼层控制器',
    ac: '空调',
    light: '灯光',
    smoke_detector: '烟雾探测器',
    curtain: '窗帘',
    tv: '智能电视',
    lock: '门锁',
    humidifier: '加湿器',
    door_sensor: '门磁传感器',
    window_sensor: '窗户传感器',
    thermostat: '温控器',
    floor_controller: '楼控节点'
  }
  return types[type] || type
}

const router = useRouter()
const appStore = useAppStore()

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

// 计算统计数据
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

// 设备筛选
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
  { title: '终端识别码', dataIndex: 'device_id', key: 'device_id' },
  { title: '类型', key: 'type', width: 120 },
  { title: '网络指纹', key: 'network' },
  { title: '首次上报时间', dataIndex: 'created_at', key: 'created_at', customRender: ({ text }: any) => formatDotDateTime(text) },
  { title: '操作', key: 'action', fixed: 'right', width: 150 }
]

// 弹窗状态
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

// 调试终端状态
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
const debugRuntime = reactive({
  online: false,
  lastUpdateText: '--',
  lastCommandResult: '--',
  temperature: '--',
  humidity: '--',
  smoke: '--',
  light: '--',
  acTarget: '--',
  brightness: '--',
  volume: '--'
})

const customMqtt = reactive({
  topic: '',
  payload: ''
})

const debugTerminalSensors = ref<any[]>([])
const debugTerminalSensorLoading = ref(false)
/** 详情接口快照 + 本地列表行，供活动流中「设备状态」行使用 */
const debugDeviceSnapshot = ref<Record<string, unknown> | null>(null)
const debugCommandHistory = ref<any[]>([])

const commandDeviceType = computed(() => {
  const t = currentDebug.deviceType
  return t === 'floor_controller' ? 'floor' : t
})

const simulationCommands = computed(() => {
  const type = commandDeviceType.value
  const deviceId = currentDebug.deviceId
  const roomId = deviceId.includes('_') 
    ? deviceId.split('_').pop() 
    : deviceId
    
  if (type === 'room') {
    return [
      { label: '💡 开灯', topic: `hotel/device/command/room/room_${roomId}`, payload: { device_id: `room_${roomId}`, command_type: 'light_on' } },
      { label: '💡 关灯', topic: `hotel/device/command/room/room_${roomId}`, payload: { device_id: `room_${roomId}`, command_type: 'light_off' } },
      { label: '🎚️ 亮度调大', topic: `hotel/device/command/room/room_${roomId}`, payload: { device_id: `room_${roomId}`, command_type: 'set_light_brightness', command_delta: 10, command_direction: 'up' } },
      { label: '🎚️ 亮度调小', topic: `hotel/device/command/room/room_${roomId}`, payload: { device_id: `room_${roomId}`, command_type: 'set_light_brightness', command_delta: 10, command_direction: 'down' } },
      { label: '🌡️ 空调温度调大', topic: `hotel/device/command/room/room_${roomId}`, payload: { device_id: `room_${roomId}`, command_type: 'set_ac_temp', command_delta: 1, command_direction: 'up' } },
      { label: '🌡️ 空调温度调小', topic: `hotel/device/command/room/room_${roomId}`, payload: { device_id: `room_${roomId}`, command_type: 'set_ac_temp', command_delta: 1, command_direction: 'down' } },
      { label: '🔊 音量调大', topic: `hotel/device/command/room/room_${roomId}`, payload: { device_id: `room_${roomId}`, command_type: 'set_volume', command_delta: 5, command_direction: 'up' } },
      { label: '🔊 音量调小', topic: `hotel/device/command/room/room_${roomId}`, payload: { device_id: `room_${roomId}`, command_type: 'set_volume', command_delta: 5, command_direction: 'down' } },
      { label: '🚨 广播警报', topic: `hotel/device/command/room/room_${roomId}`, payload: { device_id: `room_${roomId}`, command_type: 'broadcast_alarm' } },
      { label: '🌙 睡眠场景', topic: `hotel/device/command/room/room_${roomId}`, payload: { device_id: `room_${roomId}`, command_type: 'scene_sleep' } },
      { label: '👋 欢迎场景', topic: `hotel/device/command/room/room_${roomId}`, payload: { device_id: `room_${roomId}`, command_type: 'scene_welcome' } }
    ]
  } else if (type === 'floor') {
    return [
      { label: '💡 走廊照明-开', topic: `hotel/device/command/floor/${deviceId}`, payload: { device_id: deviceId, command_type: 'light_on' } },
      { label: '💡 走廊照明-关', topic: `hotel/device/command/floor/${deviceId}`, payload: { device_id: deviceId, command_type: 'light_off' } },
      { label: '🚨 广播警报', topic: `hotel/device/command/floor/${deviceId}`, payload: { device_id: deviceId, command_type: 'broadcast_alarm' } },
      { label: '🔄 系统复位', topic: `hotel/device/command/floor/${deviceId}`, payload: { device_id: deviceId, command_type: 'floor_reset' } }
    ]
  } else if (type === 'front_desk') {
    return [
      { label: '🆕 开卡-房间301', topic: `hotel/device/command/front_desk/${deviceId}`, payload: { device_id: deviceId, command_type: 'room_card_op', command_value: { action: 'issue', room_number: '301', booking_id: 'BK001' } } },
      { label: '🆕 开卡-房间302', topic: `hotel/device/command/front_desk/${deviceId}`, payload: { device_id: deviceId, command_type: 'room_card_op', command_value: { action: 'issue', room_number: '302', booking_id: 'BK002' } } },
      { label: '🔍 验卡(verify_card)', topic: `hotel/device/command/front_desk/${deviceId}`, payload: { device_id: deviceId, command_type: 'verify_card' } },
      { label: '🔍 查卡(room_card_op)', topic: `hotel/device/command/front_desk/${deviceId}`, payload: { device_id: deviceId, command_type: 'room_card_op', command_value: { action: 'verify' } } },
      { label: '📖 读卡(别名)', topic: `hotel/device/command/front_desk/${deviceId}`, payload: { device_id: deviceId, command_type: 'read_card' } },
      { label: '📟 刷卡', topic: `hotel/device/command/front_desk/${deviceId}`, payload: { device_id: deviceId, command_type: 'swipe_card' } },
      { label: '🧹 清卡(别名)', topic: `hotel/device/command/front_desk/${deviceId}`, payload: { device_id: deviceId, command_type: 'clear_card' } },
      { label: '🗑️ 退卡', topic: `hotel/device/command/front_desk/${deviceId}`, payload: { device_id: deviceId, command_type: 'room_card_op', command_value: { action: 'revoke', room_number: '301' } } },
      { label: '🚨 前台报警', topic: `hotel/device/command/front_desk/${deviceId}`, payload: { device_id: deviceId, command_type: 'alarm_trigger' } },
      { label: '🚨 301 广播警报', topic: `hotel/device/command/room/room_301`, payload: { device_id: deviceId, command_type: 'broadcast_alarm' } }
    ]
  }
  return []
})

type DebugStreamRow =
  | { kind: 'status'; order: number; data: any }
  | { kind: 'command'; order: number; data: any }
  | { kind: 'mqtt'; order: number; data: any }

const debugStreamRows = computed((): DebugStreamRow[] => {
  const out: DebugStreamRow[] = []
  const snap = debugDeviceSnapshot.value
  if (snap && typeof snap === 'object') {
    const t = snap.last_seen ? new Date(String(snap.last_seen)).getTime() : 0
    out.push({ kind: 'status', order: t, data: snap })
  }
  for (const c of debugCommandHistory.value) {
    const t = c.created_at ? new Date(c.created_at).getTime() : 0
    out.push({ kind: 'command', order: t, data: c })
  }
  for (const log of mqttLogs.value) {
    const t = log.timestamp ? new Date(log.timestamp).getTime() : 0
    out.push({ kind: 'mqtt', order: t, data: log })
  }
  out.sort((a, b) => b.order - a.order)
  return out
})

function debugStreamRowKey(row: DebugStreamRow, idx: number) {
  if (row.kind === 'mqtt') return `mqtt-${row.data.id ?? idx}`
  if (row.kind === 'command') return `cmd-${row.data.id ?? idx}`
  return 'status-snap'
}

function formatStatusForStream(s: any) {
  return JSON.stringify(
    {
      device_id: s.device_id,
      device_name: s.device_name,
      device_type: s.device_type,
      device_status: s.device_status,
      last_seen: s.last_seen,
      ip_address: s.ip_address,
      mac_address: s.mac_address,
      area: s.area,
      room_number: s.room_number
    },
    null,
    2
  )
}

function formatCommandForStream(c: any) {
  return JSON.stringify(
    {
      command_type: c.command_type,
      command_value: c.command_value,
      command_status: c.command_status,
      created_at: c.created_at
    },
    null,
    2
  )
}

function scrollLogToEnd() {
  if (autoScroll.value && logContainerRef.value) {
    setTimeout(() => {
      if (logContainerRef.value) logContainerRef.value.scrollTop = logContainerRef.value.scrollHeight
    }, 100)
  }
}

async function fetchDebugDeviceContext() {
  if (!currentDebug.id) return
  try {
    const [detRes, cmdRes]: any = await Promise.all([
      deviceApi.getDeviceDetail(currentDebug.id),
      deviceApi.getCommandHistory(currentDebug.id, { page: 1, pageSize: 25 })
    ])
    if (detRes?.data) {
      debugDeviceSnapshot.value = detRes.data
    } else {
      debugDeviceSnapshot.value = (devices.value.find((x: any) => x.id === currentDebug.id) as any) || null
    }
    const list = cmdRes?.data?.list
    debugCommandHistory.value = Array.isArray(list) ? list : []
  } catch {
    debugDeviceSnapshot.value = (devices.value.find((x: any) => x.id === currentDebug.id) as any) || null
    debugCommandHistory.value = []
  }
  scrollLogToEnd()
}

async function refreshDebugActivityPanel() {
  await Promise.all([fetchMqttLogs(true), fetchDebugDeviceContext()])
  fetchDebugRuntimeStatus()
  await fetchDebugTerminalSensors()
  applyDebugRuntimeFromSensorStrip()
}

function clearDebugMqttLog() {
  mqttLogs.value = []
}

async function openDebugTerminal(device: any) {
  Object.assign(currentDebug, {
    id: device.id,
    deviceId: device.device_id,
    deviceName: device.device_name,
    deviceType: device.device_type
  })
  debugTerminalVisible.value = true
  await fetchMqttLogs()
  fetchDebugRuntimeStatus()
  await fetchDebugDeviceContext()
  await fetchDebugTerminalSensors()
  applyDebugRuntimeFromSensorStrip()
  logTimer.value = setInterval(async () => {
    await fetchMqttLogs()
    fetchDebugRuntimeStatus()
    await fetchDebugDeviceContext()
    await fetchDebugTerminalSensors({ silent: true })
    applyDebugRuntimeFromSensorStrip()
  }, 3000)
}

function closeDebugTerminal() {
  if (logTimer.value) clearInterval(logTimer.value)
  logTimer.value = null
  debugTerminalVisible.value = false
  debugTerminalSensors.value = []
  debugDeviceSnapshot.value = null
  debugCommandHistory.value = []
}

async function fetchMqttLogs(isManual = false) {
  try {
    const res: any = await request.get('/mqtt/logs', { 
      params: { device_id: currentDebug.deviceId, limit: 50 } 
    })
    const ok = res && (res.success === true || res.code === 200 || res.code === undefined)
    if (ok && res.data !== undefined) {
      mqttLogs.value = Array.isArray(res.data) ? res.data : []
      hydrateLastCommandResult()
      hydrateRuntimeFromLogs()
      scrollLogToEnd()
    }
  } catch (err) {
    if (isManual) $notify.error({ title: '刷新日志失败', description: '无法刷新MQTT日志，请稍后重试 🔄' })
  }
}

function formatPayload(p: any) {
  if (typeof p === 'string') {
    try { return JSON.stringify(JSON.parse(p), null, 2) }
    catch { return p }
  }
  return JSON.stringify(p, null, 2)
}

function buildRealSimulationPayload(sim: any) {
  const raw = sim.payload
  if (raw != null && typeof raw === 'object') {
    return JSON.parse(JSON.stringify(raw))
  }
  return raw
}

function parseLogPayload(log: any): Record<string, unknown> | null {
  if (!log?.payload && log?.payload !== '') return null
  if (typeof log.payload === 'object' && log.payload !== null) {
    return log.payload as Record<string, unknown>
  }
  if (typeof log.payload === 'string') {
    try {
      const p = JSON.parse(log.payload)
      return typeof p === 'object' && p !== null ? (p as Record<string, unknown>) : null
    } catch {
      return null
    }
  }
  return null
}

function hydrateLastCommandResult() {
  const out = mqttLogs.value.find((l: any) => l.direction === 'out')
  if (!out) {
    debugRuntime.lastCommandResult = '--'
    return
  }
  const p = parseLogPayload(out)
  const cmd = (p?.command_type as string) || (out.topic && String(out.topic).split('/').pop()) || '下发'
  debugRuntime.lastCommandResult = String(cmd).slice(0, 48)
}

function hydrateRuntimeFromLogs() {
  const next = {
    temperature: '--',
    humidity: '--',
    smoke: '--',
    light: '--',
    acTarget: '--',
    brightness: '--',
    volume: '--'
  }
  for (const log of mqttLogs.value) {
    if (log.direction !== 'in') continue
    const p = parseLogPayload(log)
    if (!p) continue
    const setIf = (key: keyof typeof next, val: unknown) => {
      if (next[key] !== '--') return
      if (val === undefined || val === null || val === '') return
      next[key] = String(val)
    }
    setIf('temperature', p.temperature ?? p.temp ?? p.ntc_temp_c)
    setIf('humidity', p.humidity)
    setIf('smoke', p.smoke ?? p.smoke_level)
    setIf('light', p.light ?? p.light_level)
    setIf('acTarget', p.ac_target ?? p.ac_temp ?? p.target_temp)
    setIf('brightness', p.brightness ?? p.light_brightness)
    setIf('volume', p.volume)
  }
  Object.assign(debugRuntime, next)
}

function fetchDebugRuntimeStatus() {
  const d = devices.value.find((x: any) => x.id === currentDebug.id)
  if (d) {
    debugRuntime.online = d.device_status === 'online'
    debugRuntime.lastUpdateText = d.last_seen ? String(formatTime(d.last_seen)) : '--'
  } else {
    debugRuntime.online = false
    debugRuntime.lastUpdateText = '--'
  }
}

async function sendSimulationCommand(sim: any) {
  try {
    const payload = buildRealSimulationPayload(sim)
    
    await request.post('/mqtt/send', {
      topic: sim.topic,
      payload: payload,
      qos: 1
    })
    $notify.success({ title: '指令已发送', description: `${sim.label} 已通过 MQTT 下发 📡` })
    fetchMqttLogs(true)
  } catch (err) {
    NotifyPreset.operationFailed('MQTT消息发送失败')
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
    $notify.success({ title: '消息已发布', description: '自定义MQTT消息已成功发布 📡' })
    fetchMqttLogs(true)
  } catch (err) {
    NotifyPreset.operationFailed('MQTT消息发送失败')
  }
}

// UI Helpers
const getDeviceIcon = (type: string) => {
  const map: Record<string, any> = {
    'room': LayoutOutlined,
    'front_desk': UserOutlined,
    'sensor': BulbOutlined,
    'gateway': SettingOutlined,
    'floor': ClusterOutlined,
    'floor_controller': ClusterOutlined
  }
  return map[type] || DesktopOutlined
}

const getTypeColor = (type: string) => {
  const map: Record<string, string> = {
    'room': 'purple',
    'front_desk': 'blue',
    'sensor': 'orange',
    'gateway': 'cyan',
    'floor': 'geekblue',
    'floor_controller': 'geekblue'
  }
  return map[type] || 'default'
}

const statusText = (s: string) => ({ online: '在线', offline: '离线', error: '异常' } as any)[s] || '未知'

const formatTime = (t: string) => t ? (toTz(t)?.fromNow() || '从未连接') : '从未连接'

// API操作
async function fetchDevices() {
  loading.value = true
  try {
    // 从 appStore 获取用户信息，传递 hotel_id 以获取该酒店的所有设备
    const userInfo = appStore.userInfo
    const params: any = {}
    if (userInfo?.hotel_id) {
      params.hotel_id = userInfo.hotel_id
    }
    const res: any = await deviceApi.getDeviceList(params)
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
    $notify.error({ title: '同步设备状态失败', description: '无法同步设备状态，请检查网络后重试 🔄' })
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
    $notify.success({ title: '审核已提交', description: '设备审核操作已成功提交 ✅' })
    auditModalVisible.value = false
    fetchDevices()
  } catch (err) {
    NotifyPreset.operationFailed('审核处理失败')
  } finally {
    auditLoading.value = false
  }
}

async function deleteDevice(id: number) {
  try {
    await deviceApi.deleteDevice(id)
    $notify.success({ title: '设备已移除', description: '设备已成功从系统中移除 🗑️' })
    fetchDevices()
  } catch (err) {
    NotifyPreset.operationFailed('移除设备失败')
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
    $notify.success({ title: '指令已送达', description: `控制指令已送达 ${currentCmd.deviceId} 📡` })
    cmdModalVisible.value = false
  } catch (err) {
    NotifyPreset.operationFailed('指令发送失败')
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

// 实时数据弹窗：只展示"近期还在更新"的 sensor_type。超过该阈值未更新的
// 字段视为旧固件遗留（如楼控换掉雨棚后，数据库里仍残留的 canopy_angle_deg /
// rain_detected / human_present / light_adc 等），直接从卡片里隐藏，
// 不会污染界面。硬件正常上报周期一般在分钟级以内，10 分钟阈值足够宽松。
const STALE_SENSOR_THRESHOLD_MS = 10 * 60 * 1000

// 明确废弃的 sensor_type（对应硬件上已经砍掉、不再做的功能），
// 无视更新时间一律不展示；避免 10 分钟阈值内还显示残留数据的尴尬。
const DEPRECATED_SENSOR_TYPES: ReadonlySet<string> = new Set([
  'canopy_angle_deg',  // 楼控雨棚角度（已砍掉雨棚功能）
  'rain_detected',     // 楼控雨感（已砍掉雨棚功能）
  'light_adc',         // 旧命名，统一改为 light
  'air_quality_adc',   // 旧命名，统一改为 smoke
  'noise_level',       // 硬件未装噪音传感器
  'pm25'               // 硬件未装 PM2.5 传感器
])

function filterFreshSensorRows(data: any[]): any[] {
  if (!Array.isArray(data)) return []
  const now = Date.now()
  return data.filter((s: any) => {
    if (!s?.sensor_type) return false
    if (DEPRECATED_SENSOR_TYPES.has(s.sensor_type)) return false
    if (!s.created_at) return false
    const t = new Date(s.created_at).getTime()
    if (Number.isNaN(t)) return false
    return now - t <= STALE_SENSOR_THRESHOLD_MS
  })
}

async function fetchSensorData(deviceId: number) {
  sensorLoading.value = true
  try {
    const res: any = await request.get(`/devices/${deviceId}/sensor-data/latest`)
    if (res && res.success && Array.isArray(res.data)) {
      sensorData.value = filterFreshSensorRows(res.data)
    } else {
      sensorData.value = []
    }
  } catch (err) {
    sensorData.value = []
  } finally {
    sensorLoading.value = false
  }
}

/** 将传感器条数据填入下方「上报快照」网格（优先 DB 合并结果，避免仅依赖 MQTT 日志解析） */
function applyDebugRuntimeFromSensorStrip() {
  const findVal = (...types: string[]) => {
    for (const t of types) {
      const s = debugTerminalSensors.value.find((x: any) => x.sensor_type === t)
      if (s != null && s.sensor_value != null && String(s.sensor_value) !== '') {
        return String(s.sensor_value)
      }
    }
    return undefined
  }
  const t = findVal('temperature', 'ntc_temp_c')
  if (t !== undefined) debugRuntime.temperature = t
  const h = findVal('humidity')
  if (h !== undefined) debugRuntime.humidity = h
  const sm = findVal('smoke', 'air_quality_adc', 'smoke_level')
  if (sm !== undefined) debugRuntime.smoke = sm
  const li = findVal('light', 'light_level', 'light_adc')
  if (li !== undefined) debugRuntime.light = li
  const ac = findVal('ac_target_temp')
  if (ac !== undefined) debugRuntime.acTarget = ac
  const br = findVal('light_brightness')
  if (br !== undefined) debugRuntime.brightness = br
  const vol = findVal('volume')
  if (vol !== undefined) debugRuntime.volume = vol
}

async function fetchDebugTerminalSensors(options?: { silent?: boolean }) {
  if (!currentDebug.id) return
  const showSpin = !options?.silent
  if (showSpin) debugTerminalSensorLoading.value = true
  try {
    const res: any = await request.get(`/devices/${currentDebug.id}/sensor-data/latest`)
    if (res && res.success && Array.isArray(res.data)) {
      debugTerminalSensors.value = filterFreshSensorRows(res.data)
    } else {
      debugTerminalSensors.value = []
    }
  } catch {
    debugTerminalSensors.value = []
  } finally {
    if (showSpin) debugTerminalSensorLoading.value = false
  }
}

function getSensorTypeName(type: string): string {
  const map: Record<string, string> = {
    light_brightness: '灯光亮度',
    volume: '音量',
    ac_target_temp: '空调目标温',
    temperature: '温度',
    humidity: '湿度',
    smoke: '烟雾(ADC)',
    light: '光照(ADC)',
    ntc_temp_c: '热敏温度',
    human_present: '人体感应',
    air_quality_adc: 'MQ2 烟雾(ADC)',
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

onUnmounted(() => {
  if (logTimer.value) {
    clearInterval(logTimer.value)
    logTimer.value = null
  }
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

/* 调试终端样式 */
.debug-terminal {
  display: flex;
  flex-direction: column;
  height: 580px;
  background: #fff;
  border: 1px solid #f0f0f0;
  border-radius: 8px;
  overflow: hidden;
}

.debug-terminal-top {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 16px;
  padding: 12px 16px;
  border-bottom: 1px solid #f0f0f0;
  background: #fafafa;
  flex-shrink: 0;
}

.debug-terminal-top-left { flex: 1; min-width: 0; }

.debug-terminal-top-right {
  flex: 0 0 340px;
  max-width: 46%;
  text-align: right;
}

.sensor-strip-title {
  font-size: 12px;
  font-weight: 600;
  color: #595959;
  margin-bottom: 8px;
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 6px;
}

.sensor-strip-title .sensor-refresh { padding: 0 4px; margin: 0; height: auto; line-height: 1; }

.sensor-strip-empty {
  font-size: 12px;
  color: #bfbfbf;
  padding: 8px 0;
}

.sensor-chip-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  justify-content: flex-end;
}

.sensor-chip {
  background: #fff;
  border: 1px solid #e8e8e8;
  border-radius: 8px;
  padding: 6px 10px;
  min-width: 88px;
  text-align: left;
}

.sensor-chip.normal { border-left: 3px solid #52c41a; }
.sensor-chip.warning { border-left: 3px solid #faad14; }
.sensor-chip.danger { border-left: 3px solid #ff4d4f; }

.sensor-chip .chip-label {
  display: block;
  font-size: 11px;
  color: #8c8c8c;
  margin-bottom: 2px;
}

.sensor-chip .chip-value {
  font-size: 14px;
  font-weight: 600;
  color: #1890ff;
}

.sensor-chip .chip-unit {
  font-size: 11px;
  font-weight: 400;
  color: #8c8c8c;
  margin-left: 2px;
}

.debug-terminal-body {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: row;
}

.terminal-command-pane {
  flex: 1;
  min-width: 0;
  padding: 14px 16px;
  overflow-y: auto;
  background: #fff;
}

.pane-section-title {
  font-size: 13px;
  font-weight: 600;
  color: #434343;
  margin-bottom: 10px;
}

.no-commands-hint {
  font-size: 12px;
  color: #8c8c8c;
  margin: 0 0 12px;
}

.command-button-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(132px, 1fr));
  gap: 8px;
  margin-bottom: 8px;
}

.compact-divider { margin: 12px 0 8px; }

.custom-send--compact { max-width: 100%; }

.telemetry-hint-title {
  margin-top: 16px;
  margin-bottom: 8px;
  font-size: 12px;
  color: #8c8c8c;
  font-weight: 500;
}

.telemetry-mini-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(100px, 1fr));
  gap: 8px;
}

.telemetry-mini {
  background: #fafafa;
  border: 1px solid #f0f0f0;
  border-radius: 6px;
  padding: 6px 8px;
  font-size: 11px;
  display: flex;
  justify-content: space-between;
  gap: 6px;
}

.telemetry-mini span { color: #8c8c8c; }
.telemetry-mini b { font-size: 12px; color: #262626; }

.terminal-mqtt-strip {
  flex: 0 0 300px;
  width: 300px;
  display: flex;
  flex-direction: column;
  border-left: 1px solid #f0f0f0;
  background: #fcfcfc;
  min-height: 0;
}

.mqtt-strip-header {
  padding: 8px 10px;
  border-bottom: 1px solid #f0f0f0;
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 8px;
  flex-shrink: 0;
  background: #fff;
}

.strip-title-block {
  min-width: 0;
  flex: 1;
}

.mqtt-strip-header .title {
  font-weight: 600;
  color: #595959;
  font-size: 12px;
  display: block;
}

.strip-hint {
  display: block;
  font-size: 10px;
  color: #8c8c8c;
  font-weight: 400;
  margin-top: 2px;
  line-height: 1.35;
}

.log-item--synth.log-item--status {
  border-left-color: #faad14;
}

.log-item--synth.log-item--command {
  border-left-color: #722ed1;
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

.device-card-mini--inline {
  margin-bottom: 0;
  padding: 10px 12px;
}

.mini-icon { font-size: 24px; color: #1890ff; }
.mini-info .name { font-weight: 600; font-size: 13px; }

.mini-meta-row {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 4px;
  flex-wrap: wrap;
}

.mini-id code { font-size: 11px; }

.runtime-inline {
  margin-top: 8px;
  font-size: 11px;
  color: #8c8c8c;
}

.runtime-inline b { color: #434343; font-weight: 500; }
.runtime-inline .sep { margin: 0 4px; color: #d9d9d9; }

.small-label { font-size: 12px; color: #8c8c8c; margin-bottom: 8px; }

.log-container {
  flex: 1;
  background: #1e1e1e;
  padding: 12px;
  overflow-y: auto;
  font-family: 'Consolas', 'Monaco', monospace;
  min-height: 0;
}

.log-container--strip {
  border-radius: 0;
}

.log-item {
  margin-bottom: 14px;
  padding-bottom: 14px;
  border-bottom: 1px solid #333;
}

.log-item--compact {
  margin-bottom: 10px;
  padding-bottom: 10px;
}

.log-item.in { border-left: 3px solid #52c41a; padding-left: 10px; }
.log-item.out { border-left: 3px solid #1890ff; padding-left: 10px; }

.log-time { color: #8c8c8c; font-size: 10px; margin-bottom: 4px; }
.log-topic { color: #d4d4d4; font-size: 11px; margin-bottom: 6px; }
.log-topic code { background: #333; padding: 2px 6px; border-radius: 4px; color: #569cd6; }

.log-item--compact .log-payload pre {
  font-size: 11px;
  padding: 6px;
}

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
  min-height: 120px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #8c8c8c;
  font-style: italic;
  font-size: 12px;
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
