<template>
  <div class="check-in-out">
    <a-tabs v-model:activeKey="activeTab">
      <a-tab-pane key="checkin" tab="📥 入住办理">
        <a-form :model="checkinForm" layout="vertical" style="max-width: 650px;">
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
              <a-form-item label="分配房间" required>
                <a-select v-model:value="checkinForm.room_id" show-search placeholder="搜索可用房间" :filter-option="false" @search="searchAvailable">
                  <a-select-option v-for="r in availableRooms" :key="r.id" :value="r.id">{{ r.room_number }} - {{ r.room_name }} (¥{{ r.room_price }}/晚)</a-select-option>
                </a-select>
              </a-form-item>
            </a-col>
            <a-col :span="12">
              <a-form-item label="入住人数">
                <a-input-number v-model:value="checkinForm.guest_count" :min="1" :max="4" style="width: 100%;" />
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
          <a-row :gutter="16">
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
            <a-col :span="12">
              <a-form-item label="预估金额">
                <a-statistic :value="estimatedPrice" prefix="¥" :precision="2" />
              </a-form-item>
            </a-col>
          </a-row>
          <a-form-item label="备注">
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
      </a-tab-pane>

      <a-tab-pane key="checkout" tab="📤 退房办理">
        <a-table
          :columns="checkoutColumns"
          :data-source="currentGuests"
          :row-selection="{ selectedRowKeys: checkoutKeys, onChange: (k: (string | number)[]) => { checkoutKeys = k as number[] } }"
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
import { UserAddOutlined } from '@ant-design/icons-vue'
import dayjs from 'dayjs'
import { useHotelStore } from '@/stores/hotel'
import { bookingApi } from '@/api/booking'

const hotelStore = useHotelStore()
const activeTab = ref('checkin')
const submitting = ref(false)
const checkoutKeys = ref<number[]>([])
const currentGuests = ref<any[]>([])

const checkinForm = reactive({
  guest_name: '', phone: '', id_type: 'idcard', id_number: '',
  room_id: undefined as number | undefined, guest_count: 1,
  check_in_date: dayjs(), check_out_date: dayjs().add(2, 'day'),
  payment_method: 'alipay', remark: ''
})

const availableRooms = computed(() => hotelStore.getAvailableRooms())

const estimatedPrice = computed(() => {
  if (!checkinForm.room_id) return 0
  const room = availableRooms.value.find(r => r.id === checkinForm.room_id)
  if (!room) return 0
  const nights = dayjs(checkinForm.check_out_date).diff(dayjs(checkinForm.check_in_date), 'day')
  return Number(room.room_price) * Math.max(nights, 1)
})

function searchAvailable(val: string) {}

const checkoutColumns = [
  { title: '客人', dataIndex: 'guest_name', width: 100 },
  { title: '房号', dataIndex: 'room_number', width: 80 },
  { title: '入住天数', dataIndex: 'stay_nights', width: 90 },
  { title: '应付金额', dataIndex: 'total_amount', key: 'amount', width: 120 },
  { title: '操作', key: 'action', width: 120 }
]

async function fetchCurrentGuests() {
  try {
    const res = await bookingApi.getBookingList({ status: 'checked_in' })
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

async function handleCheckIn() {
  if (!checkinForm.guest_name || !checkinForm.phone || !checkinForm.room_id) {
    message.warning('请填写必填项'); return
  }
  submitting.value = true
  try {
    await bookingApi.createBooking({
      ...checkinForm,
      check_in_date: checkinForm.check_in_date.format('YYYY-MM-DD'),
      check_out_date: checkinForm.check_out_date.format('YYYY-MM-DD'),
      status: 'checked_in',
      guest_phone: checkinForm.phone
    })
    message.success(`入住成功！${checkinForm.guest_name} 已分配房间`)
    resetCheckinForm()
    fetchCurrentGuests()
    hotelStore.fetchRooms()
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
}

async function handleCheckout(record: any) {
  try {
    await bookingApi.updateBookingStatus(record.id, 'checked_out')
    message.success(`${record.guest_name}（${record.room_number}）退房成功，应付 ¥${record.total_amount}`)
    fetchCurrentGuests()
    hotelStore.fetchRooms()
  } catch (error) {
    message.error('办理退房失败')
  }
}

onMounted(() => {
  hotelStore.fetchRooms()
  fetchCurrentGuests()
})
</script>