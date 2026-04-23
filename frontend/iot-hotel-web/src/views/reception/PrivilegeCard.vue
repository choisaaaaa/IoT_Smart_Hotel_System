<template>
  <div class="privilege-card-page">
    <div class="page-header">
      <div class="header-content">
        <h1 class="page-title">特权卡发放中心</h1>
        <p class="page-subtitle">签发酒店管理卡、楼层卡及员工通行卡。特权卡具备多房或全域通行权限，请严格遵守安全审计规范。</p>
      </div>
      <div class="header-extra">
        <a-space>
          <a-alert
            v-if="!selectedEncoder && encoders.length > 0"
            message="请选择发卡器"
            type="warning"
            size="small"
            show-icon
          />
          <a-alert
            v-if="encoders.length === 0"
            message="未检测到在线发卡器"
            type="error"
            size="small"
            show-icon
          />
          <a-button 
            :type="isAuthorized ? 'default' : 'primary'" 
            :danger="isAuthorized"
            @click="openAuthorizeModal"
          >
            <template #icon>
              <UnlockOutlined v-if="isAuthorized" />
              <LockOutlined v-else />
            </template>
            {{ isAuthorized ? '解除授权' : '经理授权' }}
          </a-button>
          <a-select v-model:value="selectedEncoder" placeholder="选择发卡器" style="width: 200px">
            <template #prefix><LaptopOutlined /></template>
            <a-select-option v-for="d in encoders" :key="d.device_id" :value="d.device_id">
              {{ d.device_name || d.device_id }}
            </a-select-option>
          </a-select>
          <a-button @click="fetchEncoders">
            <template #icon><ReloadOutlined /></template>
          </a-button>
        </a-space>
      </div>
    </div>

    <div class="privilege-grid">
      <a-card v-for="type in cardTypes" :key="type.key" class="privilege-item-card" :class="{ 'auth-required': !isAuthorized }" hoverable>
        <div class="card-body">
          <div class="card-icon-wrapper" :style="{ background: type.bgColor, color: type.color }">
            <component :is="type.icon" class="type-icon" />
          </div>
          <div class="card-info">
            <h3 class="type-name">{{ type.name }}</h3>
            <p class="type-desc">{{ type.desc }}</p>
            <div class="type-features">
              <div v-for="f in type.features" :key="f" class="feature-tag">
                <CheckCircleFilled style="font-size: 12px; color: #52c41a;" /> {{ f }}
              </div>
            </div>
          </div>
          <div class="card-action">
            <a-tooltip :title="!isAuthorized ? '签发特权卡需要经理授权' : ''">
              <a-button 
                type="primary" 
                block 
                size="large" 
                :disabled="!isAuthorized"
                @click="openIssueModal(type)"
              >
                {{ !isAuthorized ? '待授权' : '配置并签发' }}
              </a-button>
            </a-tooltip>
          </div>
        </div>
      </a-card>
    </div>

    <!-- 经理授权弹窗 -->
    <a-modal
      v-model:open="authorizeModalVisible"
      title="经理权限授权"
      @ok="handleAuthorize"
      :confirmLoading="authorizing"
      width="400px"
    >
      <div class="auth-modal-content">
        <a-form layout="vertical">
          <a-form-item label="选择经理" required>
            <a-select v-model:value="authForm.manager_id" placeholder="选择当前门店经理">
              <a-select-option v-for="m in managers" :key="m.id" :value="m.id">
                {{ m.username }} ({{ m.phone || '无手机号' }})
              </a-select-option>
            </a-select>
          </a-form-item>
          <a-form-item label="授权密码" required>
            <a-input-password v-model:value="authForm.password" placeholder="请输入经理登录密码" />
          </a-form-item>
          <a-alert message="签发高权限特权卡需要经理账号进行二次验证授权" type="info" show-icon />
        </a-form>
      </div>
    </a-modal>

    <!-- 发卡对话框 -->
    <a-modal
      v-model:open="issueModalVisible"
      :title="`签发 - ${selectedType?.name}`"
      @ok="handleIssue"
      :confirmLoading="issuing"
      :okText="issueStep === 'success' ? '完成' : '立即签发'"
      :cancelButtonProps="{ style: { display: issueStep === 'success' ? 'none' : '' } }"
      width="560px"
      destroyOnClose
    >
      <div class="issue-modal-content">
        <template v-if="issueStep === 'form'">
          <a-alert
            message="高权限操作警告"
            :description="`您正在签发一张【${selectedType?.name}】，该卡片将具备${selectedType?.authDesc}。所有签发记录将被永久记录在系统审计日志中。`"
            type="warning"
            show-icon
            style="margin-bottom: 24px"
          />

          <a-form :model="issueForm" layout="vertical">
            <a-row :gutter="16">
              <a-col :span="12">
                <a-form-item label="持卡人姓名" required>
                  <a-input v-model:value="issueForm.holder_name" placeholder="请输入姓名" />
                </a-form-item>
              </a-col>
              <a-col :span="12">
                <a-form-item label="员工编号/手机号" required>
                  <a-input v-model:value="issueForm.holder_id" placeholder="请输入标识符" />
                </a-form-item>
              </a-col>
            </a-row>

            <template v-if="selectedType?.key === 'floor'">
              <a-form-item label="授权楼层" required>
                <a-select
                  v-model:value="issueForm.floors"
                  mode="multiple"
                  placeholder="请选择授权楼层"
                  style="width: 100%"
                >
                  <a-select-option v-for="f in floorList" :key="f.id" :value="f.floor_number">
                    {{ f.floor_number }} 层
                  </a-select-option>
                </a-select>
              </a-form-item>
            </template>

            <template v-if="selectedType?.key === 'staff'">
              <a-form-item label="授权房间范围" required>
                <a-select
                  v-model:value="issueForm.rooms"
                  mode="multiple"
                  placeholder="选择具体房间（可多选）"
                  style="width: 100%"
                >
                  <a-select-option v-for="r in allRooms" :key="r.id" :value="r.room_number">
                    {{ r.room_number }} - {{ r.room_name }}
                  </a-select-option>
                </a-select>
              </a-form-item>
            </template>

            <a-row :gutter="16">
              <a-col :span="12">
                <a-form-item label="有效期至" required>
                  <a-date-picker
                    v-model:value="issueForm.expiry_date"
                    show-time
                    format="YYYY-MM-DD HH:mm"
                    style="width: 100%"
                  />
                </a-form-item>
              </a-col>
              <a-col :span="12">
                <a-form-item label="备注说明">
                  <a-input v-model:value="issueForm.remark" placeholder="如：保洁部临时领用" />
                </a-form-item>
              </a-col>
            </a-row>

            <a-divider>安全验证</a-divider>
            <a-form-item label="操作员登录密码二次确认" required>
              <a-input-password v-model:value="issueForm.confirm_password" placeholder="请输入您的登录密码" />
            </a-form-item>
          </a-form>

          <div class="hardware-hint">
            <InfoCircleOutlined style="color: #1890ff" /> 请确保物理卡片已放置在发卡器 <b>{{ encoders.find(e => e.device_id === selectedEncoder)?.device_name || '未选择' }}</b> 上。
          </div>
        </template>

        <template v-else>
          <div class="step-status-container">
            <div class="status-animation">
              <a-progress
                type="circle"
                :percent="issueStep === 'writing' ? 70 : 100"
                :status="issueStep === 'error' ? 'exception' : (issueStep === 'success' ? 'success' : 'active')"
                :width="120"
              />
            </div>
            <h2 class="status-title">{{ issueStep === 'writing' ? '正在处理...' : (issueStep === 'success' ? '签发成功' : '签发失败') }}</h2>
            <p class="status-msg">{{ issueStatusMsg }}</p>
            
            <div v-if="issueStep === 'error'" style="margin-top: 24px">
              <a-button @click="issueStep = 'form'">返回修改</a-button>
            </div>
          </div>
        </template>
      </div>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, computed } from 'vue'
import { message } from 'ant-design-vue'
import dayjs from 'dayjs'
import {
  SafetyOutlined,
  KeyOutlined,
  TeamOutlined,
  AlertOutlined,
  CheckCircleFilled,
  InfoCircleOutlined,
  LaptopOutlined,
  ReloadOutlined,
  LockOutlined,
  UnlockOutlined,
  UserOutlined,
  SafetyCertificateOutlined
} from '@ant-design/icons-vue'
import { deviceApi } from '@/api/device'
import { useHotelStore } from '@/stores/hotel'
import { userApi, type UserProfile } from '@/api/user'
import request from '@/api/request'
import type { DeviceInfo } from '@/types'

const hotelStore = useHotelStore()
const encoders = ref<DeviceInfo[]>([])
const selectedEncoder = ref<string | undefined>(undefined)

// 经理授权相关
const isAuthorized = ref(false)
const authorizeModalVisible = ref(false)
const authorizing = ref(false)
const managers = ref<UserProfile[]>([])
const authForm = reactive({
  manager_id: undefined as number | undefined,
  password: ''
})

async function fetchManagers() {
  try {
    const res: any = await userApi.getUserList({ 
      role: 'hotel_admin', 
      hotel_id: hotelStore.hotelInfo?.id,
      pageSize: 100 
    })
    managers.value = res.data?.users || []
  } catch (error) {
    console.error('获取经理列表失败:', error)
  }
}

function openAuthorizeModal() {
  if (isAuthorized.value) {
    isAuthorized.value = false
    message.info('已解除授权')
    return
  }
  
  authForm.manager_id = undefined
  authForm.password = ''
  fetchManagers()
  authorizeModalVisible.value = true
}

async function handleAuthorize() {
  if (!authForm.manager_id || !authForm.password) {
    return message.warning('请选择经理并输入密码')
  }

  try {
    authorizing.value = true
    await userApi.authorizeManager({
      manager_id: authForm.manager_id,
      password: authForm.password
    })
    isAuthorized.value = true
    authorizeModalVisible.value = false
    message.success('经理授权成功，您可以签发特权卡')
  } catch (error: any) {
    message.error(error.response?.data?.message || '授权失败')
  } finally {
    authorizing.value = false
  }
}

const cardTypes = [
  {
    key: 'master',
    name: '万能管理卡',
    desc: '具备全店所有客房及公共区域的最高访问权限。',
    authDesc: '全店所有客房及公共区域的最高访问权限',
    icon: SafetyOutlined,
    color: '#f5222d',
    bgColor: '#fff1f0',
    features: ['全域通行', '绕过反锁', '离线生效', '最高优先级']
  },
  {
    key: 'floor',
    name: '楼层管理卡',
    desc: '限定在特定楼层内的所有房间通行权限，适用于楼层主管。',
    authDesc: '特定楼层内所有房间的通行权限',
    icon: KeyOutlined,
    color: '#fa8c16',
    bgColor: '#fff7e6',
    features: ['指定楼层', '常规反锁绕过', '工作时间有效', '多房授权']
  },
  {
    key: 'staff',
    name: '员工工作卡',
    desc: '针对普通员工或外包人员，限定具体房间或区域权限。',
    authDesc: '限定具体房间或区域的通行权限',
    icon: TeamOutlined,
    color: '#1890ff',
    bgColor: '#e6f7ff',
    features: ['精准房号', '时间窗限制', '任务关联', '动态授权']
  },
  {
    key: 'emergency',
    name: '紧急救灾卡',
    desc: '仅在火警或紧急安全事故下使用，强制解除所有电子锁定。',
    authDesc: '强制解除所有电子锁定的紧急通行权限',
    icon: AlertOutlined,
    color: '#722ed1',
    bgColor: '#f9f0ff',
    features: ['最高安全级别', '全门禁常开', '独立审计', '限时自动失效']
  }
]

const floorList = ref<any[]>([])
const allRooms = ref<any[]>([])

async function fetchEncoders() {
  try {
    const res = await deviceApi.getDeviceList({ audit_status: 'approved' })
    if (res.data) {
      const list = res.data.filter(d => 
        d.device_type === 'front_desk' || (d.device_id && d.device_id.startsWith('FRN_'))
      )
      encoders.value = list
      if (list.length > 0 && !selectedEncoder.value) {
        selectedEncoder.value = list[0].device_id
      }
    }
  } catch (error) {
    message.error('获取发卡设备失败')
  }
}

async function fetchMetadata() {
  try {
    const [floorRes, roomRes]: any = await Promise.all([
      request.get('/floors'),
      request.get('/rooms', { params: { pageSize: 500 } })
    ])
    floorList.value = floorRes.data || []
    allRooms.value = roomRes.data?.list || []
  } catch (error) {}
}

const issueModalVisible = ref(false)
const selectedType = ref<any>(null)
const issuing = ref(false)
const issueStep = ref<'form' | 'writing' | 'success' | 'error'>('form')
const issueStatusMsg = ref('')

const issueForm = reactive({
  holder_name: '',
  holder_id: '',
  floors: [],
  rooms: [],
  expiry_date: dayjs().add(1, 'year'),
  remark: '',
  confirm_password: ''
})

function openIssueModal(type: any) {
  if (!isAuthorized.value) {
    return message.warning('签发特权卡需要经理授权')
  }
  if (!selectedEncoder.value) {
    return message.warning('请先在右上角选择发卡器设备')
  }
  selectedType.value = type
  issueStep.value = 'form'
  issueStatusMsg.value = ''
  resetForm()
  issueModalVisible.value = true
}

function resetForm() {
  issueForm.holder_name = ''
  issueForm.holder_id = ''
  issueForm.floors = []
  issueForm.rooms = []
  issueForm.expiry_date = dayjs().add(1, 'year')
  issueForm.remark = ''
  issueForm.confirm_password = ''
}

async function handleIssue() {
  if (issueStep.value === 'success') {
    issueModalVisible.value = false
    return
  }

  if (!isAuthorized.value) {
    return message.error('授权已过期或未授权，请重新进行经理授权')
  }
  if (!issueForm.holder_name || !issueForm.holder_id || !issueForm.confirm_password) {
    return message.warning('请填写完整必要信息并输入确认密码')
  }

  try {
    issuing.value = true
    issueStep.value = 'writing'
    issueStatusMsg.value = '正在向硬件下发写卡指令...'

    const payload = {
      card_type: selectedType.value.key,
      holder_name: issueForm.holder_name,
      holder_id: issueForm.holder_id,
      floors: issueForm.floors,
      rooms: issueForm.rooms,
      expiry_date: issueForm.expiry_date.toISOString(),
      remark: issueForm.remark,
      confirm_password: issueForm.confirm_password,
      encoder_id: selectedEncoder.value,
      auth_manager_id: authForm.manager_id
    }

    const res: any = await request.post('/rfid/issue-privilege', payload)
    
    if (res.data.success) {
      issueStatusMsg.value = '写卡指令已成功接收，请等待设备蜂鸣...'
      
      // 模拟等待硬件反馈的过程
      setTimeout(() => {
        issueStep.value = 'success'
        issueStatusMsg.value = '特权卡签发成功！'
        message.success(`${selectedType.value.name} 签发成功`)
        isAuthorized.value = false // 成功后重置授权
      }, 2000)
    } else {
      issueStep.value = 'error'
      issueStatusMsg.value = res.data.message || '下发指令失败'
    }
  } catch (error: any) {
    issueStep.value = 'error'
    issueStatusMsg.value = error.response?.data?.message || '服务器通信失败'
  } finally {
    issuing.value = false
  }
}

onMounted(() => {
  fetchEncoders()
  fetchMetadata()
})
</script>

<style scoped>
.privilege-card-page {
  padding: 24px;
  background: #f8fafc;
  min-height: calc(100vh - 120px);
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 32px;
}

.page-title {
  font-size: 28px;
  font-weight: 700;
  color: #1e293b;
  margin-bottom: 8px;
}

.page-subtitle {
  color: #64748b;
  font-size: 15px;
  max-width: 600px;
}

.privilege-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 24px;
}

.privilege-item-card {
  border: none;
  border-radius: 20px;
  overflow: hidden;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.privilege-item-card:hover {
  transform: translateY(-8px);
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
}

.privilege-item-card.auth-required {
  opacity: 0.8;
  filter: grayscale(0.2);
}

.card-body {
  padding: 24px;
  display: flex;
  flex-direction: column;
  height: 100%;
}

.auth-modal-content {
  padding: 8px 0;
}

.card-icon-wrapper {
  width: 64px;
  height: 64px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 20px;
}

.type-icon {
  font-size: 32px;
}

.card-info {
  flex: 1;
  margin-bottom: 24px;
}

.type-name {
  font-size: 18px;
  font-weight: 700;
  color: #1e293b;
  margin-bottom: 12px;
}

.type-desc {
  color: #64748b;
  font-size: 14px;
  line-height: 1.6;
  margin-bottom: 16px;
  min-height: 44px;
}

.type-features {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.feature-tag {
  background: #fff;
  border: 1px solid #e2e8f0;
  padding: 4px 10px;
  border-radius: 8px;
  font-size: 12px;
  color: #475569;
  display: flex;
  align-items: center;
  gap: 6px;
}

.card-action {
  margin-top: auto;
}

.issue-form-container {
  padding: 8px 0;
}

.issue-modal-content {
  min-height: 300px;
}

.step-status-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 40px 0;
  text-align: center;
}

.status-animation {
  margin-bottom: 24px;
}

.status-title {
  font-size: 20px;
  font-weight: 600;
  color: #1e293b;
  margin-bottom: 8px;
}

.status-msg {
  color: #64748b;
  font-size: 14px;
}

.hardware-hint {
  margin-top: 24px;
  padding: 12px 16px;
  background: #f0f7ff;
  border-radius: 8px;
  font-size: 13px;
  color: #1d4ed8;
  display: flex;
  align-items: center;
  gap: 10px;
}

:deep(.ant-card-body) {
  padding: 0;
}
</style>
