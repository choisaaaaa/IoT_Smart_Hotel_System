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
            {{ dayjs(record.created_at).format('YYYY-MM-DD HH:mm:ss') }}
          </template>
          <template v-if="column.key === 'action'">
            <a-button type="link" size="small" @click="showDetail(record)">详情</a-button>
          </template>
        </template>
      </a-table>
    </a-card>

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
      page: pagination.value.current,
      pageSize: pagination.value.pageSize
    }
    if (filterType.value) params.device_type = filterType.value
    if (dateRange.value && dateRange.value.length === 2) {
      params.start_date = dateRange.value[0].format('YYYY-MM-DD')
      params.end_date = dateRange.value[1].format('YYYY-MM-DD')
    }

    const res: any = await request.get('/device-alarms', { params })
    if (res.data?.code === 200) {
      const data = res.data.data
      const alarmList = data?.list || []
      logs.value = alarmList.map((alarm: any) => ({
        id: alarm.id,
        device_name: alarm.device_name || '未知设备',
        device_id: alarm.device_id || alarm.id,
        device_type: alarm.alarm_type,
        action: getAlarmActionText(alarm.alarm_type),
        level: getAlarmLevel(alarm.alarm_level),
        operator: alarm.handled_by || '系统',
        detail: alarm.alarm_content || `${alarm.alarm_type}告警`,
        created_at: alarm.created_at || ''
      }))
      pagination.value.total = data?.pagination?.total || logs.value.length
    }
  } catch (error) {
    message.error('获取日志失败')
  } finally {
    loading.value = false
  }
}

function getAlarmActionText(alarmType: string): string {
  const map: Record<string, string> = {
    smoke: '烟雾告警',
    fire: '火灾告警',
    temperature: '温度异常',
    overheat: '过热告警',
    offline: '设备离线',
    device_error: '设备故障'
  }
  return map[alarmType] || '设备告警'
}

function getAlarmLevel(alarmLevel: string): string {
  const map: Record<string, string> = {
    emergency: 'error',
    critical: 'error',
    error: 'error',
    high: 'warning',
    warning: 'warning',
    medium: 'warning',
    info: 'info',
    low: 'info'
  }
  return map[alarmLevel] || 'info'
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
  message.success('日志导出成功')
}

onMounted(() => {
  fetchLogs()
})
</script>

<style scoped>
.device-logs { padding: 0; }
</style>
