<template>
  <div class="environment-monitor-admin">
    <a-tabs v-model:activeKey="activeTab" type="card" @change="onTabChange">
      <a-tab-pane key="overview" tab="📊 综合概览">
        <div class="dashboard-overview">
          <a-row :gutter="[16, 16]">
            <a-col :xs="24" :sm="12" :md="8">
              <a-card class="stat-card temp-card" hoverable>
                <a-statistic
                  title="平均温度"
                  :value="dashboardStats.environment?.avg_temperature || 0"
                  suffix="°C"
                  :value-style="{ color: '#1890ff', fontSize: '28px' }"
                >
                  <template #prefix><FireOutlined style="font-size: 28px;" /></template>
                </a-statistic>
                <div class="sub-info">空气质量: {{ dashboardStats.environment?.air_quality || '-' }}</div>
              </a-card>
            </a-col>

            <a-col :xs="24" :sm="12" :md="8">
              <a-card class="stat-card fire-card" hoverable :class="{ 'alarm-active': dashboardStats.fire_safety?.active_alarms > 0 }">
                <a-statistic
                  title="消防状态"
                  :value="dashboardStats.fire_safety?.active_alarms || 0"
                  suffix="个活跃警报"
                  :value-style="{ color: (dashboardStats.fire_safety?.active_alarms || 0) > 0 ? '#ff4d4f' : '#52c41a', fontSize: '28px' }"
                >
                  <template #prefix><SafetyCertificateOutlined style="font-size: 28px;" /></template>
                </a-statistic>
                <div class="sub-info">探测器在线率: {{ Math.round(((dashboardStats.fire_safety?.detectors_online || 0) / (dashboardStats.fire_safety?.detectors_total || 1)) * 100) }}%</div>
              </a-card>
            </a-col>

            <a-col :xs="24" :sm="12" :md="8">
              <a-card class="stat-card device-card" hoverable>
                <a-statistic
                  title="设备状态"
                  :value="dashboardStats.devices?.online || 0"
                  :suffix="`/${dashboardStats.devices?.total || 0} 在线`"
                  :value-style="{ color: '#722ed1', fontSize: '28px' }"
                >
                  <template #prefix><ApartmentOutlined style="font-size: 28px;" /></template>
                </a-statistic>
                <div class="sub-info">运行中: {{ dashboardStats.devices?.running || 0 }} | 异常: {{ dashboardStats.devices?.error || 0 }}</div>
              </a-card>
            </a-col>

            <a-col :xs="24" :sm="12" :md="8">
              <a-card class="stat-card energy-card" hoverable>
                <a-statistic
                  title="今日能耗"
                  :value="dashboardStats.energy?.today_total || 0"
                  suffix="kWh"
                  :value-style="{ color: '#faad14', fontSize: '28px' }"
                >
                  <template #prefix><ThunderboltOutlined style="font-size: 28px;" /></template>
                </a-statistic>
                <div class="sub-info">较昨日节省: {{ dashboardStats.energy?.savings_percent || 0 }}% | 预估月费: ¥{{ dashboardStats.energy?.monthly_cost || 0 }}</div>
              </a-card>
            </a-col>

            <a-col :xs="24" :sm="12" :md="8">
              <a-card class="stat-card alert-card" hoverable>
                <a-statistic
                  title="待处理告警"
                  :value="dashboardStats.alerts?.unresolved || 0"
                  suffix="条"
                  :value-style="{ color: (dashboardStats.alerts?.unresolved || 0) > 3 ? '#ff4d4f' : '#faad14', fontSize: '28px' }"
                >
                  <template #prefix><BellOutlined style="font-size: 28px;" /></template>
                </a-statistic>
                <div class="sub-info">严重: {{ dashboardStats.alerts?.critical || 0 }} | 警告: {{ dashboardStats.alerts?.warning || 0 }}</div>
              </a-card>
            </a-col>

            <a-col :xs="24" :sm="12" :md="8">
              <a-card class="stat-card score-card" hoverable>
                <a-statistic
                  title="环境评分"
                  :value="dashboardStats.environment?.avg_environment_score || 0"
                  suffix="分"
                  :value-style="{ color: getScoreColor(dashboardStats.environment?.avg_environment_score || 0), fontSize: '28px' }"
                >
                  <template #prefix><TrophyOutlined style="font-size: 28px;" /></template>
                </a-statistic>
                <div class="sub-info">正常房间: {{ dashboardStats.environment?.normal_count || 0 }}/{{ dashboardStats.environment?.total_rooms || 0 }}</div>
              </a-card>
            </a-col>
          </a-row>

          <a-alert
            v-if="(dashboardStats.fire_safety?.active_alarms || 0) > 0"
            message="🚨 消防警报激活！"
            :description="`系统检测到 ${dashboardStats.fire_safety?.active_alarms} 个活跃火警，请立即查看消防报警模块进行处理！`"
            type="error"
            show-icon
            closable
            style="margin-top: 16px; margin-bottom: 16px;"
          />

          <a-alert
            v-else-if="(dashboardStats.alerts?.unresolved || 0) > 5"
            message="⚠️ 告警数量较多"
            :description="`当前有 ${dashboardStats.alerts?.unresolved} 条未处理的告警信息，建议及时处理。`"
            type="warning"
            show-icon
            closable
            style="margin-top: 16px; margin-bottom: 16px;"
          />
        </div>
      </a-tab-pane>

      <a-tab-pane key="environment" tab="🌡️ 环境监测">
        <EnvironmentDataPanel />
      </a-tab-pane>

      <a-tab-pane key="fire-alarm" tab="🚨 消防报警">
        <FireAlarmPanel />
      </a-tab-pane>

      <a-tab-pane key="devices" tab="📱 设备管理">
        <DeviceManagementPanel />
      </a-tab-pane>

      <a-tab-pane key="energy" tab="⚡ 能耗统计">
        <EnergyConsumptionPanel />
      </a-tab-pane>

      <a-tab-pane key="events" tab="📋 事件日志">
        <EventLogPanel />
      </a-tab-pane>
    </a-tabs>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import {
  FireOutlined,
  SafetyCertificateOutlined,
  ApartmentOutlined,
  ThunderboltOutlined,
  BellOutlined,
  TrophyOutlined
} from '@ant-design/icons-vue'
import { environmentApi } from '@/api/environment'
import EnvironmentDataPanel from './components/EnvironmentDataPanel.vue'
import FireAlarmPanel from './components/FireAlarmPanel.vue'
import DeviceManagementPanel from './components/DeviceManagementPanel.vue'
import EnergyConsumptionPanel from './components/EnergyConsumptionPanel.vue'
import EventLogPanel from './components/EventLogPanel.vue'

const activeTab = ref('overview')
const dashboardStats = ref<any>({})

function onTabChange(key: string) {
  console.log('Tab changed to:', key)
}

function getScoreColor(score: number): string {
  if (score >= 90) return '#52c41a'
  if (score >= 70) return '#1890ff'
  if (score >= 50) return '#faad14'
  return '#ff4d4f'
}

async function loadDashboardStats() {
  try {
    const res: any = await environmentApi.getDashboardStats()
    if (res.data) {
      dashboardStats.value = res.data
    }
  } catch (err) {
    console.error('Failed to load dashboard stats:', err)
  }
}

onMounted(() => {
  loadDashboardStats()
})
</script>

<style scoped>
.environment-monitor-admin { padding: 0; }

.stat-card {
  border-radius: 10px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  transition: all 0.3s;
  border-left: 4px solid transparent;
}

.stat-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 6px 16px rgba(0, 0, 0, 0.15);
}

.temp-card { border-left-color: #1890ff; }
.fire-card { border-left-color: #ff4d4f; }
.fire-card.alarm-active {
  animation: pulse 2s infinite;
}
.device-card { border-left-color: #722ed1; }
.energy-card { border-left-color: #faad14; }
.alert-card { border-left-color: #ff7875; }
.score-card { border-left-color: #52c41a; }

.sub-info {
  font-size: 12px;
  color: rgba(0, 0, 0, 0.45);
  margin-top: 8px;
  padding-top: 8px;
  border-top: 1px solid #f0f0f0;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.6; }
}

.dashboard-overview {
  min-height: 400px;
}
</style>
