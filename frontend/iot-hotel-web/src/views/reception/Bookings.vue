<template>
  <div class="reception-bookings">
    <div class="toolbar">
      <a-space>
        <a-input-search v-model:value="searchKey" placeholder="搜索预订号/客人名" style="width: 240px;" allow-clear @search="fetchBookings" />
        <a-select v-model:value="filterStatus" placeholder="状态筛选" allow-clear style="width: 140px;" @change="fetchBookings">
          <a-select-option value="pending">待确认</a-select-option>
          <a-select-option value="confirmed">已支付</a-select-option>
          <a-select-option value="pre_checked_in">预入住</a-select-option>
          <a-select-option value="checked_in">已入住</a-select-option>
          <a-select-option value="checked_out">已退房</a-select-option>
          <a-select-option value="cancelled">已取消</a-select-option>
        </a-select>
      </a-space>
      <a-button type="primary" @click="showCreateModal"><PlusOutlined /> 新建预订</a-button>
    </div>

    <a-tabs v-model:activeKey="activeTab" @change="fetchBookings">
      <a-tab-pane key="today" tab="今日预订" />
      <a-tab-pane key="history" tab="历史预订" />
    </a-tabs>

    <a-table
      :columns="columns"
      :data-source="bookings"
      :loading="loading"
      :pagination="{ pageSize: 10 }"
      row-key="id"
      size="middle"
    >
      <template #bodyCell="{ column, record }">
        <template v-if="column.key === 'status'">
          <a-tag :color="statusColor(record.status)">{{ statusText(record.status) }}</a-tag>
        </template>
        <template v-if="column.key === 'total_price'">
          <span style="font-weight: 600;">¥{{ record.total_price }}</span>
        </template>
        <template v-if="column.key === 'action'">
          <a-space>
            <a-button type="link" size="small" @click="viewDetail(record)">详情</a-button>
            <a-dropdown v-if="['pending', 'confirmed', 'pre_checked_in', 'checked_in'].includes(record.status)">
              <a-button type="link" size="small">操作 <DownOutlined /></a-button>
              <template #overlay>
                <a-menu>
                  <a-menu-item v-if="record.status === 'pending'" @click="handleConfirm(record.id)">确认预订</a-menu-item>
                  <a-menu-item v-if="record.status === 'checked_in'" @click="handleCheckout(record.id)">办理退房</a-menu-item>
                  <a-menu-item danger v-if="['pending', 'confirmed', 'pre_checked_in'].includes(record.status)" @click="handleCancel(record.id)">取消预订</a-menu-item>
                </a-menu>
              </template>
            </a-dropdown>
          </a-space>
        </template>
      </template>
    </a-table>

    <a-modal v-model:open="modalVisible" title="新建预订" @ok="handleCreateBooking" width="600px">
      <a-form :model="newBooking" layout="vertical">
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="客人姓名" required><a-input v-model:value="newBooking.guest_name" /></a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="联系电话" required><a-input v-model:value="newBooking.guest_phone" /></a-form-item>
          </a-col>
        </a-row>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="入住日期"><a-date-picker v-model:value="newBooking.check_in_date" style="width: 100%;" /></a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="退房日期"><a-date-picker v-model:value="newBooking.check_out_date" style="width: 100%;" /></a-form-item>
          </a-col>
        </a-row>
        <a-form-item label="分配房间" required>
          <a-select v-model:value="newBooking.room_id" placeholder="选择房间">
            <a-select-option v-for="r in hotelStore.getAvailableRooms()" :key="r.id" :value="r.id">
              {{ r.room_number }} - {{ r.room_name }} (¥{{ r.room_price }})
            </a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item label="备注"><a-textarea v-model:value="newBooking.special_requests" :rows="2" /></a-form-item>
      </a-form>
    </a-modal>

    <!-- 订单详情弹窗 -->
    <a-modal
      v-model:open="detailVisible"
      title="订单详情"
      :footer="null"
      width="700px"
    >
      <div v-if="currentBooking" class="booking-detail-content">
        <a-descriptions title="基本信息" bordered :column="2" size="small">
          <a-descriptions-item label="预订号">{{ currentBooking.booking_number }}</a-descriptions-item>
          <a-descriptions-item label="状态">
            <a-tag :color="statusColor(currentBooking.status)">{{ statusText(currentBooking.status) }}</a-tag>
          </a-descriptions-item>
          <a-descriptions-item label="客人姓名">{{ currentBooking.guest_name }}</a-descriptions-item>
          <a-descriptions-item label="联系电话">{{ currentBooking.guest_phone }}</a-descriptions-item>
          <a-descriptions-item label="证件号码">{{ currentBooking.guest_id_number || '-' }}</a-descriptions-item>
          <a-descriptions-item label="入住人数">{{ currentBooking.guest_count }}人</a-descriptions-item>
        </a-descriptions>

        <a-descriptions title="入住信息" bordered :column="2" size="small" style="margin-top: 20px;">
          <a-descriptions-item label="房型">{{ currentBooking.room_type_name || currentBooking.room_type || '-' }}</a-descriptions-item>
          <a-descriptions-item label="分配房号">{{ currentBooking.room_number || '未分配' }}</a-descriptions-item>
          <a-descriptions-item label="实际入住">{{ currentBooking.check_in_time ? formatDateTime(currentBooking.check_in_time) : '-' }}</a-descriptions-item>
          <a-descriptions-item label="实际退房">{{ currentBooking.check_out_time ? formatDateTime(currentBooking.check_out_time) : '-' }}</a-descriptions-item>
          <a-descriptions-item label="预订入住">{{ formatDateTime(currentBooking.check_in_date) }}</a-descriptions-item>
          <a-descriptions-item label="预订退房">{{ formatDateTime(currentBooking.check_out_date) }}</a-descriptions-item>
        </a-descriptions>

        <a-descriptions title="费用与支付" bordered :column="2" size="small" style="margin-top: 20px;">
          <a-descriptions-item label="房型基准价">¥{{ currentBooking.room_type_base_price || '-' }}</a-descriptions-item>
          <a-descriptions-item label="选定方案">{{ currentBooking.plan_name || '标准价' }}</a-descriptions-item>
          <a-descriptions-item label="方案挂牌价">¥{{ currentBooking.plan_base_price || currentBooking.room_type_base_price || '-' }}</a-descriptions-item>
          <a-descriptions-item label="支付方式">{{ currentBooking.payment_method === 'balance' ? '余额支付' : '到店支付' }}</a-descriptions-item>
          
          <a-descriptions-item label="总金额" :span="2">
            <span style="color: #f5222d; font-weight: bold; font-size: 18px;">¥{{ currentBooking.total_price }}</span>
          </a-descriptions-item>

          <a-descriptions-item label="优惠详情" :span="2">
            <a-space direction="vertical" size="small">
              <div v-if="currentBooking.coupon_name">
                <a-tag color="orange">优惠券</a-tag> {{ currentBooking.coupon_name }}
              </div>
              <div v-if="currentBooking.points_discount > 0">
                <a-tag color="gold">积分抵扣</a-tag> ¥{{ currentBooking.points_discount }} (使用 {{ currentBooking.used_points }} 积分)
              </div>
              <div v-if="currentBooking.manual_discount < 1">
                <a-tag color="blue">手动折扣</a-tag> {{ (currentBooking.manual_discount * 10).toFixed(1) }}折
              </div>
              <div v-if="currentBooking.manual_reduce > 0">
                <a-tag color="red">手动立减</a-tag> ¥{{ currentBooking.manual_reduce }}
              </div>
              <div v-if="!currentBooking.coupon_name && !(currentBooking.points_discount > 0) && currentBooking.manual_discount >= 1 && !(currentBooking.manual_reduce > 0)">
                无优惠
              </div>
            </a-space>
          </a-descriptions-item>
        </a-descriptions>

        <a-descriptions title="其他" bordered :column="1" size="small" style="margin-top: 20px;">
          <a-descriptions-item label="特别要求">{{ currentBooking.special_requests || '无' }}</a-descriptions-item>
          <a-descriptions-item label="下单时间">{{ formatDateTime(currentBooking.created_at) }}</a-descriptions-item>
        </a-descriptions>

        <div class="detail-actions" style="margin-top: 30px; text-align: right;">
          <a-space>
            <a-button @click="detailVisible = false">关闭</a-button>
            <a-button v-if="currentBooking.status === 'pending'" type="primary" @click="handleConfirm(currentBooking.id)">确认订单</a-button>
          </a-space>
        </div>
      </div>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { message } from 'ant-design-vue'
import { PlusOutlined, DownOutlined } from '@ant-design/icons-vue'
import dayjs from 'dayjs'
import { formatDateTime } from '@/utils/date'
import { bookingApi } from '@/api/booking'
import { useRouter } from 'vue-router'
import { useHotelStore } from '@/stores/hotel'

const router = useRouter()
const hotelStore = useHotelStore()
const loading = ref(false)
const searchKey = ref('')
const filterStatus = ref<string | undefined>()
const activeTab = ref('today')
const modalVisible = ref(false)
const detailVisible = ref(false)
const bookings = ref<any[]>([])
const currentBooking = ref<any>(null)

const newBooking = reactive({
  guest_name: '', 
  guest_phone: '', 
  room_id: undefined as number | undefined,
  check_in_date: dayjs().add(1, 'day'), 
  check_out_date: dayjs().add(3, 'day'),
  guest_count: 1,
  special_requests: '',
  payment_method: 'balance'
})

const columns = [
  { title: '预订号', dataIndex: 'booking_number', width: 170 },
  { title: '客人', dataIndex: 'guest_name', width: 100 },
  { title: '电话', dataIndex: 'guest_phone', width: 130 },
  { title: '房号', dataIndex: 'room_number', width: 80 },
  { title: '实际入住', dataIndex: 'check_in_time', key: 'check_in_time', width: 130, customRender: ({ record }: any) => formatDateTime(record.check_in_time || record.check_in_date) },
  { title: '实际退房', dataIndex: 'check_out_time', key: 'check_out_time', width: 130, customRender: ({ record }: any) => formatDateTime(record.check_out_time || record.check_out_date) },
  { title: '金额', dataIndex: 'total_price', key: 'total_price', width: 110 },
  { title: '状态', dataIndex: 'status', key: 'status', width: 100 },
  { title: '操作', key: 'action', width: 160 }
]

function statusColor(s: string): string {
  return ({ pending: 'warning', confirmed: 'processing', pre_checked_in: 'cyan', checked_in: 'success', checked_out: 'default', cancelled: 'error' } as Record<string, string>)[s] || 'default'
}
function statusText(s: string): string {
  return ({ pending: '待确认', confirmed: '已支付', pre_checked_in: '预入住', checked_in: '已入住', checked_out: '已退房', cancelled: '已取消' } as Record<string, string>)[s] || s
}

function viewDetail(record: any) {
  currentBooking.value = record
  detailVisible.value = true
}

function doCheckin(record: any) {
  router.push({
    path: '/reception/checkinout',
    query: { booking_id: record.id }
  })
}

async function fetchBookings() {
  loading.value = true
  try {
    const params: any = {
      guest_name: searchKey.value,
      status: filterStatus.value
    }

    // 如果没有筛选状态，且处于“今日预订”分栏，则不传状态给后端，由前端过滤
    // 如果是“历史预订”分栏，且没有筛选状态，则也不传，由前端过滤
    
    const res: any = await bookingApi.getBookingList(params)
    let list = res.data?.list || []

    const today = dayjs().format('YYYY-MM-DD')
    
    // 前端二次过滤，确保分栏逻辑准确
    if (activeTab.value === 'today') {
      list = list.filter((b: any) => {
        const isTodayCheckin = dayjs(b.check_in_date).isSame(today, 'day')
        const isTodayCheckout = dayjs(b.check_out_date).isSame(today, 'day')
        const isActive = ['pending', 'confirmed', 'pre_checked_in', 'checked_in'].includes(b.status)
        // 今日预订：活跃订单，或者虽然不是活跃但就在今天入住/离店的
        return isActive || isTodayCheckin || isTodayCheckout
      })
    } else {
      // 历史预订：已退房、已取消，且不是今天离店的（今天离店的留在今日预订）
      list = list.filter((b: any) => {
        const isHistoryStatus = ['checked_out', 'cancelled'].includes(b.status)
        const isTodayCheckout = dayjs(b.check_out_date).isSame(today, 'day')
        return isHistoryStatus && !isTodayCheckout
      })
    }

    bookings.value = list
  } catch (error) {
    message.error('获取预订列表失败')
  } finally {
    loading.value = false
  }
}

function showCreateModal() { 
  modalVisible.value = true 
  void hotelStore.fetchRooms({ pageSize: 300 }).catch(() => {})
}

async function handleCreateBooking() {
  if (!newBooking.guest_name || !newBooking.guest_phone || !newBooking.room_id) {
    message.warning('请填写必填项')
    return
  }
  try {
    await bookingApi.createBooking({
      ...newBooking,
      check_in_date: newBooking.check_in_date.format('YYYY-MM-DD'),
      check_out_date: newBooking.check_out_date.format('YYYY-MM-DD'),
      hotel_id: hotelStore.currentHotelId!
    })
    message.success('预订创建成功')
    modalVisible.value = false
    fetchBookings()
  } catch (error) {
    message.error('创建预订失败')
  }
}

async function handleConfirm(id: number) {
  try {
    await bookingApi.updateBookingStatus(id, 'confirmed')
    message.success('预订已确认')
    fetchBookings()
  } catch (error) {
    message.error('确认失败')
  }
}

async function handleCheckin(id: number) {
  try {
    await bookingApi.checkin(id)
    message.success('入住办理成功')
    fetchBookings()
  } catch (error: any) {
    message.error(error?.response?.data?.message || '入住办理失败')
  }
}

async function handleCancel(id: number) {
  try {
    await bookingApi.updateBookingStatus(id, 'cancelled')
    message.success('预订已取消')
    fetchBookings()
  } catch (error) {
    message.error('取消失败')
  }
}

async function handleCheckout(id: number) {
  try {
    await bookingApi.updateBookingStatus(id, 'checked_out')
    message.success('退房成功，订单已完成')
    fetchBookings()
  } catch (error) {
    message.error('退房失败')
  }
}

onMounted(() => {
  void hotelStore.fetchRooms({ pageSize: 300 }).catch(() => {})
  fetchBookings()
})
</script>

<style scoped>
.toolbar { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; flex-wrap: wrap; gap: 8px; }
</style>
