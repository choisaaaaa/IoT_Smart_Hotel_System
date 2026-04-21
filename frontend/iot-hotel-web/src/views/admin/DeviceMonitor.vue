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

    <!-- Audit Modal -->
    <a-modal v-model:open="auditModalVisible" title="设备准入审核" @ok="confirmAudit" :confirmLoading="auditLoading" width="600px">
      <div class="modal-intro">
        <div class="intro-icon"><SafetyOutlined /></div>
        <div class="intro-text">
          <h4>正在为 {{ currentAudit.device_id }} 分配权限</h4>
          <p>审核通过后，系统将下发加密通讯密钥至该物理终端。</p>
        </div>
      </div>

      <a-form layout="vertical" class="mt-4">
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="设备自定义名称">
              <a-input v-model:value="currentAudit.device_name" placeholder="例如：301室智能终端" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="设备类型">
              <a-input :value="currentAudit.device_type" disabled />
            </a-form-item>
          </a-col>
        </a-row>

        <a-form-item label="分配位置 (关联房间)">
          <a-select v-model:value="currentAudit.room_id" placeholder="选择关联房间" allowClear show-search option-filter-prop="label">
            <a-select-option v-for="room in rooms" :key="room.id" :value="room.id" :label="room.room_number">
              <div class="room-option">
                <span class="room-num">{{ room.room_number }}</span>
                <span class="room-type">{{ room.room_type }}</span>
              </div>
            </a-select-option>
          </a-select>
        </a-form-item>

        <a-form-item label="分配区域 (如公共区域)">
          <a-input v-model:value="currentAudit.area" placeholder="如：走廊、电梯厅、餐厅等" />
        </a-form-item>

        <a-form-item label="审核决策">
          <a-radio-group v-model:value="currentAudit.status" button-style="solid">
            <a-radio-button value="approved">准许接入</a-radio-button>
            <a-radio-button value="rejected">拒绝接入</a-radio-button>
          </a-radio-group>
        </a-form-item>
      </a-form>
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
  BulbOutlined, LayoutOutlined, UserOutlined, SettingOutlined
} from '@ant-design/icons-vue'
import type { DeviceInfo, RoomInfo } from '@/types'
import { deviceApi } from '@/api/device'
import { roomApi } from '@/api/room'
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
  Object.assign(currentAudit, {
    id: record.id,
    device_id: record.device_id,
    device_name: record.device_name || '',
    device_type: record.device_type,
    room_id: undefined,
    area: record.area || '',
    status: 'approved'
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
  message.info('实时数据分析功能开发中...')
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

.room-option { display: flex; justify-content: space-between; width: 100%; }
.room-type { color: #8c8c8c; font-size: 12px; }

.command-panel { padding: 10px 0; }
.target-info { display: flex; align-items: center; gap: 16px; }
.cmd-icon { font-size: 40px; color: #1890ff; background: #e6f7ff; padding: 10px; border-radius: 8px; }
.target-info .name { font-size: 18px; font-weight: 600; }
.target-info .id { color: #8c8c8c; font-size: 12px; }

.mb-4 { margin-bottom: 16px; }
.mt-4 { margin-top: 16px; }
.disabled { cursor: not-allowed; opacity: 0.3; }

:deep(.ant-tabs-nav) { margin-bottom: 24px; }
:deep(.ant-card-actions) { background: #fafafa; }
</style>
