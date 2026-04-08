<template>
  <div class="reception-bookings">
    <div class="toolbar">
      <a-space>
        <a-input-search v-model:value="searchKey" placeholder="搜索预订号/客人名" style="width: 240px;" allow-clear />
        <a-select v-model:value="filterStatus" placeholder="状态筛选" allow-clear style="width: 140px;">
          <a-select-option value="confirmed">已确认</a-select-option>
          <a-select-option value="checked_in">已入住</a-select-option>
          <a-select-option value="checked_out">已退房</a-select-option>
          <a-select-option value="cancelled">已取消</a-select-option>
        </a-select>
      </a-space>
      <a-button type="primary" @click="showCreateModal"><PlusOutlined /> 新建预订</a-button>
    </div>

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
            <a-dropdown v-if="record.status === 'pending' || record.status === 'confirmed'">
              <a-button type="link" size="small">操作 <DownOutlined /></a-button>
              <template #overlay>
                <a-menu>
                  <a-menu-item v-if="record.status === 'pending'" @click="handleConfirm(record.id)">确认预订</a-menu-item>
                  <a-menu-item v-if="record.status === 'confirmed'" @click="doCheckin(record)">办理入住</a-menu-item>
                  <a-menu-item danger @click="handleCancel(record.id)">取消预订</a-menu-item>
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
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { message } from 'ant-design-vue'
import { PlusOutlined, DownOutlined, SearchOutlined } from '@ant-design/icons-vue'
import dayjs from 'dayjs'
import { bookingApi } from '@/api/booking'
import { useRouter } from 'vue-router'
import { useHotelStore } from '@/stores/hotel'

const router = useRouter()
const hotelStore = useHotelStore()
const loading = ref(false)
const searchKey = ref('')
const filterStatus = ref<string | undefined>()
const modalVisible = ref(false)
const bookings = ref<any[]>([])

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
  { title: '入住', dataIndex: 'check_in_date', key: 'check_in_date', width: 110 },
  { title: '退房', dataIndex: 'check_out_date', key: 'check_out_date', width: 110 },
  { title: '金额', dataIndex: 'total_price', key: 'total_price', width: 110 },
  { title: '状态', dataIndex: 'status', key: 'status', width: 100 },
  { title: '操作', key: 'action', width: 160 }
]

function statusColor(s: string): string {
  return ({ confirmed: 'processing', checked_in: 'success', checked_out: 'default', cancelled: 'error', pending: 'warning' } as Record<string, string>)[s] || 'default'
}
function statusText(s: string): string {
  return ({ confirmed: '已确认', checked_in: '已入住', checked_out: '已退房', cancelled: '已取消', pending: '待确认' } as Record<string, string>)[s] || s
}

function viewDetail(record: any) {
  message.info(`查看预订 ${record.booking_number} 详情`)
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
    const res = await bookingApi.getBookingList({
      status: filterStatus.value,
      guest_name: searchKey.value
    })
    bookings.value = res.data?.list || []
  } catch (error) {
    message.error('获取预订列表失败')
  } finally {
    loading.value = false
  }
}

function showCreateModal() { 
  modalVisible.value = true 
  hotelStore.fetchRooms()
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
      check_out_date: newBooking.check_out_date.format('YYYY-MM-DD')
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

async function handleCancel(id: number) {
  try {
    await bookingApi.updateBookingStatus(id, 'cancelled')
    message.success('预订已取消')
    fetchBookings()
  } catch (error) {
    message.error('取消失败')
  }
}

onMounted(fetchBookings)
</script>

<style scoped>
.toolbar { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; flex-wrap: wrap; gap: 8px; }
</style>