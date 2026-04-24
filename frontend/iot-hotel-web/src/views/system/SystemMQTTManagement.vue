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

      <!-- 快捷设备控制 -->
      <a-col :span="24" style="margin-bottom: 16px;">
        <a-card title="快捷设备控制" :bordered="false">
          <a-row :gutter="16">
            <!-- 房间选择 -->
            <a-col :span="6">
              <a-form-item label="目标房间">
                <a-select
                  v-model:value="deviceControl.roomId"
                  placeholder="选择房间"
                  style="width: 100%"
                  @change="onRoomChange"
                >
                  <a-select-option v-for="room in roomOptions" :key="room.value" :value="room.value">
                    {{ room.label }}
                  </a-select-option>
                </a-select>
              </a-form-item>
            </a-col>
            <a-col :span="6">
              <a-form-item label="或输入房间号">
                <a-input
                  v-model:value="deviceControl.customRoomId"
                  placeholder="如: 301"
                  @change="onCustomRoomChange"
                />
              </a-form-item>
            </a-col>
          </a-row>

          <a-divider />

          <!-- 设备控制按钮 -->
          <a-row :gutter="16">
            <!-- 灯光控制 -->
            <a-col :span="6">
              <a-card size="small" title="💡 房间灯光" class="control-card">
                <a-space direction="vertical" style="width: 100%">
                  <a-button type="primary" block @click="sendQuickCommand('light', 'on')">
                    <BulbOutlined /> 开灯
                  </a-button>
                  <a-button block @click="sendQuickCommand('light', 'off')">
                    <BulbOutlined /> 关灯
                  </a-button>
                </a-space>
              </a-card>
            </a-col>

            <!-- 空调控制 -->
            <a-col :span="6">
              <a-card size="small" title="❄️ 空调控制" class="control-card">
                <a-space direction="vertical" style="width: 100%">
                  <a-row :gutter="8">
                    <a-col :span="12">
                      <a-button type="primary" block size="small" @click="sendQuickCommand('air', 'on')">
                        开启
                      </a-button>
                    </a-col>
                    <a-col :span="12">
                      <a-button block size="small" @click="sendQuickCommand('air', 'off')">
                        关闭
                      </a-button>
                    </a-col>
                  </a-row>
                  <a-divider style="margin: 8px 0" />
                  <a-row :gutter="8">
                    <a-col :span="8">
                      <a-button block size="small" @click="sendQuickCommand('air', 'temp:16')">16°C</a-button>
                    </a-col>
                    <a-col :span="8">
                      <a-button block size="small" @click="sendQuickCommand('air', 'temp:24')">24°C</a-button>
                    </a-col>
                    <a-col :span="8">
                      <a-button block size="small" @click="sendQuickCommand('air', 'temp:26')">26°C</a-button>
                    </a-col>
                  </a-row>
                </a-space>
              </a-card>
            </a-col>

            <!-- 窗帘控制 -->
            <a-col :span="6">
              <a-card size="small" title="🪟 电动窗帘" class="control-card">
                <a-space direction="vertical" style="width: 100%">
                  <a-button type="primary" block @click="sendQuickCommand('curtain', 'open')">
                    <ColumnHeightOutlined /> 打开窗帘
                  </a-button>
                  <a-button block @click="sendQuickCommand('curtain', 'close')">
                    <ColumnHeightOutlined /> 关闭窗帘
                  </a-button>
                </a-space>
              </a-card>
            </a-col>

            <!-- 门锁控制 -->
            <a-col :span="6">
              <a-card size="small" title="🚪 智能门锁" class="control-card">
                <a-space direction="vertical" style="width: 100%">
                  <a-button type="primary" danger block @click="sendQuickCommand('door', 'unlock')">
                    <UnlockOutlined /> 开锁 (8秒自动回锁)
                  </a-button>
                  <a-button block @click="sendQuickCommand('door', 'lock')">
                    <LockOutlined /> 锁定
                  </a-button>
                </a-space>
              </a-card>
            </a-col>
          </a-row>

          <a-divider />

          <!-- 场景模式 -->
          <a-row :gutter="16">
            <a-col :span="24">
              <a-card size="small" title="🎭 场景模式" class="control-card">
                <a-space>
                  <a-button type="primary" @click="sendQuickCommand('scene', 'welcome')">
                    <HomeOutlined /> 迎宾模式
                    <a-tag color="blue" style="margin-left: 8px">开灯+开空调+开窗帘</a-tag>
                  </a-button>
                  <a-button @click="sendQuickCommand('scene', 'reading')">
                    <ReadOutlined /> 阅读模式
                    <a-tag color="green" style="margin-left: 8px">开灯+开空调+关窗帘</a-tag>
                  </a-button>
                  <a-button @click="sendQuickCommand('scene', 'sleep')">
                    <SunOutlined /> 睡眠模式
                    <a-tag color="purple" style="margin-left: 8px">关灯+关窗帘+空调26°C</a-tag>
                  </a-button>
                  <a-button @click="sendQuickCommand('scene', 'leave')">
                    <LogoutOutlined /> 外出模式
                    <a-tag color="orange" style="margin-left: 8px">关闭所有设备</a-tag>
                  </a-button>
                </a-space>
              </a-card>
            </a-col>
          </a-row>

          <a-divider />

          <!-- 楼层/前台控制 -->
          <a-row :gutter="16">
            <a-col :span="12">
              <a-card size="small" title="🏢 楼层控制" class="control-card">
                <a-space>
                  <a-select v-model:value="deviceControl.floorId" placeholder="选择楼层" style="width: 120px">
                    <a-select-option v-for="floor in floorOptions" :key="floor" :value="floor">
                      {{ floor }}层
                    </a-select-option>
                  </a-select>
                  <a-button @click="sendFloorCommand('light', 'on')">
                    <BulbOutlined /> 开走廊灯
                  </a-button>
                  <a-button @click="sendFloorCommand('light', 'off')">
                    <BulbOutlined /> 关走廊灯
                  </a-button>
                  <a-button type="primary" danger @click="sendFloorCommand('broadcast_start')">
                    <SoundOutlined /> 广播
                  </a-button>
                </a-space>
              </a-card>
            </a-col>
            <a-col :span="12">
              <a-card size="small" title="🔔 系统指令" class="control-card">
                <a-space>
                  <a-button @click="sendSystemCommand('alarm_reset')">
                    <SafetyOutlined /> 消警复位
                  </a-button>
                  <a-button @click="sendSystemCommand('buzzer', { count: 3 })">
                    <NotificationOutlined /> 蜂鸣器测试
                  </a-button>
                </a-space>
              </a-card>
            </a-col>
          </a-row>
        </a-card>
      </a-col>

      <!-- 手动下发指令 -->
      <a-col :span="8">
        <a-card title="高级：手动下发指令" :bordered="false">
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
                placeholder='{"command_type": "light", "command_value": "on", "command_id": 123}'
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

          <!-- 常用指令模板 -->
          <a-divider>常用指令模板</a-divider>
          <a-space direction="vertical" style="width: 100%">
            <a-button block size="small" @click="applyTemplate('light_on')">灯光开启</a-button>
            <a-button block size="small" @click="applyTemplate('light_off')">灯光关闭</a-button>
            <a-button block size="small" @click="applyTemplate('door_unlock')">门锁开启</a-button>
            <a-button block size="small" @click="applyTemplate('scene_welcome')">迎宾场景</a-button>
          </a-space>
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
                {{ formatDate(record.timestamp) }}
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
import {
  ReloadOutlined,
  BulbOutlined,
  ColumnHeightOutlined,
  UnlockOutlined,
  LockOutlined,
  HomeOutlined,
  ReadOutlined,
  LogoutOutlined,
  SoundOutlined,
  SafetyOutlined,
  NotificationOutlined,
  SunOutlined
} from '@ant-design/icons-vue'
import request from '@/api/request'
import dayjs from 'dayjs'

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

const deviceControl = reactive({
  roomId: '',
  customRoomId: '',
  floorId: '3'
})

// 房间选项（可以从API获取）
const roomOptions = ref([
  { value: '301', label: '301 标准间' },
  { value: '302', label: '302 标准间' },
  { value: '303', label: '303 大床房' },
  { value: '201', label: '201 豪华套房' },
  { value: '202', label: '202 豪华套房' }
])

const floorOptions = ref(['1', '2', '3', '4', '5'])

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

// 指令模板
const commandTemplates: Record<string, { topic: string; payload: object }> = {
  light_on: {
    topic: 'hotel/device/command/room/{room}',
    payload: { command_type: 'light', command_value: 'on', command_id: Date.now() }
  },
  light_off: {
    topic: 'hotel/device/command/room/{room}',
    payload: { command_type: 'light', command_value: 'off', command_id: Date.now() }
  },
  door_unlock: {
    topic: 'hotel/device/command/room/{room}',
    payload: { command_type: 'door', command_value: 'unlock', command_id: Date.now() }
  },
  scene_welcome: {
    topic: 'hotel/device/command/room/{room}',
    payload: { command_type: 'scene', command_value: 'welcome', command_id: Date.now() }
  }
}

const fetchStatus = async () => {
  loading.status = true
  try {
    const res = await request.get('/mqtt/status')
    status.value = {
      ...res.data,
      lastUpdate: dayjs().format('YYYY-MM-DD HH:mm:ss')
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
    fetchLogs()
  } catch (err) {
    message.error('指令发送失败')
  } finally {
    loading.send = false
  }
}

// 获取当前目标房间
const getTargetRoom = () => {
  return deviceControl.customRoomId || deviceControl.roomId || '301'
}

const onRoomChange = (value: string) => {
  deviceControl.customRoomId = ''
}

const onCustomRoomChange = () => {
  deviceControl.roomId = ''
}

// 发送快捷控制指令
const sendQuickCommand = async (commandType: string, commandValue: string | object) => {
  const roomId = getTargetRoom()
  const topic = `hotel/device/command/room/${roomId}`
  const payload = {
    command_type: commandType,
    command_value: commandValue,
    command_id: Date.now(),
    timestamp: dayjs().format('YYYY-MM-DD HH:mm:ss'),
    created_by: 'web_admin'
  }

  try {
    await request.post('/mqtt/send', {
      topic,
      payload,
      qos: 1,
      retain: false
    })
    message.success(`指令已发送至房间 ${roomId}: ${commandType}=${commandValue}`)
    fetchLogs()
  } catch (err) {
    message.error('指令发送失败')
  }
}

// 发送楼层控制指令
const sendFloorCommand = async (commandType: string, commandValue?: string) => {
  const floorId = deviceControl.floorId
  const topic = `hotel/device/command/floor/FLO_${floorId}F`
  const payload: any = {
    command_type: commandType,
    command_id: Date.now(),
    timestamp: dayjs().format('YYYY-MM-DD HH:mm:ss'),
    created_by: 'web_admin'
  }
  if (commandValue) {
    payload.command_value = commandValue
  }

  try {
    await request.post('/mqtt/send', {
      topic,
      payload,
      qos: 1,
      retain: false
    })
    message.success(`楼层指令已发送: ${commandType}`)
    fetchLogs()
  } catch (err) {
    message.error('指令发送失败')
  }
}

// 发送系统指令
const sendSystemCommand = async (commandType: string, commandValue?: object) => {
  const topic = 'hotel/device/command/room/all'
  const payload: any = {
    command_type: commandType,
    command_id: Date.now(),
    timestamp: dayjs().format('YYYY-MM-DD HH:mm:ss'),
    created_by: 'web_admin'
  }
  if (commandValue) {
    payload.command_value = commandValue
  }

  try {
    await request.post('/mqtt/send', {
      topic,
      payload,
      qos: 1,
      retain: false
    })
    message.success(`系统指令已发送: ${commandType}`)
    fetchLogs()
  } catch (err) {
    message.error('指令发送失败')
  }
}

// 应用指令模板
const applyTemplate = (templateName: string) => {
  const template = commandTemplates[templateName]
  if (!template) return

  const roomId = getTargetRoom()
  commandForm.topic = template.topic.replace('{room}', roomId)
  commandForm.payload = JSON.stringify(template.payload, null, 2)
}

const handleTableChange = (pag: any) => {
  pagination.current = pag.current
  pagination.pageSize = pag.pageSize
  fetchLogs()
}

const formatDate = (date: string) => {
  return dayjs(date).format('MM-DD HH:mm:ss')
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

.control-card {
  margin-bottom: 16px;
}

.control-card :deep(.ant-card-head) {
  background: #f5f5f5;
  font-size: 14px;
  min-height: 40px;
}

.control-card :deep(.ant-card-body) {
  padding: 12px;
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
