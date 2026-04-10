<template>
  <div class="energy-consumption-panel">
    <a-row :gutter="[16, 16]" style="margin-bottom: 16px;">
      <a-col :span="6">
        <a-card size="small" class="energy-stat today-stat">
          <a-statistic title="今日总能耗" :value="energySummary.total_today_kwh || 0" suffix="kWh" :value-style="{ color: '#1890ff', fontSize: '26px' }">
            <template #prefix><ThunderboltOutlined /></template>
          </a-statistic>
          <div class="compare">较昨日: <span :style="{ color: (energySummary.savings_rate || 0) >= 0 ? '#52c41a' : '#ff4d4f', fontWeight: 'bold' }">
            {{ energySummary.savings_rate >= 0 ? '+' : '' }}{{ energySummary.savings_rate || 0 }}%
          </span></div>
        </a-card>
      </a-col>
      <a-col :span="6">
        <a-card size="small" class="energy-stat month-stat">
          <a-statistic title="本月累计" :value="energySummary.total_month_kwh || 0" suffix="kWh" :value-style="{ color: '#722ed1', fontSize: '26px' }">
            <template #prefix><LineChartOutlined /></template>
          </a-statistic>
          <div class="cost">预估费用: ¥{{ energySummary.estimated_monthly_cost || 0 }}</div>
        </a-card>
      </a-col>
      <a-col :span="6">
        <a-card size="small" class="energy-stat best-stat">
          <a-statistic title="最节能房间" :value="energySummary.most_efficient_room || '-'" :value-style="{ color: '#52c41a', fontSize: '22px' }">
            <template #prefix><TrophyOutlined /></template>
          </a-statistic>
          <div class="label">今日能耗最低</div>
        </a-card>
      </a-col>
      <a-col :span="6">
        <a-card size="small" class="energy-stat worst-stat">
          <a-statistic title="高耗能房间" :value="energySummary.least_efficient_room || '-'" :value-style="{ color: '#ff4d4f', fontSize: '22px' }">
            <template #prefix><WarningOutlined /></template>
          </a-statistic>
          <div class="label">需要关注节能</div>
        </a-card>
      </a-col>
    </a-row>

    <a-alert
      v-if="(energySummary.savings_rate || 0) < -10"
      message="⚡ 能耗预警"
      description="今日能耗较昨日增长超过10%，建议检查是否有异常运行的设备或优化能源使用策略。"
      type="warning"
      show-icon
      closable
      style="margin-bottom: 16px;"
    />

    <a-card :loading="loading">
      <template #title>
        <span>⚡ 各房间能耗详情</span>
      </template>
      <template #extra>
        <a-space>
          <a-select v-model:value="selectedFloor" placeholder="楼层筛选" allowClear style="width: 100px;" @change="fetchEnergyData">
            <a-select-option value="">全部楼层</a-select-option>
            <a-select-option :value="3">3楼</a-select-option>
            <a-select-option :value="4">4楼</a-select-option>
            <a-select-option :value="5">5楼</a-select-option>
          </a-select>
          <a-button type="primary" size="small" :loading="loading" @click="fetchEnergyData"><ReloadOutlined /> 刷新</a-button>
        </a-space>
      </template>

      <a-table :dataSource="consumptionList" :columns="energyColumns" :loading="loading" rowKey="room_id" size="middle" :pagination="{ pageSize: 12 }">
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'room'">
            <a-tag color="blue">{{ record.room_number }}</a-tag>
            <br/>
            <span style="font-size: 11px; color: #999;">{{ getFloorName(record.floor_id) }}</span>
          </template>

          <template v-if="column.key === 'today'">
            <span :style="{ fontWeight: 'bold', color: record.today_kwh > 15 ? '#ff4d4f' : '#1890ff' }">{{ record.today_kwh }} kWh</span>
          </template>

          <template v-if="column.key === 'change'">
            <span :style="{ color: getChangeColor(record.today_kwh, record.yesterday_kwh), fontWeight: 'bold' }">
              {{ getChangePercent(record.today_kwh, record.yesterday_kwh) }}%
            </span>
          </template>

          <template v-if="column.key === 'efficiency'">
            <a-tag :color="getEfficiencyColor(record.efficiency_rating)" style="font-weight: bold; font-size: 14px;">
              {{ record.efficiency_rating }}
            </a-tag>
          </template>

          <template v-if="column.key === 'peak'">
            <Tooltip :title="'峰值时段: ' + record.peak_time">
              <span>{{ record.peak_usage }} kWh</span>
              <br/>
              <span style="font-size: 11px; color: #999;">{{ record.peak_time }}</span>
            </Tooltip>
          </template>

          <template v-if="column.key === 'devices'">
            <a-badge :count="record.devices_count" :number-style="{ backgroundColor: '#1890ff' }" />
          </template>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { message, Tooltip } from 'ant-design-vue'
import { ThunderboltOutlined, LineChartOutlined, TrophyOutlined, WarningOutlined, ReloadOutlined } from '@ant-design/icons-vue'
import { environmentApi, type EnergyConsumption } from '@/api/environment'

const loading = ref(false)
const consumptionList = ref<EnergyConsumption[]>([])
const energySummary = reactive({
  total_today_kwh: 0,
  total_yesterday_kwh: 0,
  total_month_kwh: 0,
  savings_rate: 0,
  estimated_monthly_cost: 0,
  most_efficient_room: '',
  least_efficient_room: ''
})

const selectedFloor = ref<number | undefined>(undefined)

const energyColumns = [
  { title: '房间', key: 'room', width: 90 },
  { title: '今日能耗', key: 'today', width: 110 },
  { title: '昨日对比', key: 'change', width: 100 },
  { title: '本月累计(kWh)', dataIndex: 'this_month_kwh', key: 'month', width: 120, sorter: (a: EnergyConsumption, b: EnergyConsumption) => a.this_month_kwh - b.this_month_kwh },
  { title: '效率等级', key: 'efficiency', width: 100 },
  { title: '峰值用量', key: 'peak', width: 120 },
  { title: '设备数', key: 'devices', width: 80 }
]

async function fetchEnergyData() {
  loading.value = true
  try {
    const res: any = await environmentApi.getEnergyConsumption({})
    const data = res.data

    if (data) {
      let list = data.consumption || []

      if (selectedFloor.value) {
        list = list.filter((item: EnergyConsumption) => item.floor_id === selectedFloor.value)
      }

      consumptionList.value = list
      Object.assign(energySummary, data.summary)
    }
  } catch (err) {
    console.error('Failed to fetch energy data:', err)
    message.error('获取能耗数据失败')
  } finally {
    loading.value = false
  }
}

function getFloorName(floorId: number): string {
  return floorId + '楼'
}

function getChangeColor(today: number, yesterday: number): string {
  if (!yesterday) return '#999'
  const change = ((today - yesterday) / yesterday) * 100
  if (change <= -5) return '#52c41a'
  if (change <= 5) return '#1890ff'
  return '#ff4d4f'
}

function getChangePercent(today: number, yesterday: number): string {
  if (!yesterday) return '-'
  const change = ((today - yesterday) / yesterday) * 100
  return (change >= 0 ? '+' : '') + change.toFixed(1)
}

function getEfficiencyColor(rating: string): string {
  return { A: 'success', B: 'processing', C: 'warning', D: 'error', F: 'error' }[rating] || 'default'
}

onMounted(() => {
  fetchEnergyData()
})
</script>

<style scoped>
.energy-stat {
  border-radius: 8px;
  text-align: center;
}
.today-stat { border-top: 3px solid #1890ff; background: #e6f7ff; }
.month-stat { border-top: 3px solid #722ed1; background: #f9f0ff; }
.best-stat { border-top: 3px solid #52c41a; background: #f6ffed; }
.worst-stat { border-top: 3px solid #ff4d4f; background: #fff1f0; }

.compare, .cost, .label {
  font-size: 12px;
  margin-top: 4px;
  color: rgba(0,0,0,0.45);
}
</style>
