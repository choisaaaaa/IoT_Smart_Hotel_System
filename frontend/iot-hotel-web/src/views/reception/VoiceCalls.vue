<template>
  <div class="voice-calls">
    <a-row :gutter="[16, 16]">
      <a-col :xs="24" :sm="8">
        <a-card size="small">
          <a-statistic title="活跃通话" :value="activeCalls.length" :value-style="{ color: '#1890ff' }" />
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="8">
        <a-card size="small">
          <a-statistic title="接通率" :value="Number((stats.answer_rate || 0) * 100)" suffix="%" :precision="0" :value-style="{ color: '#52c41a' }" />
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="8">
        <a-card size="small">
          <a-statistic title="平均通话时长" :value="stats.avg_duration_sec || 0" suffix="秒" :value-style="{ color: '#722ed1' }" />
        </a-card>
      </a-col>
    </a-row>

    <a-card title="发起语音通话" style="margin-top: 16px;">
      <a-form layout="inline">
        <a-form-item label="前台分机">
          <a-input v-model:value="callForm.caller_id" placeholder="例如 FD-01" style="width: 160px;" />
        </a-form-item>
        <a-form-item label="目标房间">
          <a-input v-model:value="callForm.callee_id" placeholder="输入房号或 room_id" style="width: 180px;" />
        </a-form-item>
        <a-form-item>
          <a-button type="primary" @click="startCall" :loading="calling">发起呼叫</a-button>
        </a-form-item>
      </a-form>
    </a-card>

    <a-card title="当前通话" style="margin-top: 16px;">
      <a-table :columns="activeColumns" :data-source="activeCalls" :pagination="false" row-key="call_id" size="middle">
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'status'">
            <a-tag :color="statusColor(record.status)">{{ statusText(record.status) }}</a-tag>
          </template>
          <template v-if="column.key === 'action'">
            <a-space>
              <a-button type="link" size="small" v-if="['calling', 'outgoing', 'ringing'].includes(record.status)" @click="answer(record.call_id)">接听</a-button>
              <a-button type="link" danger size="small" @click="hangup(record.call_id)">挂断</a-button>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

    <a-card title="通话记录" style="margin-top: 16px;">
      <a-table :columns="historyColumns" :data-source="history" :pagination="{ pageSize: 8 }" row-key="call_id" size="middle">
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'status'">
            <a-tag :color="statusColor(record.status)">{{ statusText(record.status) }}</a-tag>
          </template>
          <template v-if="column.key === 'duration'">
            {{ record.duration_sec || 0 }} 秒
          </template>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { message } from 'ant-design-vue'
import { callApi } from '@/api/call'

const calling = ref(false)
const activeCalls = ref<any[]>([])
const history = ref<any[]>([])
const stats = reactive({
  answer_rate: 0,
  avg_duration_sec: 0
})

const callForm = reactive({
  caller_id: 'FD-01',
  callee_id: ''
})

const activeColumns = [
  { title: '通话 ID', dataIndex: 'call_id', width: 200 },
  { title: '主叫', dataIndex: 'caller_id', width: 120 },
  { title: '被叫', dataIndex: 'callee_id', width: 120 },
  { title: '状态', dataIndex: 'status', key: 'status', width: 100 },
  { title: '开始时间', dataIndex: 'started_at', width: 180 },
  { title: '操作', key: 'action', width: 140 }
]

const historyColumns = [
  { title: '通话 ID', dataIndex: 'call_id', width: 200 },
  { title: '主叫', dataIndex: 'caller_id', width: 120 },
  { title: '被叫', dataIndex: 'callee_id', width: 120 },
  { title: '状态', dataIndex: 'status', key: 'status', width: 100 },
  { title: '时长', dataIndex: 'duration_sec', key: 'duration', width: 100 },
  { title: '开始时间', dataIndex: 'started_at', width: 180 }
]

function statusColor(status: string): string {
  return ({
    calling: 'processing',
    outgoing: 'processing',
    ringing: 'warning',
    connected: 'success',
    ended: 'default',
    rejected: 'error'
  } as Record<string, string>)[status] || 'default'
}

function statusText(status: string): string {
  return ({
    calling: '呼叫中',
    outgoing: '外呼中',
    ringing: '振铃中',
    connected: '已接通',
    ended: '已结束',
    rejected: '已拒接'
  } as Record<string, string>)[status] || status
}

async function fetchCalls() {
  try {
    const [activeRes, historyRes, statsRes] = await Promise.all([
      callApi.getActive(),
      callApi.getHistory({ limit: 50 }),
      callApi.getStats()
    ])
    activeCalls.value = (activeRes as any).data?.items || []
    history.value = (historyRes as any).data?.items || []
    stats.answer_rate = (statsRes as any).data?.answer_rate || 0
    stats.avg_duration_sec = (statsRes as any).data?.avg_duration_sec || 0
  } catch (error) {
    message.error('获取通话数据失败')
  }
}

async function startCall() {
  if (!callForm.caller_id || !callForm.callee_id) {
    message.warning('请输入前台分机和目标房间')
    return
  }
  calling.value = true
  try {
    await callApi.outbound({
      caller_id: callForm.caller_id,
      callee_type: 'room',
      callee_id: callForm.callee_id,
      caller_type: 'front_desk'
    })
    message.success('已发起语音呼叫')
    callForm.callee_id = ''
    await fetchCalls()
  } catch (error) {
    message.error('发起呼叫失败')
  } finally {
    calling.value = false
  }
}

async function answer(callId: string) {
  try {
    await callApi.answer(callId)
    message.success('已接听')
    await fetchCalls()
  } catch (error) {
    message.error('接听失败')
  }
}

async function hangup(callId: string) {
  try {
    await callApi.hangup(callId)
    message.success('已挂断')
    await fetchCalls()
  } catch (error) {
    message.error('挂断失败')
  }
}

onMounted(fetchCalls)
</script>
