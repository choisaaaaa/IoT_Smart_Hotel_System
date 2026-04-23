<template>
  <div class="admin-dashboard">
    <a-row :gutter="[16, 16]">
      <a-col :xs="24" :sm="12" :md="6" v-for="stat in statsCards" :key="stat.key">
        <a-card class="stat-card" :hoverable="true">
          <a-statistic :title="stat.title" :value="stat.value" :value-style="{ color: stat.color }">
            <template #prefix><component :is="stat.icon" /></template>
            <template v-if="stat.suffix" #suffix>
              <span style="font-size: 13px; color: rgba(0,0,0,0.45);">{{ stat.suffix }}</span>
            </template>
          </a-statistic>
        </a-card>
      </a-col>
    </a-row>

    <a-row :gutter="[16, 16]" style="margin-top: 16px;">
      <a-col :xs="24" :lg="14">
        <a-card title="设备在线状态" size="small">
          <div ref="deviceChartRef" style="height: 300px;"></div>
        </a-card>
      </a-col>
      <a-col :xs="24" :lg="10">
        <a-card title="酒店基本信息" size="small">
          <a-descriptions v-if="hotelStore.hotelInfo" :column="1" bordered size="small">
            <a-descriptions-item label="酒店名称">{{ hotelStore.hotelInfo.hotel_name }}</a-descriptions-item>
            <a-descriptions-item label="星级">{{ hotelStore.hotelInfo.hotel_star }}星级</a-descriptions-item>
            <a-descriptions-item label="总房间数">{{ hotelStore.hotelInfo.total_rooms }}间</a-descriptions-item>
            <a-descriptions-item label="入住率"><a-progress :percent="Number(hotelStore.hotelInfo.occupancy_rate)" size="small" /></a-descriptions-item>
            <a-descriptions-item label="地址">{{ hotelStore.hotelInfo.hotel_address }}</a-descriptions-item>
          </a-descriptions>
          <a-empty v-else description="加载中..." />
        </a-card>
      </a-col>
    </a-row>

    <a-row :gutter="[16, 16]" style="margin-top: 16px;">
      <a-col :xs="24">
        <a-card title="房间状态一览" size="small">
          <a-table
            :columns="roomColumns"
            :data-source="hotelStore.rooms"
            :pagination="{ pageSize: 8 }"
            row-key="id"
            size="small"
            :scroll="{ x: 700 }"
          >
            <template #bodyCell="{ column, record }">
              <template v-if="column.key === 'room_status'">
                <a-tag :color="statusColor(record.room_status)">{{ statusText(record.room_status) }}</a-tag>
              </template>
              <template v-if="column.key === 'room_price'">¥{{ record.room_price }}</template>
            </template>
          </a-table>
        </a-card>
      </a-col>
    </a-row>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, nextTick } from 'vue'
import {
  HomeOutlined, UserOutlined, CheckCircleOutlined,
  WarningOutlined, DollarOutlined
} from '@ant-design/icons-vue'
import * as echarts from 'echarts'
import { useHotelStore } from '@/stores/hotel'
import { useDeviceStore } from '@/stores/device'
import { useAppStore } from '@/stores/app'
import { deviceApi } from '@/api/device'

const hotelStore = useHotelStore()
const deviceStore = useDeviceStore()
const appStore = useAppStore()
const deviceChartRef = ref<HTMLDivElement>()
let chartInstance: echarts.ECharts | null = null

const statsCards = computed(() => [
  { key: 'rooms', title: '总客房', value: hotelStore.rooms.length, color: '#1890ff', icon: HomeOutlined, suffix: '间' },
  { key: 'occupied', title: '已入住', value: hotelStore.getOccupiedRooms().length, color: '#52c41a', icon: UserOutlined, suffix: '间' },
  { key: 'online', title: '设备在线', value: deviceStore.getOnlineCount(), color: '#52c41a', icon: CheckCircleOutlined },
  { key: 'error', title: '设备异常', value: deviceStore.getErrorCount(), color: '#ff4d4f', icon: WarningOutlined }
] as Array<{key: string; title: string; value: number; color: string; icon: any; suffix?: string}>)

const roomColumns = [
  { title: '房号', dataIndex: 'room_number', width: 80 },
  { title: '房型', dataIndex: 'room_type', width: 100 },
  { title: '价格(元/晚)', dataIndex: 'room_price', width: 110 },
  { title: '状态', dataIndex: 'room_status', width: 100 },
  { title: '楼层', dataIndex: 'floor', width: 60 },
  { title: '面积(m²)', dataIndex: 'area', width: 90 }
]

function statusColor(s: string): string {
  return ({ available: 'success', occupied: 'warning', maintenance: 'error', cleaning: 'processing' } as Record<string, string>)[s] || 'default'
}
function statusText(s: string): string {
  return ({ available: '空闲', occupied: '已入住', maintenance: '维修中', cleaning: '清洁中' } as Record<string, string>)[s] || s
}

onMounted(async () => {
  await Promise.all([hotelStore.fetchHotelInfo(), hotelStore.fetchRooms()])

  // 加载设备数据到 deviceStore，确保设备在线数统计正确
  try {
    const userInfo = appStore.userInfo
    const params: any = {}
    if (userInfo?.hotel_id) {
      params.hotel_id = userInfo.hotel_id
    }
    const res: any = await deviceApi.getDeviceList(params)
    if (res && res.success && Array.isArray(res.data)) {
      deviceStore.setDevices(res.data)
    } else if (res && Array.isArray(res.data)) {
      deviceStore.setDevices(res.data)
    } else if (Array.isArray(res)) {
      deviceStore.setDevices(res)
    }
  } catch (err) {
    console.error('Dashboard 加载设备数据失败:', err)
  }

  await nextTick()
  if (deviceChartRef.value) {
    chartInstance = echarts.init(deviceChartRef.value)
    const online = deviceStore.getOnlineCount()
    const offline = deviceStore.getOfflineCount()
    const error = deviceStore.getErrorCount()
    chartInstance.setOption({
      tooltip: { trigger: 'item', formatter: '{b}: {c}台 ({d}%)' },
      legend: { bottom: 0 },
      series: [{
        type: 'pie',
        radius: ['40%', '68%'],
        center: ['50%', '45%'],
        avoidLabelOverlap: true,
        itemStyle: { borderRadius: 8, borderColor: '#fff', borderWidth: 2 },
        label: { show: true, formatter: '{b}\n{c}台' },
        data: [
          { value: online, name: '在线', itemStyle: { color: '#52c41a' } },
          { value: offline, name: '离线', itemStyle: { color: '#999' } },
          { value: error, name: '异常', itemStyle: { color: '#ff4d4f' } }
        ]
      }]
    })
    window.addEventListener('resize', () => chartInstance?.resize())
  }
})
</script>

<style scoped>
.stat-card { text-align: center; transition: transform .2s; }
.stat-card:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(0,0,0,.1); }
</style>