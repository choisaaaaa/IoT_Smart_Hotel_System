<template>
  <div class="profile-page-container" :class="'theme-' + (memberInfo.member_level || 'standard')">
    <!-- 顶部状态栏 -->
    <input
      type="file"
      ref="avatarInput"
      style="display: none"
      accept="image/*"
      @change="onAvatarChange"
    />
    <div class="profile-content" :class="{ 'no-member': !isCustomer }">
      <!-- 左侧：会员卡与资产概览 -->
      <div class="profile-left" v-if="isCustomer">
        <div class="member-card-new" :class="`card-level-${memberInfo.member_level || 'standard'}`">
          <div class="card-inner">
            <div class="card-top">
              <div class="hotel-info">
                <div class="hotel-logo">{{ memberProgramName }}</div>
                <div class="hotel-brand">SMART HOTEL</div>
              </div>
              <div class="member-badge-new" :class="`badge-level-${memberInfo.member_level || 'standard'}`">
                <span class="level-text">{{ memberLevelInfo.label }}</span>
              </div>
            </div>

            <div class="user-info-section">
              <div class="user-name-row">
                <div class="user-avatar-wrapper" @click="handleAvatarClick">
                  <a-avatar :size="64" :src="appStore.resolveImageUrl(userInfo.avatar)" class="premium-avatar">
                    <template #icon><UserOutlined /></template>
                  </a-avatar>
                  <div class="avatar-edit-overlay">
                    <CameraOutlined />
                  </div>
                </div>
                <div class="user-main-info">
                  <h2 class="user-name">{{ userInfo.username }}</h2>
                  <div class="user-phone-row">{{ userInfo.phone }}</div>
                </div>
                <div class="checkin-btn-wrapper">
                  <a-button
                    v-if="!hasCheckedInToday"
                    type="primary"
                    shape="round"
                    class="premium-checkin-btn"
                    @click="handleCheckin"
                    :loading="checkinLoading"
                  >
                    每日签到
                  </a-button>
                  <div v-else class="checkin-done">
                    <CheckCircleFilled /> 今日已签到
                  </div>
                </div>
              </div>
            </div>

            <div class="card-bottom">
              <div class="exp-container">
                <div class="exp-header">
                  <span>成长值 {{ memberInfo.experience || 0 }} / {{ memberLevelInfo.nextExp }}</span>
                  <span class="points-badge">积分 {{ memberInfo.points || 0 }}</span>
                </div>
                <div class="exp-progress-new">
                  <div class="exp-fill" :style="{ width: `${memberLevelInfo.percent}%` }"></div>
                </div>
              </div>
            </div>
          </div>
          <div class="card-bg-pattern"></div>
        </div>

        <div class="stats-card-modern">
          <div class="stats-header-modern">我的资产</div>
          <div class="asset-grid-modern">
            <div class="asset-item-modern" @click="activeTab = 'coupons'">
              <div class="asset-icon-bg"><TagFilled /></div>
              <div class="asset-info-modern">
                <div class="asset-num">{{ memberInfo.coupons_count || 0 }}<span class="unit">张</span></div>
                <div class="asset-name">优惠券</div>
              </div>
            </div>
            <div class="asset-item-modern">
              <div class="asset-icon-bg"><ThunderboltFilled /></div>
              <div class="asset-info-modern">
                <div class="asset-num">{{ memberInfo.points || 0 }}</div>
                <div class="asset-name">积分</div>
              </div>
            </div>
            <div class="asset-item-modern">
              <div class="asset-icon-bg"><WalletFilled /></div>
              <div class="asset-info-modern">
                <div class="asset-num"><span class="currency">¥</span>{{ memberInfo.balance || '0.00' }}</div>
                <div class="asset-name">余额</div>
              </div>
            </div>
            <div class="asset-item-modern">
              <div class="asset-icon-bg"><HomeFilled /></div>
              <div class="asset-info-modern">
                <div class="asset-num">{{ memberInfo.total_stays || 0 }}<span class="unit">次</span></div>
                <div class="asset-name">累计入住</div>
              </div>
            </div>
          </div>
        </div>

        <a-card class="rights-card-modern" :bordered="false">
          <template #title>
            <div class="rights-header">
              <span class="rights-title-text">会员权益</span>
              <span class="rights-subtitle">{{ memberLevelInfo.label }}尊享</span>
            </div>
          </template>
          <div class="rights-grid-modern">
            <div class="right-box" :class="{ disabled: memberLevelInfo.discount === 1 }">
              <div class="right-icon-wrapper"><PercentageOutlined /></div>
              <div class="right-content">
                <div class="right-title">预订折扣</div>
                <div class="right-value">{{ memberLevelInfo.discount * 10 }}折起</div>
              </div>
            </div>
            <div class="right-box" :class="{ disabled: memberLevelInfo.multiplier === 1 }">
              <div class="right-icon-wrapper"><ThunderboltOutlined /></div>
              <div class="right-content">
                <div class="right-title">积分倍率</div>
                <div class="right-value">{{ memberLevelInfo.multiplier }}倍积分</div>
              </div>
            </div>
          </div>
        </a-card>
      </div>

      <!-- 右侧：个人资料与常用入住人 -->
      <div class="profile-right" :style="!isCustomer ? { width: '100%' } : {}">
        <a-tabs v-model:activeKey="activeTab" class="profile-tabs">
          <!-- 账号管理 -->
          <a-tab-pane key="account" tab="账号管理">
            <div class="account-info-list">
              <!-- 头像 (非普通用户显示在列表中) -->
              <div class="info-item" v-if="!isCustomer">
                <div class="info-label">个人头像</div>
                <div class="info-content">
                  <div class="display-row">
                    <a-avatar :size="64" :src="appStore.resolveImageUrl(userInfo.avatar)" @click="handleAvatarClick" style="cursor: pointer">
                      <template #icon><UserOutlined /></template>
                    </a-avatar>
                    <a-button type="link" class="edit-link" @click="handleAvatarClick">修改头像</a-button>
                  </div>
                </div>
              </div>

              <!-- 用户ID (不可修改) -->
              <div class="info-item">
                <div class="info-label">用户ID</div>
                <div class="info-content">
                  <span class="info-value">{{ userInfo.uid || userInfo.id }}</span>
                  <span class="info-tip">系统唯一标识，不可修改</span>
                </div>
              </div>

              <!-- 昵称 -->
              <div class="info-item">
                <div class="info-label">我的昵称</div>
                <div class="info-content">
                  <div v-if="editingField !== 'username'" class="display-row">
                    <span class="info-value">{{ userInfo.username }}</span>
                    <a-button type="link" class="edit-link" @click="startEdit('username')">修改</a-button>
                  </div>
                  <div v-else class="edit-row">
                    <a-input v-model:value="profileForm.username" placeholder="设置一个喜欢的昵称" class="edit-input" />
                    <div class="edit-actions">
                      <a-button type="primary" size="small" :loading="saving" @click="handleUpdateProfile">保存</a-button>
                      <a-button size="small" @click="cancelEdit">取消</a-button>
                    </div>
                  </div>
                </div>
              </div>

              <!-- 手机号 -->
              <div class="info-item">
                <div class="info-label">手机号码</div>
                <div class="info-content">
                  <div v-if="editingField !== 'phone'" class="display-row">
                    <span class="info-value">{{ userInfo.phone }}</span>
                    <a-button type="link" class="edit-link" @click="startEdit('phone')">更换手机号</a-button>
                  </div>
                  <div v-else class="edit-row-vertical">
                    <div class="phone-input-group">
                      <a-input v-model:value="profileForm.phone" placeholder="请输入新手机号" />
                      <a-button
                        :disabled="countdown > 0 || !profileForm.phone"
                        @click="handleSendCode"
                        class="send-code-btn"
                      >
                        {{ countdown > 0 ? `${countdown}s` : '获取验证码' }}
                      </a-button>
                    </div>
                    <a-input
                      v-model:value="profileForm.code"
                      placeholder="请输入验证码"
                      class="mt-2"
                    />
                    <div class="edit-actions mt-2">
                      <a-button type="primary" size="small" :loading="saving" @click="handleUpdateProfile">确认更换</a-button>
                      <a-button size="small" @click="cancelEdit">取消</a-button>
                    </div>
                  </div>
                  <span class="info-tip">手机号为登录凭证，请谨慎修改</span>
                </div>
              </div>

              <!-- 电子邮箱 -->
              <div class="info-item">
                <div class="info-label">电子邮箱</div>
                <div class="info-content">
                  <div v-if="editingField !== 'email'" class="display-row">
                    <span class="info-value">{{ userInfo.email || '未绑定' }}</span>
                    <a-button type="link" class="edit-link" @click="startEdit('email')">修改</a-button>
                  </div>
                  <div v-else class="edit-row">
                    <a-input v-model:value="profileForm.email" placeholder="绑定邮箱以接收订单通知" class="edit-input" />
                    <div class="edit-actions">
                      <a-button type="primary" size="small" :loading="saving" @click="handleUpdateProfile">保存</a-button>
                      <a-button size="small" @click="cancelEdit">取消</a-button>
                    </div>
                  </div>
                  <span class="info-tip">绑定邮箱以接收订单通知</span>
                </div>
              </div>

              <!-- 登录密码 -->
              <div class="info-item">
                <div class="info-label">登录密码</div>
                <div class="info-content">
                  <div v-if="editingField !== 'password'" class="display-row">
                    <span class="info-value">••••••••</span>
                    <a-button type="link" class="edit-link" @click="startEdit('password')">修改密码</a-button>
                  </div>
                  <div v-else class="edit-row-vertical">
                    <a-input-password v-model:value="profileForm.oldPassword" placeholder="请输入原密码" />
                    <a-input-password v-model:value="profileForm.newPassword" placeholder="请输入新密码" class="mt-2" />
                    <a-input-password v-model:value="profileForm.confirmPassword" placeholder="请再次输入新密码" class="mt-2" />
                    <div class="edit-actions mt-2">
                      <a-button type="primary" size="small" :loading="saving" @click="handleUpdatePassword">确认修改</a-button>
                      <a-button size="small" @click="cancelEdit">取消</a-button>
                    </div>
                  </div>
                  <span class="info-tip">建议定期更换密码以保障账号安全</span>
                </div>
              </div>
            </div>
          </a-tab-pane>

          <!-- 优惠券 -->
          <a-tab-pane key="coupons" v-if="isCustomer">
            <template #tab>
              <span><TagOutlined /> 优惠券</span>
            </template>
            <div class="coupons-section">
              <!-- 导入券码 -->
              <div class="coupon-import-bar">
                <a-input-search
                  v-model:value="couponCodeInput"
                  placeholder="请输入优惠券兑换码"
                  enter-button="导入券码"
                  size="large"
                  :loading="importLoading"
                  @search="handleImportCoupon"
                />
              </div>

              <div v-if="myCoupons.length === 0" class="empty-state">
                <a-empty description="暂无可用优惠券" />
              </div>
              <div v-else class="coupons-grid">
                <div v-for="coupon in myCoupons" :key="coupon.id" class="coupon-card">
                  <div class="coupon-left">
                    <div class="coupon-value">
                      <span v-if="coupon.coupon_type === 'discount'" class="val">{{ Number(coupon.discount_value) }}折</span>
                      <span v-else class="val"><span class="unit">¥</span>{{ coupon.discount_value }}</span>
                    </div>
                    <div class="coupon-condition">满{{ coupon.min_amount }}可用</div>
                  </div>
                  <div class="coupon-right">
                    <div class="coupon-name">{{ coupon.coupon_name }}</div>
                    <div class="coupon-date">有效期至 {{ formatDate(coupon.valid_to) }}</div>
                    <a-button type="primary" size="small" shape="round" @click="$router.push('/guest/booking')">去使用</a-button>
                  </div>
                </div>
              </div>
            </div>
          </a-tab-pane>

          <!-- 常用入住人管理 -->
          <a-tab-pane key="guests" tab="常用入住人" v-if="isCustomer">
            <div class="frequent-guests-section">
              <div class="section-header">
                <p>管理您的实名入住人信息，预订时可一键导入。</p>
                <a-button type="primary" ghost @click="handleAddFrequentGuest">
                  <PlusOutlined /> 添加联系人
                </a-button>
              </div>

              <a-list
                :data-source="frequentGuests"
                :loading="guestsLoading"
                class="guests-list"
              >
                <template #renderItem="{ item }">
                  <a-list-item>
                    <a-list-item-meta>
                      <template #title>
                        <span class="guest-name">{{ item.name }}</span>
                        <a-tag v-if="item.phone === userInfo.phone" color="blue" class="self-tag">本人</a-tag>
                      </template>
                      <template #description>
                        <div class="guest-desc">
                          <span><PhoneOutlined /> {{ item.phone }}</span>
                          <span><IdcardOutlined /> {{ getIdTypeLabel(item.id_type) }}: {{ maskId(item.id_number) }}</span>
                        </div>
                      </template>
                    </a-list-item-meta>
                    <template #actions>
                      <a @click="handleEditFrequentGuest(item)">编辑</a>
                      <a-popconfirm
                        title="确定删除该联系人吗？"
                        @confirm="handleDeleteFrequentGuest(item.id)"
                      >
                        <a class="text-danger">删除</a>
                      </a-popconfirm>
                    </template>
                  </a-list-item>
                </template>
              </a-list>
            </div>
          </a-tab-pane>

          <!-- 我的钱包 -->
          <a-tab-pane key="wallet" tab="我的钱包" v-if="isCustomer">
            <div class="wallet-card-ctrip">
              <div class="wallet-header">
                <h3>账户余额</h3>
                <a-tag color="blue">实时到账</a-tag>
              </div>

              <div class="balance-display-large">
                <div class="lab">当前可用余额</div>
                <div class="val">
                  <span class="currency">¥</span>
                  <span class="num">{{ memberInfo?.balance || '0.00' }}</span>
                </div>
              </div>

              <div class="recharge-section">
                <div class="stats-header-modern" style="margin-bottom: 24px;">快捷充值</div>
                <div class="recharge-grid">
                  <div 
                    v-for="amount in rechargeOptions" 
                    :key="amount" 
                    class="recharge-item"
                    :class="{ active: selectedRechargeAmount === amount }"
                    @click="selectedRechargeAmount = amount"
                  >
                    <span class="amount-text">¥{{ amount }}</span>
                    <span v-if="getBonusAmount(amount) > 0" class="bonus-tag">
                      赠 ¥{{ getBonusAmount(amount) }}
                    </span>
                    <span v-if="getBonusAmount(amount) > 0" class="bonus-tip">
                      立享 {{ ((1 - discountRate) * 100).toFixed(0) }}% 优惠
                    </span>
                  </div>
                </div>

                <div class="recharge-btn-container">
                  <a-button 
                    type="primary" 
                    block 
                    class="recharge-btn-large" 
                    :disabled="!selectedRechargeAmount"
                    @click="handleOpenRechargePayment"
                  >
                    立即充值 {{ selectedRechargeAmount ? `¥${selectedRechargeAmount}` : '' }}
                  </a-button>
                </div>

                <div class="bonus-explain">
                  <InfoCircleOutlined class="icon" />
                  <div class="text">
                    <strong>充值说明：</strong><br/>
                    您的当前等级为 <strong>{{ memberLevelInfo.label }}</strong>，充值立享 <strong>{{ ((1 - memberLevelInfo.discount) * 100).toFixed(0) }}%</strong> 额度赠送（等同于您的房价折扣力度）。充值后的余额可用于预订房费支付，享受折上折，余额永不过期。
                  </div>
                </div>
              </div>
            </div>
          </a-tab-pane>
        </a-tabs>
      </div>
    </div>

    <!-- Recharge Payment Modal -->
    <a-modal
      v-model:open="rechargeModalVisible"
      title="收银台"
      :footer="null"
      width="440px"
      :closable="false"
    >
      <div class="mock-payment-recharge">
        <div class="payment-title">应付金额</div>
        <div class="amount-box">
          <div class="lab">充值金额</div>
          <div class="val">¥{{ selectedRechargeAmount }}</div>
        </div>
        
        <div class="stats-header-modern" style="margin-bottom: 16px;">选择支付方式</div>
        <div class="payment-vendor-recharge">
          <div 
            class="vendor-item" 
            :class="{ active: rechargeVendor === 'wechat', 'wechat-active': rechargeVendor === 'wechat' }"
            @click="rechargeVendor = 'wechat'"
          >
            <div class="icon-wrapper wechat-color">
              <WechatOutlined style="font-size: 28px" />
            </div>
            <div class="name">微信支付</div>
          </div>
          
          <div 
            class="vendor-item" 
            :class="{ active: rechargeVendor === 'alipay', 'alipay-active': rechargeVendor === 'alipay' }"
            @click="rechargeVendor = 'alipay'"
          >
            <div class="icon-wrapper alipay-color">
              <AlipayCircleOutlined style="font-size: 28px" />
            </div>
            <div class="name">支付宝</div>
          </div>
        </div>

        <div class="payment-qr-mock">
          <div class="qr-placeholder">
            <QrcodeOutlined style="font-size: 56px; color: #1a1a1a" />
            <p>请使用{{ rechargeVendor === 'wechat' ? '微信' : '支付宝' }}扫码支付</p>
          </div>
        </div>

        <a-button type="primary" block size="large" :loading="rechargeLoading" @click="confirmRecharge">
          我已完成支付
        </a-button>
        <a-button block style="margin-top: 12px" @click="rechargeModalVisible = false">
          取消
        </a-button>
      </div>
    </a-modal>

    <!-- 添加/编辑联系人弹窗 -->
    <a-modal
      v-model:open="showGuestEditModal"
      :title="guestEditForm.id ? '编辑入住人' : '添加入住人'"
      @ok="handleSaveFrequentGuest"
      :confirmLoading="guestSaveLoading"
      okText="确认"
      cancelText="取消"
    >
      <a-form layout="vertical" class="mt-4">
        <a-form-item label="真实姓名" required>
          <a-input v-model:value="guestEditForm.name" placeholder="请填写真实姓名" />
        </a-form-item>
        <a-form-item label="手机号码" required>
          <a-input v-model:value="guestEditForm.phone" placeholder="请输入11位手机号" />
        </a-form-item>
        <a-form-item label="证件类型" required>
          <a-select v-model:value="guestEditForm.id_type">
            <a-select-option value="idcard">中国居民身份证/外国人永久居留身份证/港澳台居民居住证</a-select-option>
            <a-select-option value="hkm_pass">港澳居民来往内地通行证</a-select-option>
            <a-select-option value="taiwan_pass">台湾居民来往大陆通行证</a-select-option>
            <a-select-option value="passport">外国护照</a-select-option>
            <a-select-option value="other">其他</a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item label="证件号码" required>
          <a-input v-model:value="guestEditForm.id_number" placeholder="请输入证件号" />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { message } from 'ant-design-vue'
import {
  PlusOutlined,
  PhoneOutlined,
  IdcardOutlined,
  TeamOutlined,
  UserOutlined,
  TagOutlined,
  ThunderboltOutlined,
  CoffeeOutlined,
  CheckCircleFilled,
  TagFilled,
  ThunderboltFilled,
  WalletFilled,
  HomeFilled,
  PercentageOutlined,
  CameraOutlined,
  WechatOutlined,
  AlipayCircleOutlined,
  QrcodeOutlined
} from '@ant-design/icons-vue'
import { useAppStore } from '@/stores/app'
import { userApi } from '@/api/user'
import request from '@/api/request'
import { getImageUrl } from '@/utils/url'
import { systemConfigApi } from '@/api/system-config'
import guestService, { FrequentGuest } from '@/api/frequent-guest'
import { formatDate } from '@/utils/date'

const router = useRouter()
const appStore = useAppStore()
const userInfo = computed(() => appStore.userInfo || {})
const isCustomer = computed(() => {
  const role = appStore.userInfo?.role
  return role === 'customer' || role === 'user' || !role
})
const avatarInput = ref<HTMLInputElement | null>(null)
const activeTab = ref('account')
const editingField = ref<string | null>(null)
const rechargeOptions = [100, 300, 500, 1000, 2000, 5000]
const selectedRechargeAmount = ref<number | null>(null)
const rechargeModalVisible = ref(false)
const rechargeVendor = ref('wechat')
const rechargeLoading = ref(false)

const handleOpenRechargePayment = () => {
  rechargeModalVisible.value = true
}

const confirmRecharge = async () => {
  if (!selectedRechargeAmount.value) return
  
  rechargeLoading.value = true
  try {
    const res = await request.post('/members/recharge', {
      amount: selectedRechargeAmount.value
    })
    message.success(`充值成功！实际到账 ¥${res.data.credit_amount}`)
    rechargeModalVisible.value = false
    fetchData() // 刷新余额
  } catch (error) {
    message.error('充值失败，请稍后重试')
  } finally {
    rechargeLoading.value = false
  }
}

// 头像上传
const handleAvatarClick = () => {
  avatarInput.value?.click()
}

const onAvatarChange = async (e: Event) => {
  const target = e.target as HTMLInputElement
  const file = target.files?.[0]
  if (!file) return

  // 校验文件类型和大小
  if (!file.type.startsWith('image/')) {
    return message.error('请选择图片文件')
  }
  if (file.size > 2 * 1024 * 1024) {
    return message.error('图片大小不能超过 2MB')
  }

  const formData = new FormData()
  formData.append('image', file)

  try {
    loading.value = true
    // 1. 上传图片到服务器
    const uploadRes = await request.post('/upload/image', formData, {
      headers: { 'Content-Type': 'multipart/form-data' }
    })
    const imageUrl = uploadRes.data.url

    // 2. 更新用户资料
    await userApi.updateProfile({ avatar: imageUrl })

    // 3. 更新全局状态
    appStore.setUserInfo({
      ...appStore.userInfo,
      avatar: imageUrl
    })

    message.success('头像更新成功')
  } catch (error) {
    console.error('更新头像失败:', error)
    message.error('头像更新失败')
  } finally {
    loading.value = false
    // 重置 input，允许再次选择同一张图片
    target.value = ''
  }
}

// 会员等级逻辑 - 优先使用后端返回的数据，同时监听系统配置变化
const memberLevelInfo = computed(() => {
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

const discountRate = computed(() => {
  return memberLevelInfo.value.discount
})

const getBonusAmount = (amount: number) => {
  if (discountRate.value >= 1) return 0
  const bonusRate = 1 - discountRate.value
  return Math.floor((amount * bonusRate) * 100) / 100
}

// 会员与资产信息
const memberInfo = ref<any>({})
const memberProgramName = computed(() => appStore.systemConfigs.member_program_name || 'IOT')
const loading = ref(false)
const myCoupons = ref<any[]>([])
const checkinLoading = ref(false)
const couponCodeInput = ref('')
const importLoading = ref(false)

const handleImportCoupon = async () => {
  if (!couponCodeInput.value.trim()) return message.warning('请输入券码')

  try {
    importLoading.value = true
    await request.post('/coupons/import', { coupon_code: couponCodeInput.value.trim() })
    message.success('优惠券导入成功！')
    couponCodeInput.value = ''
    fetchData() // 刷新列表
  } catch (error: any) {
    // 错误已由拦截器处理
  } finally {
    importLoading.value = false
  }
}

const hasCheckedInToday = computed(() => {
  if (!memberInfo.value.last_checkin_date) return false
  const today = formatDate(new Date())
  const lastDate = formatDate(memberInfo.value.last_checkin_date)
  return today === lastDate
})

const handleCheckin = async () => {
  try {
    checkinLoading.value = true
    const res = await request.post('/members/checkin')
    if (res.data.already_checked_in) {
      message.info('今日已签到')
    } else {
      message.success(`签到成功！获得 ${res.data.experience} 成长值`)
      // 刷新数据
      fetchData()
    }
  } catch (error) {
    console.error('签到失败:', error)
  } finally {
    checkinLoading.value = false
  }
}

// 账号编辑
const saving = ref(false)
const profileForm = reactive({
  username: '',
  phone: '',
  email: '',
  code: '',
  oldPassword: '',
  newPassword: '',
  confirmPassword: ''
})

const startEdit = (field: string) => {
  editingField.value = field
  profileForm.username = userInfo.value.username
  profileForm.phone = userInfo.value.phone
  profileForm.email = userInfo.value.email || ''
  profileForm.code = ''
  profileForm.oldPassword = ''
  profileForm.newPassword = ''
  profileForm.confirmPassword = ''
}

const cancelEdit = () => {
  editingField.value = null
  profileForm.code = ''
  profileForm.oldPassword = ''
  profileForm.newPassword = ''
  profileForm.confirmPassword = ''
}

// 验证码倒计时
const countdown = ref(0)
const isPhoneChanged = computed(() => {
  return profileForm.phone !== appStore.userInfo?.phone
})

const handleSendCode = async () => {
  if (!/^1[3-9]\d{9}$/.test(profileForm.phone)) {
    return message.warning('请输入正确的手机号')
  }

  try {
    await userApi.sendCode(profileForm.phone)
    message.success('验证码已发送 (模拟)')
    countdown.value = 60
    const timer = setInterval(() => {
      countdown.value--
      if (countdown.value <= 0) clearInterval(timer)
    }, 1000)
  } catch (error) {
    console.error('发送验证码失败:', error)
  }
}

// 常用入住人
const frequentGuests = ref<FrequentGuest[]>([])
const guestsLoading = ref(false)
const showGuestEditModal = ref(false)
const guestSaveLoading = ref(false)
const guestEditForm = reactive<FrequentGuest>({
  name: '',
  phone: '',
  id_type: 'idcard',
  id_number: ''
})

// 脱敏证件号
const maskId = (id: string) => {
  if (!id) return ''
  if (id.length <= 8) return id
  return `${id.substring(0, 4)} **** ${id.substring(id.length - 4)}`
}

// 获取证件类型标签
const getIdTypeLabel = (type: string) => {
  const labels: Record<string, string> = {
    idcard: '身份证/永居证/居住证',
    hkm_pass: '港澳居民来往内地通行证',
    taiwan_pass: '台湾居民来往大陆通行证',
    passport: '护照',
    other: '其他'
  }
  return labels[type] || type
}

// 初始化数据
const fetchData = async () => {
  if (!appStore.userInfo) {
    message.warning('请先登录')
    appStore.showLoginModal = true
    router.push('/guest/booking')
    return
  }

  try {
    loading.value = true
    
    // 基础个人资料表单初始化 (始终执行)
    profileForm.username = appStore.userInfo.username
    profileForm.phone = appStore.userInfo.phone
    profileForm.email = appStore.userInfo.email || ''

    // 仅普通用户需要获取会员资产、优惠券和常用入住人
    if (isCustomer.value) {
      try {
        const res = await request.get('/members/me')
        memberInfo.value = res.data
      } catch (e) {
        console.error('获取会员资产信息失败:', e)
      }

      try {
        const couponRes = await request.get('/coupons/me')
        myCoupons.value = couponRes.data || []
      } catch (e) {
        console.error('获取我的优惠券失败:', e)
      }

      fetchFrequentGuests()
    }
  } catch (error) {
    console.error('获取个人信息失败:', error)
  } finally {
    loading.value = false
  }
}

const fetchFrequentGuests = async () => {
  try {
    guestsLoading.value = true
    const res = await guestService.list()
    frequentGuests.value = res.data.guests
  } catch (error) {
    console.error('获取联系人失败:', error)
  } finally {
    guestsLoading.value = false
  }
}

// 更新个人资料
const handleUpdateProfile = async () => {
  if (editingField.value === 'username' && !profileForm.username) return message.warning('昵称不能为空')
  if (editingField.value === 'phone' && (!profileForm.phone || !profileForm.code)) {
    return message.warning('请填写新手机号和验证码')
  }

  try {
    saving.value = true
    const updateData: any = {}
    if (editingField.value === 'username') updateData.username = profileForm.username
    if (editingField.value === 'email') updateData.email = profileForm.email
    if (editingField.value === 'phone') {
      updateData.phone = profileForm.phone
      updateData.code = profileForm.code
    }

    const res: any = await userApi.updateProfile(updateData)

    if (res.data?.user) {
      appStore.setUserInfo({
        ...appStore.userInfo,
        ...res.data.user
      })
      message.success('更新成功')
      editingField.value = null
      profileForm.code = ''
    }
  } catch (error) {
    console.error('更新失败:', error)
  } finally {
    saving.value = false
  }
}

const handleUpdatePassword = async () => {
  if (!profileForm.oldPassword || !profileForm.newPassword) return message.warning('请输入完整密码信息')
  if (profileForm.newPassword !== profileForm.confirmPassword) return message.warning('两次输入的新密码不一致')
  if (profileForm.newPassword.length < 6) return message.warning('新密码长度不能少于6位')

  try {
    saving.value = true
    await userApi.updatePassword(appStore.userInfo.id, {
      oldPassword: profileForm.oldPassword,
      newPassword: profileForm.newPassword
    })
    message.success('密码修改成功，请下次使用新密码登录')
    editingField.value = null
  } catch (error) {
    console.error('修改密码失败:', error)
  } finally {
    saving.value = false
  }
}

// 常用入住人操作
const handleAddFrequentGuest = () => {
  Object.assign(guestEditForm, {
    id: undefined,
    name: '',
    phone: '',
    id_type: 'idcard',
    id_number: ''
  })
  showGuestEditModal.value = true
}

const handleEditFrequentGuest = (guest: FrequentGuest) => {
  Object.assign(guestEditForm, { ...guest })
  showGuestEditModal.value = true
}

const handleSaveFrequentGuest = async () => {
  if (!guestEditForm.name || !guestEditForm.phone || !guestEditForm.id_number) {
    return message.warning('请填写完整信息')
  }

  try {
    guestSaveLoading.value = true
    if (guestEditForm.id) {
      await guestService.update(guestEditForm.id, guestEditForm)
      message.success('更新成功')
    } else {
      await guestService.create(guestEditForm)
      message.success('添加成功')
    }
    showGuestEditModal.value = false
    fetchFrequentGuests()
  } catch (error) {
    message.error('操作失败')
  } finally {
    guestSaveLoading.value = false
  }
}

const handleDeleteFrequentGuest = async (id: number) => {
  try {
    await guestService.remove(id)
    message.success('已删除')
    fetchFrequentGuests()
  } catch (error) {
    message.error('删除失败')
  }
}

onMounted(() => {
  fetchData()
})
</script>

<style scoped>
/* ==================== 会员等级主题色变量 ==================== */
.profile-page-container.theme-standard { --level-color: #4b6cb7; --level-bg: rgba(75, 108, 183, 0.08); --level-glow: rgba(75, 108, 183, 0.3); }
.profile-page-container.theme-silver { --level-color: #90a4ae; --level-bg: rgba(144, 164, 174, 0.08); --level-glow: rgba(144, 164, 174, 0.3); }
.profile-page-container.theme-gold { --level-color: var(--hotel-gold); --level-bg: rgba(201, 169, 98, 0.08); --level-glow: rgba(201, 169, 98, 0.3); }
.profile-page-container.theme-platinum { --level-color: #535c68; --level-bg: rgba(83, 92, 104, 0.08); --level-glow: rgba(83, 92, 104, 0.3); }
.profile-page-container.theme-diamond { --level-color: #30cfd0; --level-bg: rgba(48, 207, 208, 0.08); --level-glow: rgba(48, 207, 208, 0.3); }

.profile-page-container {
  padding: 48px 32px;
  max-width: 100%;
  margin: 0 auto;
  min-height: calc(100vh - 120px);
  background: linear-gradient(135deg, var(--hotel-bg) 0%, #f0f4f8 100%);
}

.profile-content {
  display: grid;
  grid-template-columns: 460px 1fr;
  gap: 48px;
  max-width: 1500px;
  margin: 0 auto;
}

.profile-content.no-member {
  display: block;
  max-width: 850px;
  margin: 0 auto;
}

/* ==================== 统一配色适配 ==================== */
.stats-header-modern::before { background: var(--level-color) !important; }
.asset-icon-bg { background: var(--level-bg) !important; color: var(--level-color) !important; }
.balance-display-large { background: var(--level-bg) !important; border-color: var(--level-color) !important; }
.recharge-item.active { border-color: var(--level-color) !important; background: var(--level-bg) !important; box-shadow: 0 0 20px var(--level-glow) !important; }
.recharge-btn-large { background: var(--level-color) !important; border-color: var(--level-color) !important; }
.bonus-explain { background: var(--level-bg) !important; border-color: var(--level-color) !important; }
.bonus-explain .icon, .bonus-explain strong { color: var(--level-color) !important; }
.rights-subtitle { color: var(--level-color) !important; background: var(--level-bg) !important; border-color: var(--level-color) !important; }
.right-box.active, .right-box:not(.disabled) { background: var(--level-bg) !important; border-color: var(--level-color) !important; }
.right-icon-wrapper { color: var(--level-color) !important; }
.right-value { color: var(--level-color) !important; }
.profile-tabs :deep(.ant-tabs-tab-active .ant-tabs-tab-btn) { color: var(--level-color) !important; }
.profile-tabs :deep(.ant-tabs-ink-bar) { background: var(--level-color) !important; }
.edit-link { color: var(--level-color) !important; }
.guest-card-modern:hover { border-color: var(--level-color) !important; }
.guest-card-body .info-row .icon { color: var(--level-color) !important; }

/* ==================== 新版会员卡样式 - 炫酷玻璃态 ==================== */
.member-card-new {
  height: 280px;
  border-radius: var(--hotel-radius-2xl);
  position: relative;
  overflow: hidden;
  color: #fff;
  padding: 36px;
  box-shadow: 
    0 25px 60px rgba(0, 0, 0, 0.25),
    0 0 0 1px rgba(255, 255, 255, 0.1) inset;
  margin-bottom: 36px;
  transition: all 0.5s cubic-bezier(0.4, 0, 0.2, 1);
}

.member-card-new:hover {
  transform: translateY(-8px) scale(1.02);
  box-shadow: 
    0 35px 70px rgba(0, 0, 0, 0.3),
    0 0 0 1px rgba(255, 255, 255, 0.15) inset;
}

/* 等级配色方案 */
.card-level-standard { 
  background: linear-gradient(135deg, #4b6cb7 0%, #182848 100%);
}
.card-level-silver { 
  background: linear-gradient(135deg, #bdc3c7 0%, #2c3e50 100%);
}
.card-level-gold { 
  background: linear-gradient(135deg, #d4af37 0%, #1a1a1a 100%);
}
.card-level-platinum { 
  background: linear-gradient(135deg, #e5e4e2 0%, #434343 100%);
}
.card-level-diamond { 
  background: linear-gradient(135deg, #30cfd0 0%, #330867 100%);
}

.card-inner {
  position: relative;
  z-index: 2;
  height: 100%;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
}

.card-top {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
}

.hotel-info {
  display: flex;
  flex-direction: column;
}

.hotel-logo {
  font-family: 'Playfair Display', 'Optima', 'Palatino', serif;
  font-size: 32px;
  font-weight: 900;
  letter-spacing: 4px;
  line-height: 1;
  text-transform: uppercase;
  background: linear-gradient(135deg, #fff, #f9e29c);
  background-clip: text;
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  animation: textGlow 3s ease-in-out infinite;
}

@keyframes textGlow {
  0%, 100% { filter: drop-shadow(0 0 2px rgba(255, 255, 255, 0.3)); }
  50% { filter: drop-shadow(0 0 8px rgba(255, 255, 255, 0.5)); }
}

.hotel-brand {
  font-size: 11px;
  letter-spacing: 4px;
  opacity: 0.6;
  margin-top: 8px;
}

.member-badge-new {
  padding: 10px 22px;
  border-radius: 16px;
  transition: all 0.3s ease;
  position: relative;
  overflow: hidden;
}

.member-badge-new::before {
  content: '';
  position: absolute;
  top: 0;
  left: -100%;
  width: 100%;
  height: 100%;
  background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
  animation: badgeShine 3s ease-in-out infinite;
}

@keyframes badgeShine {
  0%, 100% { left: -100%; }
  50% { left: 100%; }
}

/* 勋章颜色方案 */
.badge-level-standard {
  background: linear-gradient(90deg, #4b6cb7, #182848);
  box-shadow: 0 6px 20px rgba(75, 108, 183, 0.4);
}
.badge-level-standard .level-text { color: #fff; }

.badge-level-silver {
  background: linear-gradient(90deg, #bdc3c7, #2c3e50);
  box-shadow: 0 6px 20px rgba(189, 195, 199, 0.4);
}
.badge-level-silver .level-text { color: #fff; }

.badge-level-gold {
  background: linear-gradient(90deg, #d4af37, #f9e29c);
  box-shadow: 0 6px 20px rgba(212, 175, 55, 0.4);
}
.badge-level-gold .level-text { color: #1a1a1a; }

.badge-level-platinum {
  background: linear-gradient(90deg, #e5e4e2, #434343);
  box-shadow: 0 6px 20px rgba(229, 228, 226, 0.4);
}
.badge-level-platinum .level-text { color: #1a1a1a; }

.badge-level-diamond {
  background: linear-gradient(90deg, #30cfd0, #330867);
  box-shadow: 0 6px 20px rgba(48, 207, 208, 0.4);
}
.badge-level-diamond .level-text { color: #fff; }

.level-text {
  font-weight: 800;
  font-size: 14px;
  position: relative;
  z-index: 1;
}

.user-info-section {
  margin-top: 20px;
}

.user-name-row {
  display: flex;
  align-items: center;
  gap: 18px;
  flex-wrap: wrap;
}

.user-avatar-wrapper {
  position: relative;
  cursor: pointer;
  border-radius: 50%;
  padding: 4px;
  background: linear-gradient(135deg, #d4af37, #f9e29c);
  transition: all 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275);
  box-shadow: 0 4px 15px rgba(212, 175, 55, 0.4);
}

.user-avatar-wrapper:hover {
  transform: scale(1.1) rotate(5deg);
  box-shadow: 0 8px 25px rgba(212, 175, 55, 0.5);
}

.premium-avatar {
  border: 4px solid #1a1a1a;
  background: #2a2a2a;
}

.avatar-edit-overlay {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  border-radius: 50%;
  background: rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(4px);
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: 0;
  transition: opacity 0.3s;
  color: #fff;
  font-size: 24px;
}

.user-avatar-wrapper:hover .avatar-edit-overlay {
  opacity: 1;
}

.user-main-info {
  flex: 1;
  min-width: 0;
  overflow: hidden;
}

.user-name {
  color: #fff;
  font-size: 26px;
  font-weight: 800;
  margin: 0;
  text-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
  word-break: break-word;
  max-width: 180px;
}

.user-phone-row {
  font-size: 14px;
  opacity: 0.6;
  margin-top: 8px;
  letter-spacing: 1px;
}

.premium-checkin-btn {
  background: rgba(255, 255, 255, 0.15);
  border: 1.5px solid rgba(255, 255, 255, 0.4);
  color: #fff;
  font-weight: 700;
  backdrop-filter: blur(8px);
  padding: 0 18px;
  height: 36px;
  font-size: 13px;
  flex-shrink: 0;
  transition: all 0.3s;
}

.premium-checkin-btn:hover {
  background: rgba(255, 255, 255, 0.25);
  border-color: #fff;
  transform: translateY(-2px);
  box-shadow: 0 4px 15px rgba(255, 255, 255, 0.2);
}

.checkin-done {
  color: #4ade80;
  font-size: 12px;
  font-weight: 700;
  display: flex;
  align-items: center;
  gap: 6px;
  background: rgba(74, 222, 128, 0.15);
  padding: 6px 14px;
  border-radius: 24px;
  backdrop-filter: blur(4px);
  white-space: nowrap;
  flex-shrink: 0;
  box-shadow: 0 0 15px rgba(74, 222, 128, 0.2);
}

.card-bottom {
  margin-top: auto;
}

.exp-container {
  width: 100%;
}

.exp-header {
  display: flex;
  justify-content: space-between;
  font-size: 13px;
  margin-bottom: 12px;
  opacity: 0.9;
}

.points-badge {
  background: rgba(255, 255, 255, 0.15);
  padding: 4px 12px;
  border-radius: 8px;
  font-weight: 600;
}

.exp-progress-new {
  height: 8px;
  background: rgba(255, 255, 255, 0.15);
  border-radius: 4px;
  overflow: hidden;
}

.exp-fill {
  height: 100%;
  background: linear-gradient(90deg, #d4af37, #f9e29c, #fff);
  background-size: 200% 100%;
  animation: progressShine 3s infinite linear;
  border-radius: 4px;
  transition: width 1s cubic-bezier(0.34, 1.56, 0.64, 1);
}

@keyframes progressShine {
  0% { background-position: 100% 0; }
  100% { background-position: -100% 0; }
}

.card-bg-pattern {
  position: absolute;
  top: 0;
  right: 0;
  width: 70%;
  height: 100%;
  background: radial-gradient(circle at top right, rgba(212, 175, 55, 0.2), transparent 70%);
  z-index: 1;
}

/* ==================== 资产网格 - 炫酷玻璃态 ==================== */
.stats-card-modern {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(20px);
  border-radius: var(--hotel-radius-2xl);
  padding: 36px;
  margin-bottom: 36px;
  box-shadow: 
    0 15px 40px rgba(26, 43, 74, 0.08),
    0 0 0 1px rgba(201, 169, 98, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.5);
}

.stats-header-modern {
  font-size: 19px;
  font-weight: 800;
  color: var(--hotel-primary);
  margin-bottom: 28px;
  display: flex;
  align-items: center;
  gap: 12px;
}

.stats-header-modern::before {
  content: '';
  width: 4px;
  height: 20px;
  background: linear-gradient(180deg, var(--hotel-gold) 0%, var(--hotel-gold-dark) 100%);
  border-radius: 2px;
}

.asset-grid-modern {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 22px;
}

.asset-item-modern {
  display: flex;
  align-items: center;
  gap: 18px;
  padding: 22px;
  background: linear-gradient(135deg, rgba(26, 43, 74, 0.02) 0%, rgba(201, 169, 98, 0.03) 100%);
  border-radius: var(--hotel-radius-xl);
  cursor: pointer;
  transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
  border: 1px solid transparent;
}

.asset-item-modern:hover {
  background: rgba(255, 255, 255, 0.9);
  box-shadow: 0 12px 30px rgba(26, 43, 74, 0.12);
  transform: translateY(-6px);
  border-color: rgba(201, 169, 98, 0.2);
}

.asset-icon-bg {
  width: 56px;
  height: 56px;
  border-radius: var(--hotel-radius-lg);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 26px;
  box-shadow: 0 4px 15px rgba(0, 0, 0, 0.05);
  transition: transform 0.3s;
}

.asset-item-modern:hover .asset-icon-bg {
  transform: scale(1.1);
}

.coupon-bg { background: linear-gradient(135deg, #fff1f0 0%, #fff1f0 100%); color: #ff4d4f; }
.points-bg { background: linear-gradient(135deg, #fffbe6 0%, #fffbe6 100%); color: #faad14; }
.balance-bg { background: linear-gradient(135deg, #f6ffed 0%, #f6ffed 100%); color: #52c41a; }
.stays-bg { background: linear-gradient(135deg, #e6f7ff 0%, #e6f7ff 100%); color: #1890ff; }

.asset-info-modern {
  display: flex;
  flex-direction: column;
}

.asset-num {
  font-size: 26px;
  font-weight: 800;
  color: var(--hotel-primary);
  line-height: 1.1;
}

.asset-num .unit, .asset-num .currency {
  font-size: 14px;
  margin: 0 2px;
  color: var(--hotel-text-muted);
  font-weight: 600;
}

.asset-name {
  font-size: 13px;
  color: var(--hotel-text-muted);
  margin-top: 6px;
  font-weight: 500;
}

/* ==================== 钱包样式 ==================== */
.wallet-card-ctrip {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(20px);
  border-radius: var(--hotel-radius-xl);
  padding: 36px;
  box-shadow: 
    0 10px 30px rgba(26, 43, 74, 0.08),
    0 0 0 1px rgba(201, 169, 98, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.5);
}

.wallet-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 36px;
}

.wallet-header h3 {
  font-size: 22px;
  font-weight: 800;
  margin: 0;
  color: var(--hotel-primary);
}

.balance-display-large {
  background: linear-gradient(135deg, rgba(26, 43, 74, 0.03) 0%, rgba(201, 169, 98, 0.05) 100%);
  padding: 48px;
  border-radius: var(--hotel-radius-xl);
  text-align: center;
  margin-bottom: 48px;
  border: 1px solid rgba(201, 169, 98, 0.15);
  position: relative;
  overflow: hidden;
}

.balance-display-large::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 3px;
  background: linear-gradient(90deg, var(--hotel-gold), var(--hotel-gold-light), var(--hotel-gold));
}

.balance-display-large .lab {
  font-size: 14px;
  color: var(--hotel-text-secondary);
  margin-bottom: 14px;
}

.balance-display-large .val {
  color: var(--hotel-primary);
}

.balance-display-large .val .currency {
  font-size: 26px;
  font-weight: 700;
  margin-right: 6px;
}

.balance-display-large .val .num {
  font-size: 60px;
  font-weight: 900;
  background: linear-gradient(135deg, var(--hotel-primary) 0%, var(--hotel-gold) 100%);
  background-clip: text;
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}

.recharge-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 22px;
}

.recharge-item {
  border: 2px solid rgba(26, 43, 74, 0.1);
  border-radius: var(--hotel-radius-xl);
  padding: 28px;
  text-align: center;
  cursor: pointer;
  transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
  position: relative;
  overflow: hidden;
  background: rgba(255, 255, 255, 0.8);
}

.recharge-item:hover {
  border-color: var(--hotel-gold);
  background: rgba(201, 169, 98, 0.05);
  transform: translateY(-4px);
  box-shadow: 0 8px 25px rgba(201, 169, 98, 0.15);
}

.recharge-item.active {
  border-color: var(--hotel-gold);
  background: rgba(201, 169, 98, 0.1);
  box-shadow: 0 0 0 2px rgba(201, 169, 98, 0.2), 0 8px 25px rgba(201, 169, 98, 0.2);
}

.recharge-item .amount-text {
  font-size: 26px;
  font-weight: 800;
  color: var(--hotel-primary);
  display: block;
}

.recharge-item .bonus-tag {
  display: inline-block;
  background: linear-gradient(135deg, #ff6b6b 0%, #ff8e8e 100%);
  color: #fff;
  font-size: 11px;
  font-weight: 700;
  padding: 4px 12px;
  border-radius: 12px;
  margin-top: 10px;
  box-shadow: 0 2px 8px rgba(255, 107, 107, 0.3);
}

.recharge-item .bonus-tip {
  display: block;
  font-size: 12px;
  color: var(--hotel-success);
  margin-top: 6px;
  font-weight: 600;
}

.recharge-btn-container {
  margin-top: 48px;
}

.recharge-btn-large {
  height: 64px;
  font-size: 22px;
  font-weight: 800;
  border-radius: var(--hotel-radius-xl);
  box-shadow: 0 8px 30px rgba(201, 169, 98, 0.35);
  transition: all 0.3s;
}

.recharge-btn-large:hover {
  transform: translateY(-2px);
  box-shadow: 0 12px 40px rgba(201, 169, 98, 0.45);
}

.bonus-explain {
  margin-top: 28px;
  padding: 24px;
  background: rgba(201, 169, 98, 0.08);
  border-radius: var(--hotel-radius-lg);
  border: 1px solid rgba(201, 169, 98, 0.15);
  display: flex;
  gap: 14px;
  align-items: flex-start;
}

.bonus-explain .icon { 
  color: var(--hotel-gold); 
  font-size: 20px; 
  margin-top: 2px; 
}
.bonus-explain .text { 
  font-size: 13px; 
  color: var(--hotel-text-secondary); 
  line-height: 1.7; 
}

/* ==================== 支付弹窗 ==================== */
.mock-payment-recharge {
  text-align: center;
  padding: 28px 0;
}

.mock-payment-recharge .amount-box {
  margin: 28px 0;
  background: linear-gradient(135deg, rgba(26, 43, 74, 0.03) 0%, rgba(201, 169, 98, 0.05) 100%);
  padding: 24px;
  border-radius: var(--hotel-radius-xl);
  border: 1px solid rgba(201, 169, 98, 0.1);
}

.mock-payment-recharge .amount-box .lab { font-size: 13px; color: var(--hotel-text-muted); }
.mock-payment-recharge .amount-box .val { 
  font-size: 40px; 
  font-weight: 800; 
  color: var(--hotel-primary); 
  margin-top: 6px; 
}

.payment-vendor-recharge {
  display: flex;
  justify-content: center;
  gap: 24px;
  margin-bottom: 36px;
}

.vendor-item {
  width: 130px;
  padding: 20px;
  border: 2px solid rgba(26, 43, 74, 0.1);
  border-radius: var(--hotel-radius-lg);
  cursor: pointer;
  transition: all 0.3s;
  background: rgba(255, 255, 255, 0.8);
}

.vendor-item:hover { 
  border-color: var(--hotel-gold); 
  background: rgba(201, 169, 98, 0.05);
}
.vendor-item.active { border-color: var(--hotel-gold); }
.vendor-item.wechat-active { 
  background: rgba(7, 193, 96, 0.08); 
  border-color: #07c160; 
  box-shadow: 0 4px 15px rgba(7, 193, 96, 0.2);
}
.vendor-item.alipay-active { 
  background: rgba(22, 119, 255, 0.08); 
  border-color: #1677ff; 
  box-shadow: 0 4px 15px rgba(22, 119, 255, 0.2);
}
.vendor-item .icon-wrapper { margin-bottom: 10px; display: flex; justify-content: center; align-items: center; height: 36px; }
.vendor-item .icon-wrapper.wechat-color { color: #07c160 !important; }
.vendor-item .icon-wrapper.alipay-color { color: #1677ff !important; }
.vendor-item .name { font-size: 14px; font-weight: 600; text-align: center; color: var(--hotel-text-secondary); }
.vendor-item.active .name { color: var(--level-color); }

.wechat-color { color: #07c160; }
.alipay-color { color: #1677ff; }

/* ==================== 会员权益 - 炫酷卡片 ==================== */
.rights-card-modern {
  border-radius: var(--hotel-radius-2xl);
  box-shadow: 
    0 15px 40px rgba(26, 43, 74, 0.08),
    0 0 0 1px rgba(201, 169, 98, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.5);
  padding: 10px;
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(20px);
}

.rights-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.rights-title-text {
  font-size: 19px;
  font-weight: 800;
  color: var(--hotel-primary);
}

.rights-subtitle {
  font-size: 13px;
  color: var(--hotel-gold);
  font-weight: 700;
  background: rgba(201, 169, 98, 0.1);
  padding: 6px 16px;
  border-radius: 14px;
  border: 1px solid rgba(201, 169, 98, 0.2);
}

.rights-grid-modern {
  display: flex;
  flex-direction: column;
  gap: 18px;
  padding: 18px;
}

.right-box {
  display: flex;
  align-items: center;
  gap: 22px;
  padding: 22px;
  background: rgba(26, 43, 74, 0.02);
  border-radius: var(--hotel-radius-xl);
  transition: all 0.4s;
  border: 2px solid transparent;
}

.right-box.active, .right-box:not(.disabled) {
  background: linear-gradient(135deg, rgba(255, 255, 255, 0.9) 0%, rgba(201, 169, 98, 0.05) 100%);
  border: 2px solid rgba(201, 169, 98, 0.15);
}

.right-box.disabled {
  opacity: 0.5;
  filter: grayscale(1);
}

.right-icon-wrapper {
  width: 52px;
  height: 52px;
  background: rgba(255, 255, 255, 0.9);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 24px;
  color: var(--hotel-gold);
  box-shadow: 0 6px 20px rgba(201, 169, 98, 0.2);
  transition: transform 0.3s;
}

.right-box:hover .right-icon-wrapper {
  transform: scale(1.1);
}

.right-title {
  font-size: 17px;
  font-weight: 800;
  color: var(--hotel-primary);
}

.right-value {
  font-size: 14px;
  color: var(--hotel-gold);
  margin-top: 6px;
  font-weight: 600;
}

/* ==================== 优惠券页 ==================== */
.coupons-section {
  display: flex;
  flex-direction: column;
  gap: 36px;
}

.coupon-import-bar {
  background: linear-gradient(135deg, rgba(26, 43, 74, 0.03) 0%, rgba(201, 169, 98, 0.05) 100%);
  padding: 36px;
  border-radius: var(--hotel-radius-xl);
  border: 2px dashed rgba(201, 169, 98, 0.2);
  text-align: center;
}

.coupons-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(340px, 1fr));
  gap: 28px;
}

.coupon-card {
  display: flex;
  height: 130px;
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(16px);
  border-radius: var(--hotel-radius-xl);
  overflow: hidden;
  box-shadow: 
    0 10px 30px rgba(26, 43, 74, 0.1),
    0 0 0 1px rgba(201, 169, 98, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.5);
  transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
}

.coupon-card:hover {
  transform: translateY(-8px) scale(1.02);
  box-shadow: 
    0 20px 50px rgba(26, 43, 74, 0.15),
    0 0 0 1px rgba(201, 169, 98, 0.2);
}

.coupon-left {
  width: 130px;
  background: linear-gradient(135deg, #ff6b6b 0%, #ff8e8e 100%);
  color: #fff;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  padding: 18px;
  position: relative;
}

.coupon-left::after {
  content: '';
  position: absolute;
  right: -6px;
  top: 0;
  bottom: 0;
  width: 12px;
  background-image: radial-gradient(circle at 12px 10px, transparent 6px, #ff6b6b 6px);
  background-size: 12px 20px;
}

.coupon-value .val {
  font-size: 36px;
  font-weight: 900;
  text-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
}

.coupon-value .unit {
  font-size: 18px;
  font-weight: 700;
}

.coupon-condition {
  font-size: 13px;
  font-weight: 600;
  opacity: 0.9;
  margin-top: 6px;
}

.coupon-right {
  flex: 1;
  padding: 22px;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
}

.coupon-name {
  font-size: 17px;
  font-weight: 800;
  color: var(--hotel-primary);
}

.coupon-date {
  font-size: 12px;
  color: var(--hotel-text-muted);
  font-weight: 500;
}

.empty-state {
  padding: 70px 0;
}

/* ==================== 右侧标签页 ==================== */
.profile-right {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(20px);
  border-radius: var(--hotel-radius-2xl);
  padding: 36px;
  box-shadow: 
    0 15px 40px rgba(26, 43, 74, 0.08),
    0 0 0 1px rgba(201, 169, 98, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.5);
}

.profile-tabs :deep(.ant-tabs-nav) {
  margin-bottom: 36px;
}

.profile-tabs :deep(.ant-tabs-tab) {
  font-size: 16px;
  font-weight: 600;
  padding: 14px 28px;
}

.account-info-list {
  display: flex;
  flex-direction: column;
  gap: 36px;
}

.info-item {
  display: grid;
  grid-template-columns: 150px 1fr;
  align-items: start;
  gap: 28px;
  padding-bottom: 36px;
  border-bottom: 1px solid rgba(201, 169, 98, 0.1);
}

.info-item:last-child {
  border-bottom: none;
}

.info-label {
  font-size: 15px;
  color: var(--hotel-text-secondary);
  font-weight: 600;
  padding-top: 4px;
}

.info-content {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.info-value {
  font-size: 18px;
  font-weight: 700;
  color: var(--hotel-primary);
}

.display-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.edit-link {
  font-weight: 600;
  font-size: 14px;
  transition: all 0.3s;
}

.edit-link:hover {
  color: var(--hotel-gold-dark);
}

.info-tip {
  font-size: 13px;
  color: var(--hotel-text-muted);
}

.edit-row {
  display: flex;
  gap: 18px;
  align-items: center;
}

.edit-input {
  max-width: 320px;
}

.edit-row-vertical {
  display: flex;
  flex-direction: column;
  gap: 18px;
  max-width: 420px;
}

.phone-input-group {
  display: flex;
  gap: 14px;
}

.send-code-btn {
  width: 130px;
  font-weight: 600;
  border-radius: var(--hotel-radius);
}

.edit-actions {
  display: flex;
  gap: 14px;
}

.mt-2 { margin-top: 8px; }

/* ==================== 常用入住人 ==================== */
.frequent-guests-section {
  padding: 10px 0;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 36px;
  background: linear-gradient(135deg, rgba(26, 43, 74, 0.03) 0%, rgba(201, 169, 98, 0.05) 100%);
  padding: 24px 28px;
  border-radius: var(--hotel-radius-xl);
  border: 1px solid rgba(201, 169, 98, 0.1);
}

.section-header p {
  margin: 0;
  color: var(--hotel-text-secondary);
  font-weight: 500;
}

.guests-list :deep(.ant-list-item) {
  padding: 28px;
  border-radius: var(--hotel-radius-xl);
  margin-bottom: 18px;
  transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
  border: 2px solid transparent;
  background: rgba(255, 255, 255, 0.8);
}

.guests-list :deep(.ant-list-item:hover) {
  background: rgba(255, 255, 255, 0.95);
  border-color: var(--hotel-gold);
  transform: translateX(10px);
  box-shadow: 0 8px 25px rgba(201, 169, 98, 0.15);
}

.guest-name {
  font-size: 19px;
  font-weight: 800;
  color: var(--hotel-primary);
}

.self-tag {
  margin-left: 14px;
  font-weight: 700;
  border-radius: 8px;
}

.guest-desc {
  display: flex;
  gap: 28px;
  margin-top: 10px;
}

.guest-desc span {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 14px;
  color: var(--hotel-text-muted);
}

.text-danger { color: var(--hotel-error); }

/* ==================== 响应式 ==================== */
@media (max-width: 1200px) {
  .profile-content {
    grid-template-columns: 1fr;
  }

  .profile-left {
    max-width: 550px;
    margin: 0 auto 40px;
  }
}

@media (max-width: 768px) {
  .profile-page-container {
    padding: 24px 16px;
  }
  
  .profile-content {
    gap: 32px;
  }
  
  .member-card-new {
    height: auto;
    min-height: 260px;
    padding: 28px;
  }
  
  .user-name-row {
    flex-direction: column;
    align-items: flex-start;
  }
  
  .asset-grid-modern {
    grid-template-columns: 1fr;
  }
  
  .recharge-grid {
    grid-template-columns: 1fr;
  }
  
  .info-item {
    grid-template-columns: 1fr;
    gap: 14px;
  }
  
  .coupons-grid {
    grid-template-columns: 1fr;
  }
}
</style>
