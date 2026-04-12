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
                <div class="side-img-item"><img src="https://images.unsplash.com/photo-1566073771259-6a8506099945?q=80&w=400&auto=format&fit=crop" /></div>
                <div class="side-img-item"><img src="https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?q=80&w=400&auto=format&fit=crop" /></div>
                <div class="side-img-item more">
                  <img src="https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?q=80&w=400&auto=format&fit=crop" />
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
                <div class="score-card-new">
                  <div class="score-main">
                    <span class="num">{{ selectedHotel.rating }}</span>
                    <span class="total">/5</span>
                  </div>
                  <div class="score-info">
                    <div class="desc">“超赞”</div>
                    <div class="count">{{ selectedHotel.reviewCount }} 条真实评价</div>
                  </div>
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
                      :disabled="type.availableCount === 0"
                      @click="selectPlan(type, plan)"
                    >
                      预订
                    </a-button>
                    <div class="inventory-tip" v-if="type.availableCount < 3">仅剩{{ type.availableCount }}间</div>
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
                        <a-select-option value="idcard">身份证</a-select-option>
                        <a-select-option value="passport">护照</a-select-option>
                      </a-select>
                    </a-form-item>
                  </a-col>
                  <a-col :span="12">
                    <a-form-item label="证件号码" required>
                      <a-input v-model:value="bookingForm.idNumber" placeholder="请输入有效证件号" size="large" />
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
                    <span class="sub-label">可用 {{ memberInfo?.points || 0 }} 积分 (10积分=1元)</span>
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
                      <div class="val">{{ dayjs(dateRange[0]).format('MM月DD日') }}</div>
                    </div>
                    <div class="nights-tag">{{ nights }}晚</div>
                    <div class="date-item text-right">
                      <div class="lab">退房</div>
                      <div class="val">{{ dayjs(dateRange[1]).format('MM月DD日') }}</div>
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
        v-model:visible="paymentModalVisible"
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

    <!-- Frequent Guest Management Modal -->
    <a-modal
      v-model:visible="showGuestModal"
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
import { ref, reactive, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { message, Modal } from 'ant-design-vue'
import dayjs, { Dayjs } from 'dayjs'
import guestService, { FrequentGuest } from '@/api/frequent-guest'
import { authService } from '@/api/auth'
import { hotelApi } from '@/api/hotel'
import { paymentApi } from '@/api/payment'
import request from '@/api/request'
import { useAppStore } from '@/stores/app'
import {
  EnvironmentOutlined, EnvironmentFilled, StarOutlined, StarFilled,
  UserOutlined, MobileOutlined, CheckOutlined,
  CheckCircleOutlined, LeftOutlined, WifiOutlined,
  CoffeeOutlined, WalletOutlined, WechatOutlined, AlipayCircleOutlined,
  SecurityScanOutlined, PlusOutlined, DeleteOutlined, EditOutlined, InfoCircleOutlined,
  QrcodeOutlined, UnlockOutlined, HomeOutlined, FullscreenOutlined, ThunderboltOutlined
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

const handlePreSubmit = () => {
  if (paymentMethod.value === 'balance') {
    const balance = Number(memberInfo.value?.balance || 0)
    if (balance < finalTotalPrice.value) {
      return message.error(`余额不足！当前余额 ¥${balance}，还需充值 ¥${(finalTotalPrice.value - balance).toFixed(2)}`)
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

const hotelList = ref<any[]>([])

// --- Computed ---
const nights = computed(() => {
  if (dateRange.value[0] && dateRange.value[1]) {
    return dateRange.value[1].diff(dateRange.value[0], 'day')
  }
  return 1
})

const originalPrice = computed(() => (selectedRoom.value?.price || 0) * nights.value)

const memberDiscount = computed(() => {
  if (!memberInfo.value) return 1.0
  const mLevel = memberInfo.value.member_level || 'standard'
  const discounts: Record<string, number> = {
    'diamond': 0.80,
    'platinum': 0.85,
    'gold': 0.88,
    'silver': 0.95,
    'standard': 1.0
  }
  return discounts[mLevel] || 1.0
})

const memberLevelLabel = computed(() => {
  if (!memberInfo.value) return ''
  return memberInfo.value.level_label || `LEVEL ${memberInfo.value.level || 1}`
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
    const res = await request.get('/coupons/me')
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
  const roomId = selectedRoom.value?.id || selectedRoom.value?.room_id
  if (!roomId || !dateRange.value || dateRange.value.length < 2) {
    console.warn('Skipping price calculation: Missing roomId or dates', { roomId, dateRange: dateRange.value })
    return
  }

  try {
    const res = await request.get('/bookings/calculate-price', {
      params: {
        room_id: roomId,
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
  } catch (error) {
    message.error('加载房态失败，请稍后重试')
  }
}

const selectPlan = async (type: any, plan: any) => {
  if (!appStore.userInfo) {
    message.info('请先登录后再进行预订')
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
    id: type.room_id || type.id,
    room_id: type.room_id,
    room_type_id: type.room_type_id,
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
  if (!bookingForm.guestName) {
    return message.warning('请填写入住人姓名')
  }
  if (!bookingForm.phone || bookingForm.phone.length < 11) {
    return message.warning('请填写正确的手机号码')
  }
  if (!bookingForm.idNumber || bookingForm.idNumber.length < 15) {
    return message.warning('请填写正确的身份证号码')
  }

  const roomId = Number(selectedRoom.value?.id || selectedRoom.value?.room_id)
  if (!roomId || isNaN(roomId)) {
    return message.error('无效的房间 ID，请重新选择房间')
  }

  const payload = {
    room_id: roomId,
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
      message.success(`预订成功！请在15分钟内到店支付，超时订单将自动取消`)
    } else {
      message.success('预订成功！')
    }
  } catch (error: any) {
    console.error('预订或支付失败:', error)
    if (error?.response?.status === 409) {
      message.error('该房间已被其他顾客预订，请选择其他房间')
    } else {
      message.error(error?.response?.data?.message || error?.message || '预订失败，请稍后重试')
    }
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
  max-width: 1200px;
  margin: -60px auto 0;
  padding: 0 20px;
  position: relative;
  z-index: 10;
}

.ota-search-card {
  border-radius: 16px;
  box-shadow: 0 10px 40px rgba(0,0,0,0.15);
  padding: 12px;
  background: white;
}

.search-item {
  padding: 8px 20px;
}

.search-label {
  display: block;
  font-size: 13px;
  color: #8c8c8c;
  margin-bottom: 6px;
  font-weight: 600;
}

.divider-left {
  border-left: 1px solid #f0f0f0;
}

.ota-input :deep(.ant-input) {
  font-size: 17px;
  font-weight: 600;
}

.ota-range-picker :deep(.ant-picker-input > input) {
  font-size: 17px;
  font-weight: 600;
}

.ota-guest-selector {
  font-size: 17px;
  font-weight: 600;
  cursor: pointer;
  padding: 4px 0;
  display: flex;
  align-items: center;
}

.guest-popover {
  position: absolute;
  top: 100%;
  left: 0;
  width: 220px;
  background: white;
  box-shadow: 0 8px 24px rgba(0,0,0,0.15);
  border-radius: 12px;
  padding: 16px;
  margin-top: 12px;
  z-index: 100;
}

.popover-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
}

.ota-search-btn {
  height: 60px;
  font-size: 20px;
  font-weight: bold;
  border-radius: 14px;
  background: linear-gradient(90deg, #008cff, #0056ff);
  box-shadow: 0 4px 15px rgba(0, 140, 255, 0.3);
}

/* Content Wrapper */
.ota-content-wrapper {
  max-width: 1300px;
  margin: 40px auto;
  padding: 0 30px;
}

.with-padding {
  padding-top: 20px;
}

/* Steps Nav */
.ota-steps-nav {
  background: white;
  padding: 24px 40px;
  border-radius: 12px;
  margin-bottom: 32px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.03);
}

.ota-custom-steps :deep(.ant-steps-item-title) {
  font-weight: 700 !important;
  font-size: 15px !important;
}

.ota-custom-steps :deep(.ant-steps-item-process .ant-steps-item-icon) {
  background: #008cff;
  border-color: #008cff;
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
  z-index: 2;
}

.card-badge.danger {
  background: #8c8c8c;
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

/* Room Selection Styles Redesign */
.room-selection-section {
  max-width: 1100px;
  margin: 0 auto;
}

.back-nav-cta {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  color: #008cff;
  font-weight: 600;
  cursor: pointer;
  margin-bottom: 16px;
  transition: all 0.2s;
}

.back-nav-cta:hover { opacity: 0.8; }

.hotel-intro-card {
  background: white;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 4px 16px rgba(0,0,0,0.06);
  margin-bottom: 24px;
  position: relative; /* 确保子元素定位参考 */
}

.hotel-gallery {
  display: flex;
  height: 380px; /* 增加高度以容纳评分卡片 */
  gap: 4px;
}

.hotel-gallery img { width: 100%; height: 100%; object-fit: cover; }

.main-img { flex: 2; }
.side-imgs { flex: 1; display: flex; flex-direction: column; gap: 4px; }
.side-img-item { flex: 1; min-height: 0; } /* 确保子项不溢出 */
.side-img-item.more { position: relative; }
.side-img-item.more .overlay {
  position: absolute;
  top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.5);
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 14px;
}

.hotel-header-new {
  padding: 24px;
  display: flex;
  justify-content: space-between;
  align-items: flex-start; /* 顶部对齐 */
}

.hotel-name-large { font-size: 32px; font-weight: 800; margin-bottom: 8px; color: #1a1a1a; }
.hotel-tags-row { display: flex; align-items: center; gap: 12px; margin-bottom: 12px; }
.hotel-type-tag { font-size: 12px; color: #8c8c8c; background: #f5f5f5; padding: 2px 8px; border-radius: 4px; }

.hotel-address-new { font-size: 14px; color: #595959; }

.score-card-new {
  background: #fff; /* 改为白色背景增加对比 */
  padding: 12px 20px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  gap: 12px;
  border: 1px solid #f0f0f0;
  box-shadow: 0 4px 12px rgba(0,0,0,0.08);
  margin-top: -60px; /* 向上偏移悬浮在图片上 */
  position: relative;
  z-index: 5;
}

.score-main { text-align: center; border-right: 1px solid #d6e4ff; padding-right: 16px; }
.score-main .num { font-size: 32px; font-weight: 900; color: #008cff; line-height: 1; }
.score-main .total { font-size: 14px; color: #8c8c8c; }

.score-info .desc { font-weight: 800; color: #008cff; font-size: 16px; margin-bottom: 4px; }
.score-info .count { font-size: 12px; color: #8c8c8c; }

/* Room List New Styles */
.room-list-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  margin-bottom: 16px;
  padding: 0 4px;
}

.room-list-header .title { font-size: 22px; font-weight: 800; color: #1a1a1a; }
.room-list-header .filter-tips { font-size: 13px; color: #8c8c8c; }

.room-card-modern {
  background: white;
  border-radius: 12px;
  margin-bottom: 20px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.04);
  transition: all 0.3s;
  border: 1px solid #f0f0f0;
  overflow: hidden;
}

.room-card-modern:hover {
  box-shadow: 0 8px 24px rgba(0,0,0,0.08);
  border-color: #008cff;
}

.room-card-content {
  display: flex;
  height: 200px;
}

.room-img-wrapper {
  width: 260px;
  position: relative;
  overflow: hidden;
}

.room-img-wrapper img { width: 100%; height: 100%; object-fit: cover; transition: transform 0.5s; }
.room-card-modern:hover .room-img-wrapper img { transform: scale(1.1); }

.img-zoom {
  position: absolute;
  bottom: 0; left: 0; right: 0;
  background: rgba(0,0,0,0.6);
  color: white;
  font-size: 12px;
  padding: 4px 0;
  text-align: center;
  transform: translateY(100%);
  transition: transform 0.3s;
}

.room-card-modern:hover .img-zoom { transform: translateY(0); }

.room-main-info {
  flex: 1;
  padding: 20px 24px;
  display: flex;
  flex-direction: column;
}

.room-name-text { font-size: 20px; font-weight: 800; margin-bottom: 16px; color: #1a1a1a; }

.room-params {
  display: flex;
  gap: 24px;
  margin-bottom: 20px;
}

.param-item { display: flex; flex-direction: column; gap: 4px; }
.param-item .label { font-size: 12px; color: #8c8c8c; }
.param-item .val { font-size: 14px; font-weight: 700; color: #1a1a1a; }

.room-perks { display: flex; flex-wrap: wrap; gap: 8px; }
.perk-tag {
  font-size: 12px;
  padding: 2px 10px;
  border-radius: 4px;
  display: flex;
  align-items: center;
  gap: 4px;
  background: #f6ffed;
  color: #52c41a;
  border: 1px solid #b7eb8f;
}

.perk-tag.wifi { background: #e6f7ff; color: #1890ff; border-color: #91d5ff; }
.perk-tag.cancel { background: #f9f0ff; color: #722ed1; border-color: #d3adf7; }
.perk-tag.confirm { background: #fff7e6; color: #fa8c16; border-color: #ffd591; }
.perk-tag.disabled { background: #f5f5f5; color: #bfbfbf; border-color: #d9d9d9; text-decoration: line-through; }

.room-price-cta {
  width: 240px;
  padding: 20px 24px;
  border-left: 1px dashed #f0f0f0;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: flex-end;
}

.price-wrapper-new { text-align: right; margin-bottom: 16px; }
.price-top { color: #ff4d4f; line-height: 1; }
.price-top .cur { font-size: 18px; font-weight: 700; }
.price-top .val { font-size: 42px; font-weight: 900; }
.price-bottom { font-size: 12px; color: #8c8c8c; margin-top: 4px; }

.cta-actions { width: 100%; }
.book-now-btn { width: 100%; height: 48px; font-size: 18px; font-weight: 800; border-radius: 8px; }
.inventory-status { font-size: 12px; text-align: center; margin-top: 8px; color: #8c8c8c; font-weight: 600; }
.inventory-status.low { color: #fa8c16; }

/* Room Type Card New Styles */
.room-type-card-modern {
  background: white;
  border-radius: 12px;
  margin-bottom: 24px;
  box-shadow: 0 4px 16px rgba(0,0,0,0.06);
  border: 1px solid #f0f0f0;
  overflow: hidden;
}

.room-type-header {
  display: flex;
  background: #fafafa;
  border-bottom: 1px solid #f0f0f0;
}

.room-type-header .room-img-wrapper {
  width: 220px;
  height: 140px;
}

.room-type-header .room-type-info {
  flex: 1;
  padding: 20px 24px;
}

.type-name-text { font-size: 20px; font-weight: 800; margin-bottom: 12px; color: #1a1a1a; }
.type-params { display: flex; align-items: center; gap: 8px; color: #595959; font-size: 14px; margin-bottom: 12px; }
.type-facilities { display: flex; gap: 8px; flex-wrap: wrap; }
.f-tag { font-size: 12px; color: #8c8c8c; border: 1px solid #d9d9d9; padding: 1px 8px; border-radius: 4px; }

/* Rate Plans Table */
.rate-plans-container { padding: 0 20px 20px; }
.plan-row {
  display: flex;
  align-items: center;
  padding: 16px 0;
  border-bottom: 1px solid #f0f0f0;
}

.plan-row.header {
  font-size: 13px;
  color: #8c8c8c;
  font-weight: 600;
  border-bottom: 2px solid #f0f0f0;
}

.plan-row:last-child { border-bottom: none; }

.plan-info-col { flex: 2; padding-right: 20px; }
.plan-policy-col { flex: 1.5; padding-right: 20px; }
.plan-price-col { flex: 1; text-align: right; padding-right: 20px; }
.plan-action-col { width: 100px; text-align: right; }

.plan-name { font-size: 16px; font-weight: 700; color: #1a1a1a; margin-bottom: 4px; }
.plan-services { font-size: 12px; display: flex; gap: 12px; }
.plan-services .has { color: #52c41a; }
.plan-services .no { color: #8c8c8c; text-decoration: line-through; }

.plan-policy-col { font-size: 13px; line-height: 1.6; }
.text-success { color: #52c41a; font-weight: 600; }
.text-warning { color: #fa8c16; font-weight: 600; }
.payment-limit { color: #8c8c8c; display: flex; align-items: center; gap: 4px; }

.price-val { color: #ff4d4f; line-height: 1; }
.price-val .cur { font-size: 14px; font-weight: 700; }
.price-val .num { font-size: 28px; font-weight: 900; }
.original-price { color: #999; font-size: 12px; text-decoration: line-through; margin-top: 4px; text-align: right; }

.plan-book-btn { width: 80px; height: 36px; font-weight: 700; border-radius: 6px; }
.inventory-tip { font-size: 11px; color: #fa8c16; margin-top: 4px; font-weight: 600; }

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
  border-radius: 20px;
  padding: 28px;
  position: sticky;
  top: 20px;
  box-shadow: 0 15px 40px rgba(0,0,0,0.08);
  border: 1px solid #f0f0f0;
}

.summary-header { margin-bottom: 20px; border-bottom: 1px solid #f0f0f0; padding-bottom: 16px; }
.summary-title { font-size: 20px; font-weight: 800; margin: 0; color: #1a1a1a; }

.summary-hotel-large { display: flex; gap: 16px; margin-bottom: 24px; }
.hotel-large-img { width: 100px; height: 100px; border-radius: 12px; object-fit: cover; }
.hotel-large-info { flex: 1; display: flex; flex-direction: column; justify-content: center; }
.hotel-name { font-size: 18px; font-weight: 700; margin: 0 0 6px 0; }
.room-type-tag { font-size: 14px; color: #008cff; font-weight: 600; margin-bottom: 4px; }
.hotel-address { font-size: 13px; color: #8c8c8c; }

.summary-date-box { 
  background: #f8faff; 
  padding: 20px; 
  border-radius: 16px; 
  display: flex; 
  justify-content: space-between; 
  align-items: center;
  margin-bottom: 24px;
}
.date-item { flex: 1; }
.date-label { font-size: 12px; color: #8c8c8c; margin-bottom: 4px; }
.date-val { font-size: 16px; font-weight: 700; color: #1a1a1a; }
.date-week { font-size: 12px; color: #595959; }
.night-count { padding: 0 12px; display: flex; flex-direction: column; align-items: center; }
.night-count .line { width: 1px; height: 10px; background: #d9d9d9; }
.night-count .text { font-size: 12px; font-weight: 600; color: #008cff; margin: 4px 0; border: 1px solid #008cff; padding: 2px 8px; border-radius: 10px; background: white; }

.price-details-box { margin-bottom: 24px; }
.price-row-item { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; }
.price-row-item .label { font-size: 14px; color: #595959; }
.price-row-item .val { font-size: 15px; font-weight: 600; }
.price-row-item.discount .val { color: #ff4d4f; }
.price-row-item.final .label { font-size: 16px; font-weight: 700; color: #1a1a1a; }
.final-price-wrapper { color: #ff4d4f; }
.final-price-wrapper .currency { font-size: 18px; font-weight: 700; }
.final-price-wrapper .amount { font-size: 32px; font-weight: 800; }

/* Ctrip Style Redesign */
.ctrip-container {
  display: flex;
  gap: 24px;
  max-width: 1200px;
  margin: 0 auto;
}

.ctrip-main {
  flex: 1;
  min-width: 0;
}

.order-header-ctrip {
  margin-bottom: 24px;
}

.hotel-title-large {
  font-size: 28px;
  font-weight: 800;
  margin-bottom: 8px;
}

.hotel-meta-ctrip {
  display: flex;
  align-items: center;
  gap: 16px;
  color: #595959;
}

.ctrip-card {
  background: #fff;
  border-radius: 8px;
  padding: 24px;
  box-shadow: 0 1px 4px rgba(0,0,0,0.05);
}

.card-header-ctrip {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  padding-bottom: 12px;
  border-bottom: 1px solid #f0f0f0;
}

.card-header-ctrip .title {
  font-size: 18px;
  font-weight: 700;
}

.frequent-guest-bar {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 20px;
}

.frequent-guest-bar .label {
  font-size: 13px;
  color: #8c8c8c;
}

.guest-chips-container {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.guest-chip-ctrip {
  padding: 4px 16px;
  border: 1px solid #d9d9d9;
  border-radius: 4px;
  cursor: pointer;
  font-size: 13px;
  transition: all 0.3s;
}

.guest-chip-ctrip:hover {
  border-color: #008cff;
  color: #008cff;
}

.guest-chip-ctrip.active {
  border-color: #008cff;
  background: #e6f7ff;
  color: #008cff;
}

.ctrip-form :deep(.ant-form-item-label > label) {
  font-size: 13px;
  color: #595959;
}

.payment-selector-ctrip {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 16px;
}

.payment-option-ctrip {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 16px;
  border: 1px solid #f0f0f0;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
}

.payment-option-ctrip:hover {
  background: #f8faff;
  border-color: #008cff;
}

.payment-option-ctrip.active {
  background: #e6f7ff;
  border-color: #008cff;
  box-shadow: 0 0 0 1px #008cff;
}

.payment-option-ctrip.disabled {
  opacity: 0.5;
  cursor: not-allowed;
  background: #f5f5f5 !important;
  border-color: #d9d9d9 !important;
  box-shadow: none !important;
}

.payment-option-ctrip.disabled:hover {
  border-color: #d9d9d9;
}

.payment-option-ctrip .icon-box {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
}

.icon-box.balance { background: #e6f7ff; color: #1890ff; }
.icon-box.front { background: #fff7e6; color: #faad14; }
.icon-box.wechat { background: #e6fffb; color: #52c41a; }
.icon-box.alipay { background: #e6f7ff; color: #1677ff; }

.payment-option-ctrip .info .name {
  font-weight: 700;
  font-size: 14px;
}

.payment-option-ctrip .info .desc {
  font-size: 12px;
  color: #8c8c8c;
}

.offer-section-ctrip {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.offer-row-ctrip {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.offer-row-ctrip .label {
  font-weight: 600;
  font-size: 14px;
}

.label-group {
  display: flex;
  flex-direction: column;
}

.label-group .sub-label {
  font-size: 12px;
  color: #8c8c8c;
}

.action-group {
  display: flex;
  align-items: center;
  gap: 12px;
}

/* Side Summary */
.ctrip-side {
  width: 360px;
}

.ctrip-summary-card {
  background: #fff;
  border-radius: 8px;
  position: sticky;
  top: 20px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
  overflow: hidden;
}

.summary-header-ctrip {
  background: #f0f5ff;
  padding: 20px;
}

.room-info-box {
  display: flex;
  gap: 12px;
}

.room-img {
  width: 80px;
  height: 60px;
  border-radius: 4px;
  object-fit: cover;
}

.room-name-box .name {
  font-weight: 700;
  font-size: 16px;
  margin-bottom: 2px;
}

.room-name-box .plan-name-tag {
  font-size: 13px;
  color: #008cff;
  font-weight: 600;
  margin-bottom: 2px;
}

.room-name-box .tags {
  font-size: 12px;
  color: #8c8c8c;
}

.summary-body-ctrip {
  padding: 24px;
}

.date-range-ctrip {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
}

.date-item .lab {
  font-size: 12px;
  color: #8c8c8c;
  margin-bottom: 4px;
}

.date-item .val {
  font-size: 18px;
  font-weight: 700;
}

.nights-tag {
  padding: 2px 12px;
  border: 1px solid #d9d9d9;
  border-radius: 12px;
  font-size: 12px;
  background: #fff;
}

.price-breakdown-ctrip {
  margin-bottom: 24px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.price-breakdown-ctrip .item {
  display: flex;
  justify-content: space-between;
  font-size: 14px;
}

.price-breakdown-ctrip .item.discount {
  color: #ff4d4f;
}

.final-total-ctrip {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  margin-bottom: 24px;
  padding-top: 16px;
  border-top: 1px dashed #f0f0f0;
}

.final-total-ctrip .lab {
  font-size: 16px;
  font-weight: 700;
}

.final-total-ctrip .val {
  color: #ff4d4f;
}

.final-total-ctrip .val .unit {
  font-size: 18px;
  font-weight: 700;
}

.final-total-ctrip .val .num {
  font-size: 36px;
  font-weight: 800;
}

.ctrip-confirm-btn {
  height: 50px;
  font-size: 18px;
  font-weight: 700;
  border-radius: 4px;
  background: #ff9a14;
  border-color: #ff9a14;
}

.ctrip-confirm-btn:hover {
  background: #ffb147;
  border-color: #ffb147;
}

.ctrip-safety-tips {
  margin-top: 16px;
  text-align: center;
  font-size: 12px;
  color: #52c41a;
  font-weight: 600;
}

/* Mock Payment UI */
.mock-payment-ctrip {
  text-align: center;
  padding: 20px 0;
}

.payment-title {
  font-size: 14px;
  color: #8c8c8c;
}

.payment-amount {
  font-size: 48px;
  font-weight: 800;
  margin: 8px 0 24px;
  color: #1a1a1a;
}

.payment-vendor {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  margin-bottom: 32px;
  font-weight: 600;
  font-size: 16px;
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
  width: 200px;
  height: 200px;
  margin: 0 auto 32px;
  background: #f5f5f5;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.qr-placeholder {
  text-align: center;
}

.qr-placeholder p {
  margin-top: 12px;
  font-size: 13px;
  color: #8c8c8c;
}

.ota-confirm-btn-large { height: 56px; font-size: 20px; font-weight: 800; border-radius: 14px; margin-top: 8px; box-shadow: 0 6px 20px rgba(0, 140, 255, 0.25); }
.trust-badges { display: flex; justify-content: center; gap: 20px; margin-top: 24px; border-top: 1px solid #f0f0f0; padding-top: 20px; }
.badge-item { display: flex; align-items: center; gap: 6px; font-size: 12px; color: #52c41a; font-weight: 600; }
.payment-item-box { width: 100%; border: 1px solid #f0f0f0; border-radius: 12px; padding: 16px; transition: all 0.2s; margin: 0 !important; display: flex !important; align-items: center; }
.payment-item-box:hover { border-color: #008cff; background: #f8faff; }
.ant-radio-wrapper-checked.payment-item-box { border-color: #008cff; background: #e6f7ff; }
.payment-item-content { display: flex; align-items: center; gap: 16px; margin-left: 8px; }
.pay-icon { font-size: 24px; color: #008cff; }
.pay-icon.wechat { color: #07c160; }
.pay-icon.alipay { color: #1677ff; }
.pay-info { display: flex; flex-direction: column; }
.pay-name { font-size: 15px; font-weight: 700; color: #1a1a1a; }
.pay-desc { font-size: 12px; color: #8c8c8c; }
.online-payment-hint { text-align: center; margin-top: 16px; font-size: 13px; color: #1890ff; background: #e6f7ff; padding: 10px; border-radius: 8px; border: 1px solid #91d5ff; }
.front-desk-payment-hint { text-align: center; margin-top: 16px; font-size: 13px; color: #faad14; background: #fffbe6; padding: 10px; border-radius: 8px; border: 1px solid #ffe58f; }
.security-tip { text-align: center; margin-top: 12px; font-size: 12px; color: #8c8c8c; }
.points-redemption { padding: 8px 0; }
.points-info { margin-bottom: 12px; font-size: 14px; }
.points-count { font-weight: 700; color: #faad14; }
.points-rule { color: #8c8c8c; font-size: 12px; }
.points-action { display: flex; align-items: center; }
.points-result { margin-top: 12px; padding-top: 12px; border-top: 1px dashed #f0f0f0; font-size: 14px; color: #8c8c8c; }
.discount-val { color: #ff4d4f; font-weight: 700; margin-left: 4px; }
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
