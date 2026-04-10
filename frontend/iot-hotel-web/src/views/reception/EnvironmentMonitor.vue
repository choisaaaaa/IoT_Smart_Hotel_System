<template>
  <div class="environment-monitor">
    <a-row :gutter="[16, 16]" class="summary-cards">
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card temp-card">
          <a-statistic
            title="平均温度"
            :value="summary.avg_temperature"
            suffix="°C"
            :value-style="{ color: '#1890ff', fontSize: '24px' }"
          >
            <template #prefix>
              <FireOutlined />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card humidity-card">
          <a-statistic
            title="平均湿度"
            :value="summary.avg_humidity"
            suffix="%"
            :value-style="{ color: '#52c41a', fontSize: '24px' }"
          >
            <template #prefix>
              <CloudOutlined />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card smoke-card">
          <a-statistic
            title="烟雾浓度"
            :value="summary.avg_smoke_level"
            suffix="%"
            :value-style="{ color: '#faad14', fontSize: '24px' }"
          >
            <template #prefix>
              <AlertOutlined />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card status-card">
          <a-statistic
            title="监测房间"
            :value="summary.total_rooms"
            suffix="间"
            :value-style="{ color: '#722ed1', fontSize: '24px' }"
          >
            <template #prefix>
              <HomeOutlined />
            </template>
          </a-statistic>
          <div class="status-tags">
            <a-tag color="success">正常 {{ summary.normal_count }}</a-tag>
            <a-tag color="warning">警告 {{ summary.warning_count }}</a-tag>
            <a-tag color="error">危险 {{ summary.danger_count }}</a-tag>
          </div>
        </a-card>
      </a-col>
    </a-row>

    <a-card style="margin-top: 16px;">
      <template #title>
        <div style="display: flex; justify-content: space-between; align-items: center;">
          <span><EnvironmentOutlined /> 实时环境监测</span>
          <div style="display: flex; gap: 8px; align-items: center;">
            <a-select
              v-model:value="selectedFloor"
              placeholder="选择楼层"
              allowClear
              style="width: 120px;"
              @change="fetchData"
            >
              <a-select-option value="">全部楼层</a-select-option>
              <a-select-option :value="3">3楼</a-select-option>
              <a-select-option :value="4">4楼</a-select-option>
              <a-select-option :value="5">5楼</a-select-option>
            </a-select>
            <a-select
              v-model:value="selectedStatus"
              placeholder="状态筛选"
              allowClear
              style="width: 100px;"
              @change="fetchData"
            >
              <a-select-option value="">全部状态</a-select-option>
              <a-select-option value="normal">正常</a-select-option>
              <a-select-option value="warning">警告</a-select-option>
              <a-select-option value="danger">危险</a-select-option>
            </a-select>
            <a-button type="primary" :loading="loading" @click="fetchData">
              <ReloadOutlined /> 刷新
            </a-button>
            <a-switch
              v-model:checked="autoRefresh"
              checked-children="自动刷新"
              un-checked-children="手动刷新"
              @change="toggleAutoRefresh"
            />
          </div>
        </div>
      </template>

      <a-table
        :dataSource="displayList"
        :columns="columns"
        :loading="loading"
        rowKey="room_id"
        :pagination="false"
        size="middle"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'room_number'">
            <a-tag color="blue">{{ record.room_number }}</a-tag>
            <br/>
            <span style="font-size: 11px; color: #999;">{{ record.floor_name }}</span>
          </template>

          <template v-if="column.key === 'temperature'">
            <span :style="{ color: getTemperatureColor(record.temperature), fontWeight: 'bold' }">
              {{ record.temperature }}°C
            </span>
          </template>

          <template v-if="column.key === 'humidity'">
            <span :style="{ color: getHumidityColor(record.humidity), fontWeight: 'bold' }">
              {{ record.humidity }}%
            </span>
          </template>

          <template v-if="column.key === 'smoke_level'">
            <a-progress
              :percent="record.smoke_level"
              :status="record.smoke_alarm ? 'exception' : 'active'"
              :stroke-color="getSmokeColor(record.smoke_level)"
              size="small"
              style="width: 80px;"
            />
          </template>

          <template v-if="column.key === 'status'">
            <a-badge :status="getStatusBadge(record.status)" :text="getStatusText(record.status)" />
          </template>

          <template v-if="column.key === 'update_time'">
            <span style="font-size: 12px; color: #666;">
              {{ formatTime(record.update_time) }}
            </span>
          </template>
        </template>
      </a-table>

      <a-empty v-if="!displayList.length && !loading" description="暂无环境监测数据" />

      <a-alert
        v-if="summary.danger_count > 0"
        message="⚠️ 环境异常警告"
        :description="`检测到 ${summary.danger_count} 个房间存在危险级别的环境异常（温度过高/过低、湿度过高/过低的、或烟雾浓度超标），请立即处理！`"
        type="error"
        show-icon
        closable
        style="margin-top: 16px;"
      />

      <a-alert
        v-else-if="summary.warning_count > 0 && !usingMockData"
        message="⚡ 环境异常提醒"
        :description="`检测到 ${summary.warning_count} 个房间存在警告级别的环境异常，建议关注并适时调整。`"
        type="warning"
        show-icon
        closable
        style="margin-top: 16px;"
      />

      <a-alert
        v-if="usingMockData"
        message="💡 当前显示模拟数据"
        description="系统正在使用模拟数据进行展示，后端服务未连接或API调用失败。接入真实设备后可删除此提示。"
        type="info"
        show-icon
        closable
        style="margin-top: 16px;"
      />
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, onUnmounted } from 'vue'
import { message } from 'ant-design-vue'
import {
  CloudOutlined,
  AlertOutlined,
  HomeOutlined,
  EnvironmentOutlined,
  ReloadOutlined,
  FireOutlined
} from '@ant-design/icons-vue'
import { environmentApi, type EnvironmentData, type EnvironmentSummary } from '@/api/environment'
import dayjs from 'dayjs'
import relativeTime from 'dayjs/plugin/relativeTime'

dayjs.extend(relativeTime)

const loading = ref(false)
const environmentList = ref<EnvironmentData[]>([])
const usingMockData = ref(false)
const summary = reactive<EnvironmentSummary>({
  avg_temperature: 0,
  avg_humidity: 0,
  avg_smoke_level: 0,
  avg_noise_level: 0,
  avg_pm25: 0,
  avg_environment_score: 0,
  normal_count: 0,
  warning_count: 0,
  danger_count: 0,
  total_rooms: 0
})

const selectedFloor = ref<number | undefined>(undefined)
const selectedStatus = ref<string>('')
const autoRefresh = ref(false)
let refreshTimer: ReturnType<typeof setInterval> | null = null

const columns = [
  {
    title: '房间',
    key: 'room_number',
    width: 100
  },
  {
    title: '温度',
    dataIndex: 'temperature',
    key: 'temperature',
    width: 100,
    sorter: (a: EnvironmentData, b: EnvironmentData) => a.temperature - b.temperature
  },
  {
    title: '湿度',
    dataIndex: 'humidity',
    key: 'humidity',
    width: 90,
    sorter: (a: EnvironmentData, b: EnvironmentData) => a.humidity - b.humidity
  },
  {
    title: '烟雾浓度',
    dataIndex: 'smoke_level',
    key: 'smoke_level',
    width: 140
  },
  {
    title: '光照强度',
    dataIndex: 'light_level',
    key: 'light_level',
    width: 100
  },
  {
    title: '状态',
    key: 'status',
    width: 90
  },
  {
    title: '更新时间',
    dataIndex: 'update_time',
    key: 'update_time',
    width: 120
  }
]

function generateMockEnvironmentData(): EnvironmentData[] {
  const now = new Date()
  const rooms = [
    { room_id: 1, room_number: '301', floor_id: 3, floor_name: '3楼' },
    { room_id: 2, room_number: '302', floor_id: 3, floor_name: '3楼' },
    { room_id: 3, room_number: '303', floor_id: 3, floor_name: '3楼' },
    { room_id: 4, room_number: '304', floor_id: 3, floor_name: '3楼' },
    { room_id: 5, room_number: '305', floor_id: 3, floor_name: '3楼' },
    { room_id: 6, room_number: '401', floor_id: 4, floor_name: '4楼' },
    { room_id: 7, room_number: '402', floor_id: 4, floor_name: '4楼' },
    { room_id: 8, room_number: '403', floor_id: 4, floor_name: '4楼' },
    { room_id: 9, room_number: '404', floor_id: 4, floor_name: '4楼' },
    { room_id: 10, room_number: '405', floor_id: 4, floor_name: '4楼' },
    { room_id: 11, room_number: '501', floor_id: 5, floor_name: '5楼' },
    { room_id: 12, room_number: '502', floor_id: 5, floor_name: '5楼' }
  ]

  return rooms.map((room, index) => {
    let temperature: number, humidity: number, smokeLevel: number

    if (index === 7) {
      temperature = 35.8 + Math.random() * 1.5
      humidity = 68 + Math.random() * 8
      smokeLevel = 75 + Math.random() * 10
    } else if (index === 3) {
      temperature = 32.5 + Math.random() * 2
      humidity = 78 + Math.random() * 5
      smokeLevel = 48 + Math.random() * 8
    } else if (index === 9 || index === 10) {
      temperature = 28 + Math.random() * 3
      humidity = 72 + Math.random() * 6
      smokeLevel = 38 + Math.random() * 8
    } else {
      temperature = 22 + Math.random() * 6
      humidity = 45 + Math.random() * 25
      smokeLevel = 8 + Math.random() * 22
    }

    const lightLevel = parseInt((200 + Math.random() * 600).toString())
    let status: 'normal' | 'warning' | 'danger' = 'normal'

    if (temperature > 30 || temperature < 18 || humidity > 75 || humidity < 30) {
      status = 'warning'
    }

    if (smokeLevel > 60 || temperature > 35) {
      status = 'danger'
    }

    return {
      ...room,
      temperature: parseFloat(temperature.toFixed(1)),
      humidity: parseFloat(humidity.toFixed(1)),
      smoke_level: parseFloat(smokeLevel.toFixed(1)),
      smoke_alarm: smokeLevel > 60,
      noise_level: parseFloat((30 + Math.random() * 20).toFixed(1)),
      pm25: parseFloat((5 + Math.random() * 15).toFixed(1)),
      light_level: lightLevel,
      environment_score: status === 'normal' ? 95 : (status === 'warning' ? 75 : 45),
      update_time: new Date(now.getTime() - index * 60000).toISOString(),
      status
    }
  })
}

function calculateMockSummary(data: EnvironmentData[]): EnvironmentSummary {
  if (data.length === 0) {
    return {
      avg_temperature: 0,
      avg_humidity: 0,
      avg_smoke_level: 0,
      avg_noise_level: 0,
      avg_pm25: 0,
      avg_environment_score: 0,
      normal_count: 0,
      warning_count: 0,
      danger_count: 0,
      total_rooms: 0
    }
  }

  const totalTemp = data.reduce((sum, item) => sum + item.temperature, 0)
  const totalHumidity = data.reduce((sum, item) => sum + item.humidity, 0)
  const totalSmoke = data.reduce((sum, item) => sum + item.smoke_level, 0)
  const totalNoise = data.reduce((sum, item) => sum + (item.noise_level || 0), 0)
  const totalPM25 = data.reduce((sum, item) => sum + (item.pm25 || 0), 0)
  const totalScore = data.reduce((sum, item) => sum + (item.environment_score || 0), 0)

  return {
    avg_temperature: parseFloat((totalTemp / data.length).toFixed(1)),
    avg_humidity: parseFloat((totalHumidity / data.length).toFixed(1)),
    avg_smoke_level: parseFloat((totalSmoke / data.length).toFixed(1)),
    avg_noise_level: parseFloat((totalNoise / data.length).toFixed(1)),
    avg_pm25: parseFloat((totalPM25 / data.length).toFixed(1)),
    avg_environment_score: parseFloat((totalScore / data.length).toFixed(1)),
    normal_count: data.filter(item => item.status === 'normal').length,
    warning_count: data.filter(item => item.status === 'warning').length,
    danger_count: data.filter(item => item.status === 'danger').length,
    total_rooms: data.length
  }
}

const displayList = computed(() => {
  let result = environmentList.value

  if (selectedFloor.value) {
    result = result.filter(item => item.floor_id === selectedFloor.value)
  }

  if (selectedStatus.value) {
    result = result.filter(item => item.status === selectedStatus.value)
  }

  return result
})

async function fetchData() {
  loading.value = true
  usingMockData.value = false

  try {
    const params: any = {}
    if (selectedFloor.value) params.floor_id = selectedFloor.value
    if (selectedStatus.value) params.status = selectedStatus.value

    const res: any = await environmentApi.getEnvironmentData(params)
    const data = res.data

    if (data && data.list && data.list.length > 0) {
      environmentList.value = data.list
      Object.assign(summary, data.summary)
      console.log('✅ 环境数据加载成功（来自API）')
    } else {
      throw new Error('Empty or invalid response')
    }
  } catch (err: any) {
    console.warn('⚠️ API获取失败，使用模拟数据:', err.message || err)
    useMockData()
  } finally {
    loading.value = false
  }
}

function useMockData() {
  usingMockData.value = true
  const mockData = generateMockEnvironmentData()
  environmentList.value = mockData
  Object.assign(summary, calculateMockSummary(mockData))
  console.log('📊 已加载模拟环境数据（共 ' + mockData.length + ' 个房间）')
}

function getTemperatureColor(temp: number): string {
  if (temp > 30 || temp < 18) return '#ff4d4f'
  if (temp > 28 || temp < 20) return '#faad14'
  return '#1890ff'
}

function getHumidityColor(humidity: number): string {
  if (humidity > 75 || humidity < 30) return '#ff4d4f'
  if (humidity > 70 || humidity < 35) return '#faad14'
  return '#52c41a'
}

function getSmokeColor(level: number): string {
  if (level > 60) return '#ff4d4f'
  if (level > 40) return '#faad14'
  return '#52c41a'
}

function getStatusBadge(status: string): string {
  return {
    normal: 'success',
    warning: 'warning',
    danger: 'error'
  }[status] || 'default'
}

function getStatusText(status: string): string {
  return {
    normal: '正常',
    warning: '警告',
    danger: '危险'
  }[status] || status
}

function formatTime(time: string): string {
  return time ? dayjs(time).fromNow() : '-'
}

function toggleAutoRefresh(checked: boolean) {
  if (checked) {
    refreshTimer = setInterval(fetchData, 30000)
    message.info('已开启自动刷新（每30秒）')
  } else {
    if (refreshTimer) {
      clearInterval(refreshTimer)
      refreshTimer = null
    }
    message.info('已关闭自动刷新')
  }
}

onMounted(() => {
  fetchData()
})

onUnmounted(() => {
  if (refreshTimer) {
    clearInterval(refreshTimer)
  }
})
</script>

<style scoped>
.environment-monitor { padding: 0; }

.summary-cards { margin-bottom: 16px; }

.stat-card {
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  transition: all 0.3s;
}

.stat-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.12);
}

.temp-card { border-top: 4px solid #1890ff; }
.humidity-card { border-top: 4px solid #52c41a; }
.smoke-card { border-top: 4px solid #faad14; }
.status-card { border-top: 4px solid #722ed1; }

.status-tags {
  margin-top: 8px;
  display: flex;
  gap: 4px;
  flex-wrap: wrap;
}
</style>
