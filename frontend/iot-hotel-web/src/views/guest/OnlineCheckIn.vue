<template>
  <div class="online-checkin">
    <a-alert
      message="在线办理入住"
      description="如果您已完成预订，可在此提前办理入住手续，到店后直接领取房卡即可。线下办理请前往酒店前台。"
      type="info"
      show-icon
      style="margin-bottom: 20px;"
    />

    <a-steps :current="currentStep" style="margin-bottom: 32px;">
      <a-step title="验证预订" />
      <a-step title="选择房间" />
      <a-step title="确认提交" />
      <a-step title="办理完成" />
    </a-steps>

    <a-card v-if="currentStep === 0" title="步骤1: 验证预订信息" :bordered="false">
      <a-form layout="vertical" style="max-width: 500px;">
        <a-form-item label="预订号 / 手机号" required>
          <a-input-search
            v-model:value="searchKey"
            placeholder="输入预订号或预留手机号"
            enter-button="查询"
            size="large"
            @search="searchBooking"
            :loading="searching"
          />
        </a-form-item>
      </a-form>
      <a-empty v-if="!foundBooking && !searching" description="请输入预订号或手机号查询您的预订" />
      <div v-if="foundBooking" class="booking-found-container animate__animated animate__fadeIn">
        <a-alert
          message="找到您的预订！"
          type="success"
          show-icon
          style="margin-bottom: 24px;"
        />
        
        <a-card class="booking-detail-card" :bordered="true">
          <template #title>
            <span style="font-weight: bold; color: #1890ff;">
              <audit-outlined style="margin-right: 8px;" />预订详情
            </span>
          </template>
          
          <a-descriptions :column="1" size="middle" :label-style="{ color: '#8c8c8c' }" :content-style="{ fontWeight: '500' }">
            <a-descriptions-item label="入住人">
              {{ foundBooking.guest_name }}
            </a-descriptions-item>
            <a-descriptions-item label="房型信息">
              <a-tag color="blue">{{ foundBooking.room_name }}</a-tag>
            </a-descriptions-item>
            <a-descriptions-item label="预订时间">
              <div class="booking-dates-display">
                <div class="date-item">
                  <span class="date-label">入住：</span>
                  <span class="date-value">{{ formatDate(foundBooking.check_in) }}</span>
                </div>
                <div class="date-divider">至</div>
                <div class="date-item">
                  <span class="date-label">离店：</span>
                  <span class="date-value">{{ formatDate(foundBooking.check_out) }}</span>
                </div>
              </div>
            </a-descriptions-item>
            <a-descriptions-item label="订单号">
              {{ foundBooking.booking_no }}
            </a-descriptions-item>
          </a-descriptions>

        <div v-if="foundBooking.status === 'pending'" style="margin-top: 16px;">
          <a-alert
            message="订单未支付"
            description="您的订单尚未支付，请先完成支付后再进行在线选房。您可以前往“我的订单”页面完成支付。"
            type="warning"
            show-icon
          >
            <template #action>
              <a-button size="small" type="primary" @click="$router.push('/guest/orders')">前往我的订单</a-button>
            </template>
          </a-alert>
        </div>

        <div v-else style="margin-top: 24px; text-align: center;">
          <a-button type="primary" size="large" block @click="goToSelectRoom">
            下一步：选择房间
          </a-button>
        </div>
        </a-card>
      </div>
    </a-card>

    <a-card v-if="currentStep === 1" title="步骤2: 选择您心仪的房间" :bordered="false">
      <div class="room-selection-container">
        <a-alert :message="`您预订的是 ${foundBooking?.room_name}，请在下方选择一间空房：`" type="info" show-icon style="margin-bottom: 20px;" />
        
        <div v-if="loadingRooms" style="text-align: center; padding: 40px;">
          <a-spin tip="正在查询空房..." />
        </div>
        
        <div v-else-if="availableRooms.length === 0">
          <a-empty description="抱歉，当前暂无该房型的空余房间，请联系前台处理。" />
          <div style="text-align: center; margin-top: 20px;">
            <a-button @click="currentStep = 0">返回</a-button>
          </div>
        </div>
        
        <div v-else>
          <div class="room-grid-guest">
            <div
              v-for="room in availableRooms"
              :key="room.id"
              class="room-tile-guest"
              :class="{ active: selectedRoomId === room.id }"
              @click="selectRoom(room)"
            >
              <div class="room-num">{{ room.room_number }}</div>
              <div class="room-floor">{{ room.floor }}层</div>
            </div>
          </div>

          <div v-if="selectedRoomId" class="floor-plan-section animate__animated animate__fadeIn">
            <a-divider>楼层平面图参考</a-divider>
            <div v-if="currentFloorPlan" class="floor-plan-wrapper">
              <img :src="getFullUrl(currentFloorPlan)" alt="Floor Plan" class="floor-plan-img" />
              <div class="floor-plan-tip">提示：您选择的 {{ selectedRoomNumber }} 号房位于 {{ selectedFloorNumber }} 层</div>
            </div>
            <a-empty v-else description="该楼层暂未上传平面图" />
          </div>

          <div style="margin-top: 32px; text-align: center;">
            <a-space>
              <a-button type="primary" size="large" :disabled="!selectedRoomId" @click="currentStep = 2">确认房间并继续</a-button>
              <a-button size="large" @click="currentStep = 0">返回上一步</a-button>
            </a-space>
          </div>
        </div>
      </div>
    </a-card>

    <a-card v-if="currentStep === 2" title="步骤3: 填写入住信息" :bordered="false">
      <a-form layout="vertical" style="max-width: 500px;">
        <a-form-item label="真实姓名" required>
          <a-input v-model:value="checkinForm.real_name" placeholder="请输入与证件一致的真实姓名" size="large" />
        </a-form-item>
        <a-form-item label="证件类型" required>
          <a-select v-model:value="checkinForm.id_type" size="large">
            <a-select-option value="idcard">身份证/永居证/居住证</a-select-option>
            <a-select-option value="hkm_pass">港澳居民来往内地通行证</a-select-option>
            <a-select-option value="taiwan_pass">台湾居民来往大陆通行证</a-select-option>
            <a-select-option value="passport">外国护照</a-select-option>
            <a-select-option value="other">其他</a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item label="证件号码" required :validate-status="idNumberError ? 'error' : ''" :help="idNumberError">
          <a-input
            v-model:value="checkinForm.id_number"
            :placeholder="checkinForm.id_type === 'idcard' ? '请输入18位身份证号' : '请输入证件号码'"
            :maxlength="checkinForm.id_type === 'idcard' ? 18 : undefined"
            size="large"
            @change="validateIdNumber"
          />
        </a-form-item>
      </a-form>
      <a-descriptions :column="1" bordered size="small" style="max-width: 600px; margin-top: 16px;">
        <a-descriptions-item label="预订号">{{ foundBooking?.booking_no }}</a-descriptions-item>
        <a-descriptions-item label="房型">{{ foundBooking?.room_name }}</a-descriptions-item>
        <a-descriptions-item label="选定房号">{{ selectedRoomNumber }}</a-descriptions-item>
        <a-descriptions-item label="入住日期">{{ formatDate(foundBooking?.check_in) }}</a-descriptions-item>
        <a-descriptions-item label="退房日期">{{ formatDate(foundBooking?.check_out) }}</a-descriptions-item>
      </a-descriptions>
      <div style="margin-top: 24px;">
        <a-alert message="信息确认" description="请确保填写的信息准确，到店后需出示有效证件核实。如信息有误可能影响入住。" type="warning" show-icon style="margin-bottom: 20px;" />
        <a-space>
          <a-button type="primary" size="large" :loading="confirming" @click="confirmCheckin">确认办理入住</a-button>
          <a-button size="large" @click="currentStep = 1">返回修改</a-button>
        </a-space>
      </div>
    </a-card>

    <a-result
      v-if="currentStep === 4"
      status="success"
      title="🎉 在线入住办理成功！"
      sub-title="您的房间已准备就绪，到店后请向前台出示此页面领取房卡。"
    >
      <template #extra>
        <a-space direction="vertical" :size="12">
          <a-card size="small" style="text-align: center;">
            <p style="font-size: 14px;">入住房间</p>
            <h2 style="color: #1890ff; margin: 4px 0;">{{ foundBooking?.room_name }}</h2>
            <p style="color: rgba(0,0,0,0.45);">房卡密码：{{ roomPin }}</p>
          </a-card>
          <a-button @click="resetAll">返回首页</a-button>
        </a-space>
      </template>
    </a-result>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, computed } from 'vue'
import { AuditOutlined } from '@ant-design/icons-vue'
import { message } from 'ant-design-vue'
import { useRoute } from 'vue-router'
import { formatDate } from '@/utils/date'
import { bookingApi } from '@/api/booking'
import { roomApi } from '@/api/room'
import { floorApi } from '@/api/floor'
import { useAppStore } from '@/stores/app'
import type { RoomInfo, FloorInfo } from '@/types'

const route = useRoute()
const appStore = useAppStore()
const currentStep = ref(0)
const searchKey = ref('')
const searching = ref(false)
const confirming = ref(false)
const foundBooking = ref<any>(null)
const roomPin = ref('')

// 选房相关
const availableRooms = ref<RoomInfo[]>([])
const loadingRooms = ref(false)
const selectedRoomId = ref<number | null>(null)
const selectedRoomNumber = ref('')
const selectedFloorNumber = ref<number | null>(null)
const floors = ref<FloorInfo[]>([])

const currentFloorPlan = computed(() => {
  if (!selectedFloorNumber.value) return ''
  const floor = floors.value.find(f => f.floor_number === selectedFloorNumber.value)
  return floor?.floor_plan_image || ''
})

// 页面加载时
onMounted(async () => {
  const bookingNo = route.query.booking_no as string
  if (bookingNo) {
    searchKey.value = bookingNo
    await searchBooking()
  } else if (appStore.userInfo?.phone) {
    searchKey.value = appStore.userInfo.phone
    await searchBooking()
  }
})

const checkinForm = reactive({
  real_name: '', id_type: 'idcard', id_number: '', arrival_time: null as any, plate_number: ''
})

const idNumberError = ref('')

function validateIdNumber() {
  const idNumber = checkinForm.id_number.trim()
  if (!idNumber) {
    idNumberError.value = '请输入证件号码'
    return false
  }
  if (checkinForm.id_type === 'idcard') {
    if (idNumber.length !== 18) {
      idNumberError.value = '身份证号应为18位'
      return false
    }
    if (!/^\d{17}[\dXx]$/.test(idNumber)) {
      idNumberError.value = '身份证号格式不正确'
      return false
    }
  } else if (idNumber.length < 5) {
    idNumberError.value = '证件号码至少5位'
    return false
  }
  idNumberError.value = ''
  return true
}

function idTypeLabel(t: string): string {
  const labels: Record<string, string> = {
    idcard: '身份证/永居证/居住证',
    hkm_pass: '港澳居民来往内地通行证',
    taiwan_pass: '台湾居民来往大陆通行证',
    passport: '外国护照',
    other: '其他'
  }
  return labels[t] || t
}

const getFullUrl = (url: string) => {
  if (!url) return ''
  if (url.startsWith('http')) return url
  return url.startsWith('/') ? url : '/' + url
}

async function searchBooking() {
  if (!searchKey.value.trim()) { message.warning('请输入查询内容'); return }
  searching.value = true
  try {
    const res: any = await bookingApi.lookupBooking(searchKey.value.trim())
    foundBooking.value = res?.data || null
    if (!foundBooking.value) {
      message.error('未找到匹配的预订')
      return
    }
    checkinForm.real_name = foundBooking.value.guest_name
    checkinForm.id_number = ''
    message.success('找到预订记录')
  } catch (error: any) {
    if (error?.response?.status === 404) {
      message.error('未找到匹配的预订')
      return
    }
    message.error('查询失败，请稍后重试')
  } finally {
    searching.value = false
  }
}

async function goToSelectRoom() {
  if (!foundBooking.value) return
  currentStep.value = 1
  loadingRooms.value = true
  try {
    // 同时获取楼层信息和房间信息
    console.log('Fetching rooms for booking:', {
      hotel_id: foundBooking.value.hotel_id,
      room_type_id: foundBooking.value.room_type_id,
      room_name: foundBooking.value.room_name
    })
    const [roomRes, floorRes, currentRoomRes]: any = await Promise.all([
      roomApi.getRoomList({
        status: 'available',
        hotel_id: foundBooking.value.hotel_id,
        room_type_id: foundBooking.value.room_type_id,
        pageSize: 100
      }),
      floorApi.getFloorList({
        hotel_id: foundBooking.value.hotel_id
      }),
      foundBooking.value.room_id ? roomApi.getRoomDetail(foundBooking.value.room_id).catch(() => null) : Promise.resolve(null)
    ])
    
    let rooms = roomRes.data?.list || []
    if (currentRoomRes?.data) {
      // 如果当前房间不在列表中（因为它是 reserved 状态），则手动添加进去
      const exists = rooms.some((r: any) => r.id === currentRoomRes.data.id)
      if (!exists) {
        rooms.push(currentRoomRes.data)
      }
      // 默认选中当前房间
      selectedRoomId.value = currentRoomRes.data.id
      selectedRoomNumber.value = currentRoomRes.data.room_number
      selectedFloorNumber.value = currentRoomRes.data.floor
    }
    
    availableRooms.value = rooms
    console.log('Available rooms found:', availableRooms.value.length)
    floors.value = floorRes.data?.list || floorRes.data || []
  } catch (e) {
    message.error('加载房间或楼层信息失败')
  } finally {
    loadingRooms.value = false
  }
}

function selectRoom(room: RoomInfo) {
  selectedRoomId.value = room.id
  selectedRoomNumber.value = room.room_number
  selectedFloorNumber.value = room.floor
}

async function confirmCheckin() {
  if (!foundBooking.value) {
    message.warning('请先查询预订')
    return
  }
  if (!selectedRoomId.value) {
    message.warning('请先选择房间')
    return
  }
  if (!checkinForm.real_name.trim()) {
    message.warning('请填写真实姓名')
    return
  }
  if (!validateIdNumber()) {
    message.warning(idNumberError.value || '请输入正确的证件号码')
    return
  }
  confirming.value = true
  try {
    const res: any = await bookingApi.checkinOnline(foundBooking.value.id, {
      guest_phone: foundBooking.value.guest_phone,
      real_name: checkinForm.real_name.trim(),
      id_type: checkinForm.id_type,
      id_number: checkinForm.id_number.trim(),
      room_id: selectedRoomId.value
    })
    const payload = res?.data || {}
    roomPin.value = payload.room_pin || ''
    
    const guestInfo = {
      booking_id: foundBooking.value?.id,
      real_name: checkinForm.real_name.trim(),
      id_type: checkinForm.id_type,
      id_number: checkinForm.id_number.trim(),
      room_id: selectedRoomId.value,
      room_name: payload.room_name || foundBooking.value?.room_name,
      room_number: selectedRoomNumber.value,
      booking_no: payload.booking_no || foundBooking.value?.booking_no,
      guest_phone: foundBooking.value?.guest_phone,
      check_in_date: new Date().toISOString()
    }
    localStorage.setItem('guest_checkin_info', JSON.stringify(guestInfo))
    
    currentStep.value = 4
    message.success('入住办理成功！')
  } catch (error: any) {
    message.error(error?.response?.data?.message || '办理失败，请稍后重试')
  } finally {
    confirming.value = false
  }
}

function resetAll() {
  currentStep.value = 0
  searchKey.value = ''
  foundBooking.value = null
  selectedRoomId.value = null
  selectedRoomNumber.value = ''
  selectedFloorNumber.value = null
  Object.assign(checkinForm, { real_name: '', id_type: 'idcard', id_number: '', arrival_time: null, plate_number: '' })
}
</script>

<style scoped>
.online-checkin {
  max-width: 900px;
  margin: 0 auto;
  padding: 20px;
}

.booking-found-container {
  max-width: 500px;
  margin: 0 auto;
}

.booking-detail-card {
  border-radius: 12px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.05);
  overflow: hidden;
}

.booking-dates-display {
  display: flex;
  align-items: center;
  gap: 12px;
  background: #f9f9f9;
  padding: 12px;
  border-radius: 8px;
  margin-top: 4px;
}

.date-item {
  display: flex;
  flex-direction: column;
}

.date-label {
  font-size: 12px;
  color: #8c8c8c;
}

.date-value {
  font-size: 15px;
  font-weight: 600;
  color: #262626;
}

.date-divider {
  color: #bfbfbf;
  font-size: 12px;
}

.room-grid-guest {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(100px, 1fr));
  gap: 12px;
  margin-top: 16px;
}

.room-tile-guest {
  background: #f5f5f5;
  border: 2px solid transparent;
  border-radius: 8px;
  padding: 16px;
  text-align: center;
  cursor: pointer;
  transition: all 0.3s;
}

.room-tile-guest:hover {
  background: #e6f7ff;
  border-color: #91d5ff;
}

.room-tile-guest.active {
  background: #e6f7ff;
  border-color: #1890ff;
  box-shadow: 0 4px 12px rgba(24, 144, 255, 0.2);
}

.room-tile-guest .room-num {
  font-size: 20px;
  font-weight: bold;
  color: #262626;
}

.room-tile-guest .room-floor {
  font-size: 12px;
  color: #8c8c8c;
  margin-top: 4px;
}

.room-tile-guest.active .room-num {
  color: #1890ff;
}

.floor-plan-section {
  margin-top: 40px;
  padding: 20px;
  background: #fff;
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.06);
}

.floor-plan-wrapper {
  text-align: center;
}

.floor-plan-img {
  max-width: 100%;
  max-height: 400px;
  border-radius: 8px;
  border: 1px solid #f0f0f0;
}

.floor-plan-tip {
  margin-top: 12px;
  color: #8c8c8c;
  font-size: 13px;
}
</style>
