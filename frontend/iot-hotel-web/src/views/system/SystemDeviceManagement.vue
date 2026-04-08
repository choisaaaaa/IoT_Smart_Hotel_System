<template>
  <div class="system-device-management">
    <a-card title="全局设备维护" :bordered="false">
      <div class="filter-bar" style="margin-bottom: 16px; display: flex; gap: 16px; align-items: center;">
        <a-input-search
          v-model:value="searchKey"
          placeholder="搜索设备ID/名称"
          style="width: 250px"
          allow-clear
        />
        <a-select v-model:value="filterHotel" placeholder="所属酒店" style="width: 200px" allow-clear>
          <a-select-option v-for="hotel in hotels" :key="hotel.id" :value="hotel.id">
            {{ hotel.hotel_name }}
          </a-select-option>
        </a-select>
        <a-select v-model:value="filterStatus" placeholder="状态" style="width: 120px" allow-clear>
          <a-select-option value="online">在线</a-select-option>
          <a-select-option value="offline">离线</a-select-option>
          <a-select-option value="error">异常</a-select-option>
        </a-select>
        <a-button @click="fetchDevices">刷新</a-button>
      </div>

      <a-table
        :columns="columns"
        :data-source="filteredDevices"
        :loading="loading"
        row-key="id"
        size="small"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'hotel'">
            <a-tag color="blue">{{ record.hotel_name || '未绑定' }}</a-tag>
          </template>
          <template v-if="column.key === 'device_status'">
            <a-badge :status="badgeStatus(record.device_status)" :text="statusText(record.device_status)" />
          </template>
          <template v-if="column.key === 'audit_status'">
            <a-tag :color="auditColor(record.audit_status)">{{ auditText(record.audit_status) }}</a-tag>
          </template>
          <template v-if="column.key === 'action'">
            <a-space>
              <a-button type="link" size="small" @click="showDetail(record)">详情</a-button>
              <a-popconfirm title="确定要删除此设备吗？" @confirm="handleDelete(record.id)">
                <a-button type="link" size="small" danger>删除</a-button>
              </a-popconfirm>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

    <!-- 设备详情弹窗 -->
    <a-modal v-model:open="detailVisible" title="设备详细信息" :footer="null">
      <a-descriptions bordered column="1" size="small">
        <a-descriptions-item label="设备 ID">{{ currentDevice.device_id }}</a-descriptions-item>
        <a-descriptions-item label="设备名称">{{ currentDevice.device_name }}</a-descriptions-item>
        <a-descriptions-item label="所属酒店">{{ currentDevice.hotel_name }} (ID: {{ currentDevice.hotel_id }})</a-descriptions-item>
        <a-descriptions-item label="设备类型">{{ currentDevice.device_type }}</a-descriptions-item>
        <a-descriptions-item label="固件版本">{{ currentDevice.firmware_version }}</a-descriptions-item>
        <a-descriptions-item label="IP 地址">{{ currentDevice.ip_address }}</a-descriptions-item>
        <a-descriptions-item label="MAC 地址">{{ currentDevice.mac_address }}</a-descriptions-item>
        <a-descriptions-item label="通信密钥"><code>{{ currentDevice.device_key || '尚未生成' }}</code></a-descriptions-item>
        <a-descriptions-item label="最后在线">{{ formatTime(currentDevice.last_seen) }}</a-descriptions-item>
      </a-descriptions>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { message } from 'ant-design-vue'
import { deviceApi } from '@/api/device'
import { hotelManageApi, type HotelManageInfo } from '@/api/hotel-manage'
import dayjs from 'dayjs'

const columns = [
  { title: '设备ID', dataIndex: 'device_id', key: 'device_id' },
  { title: '名称', dataIndex: 'device_name', key: 'device_name' },
  { title: '所属酒店', key: 'hotel' },
  { title: '运行状态', key: 'device_status' },
  { title: '审核状态', key: 'audit_status' },
  { title: '最后通信', dataIndex: 'last_seen', key: 'last_seen', customRender: ({ text }: any) => formatTime(text) },
  { title: '操作', key: 'action' }
]

const devices = ref<any[]>([])
const hotels = ref<HotelManageInfo[]>([])
const loading = ref(false)
const searchKey = ref('')
const filterHotel = ref<number | undefined>(undefined)
const filterStatus = ref<string | undefined>(undefined)

const detailVisible = ref(false)
const currentDevice = ref<any>({})

const filteredDevices = computed(() => {
  return devices.value.filter(d => {
    const matchSearch = !searchKey.value || 
      d.device_id.toLowerCase().includes(searchKey.value.toLowerCase()) ||
      d.device_name.toLowerCase().includes(searchKey.value.toLowerCase())
    const matchHotel = !filterHotel.value || d.hotel_id === filterHotel.value
    const matchStatus = !filterStatus.value || d.device_status === filterStatus.value
    return matchSearch && matchHotel && matchStatus
  })
})

const badgeStatus = (s: string) => ({ online: 'success', offline: 'default', error: 'error' } as any)[s] || 'default'
const statusText = (s: string) => ({ online: '在线', offline: '离线', error: '异常' } as any)[s] || s
const auditColor = (s: string) => ({ approved: 'green', pending: 'orange', rejected: 'red' } as any)[s] || 'default'
const auditText = (s: string) => ({ approved: '已审核', pending: '待审核', rejected: '已拒绝' } as any)[s] || s
const formatTime = (t: string) => t ? dayjs(t).format('YYYY-MM-DD HH:mm:ss') : '-'

const fetchDevices = async () => {
  loading.value = true
  try {
    const res: any = await deviceApi.getDeviceList()
    const payload = res?.data
    devices.value = Array.isArray(payload?.data)
      ? payload.data
      : Array.isArray(payload)
        ? payload
        : []
  } finally {
    loading.value = false
  }
}

const fetchHotels = async () => {
  try {
    const res: any = await hotelManageApi.getAllHotels()
    const payload = res?.data
    hotels.value = Array.isArray(payload?.data)
      ? payload.data
      : Array.isArray(payload)
        ? payload
        : []
  } catch (error) {}
}

const showDetail = (record: any) => {
  currentDevice.value = record
  detailVisible.value = true
}

const handleDelete = async (id: number) => {
  try {
    await deviceApi.deleteDevice(id)
    message.success('设备已删除')
    fetchDevices()
  } catch (error) {
    message.error('删除失败')
  }
}

onMounted(() => {
  fetchDevices()
  fetchHotels()
})
</script>

<style scoped>
.system-device-management { padding: 0; }
</style>
