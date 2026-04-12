<template>
  <div class="my-orders-container">
    <div class="page-header">
      <h1 class="page-title">我的订单</h1>
      <p class="page-subtitle">查看和管理您的酒店预订</p>
    </div>

    <div class="orders-content">
      <!-- 搜索栏 (针对非登录用户或手动查询) -->
      <a-card class="search-card" :bordered="false">
        <div class="search-box">
          <a-input-search
            v-model:value="searchKeyword"
            placeholder="输入预订号或手机号手动查询"
            enter-button="查询订单"
            size="large"
            @search="handleManualSearch"
            :loading="searching"
          />
          <p class="search-tip">如果您未登录，可以通过预订时留下的手机号或预订号查询订单状态</p>
        </div>
      </a-card>

      <!-- 订单列表 (登录用户自动加载) -->
      <div v-if="loading" class="loading-state">
        <a-spin size="large" tip="正在加载订单..." />
      </div>

      <div v-else-if="orders.length > 0" class="orders-list">
        <a-card
          v-for="order in orders"
          :key="order.id"
          class="order-card"
          :bordered="false"
        >
          <div class="order-header">
            <div class="order-no">
              <span class="label">预订号：</span>
              <span class="value">{{ order.booking_number || order.booking_no }}</span>
            </div>
            <a-tag :color="getStatusColor(order.status)">
              {{ getStatusText(order.status) }}
            </a-tag>
          </div>

          <div class="order-body">
            <div class="hotel-info">
              <h3>{{ order.hotel_name || '智联酒店' }}</h3>
              <p class="room-type">{{ order.room_type }} - {{ order.room_number || order.room_name }}</p>
            </div>

            <div class="stay-info">
              <div class="info-item">
                <span class="label">入住日期</span>
                <span class="value">{{ formatDate(order.check_in_date || order.check_in) }}</span>
              </div>
              <div class="info-item">
                <span class="label">退房日期</span>
                <span class="value">{{ formatDate(order.check_out_date || order.check_out) }}</span>
              </div>
            </div>

            <div class="guest-info">
              <div class="info-item">
                <span class="label">入住人</span>
                <span class="value">{{ order.guest_name }}</span>
              </div>
              <div class="info-item">
                <span class="label">联系电话</span>
                <span class="value">{{ order.guest_phone }}</span>
              </div>
            </div>
          </div>

          <div class="order-footer">
            <div class="total-price">
              <span class="label">总金额：</span>
              <span class="currency">¥</span>
              <span class="amount">{{ order.total_price }}</span>
            </div>
            <div class="actions">
              <a-button
                v-if="order.status === 'checked_in'"
                type="primary"
                @click="goToRoom(order.room_id || order.room_number)"
              >
                进入房间
              </a-button>
              <a-button
                v-if="order.status === 'confirmed'"
                type="primary"
                @click="handleCheckIn(order)"
              >
                预入住
              </a-button>
              <a-button
                v-if="order.status === 'pending' || order.status === 'confirmed'"
                @click="handleCancel(order.id)"
              >
                取消订单
              </a-button>
              <template v-if="order.status === 'pre_checked_in'">
                <a-button disabled style="margin-right: 8px;">
                  待确认
                </a-button>
                <a-button @click="handleCancel(order.id)">
                  取消订单
                </a-button>
              </template>
            </div>
          </div>
        </a-card>
      </div>

      <div v-else class="empty-state">
        <a-empty description="暂无订单记录" />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { message, Modal } from 'ant-design-vue'
import dayjs from 'dayjs'
import request from '@/api/request'
import { useAppStore } from '@/stores/app'

const router = useRouter()
const appStore = useAppStore()

const loading = ref(false)
const searching = ref(false)
const searchKeyword = ref('')
const orders = ref<any[]>([])

const isLoggedIn = computed(() => !!appStore.userInfo)

// 获取状态颜色
const getStatusColor = (status: string) => {
  const colors: Record<string, string> = {
    pending: 'orange',        // 待付款
    confirmed: 'blue',        // 已支付（已确认）
    pre_checked_in: 'cyan',   // 待确认（预入住审核中）
    checked_in: 'green',      // 已入住
    checked_out: 'gray',      // 已退房
    cancelled: 'red'          // 已取消
  }
  return colors[status] || 'default'
}

// 获取状态文本
const getStatusText = (status: string) => {
  const texts: Record<string, string> = {
    pending: '待付款',           // 输入信息但未支付
    confirmed: '已支付',         // 已支付，可办理预入住
    pre_checked_in: '待确认',    // 已办理预入住，等待前台审核
    checked_in: '已入住',        // 前台审核通过，正式入住
    checked_out: '已退房',
    cancelled: '已取消'
  }
  return texts[status] || status
}

// 格式化日期
const formatDate = (date: string) => {
  if (!date) return '-'
  return dayjs(date).format('YYYY-MM-DD HH:mm')
}

// 加载登录用户的订单
const fetchOrders = async () => {
  if (!isLoggedIn.value) return
  
  try {
    loading.value = true
    const res = await request.get('/bookings')
    if (res.data) {
      orders.value = res.data.list || []
    }
  } catch (error) {
    console.error('获取订单失败:', error)
    message.error('获取订单失败')
  } finally {
    loading.value = false
  }
}

// 手动搜索订单
const handleManualSearch = async (keyword: string) => {
  if (!keyword) {
    message.warning('请输入预订号或手机号')
    return
  }

  try {
    searching.value = true
    const res = await request.get('/bookings/lookup', { params: { keyword } })
    if (res.data) {
      // 搜索结果展示 (清空当前列表并显示搜索到的这一个)
      orders.value = [res.data]
      message.success('查询成功')
    }
  } catch (error: any) {
    console.error('查询订单失败:', error)
    if (error.response?.status === 404) {
      message.error('未找到相关订单')
    } else {
      message.error('查询失败，请稍后重试')
    }
  } finally {
    searching.value = false
  }
}

// 跳转到房间控制
const goToRoom = (roomId: any) => {
  router.push(`/guest/room/${roomId}`)
}

// 在线入住
const handleCheckIn = (order: any) => {
  const bookingNumber = order.booking_number || order.booking_no
  router.push({
    path: '/guest/checkin-online',
    query: { booking_no: bookingNumber }
  })
}

// 取消订单
const handleCancel = (bookingId: number) => {
  Modal.confirm({
    title: '确认取消订单',
    content: '您确定要取消该预订吗？取消后可能无法恢复。',
    onOk: async () => {
      try {
        await request.put(`/bookings/${bookingId}/cancel`)
        message.success('订单已成功取消')
        fetchOrders()
      } catch (error) {
        message.error('取消订单失败')
      }
    }
  })
}

onMounted(() => {
  fetchOrders()
})
</script>

<style scoped>
.my-orders-container {
  padding: 24px;
  max-width: 800px;
  margin: 0 auto;
}

.page-header {
  margin-bottom: 32px;
  text-align: center;
}

.page-title {
  font-size: 28px;
  font-weight: 600;
  color: #1a1a1a;
  margin-bottom: 8px;
}

.page-subtitle {
  color: #666;
  font-size: 16px;
}

.search-card {
  margin-bottom: 24px;
  border-radius: 12px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
}

.search-box {
  padding: 8px 0;
}

.search-tip {
  margin-top: 12px;
  color: #999;
  font-size: 12px;
}

.order-card {
  margin-bottom: 16px;
  border-radius: 12px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
  transition: transform 0.2s;
}

.order-card:hover {
  transform: translateY(-2px);
}

.order-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-bottom: 16px;
  border-bottom: 1px solid #f0f0f0;
  margin-bottom: 16px;
}

.order-no .label {
  color: #999;
}

.order-no .value {
  font-weight: 500;
  color: #333;
}

.order-body {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24px;
}

.hotel-info h3 {
  margin: 0 0 8px 0;
  font-size: 18px;
}

.room-type {
  color: #666;
  margin: 0;
}

.stay-info, .guest-info {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.info-item {
  display: flex;
  flex-direction: column;
}

.info-item .label {
  font-size: 12px;
  color: #999;
}

.info-item .value {
  font-weight: 500;
  color: #333;
}

.order-footer {
  margin-top: 24px;
  padding-top: 16px;
  border-top: 1px solid #f0f0f0;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.total-price .label {
  color: #666;
}

.total-price .currency {
  color: #ff4d4f;
  font-size: 14px;
  margin-right: 2px;
}

.total-price .amount {
  color: #ff4d4f;
  font-size: 24px;
  font-weight: 600;
}

.actions {
  display: flex;
  gap: 12px;
}

.loading-state, .empty-state {
  padding: 40px;
  text-align: center;
}

@media (max-width: 576px) {
  .order-body {
    grid-template-columns: 1fr;
  }
  
  .order-footer {
    flex-direction: column;
    gap: 16px;
    align-items: flex-start;
  }
  
  .actions {
    width: 100%;
    justify-content: flex-end;
  }
}
</style>
