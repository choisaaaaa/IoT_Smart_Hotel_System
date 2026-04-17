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
              <p class="room-type">
                {{ order.room_type_name || order.room_type }}
                <template v-if="order.room_number || order.room_name">
                  - {{ order.room_number || order.room_name }}
                </template>
                <template v-else-if="order.status === 'confirmed'">
                  - 待办理预入住
                </template>
                <template v-else-if="order.status === 'pending'">
                  - 待支付后选房
                </template>
              </p>
            </div>

            <div class="stay-info">
              <div class="info-item">
                <span class="label">入住日期</span>
                <span class="value">{{ formatDateTime(order.check_in_date || order.check_in) }}</span>
              </div>
              <div class="info-item">
                <span class="label">退房日期</span>
                <span class="value">{{ formatDateTime(order.check_out_date || order.check_out) }}</span>
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
                v-if="order.status === 'checked_in'"
                @click="openExtendModal(order)"
                style="margin-left: 8px;"
              >
                续住
              </a-button>
              <a-button
                v-if="['confirmed', 'pre_checked_in'].includes(order.status)"
                type="primary"
                @click="handleCheckIn(order)"
              >
                {{ order.status === 'pre_checked_in' ? '修改预入住' : '预入住' }}
              </a-button>
              <a-button
                v-if="order.status === 'pending'"
                type="primary"
                @click="handlePayOrder(order)"
              >
                立即支付
              </a-button>
              <a-button
                v-if="['pending', 'confirmed', 'pre_checked_in'].includes(order.status)"
                @click="handleCancel(order.id)"
              >
                取消订单
              </a-button>
              <a-button
                v-if="order.status === 'checked_out' && !order.has_review"
                type="primary"
                @click="openReviewModal(order)"
              >
                <template #icon><FormOutlined /></template>
                评价
              </a-button>
              <a-button
                v-if="order.status === 'checked_out' && order.has_review"
                @click="openReviewModal(order, true)"
              >
                <template #icon><EditOutlined /></template>
                修改评价
              </a-button>
            </div>
          </div>
        </a-card>
      </div>

      <div v-else class="empty-state">
        <a-empty description="暂无订单记录" />
      </div>
    </div>

    <a-modal
      v-model:open="extendModalVisible"
      :destroyOnClose="true"
      title="在线续住"
      :confirm-loading="extendSubmitting"
      @ok="handleExtendStay"
      ok-text="确认续住"
      cancel-text="取消"
      width="520px"
    >
      <div v-if="extendOrder" class="extend-modal-content">
        <a-descriptions :column="2" size="small" bordered>
          <a-descriptions-item label="酒店">{{ extendOrder.hotel_name || '智联酒店' }}</a-descriptions-item>
          <a-descriptions-item label="房间">{{ extendOrder.room_type_name || extendOrder.room_type }} - {{ extendOrder.room_number || extendOrder.room_name }}</a-descriptions-item>
          <a-descriptions-item label="入住日期">{{ formatDateTime(extendOrder.check_in_date || extendOrder.check_in) }}</a-descriptions-item>
          <a-descriptions-item label="当前退房">{{ formatDateTime(extendOrder.check_out_date || extendOrder.check_out) }}</a-descriptions-item>
        </a-descriptions>

        <div class="extend-section">
          <div class="section-title">续住天数</div>
          <div class="nights-selector">
            <a-button @click="changeExtendNights(-1)" :disabled="extendNights <= 1">
              <template #icon><MinusOutlined /></template>
            </a-button>
            <span class="nights-value">{{ extendNights }}晚</span>
            <a-button @click="changeExtendNights(1)" :disabled="extendNights >= 30">
              <template #icon><PlusOutlined /></template>
            </a-button>
          </div>
          <div v-if="newCheckOutDate" class="new-checkout-info">
            新退房日期：{{ newCheckOutDate }}
          </div>
        </div>

        <div class="extend-section">
          <div class="section-title">优惠与抵扣</div>
          <a-form layout="vertical" size="small">
            <a-form-item label="优惠券">
              <a-select
                v-model:value="selectedCouponId"
                placeholder="不使用优惠券"
                allow-clear
                style="width: 100%"
                @change="recalculatePrice"
              >
                <a-select-option v-for="c in coupons" :key="c.id" :value="c.id">
                  {{ c.coupon_name || c.name }} - {{ c.coupon_type === 'discount' ? `${c.discount_value}折` : `¥${c.discount_value}` }}
                  {{ (c.min_amount || c.min_spend) > 0 ? `(满${c.min_amount || c.min_spend}可用)` : '(无门槛)' }}
                </a-select-option>
              </a-select>
            </a-form-item>
            <a-form-item label="积分抵扣">
              <a-switch v-model:checked="usePoints" @change="recalculatePrice" />
              <span v-if="usePoints" style="margin-left: 8px; color: #999; font-size: 12px;">
                可用 {{ memberInfo?.points || 0 }} 积分
              </span>
            </a-form-item>
          </a-form>
        </div>

        <div class="extend-section">
          <div class="section-title">支付方式</div>
          <a-radio-group v-model:value="paymentMethod">
            <a-radio value="balance">余额支付</a-radio>
            <a-radio value="wechat">微信支付</a-radio>
            <a-radio value="alipay">支付宝</a-radio>
          </a-radio-group>
        </div>

        <div v-if="priceDetails" class="price-summary">
          <div class="price-row">
            <span>续住房费（{{ extendNights }}晚）</span>
            <span>¥{{ priceDetails.base_price?.toFixed(2) }}</span>
          </div>
          <div v-if="priceDetails.discount_rate < 1" class="price-row discount">
            <span>会员折扣（{{ (priceDetails.discount_rate * 10).toFixed(1) }}折）</span>
            <span>-¥{{ priceDetails.member_discount?.toFixed(2) }}</span>
          </div>
          <div v-if="priceDetails.coupon_discount > 0" class="price-row discount">
            <span>优惠券抵扣</span>
            <span>-¥{{ priceDetails.coupon_discount?.toFixed(2) }}</span>
          </div>
          <div v-if="priceDetails.points_discount > 0" class="price-row discount">
            <span>积分抵扣（{{ priceDetails.used_points }}积分）</span>
            <span>-¥{{ priceDetails.points_discount?.toFixed(2) }}</span>
          </div>
          <a-divider style="margin: 8px 0" />
          <div class="price-row total">
            <span>续住费用合计</span>
            <span class="total-amount">¥{{ priceDetails.total_price?.toFixed(2) }}</span>
          </div>
        </div>
      </div>
    </a-modal>

    <a-modal
      v-model:open="payModalVisible"
      title="选择支付方式"
      :confirm-loading="loading"
      @ok="confirmPay"
      ok-text="立即支付"
      cancel-text="取消"
      width="400px"
    >
      <div v-if="selectedOrder" class="pay-modal-content">
        <div class="pay-amount-summary">
          <span class="label">应付金额：</span>
          <span class="value">¥{{ selectedOrder.total_price }}</span>
        </div>
        
        <a-radio-group v-model:value="payMethod" class="pay-method-group">
          <a-radio value="balance" class="pay-method-item">
            <div class="method-info">
              <WalletOutlined class="icon balance" />
              <div class="text">
                <div class="name">余额支付</div>
                <div class="desc">可用余额: ¥{{ memberInfo?.balance || 0 }}</div>
              </div>
            </div>
          </a-radio>
          <a-radio value="wechat" class="pay-method-item">
            <div class="method-info">
              <WechatOutlined class="icon wechat" />
              <div class="text">
                <div class="name">微信支付</div>
                <div class="desc">使用微信快捷支付</div>
              </div>
            </div>
          </a-radio>
          <a-radio value="alipay" class="pay-method-item">
            <div class="method-info">
              <AlipayCircleOutlined class="icon alipay" />
              <div class="text">
                <div class="name">支付宝</div>
                <div class="desc">使用支付宝快捷支付</div>
              </div>
            </div>
          </a-radio>
        </a-radio-group>

        <div v-if="payMethod === 'balance' && Number(memberInfo?.balance || 0) < Number(selectedOrder.total_price)" class="pay-warning">
          <a-alert type="warning" show-icon size="small">
            <template #message>
              <div style="display: flex; justify-content: space-between; align-items: center;">
                <span>余额不足，建议使用其他方式</span>
                <a-button type="link" size="small" @click="payMethod = 'wechat'" style="padding: 0; height: auto;">
                  切换微信支付
                </a-button>
              </div>
            </template>
          </a-alert>
        </div>
      </div>
    </a-modal>
    <!-- Review Modal -->
    <a-modal
      v-model:open="reviewModalVisible"
      :title="isEditReview ? '修改评价' : '评价订单'"
      @ok="submitReview"
      :confirm-loading="reviewSubmitting"
      ok-text="提交评价"
      cancel-text="取消"
      width="520px"
    >
      <div v-if="reviewOrder" class="review-modal-content">
        <div class="review-order-info">
          <span class="hotel-name">{{ reviewOrder.hotel_name || '酒店' }}</span>
          <span class="room-type">{{ reviewOrder.room_type_name || reviewOrder.room_type }}</span>
        </div>

        <div class="rating-section">
          <div class="rating-row">
            <span class="rating-label">环境评分</span>
            <a-rate v-model:value="reviewForm.environment_rating" :count="5" />
            <span class="rating-val">{{ reviewForm.environment_rating }}分</span>
          </div>
          <div class="rating-row">
            <span class="rating-label">设施评分</span>
            <a-rate v-model:value="reviewForm.facility_rating" :count="5" />
            <span class="rating-val">{{ reviewForm.facility_rating }}分</span>
          </div>
          <div class="rating-row">
            <span class="rating-label">舒适评分</span>
            <a-rate v-model:value="reviewForm.comfort_rating" :count="5" />
            <span class="rating-val">{{ reviewForm.comfort_rating }}分</span>
          </div>
        </div>

        <a-form layout="vertical" style="margin-top: 16px;">
          <a-form-item label="评价内容">
            <a-textarea
              v-model:value="reviewForm.content"
              placeholder="请分享您的入住体验..."
              :rows="4"
              :maxlength="500"
              show-count
            />
          </a-form-item>
        </a-form>
      </div>
    </a-modal>

  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { message, Modal } from 'ant-design-vue'
import {
  MinusOutlined,
  PlusOutlined,
  WalletOutlined,
  WechatOutlined,
  AlipayCircleOutlined,
  StarFilled,
  FormOutlined,
  EditOutlined
} from '@ant-design/icons-vue'
import dayjs from 'dayjs'
import { formatDateTime } from '@/utils/date'
import request from '@/api/request'
import { bookingApi } from '@/api/booking'
import { memberApi } from '@/api/member'
import { paymentApi } from '@/api/payment'
import { createReview, updateReview, getMyReviews } from '@/api/review'
import { useAppStore } from '@/stores/app'

const router = useRouter()
const appStore = useAppStore()

const loading = ref(false)
const searching = ref(false)
const searchKeyword = ref('')
const orders = ref<any[]>([])

const extendModalVisible = ref(false)
const extendSubmitting = ref(false)
const extendOrder = ref<any>(null)
const extendNights = ref(1)
const selectedCouponId = ref<number | undefined>(undefined)
const usePoints = ref(false)
const paymentMethod = ref('balance')
const priceDetails = ref<any>(null)
const memberInfo = ref<any>(null)
const coupons = ref<any[]>([])

const payModalVisible = ref(false)
const selectedOrder = ref<any>(null)
const payMethod = ref('balance')

const reviewModalVisible = ref(false)
const reviewSubmitting = ref(false)
const reviewOrder = ref<any>(null)
const isEditReview = ref(false)
const existingReviewId = ref<number | null>(null)
const reviewForm = reactive({
  environment_rating: 5,
  facility_rating: 5,
  comfort_rating: 5,
  content: ''
})

const isLoggedIn = computed(() => !!appStore.userInfo)

const newCheckOutDate = computed(() => {
  if (!extendOrder.value) return ''
  const currentCheckOut = dayjs(extendOrder.value.check_out_date || extendOrder.value.check_out)
  return currentCheckOut.add(extendNights.value, 'day').format('YYYY-MM-DD')
})

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

const fetchMemberInfo = async () => {
  try {
    const res = await memberApi.getMyAssets()
    if (res?.data) {
      memberInfo.value = res.data
    }
  } catch (e) {
    console.error('获取会员信息失败:', e)
  }
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

// 立即支付
const handlePayOrder = async (order: any) => {
  selectedOrder.value = order
  payModalVisible.value = true
  // 预加载会员信息以显示余额
  fetchMemberInfo()
}

// 确认支付
const confirmPay = async () => {
  if (!selectedOrder.value) return
  
  if (payMethod.value === 'balance') {
    const balance = Number(memberInfo.value?.balance || 0)
    if (balance < Number(selectedOrder.value.total_price)) {
      message.error('余额不足，请选择其他支付方式或先充值')
      return
    }
  }

  try {
    loading.value = true
    // 1. 创建支付订单
    const payment = await paymentApi.createPayment({
      order_type: 'booking',
      order_id: selectedOrder.value.id,
      amount: Number(selectedOrder.value.total_price),
      payment_method: payMethod.value,
      description: `支付预订订单: ${selectedOrder.value.booking_number || selectedOrder.value.booking_no}`
    })

    if (payment && payment.id) {
      // 2. 执行支付
      await paymentApi.payPayment(payment.id)
      message.success('支付成功！现在可以办理预入住选房了。')
      payModalVisible.value = false
      fetchOrders()
    }
  } catch (error: any) {
    console.error('支付失败:', error)
    message.error(error?.response?.data?.message || '支付失败，请重试')
  } finally {
    loading.value = false
  }
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

const openExtendModal = async (order: any) => {
  extendOrder.value = order
  extendNights.value = 1
  selectedCouponId.value = undefined
  usePoints.value = false
  paymentMethod.value = 'balance'
  priceDetails.value = null
  extendModalVisible.value = true

  try {
    const [memberRes, couponRes] = await Promise.all([
      memberApi.getMyAssets().catch(() => null),
      memberApi.getMyCoupons().catch(() => null),
    ])
    if (memberRes?.data) memberInfo.value = memberRes.data
    if (couponRes?.data) {
      const data = couponRes.data as any
      coupons.value = Array.isArray(data) ? data : (data.list || [])
    }
  } catch (e) {
    console.error('加载会员信息失败:', e)
  }

  recalculatePrice()
}

const changeExtendNights = (delta: number) => {
  extendNights.value = Math.max(1, Math.min(30, extendNights.value + delta))
  recalculatePrice()
}

const recalculatePrice = async () => {
  if (!extendOrder.value || !newCheckOutDate.value) return

  try {
    const res: any = await bookingApi.calculateExtendPrice(extendOrder.value.id, {
      new_check_out_date: newCheckOutDate.value,
      coupon_id: selectedCouponId.value,
      used_points: usePoints.value ? (memberInfo.value?.points || 0) : 0,
    })
    if (res.data) {
      priceDetails.value = res.data
    }
  } catch (e) {
    console.error('计算续住价格失败:', e)
  }
}

const handleExtendStay = async () => {
  if (!extendOrder.value || !newCheckOutDate.value) return

  try {
    extendSubmitting.value = true
    const res: any = await bookingApi.extendStay(extendOrder.value.id, {
      new_check_out_date: newCheckOutDate.value,
      coupon_id: selectedCouponId.value,
      used_points: usePoints.value ? (memberInfo.value?.points || 0) : 0,
      payment_method: paymentMethod.value,
    })

    if (res.data?.need_payment && res.data?.payment_id) {
      try {
        await paymentApi.payPayment(res.data.payment_id)
        message.success('续住成功，支付已完成！')
      } catch (payErr) {
        message.warning('续住已提交，但支付未完成，请稍后完成支付')
      }
    } else {
      message.success('续住成功！')
    }

    extendModalVisible.value = false
    fetchOrders()
  } catch (e: any) {
    const errMsg = e?.response?.data?.message || '续住失败，请重试'
    message.error(errMsg)
  } finally {
    extendSubmitting.value = false
  }
}

const openReviewModal = async (order: any, isEdit = false) => {
  reviewOrder.value = order
  isEditReview.value = isEdit
  reviewForm.environment_rating = 5
  reviewForm.facility_rating = 5
  reviewForm.comfort_rating = 5
  reviewForm.content = ''

  if (isEdit && order.has_review) {
    try {
      const res = await getMyReviews({ page: 1, pageSize: 50 })
      const reviews = res.data?.list || []
      const existing = reviews.find((r: any) => r.order_id === order.id)
      if (existing) {
        existingReviewId.value = existing.id
        reviewForm.environment_rating = existing.environment_rating || 5
        reviewForm.facility_rating = existing.facility_rating || 5
        reviewForm.comfort_rating = existing.comfort_rating || 5
        reviewForm.content = existing.content || ''
      }
    } catch (e) {
      console.error('获取评价失败:', e)
    }
  }

  reviewModalVisible.value = true
}

const submitReview = async () => {
  if (!reviewOrder.value) return
  if (!reviewForm.content.trim()) {
    return message.warning('请填写评价内容')
  }

  try {
    reviewSubmitting.value = true
    const score = Math.round((reviewForm.environment_rating + reviewForm.facility_rating + reviewForm.comfort_rating) / 3 * 10) / 10

    if (isEditReview.value && existingReviewId.value) {
      await updateReview(existingReviewId.value, {
        score,
        environment_rating: reviewForm.environment_rating,
        facility_rating: reviewForm.facility_rating,
        comfort_rating: reviewForm.comfort_rating,
        content: reviewForm.content
      })
      message.success('评价已更新')
    } else {
      await createReview({
        order_id: reviewOrder.value.id,
        hotel_id: reviewOrder.value.hotel_id,
        room_type_id: reviewOrder.value.room_type_id,
        score,
        environment_rating: reviewForm.environment_rating,
        facility_rating: reviewForm.facility_rating,
        comfort_rating: reviewForm.comfort_rating,
        content: reviewForm.content
      })
      message.success('评价提交成功')
    }

    reviewModalVisible.value = false
    fetchOrders()
  } catch (error: any) {
    message.error(error?.response?.data?.message || '评价提交失败')
  } finally {
    reviewSubmitting.value = false
  }
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

.loading-state, .pay-modal-content {
  padding: 10px 0;
}

.pay-amount-summary {
  text-align: center;
  margin-bottom: 24px;
  background: #fdf2f2;
  padding: 16px;
  border-radius: 8px;
}

.pay-amount-summary .label {
  color: #666;
  font-size: 14px;
}

.pay-amount-summary .value {
  color: #ff4d4f;
  font-size: 24px;
  font-weight: bold;
}

.pay-method-group {
  display: flex;
  flex-direction: column;
  gap: 12px;
  width: 100%;
}

.pay-method-item {
  display: flex;
  align-items: center;
  padding: 12px;
  border: 1px solid #f0f0f0;
  border-radius: 8px;
  width: 100%;
  margin: 0 !important;
}

.pay-method-item :deep(.ant-radio) {
  align-self: center;
}

.pay-method-item.ant-radio-wrapper-checked {
  border-color: #1890ff;
  background: #f0f7ff;
}

.method-info {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-left: 8px;
}

.method-info .icon {
  font-size: 24px;
}

.method-info .icon.balance { color: #faad14; }
.method-info .icon.wechat { color: #52c41a; }
.method-info .icon.alipay { color: #1890ff; }

.method-info .text .name {
  font-weight: 600;
  font-size: 14px;
}

.method-info .text .desc {
  font-size: 12px;
  color: #999;
}

.pay-warning {
  margin-top: 16px;
}

.empty-state {
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

.extend-modal-content {
  padding: 8px 0;
}

.extend-section {
  margin-top: 20px;
}

.section-title {
  font-size: 15px;
  font-weight: 600;
  color: #333;
  margin-bottom: 12px;
}

.nights-selector {
  display: flex;
  align-items: center;
  gap: 16px;
  justify-content: center;
}

.nights-value {
  font-size: 28px;
  font-weight: 700;
  color: #1890ff;
  min-width: 60px;
  text-align: center;
}

.new-checkout-info {
  margin-top: 8px;
  text-align: center;
  color: #1890ff;
  font-size: 13px;
  background: #e6f7ff;
  padding: 6px 12px;
  border-radius: 6px;
}

.price-summary {
  margin-top: 20px;
  background: #fafafa;
  border-radius: 8px;
  padding: 12px 16px;
}

.price-row {
  display: flex;
  justify-content: space-between;
  padding: 4px 0;
  font-size: 14px;
  color: #666;
}

.price-row.discount {
  color: #ff4d4f;
  font-size: 13px;
}

.price-row.total {
  font-size: 16px;
  font-weight: 600;
  color: #333;
}

.total-amount {
  color: #ff4d4f;
  font-size: 20px;
  font-weight: 700;
}

.review-modal-content {
  padding: 8px 0;
}
.review-order-info {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 20px;
  padding: 12px;
  background: #f5f5f5;
  border-radius: 8px;
}
.review-order-info .hotel-name {
  font-weight: 600;
  font-size: 15px;
}
.review-order-info .room-type {
  color: #8c8c8c;
  font-size: 13px;
}
.rating-section {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.rating-row {
  display: flex;
  align-items: center;
  gap: 12px;
}
.rating-label {
  font-size: 14px;
  color: #595959;
  width: 70px;
}
.rating-val {
  font-size: 14px;
  font-weight: 600;
  color: #faad14;
  width: 30px;
}
</style>
