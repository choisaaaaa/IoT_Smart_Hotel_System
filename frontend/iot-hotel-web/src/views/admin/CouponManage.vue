
<template>
  <div class="coupon-manage">
    <a-card title="优惠券管理" :bordered="false">
      <template #extra>
        <a-button type="primary" @click="showAddModal">
          <PlusOutlined /> 发放优惠券
        </a-button>
      </template>

      <a-table :columns="columns" :data-source="coupons" :loading="loading" row-key="id">
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'coupon_type'">
            <a-tag :color="record.coupon_type === 'discount' ? 'blue' : 'green'">
              {{ record.coupon_type === 'discount' ? '折扣券' : '直减券' }}
            </a-tag>
          </template>
          <template v-if="column.key === 'discount_value'">
            {{ record.coupon_type === 'discount' ? record.discount_value + '折' : '¥' + record.discount_value }}
          </template>
          <template v-if="column.key === 'validity'">
            {{ formatDate(record.valid_from) }} 至 {{ formatDate(record.valid_to) }}
          </template>
          <template v-if="column.key === 'action'">
            <a-space>
              <a @click="editCoupon(record)">编辑</a>
              <a-popconfirm title="确定删除此优惠券吗？" @confirm="deleteCoupon(record.id)">
                <a class="text-danger">删除</a>
              </a-popconfirm>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

    <!-- 添加/编辑弹窗 -->
    <a-modal
      v-model:open="modalVisible"
      :title="editingId ? '编辑优惠券' : '发放优惠券'"
      @ok="handleSave"
      :confirmLoading="submitLoading"
    >
      <a-form :model="formState" layout="vertical">
        <a-form-item label="优惠券名称" required>
          <a-input v-model:value="formState.coupon_name" placeholder="如：新店开业8折券" />
        </a-form-item>
        <a-form-item label="优惠码 (选填，不填则只能通过系统发放)">
          <a-input v-model:value="formState.coupon_code" placeholder="输入导入券码，如 WELCOME2026" />
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
        <a-form-item label="允许多次导入 (同一个用户是否可以多次导入此券)">
          <a-switch v-model:checked="formState.is_multiple_use" />
        </a-form-item>
        <a-form-item label="有效期" required>
          <a-range-picker v-model:value="validRange" style="width: 100%" />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { PlusOutlined } from '@ant-design/icons-vue'
import { message } from 'ant-design-vue'
import request from '@/api/request'
import dayjs from 'dayjs'

const columns = [
  { title: '券名', dataIndex: 'coupon_name', key: 'coupon_name' },
  { title: '券码', dataIndex: 'coupon_code', key: 'coupon_code' },
  { title: '类型', dataIndex: 'coupon_type', key: 'coupon_type' },
  { title: '优惠值', key: 'discount_value' },
  { title: '门槛', dataIndex: 'min_amount', key: 'min_amount', customRender: ({ text }: any) => `¥${text}` },
  { title: '已领/总量', key: 'counts', customRender: ({ record }: any) => `${record.received_count}/${record.total_count || '∞'}` },
  { title: '有效期', key: 'validity' },
  { title: '操作', key: 'action' }
]

const coupons = ref([])
const loading = ref(false)
const modalVisible = ref(false)
const submitLoading = ref(false)
const editingId = ref<number | null>(null)
const validRange = ref<any[]>([])

const formState = reactive({
  coupon_name: '',
  coupon_code: '',
  coupon_type: 'discount',
  discount_value: 0,
  min_amount: 0,
  total_count: 0,
  is_multiple_use: false
})

const formatDate = (date: any) => date ? dayjs(date).format('YYYY-MM-DD') : '-'

const fetchCoupons = async () => {
  loading.value = true
  try {
    const res = await request.get('/coupons')
    coupons.value = res.data.list || []
  } catch (error) {
    message.error('获取优惠券失败')
  } finally {
    loading.value = false
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
    is_multiple_use: false
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
    is_multiple_use: !!record.is_multiple_use
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
      message.success('发放成功')
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

onMounted(fetchCoupons)
</script>

<style scoped>
.text-danger { color: #ff4d4f; }
</style>
