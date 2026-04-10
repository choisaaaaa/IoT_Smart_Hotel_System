<template>
  <div class="global-dashboard">
    <div class="welcome-header">
      <div class="title-group">
        <h1>集团运营总览</h1>
        <p>欢迎回来，{{ appStore.userInfo?.username }}。这是智联酒店集团的全局实时运营概报。</p>
      </div>
      <a-space>
        <a-button @click="fetchStats" :loading="loading">
          <template #icon><ReloadOutlined /></template>
          刷新数据
        </a-button>
      </a-space>
    </div>

    <!-- 集团关键指标 -->
    <a-row :gutter="[16, 16]">
      <a-col :span="6">
        <a-card class="stat-card">
          <a-statistic title="运营酒店" :value="stats.hotel_count">
            <template #prefix><BankOutlined style="color: #1890ff" /></template>
            <template #suffix><span class="unit">家</span></template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :span="6">
        <a-card class="stat-card">
          <a-statistic title="集团总会员" :value="stats.member_count">
            <template #prefix><TeamOutlined style="color: #52c41a" /></template>
            <template #suffix><span class="unit">位</span></template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :span="6">
        <a-card class="stat-card">
          <a-statistic title="联网设备总数" :value="stats.device_count">
            <template #prefix><DesktopOutlined style="color: #722ed1" /></template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :span="6">
        <a-card class="stat-card">
          <a-statistic title="集团总营收 (本月)" :value="stats.total_revenue" :precision="2">
            <template #prefix><DollarOutlined style="color: #faad14" /></template>
          </a-statistic>
        </a-card>
      </a-col>
    </a-row>

    <!-- 营收趋势与排行 -->
    <a-row :gutter="[16, 16]" style="margin-top: 24px;">
      <a-col :span="16">
        <a-card title="集团营收趋势 (月度)">
          <div ref="chartRef" style="height: 350px;"></div>
        </a-card>
      </a-col>
      <a-col :span="8">
        <a-card title="酒店营收排行 (TOP 5)">
          <a-list :data-source="stats.top_hotels" size="small">
            <template #renderItem="{ item, index }">
              <a-list-item>
                <div class="rank-item">
                  <span class="rank-num" :class="'rank-' + (index + 1)">{{ index + 1 }}</span>
                  <span class="hotel-name">{{ item.hotel_name }}</span>
                  <span class="revenue">¥{{ Number(item.revenue).toLocaleString() }}</span>
                </div>
              </a-list-item>
            </template>
          </a-list>
        </a-card>
      </a-col>
    </a-row>

    <!-- 房间状态与预订状态 -->
    <a-row :gutter="[16, 16]" style="margin-top: 24px;">
      <a-col :span="12">
        <a-card title="全集团房态分布">
          <div ref="roomChartRef" style="height: 250px;"></div>
        </a-card>
      </a-col>
      <a-col :span="12">
        <a-card title="今日预订概况">
          <div ref="bookingChartRef" style="height: 250px;"></div>
        </a-card>
      </a-col>
    </a-row>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, reactive } from 'vue'
import { 
  BankOutlined, TeamOutlined, DesktopOutlined, 
  DollarOutlined, ReloadOutlined 
} from '@ant-design/icons-vue'
import { hotelApi } from '@/api/hotel'
import { useAppStore } from '@/stores/app'
import * as echarts from 'echarts'

const appStore = useAppStore()
const loading = ref(false)
const chartRef = ref<HTMLElement | null>(null)
const roomChartRef = ref<HTMLElement | null>(null)
const bookingChartRef = ref<HTMLElement | null>(null)
let myChart: any = null
let roomChart: any = null
let bookingChart: any = null

const stats = reactive({
  hotel_count: 0,
  member_count: 0,
  device_count: 0,
  total_revenue: 0,
  monthly_revenue: Array(12).fill(0),
  top_hotels: [],
  room_stats: [],
  booking_stats: []
})

const fetchStats = async () => {
  loading.value = true
  try {
    const res = await hotelApi.getStatistics()
    console.log('[GlobalDashboard] 统计数据返回:', res.data)
    if (res.data) {
      // 深度合并并确保数值类型
      stats.hotel_count = Number(res.data.hotel_count || 0)
      stats.member_count = Number(res.data.member_count || 0)
      stats.device_count = Number(res.data.device_count || 0)
      stats.total_revenue = Number(res.data.total_revenue || 0)
      
      if (Array.isArray(res.data.monthly_revenue)) {
        stats.monthly_revenue = res.data.monthly_revenue.map((v: any) => Number(v || 0))
      }
      
      stats.top_hotels = res.data.top_hotels || []
      stats.room_stats = res.data.room_stats || []
      stats.booking_stats = res.data.booking_stats || []
      
      renderCharts()
    }
  } catch (error) {
    console.error('获取统计数据失败:', error)
  } finally {
    loading.value = false
  }
}

const renderCharts = () => {
  // 营收趋势图
  if (chartRef.value) {
    if (!myChart) myChart = echarts.init(chartRef.value)
    myChart.setOption({
      tooltip: { trigger: 'axis' },
      grid: { left: '3%', right: '4%', bottom: '3%', containLabel: true },
      xAxis: { type: 'category', data: ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'] },
      yAxis: { type: 'value' },
      series: [{
        name: '营收',
        type: 'line',
        smooth: true,
        data: stats.monthly_revenue,
        areaStyle: { opacity: 0.1 },
        itemStyle: { color: '#1890ff' }
      }]
    })
  }

  // 房态分布图
  if (roomChartRef.value) {
    if (!roomChart) roomChart = echarts.init(roomChartRef.value)
    const data = (stats.room_stats || []).map((item: any) => ({
      name: getRoomStatusLabel(item.room_status),
      value: Number(item.count || 0)
    }))
    roomChart.setOption({
      tooltip: { trigger: 'item' },
      series: [{
        type: 'pie',
        radius: ['50%', '70%'],
        data: data.length > 0 ? data : [{ name: '暂无数据', value: 0 }],
        label: { show: true }
      }]
    })
  }

  // 预订概况图
  if (bookingChartRef.value) {
    if (!bookingChart) bookingChart = echarts.init(bookingChartRef.value)
    const data = (stats.booking_stats || []).map((item: any) => ({
      name: getBookingStatusLabel(item.status),
      value: Number(item.count || 0)
    }))
    bookingChart.setOption({
      tooltip: { trigger: 'item' },
      series: [{
        type: 'pie',
        radius: '70%',
        data: data.length > 0 ? data : [{ name: '暂无数据', value: 0 }],
        label: { show: true }
      }]
    })
  }
}

const getRoomStatusLabel = (status: string) => {
  const map: any = { 'available': '空闲', 'occupied': '在住', 'cleaning': '打扫中', 'maintenance': '维保中' }
  return map[status] || status
}

const getBookingStatusLabel = (status: string) => {
  const map: any = { 'pending': '待入住', 'checked_in': '已入住', 'checked_out': '已退房', 'cancelled': '已取消' }
  return map[status] || status
}

onMounted(() => {
  fetchStats()
  window.addEventListener('resize', handleResize)
})

onUnmounted(() => {
  window.removeEventListener('resize', handleResize)
})

const handleResize = () => {
  myChart?.resize()
  roomChart?.resize()
  bookingChart?.resize()
}
</script>

<style scoped>
.global-dashboard {
  padding: 0;
}
.welcome-header {
  margin-bottom: 24px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.welcome-header h1 {
  font-size: 24px;
  margin: 0;
  font-weight: 600;
}
.welcome-header p {
  color: #8c8c8c;
  margin: 4px 0 0;
}
.stat-card {
  border-radius: 8px;
  transition: all 0.3s;
}
.stat-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}
.unit {
  font-size: 14px;
  margin-left: 4px;
  color: #8c8c8c;
}
.rank-item {
  display: flex;
  align-items: center;
  width: 100%;
}
.rank-num {
  width: 20px;
  height: 20px;
  border-radius: 10px;
  background: #f0f0f0;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  margin-right: 12px;
}
.rank-1 { background: #ff4d4f; color: #fff; }
.rank-2 { background: #ffa940; color: #fff; }
.rank-3 { background: #ffec3d; color: #000; }
.hotel-name { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.revenue { font-weight: 600; color: #cf1322; }
</style>
