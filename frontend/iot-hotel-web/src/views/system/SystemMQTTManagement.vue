<template>
  <div class="mqtt-management">
    <a-row :gutter="16">
      <!-- MQTT 服务状态 -->
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

      <!-- 手动下发指令 -->
      <a-col :span="8">
        <a-card title="手动下发指令" :bordered="false">
          <a-form :model="commandForm" layout="vertical" @finish="sendCommand">
            <a-form-item label="主题 (Topic)" name="topic" required>
              <a-auto-complete
                v-model:value="commandForm.topic"
                placeholder="例如: hotel/device/command/room/301"
                :options="topicOptions"
              />
            </a-form-item>
            <a-form-item label="内容 (Payload/JSON)" name="payload" required>
              <a-textarea
                v-model:value="commandForm.payload"
                placeholder='{"command_type": "light_on", "command_id": 123}'
                :rows="4"
              />
            </a-form-item>
            <a-row :gutter="8">
              <a-col :span="12">
                <a-form-item label="QoS" name="qos">
                  <a-select v-model:value="commandForm.qos">
                    <a-select-option :value="0">0 (At most once)</a-select-option>
                    <a-select-option :value="1">1 (At least once)</a-select-option>
                    <a-select-option :value="2">2 (Exactly once)</a-select-option>
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

      <!-- 通信记录 -->
      <a-col :span="16">
        <a-card title="MQTT 通信记录" :bordered="false">
          <template #extra>
            <a-space>
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
import { ref, onMounted, reactive } from 'vue'
import { message } from 'ant-design-vue'
import { ReloadOutlined } from '@ant-design/icons-vue'
import request from '@/api/request'
import { formatDotDateTime, formatDateTime } from '@/utils/date'

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

const pagination = reactive({
  current: 1,
  pageSize: 10,
  total: 0,
  showSizeChanger: true
})

const columns = [
  { title: '方向', key: 'direction', dataIndex: 'direction', width: 80 },
  { title: '主题 (Topic)', dataIndex: 'topic', key: 'topic', ellipsis: true },
  { title: '内容 (Payload)', dataIndex: 'payload', key: 'payload' },
  { title: '设备ID', dataIndex: 'device_id', key: 'device_id', width: 120 },
  { title: 'QoS', dataIndex: 'qos', key: 'qos', width: 60 },
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
    message.error('获取MQTT状态失败')
  } finally {
    loading.status = false
  }
}

const fetchLogs = async () => {
  loading.logs = true
  try {
    const res = await request.get('/mqtt/logs', {
      params: {
        device_id: filter.deviceId,
        limit: pagination.pageSize,
        offset: (pagination.current - 1) * pagination.pageSize
      }
    })
    logs.value = res.data
    // 模拟总数，实际后端应返回总数
    pagination.total = res.data.length < pagination.pageSize ? (pagination.current - 1) * pagination.pageSize + res.data.length : 1000
  } catch (err) {
    message.error('获取通信日志失败')
  } finally {
    loading.logs = false
  }
}

const sendCommand = async () => {
  loading.send = true
  try {
    // 尝试解析 JSON
    let payload = commandForm.payload
    try {
      payload = JSON.parse(commandForm.payload)
    } catch (e) {
      // 如果不是 JSON，则按原样发送
    }

    await request.post('/mqtt/send', {
      topic: commandForm.topic,
      payload,
      qos: commandForm.qos,
      retain: commandForm.retain
    })
    message.success('指令已发送')
    fetchLogs() // 刷新日志以显示发出的指令
  } catch (err) {
    message.error('指令发送失败')
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
