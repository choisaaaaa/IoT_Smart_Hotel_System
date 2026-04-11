
<template>
  <div class="coupon-manage">
    <a-card title="优惠券管理" :bordered="false">
      <template #extra>
        <a-space v-if="!isStaff">
          <a-select
            v-if="isSystemAdmin && hotels.length > 0"
            v-model:value="filterHotelId"
            placeholder="筛选门店"
            style="width: 180px"
            allow-clear
            @change="fetchCoupons"
          >
            <a-select-option :value="-1">所有门店</a-select-option>
            <a-select-option v-for="h in hotels" :key="h.id" :value="h.id">{{ h.hotel_name }}</a-select-option>
          </a-select>
          <a-button type="primary" @click="showAddModal">
            <PlusOutlined /> 新增优惠券
          </a-button>
        </a-space>
      </template>

      <a-table :columns="columns" :data-source="coupons" :loading="loading" row-key="id">
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'hotel_id'">
            <a-tag v-if="record.hotel_id === 0" color="blue">通用券</a-tag>
            <a-tag v-else-if="record.hotel_name" color="purple">{{ record.hotel_name }}</a-tag>
            <span v-else>-</span>
          </template>
          <template v-if="column.key === 'coupon_type'">
            <a-tag :color="record.coupon_type === 'discount' ? 'blue' : 'green'">
              {{ record.coupon_type === 'discount' ? '折扣券' : '直减券' }}
            </a-tag>
          </template>
          <template v-if="column.key === 'discount_value'">
            {{ record.coupon_type === 'discount' ? record.discount_value + '折' : '\u00a5' + record.discount_value }}
          </template>
          <template v-if="column.key === 'validity'">
            {{ formatDate(record.valid_from) }} 至 {{ formatDate(record.valid_to) }}
          </template>
          <template v-if="column.key === 'action'">
            <a-space v-if="isStaff">
              <a-button type="link" size="small" @click="handleRedeem(record)" :disabled="record.status !== 'active'">
                <QrcodeOutlined /> 核销
              </a-button>
            </a-space>
            <a-space v-else>
              <a-button type="link" size="small" @click="showDirectIssueModal(record)">发放给用户</a-button>
              <a-button type="link" size="small" @click="editCoupon(record)">编辑</a-button>
              <a-popconfirm title="确定删除此优惠券吗？" @confirm="deleteCoupon(record.id)">
                <a-button type="link" danger size="small">删除</a-button>
              </a-popconfirm>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

    <!-- 直接发放给用户弹窗 -->
    <a-modal
      v-model:open="directIssueVisible"
      title="直接发放优惠券"
      @ok="handleDirectIssue"
      :confirmLoading="directIssueLoading"
      width="400px"
    >
      <a-form layout="vertical">
        <a-form-item label="优惠券" required>
          <a-input :value="selectedCouponForIssue?.coupon_name" disabled />
        </a-form-item>
        <a-form-item label="用户手机号" required>
          <a-input v-model:value="directIssuePhone" placeholder="请输入用户手机号" />
        </a-form-item>
        <a-alert message="发放后用户可在其个人中心查看到该券" type="info" show-icon />
      </a-form>
    </a-modal>

    <!-- 添加/编辑弹窗 -->
    <a-modal
      v-model:open="modalVisible"
      :title="editingId ? '编辑优惠券' : '新增优惠券'"
      @ok="handleSave"
      :confirmLoading="submitLoading"
    >
      <a-form :model="formState" layout="vertical">
        <a-form-item label="优惠券名称" required>
          <a-input v-model:value="formState.coupon_name" placeholder="如：新店开业8折券" />
        </a-form-item>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="优惠类型" required>
              <a-select v-model:value="formState.coupon_type">
                <a-select-option value="discount">折扣券</a-select-option>
                <a-select-option value="cash">直减券</a-select-option>
              </a-select>
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item :label="formState.coupon_type === 'discount' ? '折扣额 (如 8.5 表示 85 折)' : '减免金额 (元)'" required>
              <a-input-number v-model:value="formState.discount_value" style="width: 100%" :min="0" />
            </a-form-item>
          </a-col>
        </a-row>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="最低消费 (元)">
              <a-input-number v-model:value="formState.min_amount" style="width: 100%" :min="0" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="发放总量 (0为不限)">
              <a-input-number v-model:value="formState.total_count" style="width: 100%" :min="0" />
            </a-form-item>
          </a-col>
        </a-row>
        <a-form-item label="优惠码 (选填，不填则只能通过系统发放)">
          <a-input v-model:value="formState.coupon_code" placeholder="输入导入券码，如 WELCOME2026" />
        </a-form-item>
        <a-form-item label="允许多次导入">
          <a-switch v-model:checked="formState.is_multiple_use" />
        </a-form-item>
        <a-form-item v-if="isSystemAdmin && hotels.length > 0" label="选择门店">
          <a-select v-model:value="formState.hotel_id" placeholder="不选则为通用券（所有门店可用）" allow-clear>
            <a-select-option :value="0">通用券（所有门店可用）</a-select-option>
            <a-select-option v-for="h in hotels" :key="h.id" :value="h.id">{{ h.hotel_name }}</a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item label="有效期" required>
          <a-range-picker v-model:value="validRange" style="width: 100%" />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 核销确认弹窗 -->
    <a-modal
      v-model:open="redeemVisible"
      title="核销优惠券"
      @ok="handleConfirmRedeem"
      :confirmLoading="redeemLoading"
      width="400px"
    >
      <a-result status="warning" title="确定要核销此优惠券吗？">
        <template #extra>
          <p>核销后该优惠券将变为已使用状态，不可恢复。</p>
        </template>
      </a-result>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, computed } from 'vue'
import { PlusOutlined, QrcodeOutlined } from '@ant-design/icons-vue'
import { message } from 'ant-design-vue'
import request from '@/api/request'
import dayjs from 'dayjs'

const userStore = useUserStore()
const isSystemAdmin = computed(() => userStore.role === 'system')
const isAdmin = computed(() => userStore.role === 'admin')
const isStaff = computed(() => userStore.role === 'staff')

const columns = [
  { title: '券名', dataIndex: 'coupon_name', key: 'coupon_name' },
  { title: '所属门店', key: 'hotel_id', width: 120 },
  { title: '券码', dataIndex: 'coupon_code', key: 'coupon_code' },
  { title: '类型', dataIndex: 'coupon_type', key: 'coupon_type', width: 90 },
  { title: '优惠值', key: 'discount_value', width: 110 },
  { title: '门槛', dataIndex: 'min_amount', key: 'min_amount', customRender: ({ text }: any) => `\u00a5${text}`, width: 80 },
  { title: '已领/总量', key: 'counts', customRender: ({ record }: any) => `${record.received_count}/${record.total_count || '\u221e'}`, width: 90 },
  { title: '有效期', key: 'validity', width: 200 },
  { title: '操作', key: 'action', width: isStaff.value ? 80 : 220 }
]

const coupons = ref([])
const loading = ref(false)
const modalVisible = ref(false)
const submitLoading = ref(false)
const editingId = ref<number | null>(null)
const validRange = ref<any[]>([])
const hotels = ref<any[]>([])
const filterHotelId = ref<number | undefined>()

// 直接发放相关
const directIssueVisible = ref(false)
const directIssueLoading = ref(false)
const directIssuePhone = ref('')
const selectedCouponForIssue = ref<any>(null)

// 核销相关
const redeemVisible = ref(false)
const redeemLoading = ref(false)
const selectedCouponForRedeem = ref<any>(null)

const formState = reactive({
  coupon_name: '',
  coupon_code: '',
  coupon_type: 'discount',
  discount_value: 0,
  min_amount: 0,
  total_count: 0,
  is_multiple_use: false,
  hotel_id: null as number | null
})

const formatDate = (date: any) => date ? dayjs(date).format('YYYY-MM-DD') : '-'

const fetchHotels = async () => {
  try {
    const res = await request.get('/coupons/hotels')
    hotels.value = res.data?.data || []
  } catch (e) {
    console.error('获取酒店列表失败:', e)
  }
}

const fetchCoupons = async () => {
  loading.value = true
  try {
    const params: Record<string, any> = {}
    if (filterHotelId.value !== undefined && filterHotelId.value !== -1) {
      params.hotel_id = filterHotelId.value
    }
    const res = await request.get('/coupons', { params })
    coupons.value = res.data.list || []
  } catch (error) {
    message.error('获取优惠券失败')
  } finally {
    loading.value = false
  }
}

const showDirectIssueModal = (record: any) => {
  selectedCouponForIssue.value = record
  directIssuePhone.value = ''
  directIssueVisible.value = true
}

const handleDirectIssue = async () => {
  if (!directIssuePhone.value) return message.warning('请输入手机号')

  directIssueLoading.value = true
  try {
    await request.post('/coupons/issue-to-user', {
      coupon_id: selectedCouponForIssue.value.id,
      phone: directIssuePhone.value
    })
    message.success('发放成功')
    directIssueVisible.value = false
    fetchCoupons()
  } catch (error: any) {
    message.error(error.response?.data?.message || '发放失败')
  } finally {
    directIssueLoading.value = false
  }
}

const handleRedeem = (record: any) => {
  selectedCouponForRedeem.value = record
  redeemVisible.value = true
}

const handleConfirmRedeem = async () => {
  if (!selectedCouponForRedeem.value) return

  redeemLoading.value = true
  try {
    await request.post(`/coupons/${selectedCouponForRedeem.value.id}/redeem`)
    message.success('核销成功')
    redeemVisible.value = false
    fetchCoupons()
  } catch (error: any) {
    message.error(error.response?.data?.message || '核销失败')
  } finally {
    redeemLoading.value = false
  }
}

const showAddModal = () => {
  editingId.value = null
  Object.assign(formState, {
    coupon_name: '',
    coupon_code: '',
    coupon_type: 'discount',
    discount_value: 0,
    min_amount: 0,
    total_count: 0,
    is_multiple_use: false,
    hotel_id: null
  })
  validRange.value = []
  modalVisible.value = true
}

const editCoupon = (record: any) => {
  editingId.value = record.id
  Object.assign(formState, {
    coupon_name: record.coupon_name,
    coupon_code: record.coupon_code || '',
    coupon_type: record.coupon_type,
    discount_value: Number(record.discount_value),
    min_amount: Number(record.min_amount),
    total_count: record.total_count,
    is_multiple_use: !!record.is_multiple_use,
    hotel_id: record.hotel_id ?? null
  })
  validRange.value = [dayjs(record.valid_from), dayjs(record.valid_to)]
  modalVisible.value = true
}

const handleSave = async () => {
  if (!formState.coupon_name || validRange.value.length < 2) {
    return message.warning('请填写必要信息')
  }

  submitLoading.value = true
  try {
    const data = {
      ...formState,
      valid_from: validRange.value[0].format('YYYY-MM-DD'),
      valid_to: validRange.value[1].format('YYYY-MM-DD')
    }

    if (editingId.value) {
      await request.put(`/coupons/${editingId.value}`, data)
      message.success('更新成功')
    } else {
      await request.post('/coupons', data)
      message.success('创建成功')
    }
    modalVisible.value = false
    fetchCoupons()
  } catch (error) {
    message.error('保存失败')
  } finally {
    submitLoading.value = false
  }
}

const deleteCoupon = async (id: number) => {
  try {
    await request.delete(`/coupons/${id}`)
    message.success('已删除')
    fetchCoupons()
  } catch (error) {
    message.error('删除失败')
  }
}

onMounted(() => {
  fetchHotels()
  fetchCoupons()
})
</script>

<style scoped>
.text-danger { color: #ff4d4f; }
</style>
