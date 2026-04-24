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
        <a-steps :current="currentStep - 1" size="small" class="ota-custom-steps">
          <a-step title="选择酒店" />
          <a-step title="房型预订" />
          <a-step title="订单确认" />
          <a-step title="预订成功" />
        </a-steps>
      </div>

      <!-- Step 0: Featured / Recommendations -->
      <div v-if="currentStep === 0" class="recommendations-section">
        <div class="section-header">
          <h2 class="section-title">🏨 合作智能酒店</h2>
        </div>

        <a-row :gutter="[20, 20]">
          <a-col :xs="24" :sm="12" :lg="8" v-for="hotel in recommendHotels" :key="hotel.id">
            <div class="ota-hotel-card" @click="selectHotel(hotel)">
              <div class="card-image-wrapper">
                <img :src="hotel.image || '/hotel-placeholder.jpg'" :alt="hotel.name" />
                <div class="card-badge danger" v-if="hotel.availableRooms === 0">已售罄</div>
                <div class="card-badge" v-else-if="hotel.promotion">{{ hotel.promotion }}</div>
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
        <div class="back-nav-cta" @click="currentStep = 1">
          <LeftOutlined /> 返回列表
        </div>

        <div class="hotel-detail-container" v-if="selectedHotel">
          <!-- Hotel Gallery & Header -->
          <div class="hotel-intro-card">
            <div class="hotel-gallery">
              <div class="main-img">
                <img :src="selectedHotel.image || '/hotel-placeholder.jpg'" />
              </div>
              <div class="side-imgs">
                <div class="side-img-item" v-if="hotelImages[0]" @click="openImageGallery(0)">
                  <img :src="hotelImages[0].image_url" />
                </div>
                <div class="side-img-item" v-else>
                  <img src="https://images.unsplash.com/photo-1566073771259-6a8506099945?q=80&w=400&auto=format&fit=crop" />
                </div>
                <div class="side-img-item" v-if="hotelImages[1]" @click="openImageGallery(1)">
                  <img :src="hotelImages[1].image_url" />
                </div>
                <div class="side-img-item" v-else>
                  <img src="https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?q=80&w=400&auto=format&fit=crop" />
                </div>
                <div class="side-img-item more" @click="openImageGallery(0)">
                  <img :src="hotelImages[2]?.image_url || 'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?q=80&w=400&auto=format&fit=crop'" />
                  <div class="overlay">查看全部图片</div>
                </div>
              </div>
            </div>

            <div class="hotel-header-new">
              <div class="header-left">
                <h1 class="hotel-name-large">{{ selectedHotel.name }}</h1>
                <div class="hotel-tags-row">
                  <a-rate :value="selectedHotel.star" disabled style="font-size: 14px" />
                  <span class="hotel-type-tag">智能酒店</span>
                  <span class="hotel-type-tag">商务首选</span>
                </div>
                <div class="hotel-address-new">
                  <EnvironmentFilled style="color: #008cff" /> {{ selectedHotel.location }}
                </div>
              </div>
              <div class="header-right">
                <div class="score-card-new clickable" @click="openReviewDrawer">
                  <div class="score-main">
                    <span class="num">{{ Number(reviewStats?.avg_score || 0).toFixed(1) || selectedHotel.rating }}</span>
                    <span class="total">/5</span>
                  </div>
                  <div class="score-info">
                    <div class="desc">{{ getRatingDesc(Number(reviewStats?.avg_score || selectedHotel.rating)) }}</div>
                    <div class="count">{{ reviewStats?.total_reviews || selectedHotel.reviewCount || 0 }} 条真实评价</div>
                  </div>
                </div>
                <div class="view-all-reviews" @click="openReviewDrawer">
                  查看全部评价 →
                </div>
              </div>
            </div>
          </div>

          <!-- Room List -->
          <div class="ota-room-list-new" v-if="roomTypes?.length > 0">
            <div class="room-list-header">
              <div class="title">房型选择</div>
              <div class="filter-tips">已包含增值税及服务费</div>
            </div>

            <div class="room-type-card-modern" v-for="type in roomTypes" :key="type.code">
              <div class="room-type-header">
                <div class="room-img-wrapper">
                  <img :src="type.images[0] || '/room-placeholder.jpg'" :alt="type.name" />
                </div>
                <div class="room-type-info">
                  <h3 class="type-name-text">{{ type.name }}</h3>
                  <div class="type-params">
                    <span>{{ type.area }}m²</span>
                    <a-divider type="vertical" />
                    <span>{{ type.bedType }}</span>
                    <a-divider type="vertical" />
                    <span>最多入住{{ type.maxGuests }}人</span>
                  </div>
                  <div class="type-facilities">
                    <span v-for="f in type.facilities.slice(0, 4)" :key="f" class="f-tag">{{ f }}</span>
                  </div>
                </div>
              </div>

              <!-- Rate Plans Table -->
              <div class="rate-plans-container">
                <div class="plan-row header">
                  <div class="plan-info-col">方案名称 / 服务内容</div>
                  <div class="plan-policy-col">政策</div>
                  <div class="plan-price-col">价格 (每晚)</div>
                  <div class="plan-action-col"></div>
                </div>
                <div class="plan-row" v-for="plan in type.plans" :key="plan.id">
                  <div class="plan-info-col">
                    <div class="plan-name">{{ plan.name }}</div>
                    <div class="plan-services">
                      <span :class="{ 'has': plan.hasBreakfast, 'no': !plan.hasBreakfast }">
                        <CoffeeOutlined /> {{ plan.hasBreakfast ? `含早(${plan.breakfastCount || 0}份)` : '不含早' }}
                      </span>
                      <span class="has"><WifiOutlined /> 免费WiFi</span>
                    </div>
                  </div>
                  <div class="plan-policy-col">
                    <div :class="plan.freeCancel ? 'text-success' : 'text-warning'">
                      <CheckOutlined v-if="plan.freeCancel" />
                      <CloseOutlined v-else />
                      {{ plan.freeCancel ? (plan.cancelTimeLimit > 0 ? `入住前${plan.cancelTimeLimit}h免费取消` : '免费取消') : '不可取消' }}
                    </div>
                    <div class="payment-limit">
                      <CreditCardOutlined />
                      {{ plan.paymentType === 'online_only' ? '仅限在线支付' : plan.paymentType === 'front_desk_only' ? '仅限到店支付' : '在线付/到店付' }}
                      <span v-if="plan.prepaymentRatio > 0" class="prepay-tip">(预付{{ plan.prepaymentRatio }}%)</span>
                    </div>
                  </div>
                  <div class="plan-price-col">
                    <div class="price-val">
                      <span class="cur">¥</span>
                      <span class="num">{{ plan.price }}</span>
                    </div>
                    <div class="original-price" v-if="plan.originalPrice > plan.price">¥{{ plan.originalPrice }}</div>
                  </div>
                  <div class="plan-action-col">
                    <a-button 
                      type="primary" 
                      class="plan-book-btn"
                      :disabled="plan.inventory === 0"
                      @click="selectPlan(type, plan)"
                    >
                      {{ plan.inventory === 0 ? '已售罄' : '预订' }}
                    </a-button>
                    <div class="inventory-tip" :class="{ 'danger': plan.inventory <= 2 }">
                      {{ plan.inventory === 0 ? '暂时售罄' : (plan.inventory < 5 ? `仅剩${plan.inventory}间` : '余量充足') }}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
          
          <div v-else class="ota-empty-rooms">
            <a-empty description="该酒店暂无可预订房型" />
            <div style="text-align: center; margin-top: 20px;">
              <a-button @click="currentStep = 0">返回浏览其他酒店</a-button>
            </div>
          </div>
        </div>
      </div>

      <!-- Step 3: Order Confirmation -->
      <div v-if="currentStep === 3" class="order-confirmation-section">
        <div class="ctrip-container">
          <!-- Left Content -->
          <div class="ctrip-main">
            <!-- Order Header -->
            <div class="order-header-ctrip">
              <h2 class="hotel-title-large">{{ selectedHotel?.name }}</h2>
              <div class="hotel-meta-ctrip">
                <a-rate :value="5" disabled style="font-size: 14px" />
                <span class="location-text"><EnvironmentOutlined /> {{ selectedHotel?.location }}</span>
              </div>
            </div>

            <!-- Guest Form Card -->
            <div class="ctrip-card">
              <div class="card-header-ctrip">
                <span class="title">入住人信息</span>
                <a-button type="link" size="small" @click="handleAddGuest">
                  <PlusOutlined /> 添加常用入住人
                </a-button>
              </div>
              
              <!-- Frequent Guests -->
              <div class="frequent-guest-bar">
                <span class="label">常用入住人:</span>
                <div class="guest-chips-container">
                  <div
                    v-for="guest in frequentGuests"
                    :key="guest.id"
                    class="guest-chip-ctrip"
                    :class="{ active: bookingForm.idNumber === guest.id_number }"
                    @click="selectFrequentGuest(guest)"
                  >
                    {{ guest.name }}
                  </div>
                </div>
              </div>

              <a-form :model="bookingForm" layout="vertical" class="ctrip-form">
                <a-row :gutter="20">
                  <a-col :span="12">
                    <a-form-item label="入住人姓名" required>
                      <a-input v-model:value="bookingForm.guestName" placeholder="请填写真实姓名" size="large" />
                    </a-form-item>
                  </a-col>
                  <a-col :span="12">
                    <a-form-item label="手机号" required>
                      <a-input v-model:value="bookingForm.phone" placeholder="用于接收确认短信" size="large" />
                    </a-form-item>
                  </a-col>
                </a-row>
                <a-row :gutter="20">
                  <a-col :span="12">
                    <a-form-item label="证件类型" required>
                      <a-select v-model:value="bookingForm.idType" size="large">
                        <a-select-option value="idcard">中国居民身份证/外国人永久居留身份证/港澳台居民居住证</a-select-option>
                        <a-select-option value="hkm_pass">港澳居民来往内地通行证</a-select-option>
                        <a-select-option value="taiwan_pass">台湾居民来往大陆通行证</a-select-option>
                        <a-select-option value="passport">外国护照</a-select-option>
                        <a-select-option value="other">其他</a-select-option>
                      </a-select>
                    </a-form-item>
                  </a-col>
                  <a-col :span="12">
                    <a-form-item label="证件号码" required :validate-status="bookingIdNumberError ? 'error' : ''" :help="bookingIdNumberError">
                      <a-input
                        v-model:value="bookingForm.idNumber"
                        :placeholder="bookingForm.idType === 'idcard' ? '请输入18位身份证号' : '请输入有效证件号'"
                        :maxlength="bookingForm.idType === 'idcard' ? 18 : undefined"
                        size="large"
                        @change="validateBookingIdNumber"
                      />
                    </a-form-item>
                  </a-col>
                </a-row>
                <a-form-item>
                  <a-checkbox v-model:checked="saveAsFrequent">保存到常用入住人名册</a-checkbox>
                </a-form-item>
              </a-form>
            </div>

            <!-- Payment Method Card -->
            <div class="ctrip-card" style="margin-top: 20px;">
              <div class="card-header-ctrip">
                <span class="title">支付方式</span>
              </div>
              <div class="payment-selector-ctrip">
                <div 
                  class="payment-option-ctrip" 
                  :class="{ active: paymentMethod === 'balance' }"
                  @click="paymentMethod = 'balance'"
                >
                  <div class="icon-box balance"><WalletOutlined /></div>
                  <div class="info">
                    <div class="name">余额支付</div>
                    <div class="desc">余额: ¥{{ memberInfo?.balance || 0 }}</div>
                  </div>
                </div>
                <div 
                  class="payment-option-ctrip" 
                  :class="{ 
                    active: paymentMethod === 'front_desk',
                    disabled: selectedRoom?.paymentType === 'online_only'
                  }"
                  @click="selectedRoom?.paymentType !== 'online_only' && (paymentMethod = 'front_desk')"
                >
                  <div class="icon-box front"><HomeOutlined /></div>
                  <div class="info">
                    <div class="name">到店支付</div>
                    <div class="desc">{{ selectedRoom?.paymentType === 'online_only' ? '该方案不支持' : '前台办理时缴纳' }}</div>
                  </div>
                </div>
                <div 
                  class="payment-option-ctrip" 
                  :class="{ 
                    active: paymentMethod === 'wechat',
                    disabled: selectedRoom?.paymentType === 'front_desk_only'
                  }"
                  @click="selectedRoom?.paymentType !== 'front_desk_only' && (paymentMethod = 'wechat')"
                >
                  <div class="icon-box wechat"><WechatOutlined /></div>
                  <div class="info">
                    <div class="name">微信支付</div>
                    <div class="desc">{{ selectedRoom?.paymentType === 'front_desk_only' ? '该方案不支持' : '微信扫码' }}</div>
                  </div>
                </div>
                <div 
                  class="payment-option-ctrip" 
                  :class="{ 
                    active: paymentMethod === 'alipay',
                    disabled: selectedRoom?.paymentType === 'front_desk_only'
                  }"
                  @click="selectedRoom?.paymentType !== 'front_desk_only' && (paymentMethod = 'alipay')"
                >
                  <div class="icon-box alipay"><AlipayCircleOutlined /></div>
                  <div class="info">
                    <div class="name">支付宝</div>
                    <div class="desc">{{ selectedRoom?.paymentType === 'front_desk_only' ? '该方案不支持' : '手机支付' }}</div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Offer Card -->
            <div class="ctrip-card" style="margin-top: 20px;">
              <div class="card-header-ctrip">
                <span class="title">优惠与抵扣</span>
              </div>
              <div class="offer-section-ctrip">
                <div class="offer-row-ctrip">
                  <span class="label">优惠券</span>
                  <a-select
                    v-model:value="selectedCouponId"
                    placeholder="选择可用优惠券"
                    style="width: 300px"
                    allow-clear
                    @change="handleCouponChange"
                  >
                    <a-select-option v-for="coupon in availableCoupons" :key="coupon.id" :value="coupon.id">
                      {{ coupon.coupon_name }} ({{ coupon.coupon_type === 'discount' ? coupon.discount_value + '折' : '-¥' + coupon.discount_value }})
                    </a-select-option>
                  </a-select>
                </div>
                <div class="offer-row-ctrip">
                  <div class="label-group">
                    <span class="label">积分抵扣</span>
                    <span class="sub-label">可用 {{ memberInfo?.points || 0 }} 积分 ({{ appStore.systemConfigs.points_redeem_rate }}积分=1元)</span>
                  </div>
                  <div class="action-group">
                    <a-checkbox v-model:checked="usePoints" @change="handlePointsToggle">使用积分</a-checkbox>
                    <a-input-number
                      v-if="usePoints"
                      v-model:value="pointsToUse"
                      :min="0"
                      :max="memberInfo?.points || 0"
                      :step="10"
                      style="width: 120px"
                      @change="handlePointsChange"
                    />
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Right Content (Sticky Summary) -->
            <div class="ctrip-side">
              <div class="ctrip-summary-card">
                <div class="summary-header-ctrip">
                  <div class="room-info-box">
                    <img :src="selectedRoom?.image || selectedHotel?.image" class="room-img" />
                    <div class="room-name-box">
                      <div class="name">{{ selectedRoom?.name }}</div>
                      <div class="plan-name-tag">{{ selectedRoom?.plan_name }}</div>
                      <div class="tags">
                        {{ selectedRoom?.hasBreakfast ? `含早(${selectedRoom.breakfastCount}份)` : '不含早' }} | 
                        {{ selectedRoom?.freeCancel ? '免费取消' : '不可取消' }}
                      </div>
                    </div>
                  </div>
                </div>

                <div class="summary-body-ctrip">
                  <div class="date-range-ctrip">
                    <div class="date-item">
                      <div class="lab">入住</div>
                      <div class="val">{{ formatShortDate(dateRange[0]) }}</div>
                    </div>
                    <div class="nights-tag">{{ nights }}晚</div>
                    <div class="date-item text-right">
                      <div class="lab">退房</div>
                      <div class="val">{{ formatShortDate(dateRange[1]) }}</div>
                    </div>
                  </div>

                  <div class="price-breakdown-ctrip">
                    <div class="item">
                      <span>房费总计</span>
                      <span>¥{{ priceBaseTotal }}</span>
                    </div>
                    <!-- 强制显示所有优惠项以便 Debug，包含为 0 的情况 -->
                    <div v-if="priceMemberDiscount > 0" class="item discount">
                      <span>会员优惠 ({{ memberLevelLabel || '未获取' }})</span>
                      <span>-¥{{ priceMemberDiscount }}</span>
                    </div>
                    <div v-if="priceCouponDiscount > 0" class="item discount">
                      <span>优惠券</span>
                      <span>-¥{{ priceCouponDiscount }}</span>
                    </div>
                    <div v-if="pricePointsDiscount > 0" class="item discount">
                      <span>积分抵扣</span>
                      <span>-¥{{ pricePointsDiscount }}</span>
                    </div>
                  </div>

                  <div class="final-total-ctrip">
                    <div class="lab">应付总额</div>
                    <div class="val">
                      <span class="unit">¥</span>
                      <span class="num">{{ finalTotalPrice }}</span>
                    </div>
                  </div>

                  <a-button type="primary" block class="ctrip-confirm-btn" :loading="submitting" @click="handlePreSubmit">
                    {{ paymentMethod === 'front_desk' ? '确认预订' : '立即支付' }}
                  </a-button>

                  <div class="ctrip-safety-tips">
                    <SecurityScanOutlined /> 安全预订 · 房位保障
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

      <!-- Payment Modal (Mock) -->
      <a-modal
        v-model:open="paymentModalVisible"
        title="收银台"
        :footer="null"
        width="400px"
        :closable="false"
      >
        <div class="mock-payment-ctrip">
          <div class="payment-title">支付金额</div>
          <div class="payment-amount">¥{{ finalTotalPrice }}</div>
          
          <div class="payment-vendor">
            <template v-if="paymentMethod === 'wechat'">
              <div class="icon-wrapper wechat-color">
                <WechatOutlined style="font-size: 32px" />
              </div>
              <span>微信支付</span>
            </template>
            <template v-else-if="paymentMethod === 'alipay'">
              <div class="icon-wrapper alipay-color">
                <AlipayCircleOutlined style="font-size: 32px" />
              </div>
              <span>支付宝</span>
            </template>
            <template v-else-if="paymentMethod === 'balance'">
              <div class="icon-wrapper balance-color">
                <WalletOutlined style="font-size: 32px" />
              </div>
              <span>余额支付</span>
            </template>
          </div>

          <div class="payment-qr-mock">
            <div class="qr-placeholder">
              <template v-if="paymentMethod === 'balance'">
                <UnlockOutlined style="font-size: 48px; color: #52c41a" />
                <p>指纹/面容确认中</p>
              </template>
              <template v-else>
                <QrcodeOutlined style="font-size: 48px; color: #1a1a1a" />
                <p>请扫码完成支付</p>
              </template>
            </div>
          </div>

          <a-button type="primary" block size="large" :loading="paymentLoading" @click="confirmMockPayment">
            确认付款
          </a-button>
          <a-button block style="margin-top: 12px" @click="paymentModalVisible = false">
            取消支付
          </a-button>
        </div>
      </a-modal>

      <!-- Success Result -->
      <div v-if="currentStep === 4" class="success-result-section">
        <a-result
          status="success"
          title="预订已成功确认！"
          :sub-title="`预订编号: ${bookingNo}。支付状态: 已支付。我们已向您的手机发送了确认短信。`"
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


    <!-- Review Drawer -->
    <a-drawer
      v-model:open="reviewDrawerVisible"
      title="酒店评价"
      placement="right"
      :width="640"
      :destroyOnClose="true"
    >
      <div v-if="reviewLoading" style="text-align: center; padding: 40px;">
        <a-spin size="large" />
      </div>
      <div v-else class="review-drawer-content">
        <div class="review-stats-header" v-if="reviewStats">
          <div class="stats-score-box">
            <div class="big-score">{{ Number(reviewStats.avg_score || 0).toFixed(1) }}</div>
            <div class="score-label">{{ getRatingDesc(Number(reviewStats.avg_score || 0)) }}</div>
            <div class="review-total">{{ reviewStats.total_reviews }} 条评价</div>
          </div>
          <div class="stats-dimensions">
            <div class="dim-row">
              <span class="dim-label">环境</span>
              <a-progress :percent="(Number(reviewStats.avg_environment || 0) / 5) * 100" :show-info="false" :stroke-color="'#008cff'" size="small" style="flex:1" />
              <span class="dim-val">{{ Number(reviewStats.avg_environment || 0)?.toFixed(1) }}</span>
            </div>
            <div class="dim-row">
              <span class="dim-label">设施</span>
              <a-progress :percent="(Number(reviewStats.avg_facility || 0) / 5) * 100" :show-info="false" :stroke-color="'#008cff'" size="small" style="flex:1" />
              <span class="dim-val">{{ Number(reviewStats.avg_facility || 0)?.toFixed(1) }}</span>
            </div>
            <div class="dim-row">
              <span class="dim-label">舒适</span>
              <a-progress :percent="(Number(reviewStats.avg_comfort || 0) / 5) * 100" :show-info="false" :stroke-color="'#008cff'" size="small" style="flex:1" />
              <span class="dim-val">{{ Number(reviewStats.avg_comfort || 0)?.toFixed(1) }}</span>
            </div>
          </div>
        </div>

        <a-divider />

        <div class="review-list-section">
          <div v-if="reviewList.length === 0" style="text-align: center; padding: 40px; color: #999;">
            暂无评价
          </div>
          <div v-for="review in reviewList" :key="review.id" class="review-item">
            <div class="review-header">
              <div class="reviewer-info">
                <a-avatar
                  :size="32"
                  :src="review.user_avatar ? appStore.resolveImageUrl(review.user_avatar) : undefined"
                  style="background: #008cff"
                >
                  {{ review.member_name?.charAt(0) || '?' }}
                </a-avatar>
                <span class="reviewer-name">{{ review.member_name || '匿名用户' }}</span>
              </div>
              <span class="review-date">{{ formatDate(review.created_at) }}</span>
            </div>
            <div class="review-ratings">
              <span class="rating-tag">环境 {{ review.environment_rating }}⭐</span>
              <span class="rating-tag">设施 {{ review.facility_rating }}⭐</span>
              <span class="rating-tag">舒适 {{ review.comfort_rating }}⭐</span>
            </div>
            <div class="review-content">{{ review.content }}</div>
            <div v-if="review.photos?.length" class="review-photos">
              <img v-for="(photo, i) in review.photos" :key="i" :src="photo" class="review-photo" />
            </div>
            <div v-if="review.reply" class="hotel-reply">
              <div class="reply-label">酒店回复：</div>
              <div class="reply-content">{{ review.reply }}</div>
            </div>
          </div>
        </div>

        <div v-if="reviewList.length < reviewTotal" style="text-align: center; padding: 16px;">
          <a-button @click="loadMoreReviews" :loading="reviewLoading">加载更多</a-button>
        </div>
      </div>
    </a-drawer>

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
            <a-select-option value="idcard">中国居民身份证/外国人永久居留身份证/港澳台居民居住证</a-select-option>
            <a-select-option value="hkm_pass">港澳居民来往内地通行证</a-select-option>
            <a-select-option value="taiwan_pass">台湾居民来往大陆通行证</a-select-option>
            <a-select-option value="passport">外国护照</a-select-option>
            <a-select-option value="other">其他</a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item label="证件号码" required>
          <a-input v-model:value="guestModalForm.id_number" placeholder="请输入证件号" />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 图片画廊 -->
    <a-modal
      v-model:open="imageGalleryVisible"
      :footer="null"
      width="900px"
      :centered="true"
      class="image-gallery-modal"
    >
      <div class="image-gallery-content">
        <div class="main-image-container">
          <img 
            :src="hotelImages[currentImageIndex]?.image_url || selectedHotel?.image" 
            class="main-gallery-image"
          />
          <div class="image-nav prev" v-if="hotelImages.length > 1" @click="currentImageIndex = (currentImageIndex - 1 + hotelImages.length) % hotelImages.length">
            <LeftOutlined />
          </div>
          <div class="image-nav next" v-if="hotelImages.length > 1" @click="currentImageIndex = (currentImageIndex + 1) % hotelImages.length">
            <RightOutlined />
          </div>
        </div>
        <div class="image-counter" v-if="hotelImages.length > 0">
          {{ currentImageIndex + 1 }} / {{ hotelImages.length }}
        </div>
        <div class="thumbnail-list" v-if="hotelImages.length > 1">
          <div 
            v-for="(img, index) in hotelImages" 
            :key="img.id"
            class="thumbnail-item"
            :class="{ active: currentImageIndex === index }"
            @click="currentImageIndex = index"
          >
            <img :src="img.image_url" />
          </div>
        </div>
      </div>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { $notify, NotifyPreset } from '@/utils/notify'
import { Modal } from 'ant-design-vue'
import dayjs, { Dayjs } from 'dayjs'
import { formatShortDate, formatDate } from '@/utils/date'
import guestService, { FrequentGuest } from '@/api/frequent-guest'
import { authService } from '@/api/auth'
import { hotelApi } from '@/api/hotel'
import { paymentApi } from '@/api/payment'
import { systemConfigApi } from '@/api/system-config'
import { getReviews, getReviewStats } from '@/api/review'
import request from '@/api/request'
import { useAppStore } from '@/stores/app'
import {
  EnvironmentOutlined, EnvironmentFilled, StarOutlined, StarFilled,
  UserOutlined, MobileOutlined, CheckOutlined,
  CheckCircleOutlined, LeftOutlined, RightOutlined, WifiOutlined,
  CoffeeOutlined, WalletOutlined, WechatOutlined, AlipayCircleOutlined,
  SecurityScanOutlined, PlusOutlined, DeleteOutlined, EditOutlined, InfoCircleOutlined,
  QrcodeOutlined, UnlockOutlined, HomeOutlined, FullscreenOutlined, ThunderboltOutlined,
  CloseOutlined, CreditCardOutlined
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
const memberInfo = ref<any>(null)
const paymentMethod = ref('balance')
const selectedCouponId = ref<number | null>(null)
const myCoupons = ref<any[]>([])
const usePoints = ref(false)
const pointsToUse = ref(0)
const pointsDiscount = ref(0)

const paymentModalVisible = ref(false)
const paymentLoading = ref(false)
const reviewDrawerVisible = ref(false)
const reviewStats = ref<any>(null)
const reviewList = ref<any[]>([])
const reviewLoading = ref(false)
const reviewPage = ref(1)
const reviewTotal = ref(0)

// 酒店图片画廊
const hotelImages = ref<any[]>([])
const imageGalleryVisible = ref(false)
const currentImageIndex = ref(0)

const handlePreSubmit = () => {
  if (paymentMethod.value === 'balance') {
    const balance = Number(memberInfo.value?.balance || 0)
    if (balance < finalTotalPrice.value) {
      // 余额不足时，不直接报错，而是弹出提示并允许切换支付方式
      return Modal.confirm({
        title: '余额不足',
        content: `当前余额 ¥${balance}，需支付 ¥${finalTotalPrice.value.toFixed(2)}。建议切换到微信或支付宝支付。`,
        okText: '去切换',
        cancelText: '取消',
        onOk: () => {
          // 可以在这里自动切换到微信支付，或者让用户手动在界面选
          paymentMethod.value = 'wechat'
          $notify.info({ title: '已切换支付方式', description: '已为您切换至微信支付，请再次点击提交' })
        }
      })
    }
  }

  if (paymentMethod.value === 'front_desk') {
    submitBooking()
  } else {
    paymentModalVisible.value = true
  }
}

const confirmMockPayment = async () => {
  paymentLoading.value = true
  // 模拟网络延迟
  await new Promise(resolve => setTimeout(resolve, 1500))
  paymentLoading.value = false
  paymentModalVisible.value = false
  submitBooking()
}

const handlePointsToggle = () => {
  if (!usePoints.value) {
    pointsToUse.value = 0
    pointsDiscount.value = 0
  } else {
    // 默认使用最大可用积分（简单处理）
    pointsToUse.value = memberInfo.value?.points || 0
    handlePointsChange()
  }
}

const handlePointsChange = () => {
  if (currentStep.value === 3) {
    updateCalculatedPrice()
  }
}

const handleCouponChange = (val: any) => {
  selectedCouponId.value = val
}
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

const bookingIdNumberError = ref('')

function validateBookingIdNumber() {
  const idNumber = bookingForm.idNumber.trim()
  if (!idNumber) {
    bookingIdNumberError.value = '请输入证件号码'
    return false
  }
  if (bookingForm.idType === 'idcard') {
    if (idNumber.length !== 18) {
      bookingIdNumberError.value = '身份证号应为18位'
      return false
    }
    if (!/^\d{17}[\dXx]$/.test(idNumber)) {
      bookingIdNumberError.value = '身份证号格式不正确'
      return false
    }
  } else if (idNumber.length < 5) {
    bookingIdNumberError.value = '证件号码至少5位'
    return false
  }
  bookingIdNumberError.value = ''
  return true
}

const hotelList = ref<any[]>([])

// --- Computed ---
const nights = computed(() => {
  if (dateRange.value[0] && dateRange.value[1]) {
    return dateRange.value[1].diff(dateRange.value[0], 'day')
  }
  return 1
})

const originalPrice = computed(() => (selectedRoom.value?.price || 0) * nights.value)

const memberLevelInfo = computed(() => {
  if (!memberInfo.value) return null
  // 添加对系统配置的依赖，确保配置更新时重新计算
  const scheme = appStore.systemConfigs.member_scheme

  // 如果后端返回了 level_label，优先使用后端数据
  if (memberInfo.value?.level_label) {
    const levelDiscounts = memberInfo.value?.level_discounts || {}
    const levelMultipliers = memberInfo.value?.level_multipliers || {}
    const discount = levelDiscounts[memberInfo.value.member_level] ?? 1.0
    const multiplier = levelMultipliers[memberInfo.value.member_level] ?? 1

    return {
      label: memberInfo.value.level_label,
      key: memberInfo.value.member_level,
      discount: Number(discount),
      multiplier: Number(multiplier),
      color: appStore.getLevelInfo(memberInfo.value.member_level, memberInfo.value.experience).color,
      nextExp: appStore.getLevelInfo(memberInfo.value.member_level, memberInfo.value.experience).nextExp,
      percent: appStore.getLevelInfo(memberInfo.value.member_level, memberInfo.value.experience).percent,
      level: memberInfo.value?.level || 1
    }
  }

  // 否则使用前端计算
  return appStore.getLevelInfo(memberInfo.value?.member_level, memberInfo.value?.experience)
})

const memberDiscount = computed(() => {
  return memberLevelInfo.value?.discount || 1.0
})

const memberLevelLabel = computed(() => {
  return memberLevelInfo.value?.label || ''
})

const availableCoupons = computed(() => {
  if (!myCoupons.value) return []
  // 只显示满足最低消费金额的优惠券
  return myCoupons.value.filter(c => {
    const priceAfterMemberDiscount = Math.floor(originalPrice.value * memberDiscount.value * 100) / 100
    return priceAfterMemberDiscount >= (c.min_amount || 0)
  })
})

const selectedCoupon = computed(() => {
  return availableCoupons.value.find(c => c.id === selectedCouponId.value)
})

const couponDiscountAmount = computed(() => {
  if (!selectedCoupon.value) return 0
  const priceAfterMemberDiscount = Math.floor(originalPrice.value * memberDiscount.value * 100) / 100
  if (selectedCoupon.value.coupon_type === 'discount') {
    // discount_value 为 8.5 表示 8.5 折，即价格乘以 0.85
    const multiplier = Number(selectedCoupon.value.discount_value) / 10
    return Math.floor(priceAfterMemberDiscount * (1 - multiplier) * 100) / 100
  } else {
    return Math.min(priceAfterMemberDiscount, selectedCoupon.value.discount_value)
  }
})

const fetchMemberInfo = async () => {
  if (!appStore.userInfo) return
  try {
    const res = await request.get('/members/me')
    memberInfo.value = res.data
  } catch (error) {
    console.error('获取会员信息失败:', error)
  }
}

const fetchAvailableCoupons = async () => {
  if (!appStore.userInfo) return
  try {
    const res = await request.get('/coupons/me', { 
      params: { hotel_id: selectedHotel.value?.id } 
    })
    myCoupons.value = res.data || []
  } catch (error) {
    console.error('获取优惠券失败:', error)
  }
}

const finalTotalPrice = ref(0)
const memberDiscountRate = ref(1)
const priceMemberDiscount = ref(0)
const priceCouponDiscount = ref(0)
const pricePointsDiscount = ref(0)

const priceBaseTotal = ref(0)

// 当选中的房型或日期变化时，重置所有价格
watch([selectedRoom, nights], () => {
  if (selectedRoom.value) {
    const base = (selectedRoom.value.price || 0) * (nights.value || 1)
    priceBaseTotal.value = base
    finalTotalPrice.value = base
  }
}, { immediate: true })

const updateCalculatedPrice = async () => {
  const roomTypeId = selectedRoom.value?.room_type_id
  if (!roomTypeId || !dateRange.value || dateRange.value.length < 2) {
    console.warn('Skipping price calculation: Missing roomTypeId or dates', { roomTypeId, dateRange: dateRange.value })
    return
  }

  try {
    const res = await request.get('/bookings/calculate-price', {
      params: {
        room_type_id: roomTypeId,
        rate_plan_id: selectedRoom.value.rate_plan_id,
        check_in_date: dateRange.value[0].format('YYYY-MM-DD'),
        check_out_date: dateRange.value[1].format('YYYY-MM-DD'),
        guest_phone: memberInfo.value?.phone || appStore.userInfo?.phone || appStore.userInfo?.username || bookingForm.phone || undefined,
        coupon_id: selectedCouponId.value || undefined,
        used_points: usePoints.value ? pointsToUse.value : 0
      }
    })
    
    const data = res.data
    finalTotalPrice.value = data.total_price
    memberDiscountRate.value = data.discount_rate
    priceBaseTotal.value = data.base_price || priceBaseTotal.value
    priceMemberDiscount.value = data.member_discount || 0
    priceCouponDiscount.value = data.coupon_discount || 0
    pricePointsDiscount.value = data.points_discount || 0
    pointsDiscount.value = data.points_discount || 0
    
    // 如果返回了实际使用的积分且用户勾选了使用积分，同步到输入框
    if (usePoints.value && data.used_points !== undefined) {
      pointsToUse.value = data.used_points
    }
  } catch (error) {
    console.error('价格计算失败:', error)
  }
}

watch([selectedRoom, dateRange, selectedCouponId, usePoints, pointsToUse], () => {
  if (currentStep.value === 3) {
    updateCalculatedPrice()
  }
})
const discountAmount = computed(() => {
  const val = Number(originalPrice.value) - Number(finalTotalPrice.value)
  return isNaN(val) ? 0 : Math.floor(val * 100) / 100
})

const recommendHotels = computed(() => hotelList.value)

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
  if (!dateRange.value?.[0] || !dateRange.value?.[1]) return $notify.warning({ title: '请选择日期', description: '请选择入住和退房日期' })
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
    NotifyPreset.operationFailed('酒店搜索失败，请稍后重试')
  }
}

const roomTypes = ref<any[]>([])

const selectHotel = async (hotel: any) => {
  try {
    const res = await hotelApi.getRoomAvailability(
      Number(hotel.id),
      dateRange.value[0].format('YYYY-MM-DD'),
      dateRange.value[1].format('YYYY-MM-DD')
    )
    selectedHotel.value = hotel
    roomTypes.value = res.roomTypes || []
    currentStep.value = 2
    fetchReviewStats()
    fetchHotelImages()
  } catch (error) {
    NotifyPreset.operationFailed('加载房态失败，请稍后重试')
  }
}

// 获取酒店图片列表
const fetchHotelImages = async () => {
  if (!selectedHotel.value) return
  try {
    const images = await hotelApi.getHotelImages(Number(selectedHotel.value.id))
    hotelImages.value = images || []
  } catch (error) {
    console.error('获取酒店图片失败:', error)
    hotelImages.value = []
  }
}

// 打开图片画廊
const openImageGallery = (index: number = 0) => {
  if (hotelImages.value.length === 0) {
    $notify.info({ title: '提示', description: '暂无更多图片' })
    return
  }
  currentImageIndex.value = index
  imageGalleryVisible.value = true
}

const selectPlan = async (type: any, plan: any) => {
  if (!appStore.userInfo) {
    $notify.info({ title: '请先登录', description: '请先登录后再进行预订' })
    appStore.showLoginModal = true
    return
  }
  
  if (!memberInfo.value) {
    await fetchMemberInfo()
  }

  if (!myCoupons.value || myCoupons.value.length === 0) {
    await fetchAvailableCoupons()
  }

  selectedRoom.value = {
    ...type,
    room_type_id: type.id || type.room_type_id,
    hotel_id: type.hotel_id,
    price: plan.price,
    rate_plan_id: plan.id,
    plan_name: plan.name,
    mealPlan: plan.mealPlan,
    breakfastCount: plan.breakfastCount,
    cancelPolicy: plan.cancelPolicy,
    cancelTimeLimit: plan.cancelTimeLimit,
    paymentType: plan.paymentType,
    hasBreakfast: plan.hasBreakfast,
    freeCancel: plan.freeCancel,
    prepaymentRatio: plan.prepaymentRatio
  }
  currentStep.value = 3
  updateCalculatedPrice()
  fetchFrequentGuests()
}

const fetchFrequentGuests = async () => {
  try {
    const res = await guestService.list()
    if (res && res.data && res.data.guests) {
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
  NotifyPreset.roomSelected(guest.name)
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
    await guestService.remove(id)
    NotifyPreset.profileUpdated('常客信息')
    fetchFrequentGuests()
  } catch (error) {
    NotifyPreset.operationFailed('删除常客信息失败')
  }
}

const saveGuest = async () => {
  if (!guestModalForm.name || !guestModalForm.phone || !guestModalForm.id_number) {
    return $notify.warning({ title: '信息不完整', description: '请填写完整信息' })
  }
  if (guestModalForm.id_type === 'idcard') {
    const idNumber = guestModalForm.id_number.trim()
    if (idNumber.length !== 18 || !/^\d{17}[\dXx]$/.test(idNumber)) {
      return $notify.warning({ title: '证件格式错误', description: '请填写正确的18位身份证号码' })
    }
  } else if (guestModalForm.id_number.trim().length < 5) {
    return $notify.warning({ title: '证件格式错误', description: '证件号码至少5位' })
  }
  try {
    if (editingGuestId.value) {
      await guestService.update(editingGuestId.value, guestModalForm)
    } else {
      await guestService.create(guestModalForm)
    }
    NotifyPreset.profileUpdated(editingGuestId.value ? '常客信息' : '常客信息')
    showGuestModal.value = false
    fetchFrequentGuests()
  } catch (error) {
    NotifyPreset.operationFailed('保存常客信息失败')
  }
}

const submitBooking = async () => {
  if (!bookingForm.guestName) {
    return $notify.warning({ title: '信息不完整', description: '请填写入住人姓名' })
  }
  if (!bookingForm.phone || bookingForm.phone.length < 11) {
    return $notify.warning({ title: '格式错误', description: '请填写正确的手机号码' })
  }
  if (!bookingForm.idNumber || bookingForm.idNumber.length < 15) {
    return $notify.warning({ title: '证件格式错误', description: '请填写正确的身份证号码' })
  }
  if (bookingForm.idType === 'idcard') {
    if (bookingForm.idNumber.length !== 18 || !/^\d{17}[\dXx]$/.test(bookingForm.idNumber)) {
      return $notify.warning({ title: '证件格式错误', description: '请填写正确的18位身份证号码' })
    }
  } else if (bookingForm.idNumber.length < 5) {
    return $notify.warning({ title: '证件格式错误', description: '证件号码至少5位' })
  }

  const payload = {
    room_type_id: selectedRoom.value?.room_type_id,
    rate_plan_id: selectedRoom.value?.rate_plan_id,
    check_in_date: dateRange.value[0].format('YYYY-MM-DD'),
    check_out_date: dateRange.value[1].format('YYYY-MM-DD'),
    guest_name: bookingForm.guestName,
    guest_phone: bookingForm.phone,
    guest_id_number: bookingForm.idNumber,
    guest_count: searchForm.guests,
    special_requests: bookingForm.remark,
    payment_method: paymentMethod.value,
    coupon_id: selectedCouponId.value || undefined,
    used_points: usePoints.value ? pointsToUse.value : 0,
    status: 'pending'
  }

  console.log('提交预订数据:', payload)
  submitting.value = true
  try {
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

    // 1. 创建预订（后端会悲观锁锁定房间，15分钟内需完成支付）
    const booking = await hotelApi.createBooking(payload)
    const bookingId = booking?.id
    bookingNo.value = booking?.booking_number || booking?.booking_no || ('BK' + Date.now().toString().slice(-8))
    const paymentDeadline = booking?.payment_deadline

    // 2. 如果是在线支付（非到店支付），创建支付记录并确认支付
    if (paymentMethod.value !== 'front_desk' && bookingId) {
      console.log('创建支付记录...')
      const payment = await paymentApi.createPayment({
        order_type: 'booking',
        order_id: bookingId,
        amount: finalTotalPrice.value,
        payment_method: paymentMethod.value,
        description: `预订支付 - ${bookingNo.value}`
      })
      console.log('支付记录创建成功:', payment)

      if (payment?.id) {
        console.log('确认支付...')
        await paymentApi.payPayment(payment.id)
        console.log('支付确认成功')
      }
    }

    currentStep.value = 4
    if (paymentDeadline && paymentMethod.value === 'front_desk') {
      NotifyPreset.bookingSuccess(true)
    } else {
      NotifyPreset.bookingSuccess(false)
    }
  } catch (error: any) {
    console.error('预订或支付失败:', error)
    if (error?.response?.status === 409) {
      NotifyPreset.bookingFailed('该房间已被其他顾客预订，请选择其他房间')
    } else {
      NotifyPreset.bookingFailed(error?.response?.data?.message || error?.message)
    }
  } finally {
    submitting.value = false
  }
}


const getRatingDesc = (score: number) => {
  if (!score) return '暂无评分'
  if (score >= 4.5) return '超赞'
  if (score >= 4.0) return '很好'
  if (score >= 3.5) return '不错'
  if (score >= 3.0) return '一般'
  return '较差'
}

const openReviewDrawer = () => {
  if (!selectedHotel.value) return
  reviewDrawerVisible.value = true
  fetchReviewStats()
  fetchReviewList()
}

const fetchReviewStats = async () => {
  if (!selectedHotel.value) return
  try {
    const res = await getReviewStats(Number(selectedHotel.value.id))
    reviewStats.value = res.data
  } catch (error) {
    console.error('获取评价统计失败:', error)
  }
}

const fetchReviewList = async () => {
  if (!selectedHotel.value) return
  try {
    reviewLoading.value = true
    const res = await getReviews({
      hotel_id: Number(selectedHotel.value.id),
      page: reviewPage.value,
      pageSize: 10
    })
    if (reviewPage.value === 1) {
      reviewList.value = res.data?.list || []
    } else {
      reviewList.value = [...reviewList.value, ...(res.data?.list || [])]
    }
    reviewTotal.value = res.data?.total || 0
  } catch (error) {
    console.error('获取评价列表失败:', error)
  } finally {
    reviewLoading.value = false
  }
}

const loadMoreReviews = () => {
  reviewPage.value++
  fetchReviewList()
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
  if (appStore.userInfo) {
    fetchMemberInfo()
    fetchAvailableCoupons()
    fetchFrequentGuests()
  }
})

watch(() => appStore.userInfo, (newVal) => {
  if (newVal) {
    fetchMemberInfo()
    fetchAvailableCoupons()
    fetchFrequentGuests()
  }
})
</script>

<style scoped>
/* ==================== 炫酷酒店预订页面样式 ==================== */
.ota-booking-container {
  min-height: 100vh;
  background: linear-gradient(135deg, var(--hotel-bg) 0%, #f0f4f8 100%);
  font-family: var(--hotel-font);
  overflow-x: hidden;
}

/* ==================== Hero Section - 炫酷渐变背景 ==================== */
.hero-bg {
  position: relative;
  height: 480px;
  background-image: url('https://images.unsplash.com/photo-1571896349842-33c89424de2d?q=80&w=2000&auto=format&fit=crop');
  background-size: cover;
  background-position: center;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.hero-bg::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: linear-gradient(135deg, rgba(26, 43, 74, 0.7) 0%, rgba(45, 74, 111, 0.6) 50%, rgba(201, 169, 98, 0.3) 100%);
  z-index: 1;
}

.hero-bg::after {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: radial-gradient(ellipse at center, transparent 0%, rgba(15, 26, 46, 0.4) 100%);
  z-index: 2;
}

.hero-overlay {
  display: none;
}

.hero-content {
  position: relative;
  text-align: center;
  color: white;
  z-index: 3;
  animation: heroFadeIn 1s ease-out;
}

@keyframes heroFadeIn {
  from {
    opacity: 0;
    transform: translateY(30px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.hero-content h1 {
  font-size: 52px;
  font-weight: 800;
  color: white;
  text-shadow: 0 4px 20px rgba(0, 0, 0, 0.4);
  margin-bottom: 16px;
  letter-spacing: 2px;
  background: linear-gradient(135deg, #fff 0%, #f9e29c 50%, #fff 100%);
  background-clip: text;
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  animation: textShine 3s ease-in-out infinite;
}

@keyframes textShine {
  0%, 100% { background-position: 0% 50%; }
  50% { background-position: 100% 50%; }
}

.hero-content p {
  font-size: 22px;
  opacity: 0.95;
  text-shadow: 0 2px 10px rgba(0, 0, 0, 0.3);
  animation: fadeInUp 0.8s ease-out 0.3s both;
}

@keyframes fadeInUp {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.ota-highlight {
  color: var(--hotel-gold);
  font-weight: 800;
  font-size: 28px;
  text-shadow: 0 0 20px rgba(201, 169, 98, 0.5);
  animation: goldPulse 2s ease-in-out infinite;
}

@keyframes goldPulse {
  0%, 100% { text-shadow: 0 0 20px rgba(201, 169, 98, 0.5); }
  50% { text-shadow: 0 0 40px rgba(201, 169, 98, 0.8); }
}

/* ==================== Floating Search Bar - 玻璃态效果 ==================== */
.floating-search-wrapper {
  max-width: 1200px;
  margin: -80px auto 0;
  padding: 0 24px;
  position: relative;
  z-index: 10;
}

.ota-search-card {
  border-radius: var(--hotel-radius-xl);
  box-shadow: 
    0 20px 60px rgba(26, 43, 74, 0.15),
    0 0 0 1px rgba(255, 255, 255, 0.5) inset;
  padding: 16px;
  background: rgba(255, 255, 255, 0.85);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.3);
  transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
  animation: cardSlideUp 0.6s ease-out 0.5s both;
}

@keyframes cardSlideUp {
  from {
    opacity: 0;
    transform: translateY(40px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.ota-search-card:hover {
  box-shadow: 
    0 25px 70px rgba(26, 43, 74, 0.2),
    0 0 0 1px rgba(255, 255, 255, 0.6) inset;
  transform: translateY(-4px);
}

.search-item {
  padding: 10px 24px;
  min-width: 0;
  overflow: hidden;
}

.search-label {
  display: block;
  font-size: 13px;
  color: var(--hotel-text-secondary);
  margin-bottom: 8px;
  font-weight: 600;
  letter-spacing: 0.5px;
}

.divider-left {
  border-left: 1px solid rgba(201, 169, 98, 0.2);
}

.ota-input :deep(.ant-input) {
  font-size: 17px;
  font-weight: 600;
  color: var(--hotel-primary);
  transition: all 0.3s;
}

.ota-input :deep(.ant-input:focus) {
  color: var(--hotel-gold);
}

.ota-range-picker :deep(.ant-picker-input > input) {
  font-size: 17px;
  font-weight: 600;
  color: var(--hotel-primary);
}

.ota-guest-selector {
  font-size: 17px;
  font-weight: 600;
  cursor: pointer;
  padding: 4px 0;
  display: flex;
  align-items: center;
  color: var(--hotel-primary);
  transition: color 0.3s;
}

.ota-guest-selector:hover {
  color: var(--hotel-gold);
}

.guest-popover {
  position: absolute;
  top: 100%;
  left: 0;
  width: 240px;
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  box-shadow: 0 12px 40px rgba(26, 43, 74, 0.15);
  border-radius: var(--hotel-radius-lg);
  padding: 20px;
  margin-top: 12px;
  z-index: 100;
  border: 1px solid rgba(201, 169, 98, 0.15);
  animation: popoverFadeIn 0.3s ease-out;
}

@keyframes popoverFadeIn {
  from {
    opacity: 0;
    transform: translateY(-10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.popover-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
  padding: 8px 0;
}

.popover-item:last-child {
  margin-bottom: 0;
}

.ota-search-btn {
  height: 64px;
  font-size: 20px;
  font-weight: 700;
  border-radius: var(--hotel-radius-lg);
  background: linear-gradient(135deg, var(--hotel-gold-dark) 0%, var(--hotel-gold) 50%, var(--hotel-gold-light) 100%);
  background-size: 200% 200%;
  box-shadow: 
    0 8px 25px rgba(201, 169, 98, 0.4),
    0 0 0 2px rgba(255, 255, 255, 0.2) inset;
  border: none;
  transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
  position: relative;
  overflow: hidden;
}

.ota-search-btn::before {
  content: '';
  position: absolute;
  top: 0;
  left: -100%;
  width: 100%;
  height: 100%;
  background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.3), transparent);
  transition: left 0.5s;
}

.ota-search-btn:hover::before {
  left: 100%;
}

.ota-search-btn:hover {
  transform: translateY(-3px);
  box-shadow: 
    0 12px 35px rgba(201, 169, 98, 0.5),
    0 0 0 2px rgba(255, 255, 255, 0.3) inset;
  background-position: 100% 50%;
}

/* ==================== Content Wrapper ==================== */
.ota-content-wrapper {
  max-width: 1300px;
  margin: 50px auto;
  padding: 0 32px;
}

.with-padding {
  padding-top: 24px;
}

/* ==================== Steps Nav - 炫酷进度条 ==================== */
.ota-steps-nav {
  background: rgba(255, 255, 255, 0.9);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  padding: 28px 48px;
  border-radius: var(--hotel-radius-xl);
  margin-bottom: 36px;
  box-shadow: 
    0 8px 32px rgba(26, 43, 74, 0.08),
    0 0 0 1px rgba(201, 169, 98, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.5);
  animation: fadeInUp 0.6s ease-out 0.7s both;
}

.ota-custom-steps :deep(.ant-steps-item-title) {
  font-weight: 700 !important;
  font-size: 15px !important;
  color: var(--hotel-text-secondary) !important;
}

.ota-custom-steps :deep(.ant-steps-item-process .ant-steps-item-title) {
  color: var(--hotel-primary) !important;
}

.ota-custom-steps :deep(.ant-steps-item-process .ant-steps-item-icon) {
  background: linear-gradient(135deg, var(--hotel-gold-dark) 0%, var(--hotel-gold) 100%);
  border-color: var(--hotel-gold);
  box-shadow: 0 4px 15px rgba(201, 169, 98, 0.4);
}

.ota-custom-steps :deep(.ant-steps-item-finish .ant-steps-item-icon) {
  background: linear-gradient(135deg, var(--hotel-primary) 0%, var(--hotel-primary-light) 100%);
  border-color: var(--hotel-primary);
}

.ota-custom-steps :deep(.ant-steps-item-finish .ant-steps-item-icon .ant-steps-icon) {
  color: #fff;
}

/* ==================== Section Header ==================== */
.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 28px;
}

.section-title {
  font-size: 26px;
  font-weight: 800;
  color: var(--hotel-primary);
  margin: 0;
  position: relative;
  padding-left: 16px;
}

.section-title::before {
  content: '';
  position: absolute;
  left: 0;
  top: 50%;
  transform: translateY(-50%);
  width: 4px;
  height: 28px;
  background: linear-gradient(180deg, var(--hotel-gold) 0%, var(--hotel-gold-dark) 100%);
  border-radius: 2px;
}

/* ==================== OTA Hotel Card - 炫酷卡片效果 ==================== */
.ota-hotel-card {
  background: rgba(255, 255, 255, 0.95);
  border-radius: var(--hotel-radius-xl);
  overflow: hidden;
  box-shadow: 
    0 4px 20px rgba(26, 43, 74, 0.08),
    0 0 0 1px rgba(201, 169, 98, 0.1);
  transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
  cursor: pointer;
  height: 100%;
  position: relative;
}

.ota-hotel-card::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 3px;
  background: linear-gradient(90deg, var(--hotel-gold), var(--hotel-gold-light), var(--hotel-gold));
  opacity: 0;
  transition: opacity 0.3s;
}

.ota-hotel-card:hover {
  transform: translateY(-8px);
  box-shadow: 
    0 20px 50px rgba(26, 43, 74, 0.15),
    0 0 0 1px rgba(201, 169, 98, 0.3);
}

.ota-hotel-card:hover::before {
  opacity: 1;
}

.card-image-wrapper {
  position: relative;
  height: 220px;
  overflow: hidden;
}

.card-image-wrapper img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.6s cubic-bezier(0.4, 0, 0.2, 1);
}

.ota-hotel-card:hover .card-image-wrapper img {
  transform: scale(1.1);
}

.card-badge {
  position: absolute;
  top: 16px;
  left: 16px;
  background: linear-gradient(135deg, #ff6b6b 0%, #ee5a5a 100%);
  color: white;
  padding: 6px 14px;
  border-radius: 20px;
  font-weight: 700;
  font-size: 12px;
  z-index: 2;
  box-shadow: 0 4px 12px rgba(238, 90, 90, 0.4);
  animation: badgePulse 2s ease-in-out infinite;
}

@keyframes badgePulse {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.05); }
}

.card-badge.danger {
  background: linear-gradient(135deg, #8c8c8c 0%, #6b6b6b 100%);
  box-shadow: 0 4px 12px rgba(107, 107, 107, 0.3);
  animation: none;
}

.card-wishlist {
  position: absolute;
  top: 16px;
  right: 16px;
  width: 36px;
  height: 36px;
  background: rgba(255, 255, 255, 0.9);
  backdrop-filter: blur(8px);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #8c8c8c;
  transition: all 0.3s;
  z-index: 2;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.card-wishlist:hover {
  color: #ff4d4f;
  transform: scale(1.1);
  background: #fff;
}

.card-body {
  padding: 20px;
}

.hotel-title {
  font-size: 18px;
  font-weight: 700;
  margin-bottom: 6px;
  color: var(--hotel-primary);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.hotel-stars {
  color: var(--hotel-gold);
  font-size: 13px;
}

.hotel-info-row {
  margin: 10px 0;
  font-size: 13px;
  color: var(--hotel-text-secondary);
  display: flex;
  align-items: center;
  gap: 4px;
}

.hotel-rating-row {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 14px;
}

.rating-badge {
  background: linear-gradient(135deg, var(--hotel-primary) 0%, var(--hotel-primary-light) 100%);
  color: white;
  padding: 4px 10px;
  border-radius: 6px;
  font-weight: 700;
  font-size: 14px;
  box-shadow: 0 2px 8px rgba(26, 43, 74, 0.2);
}

.rating-text {
  font-size: 13px;
  color: var(--hotel-primary);
  font-weight: 600;
}

.hotel-tags {
  display: flex;
  gap: 8px;
  margin-bottom: 16px;
  flex-wrap: wrap;
}

.ota-tag {
  font-size: 11px;
  padding: 3px 10px;
  border-radius: 12px;
  font-weight: 500;
}

.ota-tag.success { 
  background: rgba(82, 196, 26, 0.1); 
  color: #52c41a; 
  border: 1px solid rgba(82, 196, 26, 0.3); 
}
.ota-tag.info { 
  background: rgba(24, 144, 255, 0.1); 
  color: #1890ff; 
  border: 1px solid rgba(24, 144, 255, 0.3); 
}

.price-box {
  text-align: right;
}

.currency { 
  font-size: 14px; 
  color: #ff6b6b; 
  font-weight: 700; 
  margin-right: 2px; 
}
.amount { 
  font-size: 28px; 
  color: #ff6b6b; 
  font-weight: 800; 
}
.unit { 
  font-size: 12px; 
  color: var(--hotel-text-muted); 
}

/* ==================== Vertical List Item ==================== */
.ota-list-item {
  background: rgba(255, 255, 255, 0.95);
  border-radius: var(--hotel-radius-xl);
  padding: 20px;
  margin-bottom: 24px;
  cursor: pointer;
  transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
  border: 1px solid transparent;
  box-shadow: 0 4px 20px rgba(26, 43, 74, 0.06);
}

.ota-list-item:hover {
  border-color: var(--hotel-gold);
  box-shadow: 
    0 12px 40px rgba(26, 43, 74, 0.12),
    0 0 0 1px var(--hotel-gold);
  transform: translateY(-4px);
}

.item-image {
  height: 200px;
  border-radius: var(--hotel-radius-lg);
  overflow: hidden;
}

.item-image img { 
  width: 100%; 
  height: 100%; 
  object-fit: cover;
  transition: transform 0.6s;
}

.ota-list-item:hover .item-image img {
  transform: scale(1.05);
}

.item-title { 
  font-size: 22px; 
  font-weight: 800; 
  margin-bottom: 6px; 
  color: var(--hotel-primary);
}
.item-stars { 
  color: var(--hotel-gold); 
  margin-bottom: 10px; 
  display: flex; 
  align-items: center; 
  gap: 10px; 
}
.star-label { 
  color: var(--hotel-text-muted); 
  font-size: 12px; 
}
.item-location { 
  font-size: 14px; 
  color: var(--hotel-text-secondary); 
  margin-bottom: 14px; 
}

.item-features { 
  display: flex; 
  gap: 10px; 
  margin-bottom: 14px; 
  flex-wrap: wrap;
}
.feature-tag { 
  font-size: 12px; 
  color: var(--hotel-text-secondary); 
  background: rgba(26, 43, 74, 0.05); 
  padding: 4px 12px; 
  border-radius: 12px; 
}

.item-benefit { 
  color: #52c41a; 
  font-weight: 600; 
  font-size: 13px; 
}

.item-rating-box { 
  display: flex; 
  justify-content: flex-end; 
  align-items: center; 
  gap: 14px; 
}
.rating-info { 
  text-align: right; 
}
.rating-desc { 
  display: block; 
  font-weight: 700; 
  color: var(--hotel-primary); 
}
.rating-count { 
  font-size: 12px; 
  color: var(--hotel-text-muted); 
}
.rating-score { 
  background: linear-gradient(135deg, var(--hotel-primary) 0%, var(--hotel-primary-light) 100%); 
  color: white; 
  width: 40px; 
  height: 40px; 
  border-radius: 8px 8px 8px 0; 
  display: flex; 
  align-items: center; 
  justify-content: center; 
  font-weight: 700; 
  font-size: 17px;
  box-shadow: 0 4px 12px rgba(26, 43, 74, 0.2);
}

.item-price-action { 
  display: flex; 
  flex-direction: column; 
  height: 200px; 
  min-width: 0;
}
.spacer { flex: 1; }
.ota-action-btn { 
  border-radius: var(--hotel-radius); 
  height: 44px; 
  font-weight: 700;
  transition: all 0.3s;
}
.ota-action-btn:hover {
  transform: translateY(-2px);
}

/* ==================== Room Selection Styles ==================== */
.room-selection-section {
  max-width: 100%;
  margin: 0 auto;
}

.back-nav-cta {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  color: var(--hotel-primary);
  font-weight: 600;
  cursor: pointer;
  margin-bottom: 20px;
  transition: all 0.3s;
  padding: 8px 16px;
  border-radius: var(--hotel-radius);
  background: rgba(26, 43, 74, 0.05);
}

.back-nav-cta:hover { 
  color: var(--hotel-gold);
  background: rgba(201, 169, 98, 0.1);
}

.hotel-intro-card {
  background: rgba(255, 255, 255, 0.95);
  border-radius: var(--hotel-radius-xl);
  overflow: hidden;
  box-shadow: 
    0 8px 32px rgba(26, 43, 74, 0.1),
    0 0 0 1px rgba(201, 169, 98, 0.1);
  margin-bottom: 28px;
  position: relative;
}

.hotel-gallery {
  display: flex;
  height: 400px;
  gap: 4px;
}

.hotel-gallery img { width: 100%; height: 100%; object-fit: cover; }

.main-img { flex: 2; }
.side-imgs { flex: 1; display: flex; flex-direction: column; gap: 4px; }
.side-img-item { flex: 1; min-height: 0; overflow: hidden; }
.side-img-item.more { position: relative; }
.side-img-item.more .overlay {
  position: absolute;
  top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(26, 43, 74, 0.6);
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 14px;
  backdrop-filter: blur(4px);
}

.hotel-header-new {
  padding: 28px;
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
}

.hotel-name-large { 
  font-size: 34px; 
  font-weight: 800; 
  margin-bottom: 10px; 
  color: var(--hotel-primary); 
}
.hotel-tags-row { 
  display: flex; 
  align-items: center; 
  gap: 14px; 
  margin-bottom: 14px; 
}
.hotel-type-tag { 
  font-size: 12px; 
  color: var(--hotel-text-secondary); 
  background: rgba(26, 43, 74, 0.05); 
  padding: 4px 12px; 
  border-radius: 12px; 
}

.hotel-address-new { 
  font-size: 14px; 
  color: var(--hotel-text-secondary); 
}

.score-card-new {
  background: rgba(255, 255, 255, 0.98);
  backdrop-filter: blur(16px);
  padding: 16px 24px;
  border-radius: var(--hotel-radius-lg);
  display: flex;
  align-items: center;
  gap: 16px;
  border: 1px solid rgba(201, 169, 98, 0.2);
  box-shadow: 
    0 8px 24px rgba(26, 43, 74, 0.12),
    0 0 0 1px rgba(255, 255, 255, 0.5);
  margin-top: -70px;
  position: relative;
  z-index: 5;
}

.score-main { 
  text-align: center; 
  border-right: 1px solid rgba(201, 169, 98, 0.2); 
  padding-right: 20px; 
}
.score-main .num { 
  font-size: 36px; 
  font-weight: 900; 
  color: var(--hotel-gold); 
  line-height: 1; 
}
.score-main .total { 
  font-size: 14px; 
  color: var(--hotel-text-muted); 
}

.score-info .desc { 
  font-weight: 800; 
  color: var(--hotel-gold); 
  font-size: 17px; 
  margin-bottom: 6px; 
}
.score-info .count { 
  font-size: 12px; 
  color: var(--hotel-text-muted); 
}

/* ==================== Room List Styles ==================== */
.room-list-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  margin-bottom: 20px;
  padding: 0 4px;
}

.room-list-header .title { 
  font-size: 24px; 
  font-weight: 800; 
  color: var(--hotel-primary); 
}
.room-list-header .filter-tips { 
  font-size: 13px; 
  color: var(--hotel-text-muted); 
}

.room-card-modern {
  background: rgba(255, 255, 255, 0.95);
  border-radius: var(--hotel-radius-xl);
  margin-bottom: 24px;
  box-shadow: 
    0 4px 20px rgba(26, 43, 74, 0.06),
    0 0 0 1px rgba(201, 169, 98, 0.1);
  transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
  border: 1px solid transparent;
  overflow: hidden;
}

.room-card-modern:hover {
  box-shadow: 
    0 12px 40px rgba(26, 43, 74, 0.12),
    0 0 0 1px var(--hotel-gold);
  border-color: var(--hotel-gold);
}

.room-card-content {
  display: flex;
  height: 220px;
}

.room-img-wrapper {
  width: 280px;
  position: relative;
  overflow: hidden;
}

.room-img-wrapper img { 
  width: 100%; 
  height: 100%; 
  object-fit: cover; 
  transition: transform 0.6s cubic-bezier(0.4, 0, 0.2, 1); 
}
.room-card-modern:hover .room-img-wrapper img { 
  transform: scale(1.1); 
}

.img-zoom {
  position: absolute;
  bottom: 0; left: 0; right: 0;
  background: rgba(26, 43, 74, 0.7);
  backdrop-filter: blur(8px);
  color: white;
  font-size: 12px;
  padding: 6px 0;
  text-align: center;
  transform: translateY(100%);
  transition: transform 0.3s;
}

.room-card-modern:hover .img-zoom { transform: translateY(0); }

.room-main-info {
  flex: 1;
  padding: 24px 28px;
  display: flex;
  flex-direction: column;
  min-width: 0;
  overflow: hidden;
}

.room-name-text { 
  font-size: 22px; 
  font-weight: 800; 
  margin-bottom: 18px; 
  color: var(--hotel-primary); 
}

.room-params {
  display: flex;
  gap: 28px;
  margin-bottom: 22px;
  flex-wrap: wrap;
}

.param-item { 
  display: flex; 
  flex-direction: column; 
  gap: 6px; 
}
.param-item .label { 
  font-size: 12px; 
  color: var(--hotel-text-muted); 
}
.param-item .val { 
  font-size: 15px; 
  font-weight: 700; 
  color: var(--hotel-primary); 
}

.room-perks { 
  display: flex; 
  flex-wrap: wrap; 
  gap: 10px; 
}
.perk-tag {
  font-size: 12px;
  padding: 4px 14px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  gap: 6px;
  background: rgba(82, 196, 26, 0.1);
  color: #52c41a;
  border: 1px solid rgba(82, 196, 26, 0.3);
}

.perk-tag.wifi { 
  background: rgba(24, 144, 255, 0.1); 
  color: #1890ff; 
  border-color: rgba(24, 144, 255, 0.3); 
}
.perk-tag.cancel { 
  background: rgba(114, 46, 209, 0.1); 
  color: #722ed1; 
  border-color: rgba(114, 46, 209, 0.3); 
}
.perk-tag.confirm { 
  background: rgba(250, 140, 22, 0.1); 
  color: #fa8c16; 
  border-color: rgba(250, 140, 22, 0.3); 
}
.perk-tag.disabled { 
  background: rgba(0, 0, 0, 0.04); 
  color: #bfbfbf; 
  border-color: rgba(0, 0, 0, 0.1); 
  text-decoration: line-through; 
}

.room-price-cta {
  width: 260px;
  padding: 24px 28px;
  border-left: 1px dashed rgba(201, 169, 98, 0.3);
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: flex-end;
  min-width: 0;
}

.price-wrapper-new { 
  text-align: right; 
  margin-bottom: 18px; 
}
.price-top { 
  color: #ff6b6b; 
  line-height: 1; 
}
.price-top .cur { 
  font-size: 18px; 
  font-weight: 700; 
}
.price-top .val { 
  font-size: 46px; 
  font-weight: 900; 
}
.price-bottom { 
  font-size: 12px; 
  color: var(--hotel-text-muted); 
  margin-top: 6px; 
}

.cta-actions { width: 100%; }
.book-now-btn { 
  width: 100%; 
  height: 52px; 
  font-size: 18px; 
  font-weight: 800; 
  border-radius: var(--hotel-radius-lg);
  background: linear-gradient(135deg, var(--hotel-gold-dark) 0%, var(--hotel-gold) 100%);
  border: none;
  box-shadow: 0 6px 20px rgba(201, 169, 98, 0.4);
  transition: all 0.3s;
}
.book-now-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 25px rgba(201, 169, 98, 0.5);
}
.inventory-status { 
  font-size: 12px; 
  text-align: center; 
  margin-top: 10px; 
  color: var(--hotel-text-muted); 
  font-weight: 600; 
}
.inventory-status.low { color: #fa8c16; }

/* ==================== Room Type Card Styles ==================== */
.room-type-card-modern {
  background: rgba(255, 255, 255, 0.95);
  border-radius: var(--hotel-radius-xl);
  margin-bottom: 28px;
  box-shadow: 
    0 6px 24px rgba(26, 43, 74, 0.08),
    0 0 0 1px rgba(201, 169, 98, 0.1);
  border: 1px solid transparent;
  overflow: hidden;
  transition: all 0.4s;
}

.room-type-card-modern:hover {
  box-shadow: 
    0 12px 40px rgba(26, 43, 74, 0.12),
    0 0 0 1px var(--hotel-gold);
}

.room-type-header {
  display: flex;
  background: linear-gradient(135deg, rgba(26, 43, 74, 0.03) 0%, rgba(201, 169, 98, 0.03) 100%);
  border-bottom: 1px solid rgba(201, 169, 98, 0.1);
}

.room-type-header .room-img-wrapper {
  width: 240px;
  height: 160px;
}

.room-type-header .room-type-info {
  flex: 1;
  padding: 24px 28px;
  min-width: 0;
  overflow: hidden;
}

.type-name-text { 
  font-size: 22px; 
  font-weight: 800; 
  margin-bottom: 14px; 
  color: var(--hotel-primary); 
}
.type-params { 
  display: flex; 
  align-items: center; 
  gap: 10px; 
  color: var(--hotel-text-secondary); 
  font-size: 14px; 
  margin-bottom: 14px; 
}
.type-facilities { 
  display: flex; 
  gap: 10px; 
  flex-wrap: wrap; 
}
.f-tag { 
  font-size: 12px; 
  color: var(--hotel-text-secondary); 
  border: 1px solid rgba(26, 43, 74, 0.15); 
  padding: 3px 12px; 
  border-radius: 12px; 
}

/* ==================== Rate Plans Table ==================== */
.rate-plans-container { 
  padding: 0 24px 24px; 
}
.plan-row {
  display: flex;
  align-items: center;
  padding: 18px 0;
  border-bottom: 1px solid rgba(201, 169, 98, 0.1);
  transition: background 0.3s;
}

.plan-row:hover {
  background: rgba(201, 169, 98, 0.03);
}

.plan-row.header {
  font-size: 13px;
  color: var(--hotel-text-muted);
  font-weight: 600;
  border-bottom: 2px solid rgba(201, 169, 98, 0.15);
  background: transparent;
}

.plan-row:last-child { border-bottom: none; }

.plan-info-col { flex: 2; padding-right: 24px; min-width: 0; }
.plan-policy-col { flex: 1.5; padding-right: 24px; }
.plan-price-col { flex: 1; text-align: right; padding-right: 24px; }
.plan-action-col { width: 110px; text-align: right; }

.plan-name { 
  font-size: 17px; 
  font-weight: 700; 
  color: var(--hotel-primary); 
  margin-bottom: 6px; 
}
.plan-services { 
  font-size: 12px; 
  display: flex; 
  gap: 14px; 
}
.plan-services .has { color: #52c41a; }
.plan-services .no { color: var(--hotel-text-muted); text-decoration: line-through; }

.plan-policy-col { 
  font-size: 13px; 
  line-height: 1.7; 
  color: var(--hotel-text-secondary);
}
.text-success { color: #52c41a; font-weight: 600; }
.text-warning { color: #fa8c16; font-weight: 600; }
.payment-limit { 
  color: var(--hotel-text-muted); 
  display: flex; 
  align-items: center; 
  gap: 6px; 
}

.price-val { color: #ff6b6b; line-height: 1; }
.price-val .cur { font-size: 15px; font-weight: 700; }
.price-val .num { font-size: 30px; font-weight: 900; }
.original-price { 
  color: var(--hotel-text-muted); 
  font-size: 12px; 
  text-decoration: line-through; 
  margin-top: 6px; 
  text-align: right; 
}

.plan-book-btn { 
  width: 90px; 
  height: 40px; 
  font-weight: 700; 
  border-radius: var(--hotel-radius);
  background: linear-gradient(135deg, var(--hotel-gold-dark) 0%, var(--hotel-gold) 100%);
  border: none;
  box-shadow: 0 4px 12px rgba(201, 169, 98, 0.3);
  transition: all 0.3s;
}
.plan-book-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 16px rgba(201, 169, 98, 0.4);
}
.inventory-tip { 
  font-size: 11px; 
  color: var(--hotel-text-muted); 
  margin-top: 6px; 
  font-weight: 600; 
  text-align: center; 
}
.inventory-tip.danger { color: #ff6b6b; }

.ota-form-card {
  border-radius: var(--hotel-radius-xl);
  box-shadow: 
    0 4px 20px rgba(26, 43, 74, 0.06),
    0 0 0 1px rgba(201, 169, 98, 0.1);
  background: rgba(255, 255, 255, 0.95);
}

.frequent-guest-list {
  display: flex;
  flex-wrap: wrap;
  gap: 14px;
}

.guest-chip {
  border: 1px solid rgba(26, 43, 74, 0.15);
  border-radius: var(--hotel-radius);
  padding: 10px 16px;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 14px;
  transition: all 0.3s;
  background: rgba(255, 255, 255, 0.8);
}

.guest-chip:hover {
  border-color: var(--hotel-gold);
  background: rgba(201, 169, 98, 0.08);
}

.guest-chip.active {
  border-color: var(--hotel-gold);
  background: rgba(201, 169, 98, 0.12);
  color: var(--hotel-primary);
  font-weight: 700;
  box-shadow: 0 4px 12px rgba(201, 169, 98, 0.2);
}

.guest-chip .actions {
  display: flex;
  gap: 10px;
  font-size: 14px;
  color: var(--hotel-text-muted);
  opacity: 0;
  transition: opacity 0.3s;
}

.guest-chip:hover .actions {
  opacity: 1;
}

.guest-chip .actions span:hover {
  color: var(--hotel-gold);
}

.empty-tip {
  color: var(--hotel-text-muted);
  font-size: 13px;
}

/* ==================== Order Summary - 炫酷订单卡片 ==================== */
.order-summary-card {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(16px);
  border-radius: var(--hotel-radius-2xl);
  padding: 32px;
  position: sticky;
  top: 24px;
  box-shadow: 
    0 20px 60px rgba(26, 43, 74, 0.12),
    0 0 0 1px rgba(201, 169, 98, 0.15);
  border: 1px solid rgba(255, 255, 255, 0.5);
}

.summary-header { 
  margin-bottom: 24px; 
  border-bottom: 1px solid rgba(201, 169, 98, 0.15); 
  padding-bottom: 20px; 
}
.summary-title { 
  font-size: 22px; 
  font-weight: 800; 
  margin: 0; 
  color: var(--hotel-primary); 
}

.summary-hotel-large { 
  display: flex; 
  gap: 18px; 
  margin-bottom: 28px; 
}
.hotel-large-img { 
  width: 110px; 
  height: 110px; 
  border-radius: var(--hotel-radius-lg); 
  object-fit: cover;
  box-shadow: 0 4px 12px rgba(26, 43, 74, 0.1);
}
.hotel-large-info { 
  flex: 1; 
  display: flex; 
  flex-direction: column; 
  justify-content: center;
  min-width: 0;
}
.hotel-name { 
  font-size: 19px; 
  font-weight: 700; 
  margin: 0 0 8px 0;
  color: var(--hotel-primary);
}
.room-type-tag { 
  font-size: 14px; 
  color: var(--hotel-gold); 
  font-weight: 600; 
  margin-bottom: 6px; 
}
.hotel-address { 
  font-size: 13px; 
  color: var(--hotel-text-muted); 
}

.summary-date-box { 
  background: linear-gradient(135deg, rgba(26, 43, 74, 0.03) 0%, rgba(201, 169, 98, 0.05) 100%); 
  padding: 24px; 
  border-radius: var(--hotel-radius-xl); 
  display: flex; 
  justify-content: space-between; 
  align-items: center;
  margin-bottom: 28px;
  border: 1px solid rgba(201, 169, 98, 0.1);
}
.date-item { flex: 1; }
.date-label { font-size: 12px; color: var(--hotel-text-muted); margin-bottom: 6px; }
.date-val { font-size: 17px; font-weight: 700; color: var(--hotel-primary); }
.date-week { font-size: 12px; color: var(--hotel-text-secondary); }
.night-count { 
  padding: 0 16px; 
  display: flex; 
  flex-direction: column; 
  align-items: center; 
}
.night-count .line { width: 1px; height: 12px; background: rgba(201, 169, 98, 0.3); }
.night-count .text { 
  font-size: 12px; 
  font-weight: 600; 
  color: var(--hotel-gold); 
  margin: 6px 0; 
  border: 1px solid var(--hotel-gold); 
  padding: 4px 12px; 
  border-radius: 12px; 
  background: rgba(201, 169, 98, 0.1); 
}

.price-details-box { margin-bottom: 28px; }
.price-row-item { 
  display: flex; 
  justify-content: space-between; 
  align-items: center; 
  margin-bottom: 14px; 
}
.price-row-item .label { font-size: 14px; color: var(--hotel-text-secondary); }
.price-row-item .val { font-size: 15px; font-weight: 600; color: var(--hotel-primary); }
.price-row-item.discount .val { color: #ff6b6b; }
.price-row-item.final .label { font-size: 17px; font-weight: 700; color: var(--hotel-primary); }
.final-price-wrapper { color: #ff6b6b; }
.final-price-wrapper .currency { font-size: 18px; font-weight: 700; }
.final-price-wrapper .amount { font-size: 36px; font-weight: 800; }

/* ==================== Ctrip Style Layout ==================== */
.ctrip-container {
  display: flex;
  gap: 28px;
  max-width: 100%;
  margin: 0 auto;
}

.ctrip-main {
  flex: 1;
  min-width: 0;
}

.order-header-ctrip {
  margin-bottom: 28px;
}

.hotel-title-large {
  font-size: 30px;
  font-weight: 800;
  margin-bottom: 10px;
  color: var(--hotel-primary);
}

.hotel-meta-ctrip {
  display: flex;
  align-items: center;
  gap: 18px;
  color: var(--hotel-text-secondary);
}

.ctrip-card {
  background: rgba(255, 255, 255, 0.95);
  border-radius: var(--hotel-radius-xl);
  padding: 28px;
  box-shadow: 
    0 4px 20px rgba(26, 43, 74, 0.06),
    0 0 0 1px rgba(201, 169, 98, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.5);
}

.card-header-ctrip {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
  padding-bottom: 16px;
  border-bottom: 1px solid rgba(201, 169, 98, 0.15);
}

.card-header-ctrip .title {
  font-size: 19px;
  font-weight: 700;
  color: var(--hotel-primary);
}

.frequent-guest-bar {
  display: flex;
  align-items: center;
  gap: 14px;
  margin-bottom: 24px;
}

.frequent-guest-bar .label {
  font-size: 13px;
  color: var(--hotel-text-muted);
}

.guest-chips-container {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}

.guest-chip-ctrip {
  padding: 6px 18px;
  border: 1px solid rgba(26, 43, 74, 0.15);
  border-radius: var(--hotel-radius);
  cursor: pointer;
  font-size: 13px;
  transition: all 0.3s;
  background: rgba(255, 255, 255, 0.8);
}

.guest-chip-ctrip:hover {
  border-color: var(--hotel-gold);
  color: var(--hotel-gold);
}

.guest-chip-ctrip.active {
  border-color: var(--hotel-gold);
  background: rgba(201, 169, 98, 0.12);
  color: var(--hotel-gold);
  font-weight: 600;
}

.ctrip-form :deep(.ant-form-item-label > label) {
  font-size: 13px;
  color: var(--hotel-text-secondary);
}

/* ==================== Payment Selector ==================== */
.payment-selector-ctrip {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 18px;
}

.payment-option-ctrip {
  display: flex;
  align-items: center;
  gap: 18px;
  padding: 20px;
  border: 1px solid rgba(26, 43, 74, 0.1);
  border-radius: var(--hotel-radius-lg);
  cursor: pointer;
  transition: all 0.3s;
  background: rgba(255, 255, 255, 0.8);
}

.payment-option-ctrip:hover {
  background: rgba(201, 169, 98, 0.05);
  border-color: var(--hotel-gold);
}

.payment-option-ctrip.active {
  background: rgba(201, 169, 98, 0.1);
  border-color: var(--hotel-gold);
  box-shadow: 0 0 0 2px rgba(201, 169, 98, 0.2);
}

.payment-option-ctrip.disabled {
  opacity: 0.5;
  cursor: not-allowed;
  background: rgba(0, 0, 0, 0.02) !important;
  border-color: rgba(26, 43, 74, 0.1) !important;
  box-shadow: none !important;
}

.payment-option-ctrip.disabled:hover {
  border-color: rgba(26, 43, 74, 0.1);
}

.payment-option-ctrip .icon-box {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 22px;
}

.icon-box.balance { background: rgba(24, 144, 255, 0.1); color: #1890ff; }
.icon-box.front { background: rgba(250, 173, 20, 0.1); color: #faad14; }
.icon-box.wechat { background: rgba(7, 193, 96, 0.1); color: #07c160; }
.icon-box.alipay { background: rgba(22, 119, 255, 0.1); color: #1677ff; }

.payment-option-ctrip .info .name {
  font-weight: 700;
  font-size: 15px;
  color: var(--hotel-primary);
}

.payment-option-ctrip .info .desc {
  font-size: 12px;
  color: var(--hotel-text-muted);
}

.offer-section-ctrip {
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.offer-row-ctrip {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.offer-row-ctrip .label {
  font-weight: 600;
  font-size: 14px;
  color: var(--hotel-text-secondary);
}

.label-group {
  display: flex;
  flex-direction: column;
}

.label-group .sub-label {
  font-size: 12px;
  color: var(--hotel-text-muted);
}

.action-group {
  display: flex;
  align-items: center;
  gap: 14px;
}

/* ==================== Side Summary ==================== */
.ctrip-side {
  width: 380px;
}

.ctrip-summary-card {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(16px);
  border-radius: var(--hotel-radius-xl);
  position: sticky;
  top: 24px;
  box-shadow: 
    0 12px 40px rgba(26, 43, 74, 0.1),
    0 0 0 1px rgba(201, 169, 98, 0.15);
  overflow: hidden;
  border: 1px solid rgba(255, 255, 255, 0.5);
}

.summary-header-ctrip {
  background: linear-gradient(135deg, rgba(26, 43, 74, 0.05) 0%, rgba(201, 169, 98, 0.08) 100%);
  padding: 24px;
  border-bottom: 1px solid rgba(201, 169, 98, 0.1);
}

.room-info-box {
  display: flex;
  gap: 14px;
}

.room-img {
  width: 90px;
  height: 70px;
  border-radius: var(--hotel-radius);
  object-fit: cover;
  box-shadow: 0 2px 8px rgba(26, 43, 74, 0.1);
}

.room-name-box .name {
  font-weight: 700;
  font-size: 17px;
  margin-bottom: 4px;
  color: var(--hotel-primary);
}

.room-name-box .plan-name-tag {
  font-size: 13px;
  color: var(--hotel-gold);
  font-weight: 600;
  margin-bottom: 4px;
}

.room-name-box .tags {
  font-size: 12px;
  color: var(--hotel-text-muted);
}

.summary-body-ctrip {
  padding: 28px;
}

.date-range-ctrip {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 28px;
}

.date-item {
  flex: 1;
}

.date-item .lab {
  font-size: 12px;
  color: var(--hotel-text-muted);
  margin-bottom: 6px;
}

.date-item .val {
  font-size: 19px;
  font-weight: 700;
  line-height: 1.2;
  color: var(--hotel-primary);
}

.nights-tag {
  padding: 4px 14px;
  border: 1px solid rgba(201, 169, 98, 0.3);
  border-radius: 14px;
  font-size: 12px;
  background: rgba(201, 169, 98, 0.1);
  margin: 0 18px;
  white-space: nowrap;
  color: var(--hotel-gold);
  font-weight: 600;
  transform: translateY(8px);
}

.price-breakdown-ctrip {
  margin-bottom: 28px;
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.price-breakdown-ctrip .item {
  display: flex;
  justify-content: space-between;
  font-size: 14px;
  color: var(--hotel-text-secondary);
}

.price-breakdown-ctrip .item.discount {
  color: #ff6b6b;
}

.final-total-ctrip {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  margin-bottom: 28px;
  padding-top: 18px;
  border-top: 1px dashed rgba(201, 169, 98, 0.2);
}

.final-total-ctrip .lab {
  font-size: 17px;
  font-weight: 700;
  color: var(--hotel-primary);
}

.final-total-ctrip .val {
  color: #ff6b6b;
}

.final-total-ctrip .val .unit {
  font-size: 18px;
  font-weight: 700;
}

.final-total-ctrip .val .num {
  font-size: 40px;
  font-weight: 800;
}

.ctrip-confirm-btn {
  height: 56px;
  font-size: 19px;
  font-weight: 700;
  border-radius: var(--hotel-radius-lg);
  background: linear-gradient(135deg, var(--hotel-gold-dark) 0%, var(--hotel-gold) 100%);
  border-color: var(--hotel-gold);
  box-shadow: 0 8px 25px rgba(201, 169, 98, 0.4);
  transition: all 0.3s;
}

.ctrip-confirm-btn:hover {
  background: linear-gradient(135deg, var(--hotel-gold) 0%, var(--hotel-gold-light) 100%);
  transform: translateY(-2px);
  box-shadow: 0 10px 30px rgba(201, 169, 98, 0.5);
}

.ctrip-safety-tips {
  margin-top: 18px;
  text-align: center;
  font-size: 12px;
  color: #52c41a;
  font-weight: 600;
}

/* ==================== Mock Payment UI ==================== */
.mock-payment-ctrip {
  text-align: center;
  padding: 24px 0;
}

.payment-title {
  font-size: 14px;
  color: var(--hotel-text-muted);
}

.payment-amount {
  font-size: 52px;
  font-weight: 800;
  margin: 10px 0 28px;
  color: var(--hotel-primary);
}

.payment-vendor {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 14px;
  margin-bottom: 36px;
  font-weight: 600;
  font-size: 17px;
}

.payment-vendor .icon-wrapper {
  display: flex;
  align-items: center;
  justify-content: center;
}

.payment-vendor .wechat-color { color: #07c160; }
.payment-vendor .alipay-color { color: #1677ff; }
.payment-vendor .balance-color { color: #1890ff; }

.payment-qr-mock {
  width: 220px;
  height: 220px;
  margin: 0 auto 36px;
  background: linear-gradient(135deg, rgba(26, 43, 74, 0.03) 0%, rgba(201, 169, 98, 0.05) 100%);
  border-radius: var(--hotel-radius-xl);
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px solid rgba(201, 169, 98, 0.15);
}

.qr-placeholder {
  text-align: center;
}

.qr-placeholder p {
  margin-top: 14px;
  font-size: 13px;
  color: var(--hotel-text-muted);
}

.ota-confirm-btn-large { 
  height: 60px; 
  font-size: 22px; 
  font-weight: 800; 
  border-radius: var(--hotel-radius-xl); 
  margin-top: 10px; 
  box-shadow: 0 8px 30px rgba(201, 169, 98, 0.4);
  background: linear-gradient(135deg, var(--hotel-gold-dark) 0%, var(--hotel-gold) 100%);
  border: none;
}
.trust-badges { 
  display: flex; 
  justify-content: center; 
  gap: 24px; 
  margin-top: 28px; 
  border-top: 1px solid rgba(201, 169, 98, 0.15); 
  padding-top: 24px; 
}
.badge-item { 
  display: flex; 
  align-items: center; 
  gap: 8px; 
  font-size: 12px; 
  color: #52c41a; 
  font-weight: 600; 
}
.payment-item-box { 
  width: 100%; 
  border: 1px solid rgba(26, 43, 74, 0.1); 
  border-radius: var(--hotel-radius-lg); 
  padding: 18px; 
  transition: all 0.3s; 
  margin: 0 !important; 
  display: flex !important; 
  align-items: center;
  background: rgba(255, 255, 255, 0.8);
}
.payment-item-box:hover { 
  border-color: var(--hotel-gold); 
  background: rgba(201, 169, 98, 0.05); 
}
.ant-radio-wrapper-checked.payment-item-box { 
  border-color: var(--hotel-gold); 
  background: rgba(201, 169, 98, 0.1); 
}
.payment-item-content { 
  display: flex; 
  align-items: center; 
  gap: 18px; 
  margin-left: 10px; 
}
.pay-icon { font-size: 26px; color: var(--hotel-gold); }
.pay-icon.wechat { color: #07c160; }
.pay-icon.alipay { color: #1677ff; }
.pay-info { display: flex; flex-direction: column; }
.pay-name { font-size: 16px; font-weight: 700; color: var(--hotel-primary); }
.pay-desc { font-size: 12px; color: var(--hotel-text-muted); }
.online-payment-hint { 
  text-align: center; 
  margin-top: 18px; 
  font-size: 13px; 
  color: #1890ff; 
  background: rgba(24, 144, 255, 0.08); 
  padding: 12px; 
  border-radius: var(--hotel-radius); 
  border: 1px solid rgba(24, 144, 255, 0.2); 
}
.front-desk-payment-hint { 
  text-align: center; 
  margin-top: 18px; 
  font-size: 13px; 
  color: #faad14; 
  background: rgba(250, 173, 20, 0.08); 
  padding: 12px; 
  border-radius: var(--hotel-radius); 
  border: 1px solid rgba(250, 173, 20, 0.2); 
}
.security-tip { 
  text-align: center; 
  margin-top: 14px; 
  font-size: 12px; 
  color: var(--hotel-text-muted); 
}
.points-redemption { padding: 10px 0; }
.points-info { margin-bottom: 14px; font-size: 14px; }
.points-count { font-weight: 700; color: #faad14; }
.points-rule { color: var(--hotel-text-muted); font-size: 12px; }
.points-action { display: flex; align-items: center; }
.points-result { 
  margin-top: 14px; 
  padding-top: 14px; 
  border-top: 1px dashed rgba(201, 169, 98, 0.2); 
  font-size: 14px; 
  color: var(--hotel-text-muted); 
}
.discount-val { color: #ff6b6b; font-weight: 700; margin-left: 6px; }

/* ==================== Review Drawer Styles ==================== */
.score-card-new.clickable {
  cursor: pointer;
  transition: all 0.3s;
}
.score-card-new.clickable:hover {
  box-shadow: 
    0 10px 30px rgba(201, 169, 98, 0.25),
    0 0 0 2px var(--hotel-gold);
  transform: translateY(-2px);
}
.view-all-reviews {
  text-align: center;
  color: var(--hotel-gold);
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  margin-top: 10px;
  transition: all 0.3s;
}
.view-all-reviews:hover {
  color: var(--hotel-gold-dark);
}
.review-drawer-content {
  padding: 0 4px;
}
.review-stats-header {
  display: flex;
  gap: 36px;
  align-items: center;
}
.stats-score-box {
  text-align: center;
  min-width: 130px;
}
.big-score {
  font-size: 52px;
  font-weight: 900;
  color: var(--hotel-gold);
  line-height: 1;
}
.score-label {
  font-size: 17px;
  font-weight: 700;
  color: var(--hotel-gold);
  margin-top: 6px;
}
.review-total {
  font-size: 12px;
  color: var(--hotel-text-muted);
  margin-top: 6px;
}
.stats-dimensions {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.dim-row {
  display: flex;
  align-items: center;
  gap: 14px;
}
.dim-label {
  font-size: 13px;
  color: var(--hotel-text-secondary);
  width: 36px;
}
.dim-val {
  font-size: 13px;
  font-weight: 600;
  color: var(--hotel-gold);
  width: 32px;
  text-align: right;
}
.review-item {
  padding: 18px 0;
  border-bottom: 1px solid rgba(201, 169, 98, 0.1);
}
.review-item:last-child {
  border-bottom: none;
}
.review-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 10px;
}
.reviewer-info {
  display: flex;
  align-items: center;
  gap: 10px;
}
.reviewer-name {
  font-weight: 600;
  font-size: 14px;
  color: var(--hotel-primary);
}
.review-date {
  font-size: 12px;
  color: var(--hotel-text-muted);
}
.review-ratings {
  display: flex;
  gap: 10px;
  margin-bottom: 10px;
}
.rating-tag {
  font-size: 12px;
  color: var(--hotel-gold);
  background: rgba(201, 169, 98, 0.1);
  padding: 4px 10px;
  border-radius: 12px;
}
.review-content {
  font-size: 14px;
  color: var(--hotel-text);
  line-height: 1.7;
  margin-bottom: 10px;
}
.review-photos {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
  margin-bottom: 10px;
}
.review-photo {
  width: 90px;
  height: 90px;
  border-radius: var(--hotel-radius);
  object-fit: cover;
  transition: transform 0.3s;
}
.review-photo:hover {
  transform: scale(1.05);
}
.hotel-reply {
  background: linear-gradient(135deg, rgba(26, 43, 74, 0.03) 0%, rgba(201, 169, 98, 0.05) 100%);
  padding: 14px 18px;
  border-radius: var(--hotel-radius-lg);
  margin-top: 10px;
  border: 1px solid rgba(201, 169, 98, 0.1);
}
.reply-label {
  font-size: 12px;
  color: var(--hotel-text-muted);
  margin-bottom: 6px;
}
.reply-content {
  font-size: 13px;
  color: var(--hotel-text-secondary);
}

/* ==================== Animation Helpers ==================== */
.animate__animated { animation-duration: 0.8s; }

@keyframes fadeInDown { 
  from { opacity: 0; transform: translateY(-20px); } 
  to { opacity: 1; transform: translateY(0); } 
}
.animate__fadeInDown { animation-name: fadeInDown; }

@keyframes fadeInUp { 
  from { opacity: 0; transform: translateY(20px); } 
  to { opacity: 1; transform: translateY(0); } 
}
.animate__fadeInUp { animation-name: fadeInUp; }

@keyframes cardReveal {
  from {
    opacity: 0;
    transform: translateY(30px) scale(0.95);
  }
  to {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}

@keyframes shimmerLoading {
  0% { background-position: -200% 0; }
  100% { background-position: 200% 0; }
}

/* ==================== Responsive Adjustments ==================== */
@media (max-width: 1200px) {
  .ctrip-side {
    width: 340px;
  }
}

@media (max-width: 992px) {
  .ctrip-container {
    flex-direction: column;
  }
  
  .ctrip-side {
    width: 100%;
    max-width: 500px;
    margin: 0 auto;
  }
  
  .ctrip-summary-card {
    position: relative;
    top: 0;
  }
  
  .room-card-content {
    flex-direction: column;
    height: auto;
  }
  
  .room-img-wrapper {
    width: 100%;
    height: 200px;
  }
  
  .room-price-cta {
    width: 100%;
    border-left: none;
    border-top: 1px dashed rgba(201, 169, 98, 0.3);
    padding: 20px;
  }
}

@media (max-width: 768px) {
  .hero-bg {
    height: 380px;
  }
  
  .hero-content h1 { 
    font-size: 36px; 
  }
  
  .hero-content p {
    font-size: 18px;
  }
  
  .floating-search-wrapper { 
    margin-top: -60px; 
  }
  
  .ota-search-card {
    padding: 12px;
  }
  
  .ota-search-btn { 
    margin-top: 16px; 
    height: 52px;
    font-size: 18px;
  }
  
  .divider-left { 
    border-left: none; 
    border-top: 1px solid rgba(201, 169, 98, 0.15); 
    padding-top: 12px;
    margin-top: 12px;
  }
  
  .ota-content-wrapper {
    padding: 0 16px;
    margin: 30px auto;
  }
  
  .section-title {
    font-size: 22px;
  }
  
  .ota-steps-nav {
    padding: 20px 24px;
  }
  
  .hotel-name-large {
    font-size: 26px;
  }
  
  .payment-selector-ctrip {
    grid-template-columns: 1fr;
  }
  
  .room-type-header {
    flex-direction: column;
  }
  
  .room-type-header .room-img-wrapper {
    width: 100%;
    height: 180px;
  }
  
  .plan-row {
    flex-wrap: wrap;
    gap: 12px;
  }
  
  .plan-info-col,
  .plan-policy-col,
  .plan-price-col {
    flex: none;
    width: 100%;
    padding-right: 0;
  }
  
  .plan-action-col {
    width: 100%;
    text-align: center;
  }
  
  .plan-book-btn {
    width: 100%;
  }
}

@media (max-width: 480px) {
  .hero-bg {
    height: 320px;
  }
  
  .hero-content h1 {
    font-size: 28px;
  }
  
  .ota-highlight {
    font-size: 22px;
  }
  
  .section-title {
    font-size: 20px;
  }
  
  .hotel-name-large {
    font-size: 22px;
  }
  
  .room-name-text {
    font-size: 18px;
  }
  
  .price-top .val {
    font-size: 36px;
  }
  
  .final-total-ctrip .val .num {
    font-size: 32px;
  }
}

/* ==================== Image Gallery Styles ==================== */
.image-gallery-content {
  padding: 20px 0;
}

.main-image-container {
  position: relative;
  width: 100%;
  height: 500px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f5f5f5;
  border-radius: var(--hotel-radius-lg);
  overflow: hidden;
}

.main-gallery-image {
  max-width: 100%;
  max-height: 100%;
  object-fit: contain;
}

.image-nav {
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  width: 44px;
  height: 44px;
  background: rgba(255, 255, 255, 0.9);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.3s;
  color: var(--hotel-primary);
  font-size: 18px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.image-nav:hover {
  background: white;
  color: var(--hotel-gold);
  transform: translateY(-50%) scale(1.1);
}

.image-nav.prev {
  left: 16px;
}

.image-nav.next {
  right: 16px;
}

.image-counter {
  text-align: center;
  margin: 16px 0;
  font-size: 14px;
  color: var(--hotel-text-secondary);
}

.thumbnail-list {
  display: flex;
  gap: 12px;
  overflow-x: auto;
  padding: 12px 0;
  justify-content: center;
}

.thumbnail-item {
  width: 80px;
  height: 60px;
  border-radius: var(--hotel-radius);
  overflow: hidden;
  cursor: pointer;
  border: 2px solid transparent;
  transition: all 0.3s;
  flex-shrink: 0;
}

.thumbnail-item img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.thumbnail-item.active {
  border-color: var(--hotel-gold);
  box-shadow: 0 4px 12px rgba(201, 169, 98, 0.3);
}

.thumbnail-item:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.side-img-item {
  cursor: pointer;
  transition: all 0.3s;
}

.side-img-item:hover {
  opacity: 0.9;
}

@media (max-width: 768px) {
  .main-image-container {
    height: 300px;
  }
  
  .thumbnail-item {
    width: 60px;
    height: 45px;
  }
}
</style>
