<template>
  <div class="delivery-orders">
    <a-row :gutter="[16, 16]">
      <a-col :xs="12" :sm="8">
        <a-badge :count="pendingCount" :offset="[-10, 10]" :show-zero="false" style="width: 100%">
          <a-card size="small" class="stat-card" :body-style="{ background: pendingCount > 0 ? '#fffbe6' : '#fff' }">
            <a-statistic title="待配送" :value="pendingCount" :value-style="{ color: '#faad14' }"><template #icon><SendOutlined /></template></a-statistic>
          </a-card>
        </a-badge>
      </a-col>
      <a-col :xs="12" :sm="8">
        <a-card size="small" class="stat-card">
          <a-statistic title="配送中" :value="deliveringCount" :value-style="{ color: '#1890ff' }"><template #icon><CarOutlined /></template></a-statistic>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="8">
        <a-card size="small" class="stat-card">
          <a-statistic title="今日已完成" :value="doneCount" :value-style="{ color: '#52c41a' }"><template #icon><CheckCircleOutlined /></template></a-statistic>
        </a-card>
      </a-col>
    </a-row>

    <div class="toolbar" style="margin-top: 16px;">
      <a-input-search v-model:value="searchKey" placeholder="搜索订单号/房号" style="width: 240px;" allow-clear />
      <a-button type="primary" @click="showCreateModal"><PlusOutlined /> 新建送物订单</a-button>
    </div>

    <a-table
      :columns="columns"
      :data-source="filteredOrders"
      :pagination="{ pageSize: 10 }"
      row-key="id"
      size="middle"
      :loading="loading"
    >
      <template #bodyCell="{ column, record }">
        <template v-if="column.key === 'category'">
          <a-tag>{{ categoryLabel(record.item_category) }}</a-tag>
        </template>
        <template v-if="column.key === 'status'">
          <a-badge :status="deliveryBadge(record.status)" :text="deliveryStatusText(record.status)" />
        </template>
        <template v-if="column.key === 'created_at'">
          {{ formatTimeHHmm(record.created_at) }}
        </template>
        <template v-if="column.key === 'action'">
          <a-space>
            <a-button type="link" size="small" v-if="record.status === 'pending'" @click="startDelivery(record)">开始配送</a-button>
            <a-button type="link" size="small" v-if="record.status === 'delivering'" @click="completeDelivery(record)">送达确认</a-button>
            <a-popconfirm title="取消此订单？" @confirm="cancelOrder(record)">
              <a-button type="link" size="small" danger v-if="record.status === 'pending'">取消</a-button>
            </a-popconfirm>
          </a-space>
        </template>
      </template>
    </a-table>

    <a-modal v-model:open="modalVisible" title="新建送物订单" @ok="createDelivery" width="500px">
      <a-form :model="form" layout="vertical">
        <a-form-item label="目标房间" required>
          <a-select v-model:value="form.room_id" show-search placeholder="选择房间">
            <a-select-option v-for="r in hotelStore.rooms" :key="r.id" :value="r.id">{{ r.room_number }} - {{ r.room_name }}</a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item label="物品类别" required>
          <a-select v-model:value="form.item_category">
            <a-select-option value="beverage">饮品</a-select-option>
            <a-select-option value="food">食品</a-select-option>
            <a-select-option value="daily">日用品</a-select-option>
            <a-select-option value="other">其他</a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item label="物品名称" required>
          <a-input v-model:value="form.item_name" placeholder="如 矿泉水、方便面等" />
        </a-form-item>
        <a-form-item label="数量">
          <a-input-number v-model:value="form.quantity" :min="1" :max="20" style="width: 100%;" />
        </a-form-item>
        <a-form-item label="备注">
          <a-textarea v-model:value="form.note" :rows="2" placeholder="特殊要求..." />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { $notify, NotifyPreset } from '@/utils/notify'
import { SendOutlined, CarOutlined, CheckCircleOutlined, PlusOutlined } from '@ant-design/icons-vue'
import { useHotelStore } from '@/stores/hotel'
import { deliveryApi } from '@/api/delivery'
import { formatTimeHHmm } from '@/utils/date'

const hotelStore = useHotelStore()
const searchKey = ref('')
const modalVisible = ref(false)
const loading = ref(false)

const form = reactive({
  room_id: undefined as number | undefined,
  item_category: 'beverage' as 'beverage' | 'food' | 'daily' | 'other',
  item_name: '',
  quantity: 1,
  note: ''
})

const orders = ref<any[]>([])

const filteredOrders = computed(() => {
  const keyword = searchKey.value.trim().toLowerCase()
  if (!keyword) return orders.value
  return orders.value.filter(order =>
    String(order.order_no || '').toLowerCase().includes(keyword) ||
    String(order.room_number || '').toLowerCase().includes(keyword)
  )
})

const pendingCount = computed(() => orders.value.filter(o => o.status === 'pending').length)
const deliveringCount = computed(() => orders.value.filter(o => o.status === 'delivering').length)
const doneCount = computed(() => orders.value.filter(o => o.status === 'completed').length)

const columns = [
  { title: '订单号', dataIndex: 'order_no', width: 170 },
  { title: '房间', dataIndex: 'room_number', width: 70 },
  { title: '类别', dataIndex: 'item_category', key: 'category', width: 80 },
  { title: '物品', dataIndex: 'item_name', width: 120 },
  { title: '数量', dataIndex: 'quantity', width: 60 },
  { title: '备注', dataIndex: 'note', ellipsis: true },
  { title: '状态', dataIndex: 'status', key: 'status', width: 90 },
  { title: '创建时间', dataIndex: 'created_at', key: 'created_at', width: 160 },
  { title: '操作', key: 'action', width: 140 }
]

function categoryLabel(c: string): string {
  return ({ beverage: '🍶 饮品', food: '🍕 食品', daily: '🧴 日用品', other: '📦 其他' } as Record<string, string>)[c] || c
}

function deliveryBadge(s: string): string {
  return ({ pending: 'warning', processing: 'default', delivering: 'processing', completed: 'success' } as Record<string, string>)[s] || 'default'
}

function deliveryStatusText(s: string): string {
  return ({ pending: '待处理', processing: '处理中', delivering: '配送中', completed: '已送达' } as Record<string, string>)[s] || s
}

function showCreateModal() { modalVisible.value = true }

async function fetchOrders() {
  loading.value = true
  try {
    const res: any = await deliveryApi.getList({ pageSize: 200 })
    orders.value = res.data?.list || []
  } catch (error) {
    $notify.error({ title: '获取送物订单失败', description: '无法加载送物订单列表，请检查网络后重试 🔄' })
  } finally {
    loading.value = false
  }
}

async function createDelivery() {
  if (!form.room_id || !form.item_name) {
    $notify.warning({ title: '请填写必填项', description: '请选择目标房间并填写物品名称 📦' })
    return
  }
  try {
    await deliveryApi.create({
      room_id: form.room_id,
      item_category: form.item_category,
      item_name: form.item_name,
      quantity: form.quantity,
      note: form.note
    })
    NotifyPreset.deliveryCreated()
    modalVisible.value = false
    Object.assign(form, { room_id: undefined, item_category: 'beverage', item_name: '', quantity: 1, note: '' })
    await fetchOrders()
  } catch (error) {
    NotifyPreset.operationFailed('创建送物订单失败')
  }
}

function startDelivery(order: any) {
  order.status = 'delivering'
  $notify.info({ title: '已开始配送', description: `${order.order_no} 已派送，工作人员正在前往 🏃` })
}

async function completeDelivery(order: any) {
  try {
    await deliveryApi.complete(order.id)
    $notify.success({ title: '已送达确认', description: `${order.order_no} 已成功送达 ✅` })
    await fetchOrders()
  } catch (error) {
    NotifyPreset.operationFailed('送达确认失败')
  }
}

function cancelOrder(order: any) {
  order.status = 'cancelled'
  $notify.warning({ title: '订单已取消', description: `已取消 ${order.order_no} 🚫` })
}

onMounted(async () => {
  await hotelStore.fetchRooms({ pageSize: 300 })
  await fetchOrders()
})
</script>

<style scoped>
.stat-card { text-align: center; cursor: pointer; }
.toolbar { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px; }
</style>
