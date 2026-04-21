<template>
  <div class="device-logs">
    <a-card title="设备操作日志" :bordered="false">
      <template #extra>
        <a-space>
          <a-range-picker v-model:value="dateRange" @change="fetchLogs" />
          <a-select v-model:value="filterType" placeholder="设备类型" allowClear style="width: 120px" @change="fetchLogs">
            <a-select-option value="">全部</a-select-option>
            <a-select-option value="smart_lock">智能门锁</a-select-option>
            <a-select-option value="ac">空调</a-select-option>
            <a-select-option value="light">灯光</a-select-option>
            <a-select-option value="curtain">窗帘</a-select-option>
          </a-select>
          <a-button type="primary" @click="fetchLogs">
            <ReloadOutlined /> 刷新
          </a-button>
          <a-button @click="exportLogs">
            <DownloadOutlined /> 导出
          </a-button>
        </a-space>
      </template>

      <a-table
        :columns="columns"
        :data-source="logs"
        :loading="loading"
        :pagination="pagination"
        row-key="id"
        size="middle"
        @change="handleTableChange"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'level'">
            <a-tag :color="getLevelColor(record.level)">{{ getLevelText(record.level) }}</a-tag>
          </template>
          <template v-if="column.key === 'created_at'">
            {{ dayjs(record.created_at).format('YYYY-MM-DD HH:mm:ss') }}
          </template>
          <template v-if="column.key === 'action'">
            <a-button type="link" size="small" @click="showDetail(record)">详情</a-button>
          </template>
        </template>
      </a-table>
    </a-card>

    <!-- 详情弹窗 -->
    <a-modal v-model:open="detailVisible" title="日志详情" :footer="null">
      <a-descriptions :column="1" bordered>
        <a-descriptions-item label="时间">{{ currentLog?.created_at }}</a-descriptions-item>
        <a-descriptions-item label="设备">{{ currentLog?.device_name }} ({{ currentLog?.device_id }})</a-descriptions-item>
        <a-descriptions-item label="操作">{{ currentLog?.action }}</a-descriptions-item>
        <a-descriptions-item label="级别">
          <a-tag :color="getLevelColor(currentLog?.level)">{{ getLevelText(currentLog?.level) }}</a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="操作人">{{ currentLog?.operator || '系统' }}</a-descriptions-item>
        <a-descriptions-item label="详情">{{ currentLog?.detail }}</a-descriptions-item>
      </a-descriptions>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ReloadOutlined, DownloadOutlined } from '@ant-design/icons-vue'
import { message } from 'ant-design-vue'
import dayjs from 'dayjs'

const loading = ref(false)
const logs = ref<any[]>([])
const dateRange = ref<any>(null)
const filterType = ref('')
const detailVisible = ref(false)
const currentLog = ref<any>(null)

const pagination = ref({
  current: 1,
  pageSize: 20,
  total: 0,
  showSizeChanger: true,
  showTotal: (total: number) => `共 ${total} 条`
})

const columns = [
  { title: '时间', key: 'created_at', width: 180 },
  { title: '设备名称', dataIndex: 'device_name', key: 'device_name', width: 150 },
  { title: '设备ID', dataIndex: 'device_id', key: 'device_id', width: 200 },
  { title: '操作', dataIndex: 'action', key: 'action' },
  { title: '级别', key: 'level', width: 100 },
  { title: '操作人', dataIndex: 'operator', key: 'operator', width: 120 },
  { title: '操作', key: 'action_col', width: 80 }
]

// 模拟日志数据
const generateMockLogs = () => {
  const actions = [
    { action: '设备上线', level: 'info' },
    { action: '设备离线', level: 'warning' },
    { action: '开关控制', level: 'info' },
    { action: '温度调节', level: 'info' },
    { action: '异常报警', level: 'error' },
    { action: '固件更新', level: 'info' },
    { action: '配置修改', level: 'info' }
  ]
  
  const devices = [
    { name: '301门锁', id: 'lock_301', type: 'smart_lock' },
    { name: '301空调', id: 'ac_301', type: 'ac' },
    { name: '301灯光', id: 'light_301', type: 'light' },
    { name: '302门锁', id: 'lock_302', type: 'smart_lock' },
    { name: '302空调', id: 'ac_302', type: 'ac' }
  ]
  
  const mockLogs = []
  for (let i = 0; i < 50; i++) {
    const action = actions[Math.floor(Math.random() * actions.length)]
    const device = devices[Math.floor(Math.random() * devices.length)]
    const date = dayjs().subtract(Math.floor(Math.random() * 7), 'day').subtract(Math.floor(Math.random() * 24), 'hour')
    
    mockLogs.push({
      id: i + 1,
      device_name: device.name,
      device_id: device.id,
      device_type: device.type,
      action: action.action,
      level: action.level,
      operator: Math.random() > 0.3 ? '管理员' : '系统',
      detail: `${action.action} - 设备${device.name}(${device.id})`,
      created_at: date.format('YYYY-MM-DD HH:mm:ss')
    })
  }
  
  return mockLogs.sort((a, b) => dayjs(b.created_at).unix() - dayjs(a.created_at).unix())
}

const fetchLogs = async () => {
  loading.value = true
  try {
    // 模拟API调用
    await new Promise(resolve => setTimeout(resolve, 500))
    logs.value = generateMockLogs()
    pagination.value.total = logs.value.length
  } catch (error) {
    message.error('获取日志失败')
  } finally {
    loading.value = false
  }
}

const handleTableChange = (pag: any) => {
  pagination.value.current = pag.current
  pagination.value.pageSize = pag.pageSize
}

const getLevelColor = (level: string) => {
  const colors: Record<string, string> = {
    info: 'blue',
    warning: 'orange',
    error: 'red',
    debug: 'gray'
  }
  return colors[level] || 'blue'
}

const getLevelText = (level: string) => {
  const texts: Record<string, string> = {
    info: '信息',
    warning: '警告',
    error: '错误',
    debug: '调试'
  }
  return texts[level] || level
}

const showDetail = (record: any) => {
  currentLog.value = record
  detailVisible.value = true
}

const exportLogs = () => {
  message.success('日志导出成功')
  // 实际项目中这里会生成CSV文件下载
}

onMounted(() => {
  fetchLogs()
})
</script>

<style scoped>
.device-logs { padding: 0; }
</style>
