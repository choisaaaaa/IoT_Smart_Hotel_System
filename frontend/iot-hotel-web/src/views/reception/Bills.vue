<template>
  <div class="bills-page">
    <a-row :gutter="[16, 16]">
      <a-col :xs="24" :sm="8">
        <a-card size="small">
          <a-statistic title="今日营收" :value="12856" prefix="¥" :value-style="{ color: '#1890ff', fontWeight: 600 }">
            <template #suffix><span style="font-size: 13px; color: #52c41a;"> ↑12.3%</span></template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="8">
        <a-card size="small">
          <a-statistic title="本月累计" :value="386420" prefix="¥" :value-style="{ color: '#722ed1', fontWeight: 600 }" />
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="8">
        <a-card size="small">
          <a-statistic title="待结算账单" :value="15" suffix="笔" :value-style="{ color: '#ff4d4f' }">
            <template #prefix><FileTextOutlined /></template>
          </a-statistic>
        </a-card>
      </a-col>
    </a-row>

    <div class="toolbar" style="margin-top: 16px;">
      <a-space>
        <a-range-picker />
        <a-select v-model:value="payMethodFilter" placeholder="支付方式" allow-clear style="width: 130px;">
          <a-select-option value="alipay">支付宝</a-select-option>
          <a-select-option value="wechat">微信支付</a-select-option>
          <a-select-option value="credit_card">银行卡</a-select-option>
          <a-select-option value="cash">现金</a-select-option>
        </a-select>
      </a-space>
      <a-space>
        <a-button><DownloadOutlined /> 导出报表</a-button>
        <a-button type="primary" @click="printBill"><PrinterOutlined /> 打印</a-button>
      </a-space>
    </div>

    <a-table
      :columns="columns"
      :data-source="bills"
      :pagination="{ pageSize: 10, showSizeChanger: true }"
      row-key="id"
      size="middle"
    >
      <template #bodyCell="{ column, record }">
        <template v-if="column.key === 'amount'">
          <span style="font-weight: 600;">¥{{ record.amount }}</span>
        </template>
        <template v-if="column.key === 'status'">
          <a-tag :color="record.status === 'paid' ? 'success' : record.status === 'pending' ? 'warning' : 'default'">
            {{ record.status === 'paid' ? '已支付' : record.status === 'pending' ? '待支付' : '已退款' }}
          </a-tag>
        </template>
        <template v-if="column.key === 'action'">
          <a-space>
            <a-button type="link" size="small" @click="viewBillDetail(record)">查看明细</a-button>
            <a-button type="link" size="small" v-if="record.status === 'pending'" @click="collectPayment(record)">
              收款
            </a-button>
          </a-space>
        </template>
      </template>
    </a-table>

    <a-drawer v-model:open="drawerVisible" :title="`账单 ${currentBill?.bill_no} 明细`" :width="520">
      <template v-if="currentBill">
        <a-descriptions :column="1" bordered size="small">
          <a-descriptions-item label="账单号">{{ currentBill.bill_no }}</a-descriptions-item>
          <a-descriptions-item label="客人">{{ currentBill.guest_name }}</a-descriptions-item>
          <a-descriptions-item label="房号">{{ currentBill.room_number }}</a-descriptions-item>
          <a-descriptions-item label="入住日期">{{ currentBill.check_in }}</a-descriptions-item>
          <a-descriptions-item label="退房日期">{{ currentBill.check_out }}</a-descriptions-item>
        </a-descriptions>
        <h4 style="margin: 16px 0 8px;">费用明细</h4>
        <a-table :columns="detailColumns" :data-source="billDetails" :pagination="false" size="small" row-key="id">
          <template #bodyCell="{ column, record }">
            <template v-if="column.key === 'amount'">¥{{ record.amount }}</template>
          </template>
        </a-table>
        <a-divider />
        <div style="display: flex; justify-content: space-between; font-size: 18px; font-weight: bold;">
          <span>合计</span>
          <span style="color: #ff4d4f;">¥{{ currentBill.amount }}</span>
        </div>
      </template>
    </a-drawer>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { message } from 'ant-design-vue'
import { FileTextOutlined, DownloadOutlined, PrinterOutlined } from '@ant-design/icons-vue'
import { bookingApi } from '@/api/booking'

const payMethodFilter = ref<string | undefined>()
const drawerVisible = ref(false)
const currentBill = ref<any>(null)
const loading = ref(false)
const bills = ref<any[]>([])

const stats = reactive({
  todayTotal: 0,
  monthTotal: 0,
  pendingCount: 0
})

const detailColumns = [
  { title: '项目', dataIndex: 'item' },
  { title: '说明', dataIndex: 'desc' },
  { title: '金额', dataIndex: 'amount', key: 'amount', width: 100 }
]

const billDetails = ref([
  { id: 1, item: '房费', desc: '系统计算', amount: '0.00' }
])

const columns = [
  { title: '账单号', dataIndex: 'booking_number', width: 170 },
  { title: '客人', dataIndex: 'guest_name', width: 90 },
  { title: '房号', dataIndex: 'room_number', width: 70 },
  { title: '入住日期', dataIndex: 'check_in_date', key: 'check_in_date', width: 110 },
  { title: '退房日期', dataIndex: 'check_out_date', key: 'check_out_date', width: 110 },
  { title: '总金额', dataIndex: 'total_price', key: 'amount', width: 110 },
  { title: '支付方式', dataIndex: 'payment_method', width: 100 },
  { title: '状态', dataIndex: 'status', key: 'status', width: 90 },
  { title: '操作', key: 'action', width: 140 }
]

async function fetchBills() {
  loading.value = true
  try {
    const res = await bookingApi.getBookingList({ pageSize: 100 })
    const list = res.data?.list || []
    
    // 过滤出有价值的账单状态
    bills.value = list.filter(b => ['checked_in', 'checked_out', 'confirmed'].includes(b.status))
    
    // 简单统计逻辑
    stats.pendingCount = list.filter(b => b.status === 'checked_in').length
    stats.todayTotal = list.filter(b => b.status === 'checked_out' && b.updated_at?.startsWith(new Date().toISOString().split('T')[0]))
      .reduce((sum, b) => sum + Number(b.total_price), 0)
    stats.monthTotal = list.filter(b => b.status === 'checked_out')
      .reduce((sum, b) => sum + Number(b.total_price), 0)
      
  } catch (error) {
    message.error('获取账单列表失败')
  } finally {
    loading.value = false
  }
}

function viewBillDetail(bill: any) {
  currentBill.value = bill
  billDetails.value = [{ id: 1, item: '房费', desc: `订单 ${bill.booking_number}`, amount: bill.total_price }]
  drawerVisible.value = true
}

function collectPayment(bill: any) { 
  message.success(`已收取 ${bill.guest_name} 账单 ¥${bill.total_price}`) 
}

onMounted(fetchBills)
</script>

<style scoped>
.toolbar { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px; }
</style>