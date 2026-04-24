
<template>
  <div class="device-management">
    <a-card title="主控设备管理" :bordered="false">
      <template #extra>
        <a-button type="primary" @click="fetchDevices">
          <SyncOutlined /> 刷新状态
        </a-button>
      </template>

      <a-table :columns="columns" :data-source="devices" :loading="loading" row-key="id">
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'device_type'">
            <a-tag color="blue">{{ getDeviceTypeName(record.device_type) }}</a-tag>
          </template>
          <template v-if="column.key === 'device_status'">
            <a-badge :status="record.device_status === 'online' ? 'success' : 'error'" :text="record.device_status === 'online' ? '在线' : '离线'" />
          </template>
          <template v-if="column.key === 'last_online'">
            {{ record.last_online ? formatDateTime(record.last_online) : '从未上线' }}
          </template>
          <template v-if="column.key === 'action'">
            <a-space>
              <a-button type="link" size="small" @click="testDevice(record)">测试通信</a-button>
              <a-button type="link" size="small" @click="openMqttModal(record)">发送MQTT命令</a-button>
            </a-space>
          </template>
        </template>
      </a-table>

      <a-divider />

      <div class="device-card-title">设备卡片（可直接发送 MQTT）</div>
      <a-row :gutter="[16, 16]">
        <a-col v-for="item in devices" :key="`card_${item.id}`" :xs="24" :sm="12" :md="8" :lg="6">
          <a-card size="small" class="device-card">
            <template #title>
              <div class="device-name">{{ item.device_name || item.device_id }}</div>
            </template>
            <div class="device-meta">ID: {{ item.device_id }}</div>
            <div class="device-meta">类型: {{ getDeviceTypeName(item.device_type) }}</div>
            <div class="device-meta">区域: {{ item.area || '-' }}</div>
            <div class="device-meta">
              状态:
              <a-badge :status="item.device_status === 'online' ? 'success' : 'error'" :text="item.device_status === 'online' ? '在线' : '离线'" />
            </div>
            <div class="card-actions">
              <a-button block type="primary" size="small" @click="openMqttModal(item)">发送MQTT命令</a-button>
            </div>
          </a-card>
        </a-col>
      </a-row>
    </a-card>

    <a-modal
      v-model:open="mqttModalVisible"
      title="发送 MQTT 命令"
      @ok="confirmSendMqtt"
      :confirmLoading="mqttSending"
      width="760px"
    >
      <a-alert
        type="info"
        show-icon
        message="默认目标已设为 酒店3 / 房间301，可直接发送或按需修改。"
        style="margin-bottom: 12px"
      />
      <a-form layout="vertical">
        <a-form-item label="目标设备">
          <a-input :value="currentDevice.device_id || 'room_301'" disabled />
        </a-form-item>
        <a-form-item label="Topic">
          <a-input v-model:value="mqttForm.topic" placeholder="hotel/device/command/room/room_301" />
        </a-form-item>
        <a-form-item label="Payload(JSON)">
          <a-textarea v-model:value="mqttForm.payload" :rows="10" />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { SyncOutlined } from '@ant-design/icons-vue'
import { $notify, NotifyPreset } from '@/utils/notify'
import request from '@/api/request'
import { formatDateTime } from '@/utils/date'

const columns = [
  { title: '设备名称', dataIndex: 'device_name', key: 'device_name' },
  { title: '设备ID', dataIndex: 'device_id', key: 'device_id' },
  { title: '类型', key: 'device_type', width: 120 },
  { title: '状态', key: 'device_status', width: 100 },
  { title: '区域/房号', dataIndex: 'area', key: 'area' },
  { title: '最后在线', key: 'last_online' },
  { title: '操作', key: 'action', width: 120 }
]

const devices = ref<any[]>([])
const loading = ref(false)
const mqttModalVisible = ref(false)
const mqttSending = ref(false)
const currentDevice = ref<any>({})
const mqttForm = ref({
  topic: 'hotel/device/command/room/room_301',
  payload: JSON.stringify(
    {
      command_id: Date.now(),
      device_id: 'room_301',
      command_type: 'set_ac_temp',
      command_value: 26,
      timestamp: new Date().toISOString(),
      hotel_id: 3,
      room_id: 301
    },
    null,
    2
  )
})

const getDeviceTypeName = (type: string) => {
  const types: Record<string, string> = {
    'front_desk': '前台发卡器',
    'smart_lock': '智能门锁',
    'gateway': '智能网关',
    'room_controller': '客控主机'
  }
  return types[type] || type
}

const fetchDevices = async () => {
  loading.value = true
  try {
    const res: any = await request.get('/devices', { params: { audit_status: 'approved' } })
    // 后端返回 { success: true, data: [...] }
    devices.value = res && res.success && Array.isArray(res.data) ? res.data : []
  } catch (error) {
    $notify.error({ title: '获取设备列表失败', description: '无法加载设备数据，请检查网络后重试 🔄' })
    console.error('获取设备列表失败:', error)
  } finally {
    loading.value = false
  }
}

const testDevice = async (record: any) => {
  try {
    await request.post(`/devices/${record.id}/command`, {
      command_type: 'light_on',
      command_value: 'on'
    })
    $notify.success({ title: '测试指令已下发', description: '请观察设备反馈，确认通信是否正常 📡' })
  } catch (error) {
    NotifyPreset.operationFailed('下发失败')
  }
}

const buildTopicByDevice = (device: any) => {
  const type = device?.device_type
  const id = device?.device_id || 'room_301'
  if (type === 'floor') return `hotel/device/command/floor/${id}`
  if (type === 'front_desk') return `hotel/device/command/front_desk/${id}`
  return `hotel/device/command/room/${id}`
}

const buildDefaultPayloadByDevice = (device: any) => {
  const type = device?.device_type
  const id = device?.device_id || 'room_301'
  let commandType = 'set_ac_temp'
  let commandValue: any = 26
  if (type === 'floor') {
    commandType = 'broadcast_alarm'
    commandValue = 'alarm'
  } else if (type === 'front_desk') {
    commandType = 'alarm_trigger'
    commandValue = 'alarm'
  }
  return {
    command_id: Date.now(),
    device_id: id,
    command_type: commandType,
    command_value: commandValue,
    timestamp: new Date().toISOString(),
    hotel_id: 3,
    room_id: 301
  }
}

const openMqttModal = (record: any) => {
  currentDevice.value = record || {}
  mqttForm.value.topic = buildTopicByDevice(record)
  mqttForm.value.payload = JSON.stringify(buildDefaultPayloadByDevice(record), null, 2)
  mqttModalVisible.value = true
}

const confirmSendMqtt = async () => {
  try {
    mqttSending.value = true
    let payloadObj: any = {}
    try {
      payloadObj = JSON.parse(mqttForm.value.payload)
    } catch {
      message.error('Payload 不是合法 JSON')
      return
    }
    await request.post('/mqtt/send', {
      topic: mqttForm.value.topic,
      payload: payloadObj,
      qos: 0,
      retain: false
    })
    message.success('MQTT 命令已发送')
    mqttModalVisible.value = false
  } catch (error) {
    message.error('发送 MQTT 命令失败')
  } finally {
    mqttSending.value = false
  }
}

onMounted(fetchDevices)
</script>

<style scoped>
.device-card-title {
  margin-bottom: 12px;
  font-weight: 600;
}
.device-card {
  min-height: 188px;
}
.device-name {
  font-size: 14px;
  font-weight: 600;
}
.device-meta {
  margin-bottom: 6px;
  font-size: 12px;
  color: #595959;
}
.card-actions {
  margin-top: 10px;
}
</style>
