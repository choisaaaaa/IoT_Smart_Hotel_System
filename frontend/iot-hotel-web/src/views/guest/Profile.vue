<template>
  <div class="profile-page-container" :class="'theme-' + (memberInfo.member_level || 'standard')">
    <!-- 隐藏的头像上传输入框 -->
    <input
      type="file"
      ref="avatarInput"
      style="display: none"
      accept="image/*"
      @change="onAvatarChange"
    />
    <div class="profile-content">
      <!-- 左侧：会员卡与资产概览 -->
      <div class="profile-left">
        <div class="member-card-new" :class="`card-level-${memberInfo.member_level || 'standard'}`">
          <div class="card-inner">
            <div class="card-top">
              <div class="hotel-info">
                <div class="hotel-logo">{{ memberProgramName }}</div>
                <div class="hotel-brand">SMART HOTEL</div>
              </div>
              <div class="member-badge-new">
                <span class="level-text">{{ memberInfo.level_label || `LEVEL ${memberInfo.level || 1}` }}</span>
              </div>
            </div>

            <div class="user-info-section">
              <div class="user-name-row">
                <div class="user-avatar-wrapper" @click="handleAvatarClick">
                  <a-avatar :size="64" :src="getImageUrl(userInfo.avatar)" class="premium-avatar">
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
      <div class="profile-right">
        <a-tabs v-model:activeKey="activeTab" class="profile-tabs">
          <!-- 账号管理 -->
          <a-tab-pane key="account" tab="账号管理">
            <div class="account-info-list">
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
          <a-tab-pane key="coupons">
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
          <a-tab-pane key="guests" tab="常用入住人">
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
          <a-tab-pane key="wallet" tab="我的钱包">
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
                    您的当前等级为 <strong>{{ memberInfo?.level_label }}</strong>，充值立享 <strong>{{ ((1 - discountRate) * 100).toFixed(0) }}%</strong> 额度赠送（等同于您的房价折扣力度）。充值后的余额可用于预订房费支付，享受折上折，余额永不过期。
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
import dayjs from 'dayjs'

const router = useRouter()
const appStore = useAppStore()
const userInfo = computed(() => appStore.userInfo || {})
const avatarInput = ref<HTMLInputElement | null>(null)
const activeTab = ref('account')
const editingField = ref<string | null>(null)
const rechargeOptions = [100, 300, 500, 1000, 2000, 5000]
const selectedRechargeAmount = ref<number | null>(null)
const rechargeModalVisible = ref(false)
const rechargeVendor = ref('wechat')
const rechargeLoading = ref(false)

const discountRate = computed(() => {
  const level = memberInfo.value?.member_level || 'standard'
  const rates: Record<string, number> = {
    'diamond': 0.80,
    'platinum': 0.85,
    'gold': 0.88,
    'silver': 0.95,
    'standard': 1.0
  }
  return rates[level] || 1.0
})

const getBonusAmount = (amount: number) => {
  if (discountRate.value >= 1) return 0
  const bonusRate = 1 - discountRate.value
  return Math.floor((amount * bonusRate) * 100) / 100
}

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

// 会员等级逻辑
const memberLevelInfo = computed(() => {
  const mLevel = memberInfo.value.member_level || 'standard'
  const exp = memberInfo.value.experience || 0
  
  const levelConfig: any = {
    'diamond': { label: '钻石会员', level: 5, discount: 0.80, multiplier: 15, nextExp: 5000, percent: 100 },
    'platinum': { label: '铂金会员', level: 4, discount: 0.85, multiplier: 12, nextExp: 5000, percent: Math.floor((exp - 2000) / 3000 * 100) },
    'gold': { label: '金会员', level: 3, discount: 0.88, multiplier: 9, nextExp: 2000, percent: Math.floor((exp - 500) / 1500 * 100) },
    'silver': { label: '银会员', level: 2, discount: 0.95, multiplier: 3, nextExp: 500, percent: Math.floor((exp - 100) / 400 * 100) },
    'standard': { label: '普通会员', level: 1, discount: 1.0, multiplier: 1, nextExp: 100, percent: Math.floor(exp / 100 * 100) }
  }
  
  return levelConfig[mLevel] || levelConfig['standard']
})

// 会员与资产信息
const memberInfo = ref<any>({})
const memberProgramName = ref('IOT')
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
  const today = new Date().toISOString().split('T')[0]
  const lastDate = new Date(memberInfo.value.last_checkin_date).toISOString().split('T')[0]
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

// 格式化日期
const formatDate = (date: any) => {
  if (!date) return '-'
  return dayjs(date).format('YYYY-MM-DD')
}

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
    // 获取会员资产信息
    const res = await request.get('/members/me')
    console.log('Member Info Response:', res.data)
    memberInfo.value = res.data

    // 获取系统配置
    try {
      const configRes = await systemConfigApi.getConfig('member_program_name')
      if (configRes.data) {
        memberProgramName.value = configRes.data
      }
    } catch (e) {
      console.error('获取会员计划名称失败:', e)
    }

    // 获取我的优惠券
    const couponRes = await request.get('/coupons/me')
    myCoupons.value = couponRes.data || []

    // 初始化个人资料表单
    profileForm.username = appStore.userInfo.username
    profileForm.phone = appStore.userInfo.phone
    profileForm.email = appStore.userInfo.email || ''

    // 获取常用入住人
    fetchFrequentGuests()
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
/* 会员等级主题色变量 */
.profile-page-container.theme-standard { --level-color: #4b6cb7; --level-bg: #f0f5ff; }
.profile-page-container.theme-silver { --level-color: #90a4ae; --level-bg: #f0f4f8; }
.profile-page-container.theme-gold { --level-color: #d4af37; --level-bg: #fffdf0; }
.profile-page-container.theme-platinum { --level-color: #535c68; --level-bg: #f1f2f6; }
.profile-page-container.theme-diamond { --level-color: #30cfd0; --level-bg: #f0fbff; }

.profile-page-container {
  padding: 40px 24px;
  max-width: 100%;
  margin: 0 auto;
  min-height: calc(100vh - 120px);
}

.profile-content {
  display: grid;
  grid-template-columns: 450px 1fr;
  gap: 40px;
}

/* 统一配色适配 */
.stats-header-modern::before { background: var(--level-color) !important; }
.asset-icon-bg { background: var(--level-bg) !important; color: var(--level-color) !important; }
.balance-display-large { background: var(--level-bg) !important; border-color: var(--level-color) !important; }
.recharge-item.active { border-color: var(--level-color) !important; background: var(--level-bg) !important; }
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

/* 新版会员卡样式 */
.member-card-new {
  height: 260px;
  border-radius: 28px;
  position: relative;
  overflow: hidden;
  color: #fff;
  padding: 32px;
  box-shadow: 0 25px 50px rgba(0, 0, 0, 0.25);
  margin-bottom: 32px;
  transition: all 0.5s ease;
}

/* 等级配色方案 */
.card-level-standard { background: linear-gradient(135deg, #4b6cb7 0%, #182848 100%); }
.card-level-silver { background: linear-gradient(135deg, #bdc3c7 0%, #2c3e50 100%); }
.card-level-gold { background: linear-gradient(135deg, #d4af37 0%, #1a1a1a 100%); }
.card-level-platinum { background: linear-gradient(135deg, #e5e4e2 0%, #434343 100%); }
.card-level-diamond { background: linear-gradient(135deg, #30cfd0 0%, #330867 100%); }

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
  font-size: 30px;
  font-weight: 900;
  letter-spacing: 4px;
  line-height: 1;
  text-transform: uppercase;
  background: linear-gradient(135deg, #fff, #f9e29c);
  background-clip: text;
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}

.hotel-brand {
  font-size: 11px;
  letter-spacing: 4px;
  opacity: 0.6;
  margin-top: 6px;
}

.member-badge-new {
  background: linear-gradient(90deg, #d4af37, #f9e29c);
  padding: 8px 20px;
  border-radius: 14px;
  box-shadow: 0 6px 15px rgba(212, 175, 55, 0.3);
}

.level-text {
  color: #1a1a1a;
  font-weight: 800;
  font-size: 14px;
}

.user-info-section {
  margin-top: 16px;
}

.user-name-row {
  display: flex;
  align-items: center;
  gap: 24px;
}

.user-avatar-wrapper {
  position: relative;
  cursor: pointer;
  border-radius: 50%;
  padding: 4px;
  background: linear-gradient(135deg, #d4af37, #f9e29c);
  transition: all 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275);
}

.user-avatar-wrapper:hover {
  transform: scale(1.1) rotate(5deg);
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
}

.user-name {
  color: #fff;
  font-size: 36px;
  font-weight: 800;
  margin: 0;
  text-shadow: 0 2px 4px rgba(0,0,0,0.3);
}

.user-phone-row {
  font-size: 18px;
  opacity: 0.6;
  margin-top: 6px;
  letter-spacing: 1.5px;
}

.premium-checkin-btn {
  background: rgba(255, 255, 255, 0.2);
  border: 1.5px solid rgba(255, 255, 255, 0.4);
  color: #fff;
  font-weight: 700;
  backdrop-filter: blur(8px);
  padding: 0 20px;
  height: 36px;
}

.premium-checkin-btn:hover {
  background: rgba(255, 255, 255, 0.3);
  border-color: #fff;
  transform: translateY(-2px);
}

.checkin-done {
  color: #52c41a;
  font-size: 14px;
  font-weight: 700;
  display: flex;
  align-items: center;
  gap: 6px;
  background: rgba(82, 196, 26, 0.15);
  padding: 6px 16px;
  border-radius: 20px;
  backdrop-filter: blur(4px);
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
  margin-bottom: 10px;
  opacity: 0.9;
}

.points-badge {
  background: rgba(255, 255, 255, 0.15);
  padding: 3px 10px;
  border-radius: 6px;
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
  animation: shine 3s infinite linear;
  border-radius: 4px;
  transition: width 1s cubic-bezier(0.34, 1.56, 0.64, 1);
}

@keyframes shine {
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

/* 资产网格 (现代感) */
.stats-card-modern {
  background: #fff;
  border-radius: 28px;
  padding: 32px;
  margin-bottom: 32px;
  box-shadow: 0 15px 40px rgba(0, 0, 0, 0.06);
  border: 1px solid #f0f0f0;
}

.stats-header-modern {
  font-size: 18px;
  font-weight: 800;
  color: #1a1a1a;
  margin-bottom: 24px;
  display: flex;
  align-items: center;
  gap: 10px;
}

.stats-header-modern::before {
  content: '';
  width: 4px;
  height: 18px;
  background: #d4af37;
  border-radius: 2px;
}

.asset-grid-modern {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px;
}

.asset-item-modern {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 20px;
  background: #f8faff;
  border-radius: 20px;
  cursor: pointer;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  border: 1px solid transparent;
}

.asset-item-modern:hover {
  background: #fff;
  box-shadow: 0 12px 24px rgba(0, 0, 0, 0.1);
  transform: translateY(-4px);
  border-color: #e6f0ff;
}

.asset-icon-bg {
  width: 52px;
  height: 52px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 24px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.05);
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
  font-size: 24px;
  font-weight: 800;
  color: #1a1a1a;
  line-height: 1.1;
}

.asset-num .unit, .asset-num .currency {
  font-size: 14px;
  margin: 0 2px;
  color: #8c8c8c;
  font-weight: 600;
}

.asset-name {
  font-size: 13px;
  color: #8c8c8c;
  margin-top: 4px;
  font-weight: 500;
}

/* Wallet Styles */
.wallet-card-ctrip {
  background: #fff;
  border-radius: 20px;
  padding: 32px;
  box-shadow: 0 10px 30px rgba(0,0,0,0.05);
}

.wallet-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 32px;
}

.wallet-header h3 {
  font-size: 20px;
  font-weight: 800;
  margin: 0;
}

.balance-display-large {
  background: linear-gradient(135deg, #f0f5ff 0%, #e6f7ff 100%);
  padding: 40px;
  border-radius: 24px;
  text-align: center;
  margin-bottom: 40px;
  border: 1px solid #91d5ff;
}

.balance-display-large .lab {
  font-size: 14px;
  color: #595959;
  margin-bottom: 12px;
}

.balance-display-large .val {
  color: #1a1a1a;
}

.balance-display-large .val .currency {
  font-size: 24px;
  font-weight: 700;
  margin-right: 4px;
}

.balance-display-large .val .num {
  font-size: 56px;
  font-weight: 900;
}

.recharge-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 20px;
}

.recharge-item {
  border: 1.5px solid #f0f0f0;
  border-radius: 16px;
  padding: 24px;
  text-align: center;
  cursor: pointer;
  transition: all 0.3s;
  position: relative;
  overflow: hidden;
}

.recharge-item:hover {
  border-color: #008cff;
  background: #f8faff;
}

.recharge-item.active {
  border-color: #008cff;
  background: #e6f7ff;
  box-shadow: 0 0 0 1px #008cff;
}

.recharge-item .amount-text {
  font-size: 24px;
  font-weight: 800;
  color: #1a1a1a;
  display: block;
}

.recharge-item .bonus-tag {
  display: inline-block;
  background: #ff4d4f;
  color: #fff;
  font-size: 11px;
  font-weight: 700;
  padding: 2px 8px;
  border-radius: 10px;
  margin-top: 8px;
}

.recharge-item .bonus-tip {
  display: block;
  font-size: 12px;
  color: #52c41a;
  margin-top: 4px;
  font-weight: 600;
}

.recharge-btn-container {
  margin-top: 40px;
}

.recharge-btn-large {
  height: 60px;
  font-size: 20px;
  font-weight: 800;
  border-radius: 16px;
  box-shadow: 0 8px 24px rgba(0, 140, 255, 0.2);
}

.bonus-explain {
  margin-top: 24px;
  padding: 20px;
  background: #fffbe6;
  border-radius: 12px;
  border: 1px solid #ffe58f;
  display: flex;
  gap: 12px;
  align-items: flex-start;
}

.bonus-explain .icon { color: #faad14; font-size: 18px; margin-top: 2px; }
.bonus-explain .text { font-size: 13px; color: #856404; line-height: 1.6; }

/* Mock Payment Recharge */
.mock-payment-recharge {
  text-align: center;
  padding: 24px 0;
}

.mock-payment-recharge .amount-box {
  margin: 24px 0;
  background: #f8f9fa;
  padding: 20px;
  border-radius: 12px;
}

.mock-payment-recharge .amount-box .lab { font-size: 13px; color: #8c8c8c; }
.mock-payment-recharge .amount-box .val { font-size: 36px; font-weight: 800; color: #1a1a1a; margin-top: 4px; }

.payment-vendor-recharge {
  display: flex;
  justify-content: center;
  gap: 20px;
  margin-bottom: 32px;
}

.vendor-item {
  width: 120px;
  padding: 16px;
  border: 1px solid #f0f0f0;
  border-radius: 12px;
  cursor: pointer;
  transition: all 0.2s;
}

.vendor-item:hover { border-color: #008cff; }
.vendor-item.active { border-color: #008cff; }
.vendor-item.wechat-active { background: #e6fffb; border-color: #07c160; }
.vendor-item.alipay-active { background: #e6f7ff; border-color: #1677ff; }
.vendor-item .icon-wrapper { margin-bottom: 8px; display: flex; justify-content: center; align-items: center; height: 32px; }
.vendor-item .icon-wrapper.wechat-color { color: #07c160 !important; }
.vendor-item .icon-wrapper.alipay-color { color: #1677ff !important; }
.vendor-item .name { font-size: 13px; font-weight: 600; text-align: center; color: #595959; }
.vendor-item.active .name { color: var(--level-color); }

.wechat-color { color: #07c160; }
.alipay-color { color: #1677ff; }

/* 会员权益 (现代感) */
.rights-card-modern {
  border-radius: 28px;
  box-shadow: 0 15px 40px rgba(0, 0, 0, 0.06);
  border: 1px solid #f0f0f0;
  padding: 8px;
}

.rights-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.rights-title-text {
  font-size: 18px;
  font-weight: 800;
}

.rights-subtitle {
  font-size: 13px;
  color: #d4af37;
  font-weight: 700;
  background: #fffdf0;
  padding: 4px 12px;
  border-radius: 10px;
  border: 1px solid #f9e29c;
}

.rights-grid-modern {
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 16px;
}

.right-box {
  display: flex;
  align-items: center;
  gap: 20px;
  padding: 20px;
  background: #fafafa;
  border-radius: 20px;
  transition: all 0.3s;
  border: 1px solid transparent;
}

.right-box.active, .right-box:not(.disabled) {
  background: linear-gradient(90deg, #fff 0%, #fffdf0 100%);
  border: 1px solid #f9e29c;
}

.right-box.disabled {
  opacity: 0.5;
  filter: grayscale(1);
}

.right-icon-wrapper {
  width: 48px;
  height: 48px;
  background: #fff;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 22px;
  color: #d4af37;
  box-shadow: 0 6px 15px rgba(212, 175, 55, 0.15);
}

.right-title {
  font-size: 16px;
  font-weight: 800;
  color: #1a1a1a;
}

.right-value {
  font-size: 14px;
  color: #8c8c8c;
  margin-top: 4px;
  font-weight: 500;
}

/* 优惠券页 */
.coupons-section {
  display: flex;
  flex-direction: column;
  gap: 32px;
}

.coupon-import-bar {
  background: linear-gradient(135deg, #f8f9fa 0%, #f0f2f5 100%);
  padding: 32px;
  border-radius: 24px;
  border: 1px dashed #d9d9d9;
  text-align: center;
}

.coupons-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 24px;
}

.coupon-card {
  display: flex;
  height: 120px;
  background: #fff;
  border-radius: 20px;
  overflow: hidden;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.08);
  border: 1px solid #f0f0f0;
  transition: all 0.3s;
}

.coupon-card:hover {
  transform: translateY(-6px);
  box-shadow: 0 15px 35px rgba(0, 0, 0, 0.12);
}

.coupon-left {
  width: 120px;
  background: linear-gradient(135deg, #ff4d4f 0%, #ff7875 100%);
  color: #fff;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  padding: 16px;
  position: relative;
}

.coupon-left::after {
  content: '';
  position: absolute;
  right: -6px;
  top: 0;
  bottom: 0;
  width: 12px;
  background-image: radial-gradient(circle at 12px 10px, transparent 6px, #ff605c 6px);
  background-size: 12px 20px;
}

.coupon-value .val {
  font-size: 32px;
  font-weight: 900;
}

.coupon-value .unit {
  font-size: 16px;
  font-weight: 700;
}

.coupon-condition {
  font-size: 13px;
  font-weight: 600;
  opacity: 0.9;
  margin-top: 4px;
}

.coupon-right {
  flex: 1;
  padding: 20px;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
}

.coupon-name {
  font-size: 16px;
  font-weight: 800;
  color: #1a1a1a;
}

.coupon-date {
  font-size: 12px;
  color: #8c8c8c;
  font-weight: 500;
}

.empty-state {
  padding: 60px 0;
}
/* 右侧标签页 */
.profile-right {
  background: #fff;
  border-radius: 28px;
  padding: 32px;
  box-shadow: 0 15px 40px rgba(0, 0, 0, 0.06);
  border: 1px solid #f0f0f0;
}

.profile-tabs :deep(.ant-tabs-nav) {
  margin-bottom: 32px;
}

.profile-tabs :deep(.ant-tabs-tab) {
  font-size: 16px;
  font-weight: 600;
  padding: 12px 24px;
}

.account-info-list {
  display: flex;
  flex-direction: column;
  gap: 32px;
}

.info-item {
  display: grid;
  grid-template-columns: 140px 1fr;
  align-items: start;
  gap: 24px;
  padding-bottom: 32px;
  border-bottom: 1px solid #f5f5f5;
}

.info-item:last-child {
  border-bottom: none;
}

.info-label {
  font-size: 15px;
  color: #8c8c8c;
  font-weight: 600;
  padding-top: 4px;
}

.info-content {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.info-value {
  font-size: 17px;
  font-weight: 700;
  color: #1a1a1a;
}

.display-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.edit-link {
  font-weight: 600;
  font-size: 14px;
}

.info-tip {
  font-size: 13px;
  color: #bfbfbf;
}

.edit-row {
  display: flex;
  gap: 16px;
  align-items: center;
}

.edit-input {
  max-width: 300px;
}

.edit-row-vertical {
  display: flex;
  flex-direction: column;
  gap: 16px;
  max-width: 400px;
}

.phone-input-group {
  display: flex;
  gap: 12px;
}

.send-code-btn {
  width: 120px;
  font-weight: 600;
}

.edit-actions {
  display: flex;
  gap: 12px;
}

.mt-2 { margin-top: 8px; }

/* 常用入住人 */
.frequent-guests-section {
  padding: 8px 0;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 32px;
  background: #f8faff;
  padding: 20px 24px;
  border-radius: 20px;
  border: 1px solid #e6f0ff;
}

.section-header p {
  margin: 0;
  color: #595959;
  font-weight: 500;
}

.guests-list :deep(.ant-list-item) {
  padding: 24px;
  border-radius: 20px;
  margin-bottom: 16px;
  transition: all 0.3s;
  border: 1px solid #f0f0f0;
}

.guests-list :deep(.ant-list-item:hover) {
  background: #f8faff;
  border-color: #008cff;
  transform: translateX(8px);
}

.guest-name {
  font-size: 18px;
  font-weight: 800;
  color: #1a1a1a;
}

.self-tag {
  margin-left: 12px;
  font-weight: 700;
  border-radius: 6px;
}

.guest-desc {
  display: flex;
  gap: 24px;
  margin-top: 8px;
}

.guest-desc span {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 14px;
  color: #8c8c8c;
}

.text-danger { color: #ff4d4f; }

@media (max-width: 992px) {
  .profile-content {
    grid-template-columns: 1fr;
  }

  .profile-left {
    max-width: 500px;
    margin: 0 auto 32px;
  }
}
</style>
