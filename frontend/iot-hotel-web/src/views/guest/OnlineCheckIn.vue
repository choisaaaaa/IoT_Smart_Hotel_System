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
      <a-step title="填写信息" />
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
      <a-result
        v-if="foundBooking"
        status="success"
        title="找到您的预订！"
        :sub-title="`${foundBooking.guest_name} · ${foundBooking.room_name} · ${foundBooking.check_in} 至 ${foundBooking.check_out}`"
      >
        <template #extra>
          <a-button type="primary" size="large" @click="currentStep = 1">下一步：填写入住信息</a-button>
        </template>
      </a-result>
    </a-card>

    <a-card v-if="currentStep === 1" title="步骤2: 填写入住信息" :bordered="false">
      <a-form :model="checkinForm" layout="vertical" style="max-width: 600px;">
        <a-alert :description="`正在为 ${foundBooking?.guest_name} 办理 ${foundBooking?.room_name} 入住`" style="margin-bottom: 16px;" />
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="真实姓名" required>
              <a-input v-model:value="checkinForm.real_name" placeholder="与证件一致" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="证件类型">
              <a-select v-model:value="checkinForm.id_type">
                <a-select-option value="idcard">身份证</a-select-option>
                <a-select-option value="passport">护照</a-select-option>
              </a-select>
            </a-form-item>
          </a-col>
        </a-row>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="证件号码" required>
              <a-input v-model:value="checkinForm.id_number" placeholder="证件号码" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="预计到达时间">
              <a-time-picker v-model:value="checkinForm.arrival_time" format="HH:mm" style="width: 100%;" placeholder="预计几点到店" />
            </a-form-item>
          </a-col>
        </a-row>
        <a-form-item label="车牌号（可选）">
          <a-input v-model:value="checkinForm.plate_number" placeholder="如需停车请填写" />
        </a-form-item>
        <a-form-item>
          <a-space>
            <a-button type="primary" @click="currentStep = 2">下一步：确认</a-button>
            <a-button @click="currentStep = 0">上一步</a-button>
          </a-space>
        </a-form-item>
      </a-form>
    </a-card>

    <a-card v-if="currentStep === 2" title="步骤3: 确认信息" :bordered="false">
      <a-descriptions :column="1" bordered size="small" style="max-width: 600px;">
        <a-descriptions-item label="预订号">{{ foundBooking?.booking_no }}</a-descriptions-item>
        <a-descriptions-item label="房间">{{ foundBooking?.room_name }}</a-descriptions-item>
        <a-descriptions-item label="入住日期">{{ foundBooking?.check_in }}</a-descriptions-item>
        <a-descriptions-item label="退房日期">{{ foundBooking?.check_out }}</a-descriptions-item>
        <a-descriptions-item label="客人姓名">{{ checkinForm.real_name }}</a-descriptions-item>
        <a-descriptions-item label="证件类型">{{ idTypeLabel(checkinForm.id_type) }}</a-descriptions-item>
        <a-descriptions-item label="证件号码">{{ checkinForm.id_number }}</a-descriptions-item>
        <a-descriptions-item label="预计到达">{{ checkinForm.arrival_time ? dayjs(checkinForm.arrival_time).format('HH:mm') : '未指定' }}</a-descriptions-item>
      </a-descriptions>
      <div style="margin-top: 20px;">
        <a-space>
          <a-button type="primary" size="large" :loading="confirming" @click="confirmCheckin">确认办理入住</a-button>
          <a-button @click="currentStep = 1">返回修改</a-button>
        </a-space>
      </div>
    </a-card>

    <a-result
      v-if="currentStep === 3"
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
          <a-button type="primary" size="large" @click="$router.push('/guest/room')">进入客房服务</a-button>
          <a-button @click="resetAll">返回首页</a-button>
        </a-space>
      </template>
    </a-result>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue'
import { message } from 'ant-design-vue'
import dayjs from 'dayjs'
import { bookingApi } from '@/api/booking'

const currentStep = ref(0)
const searchKey = ref('')
const searching = ref(false)
const confirming = ref(false)
const foundBooking = ref<any>(null)
const roomPin = ref('')

const checkinForm = reactive({
  real_name: '', id_type: 'idcard', id_number: '', arrival_time: null as any, plate_number: ''
})

function idTypeLabel(t: string): string {
  return ({ idcard: '身份证', passport: '护照' } as Record<string, string>)[t] || t
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

async function confirmCheckin() {
  if (!foundBooking.value) {
    message.warning('请先查询预订')
    return
  }
  if (!checkinForm.real_name || !checkinForm.id_number) {
    message.warning('请填写完整实名信息')
    return
  }
  confirming.value = true
  try {
    const res: any = await bookingApi.checkinOnline(foundBooking.value.id, {
      guest_phone: foundBooking.value.guest_phone,
      real_name: checkinForm.real_name,
      id_type: checkinForm.id_type,
      id_number: checkinForm.id_number,
      arrival_time: checkinForm.arrival_time ? dayjs(checkinForm.arrival_time).format('HH:mm') : null,
      plate_number: checkinForm.plate_number
    })
    const payload = res?.data || {}
    roomPin.value = payload.room_pin || ''
    
    const guestInfo = {
      booking_id: foundBooking.value?.id,
      real_name: checkinForm.real_name,
      id_type: checkinForm.id_type,
      id_number: checkinForm.id_number,
      room_id: payload.room_id || foundBooking.value?.room_id,
      room_name: payload.room_name || foundBooking.value?.room_name,
      booking_no: payload.booking_no || foundBooking.value?.booking_no,
      guest_phone: foundBooking.value?.guest_phone,
      check_in_date: new Date().toISOString()
    }
    localStorage.setItem('guest_checkin_info', JSON.stringify(guestInfo))
    
    currentStep.value = 3
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
  Object.assign(checkinForm, { real_name: '', id_type: 'idcard', id_number: '', arrival_time: null, plate_number: '' })
}
</script>
