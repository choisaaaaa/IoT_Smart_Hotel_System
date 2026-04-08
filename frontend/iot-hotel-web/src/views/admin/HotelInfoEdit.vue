<template>
  <div class="hotel-info-edit">
    <a-spin :spinning="loading">
      <a-form
        :model="formData"
        layout="vertical"
        style="max-width: 700px;"
      >
        <a-card title="酒店基本信息" size="small">
          <a-row :gutter="20">
            <a-col :span="12">
              <a-form-item label="酒店名称" required>
                <a-input v-model:value="formData.hotel_name" placeholder="请输入酒店名称" />
              </a-form-item>
            </a-col>
            <a-col :span="12">
              <a-form-item label="酒店星级">
                <a-rate v-model:value="formData.starNum" allow-half />
              </a-form-item>
            </a-col>
          </a-row>
          <a-row :gutter="20">
            <a-col :span="12">
              <a-form-item label="联系电话">
                <a-input v-model:value="formData.hotel_phone" placeholder="如 010-12345678" />
              </a-form-item>
            </a-col>
            <a-col :span="12">
              <a-form-item label="总房间数">
                <a-input-number v-model:value="formData.total_rooms" :min="1" style="width: 100%;" />
              </a-form-item>
            </a-col>
          </a-row>
          <a-form-item label="酒店地址">
            <a-textarea v-model:value="formData.hotel_address" :rows="2" placeholder="详细地址" />
          </a-form-item>
          <a-form-item label="酒店简介">
            <a-textarea v-model:value="formData.description" :rows="4" placeholder="酒店介绍、特色服务等" />
          </a-form-item>
        </a-card>

        <a-card title="运营设置" size="small" style="margin-top: 16px;">
          <a-row :gutter="20">
            <a-col :span="12">
              <a-form-item label="默认房价基数">
                <a-input-number v-model:value="formData.base_price" :min="0" :precision="2" addon-after="元/晚" style="width: 100%;" />
              </a-form-item>
            </a-col>
            <a-col :span="12">
              <a-form-item label="最大入住人数(每间)">
                <a-input-number v-model:value="formData.default_max_guests" :min="1" :max="10" style="width: 100%;" />
              </a-form-item>
            </a-col>
          </a-row>
          <a-form-item label="服务时间">
            <a-time-picker v-model:value="formData.checkin_time" format="HH:mm" placeholder="最早入住" style="margin-right: 12px;" />
            <span>至</span>
            <a-time-picker v-model:value="formData.checkout_time" format="HH:mm" placeholder="最晚退房" style="margin-left: 12px;" />
          </a-form-item>
          <a-form-item label="Logo 图片">
            <a-upload
              name="image"
              list-type="picture-card"
              :show-upload-list="false"
              :action="uploadUrl"
              :headers="uploadHeaders"
              @change="handleUploadChange"
            >
              <img v-if="formData.logo" :src="getFullUrl(formData.logo)" alt="logo" style="width: 100%" />
              <div v-else>
                <PlusOutlined />
                <div style="margin-top: 8px;">上传</div>
              </div>
            </a-upload>
          </a-form-item>
        </a-card>

        <div class="form-actions">
          <a-button type="primary" size="large" @click="handleSave" :loading="saving">
            <SaveOutlined /> 保存修改
          </a-button>
          <a-button size="large" @click="loadData">重置</a-button>
        </div>
      </a-form>
    </a-spin>
  </div>
</template>

<script setup lang="ts">
import { reactive, ref, onMounted } from 'vue'
import { message } from 'ant-design-vue'
import { SaveOutlined, PlusOutlined } from '@ant-design/icons-vue'
import { useHotelStore } from '@/stores/hotel'
import { hotelManageApi } from '@/api/hotel-manage'

const hotelStore = useHotelStore()
const loading = ref(false)
const saving = ref(false)

const formData = reactive({
  hotel_name: '', hotel_address: '', hotel_phone: '',
  starNum: 5, total_rooms: 200, occupancy_rate: 0,
  base_price: 299, default_max_guests: 2,
  checkin_time: null as any, checkout_time: null as any,
  description: '',
  logo: ''
})

const uploadUrl = '/api/v1/upload/image'
const uploadHeaders = {
  Authorization: `Bearer ${localStorage.getItem('auth_token')}`
}

const getFullUrl = (url: string) => {
  if (!url) return ''
  if (url.startsWith('http')) return url
  return url.startsWith('/') ? url : '/' + url
}

const handleUploadChange = (info: any) => {
  if (info.file.status === 'uploading') {
    loading.value = true
    return
  }
  if (info.file.status === 'done') {
    formData.logo = info.file.response.data.url
    message.success('图片上传成功')
    loading.value = false
  } else if (info.file.status === 'error') {
    message.error('图片上传失败')
    loading.value = false
  }
}

async function loadData() {
  loading.value = true
  try {
    const res: any = await hotelManageApi.getHotelInfo()
    if (res.data) {
      const h = res.data
      Object.assign(formData, {
        hotel_name: h.hotel_name,
        hotel_address: h.hotel_address,
        hotel_phone: h.hotel_phone,
        starNum: h.hotel_star,
        total_rooms: h.total_rooms,
        description: h.description,
        logo: h.logo || ''
      })
    }
  } catch (err) {
    message.error('加载酒店信息失败')
  } finally {
    loading.value = false
  }
}

async function handleSave() {
  saving.value = true
  try {
    await hotelManageApi.updateHotelInfo(null, {
      hotel_name: formData.hotel_name,
      hotel_address: formData.hotel_address,
      hotel_phone: formData.hotel_phone,
      hotel_star: formData.starNum,
      total_rooms: formData.total_rooms,
      description: formData.description,
      logo: formData.logo
    })
    message.success('酒店信息已保存成功')
    loadData()
  } catch (err) {
    // 错误已由拦截器处理
  } finally {
    saving.value = false
  }
}

onMounted(loadData)
</script>

<style scoped>
.form-actions { margin-top: 24px; display: flex; gap: 12px; }
</style>
