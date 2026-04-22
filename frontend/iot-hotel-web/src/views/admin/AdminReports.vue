<template>
  <div class="admin-reports">
    <a-row :gutter="[16, 16]">
      <a-col :xs="24" :sm="8">
        <a-card>
          <a-statistic title="今日营收" :value="reports.today_revenue" prefix="¥" :precision="2" :value-style="{ color: '#1890ff', fontWeight: 600 }" :loading="loading" />
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="8">
        <a-card>
          <a-statistic title="本月累计" :value="reports.month_revenue" prefix="¥" :precision="2" :value-style="{ color: '#722ed1', fontWeight: 600 }" :loading="loading" />
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="8">
        <a-card>
          <a-statistic title="待结算账单" :value="reports.pending_bills" suffix="笔" :value-style="{ color: '#faad14' }" :loading="loading">
            <template #prefix><FileTextOutlined /></template>
          </a-statistic>
        </a-card>
      </a-col>
    </a-row>

    <a-row :gutter="[16, 16]" style="margin-top: 16px;">
      <a-col :xs="24" :lg="14">
        <a-card title="营收趋势（近7日）" size="small">
          <div ref="revenueChartRef" style="height: 320px;"></div>
        </a-card>
      </a-col>
      <a-col :xs="24" :lg="10">
        <a-card title="收入构成" size="small">
          <div ref="pieChartRef" style="height: 320px;"></div>
        </a-card>
      </a-col>
    </a-row>

    <a-card title="账单明细" size="small" style="margin-top: 16px;">
      <template #extra>
        <a-button size="small" @click="fetchReports" :loading="loading">刷新</a-button>
      </template>
      <a-table
        :columns="billColumns"
        :data-source="reports.bills"
        :pagination="{ pageSize: 8 }"
        row-key="id"
        size="small"
        :loading="loading"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'amount'">
            <span style="font-weight: 600; color: #1890ff;">¥{{ record.amount.toFixed(2) }}</span>
          </template>
          <template v-if="column.key === 'pay_method'">
            {{ paymentMethodText(record.pay_method) }}
          </template>
          <template v-if="column.key === 'status'">
            <a-tag :color="getBillStatusColor(record.status)">
              {{ getBillStatusText(record.status) }}
            </a-tag>
          </template>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, nextTick, onUnmounted } from 'vue'
import * as echarts from 'echarts'
import { FileTextOutlined } from '@ant-design/icons-vue'
import request from '@/api/request'

function paymentMethodText(method: string): string {
  const map: Record<string, string> = {
    alipay: '支付宝',
    wechat: '微信支付',
    wechat_pay: '微信支付',
    credit_card: '银行卡',
    cash: '现金',
    pending: '待支付'
  }
  return map[method] || method || '未设置'
}

function getBillStatusText(status: string): string {
  const map: Record<string, string> = {
    confirmed: '已确认',
    checked_in: '已入住',
    checked_out: '已完成',
    cancelled: '已退款',
    pending: '待支付',
    paid: '已支付',
    refunded: '已退款'
  }
  return map[status] || status
}

function getBillStatusColor(status: string): string {
  const map: Record<string, string> = {
    confirmed: 'blue',
    checked_in: 'processing',
    checked_out: 'success',
    cancelled: 'error',
    pending: 'warning',
    paid: 'success',
    refunded: 'default'
  }
  return map[status] || 'default'
}

const revenueChartRef = ref<HTMLDivElement>()
const pieChartRef = ref<HTMLDivElement>()
let revenueChart: echarts.ECharts | null = null
let pieChart: echarts.ECharts | null = null
const loading = ref(false)

const billColumns = [
  { title: '账单号', dataIndex: 'bill_no', width: 180 },
  { title: '客人', dataIndex: 'guest_name', width: 100 },
  { title: '房号', dataIndex: 'room_number', width: 80 },
  { title: '金额', dataIndex: 'amount', key: 'amount', width: 110 },
  { title: '支付方式', dataIndex: 'pay_method', width: 100 },
  { title: '状态', dataIndex: 'status', key: 'status', width: 90 },
  { title: '日期', dataIndex: 'date', width: 120 }
]

const reports = reactive({
  today_revenue: 0,
  month_revenue: 0,
  pending_bills: 0,
  revenue_trend: [] as { date: string; revenue: number }[],
  income_composition: [] as { name: string; value: number }[],
  bills: [] as any[]
})

const fetchReports = async () => {
  loading.value = true
  try {
    const res: any = await request.get('/hotel/reports')
    const data = res.data
    reports.today_revenue = data.today_revenue || 0
    reports.month_revenue = data.month_revenue || 0
    reports.pending_bills = data.pending_bills || 0
    reports.revenue_trend = data.revenue_trend || []
    reports.income_composition = data.income_composition || []
    reports.bills = data.bills || []
    await nextTick()
    renderCharts()
  } catch (error) {
    console.error('获取报表数据失败:', error)
  } finally {
    loading.value = false
  }
}

const renderCharts = () => {
  if (revenueChartRef.value) {
    if (!revenueChart) revenueChart = echarts.init(revenueChartRef.value)
    const dates = reports.revenue_trend.map(item => item.date.substring(5))
    const values = reports.revenue_trend.map(item => item.revenue)
    revenueChart.setOption({
      grid: { top: 40, right: 20, bottom: 30, left: 55 },
      tooltip: { trigger: 'axis', formatter: '{b}<br/>营收: ¥{c}' },
      xAxis: { type: 'category', data: dates },
      yAxis: { type: 'value', name: '元' },
      series: [
        { name: '营业收入', type: 'bar', data: values, itemStyle: { color: '#1890ff', borderRadius: [4, 4, 0, 0] } },
        { name: '趋势线', type: 'line', smooth: true, data: values, lineStyle: { color: '#faad14' }, symbol: 'none' }
      ]
    })
  }

  if (pieChartRef.value) {
    if (!pieChart) pieChart = echarts.init(pieChartRef.value)
    const data = reports.income_composition.length > 0
      ? reports.income_composition
      : [{ name: '暂无数据', value: 0 }]
    pieChart.setOption({
      tooltip: { trigger: 'item', formatter: '{b}: ¥{c} ({d}%)' },
      legend: { bottom: 0 },
      series: [{
        type: 'pie',
        radius: ['35%', '65%'],
        center: ['50%', '48%'],
        itemStyle: { borderRadius: 6 },
        label: { formatter: '{b}\n{d}%' },
        data
      }]
    })
  }
}

const handleResize = () => {
  revenueChart?.resize()
  pieChart?.resize()
}

onMounted(() => {
  fetchReports()
  window.addEventListener('resize', handleResize)
})

onUnmounted(() => {
  window.removeEventListener('resize', handleResize)
  revenueChart?.dispose()
  pieChart?.dispose()
})
</script>
