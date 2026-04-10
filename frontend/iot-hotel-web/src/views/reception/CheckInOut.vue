<template>
  <div class="check-in-out">
    <a-tabs v-model:activeKey="activeTab">
      <a-tab-pane key="checkin" tab="📥 入住办理">
        <a-row :gutter="16">
          <a-col :xs="24" :xl="15">
            <a-form :model="checkinForm" layout="vertical">
              <a-alert message="线下办理：请核验客人身份证件后录入信息" type="info" show-icon style="margin-bottom: 16px;" />
              <a-row :gutter="16">
                <a-col :span="12">
                  <a-form-item label="客人姓名" required>
                    <a-input v-model:value="checkinForm.guest_name" placeholder="请输入真实姓名" />
                  </a-form-item>
                </a-col>
                <a-col :span="12">
                  <a-form-item label="联系电话" required>
                    <a-input v-model:value="checkinForm.phone" placeholder="手机号码" />
                  </a-form-item>
                  <a-tag :color="phoneRegistered ? 'success' : 'warning'">{{ phoneRegistered ? '已注册用户' : '未注册用户' }}</a-tag>
                </a-col>
              </a-row>
              <a-row :gutter="16">
                <a-col :span="12">
                  <a-form-item label="证件类型">
                    <a-select v-model:value="checkinForm.id_type">
                      <a-select-option value="idcard">身份证</a-select-option>
                      <a-select-option value="passport">护照</a-select-option>
                      <a-select-option value="other">其他</a-select-option>
                    </a-select>
                  </a-form-item>
                </a-col>
                <a-col :span="12">
                  <a-form-item label="证件号码">
                    <a-input v-model:value="checkinForm.id_number" placeholder="证件号码" />
                  </a-form-item>
                </a-col>
              </a-row>
              <a-row :gutter="16">
                <a-col :span="12">
                  <a-form-item label="入住人数">
                    <a-input-number v-model:value="checkinForm.guest_count" :min="1" :max="8" style="width: 100%;" />
                  </a-form-item>
                </a-col>
                <a-col :span="12">
                  <a-form-item label="支付方式">
                    <a-select v-model:value="checkinForm.payment_method">
                      <a-select-option value="alipay">支付宝</a-select-option>
                      <a-select-option value="wechat">微信支付</a-select-option>
                      <a-select-option value="credit_card">银行卡</a-select-option>
                      <a-select-option value="cash">现金</a-select-option>
                    </a-select>
                  </a-form-item>
                </a-col>
              </a-row>
              <a-row :gutter="16">
                <a-col :span="12">
                  <a-form-item label="入住日期" required>
                    <a-date-picker v-model:value="checkinForm.check_in_date" style="width: 100%;" />
                  </a-form-item>
                </a-col>
                <a-col :span="12">
                  <a-form-item label="预计退房日期" required>
                    <a-date-picker v-model:value="checkinForm.check_out_date" style="width: 100%;" />
                  </a-form-item>
                </a-col>
              </a-row>
              <a-card size="small" class="selected-room-card">
                <div class="selected-room-header">
                  <span>已选空房</span>
                  <a-tag v-if="selectedRoom" color="success">{{ selectedRoom.room_number }}</a-tag>
                  <a-tag v-else color="warning">未选择</a-tag>
                </div>
                <div v-if="selectedRoom" class="selected-room-text">
                  {{ selectedRoom.room_name }} · ¥{{ selectedRoom.room_price }}/晚
                </div>
              </a-card>
              <a-form-item label="预估金额" style="margin-top: 12px;">
                <a-statistic :value="estimatedPrice" prefix="¥" :precision="2" />
              </a-form-item>
              <a-divider orientation="left">同住人</a-divider>
              <a-space direction="vertical" style="width: 100%;">
                <a-card v-for="(item, index) in companions" :key="index" size="small">
                  <a-row :gutter="12">
                    <a-col :span="6"><a-input v-model:value="item.name" placeholder="姓名" /></a-col>
                    <a-col :span="6"><a-input v-model:value="item.phone" placeholder="手机号" /></a-col>
                    <a-col :span="5">
                      <a-select v-model:value="item.id_type" style="width: 100%;">
                        <a-select-option value="idcard">身份证</a-select-option>
                        <a-select-option value="passport">护照</a-select-option>
                        <a-select-option value="other">其他</a-select-option>
                      </a-select>
                    </a-col>
                    <a-col :span="5"><a-input v-model:value="item.id_number" placeholder="证件号" /></a-col>
                    <a-col :span="2">
                      <a-button danger @click="removeCompanion(index)">
                        <DeleteOutlined />
                      </a-button>
                    </a-col>
                  </a-row>
                </a-card>
              </a-space>
              <a-button type="dashed" block style="margin-top: 8px;" @click="addCompanion">
                <PlusOutlined /> 添加同住人
              </a-button>
              <a-form-item label="备注" style="margin-top: 12px;">
                <a-textarea v-model:value="checkinForm.remark" :rows="2" placeholder="特殊要求等" />
              </a-form-item>
              <a-form-item>
                <a-space>
                  <a-button type="primary" size="large" @click="handleCheckIn" :loading="submitting">
                    <UserAddOutlined /> 确认入住
                  </a-button>
                  <a-button @click="resetCheckinForm">重置</a-button>
                </a-space>
              </a-form-item>
            </a-form>
          </a-col>
          <a-col :xs="24" :xl="9">
            <a-card size="small" title="空房清单">
              <a-input v-model:value="roomSearchKeyword" placeholder="搜索房号/房名" allow-clear />
              <div class="room-grid">
                <div
                  v-for="room in searchedRooms"
                  :key="room.id"
                  class="room-tile"
                  :class="{ active: checkinForm.room_id === room.id }"
                  @click="chooseRoom(room)"
                >
                  <div class="room-num">{{ room.room_number }}</div>
                  <div class="room-name">{{ room.room_name }}</div>
                </div>
              </div>
            </a-card>
            <a-card size="small" title="今日预定清单" style="margin-top: 12px;" :loading="todayBookingLoading">
              <a-space style="margin-bottom: 8px;">
                <a-button size="small" @click="fetchTodayBookings">刷新</a-button>
                <a-button size="small" type="primary" :disabled="selectedBookingKeys.length === 0" @click="checkInSelectedBooking">
                  办理选中预订
                </a-button>
              </a-space>
              <a-table
                :columns="todayBookingColumns"
                :data-source="todayBookings"
                :pagination="{ pageSize: 5 }"
                row-key="id"
                size="small"
                :row-selection="{ selectedRowKeys: selectedBookingKeys, onChange: onBookingSelectionChange }"
              >
                <template #bodyCell="{ column, record }">
                  <template v-if="column.key === 'registered'">
                    <a-tag :color="record.phone_registered ? 'success' : 'warning'">
                      {{ record.phone_registered ? '已注册' : '未注册' }}
                    </a-tag>
                  </template>
                  <template v-if="column.key === 'action'">
                    <a-button type="link" size="small" @click="fillByBooking(record)">办理入住</a-button>
                  </template>
                </template>
              </a-table>
            </a-card>
          </a-col>
        </a-row>
      </a-tab-pane>

      <a-tab-pane key="checkout" tab="📤 退房办理">
        <a-table
          :columns="checkoutColumns"
          :data-source="currentGuests"
          :row-selection="{ selectedRowKeys: checkoutKeys, onChange: onCheckoutSelectionChange }"
          :pagination="{ pageSize: 8 }"
          row-key="id"
          size="middle"
        >
          <template #bodyCell="{ column, record }">
            <template v-if="column.key === 'amount'"><strong>¥{{ record.total_amount }}</strong></template>
            <template v-if="column.key === 'action'">
              <a-popconfirm title="确认办理退房？" @confirm="handleCheckout(record)">
                <a-button type="primary" size="small">办理退房</a-button>
              </a-popconfirm>
            </template>
          </template>
        </a-table>
      </a-tab-pane>
    </a-tabs>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { message } from 'ant-design-vue'
import { UserAddOutlined, PlusOutlined, DeleteOutlined } from '@ant-design/icons-vue'
import dayjs from 'dayjs'
import { useHotelStore } from '@/stores/hotel'
import { bookingApi } from '@/api/booking'
import { useRoute } from 'vue-router'
import { memberApi } from '@/api/member'
import type { RoomInfo } from '@/types'

const hotelStore = useHotelStore()
const route = useRoute()
const activeTab = ref('checkin')
const submitting = ref(false)
const checkoutKeys = ref<number[]>([])
const currentGuests = ref<any[]>([])
const roomSearchKeyword = ref('')
const todayBookings = ref<any[]>([])
const selectedBookingKeys = ref<number[]>([])
const memberPhones = ref<Set<string>>(new Set())
const todayBookingLoading = ref(false)
const companions = ref<Array<{ name: string; phone: string; id_type: string; id_number: string }>>([])

const checkinForm = reactive({
  guest_name: '', phone: '', id_type: 'idcard', id_number: '',
  room_id: undefined as number | undefined, guest_count: 1,
  check_in_date: dayjs(), check_out_date: dayjs().add(2, 'day'),
  payment_method: 'alipay', remark: ''
})

const availableRooms = computed(() => hotelStore.getAvailableRooms())
const searchedRooms = computed(() => {
  const keyword = roomSearchKeyword.value.trim().toLowerCase()
  if (!keyword) return availableRooms.value
  return availableRooms.value.filter(room =>
    String(room.room_number).toLowerCase().includes(keyword) ||
    String(room.room_name).toLowerCase().includes(keyword)
  )
})
const selectedRoom = computed(() => availableRooms.value.find(room => room.id === checkinForm.room_id))
const phoneRegistered = computed(() => isPhoneRegistered(checkinForm.phone))

const estimatedPrice = computed(() => {
  if (!checkinForm.room_id) return 0
  const room = availableRooms.value.find(r => r.id === checkinForm.room_id)
  if (!room) return 0
  const nights = dayjs(checkinForm.check_out_date).diff(dayjs(checkinForm.check_in_date), 'day')
  return Number(room.room_price) * Math.max(nights, 1)
})

const checkoutColumns = [
  { title: '客人', dataIndex: 'guest_name', width: 100 },
  { title: '房号', dataIndex: 'room_number', width: 80 },
  { title: '入住天数', dataIndex: 'stay_nights', width: 90 },
  { title: '应付金额', dataIndex: 'total_amount', key: 'amount', width: 120 },
  { title: '操作', key: 'action', width: 120 }
]

const todayBookingColumns = [
  { title: '客人', dataIndex: 'guest_name', width: 88 },
  { title: '手机号', dataIndex: 'guest_phone', width: 112 },
  { title: '房号', dataIndex: 'room_number', width: 62 },
  { title: '注册', key: 'registered', width: 72 },
  { title: '操作', key: 'action', width: 92 }
]

function normalizePhone(phone: string): string {
  return String(phone || '').replace(/\D/g, '')
}

function isPhoneRegistered(phone: string): boolean {
  const key = normalizePhone(phone)
  if (!key) return false
  return memberPhones.value.has(key)
}

function addCompanion() {
  companions.value.push({ name: '', phone: '', id_type: 'idcard', id_number: '' })
}

function removeCompanion(index: number) {
  companions.value.splice(index, 1)
}

function chooseRoom(room: RoomInfo) {
  checkinForm.room_id = room.id
}

function onBookingSelectionChange(keys: (string | number)[]) {
  selectedBookingKeys.value = keys as number[]
}

function onCheckoutSelectionChange(keys: (string | number)[]) {
  checkoutKeys.value = keys as number[]
}

async function fetchCurrentGuests() {
  try {
    const res: any = await bookingApi.getBookingList({ status: 'checked_in' })
    currentGuests.value = (res.data?.list || []).map((b: any) => {
      const nights = dayjs().diff(dayjs(b.check_in_date), 'day') || 1
      return {
        ...b,
        stay_nights: nights,
        total_amount: b.total_price
      }
    })
  } catch (error) {
    message.error('获取在住客人失败')
  }
}

async function fetchMemberList() {
  try {
    const res: any = await memberApi.getMemberList({ pageSize: 1000 })
    const list = res.data?.list || []
    const phoneSet = new Set<string>()
    list.forEach((item: any) => {
      const key = normalizePhone(item.phone)
      if (key) phoneSet.add(key)
    })
    memberPhones.value = phoneSet
  } catch (error) {
    memberPhones.value = new Set()
  }
}

async function fetchTodayBookings() {
  if (todayBookingLoading.value) return
  todayBookingLoading.value = true
  try {
    // 改用后端过滤，支持 check_in_date=today 参数，且只查询待办理和已确认的
    const res: any = await bookingApi.getBookingList({
      pageSize: 200,
      check_in_date: 'today'
    })
    const list = (res.data?.list || []).filter((item: any) =>
      ['pending', 'confirmed'].includes(item.status)
    )
    todayBookings.value = list.map((item: any) => ({
      ...item,
      phone_registered: isPhoneRegistered(item.guest_phone)
    }))
  } catch (error) {
    message.error('获取今日预订失败')
  } finally {
    todayBookingLoading.value = false
  }
}

function fillByBooking(booking: any) {
  activeTab.value = 'checkin'
  checkinForm.guest_name = booking.guest_name || ''
  checkinForm.phone = booking.guest_phone || ''
  checkinForm.guest_count = Number(booking.guest_count || 1)
  if (booking.check_in_date) checkinForm.check_in_date = dayjs(booking.check_in_date)
  if (booking.check_out_date) checkinForm.check_out_date = dayjs(booking.check_out_date)
  if (booking.payment_method) checkinForm.payment_method = booking.payment_method
  companions.value = []
  if (booking.room_id) {
    const room = availableRooms.value.find(item => item.id === booking.room_id)
    if (room) {
      chooseRoom(room)
    }
  }
}

function checkInSelectedBooking() {
  const targetId = selectedBookingKeys.value[0]
  if (!targetId) return
  const booking = todayBookings.value.find(item => Number(item.id) === Number(targetId))
  if (!booking) {
    message.warning('未找到选中的预订记录')
    return
  }
  fillByBooking(booking)
}

async function handleCheckIn() {
  if (!checkinForm.guest_name || !checkinForm.phone || !checkinForm.room_id) {
    message.warning('请填写必填项'); return
  }
  submitting.value = true
  try {
    const payload: any = {
      ...checkinForm,
      check_in_date: checkinForm.check_in_date.format('YYYY-MM-DD'),
      check_out_date: checkinForm.check_out_date.format('YYYY-MM-DD'),
      status: 'checked_in',
      guest_phone: checkinForm.phone,
      companions: companions.value.filter(item => item.name || item.phone || item.id_number)
    }
    await bookingApi.createBooking(payload)
    message.success(`入住成功！${checkinForm.guest_name} 已分配房间`)
    resetCheckinForm()
    await Promise.all([
      fetchCurrentGuests(),
      fetchTodayBookings(),
      hotelStore.fetchRooms({ pageSize: 300 })
    ])
  } catch (error) {
    message.error('办理入住失败')
  } finally {
    submitting.value = false
  }
}

function resetCheckinForm() {
  Object.assign(checkinForm, {
    guest_name: '', phone: '', id_type: 'idcard', id_number: '',
    room_id: undefined, guest_count: 1,
    check_in_date: dayjs(), check_out_date: dayjs().add(2, 'day'),
    payment_method: 'alipay', remark: ''
  })
  companions.value = []
}

async function handleCheckout(record: any) {
  try {
    await bookingApi.updateBookingStatus(record.id, 'checked_out')
    message.success(`${record.guest_name}（${record.room_number}）退房成功，应付 ¥${record.total_amount}`)
    await Promise.all([
      fetchCurrentGuests(),
      hotelStore.fetchRooms({ pageSize: 300 })
    ])
  } catch (error) {
    message.error('办理退房失败')
  }
}

async function fillByBookingId() {
  const bookingId = Number(route.query.booking_id || 0)
  if (!bookingId) return
  try {
    const res: any = await bookingApi.getBookingList({ pageSize: 200 })
    const booking = (res.data?.list || []).find((item: any) => Number(item.id) === bookingId)
    if (booking) fillByBooking(booking)
  } catch (error) {
    message.error('预订信息回填失败')
  }
}

onMounted(async () => {
  try {
    await hotelStore.fetchRooms({ pageSize: 300 })
  } catch (error) {}
  await Promise.allSettled([
    fetchMemberList(),
    fetchCurrentGuests(),
    fetchTodayBookings(),
    fillByBookingId()
  ])
})
</script>

<style scoped>
.room-grid {
  margin-top: 10px;
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(92px, 1fr));
  gap: 8px;
  max-height: 240px;
  overflow-y: auto;
}
.room-tile {
  border: 1px solid #f0f0f0;
  border-radius: 6px;
  padding: 8px;
  cursor: pointer;
  transition: all 0.2s;
}
.room-tile.active {
  border-color: #1890ff;
  background: #e6f7ff;
}
.room-num {
  font-weight: 700;
  font-size: 15px;
}
.room-name {
  font-size: 12px;
  color: rgba(0, 0, 0, 0.55);
}
.selected-room-card {
  border: 1px dashed #d9d9d9;
}
.selected-room-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.selected-room-text {
  margin-top: 4px;
  color: rgba(0, 0, 0, 0.65);
}
</style>
