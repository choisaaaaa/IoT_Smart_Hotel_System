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
                    <div class="phone-input-wrapper">
                      <a-input v-model:value="checkinForm.phone" placeholder="手机号码" style="flex: 1;" />
                      <div class="member-status-info">
                        <a-tag v-if="getMemberByPhone(checkinForm.phone)" color="gold" style="margin: 0;">
                          {{ getLevelName(getMemberByPhone(checkinForm.phone).member_level) }}
                        </a-tag>
                        <a-tag v-else-if="checkinForm.phone && checkinForm.phone.length >= 11" color="warning" style="margin: 0;">未注册</a-tag>
                      </div>
                    </div>
                  </a-form-item>
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
              <a-form-item label="预估金额 (含会员/日期折扣)" style="margin-top: 12px;">
                <a-statistic :value="estimatedPrice" prefix="¥" :precision="2" :loading="priceLoading" />
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
                >
                  <div class="room-main" @click="chooseRoom(room)">
                    <div class="room-type-text">{{ room.room_name }}</div>
                    <div class="room-num-text">{{ room.room_number }}</div>
                  </div>
                  <a-button type="link" size="small" class="detail-link" @click.stop="showRoomDetail(room)">详情</a-button>
                </div>
              </div>
            </a-card>

    <!-- 房间详情弹窗 -->
    <a-modal v-model:open="roomDetailVisible" title="房间详情" :footer="null" width="400px">
      <div v-if="roomDetail" class="room-detail-modal-content">
        <a-descriptions :column="1" bordered size="small">
          <a-descriptions-item label="房号">{{ roomDetail.room_number }}</a-descriptions-item>
          <a-descriptions-item label="房型">{{ roomDetail.room_name }}</a-descriptions-item>
          <a-descriptions-item label="基准价格">¥{{ roomDetail.room_price }}/晚</a-descriptions-item>
          <a-descriptions-item label="面积">{{ roomDetail.area }}㎡</a-descriptions-item>
          <a-descriptions-item label="床型">{{ roomDetail.bed_type }}</a-descriptions-item>
          <a-descriptions-item label="最大入住">{{ roomDetail.max_guests }}人</a-descriptions-item>
          <a-descriptions-item label="设施">
            <a-tag v-for="f in roomDetail.facilities" :key="f" size="small">{{ f }}</a-tag>
          </a-descriptions-item>
        </a-descriptions>
      </div>
    </a-modal>
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
                    <a-tag v-if="getMemberByPhone(record.guest_phone)" color="gold">
                      {{ getLevelName(getMemberByPhone(record.guest_phone).member_level) }}
                    </a-tag>
                    <a-tag v-else color="default">非会员</a-tag>
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
import { ref, reactive, computed, onMounted, watch } from 'vue'
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
// 移除 memberPhones，改用 memberList
// const memberPhones = ref<Set<string>>(new Set())
const todayBookingLoading = ref(false)
const companions = ref<any[]>([])

// 房间详情
const roomDetailVisible = ref(false)
const roomDetail = ref<RoomInfo | null>(null)

function showRoomDetail(room: RoomInfo) {
  roomDetail.value = room
  roomDetailVisible.value = true
}

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

const estimatedPrice = ref(0)
const priceLoading = ref(false)

async function updateEstimatedPrice() {
  if (!checkinForm.room_id || !checkinForm.check_in_date || !checkinForm.check_out_date) {
    estimatedPrice.value = 0
    return
  }
  
  try {
    priceLoading.value = true
    const res: any = await bookingApi.getCalculatedPrice({
      room_id: checkinForm.room_id,
      check_in_date: checkinForm.check_in_date.format('YYYY-MM-DD'),
      check_out_date: checkinForm.check_out_date.format('YYYY-MM-DD'),
      guest_phone: checkinForm.phone || undefined
    })
    estimatedPrice.value = res.data?.total_price || 0
  } catch (error) {
    console.error('计算预估价失败:', error)
  } finally {
    priceLoading.value = false
  }
}

watch(() => [checkinForm.room_id, checkinForm.check_in_date, checkinForm.check_out_date, checkinForm.phone], () => {
  updateEstimatedPrice()
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
  { title: '会员等级', key: 'registered', width: 100 },
  { title: '操作', key: 'action', width: 92 }
]

function normalizePhone(phone: string): string {
  return String(phone || '').replace(/\D/g, '')
}

const memberList = ref<any[]>([])

function getMemberByPhone(phone: string): any {
  const key = normalizePhone(phone)
  if (!key) return null
  return memberList.value.find(m => normalizePhone(m.phone) === key)
}

function getLevelName(level: string): string {
  const levels: Record<string, string> = {
    'diamond': '💎 钻石会员',
    'platinum': '🥈 铂金会员',
    'gold': '🥇 金卡会员',
    'silver': '🥈 银卡会员',
    'standard': '👤 普通会员'
  }
  return levels[level] || '已注册'
}

function isPhoneRegistered(phone: string): boolean {
  return !!getMemberByPhone(phone)
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
    memberList.value = res.data?.list || []
  } catch (error) {
    memberList.value = []
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
    } as any)
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
  margin-top: 12px;
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
  gap: 12px;
  max-height: 400px;
  overflow-y: auto;
  padding: 4px;
}
.room-tile {
  border: 1px solid #f0f0f0;
  border-radius: 10px;
  padding: 0;
  cursor: pointer;
  transition: all 0.3s cubic-bezier(0.645, 0.045, 0.355, 1);
  display: flex;
  flex-direction: column;
  overflow: hidden;
  background: #fff;
  min-height: 100px;
}
.room-tile:hover {
  box-shadow: 0 4px 12px rgba(0,0,0,0.12);
  transform: translateY(-2px);
}
.room-tile.active {
  border-color: #1890ff;
  background: #e6f7ff;
  box-shadow: 0 2px 8px rgba(24, 144, 255, 0.2);
}
.room-tile.active .room-type-text {
  color: #1890ff;
}
.room-main {
  padding: 12px 8px;
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
}
.room-type-text {
  font-size: 14px;
  font-weight: 700;
  color: rgba(0, 0, 0, 0.85);
  margin-bottom: 4px;
  width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.room-num-text {
  font-size: 16px;
  font-family: 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
  color: rgba(0, 0, 0, 0.65);
  font-weight: 500;
}
.detail-link {
  font-size: 12px;
  height: 28px;
  line-height: 28px;
  padding: 0;
  border-top: 1px solid #f0f0f0;
  width: 100%;
  background: #fafafa;
  color: #8c8c8c;
}
.detail-link:hover {
  background: #f0f0f0;
  color: #1890ff;
}
.room-tile.active .detail-link {
  border-top-color: #91d5ff;
  background: #bae7ff;
  color: #0050b3;
}
.room-detail-modal-content {
  padding: 8px 0;
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

.phone-input-wrapper {
  display: flex;
  align-items: center;
  gap: 8px;
}

.member-status-info {
  flex-shrink: 0;
  min-width: 80px;
  display: flex;
  justify-content: flex-end;
}
</style>
