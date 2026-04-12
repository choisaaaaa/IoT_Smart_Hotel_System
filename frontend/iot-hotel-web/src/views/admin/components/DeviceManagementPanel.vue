<template>
  <div class="device-management-panel">
    <a-row :gutter="[16, 16]" style="margin-bottom: 16px;">
      <a-col :xs="24" :sm="6">
        <a-card size="small" class="device-stat online-stat">
          <a-statistic title="在线设备" :value="deviceSummary.online_count || 0" suffix="/{{ deviceSummary.total_devices || 0 }}" :value-style="{ color: '#52c41a', fontSize: '24px' }">
            <template #prefix><CheckCircleFilled /></template>
          </a-statistic>
          <div class="rate">在线率: {{ deviceSummary.online_rate || 0 }}%</div>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="6">
        <a-card size="small" class="device-stat running-stat">
          <a-statistic title="运行中" :value="deviceSummary.running_count || 0" :value-style="{ color: '#1890ff', fontSize: '24px' }">
            <template #prefix><PlayCircleFilled /></template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="6">
        <a-card size="small" class="device-stat offline-stat">
          <a-statistic title="离线" :value="deviceSummary.offline_count || 0" :value-style="{ color: '#999', fontSize: '24px' }">
            <template #prefix><MinusCircleFilled /></template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="6">
        <a-card size="small" class="device-stat error-stat">
          <a-statistic title="异常" :value="deviceSummary.error_count || 0" :value-style="{ color: '#ff4d4f', fontSize: '24px' }">
            <template #prefix><CloseCircleFilled /></template>
          </a-statistic>
        </a-card>
      </a-col>
    </a-row>

    <a-card :loading="loading">
      <template #title>
        <span>📱 客房设备管理</span>
      </template>
      <template #extra>
        <a-space>
          <a-select v-model:value="selectedRoom" placeholder="选择房间" allowClear style="width: 100px;" @change="fetchDevices">
            <a-select-option value="">全部房间</a-select-option>
            <a-select-option v-for="room in roomList" :key="room.id" :value="room.id">{{ room.number }}</a-select-option>
          </a-select>
          <a-select v-model:value="filterType" placeholder="设备类型" allowClear style="width: 110px;" @change="fetchDevices">
            <a-select-option value="">全部类型</a-select-option>
            <a-select-option value="ac">空调</a-select-option>
            <a-select-option value="light">灯光</a-select-option>
            <a-select-option value="smoke_detector">烟雾探测器</a-select-option>
            <a-select-option value="curtain">窗帘</a-select-option>
            <a-select-option value="window_sensor">窗户传感器</a-select-option>
            <a-select-option value="door_sensor">门磁传感器</a-select-option>
          </a-select>
          <a-button type="primary" size="small" :loading="loading" @click="fetchDevices"><ReloadOutlined /> 刷新</a-button>
        </a-space>
      </template>

      <a-table :dataSource="filteredDevices" :columns="deviceColumns" :loading="loading" rowKey="device_id" size="middle" :pagination="{ pageSize: 15 }">
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'status'">
            <a-badge :status="getDeviceStatusBadge(record.status)" :text="getDeviceStatusText(record.status)" />
          </template>

          <template v-if="column.key === 'running'">
            <a-tag :color="record.is_running ? 'green' : 'default'">{{ record.is_running ? '运行中' : '已关闭' }}</a-tag>
          </template>

          <template v-if="column.key === 'value'">
            <span style="font-weight: bold;">{{ record.current_value }} {{ record.unit }}</span>
          </template>

          <template v-if="column.key === 'battery'">
            <a-progress
              v-if="record.battery_level"
              :percent="record.battery_level"
              :stroke-color="record.battery_level > 20 ? '#52c41a' : '#ff4d4f'"
              size="small"
              style="width: 60px;"
            />
            <span v-else>-</span>
          </template>

          <template v-if="column.key === 'action'">
            <a-space>
              <a-button
                v-if="record.device_type === 'ac'"
                type="primary"
                size="small"
                :disabled="record.status !== 'online'"
                @click="openControlModal(record)"
              >
                控制
              </a-button>
              <a-button
                v-else-if="['light', 'curtain'].includes(record.device_type)"
                size="small"
                :disabled="record.status !== 'online'"
                @click="openControlModal(record)"
              >
                调节
              </a-button>
              <a-tag v-else color="blue">只读</a-tag>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

    <a-modal v-model:open="controlModalVisible" :title="`控制设备 - ${currentDevice?.device_name} (${currentDevice ? getRoomNumber(currentDevice.room_id) : ''})`" @ok="executeControl" :confirmLoading="controlling" width="500px">
      <a-form layout="vertical" v-if="currentDevice">
        <a-alert message="设备控制" :description="`正在控制 ${currentDevice.device_name}，当前状态: ${currentDevice.is_running ? '运行中' : '已关闭'}，当前值: ${currentDevice.current_value}${currentDevice.unit}`" show-icon style="margin-bottom: 16px;" />

        <a-form-item label="操作类型">
          <a-radio-group v-model:value="controlAction">
            <a-radio-button value="toggle">开关切换</a-radio-button>
            <a-radio-button value="set_value">设定值</a-radio-button>
            <a-radio-button v-if="!currentDevice.is_running" value="turn_on">开启</a-radio-button>
            <a-radio-button v-if="currentDevice.is_running" value="turn_off">关闭</a-radio-button>
          </a-radio-group>
        </a-form-item>

        <a-form-item v-if="controlAction === 'set_value'" label="目标值">
          <a-slider
            v-model:value="controlValue"
            :min="getMinValue(currentDevice.device_type)"
            :max="getMaxValue(currentDevice.device_type)"
            :marks="getValueMarks(currentDevice.device_type, currentDevice.unit)"
          />
          <div style="text-align: center; margin-top: 8px;">
            <span style="font-size: 18px; font-weight: bold; color: #1890ff;">{{ controlValue }} {{ currentDevice.unit }}</span>
          </div>
        </a-form-item>

        <a-form-item label="备注（可选）">
          <a-input v-model:value="controlNote" placeholder="可选的操作备注..." />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, reactive } from 'vue'
import { message } from 'ant-design-vue'
import { CheckCircleFilled, PlayCircleFilled, MinusCircleFilled, CloseCircleFilled, ReloadOutlined } from '@ant-design/icons-vue'
import { environmentApi, type DeviceInfo } from '@/api/environment'

const loading = ref(false)
const devices = ref<DeviceInfo[]>([])
const deviceSummary = reactive({
  online_count: 0,
  offline_count: 0,
  error_count: 0,
  running_count: 0,
  total_devices: 0,
  online_rate: 0
})

const selectedRoom = ref<number | undefined>(undefined)
const filterType = ref<string>('')

const roomList = [
  { id: 1, number: '301' },
  { id: 2, number: '302' },
  { id: 3, number: '303' },
  { id: 4, number: '304' },
  { id: 5, number: '305' },
  { id: 6, number: '401' },
  { id: 7, number: '402' },
  { id: 8, number: '403' },
  { id: 9, number: '404' },
  { id: 10, number: '405' },
  { id: 11, number: '501' },
  { id: 12, number: '502' }
]

const filteredDevices = computed(() => {
  let result = devices.value
  if (filterType.value) {
    result = result.filter(d => d.device_type === filterType.value)
  }
  return result
})

const deviceColumns = [
  { title: '设备名称', dataIndex: 'device_name', key: 'name', width: 120 },
  { title: '房间号', key: 'room', width: 80, customRender: ({ record }: any) => getRoomNumber(record.room_id) },
  { title: '类型', dataIndex: 'device_type', key: 'type', width: 110, customRender: ({ text }: any) => getDeviceTypeText(text) },
  { title: '状态', key: 'status', width: 90 },
  { title: '运行状态', key: 'running', width: 90 },
  { title: '当前值', key: 'value', width: 100 },
  { title: '电量', key: 'battery', width: 90 },
  { title: '操作', key: 'action', width: 80 }
]

const controlModalVisible = ref(false)
const currentDevice = ref<DeviceInfo | null>(null)
const controlAction = ref('toggle')
const controlValue = ref(24)
const controlNote = ref('')
const controlling = ref(false)

async function fetchDevices() {
  loading.value = true
  try {
    const params: any = {}
    if (selectedRoom.value) params.room_id = selectedRoom.value

    const res: any = await environmentApi.getRoomDevices(params)
    const data = res.data

    if (data) {
      devices.value = data.devices || []
      Object.assign(deviceSummary, data.summary)
    }
  } catch (err) {
  } finally {
    loading.value = false
  }
}

function openControlModal(device: DeviceInfo) {
  currentDevice.value = device
  controlAction.value = 'set_value'
  controlValue.value = device.current_value
  controlNote.value = ''
  controlModalVisible.value = true
}

async function executeControl() {
  if (!currentDevice.value) return

  controlling.value = true
  try {
    const actionData: any = { action: controlAction.value }

    if (controlAction.value === 'set_value') {
      actionData.value = controlValue.value
    }

    if (controlNote.value) {
      actionData.note = controlNote.value
    }

    await environmentApi.controlDevice(currentDevice.value.device_id, actionData)

    let actionText = ''
    switch (controlAction.value) {
      case 'toggle': actionText = '切换'; break
      case 'set_value': actionText = `设置为 ${controlValue.value}${currentDevice.value.unit}`; break
      case 'turn_on': actionText = '开启'; break
      case 'turn_off': actionText = '关闭'; break
    }

    message.success(`已向 ${currentDevice.value.device_name} 发送${actionText}指令`)
    controlModalVisible.value = false

    setTimeout(() => {
      fetchDevices()
    }, 1500)
  } catch (err) {
    message.error('发送控制指令失败')
  } finally {
    controlling.value = false
  }
}

function getRoomNumber(roomId: number): string {
  const room = roomList.find(r => r.id === roomId)
  return room ? room.number : `${roomId}`
}

function getDeviceTypeText(type: string): string {
  const types: Record<string, string> = {
    ac: '空调',
    light: '灯光',
    smoke_detector: '烟雾探测器',
    curtain: '窗帘',
    window_sensor: '窗户传感器',
    door_sensor: '门磁传感器',
    humidifier: '加湿器',
    tv: '智能电视'
  }
  return types[type] || type
}

function getDeviceStatusBadge(status: string): string {
  return { online: 'success', offline: 'default', error: 'error' }[status] || 'default'
}

function getDeviceStatusText(status: string): string {
  return { online: '在线', offline: '离线', error: '异常' }[status] || status
}

function getMinValue(type: string): number {
  return { ac: 16, light: 0, curtain: 0 }[type] || 0
}

function getMaxValue(type: string): number {
  return { ac: 30, light: 100, curtain: 100 }[type] || 100
}

function getValueMarks(type: string, unit: string): Record<number, string> {
  if (type === 'ac') {
    return { 16: '16°C', 22: '22°C', 26: '26°C', 30: '30°C' }
  }
  if (type === 'light' || type === 'curtain') {
    return { 0: '关', 50: '50%', 100: '100%' }
  }
  return {}
}

onMounted(() => {
  fetchDevices()
})
</script>

<style scoped>
.device-stat {
  border-radius: 8px;
  text-align: center;
}
.online-stat { border-top: 3px solid #52c41a; background: #f6ffed; }
.running-stat { border-top: 3px solid #1890ff; background: #e6f7ff; }
.offline-stat { border-top: 3px solid #999; background: #fafafa; }
.error-stat { border-top: 3px solid #ff4d4f; background: #fff1f0; }

.rate {
  font-size: 12px;
  margin-top: 4px;
  color: rgba(0,0,0,0.45);
}
</style>
