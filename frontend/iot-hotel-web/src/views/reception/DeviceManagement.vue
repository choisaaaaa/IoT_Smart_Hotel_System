
<template>
  <div class="device-management">
    <a-card title="主控设备管理" :bordered="false">
      <template #extra>
        <a-button type="primary" @click="fetchDevices">
          <SyncOutlined /> 刷新状态
        </a-button>
      </template>

      <a-table :columns="columns" :data-source="devices" :loading="loading" row-key="id">
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'device_type'">
            <a-tag color="blue">{{ getDeviceTypeName(record.device_type) }}</a-tag>
          </template>
          <template v-if="column.key === 'device_status'">
            <a-badge :status="record.device_status === 'online' ? 'success' : 'error'" :text="record.device_status === 'online' ? '在线' : '离线'" />
          </template>
          <template v-if="column.key === 'last_online'">
            {{ record.last_online ? formatDateTime(record.last_online) : '从未上线' }}
          </template>
          <template v-if="column.key === 'action'">
            <a-space>
              <a-button type="link" size="small" @click="testDevice(record)">测试通信</a-button>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { SyncOutlined } from '@ant-design/icons-vue'
import { message } from 'ant-design-vue'
import request from '@/api/request'
import { formatDateTime } from '@/utils/date'

const columns = [
  { title: '设备名称', dataIndex: 'device_name', key: 'device_name' },
  { title: '设备ID', dataIndex: 'device_id', key: 'device_id' },
  { title: '类型', key: 'device_type', width: 120 },
  { title: '状态', key: 'device_status', width: 100 },
  { title: '区域/房号', dataIndex: 'area', key: 'area' },
  { title: '最后在线', key: 'last_online' },
  { title: '操作', key: 'action', width: 120 }
]

const devices = ref([])
const loading = ref(false)

const getDeviceTypeName = (type: string) => {
  const types: Record<string, string> = {
    'front_desk': '前台发卡器',
    'smart_lock': '智能门锁',
    'gateway': '智能网关',
    'room_controller': '客控主机'
  }
  return types[type] || type
}

const fetchDevices = async () => {
  loading.value = true
  try {
    const res: any = await request.get('/devices', { params: { audit_status: 'approved' } })
    // 后端返回 { success: true, data: [...] }
    devices.value = res && res.success && Array.isArray(res.data) ? res.data : []
  } catch (error) {
    message.error('获取设备列表失败')
    console.error('获取设备列表失败:', error)
  } finally {
    loading.value = false
  }
}

const testDevice = async (record: any) => {
  try {
    await request.post(`/devices/${record.id}/command`, {
      command: 'ping',
      value: '1'
    })
    message.success('测试指令已下发，请观察设备反馈')
  } catch (error) {
    message.error('下发失败')
  }
}

onMounted(fetchDevices)
</script>
