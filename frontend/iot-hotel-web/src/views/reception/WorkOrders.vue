<template>
  <div class="work-orders">
    <a-row :gutter="[16, 16]">
      <a-col :xs="24" :sm="8">
        <a-card class="stat-card" @click="filterByStatus('pending')">
          <a-statistic title="待处理" :value="pendingCount" :value-style="{ color: '#faad14' }"><template #prefix><ClockCircleOutlined /></template></a-statistic>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="8">
        <a-card class="stat-card" @click="filterByStatus('processing')">
          <a-statistic title="处理中" :value="processingCount" :value-style="{ color: '#1890ff' }"><template #prefix><ToolOutlined /></template></a-statistic>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="8">
        <a-card class="stat-card" @click="filterByStatus('completed')">
          <a-statistic title="已完成(今日)" :value="completedCount" :value-style="{ color: '#52c41a' }"><template #prefix><CheckCircleOutlined /></template></a-statistic>
        </a-card>
      </a-col>
    </a-row>

    <div class="toolbar" style="margin-top: 16px;">
      <a-space>
        <a-radio-group v-model:value="statusFilter" button-style="solid" size="small">
          <a-radio-button value="">全部</a-radio-button>
          <a-radio-button value="pending">待处理</a-radio-button>
          <a-radio-button value="assigned">已分配</a-radio-button>
          <a-radio-button value="processing">处理中</a-radio-button>
          <a-radio-button value="completed">已完成</a-radio-button>
        </a-radio-group>
      </a-space>
      <a-button type="primary" @click="showCreateModal"><PlusOutlined /> 新建维修工单</a-button>
    </div>

    <a-tabs v-model:activeKey="activeTab">
      <a-tab-pane key="maintenance" tab="维修处理">
        <a-table
          :columns="maintenanceColumns"
          :data-source="filteredOrders"
          :pagination="{ pageSize: 10 }"
          row-key="id"
          size="middle"
          :loading="loading"
        >
          <template #bodyCell="{ column, record }">
            <template v-if="column.key === 'priority'">
              <a-tag :color="priorityColor(record.priority)">{{ priorityText(record.priority) }}</a-tag>
            </template>
            <template v-if="column.key === 'status'">
              <a-badge :status="orderBadge(record.status)" :text="orderStatusText(record.status)" />
            </template>
            <template v-if="column.key === 'created_at'">
              {{ formatTimeHHmm(record.created_at) }}
            </template>
            <template v-if="column.key === 'action'">
              <a-space>
                <a-button type="link" size="small" v-if="record.status === 'pending'" @click="startProcess(record)">开始处理</a-button>
                <a-button type="link" size="small" v-if="record.status === 'assigned'" @click="startWork(record)">开始维修</a-button>
                <a-button type="link" size="small" v-if="record.status === 'assigned' || record.status === 'processing'" @click="completeOrder(record)">完成</a-button>
              </a-space>
            </template>
          </template>
        </a-table>
      </a-tab-pane>
      <a-tab-pane key="cleaning" tab="打扫处理">
        <a-table
          :columns="cleaningColumns"
          :data-source="cleaningTasks"
          :pagination="{ pageSize: 10 }"
          row-key="id"
          size="middle"
        >
          <template #bodyCell="{ column, record }">
            <template v-if="column.key === 'status'">
              <a-tag :color="record.room_status === 'cleaning' ? 'warning' : 'success'">
                {{ record.room_status === 'cleaning' ? '待清扫' : '可售房' }}
              </a-tag>
            </template>
            <template v-if="column.key === 'action'">
              <a-space>
                <a-button
                  v-if="record.room_status !== 'cleaning'"
                  type="link"
                  size="small"
                  @click="markCleaning(record.id)"
                >
                  标记待扫
                </a-button>
                <a-button
                  v-if="record.room_status === 'cleaning'"
                  type="link"
                  size="small"
                  @click="finishCleaning(record.id)"
                >
                  完成打扫
                </a-button>
              </a-space>
            </template>
          </template>
        </a-table>
      </a-tab-pane>
    </a-tabs>

    <a-modal v-model:open="modalVisible" title="新建工单" @ok="createOrder" width="550px">
      <a-form :model="newOrder" layout="vertical">
        <a-form-item label="关联房间">
          <a-select v-model:value="newOrder.room_id" show-search placeholder="选择房间" allow-clear>
            <a-select-option v-for="r in hotelStore.rooms" :key="r.id" :value="r.id">{{ r.room_number }}</a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item label="优先级">
          <a-radio-group v-model:value="newOrder.priority">
            <a-radio value="low">低</a-radio>
            <a-radio value="medium">中</a-radio>
            <a-radio value="high">高</a-radio>
            <a-radio value="urgent">紧急</a-radio>
          </a-radio-group>
        </a-form-item>
        <a-form-item label="问题描述" required>
          <a-textarea v-model:value="newOrder.description" :rows="3" placeholder="请详细描述问题..." />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { message } from 'ant-design-vue'
import { ClockCircleOutlined, ToolOutlined, CheckCircleOutlined, PlusOutlined } from '@ant-design/icons-vue'
import { useHotelStore } from '@/stores/hotel'
import { useAppStore } from '@/stores/app'
import { maintenanceApi } from '@/api/maintenance'
import { roomApi } from '@/api/room'
import { formatTimeHHmm } from '@/utils/date'

const hotelStore = useHotelStore()
const appStore = useAppStore()
const activeTab = ref('maintenance')
const statusFilter = ref('')
const modalVisible = ref(false)
const loading = ref(false)
const allOrders = ref<any[]>([])
const newOrder = reactive({
  room_id: undefined as number | undefined,
  fault_type: '设备故障',
  description: '',
  priority: 'medium' as 'low' | 'medium' | 'high' | 'urgent'
})

const filteredOrders = computed(() => {
  return allOrders.value.filter(o => {
    if (statusFilter.value && o.status !== statusFilter.value) return false
    return true
  })
})

const cleaningTasks = computed(() => {
  return hotelStore.rooms
    .filter(room => ['cleaning', 'available', 'occupied'].includes(room.room_status))
    .map(room => ({
      ...room,
      room_type_display: room.room_type_name || room.room_type
    }))
})

const pendingCount = computed(() => allOrders.value.filter(o => o.status === 'pending').length)
const processingCount = computed(() => allOrders.value.filter(o => o.status === 'processing').length)
const completedCount = computed(() => allOrders.value.filter(o => o.status === 'completed').length)

function filterByStatus(s: string) { statusFilter.value = s }

function priorityColor(p: string): string {
  return ({ low: 'default', medium: 'blue', high: 'orange', urgent: 'red' } as Record<string, string>)[p] || 'default'
}
function priorityText(p: string): string {
  return ({ low: '低', medium: '中', high: '高', urgent: '紧急' } as Record<string, string>)[p] || p
}
function orderBadge(s: string): string {
  return ({ pending: 'warning', assigned: 'processing', processing: 'processing', completed: 'success' } as Record<string, string>)[s] || 'default'
}
function orderStatusText(s: string): string {
  return ({ pending: '待处理', assigned: '已分配', processing: '处理中', completed: '已完成' } as Record<string, string>)[s] || s
}

const maintenanceColumns = [
  { title: '工单号', dataIndex: 'ticket_no', width: 160 },
  { title: '房间', dataIndex: 'room_number', width: 70 },
  { title: '类型', dataIndex: 'fault_type', width: 100 },
  { title: '描述', dataIndex: 'fault_description', ellipsis: true },
  { title: '优先级', dataIndex: 'priority', key: 'priority', width: 80 },
  { title: '状态', dataIndex: 'status', key: 'status', width: 90 },
  { title: '创建时间', dataIndex: 'created_at', width: 160 },
  { title: '操作', key: 'action', width: 150 }
]

const cleaningColumns = [
  { title: '房号', dataIndex: 'room_number', width: 80 },
  { title: '房型', dataIndex: 'room_type_display', width: 120 },
  { title: '楼层', dataIndex: 'floor', width: 70 },
  { title: '当前状态', dataIndex: 'room_status', key: 'status', width: 100 },
  { title: '操作', key: 'action', width: 150 }
]

function showCreateModal() { modalVisible.value = true }

async function fetchOrders() {
  loading.value = true
  try {
    const res: any = await maintenanceApi.getList({ pageSize: 200 })
    allOrders.value = (res.data?.list || []).map((item: any) => ({
      ...item,
      ticket_no: item.ticket_no || `MT${String(item.id).padStart(6, '0')}`
    }))
  } catch (error) {
    message.error('获取工单失败')
  } finally {
    loading.value = false
  }
}

async function createOrder() {
  if (!newOrder.room_id || !newOrder.description) {
    message.warning('请填写必填项')
    return
  }
  try {
    await maintenanceApi.create({
      room_id: newOrder.room_id,
      fault_type: newOrder.fault_type,
      fault_description: newOrder.description,
      priority: newOrder.priority
    })
    message.success('工单已创建')
    modalVisible.value = false
    Object.assign(newOrder, { room_id: undefined, fault_type: '设备故障', description: '', priority: 'medium' })
    await fetchOrders()
  } catch (error) {
    message.error('创建失败')
  }
}

async function startProcess(order: any) {
  try {
    const username = appStore.userInfo?.username || '前台'
    await maintenanceApi.assign(order.id, username)
    message.info(`工单 ${order.ticket_no} 已分配给 ${username}`)
    await fetchOrders()
  } catch (error) {
    message.error('操作失败')
  }
}

async function startWork(order: any) {
  try {
    await maintenanceApi.updateStatus(order.id, 'processing')
    message.info(`工单 ${order.ticket_no} 已开始维修`)
    await fetchOrders()
  } catch (error) {
    message.error('操作失败')
  }
}

async function completeOrder(order: any) {
  try {
    await maintenanceApi.complete(order.id)
    message.success(`${order.ticket_no} 已完成`)
    await fetchOrders()
    await hotelStore.fetchRooms({ pageSize: 300 })
  } catch (error) {
    message.error('操作失败')
  }
}

async function markCleaning(roomId: number) {
  try {
    await roomApi.updateRoomStatus(roomId, 'cleaning')
    message.success('已标记为待清扫')
    await hotelStore.fetchRooms({ pageSize: 300 })
  } catch (error) {
    message.error('状态更新失败')
  }
}

async function finishCleaning(roomId: number) {
  try {
    await roomApi.updateRoomStatus(roomId, 'available')
    message.success('打扫完成，房间已可售')
    await hotelStore.fetchRooms({ pageSize: 300 })
  } catch (error) {
    message.error('状态更新失败')
  }
}

onMounted(() => {
  hotelStore.fetchRooms({ pageSize: 300 })
  fetchOrders()
})
</script>

<style scoped>
.stat-card { cursor: pointer; transition: transform .2s; text-align: center; }
.stat-card:hover { transform: translateY(-2px); }
.toolbar { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px; }
</style>
