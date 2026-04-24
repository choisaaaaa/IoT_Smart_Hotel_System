
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
            <a-tag v-if="record.scope_type === 'global'" color="blue">全局券</a-tag>
            <template v-else-if="record.hotel_ids && record.hotel_ids.trim()">
              <a-popover title="适用门店">
                <template #content>
                  <div v-for="hId in record.hotel_ids.split(',')" :key="hId">
                    {{ hotels.find(h => h.id == hId)?.hotel_name || hId }}
                  </div>
                </template>
                <a-tag color="purple">
                  {{ record.hotel_name || '多门店' }}
                  <span v-if="record.hotel_ids.split(',').length > 1">+{{ record.hotel_ids.split(',').length - 1 }}</span>
                </a-tag>
              </a-popover>
            </template>
            <a-tag v-else-if="record.hotel_name" color="purple">{{ record.hotel_name }}</a-tag>
            <span v-else>-</span>
          </template>
          <template v-if="column.key === 'scope_type'">
            <a-tag v-if="record.scope_type === 'global'" color="blue">全局</a-tag>
            <a-tag v-else-if="record.scope_type === 'hotel'" color="purple">酒店专属</a-tag>
            <a-tag v-else-if="record.scope_type === 'private'" color="orange">私密发放</a-tag>
          </template>
          <template v-if="column.key === 'is_public'">
            <a-tag v-if="record.is_public" color="green">公开</a-tag>
            <a-tag v-else color="default">私密</a-tag>
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
              <a-button type="link" size="small" @click="showDirectIssueModal(record)">发放</a-button>
            </a-space>
            <a-space v-else-if="isSystemAdmin || isAdmin">
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
        <a-form-item label="优惠券范围" required>
          <a-select v-model:value="formState.scope_type" @change="handleScopeTypeChange">
            <a-select-option v-if="isSystemAdmin" value="global">全局券（所有门店通用）</a-select-option>
            <a-select-option value="hotel">酒店专属券</a-select-option>
            <a-select-option value="private">私密发放券（仅管理员可发放）</a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item v-if="formState.scope_type !== 'global'" label="是否公开领取">
          <a-switch v-model:checked="formState.is_public" :checked-children="'公开'" :un-checked-children="'私密'" />
          <div class="form-hint">公开：顾客可自行领取；私密：仅管理员可发放</div>
        </a-form-item>
        <a-form-item v-if="isSystemAdmin && formState.scope_type !== 'global' && hotels.length > 0" label="适用门店">
          <a-select v-model:value="formState.hotel_ids" placeholder="请选择适用门店" mode="multiple" allow-clear>
            <a-select-option v-for="h in hotels" :key="h.id" :value="h.id">{{ h.hotel_name }}</a-select-option>
          </a-select>
          <div class="form-hint">支持选择一个或多个门店</div>
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
import { $notify, NotifyPreset } from '@/utils/notify'
import request from '@/api/request'
import { CANONICAL_ROLES } from '@/api/auth'
import { useAppStore } from '@/stores/app'
import dayjs from 'dayjs'
import { formatDate } from '@/utils/date'

const userStore = useAppStore()
const isSystemAdmin = computed(() => userStore.userInfo?.role === CANONICAL_ROLES.SYSTEM_ADMIN)
const isAdmin = computed(() => userStore.userInfo?.role === CANONICAL_ROLES.HOTEL_ADMIN)
const isStaff = computed(() => userStore.userInfo?.role === CANONICAL_ROLES.STAFF)

const columns = computed(() => [
  { title: '券名', dataIndex: 'coupon_name', key: 'coupon_name' },
  { title: '范围', key: 'scope_type', width: 100 },
  { title: '领取', key: 'is_public', width: 80 },
  { title: '所属门店', key: 'hotel_id', width: 120 },
  { title: '券码', dataIndex: 'coupon_code', key: 'coupon_code' },
  { title: '类型', dataIndex: 'coupon_type', key: 'coupon_type', width: 90 },
  { title: '优惠值', key: 'discount_value', width: 110 },
  { title: '门槛', dataIndex: 'min_amount', key: 'min_amount', customRender: ({ text }: any) => `\u00a5${text}`, width: 80 },
  { title: '已领/总量', key: 'counts', customRender: ({ record }: any) => `${record.received_count}/${record.total_count || '\u221e'}`, width: 90 },
  { title: '有效期', key: 'validity', width: 200 },
  { title: '操作', key: 'action', width: isStaff.value ? 150 : 220 }
])

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
  hotel_id: null as number | null,
  hotel_ids: [] as number[],
  scope_type: 'hotel',
  is_public: true
})

const fetchHotels = async () => {
  try {
    const res = await request.get('/coupons/hotels')
    hotels.value = res.data || []
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
    $notify.error({ title: '获取优惠券失败', description: '无法加载优惠券列表，请稍后重试 🔄' })
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
  if (!directIssuePhone.value) return $notify.warning({ title: '请输入手机号', description: '请输入用户手机号以发放优惠券 📱' })

  directIssueLoading.value = true
  try {
    await request.post('/coupons/issue-to-user', {
      coupon_id: selectedCouponForIssue.value.id,
      phone: directIssuePhone.value
    })
    NotifyPreset.couponIssued()
    directIssueVisible.value = false
    fetchCoupons()
  } catch (error: any) {
    NotifyPreset.operationFailed(error.response?.data?.message || '发放失败')
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
    $notify.success({ title: '核销成功', description: '优惠券已成功核销 ✅' })
    redeemVisible.value = false
    fetchCoupons()
  } catch (error: any) {
    NotifyPreset.operationFailed(error.response?.data?.message || '核销失败')
  } finally {
    redeemLoading.value = false
  }
}

const handleScopeTypeChange = (value: string) => {
  if (value === 'global') {
    formState.is_public = true
    formState.hotel_id = null
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
    hotel_id: isSystemAdmin.value ? null : userStore.userInfo?.hotel_id,
    hotel_ids: isSystemAdmin.value ? [] : (userStore.userInfo?.hotel_id ? [userStore.userInfo.hotel_id] : []),
    scope_type: isSystemAdmin.value ? 'global' : 'hotel',
    is_public: true
  })
  validRange.value = []
  modalVisible.value = true
}

const editCoupon = (record: any) => {
  editingId.value = record.id
  let hIds: number[] = []
  if (record.hotel_ids) {
    hIds = record.hotel_ids.split(',').map((id: string) => Number(id.trim()))
  } else if (record.hotel_id) {
    hIds = [record.hotel_id]
  }
  
  Object.assign(formState, {
    coupon_name: record.coupon_name,
    coupon_code: record.coupon_code || '',
    coupon_type: record.coupon_type,
    discount_value: Number(record.discount_value),
    min_amount: Number(record.min_amount),
    total_count: record.total_count,
    is_multiple_use: !!record.is_multiple_use,
    hotel_id: record.hotel_id ?? null,
    hotel_ids: hIds,
    scope_type: record.scope_type || 'hotel',
    is_public: record.is_public !== undefined ? record.is_public : true
  })
  validRange.value = [dayjs(record.valid_from), dayjs(record.valid_to)]
  modalVisible.value = true
}

const handleSave = async () => {
  if (!formState.coupon_name || validRange.value.length < 2) {
    return $notify.warning({ title: '请填写必要信息', description: '请填写优惠券名称和有效期 📋' })
  }

  submitLoading.value = true
  try {
    const data = {
      ...formState,
      valid_from: validRange.value[0].format('YYYY-MM-DD'),
      valid_to: validRange.value[1].format('YYYY-MM-DD')
    }

    // 全局券不需要hotel_id
    if (data.scope_type === 'global') {
      data.hotel_id = 0
      data.hotel_ids = []
    } else if (!data.hotel_ids?.length && !isSystemAdmin.value) {
      // 非系统管理员必须设置本店ID
      data.hotel_id = userStore.userInfo?.hotel_id
      data.hotel_ids = [userStore.userInfo?.hotel_id]
    } else if (data.hotel_ids?.length) {
      data.hotel_id = data.hotel_ids[0]
    }

    if (editingId.value) {
      await request.put(`/coupons/${editingId.value}`, data)
      NotifyPreset.profileUpdated('优惠券')
    } else {
      await request.post('/coupons', data)
      $notify.success({ title: '创建成功', description: '新优惠券已成功创建 🎫' })
    }
    modalVisible.value = false
    fetchCoupons()
  } catch (error: any) {
    NotifyPreset.operationFailed(error.response?.data?.message || '保存失败')
  } finally {
    submitLoading.value = false
  }
}

const deleteCoupon = async (id: number) => {
  try {
    await request.delete(`/coupons/${id}`)
    $notify.success({ title: '已删除', description: '优惠券已成功删除 🗑️' })
    fetchCoupons()
  } catch (error) {
    NotifyPreset.operationFailed('删除优惠券失败')
  }
}

onMounted(() => {
  fetchHotels()
  fetchCoupons()
})
</script>

<style scoped>
.text-danger { color: #ff4d4f; }
.form-hint {
  font-size: 12px;
  color: #999;
  margin-top: 4px;
}
</style>
