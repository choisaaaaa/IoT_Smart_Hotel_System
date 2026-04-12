<template>
  <div class="environment-data-panel">
    <a-row :gutter="[16, 16]" class="summary-cards">
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card temp-card" size="small">
          <a-statistic title="平均温度" :value="summary.avg_temperature" suffix="°C" :value-style="{ color: '#1890ff', fontSize: '22px' }">
            <template #prefix><FireOutlined /></template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card humidity-card" size="small">
          <a-statistic title="平均湿度" :value="summary.avg_humidity" suffix="%" :value-style="{ color: '#52c41a', fontSize: '22px' }">
            <template #prefix><CloudOutlined /></template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card smoke-card" size="small">
          <a-statistic title="烟雾浓度" :value="summary.avg_smoke_level" suffix="%" :value-style="{ color: '#faad14', fontSize: '22px' }">
            <template #prefix><AlertOutlined /></template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card score-card" size="small">
          <a-statistic title="环境评分" :value="summary.avg_environment_score" suffix="分" :value-style="{ color: getScoreColor(summary.avg_environment_score), fontSize: '22px' }">
            <template #prefix><TrophyOutlined /></template>
          </a-statistic>
        </a-card>
      </a-col>
    </a-row>

    <a-card style="margin-top: 16px;" :loading="loading">
      <template #title>
        <span>🌡️ 实时环境数据</span>
      </template>
      <template #extra>
        <a-space>
          <a-select v-model:value="selectedFloor" placeholder="楼层" allowClear style="width: 100px;" @change="fetchData">
            <a-select-option value="">全部</a-select-option>
            <a-select-option :value="3">3楼</a-select-option>
            <a-select-option :value="4">4楼</a-select-option>
            <a-select-option :value="5">5楼</a-select-option>
          </a-select>
          <a-button type="primary" size="small" :loading="loading" @click="fetchData"><ReloadOutlined /> 刷新</a-button>
        </a-space>
      </template>

      <a-table :dataSource="environmentList" :columns="columns" :loading="loading" rowKey="room_id" size="small" :pagination="{ pageSize: 10 }" :scroll="{ x: 1000 }">
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'room_number'">
            <a-tag color="blue">{{ record.room_number }}</a-tag>
          </template>

          <template v-if="column.key === 'temperature'">
            <a-progress :percent="(record.temperature / 40) * 100" :stroke-color="getTempColor(record.temperature)" size="small" :format="() => `${record.temperature}°C`" />
          </template>

          <template v-if="column.key === 'humidity'">
            <a-progress :percent="record.humidity" :stroke-color="getHumidityColor(record.humidity)" size="small" :format="() => `${record.humidity}%`" />
          </template>

          <template v-if="column.key === 'pm25'">
            <a-tag :color="record.pm25 <= 35 ? 'green' : record.pm25 <= 75 ? 'orange' : 'red'">{{ record.pm25 }} μg/m³</a-tag>
          </template>

          <template v-if="column.key === 'status'">
            <a-badge :status="getStatusBadge(record.status)" :text="getStatusText(record.status)" />
          </template>

          <template v-if="column.key === 'score'">
            <a-rate :value="Math.ceil(record.environment_score / 20)" disabled :count="5" style="font-size: 12px;" />
            <span style="margin-left: 8px; font-weight: bold;" :style="{ color: getScoreColor(record.environment_score) }">{{ record.environment_score }}</span>
          </template>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { message } from 'ant-design-vue'
import { FireOutlined, CloudOutlined, AlertOutlined, TrophyOutlined, ReloadOutlined } from '@ant-design/icons-vue'
import { environmentApi, type EnvironmentData, type EnvironmentSummary } from '@/api/environment'

const loading = ref(false)
const environmentList = ref<EnvironmentData[]>([])
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

const columns = [
  { title: '房间', key: 'room_number', width: 80 },
  { title: '温度(°C)', dataIndex: 'temperature', key: 'temperature', width: 120, sorter: (a: EnvironmentData, b: EnvironmentData) => a.temperature - b.temperature },
  { title: '湿度(%)', dataIndex: 'humidity', key: 'humidity', width: 110, sorter: (a: EnvironmentData, b: EnvironmentData) => a.humidity - b.humidity },
  { title: '烟雾(%)', dataIndex: 'smoke_level', key: 'smoke_level', width: 100 },
  { title: 'PM2.5', dataIndex: 'pm25', key: 'pm25', width: 100 },
  { title: '噪音(dB)', dataIndex: 'noise_level', key: 'noise_level', width: 90 },
  { title: '状态', key: 'status', width: 80 },
  { title: '评分', key: 'score', width: 140 }
]

async function fetchData() {
  loading.value = true
  try {
    const params: any = {}
    if (selectedFloor.value) params.floor_id = selectedFloor.value

    const res: any = await environmentApi.getEnvironmentData(params)
    const data = res.data

    if (data) {
      environmentList.value = data.list || []
      Object.assign(summary, data.summary)
    }
  } catch (err) {
  } finally {
    loading.value = false
  }
}

function getTempColor(temp: number): string {
  if (temp > 30 || temp < 18) return '#ff4d4f'
  if (temp > 28 || temp < 20) return '#faad14'
  return '#52c41a'
}

function getHumidityColor(humidity: number): string {
  if (humidity > 75 || humidity < 30) return '#ff4d4f'
  if (humidity > 70 || humidity < 35) return '#faad14'
  return '#52c41a'
}

function getStatusBadge(status: string): string {
  return { normal: 'success', warning: 'warning', danger: 'error' }[status] || 'default'
}

function getStatusText(status: string): string {
  return { normal: '正常', warning: '警告', danger: '危险' }[status] || status
}

function getScoreColor(score: number): string {
  if (score >= 90) return '#52c41a'
  if (score >= 70) return '#1890ff'
  if (score >= 50) return '#faad14'
  return '#ff4d4f'
}

onMounted(() => {
  fetchData()
})
</script>

<style scoped>
.stat-card { border-radius: 8px; box-shadow: 0 2px 6px rgba(0,0,0,0.06); }
.temp-card { border-top: 3px solid #1890ff; }
.humidity-card { border-top: 3px solid #52c41a; }
.smoke-card { border-top: 3px solid #faad14; }
.score-card { border-top: 3px solid #722ed1; }
</style>
