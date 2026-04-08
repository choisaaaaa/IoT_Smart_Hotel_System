<template>
  <div class="guest-booking">
    <!-- 步骤条 -->
    <a-steps :current="currentStep" size="small" style="margin-bottom: 24px;">
      <a-step title="选择日期" />
      <a-step title="选择酒店" />
      <a-step title="选择房型" />
      <a-step title="填写信息" />
      <a-step title="完成预订" />
    </a-steps>

    <!-- 步骤 1: 选择日期 -->
    <div v-if="currentStep === 0" class="step-content">
      <div class="hero-section">
        <h1>🏨 智联酒店预订</h1>
        <p>智能推荐 · 实时确认 · 无忧入住</p>
      </div>

      <a-card class="search-card" :bordered="false">
        <a-form layout="vertical" size="large">
          <a-row :gutter="16">
            <a-col :xs="24" :md="8">
              <a-form-item label="目的地" required>
                <a-input 
                  v-model:value="searchForm.destination" 
                  placeholder="城市、商圈、酒店名称" 
                  size="large"
                >
                  <template #prefix><EnvironmentOutlined /></template>
                </a-input>
              </a-form-item>
            </a-col>
            <a-col :xs="24" :md="12">
              <a-form-item label="入住日期" required>
                <a-range-picker 
                  v-model:value="dateRange" 
                  :disabled-date="(d: any) => d && d < dayjs().startOf('day')"
                  style="width: 100%;"
                  size="large"
                />
              </a-form-item>
            </a-col>
            <a-col :xs="24" :md="4">
              <a-form-item label="房间/人数">
                <a-space>
                  <a-input-number v-model:value="searchForm.rooms" :min="1" :max="5" style="width: 100px;" />
                  <a-input-number v-model:value="searchForm.guests" :min="1" :max="10" style="width: 100px;" />
                </a-space>
              </a-form-item>
            </a-col>
          </a-row>
          <a-form-item>
            <a-button type="primary" size="large" block @click="searchHotels">
              <SearchOutlined /> 搜索酒店
            </a-button>
          </a-form-item>
        </a-form>
      </a-card>

      <a-divider orientation="left">✨ 热门酒店推荐</a-divider>
      <a-row :gutter="[16, 16]">
        <a-col :xs="24" :sm="12" :lg="8" v-for="hotel in recommendHotels" :key="hotel.id">
          <a-card hoverable class="hotel-card" @click="selectHotel(hotel)">
            <template #cover>
              <div class="hotel-cover">
                <img :alt="hotel.name" :src="hotel.image || '/hotel-placeholder.jpg'" />
                <a-tag v-if="hotel.promotion" color="red" class="promotion-tag">{{ hotel.promotion }}</a-tag>
              </div>
            </template>
            <a-card-meta>
              <template #title>
                <div class="hotel-name">{{ hotel.name }}</div>
                <a-tag :color="hotel.star === 5 ? 'gold' : hotel.star === 4 ? 'blue' : 'green'" size="small">
                  {{ '★'.repeat(hotel.star) }}
                </a-tag>
              </template>
              <template #description>
                <div class="hotel-location">
                  <EnvironmentOutlined /> {{ hotel.location }}
                </div>
                <div class="hotel-rating">
                  <StarOutlined /> {{ hotel.rating }}分 · {{ hotel.reviewCount }}条评价
                </div>
                <div class="hotel-price">
                  <span class="price-label">¥</span>
                  <span class="price-value">{{ hotel.price }}</span>
                  <span class="price-unit">/晚起</span>
                </div>
              </template>
            </a-card-meta>
          </a-card>
        </a-col>
      </a-row>
    </div>

    <!-- 步骤 1: 酒店列表 -->
    <div v-if="currentStep === 1" class="step-content">
      <div class="filter-bar">
        <a-space wrap size="large">
          <span style="font-weight: 600;">筛选：</span>
          <a-select v-model:value="filters.star" placeholder="星级" style="width: 120px" allow-clear>
            <a-select-option value="5">5 星级</a-select-option>
            <a-select-option value="4">4 星级</a-select-option>
            <a-select-option value="3">3 星级</a-select-option>
          </a-select>
          <a-select v-model:value="filters.price" placeholder="价格区间" style="width: 150px" allow-clear>
            <a-select-option value="0-300">¥0-300</a-select-option>
            <a-select-option value="300-500">¥300-500</a-select-option>
            <a-select-option value="500-1000">¥500-1000</a-select-option>
            <a-select-option value="1000+">¥1000+</a-select-option>
          </a-select>
          <a-select v-model:value="filters.sort" placeholder="排序" style="width: 130px">
            <a-select-option value="recommend">智能排序</a-select-option>
            <a-select-option value="price_asc">价格从低到高</a-select-option>
            <a-select-option value="price_desc">价格从高到低</a-select-option>
            <a-select-option value="rating">评分优先</a-select-option>
          </a-select>
          <a-button @click="currentStep = 0">返回修改日期</a-button>
        </a-space>
      </div>

      <a-row :gutter="16">
        <a-col :xs="24" :lg="8" v-for="hotel in filteredHotels" :key="hotel.id">
          <a-card hoverable class="hotel-card" @click="selectHotel(hotel)">
            <template #cover>
              <div class="hotel-cover">
                <img :alt="hotel.name" :src="hotel.image || '/hotel-placeholder.jpg'" />
              </div>
            </template>
            <a-card-meta>
              <template #title>
                <div class="hotel-name">{{ hotel.name }}</div>
              </template>
              <template #description>
                <div class="hotel-location"><EnvironmentOutlined /> {{ hotel.location }}</div>
                <div class="hotel-rating"><StarOutlined /> {{ hotel.rating }}分</div>
                <div class="hotel-price">
                  <span class="price-label">¥</span>
                  <span class="price-value">{{ hotel.price }}</span>
                  <span class="price-unit">/晚起</span>
                </div>
              </template>
            </a-card-meta>
          </a-card>
        </a-col>
      </a-row>
    </div>

    <!-- 步骤 2: 房型选择 -->
    <div v-if="currentStep === 2" class="step-content">
      <div v-if="selectedHotel" class="room-selection">
        <a-button @click="currentStep = 1" style="margin-bottom: 16px;">← 返回选择酒店</a-button>
        
        <a-card class="hotel-info-card">
          <a-row :gutter="16">
            <a-col :span="8">
              <img :src="selectedHotel.image" style="width: 100%; border-radius: 8px;" />
            </a-col>
            <a-col :span="16">
              <h2>{{ selectedHotel.name }}</h2>
              <p><EnvironmentOutlined /> {{ selectedHotel.location }}</p>
              <p><StarOutlined /> {{ selectedHotel.rating }}分 · {{ selectedHotel.reviewCount }}条评价</p>
            </a-col>
          </a-row>
        </a-card>

        <a-divider>选择房型</a-divider>
        <a-row :gutter="16">
          <a-col :span="24" v-for="room in selectedHotel.rooms" :key="room.id">
            <a-card 
              hoverable 
              class="room-card"
              :class="{ selected: selectedRoom?.id === room.id }"
              @click="selectRoom(room)"
            >
              <a-row :gutter="16">
                <a-col :span="6">
                  <div class="room-image">
                    <img :alt="room.name" :src="room.image || '/room-placeholder.jpg'" />
                  </div>
                </a-col>
                <a-col :span="12">
                  <h4>{{ room.name }}</h4>
                  <p class="room-desc">{{ room.description }}</p>
                  <div class="room-meta">
                    <span>📐 {{ room.area }}m²</span>
                    <span>🛏️ {{ room.bedType }}</span>
                    <span>👥 最多{{ room.maxGuests }}人</span>
                  </div>
                  <div class="room-services">
                    <a-tag v-if="room.hasBreakfast" color="orange">含早餐</a-tag>
                    <a-tag v-if="room.freeCancel" color="green">免费取消</a-tag>
                    <a-tag v-if="room.hasWifi" color="blue">免费 WiFi</a-tag>
                    <a-tag v-if="room.availableCount === 0" color="red">已售罄</a-tag>
                    <a-tag v-else color="blue">余{{ room.availableCount }}间</a-tag>
                  </div>
                </a-col>
                <a-col :span="6" class="room-price-col">
                  <div class="room-price">
                    <span class="price-symbol">¥</span>
                    <span class="price-number">{{ room.price }}</span>
                  </div>
                  <div class="price-note">/晚</div>
                  <a-button 
                    type="primary" 
                    block 
                    :disabled="selectedRoom?.id !== room.id || room.availableCount === 0"
                    @click.stop="goToNextStep"
                  >
                    选择此房型
                  </a-button>
                </a-col>
              </a-row>
            </a-card>
          </a-col>
        </a-row>
      </div>
    </div>

    <!-- 步骤 3: 填写信息 -->
    <div v-if="currentStep === 3" class="step-content">
      <a-button @click="currentStep = 2" style="margin-bottom: 16px;">← 返回选择房型</a-button>
      
      <a-card title="填写入住人信息" :bordered="false">
        <a-alert 
          message="请填写真实信息" 
          description="入住人信息需与有效证件一致，将用于酒店登记" 
          type="info" 
          show-icon 
          style="margin-bottom: 16px;"
        />
        
        <a-form :model="bookingForm" layout="vertical" size="large">
          <a-form-item label="入住人姓名" required>
            <a-input 
              v-model:value="bookingForm.guestName" 
              placeholder="姓名（与身份证一致）" 
              size="large"
            >
              <template #prefix><UserOutlined /></template>
            </a-input>
          </a-form-item>
          
          <a-form-item label="联系电话" required>
            <a-input 
              v-model:value="bookingForm.phone" 
              placeholder="手机号码" 
              size="large"
            >
              <template #prefix><MobileOutlined /></template>
            </a-input>
          </a-form-item>
          
          <a-form-item label="证件类型" required>
            <a-select v-model:value="bookingForm.idType" size="large">
              <a-select-option value="idcard">身份证</a-select-option>
              <a-select-option value="passport">护照</a-select-option>
            </a-select>
          </a-form-item>
          
          <a-form-item label="证件号码" required>
            <a-input 
              v-model:value="bookingForm.idNumber" 
              placeholder="证件号码" 
              size="large"
            />
          </a-form-item>
          
          <a-form-item label="特殊要求">
            <a-textarea 
              v-model:value="bookingForm.remark" 
              :rows="2" 
              placeholder="如：高楼层、无烟房、大床等（仅供参考，酒店将尽量安排）" 
            />
          </a-form-item>
          
          <a-divider />
          
          <a-descriptions :column="2" bordered>
            <a-descriptions-item label="预订酒店">{{ selectedHotel?.name }}</a-descriptions-item>
            <a-descriptions-item label="预订房型">{{ selectedRoom?.name }}</a-descriptions-item>
            <a-descriptions-item label="入住日期">{{ dayjs(dateRange[0]).format('YYYY-MM-DD') }}</a-descriptions-item>
            <a-descriptions-item label="退房日期">{{ dayjs(dateRange[1]).format('YYYY-MM-DD') }}</a-descriptions-item>
            <a-descriptions-item label="住宿晚数">{{ nights }}晚</a-descriptions-item>
            <a-descriptions-item label="房间价格">¥{{ selectedRoom?.price }} × {{ nights }}晚</a-descriptions-item>
            <a-descriptions-item label="订单总价" :span="2">
              <span style="color: #ff4d4f; font-weight: bold; font-size: 18px;">¥{{ (selectedRoom?.price || 0) * nights }}</span>
            </a-descriptions-item>
          </a-descriptions>
          
          <div style="margin-top: 24px;">
            <a-space>
              <a-button @click="currentStep = 2">上一步</a-button>
              <a-button type="primary" size="large" block :loading="submitting" @click="submitBooking">
                <CheckOutlined /> 确认预订并支付
              </a-button>
            </a-space>
          </div>
        </a-form>
      </a-card>
    </div>

    <!-- 步骤 4: 预订成功 -->
    <div v-if="currentStep === 4" class="step-content">
      <a-result
        status="success"
        title="🎉 预订成功！"
        :sub-title="`您的预订号：${bookingNo}，确认短信已发送至 ${bookingForm.phone}`"
      >
        <template #extra>
          <a-space direction="vertical" :size="12" style="width: 100%;">
            <a-card size="small" style="text-align: center;">
              <p style="margin: 8px 0; color: rgba(0,0,0,0.45);">入住信息</p>
              <p style="margin: 4px 0;"><strong>{{ selectedHotel?.name }}</strong></p>
              <p style="margin: 4px 0; font-size: 13px;">{{ selectedRoom?.name }}</p>
              <p style="margin: 4px 0; font-size: 13px;">{{ dayjs(dateRange[0]).format('MM-DD') }} 至 {{ dayjs(dateRange[1]).format('MM-DD') }}</p>
            </a-card>
            <a-button type="primary" block size="large" @click="$router.push('/guest/checkin-online')">
              在线办理入住
            </a-button>
            <a-button block @click="resetAll">返回首页</a-button>
          </a-space>
        </template>
      </a-result>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue'
import { message } from 'ant-design-vue'
import dayjs, { Dayjs } from 'dayjs'
import {
  SearchOutlined, EnvironmentOutlined, StarOutlined,
  UserOutlined, MobileOutlined, CheckOutlined
} from '@ant-design/icons-vue'

// 当前步骤
const currentStep = ref(0)

// 搜索表单
const searchForm = reactive({
  destination: '',
  rooms: 1,
  guests: 2
})

// 日期范围
const dateRange = reactive<[Dayjs, Dayjs]>([
  dayjs(),
  dayjs().add(1, 'day')
])

// 筛选条件
const filters = reactive({
  star: undefined as string | undefined,
  price: undefined as string | undefined,
  sort: 'recommend'
})

// 状态
const submitting = ref(false)
const bookingNo = ref('')
const selectedHotel = ref<typeof recommendHotels[0] | null>(null)
const selectedRoom = ref<any>(null)

// 预订表单
const bookingForm = reactive({
  guestName: '',
  phone: '',
  idType: 'idcard',
  idNumber: '',
  remark: ''
})

// 计算晚数
const nights = computed(() => {
  if (dateRange[0] && dateRange[1]) {
    return dateRange[1].diff(dateRange[0], 'day')
  }
  return 1
})

// 推荐酒店数据
const recommendHotels = reactive([
  {
    id: 1,
    name: '智联酒店·行政豪华房',
    location: '市中心·CBD 商圈',
    star: 5,
    rating: 4.9,
    reviewCount: 2856,
    price: 599,
    image: '/hotel1.jpg',
    promotion: '今日特价',
    rooms: [
      {
        id: 101,
        name: '豪华大床房',
        description: '宽敞舒适，城市景观',
        area: 35,
        bedType: '1.8 米大床',
        maxGuests: 2,
        price: 599,
        hasBreakfast: true,
        freeCancel: true,
        hasWifi: true,
        image: '/room1.jpg'
      },
      {
        id: 102,
        name: '豪华双床房',
        description: '适合朋友/同事出行',
        area: 38,
        bedType: '1.2 米双床',
        maxGuests: 2,
        price: 629,
        hasBreakfast: true,
        freeCancel: true,
        hasWifi: true,
        image: '/room2.jpg'
      }
    ]
  },
  {
    id: 2,
    name: '智联酒店·商务精选',
    location: '高新技术区',
    star: 4,
    rating: 4.7,
    reviewCount: 1523,
    price: 399,
    image: '/hotel2.jpg',
    rooms: [
      {
        id: 201,
        name: '商务大床房',
        description: '简约商务风格',
        area: 30,
        bedType: '1.8 米大床',
        maxGuests: 2,
        price: 399,
        hasBreakfast: false,
        freeCancel: true,
        hasWifi: true,
        image: '/room3.jpg'
      }
    ]
  },
  {
    id: 3,
    name: '智联酒店·度假套房',
    location: '风景区·湖畔',
    star: 5,
    rating: 4.8,
    reviewCount: 987,
    price: 899,
    image: '/hotel3.jpg',
    promotion: '连住优惠',
    rooms: [
      {
        id: 301,
        name: '湖景套房',
        description: '独立客厅，全景湖景',
        area: 65,
        bedType: '2 米大床',
        maxGuests: 3,
        price: 899,
        hasBreakfast: true,
        freeCancel: false,
        hasWifi: true,
        image: '/room4.jpg'
      }
    ]
  }
])

// 筛选后的酒店
const filteredHotels = computed(() => {
  let result = [...recommendHotels]
  
  if (filters.star) {
    result = result.filter(h => h.star === parseInt(filters.star!))
  }
  
  if (filters.price) {
    const [min, max] = filters.price.split('-').map(Number)
    result = result.filter(h => {
      if (max) return h.price >= min && h.price <= max
      return h.price >= min
    })
  }
  
  if (filters.sort === 'price_asc') {
    result.sort((a, b) => a.price - b.price)
  } else if (filters.sort === 'price_desc') {
    result.sort((a, b) => b.price - a.price)
  } else if (filters.sort === 'rating') {
    result.sort((a, b) => b.rating - a.rating)
  }
  
  return result
})

// 搜索酒店
function searchHotels() {
  if (!searchForm.destination) {
    message.warning('请输入目的地')
    return
  }
  currentStep.value = 1
  message.success(`找到${filteredHotels.value.length}家可预订酒店`)
}

// 选择酒店
function selectHotel(hotel: typeof recommendHotels[0]) {
  selectedHotel.value = hotel
  currentStep.value = 2
}

// 选择房型
function selectRoom(room: any) {
  selectedRoom.value = room
}

// 进入下一步
function goToNextStep() {
  if (!selectedRoom.value) {
    message.warning('请选择房型')
    return
  }
  currentStep.value = 3
}

// 提交预订
async function submitBooking() {
  if (!bookingForm.guestName || !bookingForm.phone || !bookingForm.idNumber) {
    message.warning('请填写完整的入住人信息')
    return
  }
  
  submitting.value = true
  try {
    await new Promise(r => setTimeout(r, 1500))
    bookingNo.value = 'ORD' + Date.now().toString().substring(5)
    currentStep.value = 4
    message.success('预订成功！')
  } finally {
    submitting.value = false
  }
}

// 重置所有状态
function resetAll() {
  currentStep.value = 0
  selectedHotel.value = null
  selectedRoom.value = null
  searchForm.destination = ''
  bookingForm.guestName = ''
  bookingForm.phone = ''
  bookingForm.idNumber = ''
  bookingForm.remark = ''
}
</script>

<style scoped>
.guest-booking { max-width: 1200px; margin: 0 auto; padding: 20px; }
.step-content { min-height: 400px; }
.hero-section { text-align: center; padding: 40px 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 12px; color: white; margin-bottom: 24px; }
.hero-section h1 { font-size: 32px; margin: 0 0 12px; }
.hero-section p { font-size: 16px; opacity: 0.9; margin: 0; }
.search-card { background: #f5f7fa; border-radius: 12px; margin-bottom: 24px; }
.filter-bar { margin-bottom: 20px; padding: 16px; background: white; border-radius: 8px; }
.hotel-list { margin-top: 20px; }
.hotel-card { cursor: pointer; transition: transform 0.2s; margin-bottom: 16px; }
.hotel-card:hover { transform: translateY(-4px); box-shadow: 0 8px 24px rgba(0,0,0,0.12); }
.hotel-cover { position: relative; height: 200px; overflow: hidden; }
.hotel-cover img { width: 100%; height: 100%; object-fit: cover; }
.promotion-tag { position: absolute; top: 12px; left: 12px; font-weight: bold; }
.hotel-name { font-size: 16px; font-weight: 600; margin-bottom: 8px; }
.hotel-location { font-size: 13px; color: rgba(0,0,0,0.65); margin-bottom: 6px; }
.hotel-rating { font-size: 13px; color: #faad14; margin-bottom: 8px; }
.hotel-price { text-align: right; margin-top: 12px; }
.price-label { font-size: 14px; color: #ff4d4f; }
.price-value { font-size: 24px; color: #ff4d4f; font-weight: bold; }
.price-unit { font-size: 12px; color: rgba(0,0,0,0.45); }
.room-selection { padding: 10px; }
.hotel-info-card { margin-bottom: 24px; }
.room-card { margin-bottom: 16px; cursor: pointer; border: 2px solid transparent; }
.room-card:hover { border-color: #1890ff; }
.room-card.selected { border-color: #1890ff; background: #e6f7ff; }
.room-image { height: 120px; overflow: hidden; border-radius: 8px; }
.room-image img { width: 100%; height: 100%; object-fit: cover; }
.room-desc { font-size: 13px; color: rgba(0,0,0,0.65); margin: 8px 0; }
.room-meta { font-size: 12px; color: rgba(0,0,0,0.45); margin-bottom: 8px; }
.room-meta span { margin-right: 12px; }
.room-services { margin-top: 8px; }
.room-price-col { text-align: right; display: flex; flex-direction: column; justify-content: center; align-items: center; }
.room-price { margin-bottom: 4px; }
.price-symbol { font-size: 14px; color: #ff4d4f; }
.price-number { font-size: 28px; color: #ff4d4f; font-weight: bold; }
.price-note { font-size: 12px; color: rgba(0,0,0,0.45); margin-bottom: 12px; }
</style>