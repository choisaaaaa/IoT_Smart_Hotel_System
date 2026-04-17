<template>
  <div class="review-manage">
    <a-card title="评价管理" :bordered="false">
      <!-- 统计概览 -->
      <a-row :gutter="16" class="stats-row">
        <a-col :span="6">
          <a-statistic title="总评价数" :value="stats.total_reviews" />
        </a-col>
        <a-col :span="6">
          <a-statistic title="平均评分" :value="stats.avg_score" :precision="1" suffix="分" />
        </a-col>
        <a-col :span="6">
          <a-statistic title="好评数" :value="stats.good_count" value-style="color: #52c41a" />
        </a-col>
        <a-col :span="6">
          <a-statistic title="差评数" :value="stats.bad_count" value-style="color: #ff4d4f" />
        </a-col>
      </a-row>

      <a-divider />

      <!-- 筛选条件 -->
      <div class="filter-section">
        <a-space>
          <a-select
            v-model:value="filter.score"
            placeholder="评分筛选"
            style="width: 120px"
            allow-clear
            @change="handleFilterChange"
          >
            <a-select-option :value="5">5星</a-select-option>
            <a-select-option :value="4">4星</a-select-option>
            <a-select-option :value="3">3星</a-select-option>
            <a-select-option :value="2">2星</a-select-option>
            <a-select-option :value="1">1星</a-select-option>
          </a-select>
          <a-range-picker
            v-model:value="filter.dateRange"
            @change="handleFilterChange"
          />
          <a-input-search
            v-model:value="filter.keyword"
            placeholder="搜索评价内容"
            style="width: 250px"
            @search="handleFilterChange"
          />
        </a-space>
      </div>

      <!-- 评价列表 -->
      <a-list
        :loading="loading"
        :data-source="reviewList"
        :pagination="pagination"
        item-layout="vertical"
        class="review-list"
      >
        <template #renderItem="{ item }">
          <a-list-item>
            <div class="review-item">
              <div class="review-header">
                <div class="reviewer-info">
                  <a-avatar
                    :size="40"
                    :src="item.user_avatar ? getFullUrl(item.user_avatar) : undefined"
                  >
                    {{ item.member_name?.charAt(0) || '?' }}
                  </a-avatar>
                  <div class="reviewer-detail">
                    <div class="reviewer-name">{{ item.member_name || '匿名用户' }}</div>
                    <div class="review-meta">
                      <a-rate :value="item.score" disabled style="font-size: 12px" />
                      <span class="review-date">{{ formatDateTime(item.created_at) }}</span>
                    </div>
                  </div>
                </div>
                <div class="review-actions">
                  <a-tag v-if="item.reply" color="blue">已回复</a-tag>
                  <a-tag v-else color="orange">待回复</a-tag>
                  <a-dropdown>
                    <a-button type="text">
                      <MoreOutlined />
                    </a-button>
                    <template #overlay>
                      <a-menu>
                        <a-menu-item @click="handleReply(item)">
                          <EditOutlined /> {{ item.reply ? '修改回复' : '回复' }}
                        </a-menu-item>
                        <a-menu-item @click="handleViewDetail(item)">
                          <EyeOutlined /> 查看详情
                        </a-menu-item>
                        <a-menu-item danger @click="handleDelete(item)">
                          <DeleteOutlined /> 删除
                        </a-menu-item>
                      </a-menu>
                    </template>
                  </a-dropdown>
                </div>
              </div>

              <div class="review-content">
                <p>{{ item.content }}</p>
                <div v-if="item.photos?.length" class="review-photos">
                  <a-image
                    v-for="(photo, idx) in item.photos"
                    :key="idx"
                    :src="getFullUrl(photo)"
                    :width="80"
                    :height="80"
                    style="margin-right: 8px"
                  />
                </div>
              </div>

              <div class="review-ratings">
                <span class="rating-item">
                  <span class="rating-label">环境</span>
                  <a-rate :value="item.environment_rating" disabled style="font-size: 12px" />
                </span>
                <span class="rating-item">
                  <span class="rating-label">设施</span>
                  <a-rate :value="item.facility_rating" disabled style="font-size: 12px" />
                </span>
                <span class="rating-item">
                  <span class="rating-label">舒适</span>
                  <a-rate :value="item.comfort_rating" disabled style="font-size: 12px" />
                </span>
              </div>

              <!-- 酒店回复 -->
              <div v-if="item.reply" class="hotel-reply">
                <div class="reply-header">
                  <span class="reply-title">酒店回复</span>
                  <span class="reply-date">{{ formatDateTime(item.replied_at) }}</span>
                </div>
                <p class="reply-content">{{ item.reply }}</p>
              </div>
            </div>
          </a-list-item>
        </template>
      </a-list>
    </a-card>

    <!-- 回复弹窗 -->
    <a-modal
      v-model:open="replyModalVisible"
      :title="currentReview?.reply ? '修改回复' : '回复评价'"
      @ok="submitReply"
      :confirm-loading="replySubmitting"
    >
      <a-textarea
        v-model:value="replyForm.content"
        :rows="4"
        placeholder="请输入回复内容..."
        :maxlength="500"
        show-count
      />
    </a-modal>

    <!-- 详情弹窗 -->
    <a-modal
      v-model:open="detailModalVisible"
      title="评价详情"
      :footer="null"
      width="600px"
    >
      <div v-if="currentReview" class="review-detail">
        <div class="detail-row">
          <span class="detail-label">评价用户：</span>
          <span>{{ currentReview.member_name || '匿名用户' }}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">联系电话：</span>
          <span>{{ currentReview.member_phone || '-' }}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">订单编号：</span>
          <span>#{{ currentReview.order_id }}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">房型：</span>
          <span>{{ currentReview.room_type_name || '-' }}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">综合评分：</span>
          <a-rate :value="currentReview.score" disabled />
          <span style="margin-left: 8px">{{ currentReview.score }}分</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">评价时间：</span>
          <span>{{ formatDateTime(currentReview.created_at) }}</span>
        </div>
        <a-divider />
        <div class="detail-section">
          <h4>评价内容</h4>
          <p>{{ currentReview.content }}</p>
        </div>
        <div v-if="currentReview.photos?.length" class="detail-section">
          <h4>评价图片</h4>
          <div class="detail-photos">
            <a-image
              v-for="(photo, idx) in currentReview.photos"
              :key="idx"
              :src="getFullUrl(photo)"
              :width="100"
              :height="100"
              style="margin-right: 8px; margin-bottom: 8px"
            />
          </div>
        </div>
      </div>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { message, Modal } from 'ant-design-vue'
import {
  MoreOutlined,
  EditOutlined,
  EyeOutlined,
  DeleteOutlined
} from '@ant-design/icons-vue'
import { getReviews, replyReview, deleteReview, getReviewStats } from '@/api/review'
import { useAppStore } from '@/stores/app'
import { formatDateTime } from '@/utils/date'

const appStore = useAppStore()
const loading = ref(false)
const reviewList = ref<any[]>([])
const currentReview = ref<any>(null)
const replyModalVisible = ref(false)
const detailModalVisible = ref(false)
const replySubmitting = ref(false)

const stats = reactive({
  total_reviews: 0,
  avg_score: 0,
  good_count: 0,
  bad_count: 0
})

const filter = reactive({
  score: undefined as number | undefined,
  dateRange: null as any,
  keyword: ''
})

const pagination = reactive({
  current: 1,
  pageSize: 10,
  total: 0,
  showSizeChanger: true,
  showQuickJumper: true,
  onChange: (page: number, pageSize: number) => {
    pagination.current = page
    pagination.pageSize = pageSize
    loadReviews()
  }
})

const replyForm = reactive({
  content: ''
})

const getFullUrl = (url: string) => {
  if (!url) return ''
  if (url.startsWith('http')) return url
  return appStore.resolveImageUrl(url)
}

// 加载评价统计
const loadStats = async () => {
  try {
    // 获取当前酒店ID
    const hotelId = appStore.userInfo?.hotel_id
    if (!hotelId) return

    const res = await getReviewStats(Number(hotelId))
    if (res.data) {
      stats.total_reviews = res.data.total_reviews || 0
      stats.avg_score = Number(res.data.avg_score) || 0
      stats.good_count = res.data.good_count || 0
      stats.bad_count = res.data.bad_count || 0
    }
  } catch (err) {
    console.error('加载评价统计失败', err)
  }
}

// 加载评价列表
const loadReviews = async () => {
  loading.value = true
  try {
    const hotelId = appStore.userInfo?.hotel_id
    if (!hotelId) {
      message.error('未获取到酒店信息')
      return
    }

    const params: any = {
      hotel_id: Number(hotelId),
      page: pagination.current,
      pageSize: pagination.pageSize
    }

    if (filter.score) {
      params.score = filter.score
    }

    const res = await getReviews(params)
    if (res.data) {
      reviewList.value = res.data.list || []
      pagination.total = res.data.total || 0
    }
  } catch (err) {
    message.error('加载评价列表失败')
  } finally {
    loading.value = false
  }
}

// 筛选变化
const handleFilterChange = () => {
  pagination.current = 1
  loadReviews()
}

// 回复评价
const handleReply = (review: any) => {
  currentReview.value = review
  replyForm.content = review.reply || ''
  replyModalVisible.value = true
}

// 提交回复
const submitReply = async () => {
  if (!replyForm.content.trim()) {
    message.warning('请输入回复内容')
    return
  }

  replySubmitting.value = true
  try {
    await replyReview(currentReview.value.id, replyForm.content.trim())
    message.success('回复成功')
    replyModalVisible.value = false
    loadReviews()
    loadStats()
  } catch (err) {
    message.error('回复失败')
  } finally {
    replySubmitting.value = false
  }
}

// 查看详情
const handleViewDetail = (review: any) => {
  currentReview.value = review
  detailModalVisible.value = true
}

// 删除评价
const handleDelete = (review: any) => {
  Modal.confirm({
    title: '确认删除',
    content: '确定要删除这条评价吗？删除后不可恢复。',
    okText: '删除',
    okType: 'danger',
    cancelText: '取消',
    async onOk() {
      try {
        await deleteReview(review.id)
        message.success('删除成功')
        loadReviews()
        loadStats()
      } catch (err) {
        message.error('删除失败')
      }
    }
  })
}

onMounted(() => {
  loadStats()
  loadReviews()
})
</script>

<style scoped>
.review-manage {
  padding: 24px;
}

.stats-row {
  margin-bottom: 24px;
}

.filter-section {
  margin-bottom: 24px;
}

.review-list {
  margin-top: 16px;
}

.review-item {
  padding: 16px;
  background: #fafafa;
  border-radius: 8px;
}

.review-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 12px;
}

.reviewer-info {
  display: flex;
  align-items: center;
  gap: 12px;
}

.reviewer-detail {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.reviewer-name {
  font-weight: 500;
  font-size: 14px;
}

.review-meta {
  display: flex;
  align-items: center;
  gap: 12px;
}

.review-date {
  color: #999;
  font-size: 12px;
}

.review-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.review-content {
  margin-bottom: 12px;
}

.review-content p {
  margin: 0 0 12px 0;
  line-height: 1.6;
}

.review-photos {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.review-ratings {
  display: flex;
  gap: 24px;
  margin-bottom: 12px;
}

.rating-item {
  display: flex;
  align-items: center;
  gap: 8px;
}

.rating-label {
  color: #666;
  font-size: 12px;
}

.hotel-reply {
  background: #e6f7ff;
  border-left: 3px solid #1890ff;
  padding: 12px 16px;
  border-radius: 4px;
  margin-top: 12px;
}

.reply-header {
  display: flex;
  justify-content: space-between;
  margin-bottom: 8px;
}

.reply-title {
  font-weight: 500;
  color: #1890ff;
}

.reply-date {
  color: #999;
  font-size: 12px;
}

.reply-content {
  margin: 0;
  color: #333;
}

.review-detail {
  padding: 16px;
}

.detail-row {
  display: flex;
  margin-bottom: 12px;
  align-items: center;
}

.detail-label {
  color: #666;
  width: 100px;
  flex-shrink: 0;
}

.detail-section {
  margin-top: 16px;
}

.detail-section h4 {
  margin-bottom: 12px;
  color: #333;
}

.detail-photos {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
</style>
