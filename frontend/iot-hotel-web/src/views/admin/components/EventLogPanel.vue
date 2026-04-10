<template>
  <div class="event-log-panel">
    <a-row :gutter="[16, 16]" style="margin-bottom: 16px;">
      <a-col :xs="24" :sm="8">
        <a-card size="small" class="log-stat critical-log">
          <a-statistic title="严重事件" :value="logSummary.critical_count || 0" :value-style="{ color: '#ff4d4f', fontSize: '26px' }">
            <template #prefix><AlertFilled /></template>
          </a-statistic>
          <div class="sub">需立即处理</div>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="8">
        <a-card size="small" class="log-stat unresolved-log">
          <a-statistic title="未解决事件" :value="logSummary.unresolved_count || 0" :value-style="{ color: '#faad14', fontSize: '26px' }">
            <template #prefix><ClockCircleFilled /></template>
          </a-statistic>
          <div class="sub">待处理</div>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="8">
        <a-card size="small" class="log-stat today-log">
          <a-statistic title="今日事件总数" :value="logSummary.today_total || 0" :value-style="{ color: '#1890ff', fontSize: '26px' }">
            <template #prefix><FileTextOutlined /></template>
          </a-statistic>
          <div class="sub">系统活动记录</div>
        </a-card>
      </a-col>
    </a-row>

    <a-alert
      v-if="(logSummary.critical_count || 0) > 0"
      message="🚨 存在严重级别事件！"
      description="系统检测到严重级别的事件，请立即查看并处理。"
      type="error"
      show-icon
      closable
      style="margin-bottom: 16px;"
    />

    <a-card :loading="loading">
      <template #title>
        <span>📋 系统事件日志</span>
      </template>
      <template #extra>
        <a-space>
          <a-select v-model:value="filterType" placeholder="事件类型" allowClear style="width: 130px;" @change="fetchLogs">
            <a-select-option value="">全部类型</a-select-option>
            <a-select-option value="fire_alarm">🔥 消防警报</a-select-option>
            <a-select-option value="device_error">❌ 设备故障</a-select-option>
            <a-select-option value="environment_warning">⚠️ 环境警告</a-select-option>
            <a-select-option value="device_control">📱 设备控制</a-select-option>
            <a-select-option value="maintenance">🔧 维护提醒</a-select-option>
            <a-select-option value="energy_alert">⚡ 能耗预警</a-select-option>
          </a-select>
          <a-select v-model:value="filterSeverity" placeholder="严重程度" allowClear style="width: 110px;" @change="fetchLogs">
            <a-select-option value="">全部</a-select-option>
            <a-select-option value="critical">严重</a-select-option>
            <a-select-option value="error">错误</a-select-option>
            <a-select-option value="warning">警告</a-select-option>
            <a-select-option value="info">信息</a-select-option>
          </a-select>
          <a-button type="primary" size="small" :loading="loading" @click="fetchLogs"><ReloadOutlined /> 刷新</a-button>
        </a-space>
      </template>

      <a-timeline mode="left" v-if="logs.length > 0">
        <a-timeline-item
          v-for="log in logs"
          :key="log.id"
          :color="getTimelineColor(log.severity)"
        >
          <div class="log-item" :class="{ 'unresolved': !log.resolved, 'critical': log.severity === 'critical' }">
            <div class="log-header">
              <span class="log-title">{{ log.title }}</span>
              <a-space>
                <a-tag :color="getSeverityColor(log.severity)" size="small">{{ getSeverityText(log.severity) }}</a-tag>
                <a-tag :color="getEventTypeColor(log.event_type)" size="small">{{ getEventTypeText(log.event_type) }}</a-tag>
                <a-badge v-if="!log.resolved" status="processing" text="未解决" />
                <a-badge v-else status="success" text="已解决" />
              </a-space>
            </div>
            <div class="log-description">{{ log.description }}</div>
            <div class="log-meta">
              <Space>
                <span><EnvironmentOutlined /> {{ log.room_number }}房</span>
                <span><ClockCircleOutlined /> {{ formatTime(log.created_at) }}</span>
                <span v-if="log.handled_by"><UserOutlined /> 处理人: {{ log.handled_by }}</span>
              </Space>
            </div>
          </div>
        </a-timeline-item>
      </a-timeline>

      <a-empty v-if="!logs.length && !loading" description="暂无事件记录" />

      <a-pagination
        v-if="totalLogs > 10"
        v-model:current="currentPage"
        :total="totalLogs"
        :pageSize="10"
        show-size-changer
        style="margin-top: 16px; text-align: right;"
        @change="onPageChange"
      />
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { message, Space } from 'ant-design-vue'
import {
  AlertFilled,
  ClockCircleFilled,
  FileTextOutlined,
  ReloadOutlined,
  EnvironmentOutlined,
  UserOutlined
} from '@ant-design/icons-vue'
import { environmentApi, type EventLog } from '@/api/environment'
import dayjs from 'dayjs'
import relativeTime from 'dayjs/plugin/relativeTime'

dayjs.extend(relativeTime)

const loading = ref(false)
const logs = ref<EventLog[]>([])
const totalLogs = ref(0)
const currentPage = ref(1)

const logSummary = reactive({
  critical_count: 0,
  unresolved_count: 0,
  today_total: 0
})

const filterType = ref<string>('')
const filterSeverity = ref<string>('')

async function fetchLogs() {
  loading.value = true
  try {
    const params: any = { limit: 50 }
    if (filterType.value) params.event_type = filterType.value
    if (filterSeverity.value) params.severity = filterSeverity.value

    const res: any = await environmentApi.getEventLogs(params)
    const data = res.data

    if (data) {
      logs.value = data.logs || []
      totalLogs.value = data.total || 0
      Object.assign(logSummary, data.summary)
    }
  } catch (err) {
    console.error('Failed to fetch event logs:', err)
    message.error('获取事件日志失败')
  } finally {
    loading.value = false
  }
}

function onPageChange(page: number) {
  currentPage.value = page
}

function getTimelineColor(severity: string): string {
  return { critical: 'red', error: 'orange', warning: 'yellow', info: 'blue' }[severity] || 'gray'
}

function getSeverityColor(severity: string): string {
  return { critical: 'error', error: 'orange', warning: 'warning', info: 'blue' }[severity] || 'default'
}

function getSeverityText(severity: string): string {
  return { critical: '严重', error: '错误', warning: '警告', info: '信息' }[severity] || severity
}

function getEventTypeColor(type: string): string {
  return {
    fire_alarm: 'red',
    device_error: 'orange',
    environment_warning: 'gold',
    device_control: 'blue',
    maintenance: 'purple',
    energy_alert: 'cyan'
  }[type] || 'default'
}

function getEventTypeText(type: string): string {
  return {
    fire_alarm: '消防',
    device_error: '设备',
    environment_warning: '环境',
    device_control: '控制',
    maintenance: '维护',
    energy_alert: '能耗'
  }[type] || type
}

function formatTime(time: string): string {
  return time ? dayjs(time).fromNow() : '-'
}

onMounted(() => {
  fetchLogs()
})
</script>

<style scoped>
.log-stat {
  border-radius: 8px;
  text-align: center;
}
.critical-log { border-top: 3px solid #ff4d4f; background: #fff1f0; }
.unresolved-log { border-top: 3px solid #faad14; background: #fffbe6; }
.today-log { border-top: 3px solid #1890ff; background: #e6f7ff; }

.sub {
  font-size: 12px;
  margin-top: 4px;
  color: rgba(0,0,0,0.45);
}

.log-item {
  background: #fafafa;
  padding: 12px;
  border-radius: 8px;
  margin-bottom: 4px;
  transition: all 0.2s;
}

.log-item:hover {
  background: #f0f0f0;
}

.log-item.unresolved {
  border-left: 3px solid #faad14;
}

.log-item.critical {
  border-left: 3px solid #ff4d4f;
  background: #fff1f0;
}

.log-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
  flex-wrap: wrap;
  gap: 8px;
}

.log-title {
  font-weight: bold;
  font-size: 14px;
}

.log-description {
  color: rgba(0,0,0,0.65);
  font-size: 13px;
  margin-bottom: 8px;
  line-height: 1.5;
}

.log-meta {
  font-size: 12px;
  color: rgba(0,0,0,0.45);
  display: flex;
  gap: 16px;
  flex-wrap: wrap;
}
</style>
