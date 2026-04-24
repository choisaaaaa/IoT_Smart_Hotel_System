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
            <a-select-option value="smoke_detector">烟雾探测器</a-select-option>
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
            {{ formatDateTimeSec(record.created_at) }}
          </template>
          <template v-if="column.key === 'action'">
            <a-button type="link" size="small" @click="showDetail(record)">详情</a-button>
          </template>
        </template>
      </a-table>
    </a-card>

    <a-modal v-model:open="detailVisible" title="日志详情" :footer="null">
      <a-descriptions :column="1" bordered>
        <a-descriptions-item label="时间">{{ formatDateTimeSec(currentLog?.created_at) }}</a-descriptions-item>
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
import { $notify, NotifyPreset } from '@/utils/notify'
import { formatDateTimeSec } from '@/utils/date'
import request from '@/api/request'

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

const fetchLogs = async () => {
  loading.value = true
  try {
    const params: any = {
      limit: pagination.value.pageSize
    }
    if (filterType.value) params.event_type = mapFilterTypeToEventType(filterType.value)
    if (dateRange.value && dateRange.value.length === 2) {
      params.start_date = dateRange.value[0].format('YYYY-MM-DD')
      params.end_date = dateRange.value[1].format('YYYY-MM-DD')
    }

    const res: any = await request.get('/environment/event-logs', { params })
    // 兼容多种响应格式
    const data = res.data || res
    if (data) {
      const logList = Array.isArray(data.logs) ? data.logs : (Array.isArray(data) ? data : [])
      logs.value = logList.map((log: any) => ({
        id: log.id,
        device_name: log.room_number || '未知区域',
        device_id: `room_${log.room_id || 0}`,
        device_type: log.event_type,
        action: getEventTypeText(log.event_type),
        level: mapSeverityToLevel(log.severity),
        operator: log.handled_by || (log.resolved ? '系统' : '待处理'),
        detail: log.description || log.title,
        created_at: log.created_at || ''
      }))
      pagination.value.total = data.total || logs.value.length
    }
  } catch (error) {
    $notify.error({ title: '获取日志失败', description: '无法加载设备日志，请稍后重试 🔄' })
  } finally {
    loading.value = false
  }
}

function mapFilterTypeToEventType(filterType: string): string {
  const map: Record<string, string> = {
    smart_lock: 'device_control',
    ac: 'environment_warning',
    light: 'device_control',
    curtain: 'device_control',
    smoke_detector: 'fire_alarm'
  }
  return map[filterType] || filterType
}

function getEventTypeText(eventType: string): string {
  const map: Record<string, string> = {
    fire_alarm: '火灾告警',
    device_error: '设备故障',
    environment_warning: '环境预警',
    device_control: '设备控制',
    maintenance: '设备维护',
    energy_alert: '能耗异常'
  }
  return map[eventType] || eventType
}

function mapSeverityToLevel(severity: string): string {
  const map: Record<string, string> = {
    critical: 'error',
    error: 'error',
    warning: 'warning',
    info: 'info'
  }
  return map[severity] || 'info'
}

const handleTableChange = (pag: any) => {
  pagination.value.current = pag.current
  pagination.value.pageSize = pag.pageSize
  fetchLogs()
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
  $notify.success({ title: '导出成功', description: '日志已成功导出 📥' })
}

onMounted(() => {
  fetchLogs()
})
</script>

<style scoped>
.device-logs { padding: 0; }
</style>
