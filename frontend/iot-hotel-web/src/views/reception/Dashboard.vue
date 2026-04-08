<template>
  <div class="reception-dashboard">
    <a-row :gutter="[16, 16]">
      <a-col :xs="12" :sm="6" v-for="s in stats" :key="s.key">
        <a-card size="small" :hoverable="true" class="stat-card">
          <a-statistic :title="s.title" :value="s.value" :value-style="{ color: s.color, fontSize: '24px' }">
            <template #prefix><component :is="s.icon" /></template>
          </a-statistic>
        </a-card>
      </a-col>
    </a-row>

    <a-row :gutter="[16, 16]" style="margin-top: 16px;">
      <a-col :xs="24" :lg="14">
        <a-card title="今日入住/退房" size="small">
          <a-timeline>
            <a-timeline-item color="green" v-for="(item, i) in todayEvents.slice(0, 6)" :key="i">
              <div class="event-item">
                <strong>{{ item.guest }}</strong> · {{ item.room }}
                <a-tag :color="item.type === 'checkin' ? 'success' : 'warning'" size="small">{{ item.type === 'checkin' ? '入住' : '退房' }}</a-tag>
                <span class="event-time">{{ item.time }}</span>
              </div>
            </a-timeline-item>
          </a-timeline>
        </a-card>
      </a-col>
      <a-col :xs="24" :lg="10">
        <a-card title="待处理事项" size="small">
          <a-list :data-source="pendingItems" size="small">
            <template #renderItem="{ item }">
              <a-list-item>
                <a-list-item-meta :title="item.title" :description="item.desc">
                  <template #avatar><a-badge :status="item.status" /></template>
                </a-list-item-meta>
                <a-button type="link" size="small">处理</a-button>
              </a-list-item>
            </template>
          </a-list>
        </a-card>
      </a-col>
    </a-row>

    <a-row :gutter="[16, 16]" style="margin-top: 16px;">
      <a-col :xs="24">
        <a-card title="当前在住客人" size="small">
          <a-table
            :columns="guestColumns"
            :data-source="currentGuests"
            :pagination="{ pageSize: 6 }"
            row-key="id"
            size="small"
          >
            <template #bodyCell="{ column, record }">
              <template v-if="column.key === 'stay_days'">
                {{ record.stay_days }}晚
              </template>
              <template v-if="column.key === 'action'">
                <a-space>
                  <a-button type="link" size="small">退房</a-button>
                  <a-button type="link" size="small">续住</a-button>
                </a-space>
              </template>
            </template>
          </a-table>
        </a-card>
      </a-col>
    </a-row>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import {
  UserAddOutlined, UserDeleteOutlined,
  CalendarOutlined, FileTextOutlined
} from '@ant-design/icons-vue'
import { useHotelStore } from '@/stores/hotel'

import axios from '@/api/request'
import { bookingApi } from '@/api/booking'

const hotelStore = useHotelStore()
const loading = ref(false)

const stats = ref([
  { key: 'today_checkin', title: '今日入住', value: 0, color: '#52c41a', icon: UserAddOutlined },
  { key: 'today_checkout', title: '今日退房', value: 0, color: '#faad14', icon: UserDeleteOutlined },
  { key: 'available', title: '可售房间', value: 0, color: '#1890ff', icon: CalendarOutlined },
  { key: 'pending_bills', title: '待处理工单', value: 0, color: '#ff4d4f', icon: FileTextOutlined }
])

const todayEvents = ref<any[]>([])
const pendingItems = ref<any[]>([])
const currentGuests = ref<any[]>([])

const guestColumns = [
  { title: '姓名', dataIndex: 'guest_name', width: 90 },
  { title: '房号', dataIndex: 'room_number', width: 80 },
  { title: '电话', dataIndex: 'phone', width: 130 },
  { title: '入住日期', dataIndex: 'check_in', width: 110 },
  { title: '预计退房', dataIndex: 'check_out', width: 110 },
  { title: '已住', dataIndex: 'stay_days', key: 'stay_days', width: 70 },
  { title: '操作', key: 'action', width: 140 }
]

async function fetchDashboardData() {
  loading.value = true
  try {
    // 1. 获取房态统计
    await hotelStore.fetchRooms()
    const availableCount = hotelStore.getAvailableRooms().length
    const statAvailable = stats.value.find(s => s.key === 'available')
    if (statAvailable) statAvailable.value = availableCount

    // 2. 获取今日预订/入住/退房数据
    const today = new Date().toISOString().split('T')[0]
    const resBookings: any = await bookingApi.getBookingList({ pageSize: 100 })
    const allBookings = resBookings.data?.list || []
    
    const checkins = allBookings.filter((b: any) => b.check_in_date?.startsWith(today))
    const checkouts = allBookings.filter((b: any) => b.check_out_date?.startsWith(today))
    
    stats.value.find(s => s.key === 'today_checkin')!.value = checkins.length
    stats.value.find(s => s.key === 'today_checkout')!.value = checkouts.length

    // 3. 构造今日事件时间轴
    todayEvents.value = [
      ...checkins.map((b: any) => ({ guest: b.guest_name, room: b.room_number || '未分配', type: 'checkin', time: '今日' })),
      ...checkouts.map((b: any) => ({ guest: b.guest_name, room: b.room_number || '未分配', type: 'checkout', time: '今日' }))
    ]

    // 4. 获取待处理事项 (报修和送物)
    const [resMaintenance, resDelivery] = await Promise.all([
      axios.get('/maintenance', { params: { status: 'pending' } }),
      axios.get('/delivery', { params: { status: 'pending' } })
    ])

    const maintenanceItems = (resMaintenance.data?.list || []).map((m: any) => ({
      id: m.id,
      title: `报修: ${m.room_number}房 ${m.fault_type}`,
      desc: m.fault_description,
      status: 'error',
      type: 'maintenance'
    }))

    const deliveryItems = (resDelivery.data?.list || []).map((d: any) => ({
      id: d.id,
      title: `送物: ${d.room_number}房 ${d.item_name}`,
      desc: `数量: ${d.quantity}`,
      status: 'processing',
      type: 'delivery'
    }))

    pendingItems.value = [...maintenanceItems, ...deliveryItems]
    stats.value.find(s => s.key === 'pending_bills')!.value = pendingItems.value.length

    // 5. 当前在住客人
    currentGuests.value = allBookings.filter((b: any) => b.status === 'checked_in').map((b: any) => ({
      id: b.id,
      guest_name: b.guest_name,
      room_number: b.room_number,
      phone: b.guest_phone,
      check_in: b.check_in_date?.split('T')[0],
      check_out: b.check_out_date?.split('T')[0],
      stay_days: Math.ceil((new Date().getTime() - new Date(b.check_in_date).getTime()) / (1000 * 60 * 60 * 24))
    }))

  } catch (error) {
    console.error('加载仪表盘数据失败:', error)
  } finally {
    loading.value = false
  }
}

onMounted(fetchDashboardData)
</script>

<style scoped>
.stat-card { text-align: center; }
.event-item { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
.event-time { font-size: 12px; color: rgba(0,0,0,0.35); margin-left: auto; }
</style>
