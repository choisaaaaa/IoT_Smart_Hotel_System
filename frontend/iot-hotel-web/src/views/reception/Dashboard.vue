<template>
  <div class="reception-dashboard">
    <!-- 页面标题 -->
    <div class="dashboard-header">
      <div class="header-title">
        <DashboardOutlined class="title-icon" />
        <h1>前台总览</h1>
      </div>
      <div class="header-date">
        <CalendarOutlined />
        <span>{{ currentDate }}</span>
      </div>
    </div>

    <!-- 统计卡片 -->
    <a-row :gutter="24" class="stats-row">
      <a-col :xs="24" :sm="12" :lg="6">
        <div class="stat-card">
          <div class="stat-icon checkin">
            <LoginOutlined />
          </div>
          <div class="stat-info">
            <div class="stat-label">今日入住</div>
            <div class="stat-value">{{ stats.todayCheckin }}</div>
          </div>
        </div>
      </a-col>
      <a-col :xs="24" :sm="12" :lg="6">
        <div class="stat-card">
          <div class="stat-icon checkout">
            <LogoutOutlined />
          </div>
          <div class="stat-info">
            <div class="stat-label">今日退房</div>
            <div class="stat-value">{{ stats.todayCheckout }}</div>
          </div>
        </div>
      </a-col>
      <a-col :xs="24" :sm="12" :lg="6">
        <div class="stat-card">
          <div class="stat-icon occupied">
            <HomeOutlined />
          </div>
          <div class="stat-info">
            <div class="stat-label">当前入住</div>
            <div class="stat-value">{{ stats.currentOccupancy }}</div>
          </div>
        </div>
      </a-col>
      <a-col :xs="24" :sm="12" :lg="6">
        <div class="stat-card">
          <div class="stat-icon occupancy">
            <PieChartOutlined />
          </div>
          <div class="stat-info">
            <div class="stat-label">入住率</div>
            <div class="stat-value">{{ stats.occupancyRate }}%</div>
          </div>
        </div>
      </a-col>
    </a-row>

    <!-- 快捷操作 -->
    <div class="quick-actions-section">
      <div class="section-title">
        <ThunderboltOutlined class="section-icon" />
        <span>快捷操作</span>
      </div>
      <div class="actions-grid">
        <div class="action-card" @click="$router.push('/reception/bookings')">
          <a-badge :count="notificationStore.moduleUnreadCounts['/reception/bookings']" :offset="[-10, 10]">
            <div class="action-icon booking">
              <CalendarOutlined />
            </div>
          </a-badge>
          <div class="action-name">预订管理</div>
          <div class="action-desc">查看和处理预订</div>
        </div>
        <div class="action-card" @click="$router.push('/reception/reception-center')">
          <a-badge :count="notificationStore.moduleUnreadCounts['/reception/reception-center']" :offset="[-10, 10]">
            <div class="action-icon checkin">
              <IdcardOutlined />
            </div>
          </a-badge>
          <div class="action-name">接待中心</div>
          <div class="action-desc">办理入住与退房</div>
        </div>
        <div class="action-card" @click="$router.push('/reception/workorders')">
          <a-badge :count="notificationStore.moduleUnreadCounts['/reception/workorders']" :offset="[-10, 10]">
            <div class="action-icon checkout">
              <ToolOutlined />
            </div>
          </a-badge>
          <div class="action-name">工单处理</div>
          <div class="action-desc">维修与打扫任务</div>
        </div>
        <div class="action-card" @click="$router.push('/reception/delivery')">
          <a-badge :count="notificationStore.moduleUnreadCounts['/reception/delivery']" :offset="[-10, 10]">
            <div class="action-icon rooms">
              <SendOutlined />
            </div>
          </a-badge>
          <div class="action-name">送物服务</div>
          <div class="action-desc">处理客房送物请求</div>
        </div>
      </div>
    </div>

    <!-- 待处理事项 -->
    <a-row :gutter="24" class="tasks-row">
      <a-col :xs="24" :lg="12">
        <div class="task-card">
          <div class="task-header">
            <div class="task-title">
              <ToolOutlined class="task-icon" />
              <span>待处理工单</span>
              <a-badge :count="notificationStore.moduleUnreadCounts['/reception/workorders']" :offset="[5, -2]" />
            </div>
            <a-button type="link" @click="$router.push('/reception/workorders')">
              查看全部 <RightOutlined />
            </a-button>
          </div>
          <div class="task-list">
            <div v-if="pendingWorkorders.length === 0" class="task-empty">
              <CheckCircleOutlined class="empty-icon" />
              <p>暂无待处理工单</p>
            </div>
            <div 
              v-for="item in pendingWorkorders.slice(0, 5)" 
              :key="item.id" 
              class="task-item"
              @click="$router.push('/reception/workorders')"
            >
              <div class="task-badge" :class="item.priority">
                {{ getPriorityText(item.priority) }}
              </div>
              <div class="task-content">
                <div class="task-name">{{ item.fault_description?.substring(0, 30) || '维修工单' }}</div>
                <div class="task-meta">
                  <span><HomeOutlined /> {{ item.room_number || item.room_id }}</span>
                  <span><ClockCircleOutlined /> {{ formatTimeHHmm(item.created_at) }}</span>
                </div>
              </div>
              <RightOutlined class="task-arrow" />
            </div>
          </div>
        </div>
      </a-col>

      <a-col :xs="24" :lg="12">
        <div class="task-card">
          <div class="task-header">
            <div class="task-title">
              <SendOutlined class="task-icon" />
              <span>待配送订单</span>
              <a-badge :count="notificationStore.moduleUnreadCounts['/reception/delivery']" :offset="[5, -2]" />
            </div>
            <a-button type="link" @click="$router.push('/reception/delivery')">
              查看全部 <RightOutlined />
            </a-button>
          </div>
          <div class="task-list">
            <div v-if="pendingDeliveries.length === 0" class="task-empty">
              <CheckCircleOutlined class="empty-icon" />
              <p>暂无待配送订单</p>
            </div>
            <div 
              v-for="item in pendingDeliveries.slice(0, 5)" 
              :key="item.id" 
              class="task-item"
              @click="$router.push('/reception/delivery')"
            >
              <div class="task-badge pending">
                待处理
              </div>
              <div class="task-content">
                <div class="task-name">{{ item.item_name }} x{{ item.quantity }}</div>
                <div class="task-meta">
                  <span><HomeOutlined /> {{ item.room_number || item.room_id }}</span>
                  <span><ClockCircleOutlined /> {{ formatTimeHHmm(item.created_at) }}</span>
                </div>
              </div>
              <RightOutlined class="task-arrow" />
            </div>
          </div>
        </div>
      </a-col>
    </a-row>

    <!-- 今日预订 -->
    <div class="booking-section">
      <div class="section-title">
        <CalendarOutlined class="section-icon" />
        <span>今日预订</span>
      </div>
      <a-table 
        :dataSource="todayBookings" 
        :columns="bookingColumns" 
        :loading="loading" 
        :pagination="{ pageSize: 5 }"
        size="middle"
        class="booking-table"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'status'">
            <a-tag :color="getBookingStatusColor(record.status)">
              {{ getBookingStatusText(record.status) }}
            </a-tag>
          </template>
          <template v-if="column.key === 'action'">
            <a-button 
              v-if="record.status === 'confirmed'" 
              type="primary" 
              size="small"
              @click="handleCheckin(record)"
            >
              办理入住
            </a-button>
            <a-button 
              v-else-if="record.status === 'checked_in'" 
              type="link" 
              size="small"
              @click="handleCheckout(record)"
            >
              退房
            </a-button>
            <span v-else>-</span>
          </template>
        </template>
      </a-table>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useNotificationStore } from '@/stores/notification'

import dayjs from 'dayjs'
import {
  DashboardOutlined,
  CalendarOutlined,
  LoginOutlined,
  LogoutOutlined,
  HomeOutlined,
  PieChartOutlined,
  ThunderboltOutlined,
  IdcardOutlined,
  ToolOutlined,
  SendOutlined,
  RightOutlined,
  CheckCircleOutlined,
  ClockCircleOutlined
} from '@ant-design/icons-vue'
import { bookingApi } from '@/api/booking'
import { maintenanceApi } from '@/api/maintenance'
import { deliveryApi } from '@/api/delivery'
import { hotelApi } from '@/api/hotel'
import { formatTimeHHmm, formatDateWeekdayCN, formatDate, now } from '@/utils/date'

const router = useRouter()
const notificationStore = useNotificationStore()

const loading = ref(false)
const currentDate = computed(() => formatDateWeekdayCN(now()))

const stats = ref({
  todayCheckin: 0,
  todayCheckout: 0,
  currentOccupancy: 0,
  occupancyRate: 0
})

const pendingWorkorders = ref<any[]>([])
const pendingDeliveries = ref<any[]>([])
const todayBookings = ref<any[]>([])

const bookingColumns = [
  { title: '预订号', dataIndex: 'booking_no', key: 'booking_no', width: 140 },
  { title: '客人姓名', dataIndex: 'guest_name', key: 'guest_name' },
  { title: '房间号', dataIndex: 'room_number', key: 'room_number', width: 100 },
  { title: '入住日期', dataIndex: 'checkin_date', key: 'checkin_date', width: 120 },
  { title: '退房日期', dataIndex: 'checkout_date', key: 'checkout_date', width: 120 },
  { title: '状态', key: 'status', width: 100 },
  { title: '操作', key: 'action', width: 120 }
]

onMounted(async () => {
  await loadDashboardData()
})

async function loadDashboardData() {
  loading.value = true
  try {
    // 加载统计数据
    await loadStats()
    // 加载待处理工单
    await loadPendingWorkorders()
    // 加载待配送订单
    await loadPendingDeliveries()
    // 加载今日预订
    await loadTodayBookings()
  } catch (error) {
    console.error('加载数据失败:', error)
  } finally {
    loading.value = false
  }
}

async function loadStats() {
  try {
    const today = formatDate(now())
    
    // 获取酒店统计数据
    const statsRes: any = await hotelApi.getStatistics()
    const hotelStats = statsRes?.data || {}
    
    // 从 rooms 数组中提取房间统计信息
    const rooms = hotelStats.rooms || []
    const totalRooms = rooms.reduce((sum: number, r: any) => sum + (r.count || 0), 0)
    const occupiedRooms = rooms.find((r: any) => r.room_status === 'occupied')?.count || 0
    
    // 获取今日预订统计 - 使用正确的参数名 checkin_date
    const bookingRes: any = await bookingApi.getBookingList({ 
      checkin_date: today,
      pageSize: 1000 
    })
    const bookings = bookingRes.data?.list || []
    
    // 更准确的统计逻辑
    const todayCheckin = bookings.filter((b: any) => ['checked_in', 'confirmed', 'pre_checked_in'].includes(b.status)).length
    const todayCheckout = bookings.filter((b: any) => b.status === 'checked_out' && b.check_out_date?.startsWith(today)).length
    
    const occupancyRate = totalRooms > 0 ? Math.round((occupiedRooms / totalRooms) * 100) : 0
    
    stats.value = {
      todayCheckin,
      todayCheckout,
      currentOccupancy: occupiedRooms,
      occupancyRate
    }
  } catch (error) {
    console.error('加载统计数据失败:', error)
  }
}

async function loadPendingWorkorders() {
  try {
    const res: any = await maintenanceApi.getList({ 
      status: 'pending',
      pageSize: 10 
    })
    pendingWorkorders.value = res.data?.list || []
  } catch (error) {
    console.error('加载工单失败:', error)
  }
}

async function loadPendingDeliveries() {
  try {
    const res: any = await deliveryApi.getList({ 
      status: 'pending',
      pageSize: 10 
    })
    pendingDeliveries.value = res.data?.list || []
  } catch (error) {
    console.error('加载配送订单失败:', error)
  }
}

async function loadTodayBookings() {
  try {
    const today = formatDate(now())
    const res: any = await bookingApi.getBookingList({ 
      pageSize: 1000 
    })
    const allList = res.data?.list || []
    
    // 过滤出今日需要处理的预订：今天入住且状态为待处理/已确认/预入住
    todayBookings.value = allList.filter((item: any) => {
      const isTodayCheckin = dayjs(item.check_in_date).isSame(today, 'day')
      const isPendingCheckin = ['pending', 'confirmed', 'pre_checked_in'].includes(item.status)
      return isTodayCheckin && isPendingCheckin
    })
  } catch (error) {
    console.error('加载预订失败:', error)
  }
}

function getPriorityText(priority: string) {
  const map: Record<string, string> = {
    low: '低',
    medium: '中',
    high: '高',
    urgent: '紧急'
  }
  return map[priority] || priority
}

function getBookingStatusColor(status: string) {
  const map: Record<string, string> = {
    pending: 'warning',
    confirmed: 'processing',
    checked_in: 'success',
    checked_out: 'default',
    cancelled: 'error'
  }
  return map[status] || 'default'
}

function getBookingStatusText(status: string) {
  const map: Record<string, string> = {
    pending: '待确认',
    confirmed: '已确认',
    checked_in: '已入住',
    checked_out: '已退房',
    cancelled: '已取消'
  }
  return map[status] || status
}

function handleCheckin(record: any) {
  router.push(`/reception/checkin?booking_id=${record.id}`)
}

function handleCheckout(record: any) {
  router.push(`/reception/checkout?booking_id=${record.id}`)
}
</script>

<style scoped>
.reception-dashboard {
  padding: 0;
}

.dashboard-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
}

.header-title {
  display: flex;
  align-items: center;
  gap: 12px;
}

.title-icon {
  width: 48px;
  height: 48px;
  background: linear-gradient(135deg, var(--hotel-primary) 0%, var(--hotel-primary-light) 100%);
  border-radius: var(--hotel-radius);
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-size: 24px;
}

.header-title h1 {
  font-size: 24px;
  font-weight: 600;
  color: var(--hotel-primary);
  margin: 0;
}

.header-date {
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--hotel-text-muted);
  font-size: 14px;
  padding: 8px 16px;
  background: var(--hotel-bg-secondary);
  border-radius: 20px;
}

/* 统计卡片 */
.stats-row {
  margin-bottom: 24px;
}

.stat-card {
  background: #fff;
  border-radius: var(--hotel-radius);
  padding: 20px;
  display: flex;
  align-items: center;
  gap: 16px;
  box-shadow: var(--hotel-shadow-sm);
  transition: all 0.3s;
}

.stat-card:hover {
  box-shadow: var(--hotel-shadow);
  transform: translateY(-2px);
}

.stat-icon {
  width: 56px;
  height: 56px;
  border-radius: var(--hotel-radius);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 28px;
}

.stat-icon.checkin {
  background: rgba(39, 174, 96, 0.1);
  color: var(--hotel-success);
}

.stat-icon.checkout {
  background: rgba(243, 156, 18, 0.1);
  color: var(--hotel-warning);
}

.stat-icon.occupied {
  background: rgba(52, 152, 219, 0.1);
  color: var(--hotel-info);
}

.stat-icon.occupancy {
  background: rgba(201, 169, 98, 0.1);
  color: var(--hotel-gold);
}

.stat-info {
  flex: 1;
}

.stat-label {
  font-size: 13px;
  color: var(--hotel-text-muted);
  margin-bottom: 4px;
}

.stat-value {
  font-size: 28px;
  font-weight: 700;
  color: var(--hotel-primary);
}

/* 快捷操作 */
.quick-actions-section {
  margin-bottom: 24px;
}

.section-title {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 18px;
  font-weight: 600;
  color: var(--hotel-primary);
  margin-bottom: 16px;
}

.section-icon {
  font-size: 20px;
  color: var(--hotel-gold);
}

.actions-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
}

.action-card {
  background: #fff;
  border-radius: var(--hotel-radius);
  padding: 24px;
  text-align: center;
  cursor: pointer;
  transition: all 0.3s;
  box-shadow: var(--hotel-shadow-sm);
}

.action-card:hover {
  box-shadow: var(--hotel-shadow);
  transform: translateY(-4px);
}

.action-icon {
  width: 64px;
  height: 64px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 28px;
  margin: 0 auto 16px;
}

.action-icon.booking {
  background: rgba(52, 152, 219, 0.1);
  color: var(--hotel-info);
}

.action-icon.checkin {
  background: rgba(39, 174, 96, 0.1);
  color: var(--hotel-success);
}

.action-icon.checkout {
  background: rgba(231, 76, 60, 0.1);
  color: var(--hotel-error);
}

.action-icon.rooms {
  background: rgba(201, 169, 98, 0.1);
  color: var(--hotel-gold);
}

.action-name {
  font-size: 16px;
  font-weight: 600;
  color: var(--hotel-text);
  margin-bottom: 4px;
}

.action-desc {
  font-size: 12px;
  color: var(--hotel-text-muted);
}

/* 待处理事项 */
.tasks-row {
  margin-bottom: 24px;
}

.task-card {
  background: #fff;
  border-radius: var(--hotel-radius);
  box-shadow: var(--hotel-shadow-sm);
  overflow: hidden;
}

.task-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 20px;
  border-bottom: 1px solid var(--hotel-border);
}

.task-title {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 16px;
  font-weight: 600;
  color: var(--hotel-primary);
}

.task-icon {
  font-size: 18px;
  color: var(--hotel-gold);
}

.task-list {
  padding: 8px;
}

.task-empty {
  text-align: center;
  padding: 40px 20px;
  color: var(--hotel-text-muted);
}

.empty-icon {
  font-size: 48px;
  color: var(--hotel-border);
  margin-bottom: 12px;
}

.task-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px;
  border-radius: var(--hotel-radius-sm);
  cursor: pointer;
  transition: all 0.3s;
}

.task-item:hover {
  background: var(--hotel-bg-secondary);
}

.task-badge {
  padding: 4px 10px;
  border-radius: 4px;
  font-size: 12px;
  font-weight: 500;
}

.task-badge.low {
  background: rgba(39, 174, 96, 0.1);
  color: var(--hotel-success);
}

.task-badge.medium {
  background: rgba(243, 156, 18, 0.1);
  color: var(--hotel-warning);
}

.task-badge.high {
  background: rgba(231, 76, 60, 0.1);
  color: var(--hotel-error);
}

.task-badge.urgent {
  background: rgba(231, 76, 60, 0.2);
  color: var(--hotel-error);
}

.task-badge.pending {
  background: rgba(52, 152, 219, 0.1);
  color: var(--hotel-info);
}

.task-content {
  flex: 1;
  min-width: 0;
}

.task-name {
  font-size: 14px;
  font-weight: 500;
  color: var(--hotel-text);
  margin-bottom: 4px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.task-meta {
  display: flex;
  gap: 16px;
  font-size: 12px;
  color: var(--hotel-text-muted);
}

.task-meta span {
  display: flex;
  align-items: center;
  gap: 4px;
}

.task-arrow {
  color: var(--hotel-text-muted);
  font-size: 12px;
}

/* 今日预订 */
.booking-section {
  background: #fff;
  border-radius: var(--hotel-radius);
  padding: 20px;
  box-shadow: var(--hotel-shadow-sm);
}

.booking-table :deep(.ant-table-thead > tr > th) {
  background: var(--hotel-bg-secondary);
  color: var(--hotel-primary);
  font-weight: 600;
}

/* 响应式 */
@media (max-width: 1200px) {
  .actions-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (max-width: 768px) {
  .dashboard-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 12px;
  }
  
  .actions-grid {
    grid-template-columns: 1fr;
  }
  
  .task-meta {
    flex-direction: column;
    gap: 4px;
  }
}
</style>
