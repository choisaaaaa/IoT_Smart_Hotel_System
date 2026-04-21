<template>
  <div class="device-monitor">
    <a-tabs v-model:activeKey="activeTab" type="card">
      <a-tab-pane key="active" tab="活跃设备">
        <a-row :gutter="[12, 12]">
          <a-col :xs="24" :sm="12" :md="8" :lg="6" v-for="device in activeDevices" :key="device.id">
            <a-card hoverable size="small" :class="['device-card', `status-${device.device_status}`]">
              <div class="card-header">
                <a-avatar :style="{ backgroundColor: avatarColor(device.device_status), fontSize: 18 }" shape="square">
                  {{ typeLabel(device.device_type) }}
                </a-avatar>
                <div class="header-info">
                  <h4>{{ device.device_name }}</h4>
                  <span class="device-id">{{ device.device_id }}</span>
                </div>
              </div>
              <a-divider style="margin: 10px 0;" />
              <div class="detail-list">
                <div class="detail-item">
                  <span>房间/区域</span>
                  <a-tag color="purple">{{ device.room_number || device.area || '未分配' }}</a-tag>
                </div>
                <div class="detail-item">
                  <span>固件版本</span>
                  <a-tag color="blue">{{ device.firmware_version }}</a-tag>
                </div>
                <div class="detail-item">
                  <span>运行状态</span>
                  <a-badge :status="badgeStatus(device.device_status)" :text="statusText(device.device_status)" />
                </div>
                <div class="detail-item">
                  <span>最后通信</span>
                  <span class="time-text">{{ formatTime(device.last_seen) }}</span>
                </div>
              </div>
              <div class="card-actions">
                <a-space>
                  <a-button size="small" :disabled="device.device_status !== 'online'" @click="sendCommand(device)">
                    测试
                  </a-button>
                  <a-popconfirm title="确定要删除此设备吗？" @confirm="deleteDevice(device.id)">
                    <a-button size="small" danger>删除</a-button>
                  </a-popconfirm>
                </a-space>
              </div>
            </a-card>
          </a-col>
        </a-row>
        <a-empty v-if="!activeDevices.length && !loading" description="暂无活跃设备" />
      </a-tab-pane>

      <a-tab-pane key="audit" tab="待审核设备">
        <a-table :dataSource="pendingDevices" :columns="auditColumns" :loading="loading" size="small">
          <template #bodyCell="{ column, record }">
            <template v-if="column.key === 'type'">
              <a-tag>{{ record.device_type }}</a-tag>
            </template>
            <template v-if="column.key === 'info'">
              <div style="font-size: 12px;">
                <div>IP: {{ record.ip_address || '-' }}</div>
                <div>MAC: {{ record.mac_address || '-' }}</div>
              </div>
            </template>
            <template v-if="column.key === 'action'">
              <a-button type="primary" size="small" @click="openAuditModal(record)">审核确认</a-button>
            </template>
          </template>
        </a-table>
      </a-tab-pane>
    </a-tabs>

    <!-- 审核弹窗 -->
    <a-modal v-model:open="auditModalVisible" title="设备审核与分配" @ok="confirmAudit" :confirmLoading="auditLoading">
      <a-form layout="vertical">
        <a-alert message="安全提示" description="审核通过后，系统将为该设备分配唯一的通讯秘钥(Device Key)，请确保设备来源可靠。" type="info" show-icon style="margin-bottom: 16px;" />
        <a-form-item label="设备ID">
          <a-input :value="currentAudit.device_id" disabled />
        </a-form-item>
        <a-form-item label="设备名称">
          <a-input v-model:value="currentAudit.device_name" />
        </a-form-item>
        <a-form-item label="分配房间">
          <a-select v-model:value="currentAudit.room_id" placeholder="选择关联房间" allowClear>
            <a-select-option v-for="room in rooms" :key="room.id" :value="room.id">
              {{ room.room_number }} ({{ room.room_type }})
            </a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item label="分配区域 (可选)">
          <a-input v-model:value="currentAudit.area" placeholder="如：走廊、电梯厅、餐厅等" />
        </a-form-item>
        <a-form-item label="审核结果">
          <a-radio-group v-model:value="currentAudit.status">
            <a-radio value="approved">通过并分配</a-radio>
            <a-radio value="rejected">拒绝并拉黑</a-radio>
          </a-radio-group>
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 指令弹窗 -->
    <a-modal v-model:open="cmdModalVisible" title="发送设备指令" @ok="confirmCommand" :confirmLoading="cmdLoading">
      <a-form layout="vertical">
        <a-form-item label="目标设备">
          <a-input :value="currentCmd.deviceId" disabled />
        </a-form-item>
        <a-form-item label="指令类型">
          <a-select v-model:value="currentCmd.commandType">
            <a-select-option value="ping">Ping 测试</a-select-option>
            <a-select-option value="restart">重启设备</a-select-option>
            <a-select-option value="status_query">状态查询</a-select-option>
            <a-select-option value="firmware_update">固件更新</a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item label="指令参数">
          <a-input v-model:value="currentCmd.commandValue" placeholder="可选参数值" />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { message } from 'ant-design-vue'
import type { DeviceInfo, RoomInfo } from '@/types'
import { deviceApi } from '@/api/device'
import { roomApi } from '@/api/room'
import { sendDeviceCommand } from '@/utils/websocket'
import dayjs from 'dayjs'
import relativeTime from 'dayjs/plugin/relativeTime'
import { formatDotDateTime } from '@/utils/date'

dayjs.extend(relativeTime)

const activeTab = ref('active')
const devices = ref<any[]>([])
const rooms = ref<RoomInfo[]>([])
const loading = ref(false)
const auditLoading = ref(false)

const activeDevices = computed(() => devices.value.filter(d => d.audit_status === 'approved'))
const pendingDevices = computed(() => devices.value.filter(d => d.audit_status === 'pending'))

const auditColumns = [
  { title: '设备ID', dataIndex: 'device_id', key: 'device_id' },
  { title: '类型', dataIndex: 'device_type', key: 'type' },
  { title: '连接信息', key: 'info' },
  { title: '上报时间', dataIndex: 'created_at', key: 'created_at', customRender: ({ text }: any) => formatDotDateTime(text) },
  { title: '操作', key: 'action', fixed: 'right' }
]

// 审核表单
const auditModalVisible = ref(false)
const currentAudit = reactive({
  id: 0,
  device_id: '',
  device_name: '',
  room_id: undefined as number | undefined,
  area: '',
  status: 'approved' as 'approved' | 'rejected'
})

// 指令表单
const cmdModalVisible = ref(false)
const cmdLoading = ref(false)
const currentCmd = reactive({
  id: 0,
  deviceId: '',
  commandType: 'ping',
  commandValue: ''
})

function typeLabel(type: string): string {
  return ({ main: '前', sub1: '楼', sub2: '客', sensor: '感', actuator: '执' } as Record<string, string>)[type] || '?'
}

function avatarColor(status: string): string {
  return ({ online: '#52c41a', offline: '#999', error: '#ff4d4f', unknown: '#d9d9d9' } as Record<string, string>)[status] || '#d9d9d9'
}

function badgeStatus(s: string): string {
  return ({ online: 'success', offline: 'default', error: 'error', unknown: 'default' } as Record<string, string>)[s] || 'default'
}

function statusText(s: string): string {
  return ({ online: '在线', offline: '离线', error: '异常', unknown: '未知' } as Record<string, string>)[s] || s
}

function formatTime(t: string): string { return t ? dayjs(t).fromNow() : '-' }

async function fetchDevices() {
  loading.value = true
  try {
    const res: any = await deviceApi.getDeviceList()
    console.log('Device API response:', res)
    // 处理后端返回的数据结构 { success: true, data: [...] }
    if (res && res.success && Array.isArray(res.data)) {
      devices.value = res.data
    } else if (res && Array.isArray(res.data)) {
      devices.value = res.data
    } else if (Array.isArray(res)) {
      devices.value = res
    } else {
      devices.value = []
      console.warn('Unexpected API response format:', res)
    }
  } catch (err) {
    console.error('Failed to fetch devices:', err)
    message.error('获取设备列表失败')
    devices.value = []
  } finally {
    loading.value = false
  }
}

async function fetchRooms() {
  try {
    const res: any = await roomApi.getRoomList({ pageSize: 1000 })
    console.log('Room API response:', res)
    // 处理后端返回的数据结构
    if (res && res.success && res.data) {
      rooms.value = res.data.list || res.data || []
    } else if (res && res.data) {
      rooms.value = res.data.list || res.data || []
    } else if (Array.isArray(res)) {
      rooms.value = res
    } else {
      rooms.value = []
    }
  } catch (err) {
    console.error('Failed to fetch rooms:', err)
    rooms.value = []
  }
}

function openAuditModal(record: any) {
  currentAudit.id = record.id
  currentAudit.device_id = record.device_id
  currentAudit.device_name = record.device_name
  currentAudit.room_id = undefined
  currentAudit.area = ''
  currentAudit.status = 'approved'
  auditModalVisible.value = true
}

async function confirmAudit() {
  auditLoading.value = true
  try {
    await deviceApi.auditDevice(currentAudit.id, {
      status: currentAudit.status,
      room_id: currentAudit.room_id,
      area: currentAudit.area
    })
    message.success('审核操作成功')
    auditModalVisible.value = false
    fetchDevices()
  } catch (err) {
    message.error('审核操作失败')
  } finally {
    auditLoading.value = false
  }
}

async function deleteDevice(id: number) {
  try {
    await deviceApi.deleteDevice(id)
    message.success('设备已删除')
    fetchDevices()
  } catch (err) {
    message.error('删除失败')
  }
}

function sendCommand(device: any) {
  currentCmd.id = device.id
  currentCmd.deviceId = device.device_id
  currentCmd.commandType = 'ping'
  currentCmd.commandValue = ''
  cmdModalVisible.value = true
}

async function confirmCommand() {
  cmdLoading.value = true
  try {
    await deviceApi.sendCommand(currentCmd.id, currentCmd.commandType, currentCmd.commandValue)
    message.success(`指令已成功下发至 ${currentCmd.deviceId}`)
    cmdModalVisible.value = false
  } catch (err) {
    message.error('指令下发失败')
  } finally {
    cmdLoading.value = false
  }
}

onMounted(() => {
  fetchDevices()
  fetchRooms()
})
</script>

<style scoped>
.device-monitor { padding: 0px; }
.device-card { border-left: 4px solid transparent; transition: all .3s; margin-bottom: 4px; }
.device-card.status-online { border-left-color: #52c41a; }
.device-card.status-offline { border-left-color: #999; }
.device-card.status-error { border-left-color: #ff4d4f; }
.card-header { display: flex; align-items: center; gap: 10px; }
.header-info h4 { margin: 0; font-size: 14px; }
.device-id { font-size: 11px; color: rgba(0,0,0,0.45); }
.detail-item { display: flex; justify-content: space-between; align-items: center; padding: 3px 0; font-size: 13px; }
.time-text { font-size: 11px; color: rgba(0,0,0,0.35); }
.card-actions { margin-top: 10px; text-align: right; }
</style>
