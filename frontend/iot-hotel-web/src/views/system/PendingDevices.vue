<template>
  <div class="pending-devices">
    <a-card title="待审核设备" :bordered="false">
      <template #extra>
        <a-button type="primary" @click="fetchPendingDevices">
          <SyncOutlined /> 刷新
        </a-button>
      </template>

      <a-alert
        v-if="pendingDevices.length === 0"
        message="暂无待审核设备"
        description="当新的硬件设备连接到MQTT时，会显示在这里等待审核"
        type="info"
        show-icon
        style="margin-bottom: 16px"
      />

      <a-table
        v-else
        :columns="columns"
        :data-source="pendingDevices"
        :loading="loading"
        row-key="id"
        size="small"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'device_type'">
            <a-tag color="blue">{{ getDeviceTypeName(record.device_type) }}</a-tag>
          </template>
          <template v-if="column.key === 'device_status'">
            <a-badge :status="record.device_status === 'online' ? 'success' : 'default'" :text="record.device_status === 'online' ? '在线' : '离线'" />
          </template>
          <template v-if="column.key === 'last_seen'">
            {{ record.last_seen ? dayjs(record.last_seen).format('YYYY-MM-DD HH:mm:ss') : '-' }}
          </template>
          <template v-if="column.key === 'action'">
            <a-space>
              <a-button type="primary" size="small" @click="showAuditModal(record)">
                审核
              </a-button>
              <a-button type="link" size="small" danger @click="rejectDevice(record.id)">
                拒绝
              </a-button>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

    <!-- 审核弹窗 -->
    <a-modal
      v-model:open="auditVisible"
      title="审核设备"
      @ok="handleAudit"
      :confirmLoading="auditLoading"
    >
      <a-form :model="auditForm" layout="vertical">
        <a-form-item label="设备ID">
          <a-input v-model:value="currentDevice.device_id" disabled />
        </a-form-item>
        <a-form-item label="设备名称">
          <a-input v-model:value="currentDevice.device_name" disabled />
        </a-form-item>
        <a-form-item label="设备类型">
          <a-input :value="getDeviceTypeName(currentDevice.device_type)" disabled />
        </a-form-item>
        <a-form-item label="分配房间" required>
          <a-select
            v-model:value="auditForm.room_id"
            placeholder="选择房间"
            style="width: 100%"
          >
            <a-select-option v-for="room in rooms" :key="room.id" :value="room.id">
              {{ room.room_number }} ({{ room.room_type }})
            </a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item label="区域/位置">
          <a-input v-model:value="auditForm.area" placeholder="如：前台、走廊、房间301" />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { SyncOutlined } from '@ant-design/icons-vue'
import { message } from 'ant-design-vue'
import { deviceApi } from '@/api/device'
import { roomApi } from '@/api/room'
import dayjs from 'dayjs'

const columns = [
  { title: '设备ID', dataIndex: 'device_id', key: 'device_id', width: 200 },
  { title: '设备名称', dataIndex: 'device_name', key: 'device_name' },
  { title: '类型', key: 'device_type', width: 120 },
  { title: '状态', key: 'device_status', width: 100 },
  { title: 'IP地址', dataIndex: 'ip_address', key: 'ip_address', width: 150 },
  { title: '最后通信', key: 'last_seen', width: 180 },
  { title: '操作', key: 'action', width: 150, fixed: 'right' }
]

const pendingDevices = ref<any[]>([])
const rooms = ref<any[]>([])
const loading = ref(false)
const auditVisible = ref(false)
const auditLoading = ref(false)
const currentDevice = ref<any>({})

const auditForm = ref({
  room_id: undefined as number | undefined,
  area: ''
})

const getDeviceTypeName = (type: string) => {
  const types: Record<string, string> = {
    'front_desk': '前台发卡器',
    'floor': '楼控节点',
    'room': '客房终端',
    'smart_lock': '智能门锁',
    'gateway': '智能网关'
  }
  return types[type] || type
}

const fetchPendingDevices = async () => {
  loading.value = true
  try {
    const res: any = await deviceApi.getDeviceList({ audit_status: 'pending' })
    pendingDevices.value = res?.data?.data || []
  } catch (error) {
    message.error('获取待审核设备失败')
  } finally {
    loading.value = false
  }
}

const fetchRooms = async () => {
  try {
    const res: any = await roomApi.getRoomList()
    rooms.value = res?.data?.data || []
  } catch (error) {
    console.error('获取房间列表失败', error)
  }
}

const showAuditModal = (record: any) => {
  currentDevice.value = record
  auditForm.value = {
    room_id: undefined,
    area: ''
  }
  auditVisible.value = true
}

const handleAudit = async () => {
  if (!auditForm.value.room_id) {
    message.error('请选择分配的房间')
    return
  }

  auditLoading.value = true
  try {
    await deviceApi.auditDevice(currentDevice.value.id, {
      status: 'approved',
      room_id: auditForm.value.room_id,
      area: auditForm.value.area
    })
    message.success('设备审核通过')
    auditVisible.value = false
    fetchPendingDevices()
  } catch (error) {
    message.error('审核失败')
  } finally {
    auditLoading.value = false
  }
}

const rejectDevice = async (id: number) => {
  try {
    await deviceApi.auditDevice(id, { status: 'rejected' })
    message.success('已拒绝该设备')
    fetchPendingDevices()
  } catch (error) {
    message.error('操作失败')
  }
}

onMounted(() => {
  fetchPendingDevices()
  fetchRooms()
  // 每10秒自动刷新
  setInterval(fetchPendingDevices, 10000)
})
</script>

<style scoped>
.pending-devices { padding: 0; }
</style>
