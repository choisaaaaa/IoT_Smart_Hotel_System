<template>
  <div class="mqtt-management">
    <a-row :gutter="16">
      <a-col :span="24" style="margin-bottom: 16px;">
        <a-card title="MQTT 服务状态" :bordered="false">
          <template #extra>
            <a-tag :color="status.connected ? 'success' : 'error'">
              {{ status.connected ? '已连接' : '已断开' }}
            </a-tag>
            <a-button type="link" @click="fetchStatus" :loading="loading.status">刷新状态</a-button>
          </template>
          <a-descriptions bordered size="small">
            <a-descriptions-item label="代理服务器">{{ status.broker }}</a-descriptions-item>
            <a-descriptions-item label="当前连接数">{{ status.connections || '未知' }}</a-descriptions-item>
            <a-descriptions-item label="最后更新">{{ status.lastUpdate || '-' }}</a-descriptions-item>
          </a-descriptions>
        </a-card>
      </a-col>

      <a-col :span="8">
        <a-card title="手动下发指令" :bordered="false">
          <a-form :model="commandForm" layout="vertical" @finish="sendCommand">
            <a-form-item label="主题" name="topic" required>
              <a-auto-complete
                v-model:value="commandForm.topic"
                placeholder="例如: hotel/device/command/room/301"
                :options="topicOptions"
              />
            </a-form-item>
            <a-form-item label="消息内容 (JSON)" name="payload" required>
              <a-textarea
                v-model:value="commandForm.payload"
                placeholder='{"command_type": "light_on", "command_id": 123}'
                :rows="4"
              />
            </a-form-item>
            <a-row :gutter="8">
              <a-col :span="12">
                <a-form-item label="服务质量 (QoS)" name="qos">
                  <a-select v-model:value="commandForm.qos">
                    <a-select-option :value="0">0 - 最多一次</a-select-option>
                    <a-select-option :value="1">1 - 至少一次</a-select-option>
                    <a-select-option :value="2">2 - 恰好一次</a-select-option>
                  </a-select>
                </a-form-item>
              </a-col>
              <a-col :span="12">
                <a-form-item label="保留消息 (Retain)" name="retain">
                  <a-switch v-model:checked="commandForm.retain" />
                </a-form-item>
              </a-col>
            </a-row>
            <a-form-item>
              <a-button type="primary" html-type="submit" block :loading="loading.send">
                发送指令
              </a-button>
            </a-form-item>
          </a-form>
        </a-card>
      </a-col>

      <a-col :span="16">
        <a-card title="MQTT 通信记录" :bordered="false">
          <template #extra>
            <a-space>
              <a-select
                v-if="isSystemAdmin"
                v-model:value="filterHotelId"
                placeholder="筛选酒店"
                style="width: 180px"
                allow-clear
                @change="fetchLogs"
              >
                <a-select-option v-for="hotel in hotels" :key="hotel.id" :value="hotel.id">
                  {{ hotel.hotel_name }}
                </a-select-option>
              </a-select>
              <a-input-search
                v-model:value="filter.deviceId"
                placeholder="搜索设备ID"
                style="width: 200px"
                @search="fetchLogs"
              />
              <a-button @click="fetchLogs" :loading="loading.logs">
                <template #icon><ReloadOutlined /></template>
              </a-button>
            </a-space>
          </template>
          
          <a-table
            :columns="columns"
            :data-source="logs"
            :pagination="pagination"
            :loading="loading.logs"
            size="small"
            @change="handleTableChange"
          >
            <template #bodyCell="{ column, record }">
              <template v-if="column.key === 'direction'">
                <a-tag :color="record.direction === 'in' ? 'blue' : 'orange'">
                  {{ record.direction === 'in' ? '收到' : '发出' }}
                </a-tag>
              </template>
              <template v-if="column.key === 'payload'">
                <a-typography-text
                  :ellipsis="{ rows: 1, expandable: true, symbol: '展开' }"
                  style="margin-bottom: 0"
                >
                  <code>{{ record.payload }}</code>
                </a-typography-text>
              </template>
              <template v-if="column.key === 'timestamp'">
                {{ formatDotDateTime(record.timestamp) }}
              </template>
            </template>
          </a-table>
        </a-card>
      </a-col>
    </a-row>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, reactive, computed } from 'vue'
import { $notify, NotifyPreset } from '@/utils/notify'
import { ReloadOutlined } from '@ant-design/icons-vue'
import request from '@/api/request'
import { formatDotDateTime, formatDateTime } from '@/utils/date'
import { hotelManageApi, type HotelManageInfo } from '@/api/hotel-manage'
import { useAppStore } from '@/stores/app'
import { normalizeRole, CANONICAL_ROLES } from '@/api/auth'

const appStore = useAppStore()
appStore.initUserInfo()

const isSystemAdmin = computed(() => normalizeRole(appStore.userInfo?.role) === CANONICAL_ROLES.SYSTEM_ADMIN)

const status = ref({
  connected: false,
  broker: '',
  connections: 0,
  lastUpdate: ''
})

const loading = reactive({
  status: false,
  send: false,
  logs: false
})

const commandForm = reactive({
  topic: '',
  payload: '',
  qos: 1,
  retain: false
})

const topicOptions = [
  { value: 'hotel/device/command/room/' },
  { value: 'hotel/device/command/floor/' },
  { value: 'hotel/system/broadcast' }
]

const logs = ref([])
const filter = reactive({
  deviceId: ''
})
const filterHotelId = ref<number | undefined>(undefined)
const hotels = ref<HotelManageInfo[]>([])

const pagination = reactive({
  current: 1,
  pageSize: 10,
  total: 0,
  showSizeChanger: true
})

const columns = [
  { title: '方向', key: 'direction', dataIndex: 'direction', width: 80 },
  { title: '主题', dataIndex: 'topic', key: 'topic', ellipsis: true },
  { title: '消息内容', dataIndex: 'payload', key: 'payload' },
  { title: '设备ID', dataIndex: 'device_id', key: 'device_id', width: 120 },
  { title: '服务质量', dataIndex: 'qos', key: 'qos', width: 60 },
  { title: '时间', dataIndex: 'timestamp', key: 'timestamp', width: 160 }
]

const fetchStatus = async () => {
  loading.status = true
  try {
    const res = await request.get('/mqtt/status')
    status.value = {
      ...res.data,
      lastUpdate: formatDateTime(new Date())
    }
  } catch (err) {
    $notify.error({ title: '获取MQTT状态失败', description: '无法获取MQTT服务状态，请检查网络连接' })
  } finally {
    loading.status = false
  }
}

const fetchLogs = async () => {
  loading.logs = true
  try {
    const params: any = {
      device_id: filter.deviceId,
      limit: pagination.pageSize,
      offset: (pagination.current - 1) * pagination.pageSize
    }
    if (isSystemAdmin.value && filterHotelId.value) {
      params.hotel_id = filterHotelId.value
    }
    const res = await request.get('/mqtt/logs', { params })
    logs.value = res.data
    pagination.total = res.data.length < pagination.pageSize ? (pagination.current - 1) * pagination.pageSize + res.data.length : 1000
  } catch (err) {
    $notify.error({ title: '获取通信日志失败', description: '无法加载MQTT通信记录，请稍后重试' })
  } finally {
    loading.logs = false
  }
}

const fetchHotels = async () => {
  if (!isSystemAdmin.value) return
  try {
    const res: any = await hotelManageApi.getAllHotels()
    if (res && res.code === 200 && Array.isArray(res.data)) {
      hotels.value = res.data
    } else {
      hotels.value = []
    }
  } catch (error) {
    console.error('获取酒店列表失败:', error)
    hotels.value = []
  }
}

const sendCommand = async () => {
  loading.send = true
  try {
    let payload = commandForm.payload
    try {
      payload = JSON.parse(commandForm.payload)
    } catch (e) {
    }

    await request.post('/mqtt/send', {
      topic: commandForm.topic,
      payload,
      qos: commandForm.qos,
      retain: commandForm.retain
    })
    $notify.success({ title: '指令已发送', description: 'MQTT指令已成功下发至目标设备 📡' })
    fetchLogs()
  } catch (err) {
    NotifyPreset.operationFailed('MQTT指令发送失败')
  } finally {
    loading.send = false
  }
}

const handleTableChange = (pag: any) => {
  pagination.current = pag.current
  pagination.pageSize = pag.pageSize
  fetchLogs()
}

onMounted(() => {
  fetchStatus()
  fetchLogs()
  fetchHotels()
})
</script>

<style scoped>
.mqtt-management {
  padding: 16px;
}
code {
  background: #f5f5f5;
  padding: 2px 4px;
  border-radius: 4px;
  font-family: monospace;
  font-size: 12px;
}
.urgent-text {
  color: #ff4d4f;
}
</style>
