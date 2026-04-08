<template>
  <div class="ota-booking-container">
    <!-- Header Section (Floating if possible) -->
    <div class="ota-header" v-if="currentStep === 0">
      <div class="hero-bg">
        <div class="hero-overlay"></div>
        <div class="hero-content">
          <h1 class="animate__animated animate__fadeInDown">探索您的完美下榻之地</h1>
          <p class="animate__animated animate__fadeInUp animate__delay-1s">
            <span class="ota-highlight">100,000+</span> 间智能客房 · 实时预订 · 极速入住
          </p>
        </div>
      </div>
      
      <!-- Floating Search Bar -->
      <div class="floating-search-wrapper">
        <a-card class="ota-search-card" :bordered="false">
          <a-form layout="vertical" size="large">
            <a-row :gutter="[12, 12]" align="middle">
              <a-col :xs="24" :md="7">
                <div class="search-item">
                  <span class="search-label">目的地/酒店名称</span>
                  <a-input 
                    v-model:value="searchForm.destination" 
                    placeholder="城市、商圈或酒店" 
                    :bordered="false"
                    class="ota-input"
                  >
                    <template #prefix><EnvironmentFilled style="color: #008cff" /></template>
                  </a-input>
                </div>
              </a-col>
              <a-col :xs="24" :md="9">
                <div class="search-item divider-left">
                  <span class="search-label">入住 - 退房日期</span>
                  <a-range-picker 
                    v-model:value="dateRange" 
                    :disabled-date="(d: any) => d && d < dayjs().startOf('day')"
                    :bordered="false"
                    class="ota-range-picker"
                    :separator="'-'"
                  />
                </div>
              </a-col>
              <a-col :xs="24" :md="5">
                <div class="search-item divider-left">
                  <span class="search-label">房间及人数</span>
                  <div class="ota-guest-selector" @click="showGuestSelector = !showGuestSelector">
                    <UserOutlined style="color: #008cff; margin-right: 8px;" />
                    <span>{{ searchForm.rooms }}间, {{ searchForm.guests }}人</span>
                  </div>
                  <!-- Simple Popover replacement -->
                  <div v-if="showGuestSelector" class="guest-popover">
                    <div class="popover-item">
                      <span>房间</span>
                      <a-input-number v-model:value="searchForm.rooms" :min="1" :max="5" size="small" />
                    </div>
                    <div class="popover-item">
                      <span>人数</span>
                      <a-input-number v-model:value="searchForm.guests" :min="1" :max="10" size="small" />
                    </div>
                    <div class="popover-footer">
                      <a-button type="link" size="small" @click="showGuestSelector = false">确定</a-button>
                    </div>
                  </div>
                </div>
              </a-col>
              <a-col :xs="24" :md="3">
                <a-button type="primary" class="ota-search-btn" block @click="searchHotels">
                  搜索
                </a-button>
              </a-col>
            </a-row>
          </a-form>
        </a-card>
      </div>
    </div>

    <!-- Main Content Area -->
    <div class="ota-content-wrapper" :class="{ 'with-padding': currentStep > 0 }">
      <!-- Steps Navigation (Visible after step 0) -->
      <div v-if="currentStep > 0" class="ota-steps-nav">
        <a-steps :current="currentStep" size="small" class="ota-custom-steps">
          <a-step title="选择酒店" />
          <a-step title="房型预订" />
          <a-step title="订单确认" />
          <a-step title="预订成功" />
        </a-steps>
      </div>

      <!-- Step 0: Featured / Recommendations -->
      <div v-if="currentStep === 0" class="recommendations-section">
        <div class="section-header">
          <h2 class="section-title">✨ 精选热门推荐</h2>
          <a-button type="link">查看更多 <RightOutlined /></a-button>
        </div>
        
        <a-row :gutter="[20, 20]">
          <a-col :xs="24" :sm="12" :lg="8" v-for="hotel in recommendHotels" :key="hotel.id">
            <div class="ota-hotel-card" @click="selectHotel(hotel)">
              <div class="card-image-wrapper">
                <img :src="hotel.image || '/hotel-placeholder.jpg'" :alt="hotel.name" />
                <div class="card-badge" v-if="hotel.promotion">{{ hotel.promotion }}</div>
                <div class="card-wishlist"><HeartOutlined /></div>
              </div>
              <div class="card-body">
                <div class="card-header">
                  <h3 class="hotel-title">{{ hotel.name }}</h3>
                  <div class="hotel-stars">
                    <StarFilled v-for="i in hotel.star" :key="i" />
                  </div>
                </div>
                <div class="hotel-info-row">
                  <span class="location-text"><EnvironmentOutlined /> {{ hotel.location }}</span>
                </div>
                <div class="hotel-rating-row">
                  <div class="rating-badge">{{ hotel.rating }}</div>
                  <span class="rating-text">超赞 · {{ hotel.reviewCount }} 条评价</span>
                </div>
                <div class="hotel-tags">
                  <span class="ota-tag success">免费取消</span>
                  <span class="ota-tag info">立即确认</span>
                </div>
                <div class="card-footer">
                  <div class="price-box">
                    <span class="currency">¥</span>
                    <span class="amount">{{ hotel.price }}</span>
                    <span class="unit">/晚起</span>
                  </div>
                </div>
              </div>
            </div>
          </a-col>
        </a-row>
      </div>

      <!-- Step 1: Hotel Search Results -->
      <div v-if="currentStep === 1" class="search-results-section">
        <div class="results-header">
          <div class="results-count">为您找到 {{ filteredHotels.length }} 家酒店</div>
          <div class="results-filters">
            <a-space>
              <a-select v-model:value="filters.star" placeholder="星级" style="width: 110px" allow-clear>
                <a-select-option value="5">5 星级</a-select-option>
                <a-select-option value="4">4 星级</a-select-option>
                <a-select-option value="3">3 星级</a-select-option>
              </a-select>
              <a-select v-model:value="filters.price" placeholder="价格区间" style="width: 120px" allow-clear>
                <a-select-option value="0-300">¥0-300</a-select-option>
                <a-select-option value="300-500">¥300-500</a-select-option>
                <a-select-option value="500-1000">¥500-1000</a-select-option>
                <a-select-option value="1000+">¥1000+</a-select-option>
              </a-select>
              <a-select v-model:value="filters.sort" style="width: 120px">
                <a-select-option value="recommend">智能排序</a-select-option>
                <a-select-option value="price_asc">低价优先</a-select-option>
                <a-select-option value="rating">好评优先</a-select-option>
              </a-select>
            </a-space>
          </div>
        </div>

        <div class="hotel-list-vertical">
          <div class="ota-list-item" v-for="hotel in filteredHotels" :key="hotel.id" @click="selectHotel(hotel)">
            <a-row :gutter="24">
              <a-col :md="7">
                <div class="item-image">
                  <img :src="hotel.image || '/hotel-placeholder.jpg'" :alt="hotel.name" />
                </div>
              </a-col>
              <a-col :md="12">
                <div class="item-content">
                  <h3 class="item-title">{{ hotel.name }}</h3>
                  <div class="item-stars">
                    <StarFilled v-for="i in hotel.star" :key="i" />
                    <span class="star-label">{{ hotel.star }}星级</span>
                  </div>
                  <div class="item-location"><EnvironmentOutlined /> {{ hotel.location }}</div>
                  <div class="item-features">
                    <span class="feature-tag">无线网络</span>
                    <span class="feature-tag">行李寄存</span>
                    <span class="feature-tag">24小时前台</span>
                  </div>
                  <div class="item-benefit">
                    <CheckCircleOutlined style="color: #52c41a" /> 极速办理入住，无需排队
                  </div>
                </div>
              </a-col>
              <a-col :md="5" class="item-price-action">
                <div class="item-rating-box">
                  <div class="rating-info">
                    <span class="rating-desc">非常好</span>
                    <span class="rating-count">{{ hotel.reviewCount }}条评价</span>
                  </div>
                  <div class="rating-score">{{ hotel.rating }}</div>
                </div>
                <div class="spacer"></div>
                <div class="item-price-wrapper">
                  <div class="price-box">
                    <span class="currency">¥</span>
                    <span class="amount">{{ hotel.price }}</span>
                    <span class="unit">/晚起</span>
                  </div>
                  <a-button type="primary" class="ota-action-btn">查看详情</a-button>
                </div>
              </a-col>
            </a-row>
          </div>
        </div>
      </div>

      <!-- Step 2: Room Selection -->
      <div v-if="currentStep === 2" class="room-selection-section">
        <div class="back-nav" @click="currentStep = 1">
          <LeftOutlined /> 返回列表
        </div>
        
        <div class="hotel-detail-header" v-if="selectedHotel">
          <div class="header-info">
            <h1 class="detail-title">{{ selectedHotel.name }}</h1>
            <div class="detail-meta">
              <span class="stars"><StarFilled v-for="i in selectedHotel.star" :key="i" /></span>
              <span class="location"><EnvironmentOutlined /> {{ selectedHotel.location }}</span>
            </div>
          </div>
          <div class="header-rating">
            <div class="score">{{ selectedHotel.rating }}</div>
            <div class="info">
              <div class="desc">超赞</div>
              <div class="count">{{ selectedHotel.reviewCount }}条评价</div>
            </div>
          </div>
        </div>

        <div class="ota-room-list">
          <div class="room-item-card" v-for="room in selectedHotel?.rooms" :key="room.id">
            <a-row :gutter="20">
              <a-col :md="6">
                <div class="room-preview">
                  <img :src="room.image || '/room-placeholder.jpg'" :alt="room.name" />
                </div>
              </a-col>
              <a-col :md="12">
                <div class="room-info">
                  <h3 class="room-title">{{ room.name }}</h3>
                  <div class="room-specs">
                    <span>📐 {{ room.area }}m²</span>
                    <span>🛏️ {{ room.bedType }}</span>
                    <span>👥 {{ room.maxGuests }}人</span>
                  </div>
                  <div class="room-policies">
                    <div class="policy-item"><CoffeeOutlined /> {{ room.hasBreakfast ? '含早餐' : '不含早' }}</div>
                    <div class="policy-item success" v-if="room.freeCancel"><CheckCircleOutlined /> 免费取消 (入住前24h)</div>
                    <div class="policy-item" v-if="room.hasWifi"><WifiOutlined /> 免费无线网络</div>
                  </div>
                </div>
              </a-col>
              <a-col :md="6" class="room-cta">
                <div class="room-price-info">
                  <div class="price-main">
                    <span class="currency">¥</span>
                    <span class="amount">{{ room.price }}</span>
                  </div>
                  <div class="price-sub">含税费 / 晚</div>
                </div>
                <a-button 
                  type="primary" 
                  size="large" 
                  class="ota-book-btn"
                  :disabled="room.availableCount === 0"
                  @click="selectRoom(room)"
                >
                  {{ room.availableCount === 0 ? '已售罄' : '立即预订' }}
                </a-button>
                <div class="room-status" :class="{ warning: room.availableCount < 3 }">
                  仅剩 {{ room.availableCount }} 间
                </div>
              </a-col>
            </a-row>
          </div>
        </div>
      </div>

      <!-- Step 3: Order Confirmation -->
      <div v-if="currentStep === 3" class="order-confirmation-section">
        <a-row :gutter="24">
          <a-col :md="16">
            <!-- Guest Selection Section -->
            <a-card class="ota-form-card frequent-guests-card" title="常用入住人" :bordered="false">
              <template #extra>
                <a-button type="link" @click="handleAddGuest">
                  <PlusOutlined /> 管理名册
                </a-button>
              </template>
              <div class="frequent-guest-list">
                <div 
                  v-for="guest in frequentGuests" 
                  :key="guest.id" 
                  class="guest-chip"
                  :class="{ active: bookingForm.idNumber === guest.id_number }"
                  @click="selectFrequentGuest(guest)"
                >
                  <span class="name">{{ guest.name }}</span>
                  <div class="actions">
                    <EditOutlined @click.stop="handleEditGuest(guest)" />
                    <a-popconfirm title="确定删除吗？" @confirm.stop="handleDeleteGuest(guest.id!)">
                      <DeleteOutlined @click.stop />
                    </a-popconfirm>
                  </div>
                </div>
                <div v-if="frequentGuests.length === 0" class="empty-tip">
                  暂无常用联系人，填写后可勾选保存
                </div>
              </div>
            </a-card>

            <a-card class="ota-form-card" title="入住人信息" :bordered="false" style="margin-top: 20px;">
              <a-form :model="bookingForm" layout="vertical">
                <a-row :gutter="16">
                  <a-col :span="12">
                    <a-form-item label="姓名" required>
                      <a-input v-model:value="bookingForm.guestName" placeholder="请填写真实姓名" />
                    </a-form-item>
                  </a-col>
                  <a-col :span="12">
                    <a-form-item label="手机号" required>
                      <a-input v-model:value="bookingForm.phone" placeholder="接收确认短信" />
                    </a-form-item>
                  </a-col>
                </a-row>
                <a-row :gutter="16">
                  <a-col :span="8">
                    <a-form-item label="证件类型" required>
                      <a-select v-model:value="bookingForm.idType">
                        <a-select-option value="idcard">身份证</a-select-option>
                        <a-select-option value="passport">护照</a-select-option>
                      </a-select>
                    </a-form-item>
                  </a-col>
                  <a-col :span="16">
                    <a-form-item label="证件号码" required>
                      <a-input v-model:value="bookingForm.idNumber" placeholder="请输入有效证件号" />
                    </a-form-item>
                  </a-col>
                </a-row>
                <a-form-item>
                  <a-checkbox v-model:checked="saveAsFrequent">保存到常用入住人名册</a-checkbox>
                </a-form-item>
                <a-form-item label="特殊要求">
                  <a-textarea v-model:value="bookingForm.remark" :rows="3" placeholder="如：高楼层、无烟房等" />
                </a-form-item>
              </a-form>
            </a-card>

            <a-card class="ota-form-card" title="支付方式" :bordered="false" style="margin-top: 20px;">
              <a-radio-group v-model:value="paymentMethod" class="payment-group">
                <a-radio value="balance" class="payment-item">
                  <WalletOutlined /> 余额支付 (推荐)
                </a-radio>
                <a-radio value="wechat" class="payment-item">
                  <WechatOutlined style="color: #07c160" /> 微信支付
                </a-radio>
                <a-radio value="alipay" class="payment-item">
                  <AlipayCircleOutlined style="color: #1677ff" /> 支付宝
                </a-radio>
              </a-radio-group>
            </a-card>
          </a-col>

          <a-col :md="8">
            <div class="order-summary-card">
              <div class="summary-hotel">
                <img :src="selectedHotel?.image" class="hotel-mini-img" />
                <div class="hotel-mini-info">
                  <h4>{{ selectedHotel?.name }}</h4>
                  <div class="room-name">{{ selectedRoom?.name }}</div>
                </div>
              </div>
              <div class="summary-details">
                <div class="detail-item">
                  <span>入住</span>
                  <span>{{ dayjs(dateRange[0]).format('MM-DD') }} ({{ nights }}晚)</span>
                </div>
                <div class="detail-item">
                  <span>退房</span>
                  <span>{{ dayjs(dateRange[1]).format('MM-DD') }}</span>
                </div>
              </div>
              <a-divider />
              <div class="price-breakdown">
                <div class="price-row">
                  <span>房费 ({{ nights }}晚)</span>
                  <span>¥{{ (selectedRoom?.price || 0) * nights }}</span>
                </div>
                <div class="price-row total">
                  <span>应付总额</span>
                  <span class="total-amount">¥{{ (selectedRoom?.price || 0) * nights }}</span>
                </div>
              </div>
              <a-button type="primary" size="large" block class="ota-confirm-btn" :loading="submitting" @click="submitBooking">
                确认支付
              </a-button>
              <div class="security-tip">
                <SecurityScanOutlined /> 安全支付保障 · 极速确认
              </div>
            </div>
          </a-col>
        </a-row>
      </div>

      <!-- Success Result -->
      <div v-if="currentStep === 4" class="success-result-section">
        <a-result
          status="success"
          title="预订已成功确认！"
          :sub-title="`预订编号: ${bookingNo}。我们已向您的手机发送了确认短信。`"
        >
          <template #extra>
            <div class="success-actions">
              <a-button type="primary" size="large" @click="$router.push('/guest/checkin-online')">
                前往在线办理入住
              </a-button>
              <a-button size="large" @click="resetAll">返回首页</a-button>
            </div>
          </template>
        </a-result>
      </div>
    </div>

    <!-- Frequent Guest Management Modal -->
    <a-modal
      v-model:open="showGuestModal"
      :title="editingGuestId ? '编辑联系人' : '添加联系人'"
      @ok="saveGuest"
    >
      <a-form layout="vertical">
        <a-form-item label="姓名" required>
          <a-input v-model:value="guestModalForm.name" placeholder="请输入姓名" />
        </a-form-item>
        <a-form-item label="手机号" required>
          <a-input v-model:value="guestModalForm.phone" placeholder="请输入手机号" />
        </a-form-item>
        <a-form-item label="证件类型" required>
          <a-select v-model:value="guestModalForm.id_type">
            <a-select-option value="idcard">身份证</a-select-option>
            <a-select-option value="passport">护照</a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item label="证件号码" required>
          <a-input v-model:value="guestModalForm.id_number" placeholder="请输入证件号" />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { message, Modal } from 'ant-design-vue'
import dayjs, { Dayjs } from 'dayjs'
import guestService, { FrequentGuest } from '@/api/frequent-guest'
import { authService } from '@/api/auth'
import { hotelApi } from '@/api/hotel'
import { useAppStore } from '@/stores/app'
import {
  EnvironmentOutlined, EnvironmentFilled, StarOutlined, StarFilled,
  UserOutlined, MobileOutlined, CheckOutlined, RightOutlined,
  HeartOutlined, CheckCircleOutlined, LeftOutlined, WifiOutlined,
  CoffeeOutlined, WalletOutlined, WechatOutlined, AlipayCircleOutlined,
  SecurityScanOutlined, PlusOutlined, DeleteOutlined, EditOutlined
} from '@ant-design/icons-vue'

// --- State ---
const router = useRouter()
const appStore = useAppStore()
const currentStep = ref(0)
const showGuestSelector = ref(false)
const submitting = ref(false)
const bookingNo = ref('')
const selectedHotel = ref<any>(null)
const selectedRoom = ref<any>(null)
const paymentMethod = ref('balance')
const frequentGuests = ref<FrequentGuest[]>([])
const saveAsFrequent = ref(false)
const showGuestModal = ref(false)
const guestModalForm = reactive<FrequentGuest>({
  name: '',
  phone: '',
  id_type: 'idcard',
  id_number: ''
})
const editingGuestId = ref<number | null>(null)

const searchForm = reactive({
  destination: '',
  rooms: 1,
  guests: 2
})

const dateRange = ref<[Dayjs, Dayjs]>([
  dayjs(),
  dayjs().add(1, 'day')
])

const filters = reactive({
  star: undefined as string | undefined,
  price: undefined as string | undefined,
  sort: 'recommend'
})

const bookingForm = reactive({
  guestName: '',
  phone: '',
  idType: 'idcard',
  idNumber: '',
  remark: ''
})

const hotelList = ref<any[]>([])

// --- Computed ---
const nights = computed(() => {
  if (dateRange.value[0] && dateRange.value[1]) {
    return dateRange.value[1].diff(dateRange.value[0], 'day')
  }
  return 1
})

const recommendHotels = computed(() => hotelList.value.slice(0, 6))

const filteredHotels = computed(() => {
  let result = [...hotelList.value]
  if (filters.star) result = result.filter(h => h.star === parseInt(filters.star!))
  if (filters.price) {
    const [min, max] = filters.price.split('-').map(Number)
    result = result.filter(h => max ? (h.price >= min && h.price <= max) : h.price >= min)
  }
  if (filters.sort === 'price_asc') result.sort((a, b) => a.price - b.price)
  else if (filters.sort === 'rating') result.sort((a, b) => b.rating - a.rating)
  return result
})

// --- Methods ---
const searchHotels = async (shouldAdvance = true) => {
  if (!dateRange.value?.[0] || !dateRange.value?.[1]) return message.warning('请选择入住和退房日期')
  try {
    const items = await hotelApi.searchHotels({
      destination: searchForm.destination || '',
      check_in: dateRange.value[0].format('YYYY-MM-DD'),
      check_out: dateRange.value[1].format('YYYY-MM-DD'),
      rooms: searchForm.rooms,
      guests: searchForm.guests
    })
    hotelList.value = items.map((item: any) => ({
      ...item,
      reviewCount: Number(item.reviewCount ?? item.review_count ?? 0),
      star: Number(item.star || item.star_rating || 3),
      rooms: []
    }))
    if (shouldAdvance) {
      currentStep.value = 1
    }
  } catch (error) {
    message.error('酒店搜索失败，请稍后重试')
  }
}

const selectHotel = async (hotel: any) => {
  try {
    const rooms = await hotelApi.getRoomAvailability(
      Number(hotel.id),
      dateRange.value[0].format('YYYY-MM-DD'),
      dateRange.value[1].format('YYYY-MM-DD')
    )
    selectedHotel.value = {
      ...hotel,
      rooms: (rooms || []).map((room: any) => ({
        ...room,
        name: room.name || room.room_name || room.room_number,
        area: Number(room.area || 0),
        bedType: room.bedType || room.bed_type || '-',
        maxGuests: Number(room.maxGuests || room.max_guests || 1),
        price: Number(room.price || room.room_price || 0),
        availableCount: Number(room.available_count || room.availableCount || 0),
        image: room.image || room.image_url || '/room-placeholder.jpg',
        hasBreakfast: Boolean(room.hasBreakfast),
        freeCancel: Boolean(room.freeCancel),
        hasWifi: Boolean(room.hasWifi)
      }))
    }
    currentStep.value = 2
  } catch (error) {
    message.error('加载房态失败，请稍后重试')
  }
}

const selectRoom = (room: any) => {
  if (!authService.isAuthenticated()) {
    Modal.confirm({
      title: '请先登录',
      content: '预订房间需要先登录账号，是否立即登录？',
      okText: '立即登录',
      cancelText: '取消',
      onOk: () => {
        appStore.showLoginModal = true
      }
    })
    return
  }
  selectedRoom.value = room
  currentStep.value = 3
  fetchFrequentGuests()
}

const fetchFrequentGuests = async () => {
  try {
    const res = await guestService.list()
    if (res.code === 200) {
      frequentGuests.value = res.data.guests
    }
  } catch (error) {
    console.error('获取常用联系人失败:', error)
  }
}

const selectFrequentGuest = (guest: FrequentGuest) => {
  bookingForm.guestName = guest.name
  bookingForm.phone = guest.phone
  bookingForm.idType = guest.id_type
  bookingForm.idNumber = guest.id_number
  message.success(`已选择：${guest.name}`)
}

const handleAddGuest = () => {
  editingGuestId.value = null
  Object.assign(guestModalForm, { name: '', phone: '', id_type: 'idcard', id_number: '' })
  showGuestModal.value = true
}

const handleEditGuest = (guest: FrequentGuest) => {
  editingGuestId.value = guest.id || null
  Object.assign(guestModalForm, { ...guest })
  showGuestModal.value = true
}

const handleDeleteGuest = async (id: number) => {
  try {
    const res = await guestService.remove(id)
    if (res.code === 200) {
      message.success('删除成功')
      fetchFrequentGuests()
    }
  } catch (error) {
    message.error('删除失败')
  }
}

const saveGuest = async () => {
  if (!guestModalForm.name || !guestModalForm.phone || !guestModalForm.id_number) {
    return message.warning('请填写完整信息')
  }
  try {
    let res
    if (editingGuestId.value) {
      res = await guestService.update(editingGuestId.value, guestModalForm)
    } else {
      res = await guestService.create(guestModalForm)
    }
    if (res.code === 200) {
      message.success(editingGuestId.value ? '更新成功' : '添加成功')
      showGuestModal.value = false
      fetchFrequentGuests()
    }
  } catch (error) {
    message.error('操作失败')
  }
}

const submitBooking = async () => {
  if (!bookingForm.guestName || !bookingForm.phone || !bookingForm.idNumber) {
    return message.warning('请完善入住人信息')
  }
  
  submitting.value = true
  try {
    // 如果勾选了保存为常用联系人，且该联系人不在列表中
    if (saveAsFrequent.value) {
      const exists = frequentGuests.value.some(g => g.id_number === bookingForm.idNumber)
      if (!exists) {
        await guestService.create({
          name: bookingForm.guestName,
          phone: bookingForm.phone,
          id_type: bookingForm.idType as any,
          id_number: bookingForm.idNumber
        })
      }
    }

    const booking = await hotelApi.createBooking({
      room_id: Number(selectedRoom.value?.id),
      check_in_date: dateRange.value[0].format('YYYY-MM-DD'),
      check_out_date: dateRange.value[1].format('YYYY-MM-DD'),
      guest_name: bookingForm.guestName,
      guest_phone: bookingForm.phone,
      guest_id_number: bookingForm.idNumber,
      guest_count: searchForm.guests,
      special_requests: bookingForm.remark,
      payment_method: paymentMethod.value,
      status: 'pending'
    })
    bookingNo.value = booking?.booking_number || booking?.booking_no || ('BK' + Date.now().toString().slice(-8))
    currentStep.value = 4
    message.success('预订成功！')
  } catch (error) {
    message.error('预订失败，请稍后重试')
  } finally {
    submitting.value = false
  }
}

const resetAll = () => {
  currentStep.value = 0
  selectedHotel.value = null
  selectedRoom.value = null
  Object.assign(searchForm, { destination: '', rooms: 1, guests: 2 })
  Object.assign(bookingForm, { guestName: '', phone: '', idNumber: '', remark: '' })
}

onMounted(() => {
  searchHotels(false)
})
</script>

<style scoped>
/* OTA Professional Styles */
.ota-booking-container {
  min-height: 100vh;
  background-color: #f5f7fa;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial;
}

/* Hero Section */
.hero-bg {
  position: relative;
  height: 420px;
  background-image: url('https://images.unsplash.com/photo-1571896349842-33c89424de2d?q=80&w=2000&auto=format&fit=crop');
  background-size: cover;
  background-position: center;
  display: flex;
  align-items: center;
  justify-content: center;
}

.hero-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: linear-gradient(to bottom, rgba(0,0,0,0.3), rgba(0,0,0,0.5));
}

.hero-content {
  position: relative;
  text-align: center;
  color: white;
  z-index: 1;
}

.hero-content h1 {
  font-size: 48px;
  font-weight: 800;
  color: white;
  text-shadow: 0 2px 10px rgba(0,0,0,0.3);
  margin-bottom: 16px;
}

.hero-content p {
  font-size: 20px;
  opacity: 0.95;
}

.ota-highlight {
  color: #ff9d00;
  font-weight: bold;
  font-size: 24px;
}

/* Floating Search Bar */
.floating-search-wrapper {
  max-width: 1040px;
  margin: -60px auto 0;
  padding: 0 20px;
  position: relative;
  z-index: 10;
}

.ota-search-card {
  border-radius: 16px;
  box-shadow: 0 10px 30px rgba(0,0,0,0.1);
  padding: 8px;
  background: white;
}

.search-item {
  padding: 8px 16px;
}

.search-label {
  display: block;
  font-size: 12px;
  color: #8c8c8c;
  margin-bottom: 4px;
  font-weight: 600;
}

.divider-left {
  border-left: 1px solid #f0f0f0;
}

.ota-input :deep(.ant-input) {
  font-size: 16px;
  font-weight: 500;
}

.ota-range-picker :deep(.ant-picker-input > input) {
  font-size: 16px;
  font-weight: 500;
}

.ota-guest-selector {
  font-size: 16px;
  font-weight: 500;
  cursor: pointer;
  padding: 4px 0;
  display: flex;
  align-items: center;
}

.guest-popover {
  position: absolute;
  top: 100%;
  left: 0;
  width: 200px;
  background: white;
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  border-radius: 8px;
  padding: 12px;
  margin-top: 12px;
  z-index: 100;
}

.popover-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}

.ota-search-btn {
  height: 56px;
  font-size: 18px;
  font-weight: bold;
  border-radius: 12px;
  background: linear-gradient(90deg, #008cff, #0056ff);
}

/* Content Wrapper */
.ota-content-wrapper {
  max-width: 1100px;
  margin: 40px auto;
  padding: 0 20px;
}

.with-padding {
  padding-top: 20px;
}

/* Section Header */
.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
}

.section-title {
  font-size: 24px;
  font-weight: 700;
  color: #1a1a1a;
  margin: 0;
}

/* OTA Hotel Card */
.ota-hotel-card {
  background: white;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 2px 12px rgba(0,0,0,0.05);
  transition: all 0.3s ease;
  cursor: pointer;
  height: 100%;
}

.ota-hotel-card:hover {
  transform: translateY(-6px);
  box-shadow: 0 12px 24px rgba(0,0,0,0.1);
}

.card-image-wrapper {
  position: relative;
  height: 200px;
}

.card-image-wrapper img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.card-badge {
  position: absolute;
  top: 12px;
  left: 12px;
  background: #ff4d4f;
  color: white;
  padding: 4px 10px;
  border-radius: 6px;
  font-weight: bold;
  font-size: 12px;
}

.card-wishlist {
  position: absolute;
  top: 12px;
  right: 12px;
  width: 32px;
  height: 32px;
  background: rgba(255,255,255,0.8);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #8c8c8c;
}

.card-body {
  padding: 16px;
}

.hotel-title {
  font-size: 18px;
  font-weight: 700;
  margin-bottom: 4px;
  color: #1a1a1a;
}

.hotel-stars {
  color: #ff9d00;
  font-size: 12px;
}

.hotel-info-row {
  margin: 8px 0;
  font-size: 13px;
  color: #595959;
}

.hotel-rating-row {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 12px;
}

.rating-badge {
  background: #003580;
  color: white;
  padding: 2px 6px;
  border-radius: 4px;
  font-weight: bold;
  font-size: 14px;
}

.rating-text {
  font-size: 13px;
  color: #003580;
  font-weight: 600;
}

.hotel-tags {
  display: flex;
  gap: 6px;
  margin-bottom: 16px;
}

.ota-tag {
  font-size: 11px;
  padding: 2px 6px;
  border-radius: 4px;
}

.ota-tag.success { background: #e6f7ff; color: #1890ff; border: 1px solid #91d5ff; }
.ota-tag.info { background: #f6ffed; color: #52c41a; border: 1px solid #b7eb8f; }

.price-box {
  text-align: right;
}

.currency { font-size: 14px; color: #ff4d4f; font-weight: bold; margin-right: 2px; }
.amount { font-size: 26px; color: #ff4d4f; font-weight: 800; }
.unit { font-size: 12px; color: #8c8c8c; }

/* Vertical List Item */
.ota-list-item {
  background: white;
  border-radius: 12px;
  padding: 16px;
  margin-bottom: 20px;
  cursor: pointer;
  transition: all 0.2s;
  border: 1px solid transparent;
}

.ota-list-item:hover {
  border-color: #008cff;
  box-shadow: 0 4px 16px rgba(0,0,0,0.08);
}

.item-image {
  height: 180px;
  border-radius: 8px;
  overflow: hidden;
}

.item-image img { width: 100%; height: 100%; object-fit: cover; }

.item-title { font-size: 20px; font-weight: 700; margin-bottom: 4px; }
.item-stars { color: #ff9d00; margin-bottom: 8px; display: flex; align-items: center; gap: 8px; }
.star-label { color: #8c8c8c; font-size: 12px; }
.item-location { font-size: 14px; color: #595959; margin-bottom: 12px; }

.item-features { display: flex; gap: 8px; margin-bottom: 12px; }
.feature-tag { font-size: 12px; color: #8c8c8c; background: #f5f5f5; padding: 2px 8px; border-radius: 4px; }

.item-benefit { color: #52c41a; font-weight: 600; font-size: 13px; }

.item-rating-box { display: flex; justify-content: flex-end; align-items: center; gap: 12px; }
.rating-info { text-align: right; }
.rating-desc { display: block; font-weight: 700; color: #1a1a1a; }
.rating-count { font-size: 12px; color: #8c8c8c; }
.rating-score { background: #003580; color: white; width: 36px; height: 36px; border-radius: 6px 6px 6px 0; display: flex; align-items: center; justify-content: center; font-weight: bold; font-size: 16px; }

.item-price-action { display: flex; flex-direction: column; height: 180px; }
.spacer { flex: 1; }
.ota-action-btn { border-radius: 8px; height: 40px; font-weight: 700; }

/* Room Selection Styles */
.room-item-card {
  background: white;
  border-radius: 12px;
  padding: 20px;
  margin-bottom: 16px;
  border: 1px solid #f0f0f0;
}

.room-preview { height: 140px; border-radius: 8px; overflow: hidden; }
.room-preview img { width: 100%; height: 100%; object-fit: cover; }

.room-specs { margin: 8px 0; display: flex; gap: 16px; color: #8c8c8c; font-size: 13px; }
.room-policies { margin-top: 12px; }
.policy-item { font-size: 13px; margin-bottom: 4px; color: #595959; display: flex; align-items: center; gap: 6px; }
.policy-item.success { color: #52c41a; font-weight: 600; }

.room-cta { text-align: right; }
.room-price-info { margin-bottom: 12px; }
.price-main { color: #ff4d4f; }
.price-main .currency { font-size: 16px; }
.price-main .amount { font-size: 32px; }
.price-sub { font-size: 12px; color: #8c8c8c; }

.room-status { font-size: 12px; margin-top: 8px; color: #8c8c8c; }
.ota-form-card {
  border-radius: 12px;
  box-shadow: 0 2px 12px rgba(0,0,0,0.05);
}

.frequent-guest-list {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
}

.guest-chip {
  border: 1px solid #d9d9d9;
  border-radius: 6px;
  padding: 8px 12px;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 12px;
  transition: all 0.2s;
}

.guest-chip:hover {
  border-color: #008cff;
  background: #f0f7ff;
}

.guest-chip.active {
  border-color: #008cff;
  background: #e6f7ff;
  color: #008cff;
  font-weight: bold;
}

.guest-chip .actions {
  display: flex;
  gap: 8px;
  font-size: 14px;
  color: #8c8c8c;
  opacity: 0;
  transition: opacity 0.2s;
}

.guest-chip:hover .actions {
  opacity: 1;
}

.guest-chip .actions span:hover {
  color: #008cff;
}

.empty-tip {
  color: #bfbfbf;
  font-size: 13px;
}

/* Order Summary */
.order-summary-card {
  background: white;
  border-radius: 12px;
  padding: 20px;
  position: sticky;
  top: 20px;
  box-shadow: 0 2px 12px rgba(0,0,0,0.05);
}

.summary-hotel { display: flex; gap: 12px; margin-bottom: 20px; }
.hotel-mini-img { width: 60px; height: 60px; border-radius: 6px; object-fit: cover; }
.hotel-mini-info h4 { margin: 0; font-size: 16px; }
.hotel-mini-info .room-name { font-size: 13px; color: #8c8c8c; }

.summary-details { background: #f9f9f9; padding: 12px; border-radius: 8px; }
.detail-item { display: flex; justify-content: space-between; margin-bottom: 4px; font-size: 13px; }

.price-row { display: flex; justify-content: space-between; margin-bottom: 8px; }
.price-row.total { margin-top: 16px; border-top: 1px solid #f0f0f0; padding-top: 16px; }
.total-amount { font-size: 24px; color: #ff4d4f; font-weight: 800; }

.ota-confirm-btn { height: 48px; font-size: 18px; font-weight: 700; border-radius: 8px; margin-top: 12px; }
.security-tip { text-align: center; margin-top: 12px; font-size: 12px; color: #8c8c8c; }

/* Animation helpers */
.animate__animated { animation-duration: 0.8s; }
@keyframes fadeInDown { from { opacity: 0; transform: translateY(-20px); } to { opacity: 1; transform: translateY(0); } }
.animate__fadeInDown { animation-name: fadeInDown; }
@keyframes fadeInUp { from { opacity: 0; transform: translateY(20px); } to { opacity: 1; transform: translateY(0); } }
.animate__fadeInUp { animation-name: fadeInUp; }

/* Responsive adjustments */
@media (max-width: 768px) {
  .hero-content h1 { font-size: 32px; }
  .floating-search-wrapper { margin-top: -100px; }
  .ota-search-btn { margin-top: 12px; }
  .divider-left { border-left: none; border-top: 1px solid #f0f0f0; }
}
</style>
