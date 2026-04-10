
<template>
  <div class="price-calendar">
    <a-card title="房型价格日历" :bordered="false">
      <template #extra>
        <a-space>
          <span class="label">选择房型:</span>
          <a-select v-model:value="selectedRoomTypeId" style="width: 180px" @change="onRoomTypeChange">
            <a-select-option v-for="type in roomTypes" :key="type.id" :value="type.id">
              {{ type.name }}
            </a-select-option>
          </a-select>
          
          <span class="label">房价方案:</span>
          <a-select v-model:value="selectedRatePlanId" style="width: 180px" @change="fetchCalendar" placeholder="默认标准价">
            <a-select-option :value="null">默认标准价</a-select-option>
            <a-select-option v-for="plan in ratePlans" :key="plan.id" :value="plan.id">
              {{ plan.plan_name }}
            </a-select-option>
          </a-select>
          
          <a-button type="primary" ghost @click="handleOpenRatePlanModal">
            管理方案
          </a-button>
        </a-space>
      </template>

      <div class="calendar-container">
        <a-calendar v-model:value="currentMonth" @panelChange="onPanelChange">
          <template #dateCellRender="{ current }">
            <div class="price-cell" @click.stop="openEditModal(current)">
              <template v-if="getPriceForDate(current)">
                <div class="base-price">基准: ¥{{ getPriceForDate(current).base_price }}</div>
                <div class="final-price">
                  <span class="label">现价:</span>
                  <span class="val">¥{{ getPriceForDate(current).final_price }}</span>
                </div>
                <div class="discount-tag" v-if="getPriceForDate(current).discount_rate < 1">
                  {{ Math.round(getPriceForDate(current).discount_rate * 100) / 10 }}折
                </div>
              </template>
              <template v-else-if="selectedRoomType">
                <div class="base-price placeholder">房型基准价</div>
                <div class="final-price">
                  <span class="label">现价:</span>
                  <span class="val">¥{{ selectedRoomType.base_price }}</span>
                </div>
                <div class="status-tag default">默认价</div>
              </template>
              <a-button type="link" size="small" class="edit-btn">
                {{ getPriceForDate(current) ? '修改' : '设置' }}
              </a-button>
            </div>
          </template>
        </a-calendar>
      </div>
    </a-card>

    <!-- 价格编辑弹窗 -->
    <a-modal
      v-model:open="modalVisible"
      :title="`设置价格 - ${selectedDateStr}`"
      @ok="handleSavePrice"
      :confirmLoading="submitLoading"
    >
      <a-form layout="vertical">
        <a-form-item label="当日基准价 (元)">
          <a-input-number v-model:value="editForm.base_price" style="width: 100%" :min="0" />
        </a-form-item>
        <a-form-item label="折扣率 (1.0 为不打折, 0.85 为 85 折)">
          <a-input-number v-model:value="editForm.discount_rate" style="width: 100%" :min="0" :max="1" :step="0.01" />
        </a-form-item>
        <div class="final-price-preview">
          <div class="preview-title">预计结算价格预览</div>
          <div class="level-prices">
            <div class="level-price-item">
              <span class="label">执行价 (基础):</span>
              <span class="val">¥{{ (editForm.base_price * editForm.discount_rate).toFixed(2) }}</span>
            </div>
            <div v-for="(discount, level) in levelDiscounts" :key="level" class="level-price-item">
              <span class="label">{{ getLevelLabel(level) }} ({{ Math.round(discount * 100) / 10 }}折):</span>
              <span class="val">¥{{ (editForm.base_price * editForm.discount_rate * discount).toFixed(2) }}</span>
            </div>
          </div>
        </div>
      </a-form>
    </a-modal>

    <!-- 房价方案管理弹窗 -->
    <a-modal
      v-model:open="showRatePlanModal"
      title="房价方案管理"
      width="900px"
      :footer="null"
    >
      <div class="plan-mgmt-container">
        <div class="mgmt-header">
          <a-button type="primary" @click="openPlanEdit(null)">
            <PlusOutlined /> 新增方案
          </a-button>
        </div>
        
        <a-table :dataSource="ratePlans" :columns="planColumns" :pagination="false" rowKey="id">
          <template #bodyCell="{ column, record }">
            <template v-if="column.key === 'meal_plan'">
              <a-tag color="blue">{{ getMealLabel(record.meal_plan) }} ({{ record.breakfast_count }}份)</a-tag>
            </template>
            <template v-if="column.key === 'cancellation_policy'">
              <a-tag :color="record.cancellation_policy === 'free' ? 'green' : 'orange'">
                {{ getCancelLabel(record.cancellation_policy) }}
                <span v-if="record.cancel_time_limit > 0">({{ record.cancel_time_limit }}h前)</span>
              </a-tag>
            </template>
            <template v-if="column.key === 'payment_type'">
              <a-tag color="purple">{{ getPaymentLabel(record.payment_type) }}</a-tag>
              <div v-if="record.prepayment_ratio > 0" style="font-size: 11px; color: #8c8c8c">
                预付 {{ record.prepayment_ratio }}%
              </div>
            </template>
            <template v-if="column.key === 'is_guaranteed'">
              <a-switch :checked="record.is_guaranteed === 1" disabled size="small" />
            </template>
            <template v-if="column.key === 'action'">
              <a-space>
                <a-button type="link" size="small" @click="openPlanEdit(record)">编辑</a-button>
                <a-popconfirm title="确定删除该方案吗？" @confirm="handleDeletePlan(record.id)">
                  <a-button type="link" size="small" danger>删除</a-button>
                </a-popconfirm>
              </a-space>
            </template>
          </template>
        </a-table>
      </div>
    </a-modal>

    <!-- 方案编辑弹窗 -->
    <a-modal
      v-model:open="planEditVisible"
      :title="planForm.id ? '编辑方案' : '新增方案'"
      @ok="handleSavePlan"
      :confirmLoading="planSubmitLoading"
    >
      <a-form layout="vertical">
        <a-form-item label="方案名称" required>
          <a-input v-model:value="planForm.plan_name" placeholder="如：含双早特惠、不可取消特惠" />
        </a-form-item>
        
        <a-form-item label="方案基础价 (不设置则默认使用房型价)" tooltip="此价格作为该方案的默认价格，若价格日历未设置则使用此价">
          <a-input-number v-model:value="planForm.base_price" :min="0" style="width: 100%" placeholder="0 为跟随房型价" />
        </a-form-item>
        
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="餐食计划">
              <a-select v-model:value="planForm.meal_plan">
                <a-select-option value="none">无早</a-select-option>
                <a-select-option value="breakfast">含早</a-select-option>
                <a-select-option value="half_board">半食宿</a-select-option>
                <a-select-option value="full_board">全食宿</a-select-option>
              </a-select>
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="早餐份数">
              <a-input-number v-model:value="planForm.breakfast_count" :min="0" style="width: 100%" />
            </a-form-item>
          </a-col>
        </a-row>

        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="取消政策">
              <a-select v-model:value="planForm.cancellation_policy">
                <a-select-option value="free">免费取消</a-select-option>
                <a-select-option value="no_cancel">不可取消</a-select-option>
                <a-select-option value="restricted">限时取消</a-select-option>
              </a-select>
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="取消时限 (入住前小时)">
              <a-input-number v-model:value="planForm.cancel_time_limit" :min="0" style="width: 100%" placeholder="0为不限" />
            </a-form-item>
          </a-col>
        </a-row>

        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="支付要求">
              <a-select v-model:value="planForm.payment_type">
                <a-select-option value="all">不限</a-select-option>
                <a-select-option value="online_only">仅限在线支付</a-select-option>
                <a-select-option value="front_desk_only">仅限到店支付</a-select-option>
              </a-select>
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="预付比例 (%)">
              <a-input-number v-model:value="planForm.prepayment_ratio" :min="0" :max="100" style="width: 100%" />
            </a-form-item>
          </a-col>
        </a-row>

        <a-form-item label="是否需要信用卡担保">
          <a-radio-group v-model:value="planForm.is_guaranteed">
            <a-radio :value="1">是</a-radio>
            <a-radio :value="0">否</a-radio>
          </a-radio-group>
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, computed } from 'vue'
import { message } from 'ant-design-vue'
import { PlusOutlined } from '@ant-design/icons-vue'
import request from '@/api/request'
import dayjs, { Dayjs } from 'dayjs'

const roomTypes = ref<any[]>([])
const ratePlans = ref<any[]>([])
const selectedRoomTypeId = ref<number | null>(null)
const selectedRatePlanId = ref<number | null>(null)
const currentMonth = ref<Dayjs>(dayjs())
const calendarData = ref<any[]>([])
const levelDiscounts = ref<Record<string, number>>({})
const loading = ref(false)

const showRatePlanModal = ref(false)
const handleOpenRatePlanModal = () => {
  if (!selectedRoomTypeId.value) {
    message.warning('请先选择房型')
    return
  }
  fetchRatePlans()
  showRatePlanModal.value = true
}
const planEditVisible = ref(false)
const planSubmitLoading = ref(false)
const planForm = reactive({
  id: undefined,
  plan_name: '',
  base_price: 0,
  meal_plan: 'none',
  breakfast_count: 0,
  cancellation_policy: 'free',
  cancel_time_limit: 0,
  payment_type: 'all',
  is_guaranteed: 0,
  prepayment_ratio: 0
})

const planColumns = [
  { title: '方案名称', dataIndex: 'plan_name', key: 'plan_name' },
  { title: '方案底价', dataIndex: 'base_price', key: 'base_price' },
  { title: '餐食', dataIndex: 'meal_plan', key: 'meal_plan' },
  { title: '取消政策', dataIndex: 'cancellation_policy', key: 'cancellation_policy' },
  { title: '支付/预付', dataIndex: 'payment_type', key: 'payment_type' },
  { title: '需担保', dataIndex: 'is_guaranteed', key: 'is_guaranteed' },
  { title: '操作', key: 'action', width: 120 }
]

const getMealLabel = (val: string) => ({ none: '无早', breakfast: '含早', half_board: '半食宿', full_board: '全食宿' }[val] || val)
const getCancelLabel = (val: string) => ({ free: '免费取消', no_cancel: '不可取消', restricted: '限时取消' }[val] || val)
const getPaymentLabel = (val: string) => ({ all: '不限', online_only: '在线付', front_desk_only: '到店付' }[val] || val)

const openPlanEdit = (record: any) => {
  if (record) {
    Object.assign(planForm, { ...record })
  } else {
    Object.assign(planForm, {
      id: undefined,
      plan_name: '',
      base_price: 0,
      meal_plan: 'none',
      breakfast_count: 0,
      cancellation_policy: 'free',
      cancel_time_limit: 0,
      payment_type: 'all',
      is_guaranteed: 0,
      prepayment_ratio: 0
    })
  }
  planEditVisible.value = true
}

const handleSavePlan = async () => {
  if (!planForm.plan_name) return message.warning('请填写方案名称')
  
  planSubmitLoading.value = true
  try {
    const data = { ...planForm, room_type_id: selectedRoomTypeId.value }
    if (planForm.id) {
      await request.put(`/rate-plans/${planForm.id}`, data)
      message.success('更新成功')
    } else {
      await request.post('/rate-plans', data)
      message.success('创建成功')
    }
    planEditVisible.value = false
    fetchRatePlans()
  } catch (error) {
    message.error('操作失败')
  } finally {
    planSubmitLoading.value = false
  }
}

const handleDeletePlan = async (id: number) => {
  try {
    await request.delete(`/rate-plans/${id}`)
    message.success('删除成功')
    fetchRatePlans()
  } catch (error: any) {
    message.error(error.response?.data?.message || '删除失败')
  }
}

const selectedRoomType = computed(() => {
  return roomTypes.value.find(t => t.id === selectedRoomTypeId.value)
})

const getLevelLabel = (level: string) => {
  const labels: Record<string, string> = {
    'diamond': '钻石会员',
    'platinum': '铂金会员',
    'gold': '金卡会员',
    'silver': '银卡会员',
    'standard': '普通会员'
  }
  return labels[level] || level
}

const fetchLevelDiscounts = async () => {
  try {
    const res = await request.get('/members/discounts')
    levelDiscounts.value = res.data || {}
  } catch (error) {
    console.error('获取会员折扣失败:', error)
  }
}

const modalVisible = ref(false)
const submitLoading = ref(false)
const selectedDateStr = ref('')
const editForm = reactive({
  base_price: 0,
  discount_rate: 1.0
})

const fetchRoomTypes = async () => {
  try {
    const res = await request.get('/room-types')
    roomTypes.value = res.data || []
    if (roomTypes.value.length > 0) {
      selectedRoomTypeId.value = roomTypes.value[0].id
      fetchRatePlans()
      fetchCalendar()
    }
  } catch (error) {
    message.error('获取房型失败')
  }
}

const fetchRatePlans = async () => {
  if (!selectedRoomTypeId.value) return
  try {
    const res = await request.get('/rate-plans', {
      params: { room_type_id: selectedRoomTypeId.value }
    })
    ratePlans.value = res.data || []
  } catch (error) {
    console.error('获取房价方案失败:', error)
  }
}

const onRoomTypeChange = () => {
  selectedRatePlanId.value = null
  fetchRatePlans()
  fetchCalendar()
}

const fetchCalendar = async () => {
  if (!selectedRoomTypeId.value) return
  
  const start = currentMonth.value.startOf('month').format('YYYY-MM-DD')
  const end = currentMonth.value.endOf('month').format('YYYY-MM-DD')
  
  loading.value = true
  try {
    const res = await request.get('/price-calendar', {
      params: {
        room_type_id: selectedRoomTypeId.value,
        rate_plan_id: selectedRatePlanId.value,
        start_date: start,
        end_date: end
      }
    })
    calendarData.value = res.data || []
  } catch (error) {
    message.error('获取价格日历失败')
  } finally {
    loading.value = false
  }
}

const onPanelChange = (value: Dayjs) => {
  currentMonth.value = value
  fetchCalendar()
}

const getPriceForDate = (date: Dayjs) => {
  const dateStr = date.format('YYYY-MM-DD')
  return calendarData.value.find(item => dayjs(item.price_date).format('YYYY-MM-DD') === dateStr)
}

const openEditModal = (date: Dayjs) => {
  const existing = getPriceForDate(date)
  selectedDateStr.value = date.format('YYYY-MM-DD')
  
  if (existing) {
    editForm.base_price = Number(existing.base_price)
    editForm.discount_rate = Number(existing.discount_rate)
  } else {
    const type = roomTypes.value.find(t => t.id === selectedRoomTypeId.value)
    editForm.base_price = type ? Number(type.base_price) : 0
    editForm.discount_rate = 1.0
  }
  
  modalVisible.value = true
}

const handleSavePrice = async () => {
  submitLoading.value = true
  try {
    await request.post('/price-calendar/set', {
      room_type_id: selectedRoomTypeId.value,
      rate_plan_id: selectedRatePlanId.value,
      prices: [{
        date: selectedDateStr.value,
        base_price: editForm.base_price,
        discount_rate: editForm.discount_rate
      }]
    })
    message.success('价格设置成功')
    modalVisible.value = false
    fetchCalendar()
  } catch (error) {
    message.error('保存失败')
  } finally {
    submitLoading.value = false
  }
}

onMounted(() => {
  fetchRoomTypes()
  fetchLevelDiscounts()
})
</script>

<style scoped>
.calendar-container {
  margin-top: 20px;
  background: #fff;
  padding: 12px;
}

.price-cell {
  height: 100%;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  position: relative;
  padding: 4px;
  cursor: pointer;
  transition: background 0.3s;
}

.price-cell:hover {
  background: #f0f5ff;
}

.base-price {
  font-size: 11px;
  color: #999;
  text-decoration: line-through;
}

.base-price.placeholder {
  text-decoration: none;
  font-style: italic;
  opacity: 0.7;
}

.final-price {
  font-size: 13px;
  font-weight: bold;
  color: #f5222d;
  margin: 2px 0;
}

.discount-tag {
  background: #fff1f0;
  color: #f5222d;
  font-size: 10px;
  padding: 0 4px;
  border-radius: 4px;
}

.status-tag.default {
  background: #f5f5f5;
  color: #8c8c8c;
  font-size: 10px;
  padding: 0 4px;
  border-radius: 4px;
}

.edit-btn {
  opacity: 0;
  transition: opacity 0.3s;
}

.price-cell:hover .edit-btn {
  opacity: 1;
}

.final-price-preview {
  margin-top: 16px;
  padding: 16px;
  background: #f8f9fa;
  border-radius: 12px;
  border: 1px solid #e8e8e8;
}

.preview-title {
  font-size: 14px;
  font-weight: 600;
  color: #1a1a1a;
  margin-bottom: 12px;
  padding-bottom: 8px;
  border-bottom: 1px solid #eee;
}

.level-prices {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.level-price-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 13px;
}

.level-price-item .label {
  color: #666;
}

.level-price-item .val {
  color: #f5222d;
  font-weight: 700;
  font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', 'Consolas', monospace;
}

.level-price-item:first-child {
  padding-bottom: 4px;
  margin-bottom: 4px;
  border-bottom: 1px dashed #eee;
}

.level-price-item:first-child .val {
  color: #1a1a1a;
  font-size: 15px;
}

/* 方案管理弹窗样式 */
.plan-mgmt-container {
  padding: 12px 0;
}

.mgmt-header {
  margin-bottom: 16px;
  display: flex;
  justify-content: flex-end;
}

:deep(.ant-table-wrapper) {
  background: #fff;
  border-radius: 8px;
}

:deep(.ant-tag) {
  margin: 2px;
}
</style>
