<template>
  <div class="fire-alarm-panel">
    <a-row :gutter="[16, 16]" style="margin-bottom: 16px;">
      <a-col :xs="24" :sm="8">
        <a-card size="small" class="alarm-summary critical">
          <a-statistic title="活跃警报" :value="alarmSummary.active_count || 0" :value-style="{ color: '#ff4d4f', fontSize: '28px' }">
            <template #prefix><WarningFilled /></template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="8">
        <a-card size="small" class="alarm-summary warning">
          <a-statistic title="待确认" :value="alarmSummary.acknowledged_count || 0" :value-style="{ color: '#faad14', fontSize: '28px' }">
            <template #prefix><ExclamationCircleFilled /></template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="8">
        <a-card size="small" class="alarm-summary success">
          <a-statistic title="今日已解决" :value="alarmSummary.resolved_today || 0" :value-style="{ color: '#52c41a', fontSize: '28px' }">
            <template #prefix><CheckCircleFilled /></template>
          </a-statistic>
        </a-card>
      </a-col>
    </a-row>

    <a-alert
      v-if="(alarmSummary.active_count || 0) > 0"
      message="⚠️ 存在活跃火警！"
      description="请立即处理以下活跃的消防警报，确保人员安全！"
      type="error"
      show-icon
      closable
      style="margin-bottom: 16px;"
    />

    <a-card :loading="loading">
      <template #title>
        <span>🚨 消防报警记录</span>
      </template>
      <template #extra>
        <a-space>
          <a-select v-model:value="filterStatus" placeholder="状态" allowClear style="width: 120px;" @change="fetchAlarms">
            <a-select-option value="">全部状态</a-select-option>
            <a-select-option value="active">活跃</a-select-option>
            <a-select-option value="acknowledged">待处理</a-select-option>
            <a-select-option value="resolved">已解决</a-select-option>
            <a-select-option value="false_alarm">误报</a-select-option>
          </a-select>
          <a-select v-model:value="filterSeverity" placeholder="严重程度" allowClear style="width: 110px;" @change="fetchAlarms">
            <a-select-option value="">全部</a-select-option>
            <a-select-option value="critical">严重</a-select-option>
            <a-select-option value="high">高</a-select-option>
            <a-select-option value="medium">中</a-select-option>
            <a-select-option value="low">低</a-select-option>
          </a-select>
          <a-button type="primary" size="small" :loading="loading" @click="fetchAlarms"><ReloadOutlined /> 刷新</a-button>
        </a-space>
      </template>

      <a-table :dataSource="alarms" :columns="alarmColumns" :loading="loading" rowKey="id" size="middle">
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'severity'">
            <a-tag :color="getSeverityColor(record.severity)" style="font-weight: bold;">{{ getSeverityText(record.severity) }}</a-tag>
          </template>

          <template v-if="column.key === 'status'">
            <a-badge :status="getAlarmStatusBadge(record.status)" :text="getAlarmStatusText(record.status)" />
          </template>

          <template v-if="column.key === 'room'">
            <a-tag color="blue">{{ record.room_number }}</a-tag>
          </template>

          <template v-if="column.key === 'triggered_at'">
            {{ formatTime(record.triggered_at) }}
          </template>

          <template v-if="column.key === 'action'">
            <a-space>
              <a-button
                v-if="record.status === 'active'"
                type="primary"
                size="small"
                danger
                @click="handleAcknowledge(record)"
              >
                确认处理
              </a-button>
              <a-button
                v-if="record.status === 'acknowledged'"
                type="primary"
                size="small"
                @click="handleResolve(record)"
              >
                标记解决
              </a-button>
              <a-button
                v-if="record.status === 'active'"
                size="small"
                @click="showDetail(record)"
              >
                详情
              </a-button>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

    <a-modal v-model:open="detailVisible" :title="`🚨 警报详情 - ${currentAlarm?.room_number}房`" width="650px" :footer="null">
      <a-descriptions v-if="currentAlarm" :column="2" bordered size="small">
        <a-descriptions-item label="警报ID">#{{ currentAlarm.id }}</a-descriptions-item>
        <a-descriptions-item label="房间号"><a-tag color="blue">{{ currentAlarm.room_number }}</a-tag></a-descriptions-item>
        <a-descriptions-item label="警报类型">{{ getAlarmTypeText(currentAlarm.alarm_type) }}</a-descriptions-item>
        <a-descriptions-item label="严重程度"><a-tag :color="getSeverityColor(currentAlarm.severity)">{{ getSeverityText(currentAlarm.severity) }}</a-tag></a-descriptions-item>
        <a-descriptions-item label="当前值">
          <span :style="{ fontWeight: 'bold', fontSize: '18px', color: currentAlarm.value > currentAlarm.threshold ? '#ff4d4f' : '#52c41a' }">
            {{ currentAlarm.value }}{{ getUnitByType(currentAlarm.alarm_type) }}
          </span>
        </a-descriptions-item>
        <a-descriptions-item label="阈值">{{ currentAlarm.threshold }}{{ getUnitByType(currentAlarm.alarm_type) }}</a-descriptions-item>
        <a-descriptions-item label="触发时间">{{ formatDateTime(currentAlarm.triggered_at) }}</a-descriptions-item>
        <a-descriptions-item label="当前状态"><a-badge :status="getAlarmStatusBadge(currentAlarm.status)" :text="getAlarmStatusText(currentAlarm.status)" /></a-descriptions-item>
        <a-descriptions-item label="描述" :span="2">{{ currentAlarm.description }}</a-descriptions-item>
        <a-descriptions-item v-if="currentAlarm.handled_by" label="处理人">{{ currentAlarm.handled_by }}</a-descriptions-item>
        <a-descriptions-item v-if="currentAlarm.resolved_at" label="解决时间">{{ formatDateTime(currentAlarm.resolved_at) }}</a-descriptions-item>
      </a-descriptions>

      <div style="margin-top: 16px; text-align: right;">
        <a-space>
          <a-button v-if="currentAlarm?.status === 'active'" type="primary" danger @click="handleAcknowledge(currentAlarm!)">确认并处理</a-button>
          <a-button @click="detailVisible = false">关闭</a-button>
        </a-space>
      </div>
    </a-modal>

    <a-modal v-model:open="resolveModalVisible" title="标记警报为已解决" :footer="null">
      <a-form layout="vertical">
        <a-form-item label="解决方案">
          <a-textarea v-model:value="resolution" placeholder="请输入处理结果和解决方案..." :rows="4" />
        </a-form-item>
        <a-form-item>
          <a-space style="float: right;">
            <a-button @click="resolveModalVisible = false">取消</a-button>
            <a-button type="primary" :loading="resolving" @click="confirmResolve">确定</a-button>
          </a-space>
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { message, Modal } from 'ant-design-vue'
import { WarningFilled, ExclamationCircleFilled, CheckCircleFilled, ReloadOutlined } from '@ant-design/icons-vue'
import { environmentApi, type FireAlarmRecord } from '@/api/environment'
import dayjs from 'dayjs'
import relativeTime from 'dayjs/plugin/relativeTime'
import { formatDateTime } from '@/utils/date'

dayjs.extend(relativeTime)

const loading = ref(false)
const alarms = ref<FireAlarmRecord[]>([])
const alarmSummary = reactive({
  active_count: 0,
  acknowledged_count: 0,
  resolved_today: 0,
  false_alarm_count: 0
})

const filterStatus = ref<string>('')
const filterSeverity = ref<string>('')

const detailVisible = ref(false)
const currentAlarm = ref<FireAlarmRecord | null>(null)

const resolveModalVisible = ref(false)
const resolving = ref(false)
const resolution = ref('')
const resolvingAlarmId = ref<number>(0)

const alarmColumns = [
  { title: '严重程度', key: 'severity', width: 100 },
  { title: '房间', key: 'room', width: 80 },
  { title: '类型', dataIndex: 'alarm_type', key: 'type', width: 100 },
  { title: '数值/阈值', key: 'value_threshold', width: 130, customRender: ({ record }: any) => `${record.value}/${record.threshold}` },
  { title: '触发时间', key: 'triggered_at', width: 150 },
  { title: '状态', key: 'status', width: 100 },
  { title: '操作', key: 'action', width: 180 }
]

async function fetchAlarms() {
  loading.value = true
  try {
    const params: any = {}
    if (filterStatus.value) params.status = filterStatus.value
    if (filterSeverity.value) params.severity = filterSeverity.value

    const res: any = await environmentApi.getFireAlarms(params)
    const data = res.data

    if (data) {
      alarms.value = data.alarms || []
      Object.assign(alarmSummary, data.summary)
    }
  } catch (err) {
  } finally {
    loading.value = false
  }
}

function showDetail(alarm: FireAlarmRecord) {
  currentAlarm.value = alarm
  detailVisible.value = true
}

async function handleAcknowledge(alarm: FireAlarmRecord) {
  Modal.confirm({
    title: '确认处理此警报？',
    content: `您即将确认处理 ${alarm.room_number} 房的${getSeverityText(alarm.severity)}级别警报`,
    okText: '确认',
    cancelText: '取消',
    async onOk() {
      try {
        await environmentApi.acknowledgeAlarm(alarm.id, {
          handler: 'admin',
          notes: '管理员正在处理中'
        })
        message.success('警报已确认，请尽快现场处理')
        fetchAlarms()
      } catch (err) {
        message.error('操作失败')
      }
    }
  })
}

function handleResolve(alarm: FireAlarmRecord) {
  resolvingAlarmId.value = alarm.id
  resolution.value = ''
  resolveModalVisible.value = true
}

async function confirmResolve() {
  if (!resolution.value.trim()) {
    message.warning('请输入解决方案')
    return
  }

  resolving.value = true
  try {
    await environmentApi.resolveAlarm(resolvingAlarmId.value, {
      resolution: resolution.value,
      handler: 'admin'
    })
    message.success('警报已标记为已解决')
    resolveModalVisible.value = false
    fetchAlarms()
  } catch (err) {
    message.error('操作失败')
  } finally {
    resolving.value = false
  }
}

function getSeverityColor(severity: string): string {
  return { critical: 'error', high: 'orange', medium: 'warning', low: 'blue' }[severity] || 'default'
}

function getSeverityText(severity: string): string {
  return { critical: '严重', high: '高', medium: '中', low: '低' }[severity] || severity
}

function getAlarmStatusBadge(status: string): string {
  return { active: 'error', acknowledged: 'warning', resolved: 'success', false_alarm: 'default' }[status] || 'default'
}

function getAlarmStatusText(status: string): string {
  return { active: '活跃', acknowledged: '待处理', resolved: '已解决', false_alarm: '误报' }[status] || status
}

function getAlarmTypeText(type: string): string {
  return { smoke: '烟雾探测', temperature: '温度异常', manual: '手动报警', fire_alarm: '消防报警', sos_alarm: 'SOS报警' }[type] || type
}

function getUnitByType(type: string): string {
  return { smoke: '%', temperature: '°C', manual: '', fire_alarm: 'ppm', sos_alarm: '' }[type] || ''
}

function formatTime(time: string): string {
  return time ? dayjs(time).fromNow() : '-'
}

onMounted(() => {
  fetchAlarms()
})
</script>

<style scoped>
.alarm-summary {
  border-radius: 8px;
  text-align: center;
}
.alarm-summary.critical { border-top: 4px solid #ff4d4f; background: #fff1f0; }
.alarm-summary.warning { border-top: 4px solid #faad14; background: #fffbe6; }
.alarm-summary.success { border-top: 4px solid #52c41a; background: #f6ffed; }
</style>
