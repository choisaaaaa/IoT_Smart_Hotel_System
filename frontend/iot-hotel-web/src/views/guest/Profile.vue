<template>
  <div class="profile-page-container">
    <div class="profile-content">
      <!-- 左侧：会员卡与资产概览 -->
      <div class="profile-left">
        <a-card class="member-card" :bordered="false">
          <div class="card-bg"></div>
          <div class="card-content">
            <div class="card-header">
              <div class="hotel-brand">IOT SMART HOTEL</div>
              <div class="member-level-badge">{{ memberInfo.member_level === 'platinum' ? '铂金会员' : memberInfo.member_level === 'gold' ? '黄金会员' : '标准会员' }}</div>
            </div>
            <div class="user-main">
              <div class="user-nickname">{{ userInfo.username }}</div>
              <div class="user-phone">{{ userInfo.phone }}</div>
            </div>
            <div class="card-footer">
              <div class="points-info">
                <span class="label">积分：</span>
                <span class="value">{{ memberInfo.points || 0 }}</span>
              </div>
              <div class="join-date">注册于 {{ formatDate(userInfo.created_at) }}</div>
            </div>
          </div>
        </a-card>

        <div class="asset-grid">
          <a-card class="asset-item" :bordered="false">
            <template #title><span class="asset-title">账户余额</span></template>
            <div class="asset-value">
              <span class="currency">¥</span>
              <span class="amount">{{ memberInfo.balance || '0.00' }}</span>
            </div>
            <a-button type="link" class="action-btn">立即充值</a-button>
          </a-card>
          <a-card class="asset-item" :bordered="false">
            <template #title><span class="asset-title">优惠券</span></template>
            <div class="asset-value">
              <span class="amount">{{ memberInfo.coupons_count || 0 }}</span>
              <span class="unit">张</span>
            </div>
            <a-button type="link" class="action-btn" @click="$router.push('/guest/orders')">查看更多</a-button>
          </a-card>
        </div>

        <a-card class="stats-card" :bordered="false">
          <div class="stats-grid">
            <div class="stat-box">
              <div class="stat-value">{{ memberInfo.total_stays || 0 }}</div>
              <div class="stat-label">累计入住</div>
            </div>
            <div class="stat-box">
              <div class="stat-value">¥{{ memberInfo.total_spent || '0.00' }}</div>
              <div class="stat-label">累计消费</div>
            </div>
          </div>
        </a-card>
      </div>

      <!-- 右侧：个人资料与常用入住人 -->
      <div class="profile-right">
        <a-tabs v-model:activeKey="activeTab" class="profile-tabs">
          <!-- 个人资料编辑 -->
          <a-tab-pane key="account" tab="账号信息">
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
                          <span><IdcardOutlined /> {{ item.id_type === 'idcard' ? '身份证' : '护照' }}: {{ maskId(item.id_number) }}</span>
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
        </a-tabs>
      </div>
    </div>

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
            <a-select-option value="idcard">身份证</a-select-option>
            <a-select-option value="passport">护照</a-select-option>
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
import { message } from 'ant-design-vue'
import {
  PlusOutlined,
  PhoneOutlined,
  IdcardOutlined,
  TeamOutlined,
  UserOutlined
} from '@ant-design/icons-vue'
import { useAppStore } from '@/stores/app'
import { userApi } from '@/api/user'
import request from '@/api/request'
import guestService, { FrequentGuest } from '@/api/frequent-guest'
import dayjs from 'dayjs'

const appStore = useAppStore()
const userInfo = computed(() => appStore.userInfo || {})
const activeTab = ref('account')
const editingField = ref<string | null>(null)

// 会员与资产信息
const memberInfo = ref<any>({})
const loading = ref(false)

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

// 初始化数据
const fetchData = async () => {
  if (!appStore.userInfo) return
  
  try {
    loading.value = true
    // 获取会员资产信息
    const res = await request.get('/members/me')
    memberInfo.value = res.data
    
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

    const res = await userApi.updateProfile(updateData)
    
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
.profile-page-container {
  padding: 40px 24px;
  max-width: 1200px;
  margin: 0 auto;
  min-height: calc(100vh - 120px);
}

.profile-content {
  display: grid;
  grid-template-columns: 380px 1fr;
  gap: 32px;
}

/* 会员卡样式 */
.member-card {
  height: 220px;
  border-radius: 20px;
  overflow: hidden;
  position: relative;
  color: #fff;
  margin-bottom: 24px;
  box-shadow: 0 12px 24px rgba(0, 0, 0, 0.15);
}

.card-bg {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: linear-gradient(135deg, #1a1a1a 0%, #4a4a4a 100%);
  z-index: 1;
}

.card-content {
  position: relative;
  z-index: 2;
  padding: 24px;
  height: 100%;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
}

.hotel-brand {
  font-family: 'Copperplate', serif;
  font-size: 18px;
  letter-spacing: 2px;
  font-weight: 600;
  opacity: 0.9;
}

.member-level-badge {
  background: linear-gradient(90deg, #d4af37, #f9e29c);
  color: #1a1a1a;
  padding: 4px 12px;
  border-radius: 20px;
  font-size: 12px;
  font-weight: 600;
}

.user-main {
  margin-top: 20px;
}

.user-nickname {
  font-size: 28px;
  font-weight: 600;
  margin-bottom: 4px;
}

.user-phone {
  font-size: 16px;
  opacity: 0.7;
}

.card-footer {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  font-size: 13px;
  opacity: 0.8;
}

.points-info .value {
  font-size: 18px;
  font-weight: 600;
  margin-left: 4px;
}

/* 资产网格 */
.asset-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
  margin-bottom: 24px;
}

.asset-item {
  border-radius: 16px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
}

.asset-title {
  font-size: 14px;
  color: #666;
}

.asset-value {
  margin: 8px 0;
}

.asset-value .currency {
  font-size: 14px;
  color: #333;
  margin-right: 2px;
}

.asset-value .amount {
  font-size: 24px;
  font-weight: 600;
  color: #1a1a1a;
}

.asset-value .unit {
  font-size: 14px;
  color: #666;
  margin-left: 4px;
}

.action-btn {
  padding: 0;
  height: auto;
}

/* 统计卡片 */
.stats-card {
  border-radius: 16px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
}

.stats-grid {
  display: flex;
  justify-content: space-around;
  padding: 8px 0;
}

.stat-box {
  text-align: center;
}

.stat-value {
  font-size: 20px;
  font-weight: 600;
  color: #1a1a1a;
  margin-bottom: 4px;
}

.stat-label {
  font-size: 12px;
  color: #999;
}

/* 右侧标签页 */
.profile-right {
  background: #fff;
  border-radius: 20px;
  padding: 24px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.05);
}

.profile-tabs :deep(.ant-tabs-nav) {
  margin-bottom: 32px;
}

.profile-tabs :deep(.ant-tabs-tab-btn) {
  font-size: 16px;
}

/* 账号信息列表样式 */
.account-info-list {
  display: flex;
  flex-direction: column;
  gap: 0;
}

.info-item {
  display: flex;
  padding: 24px 0;
  border-bottom: 1px solid #f0f0f0;
  align-items: flex-start;
}

.info-item:last-child {
  border-bottom: none;
}

.info-label {
  width: 120px;
  font-size: 14px;
  color: #666;
  padding-top: 4px;
}

.info-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.info-value {
  font-size: 16px;
  color: #1a1a1a;
  font-weight: 500;
}

.info-tip {
  font-size: 12px;
  color: #999;
}

.display-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  width: 100%;
}

.edit-link {
  padding: 0;
  height: auto;
  font-size: 14px;
}

.edit-row {
  display: flex;
  gap: 12px;
  align-items: center;
  width: 100%;
}

.edit-input {
  max-width: 300px;
}

.edit-row-vertical {
  display: flex;
  flex-direction: column;
  gap: 12px;
  width: 100%;
  max-width: 400px;
}

.edit-actions {
  display: flex;
  gap: 8px;
  flex-shrink: 0;
}

.mt-2 { margin-top: 8px; }

.phone-input-group {
  display: flex;
  gap: 8px;
}

.send-code-btn {
  width: 120px;
}

/* 常用入住人列表 */
.frequent-guests-section .section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
}

.frequent-guests-section .section-header p {
  color: #666;
  margin: 0;
}

.guest-name {
  font-size: 16px;
  font-weight: 600;
}

.self-tag {
  margin-left: 8px;
  font-size: 11px;
}

.guest-desc {
  display: flex;
  gap: 24px;
  margin-top: 4px;
}

.text-danger {
  color: #ff4d4f;
}

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
