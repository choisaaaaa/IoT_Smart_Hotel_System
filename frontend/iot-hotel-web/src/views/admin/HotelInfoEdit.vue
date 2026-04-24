<template>
  <div class="hotel-info-edit">
    <a-spin :spinning="loading">
      <a-form
        :model="formData"
        layout="vertical"
        style="max-width: 900px;"
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
          <a-row :gutter="20">
            <a-col :span="12">
              <a-form-item label="所在城市">
                <a-input v-model:value="formData.city" placeholder="如 北京" />
              </a-form-item>
            </a-col>
            <a-col :span="12">
              <a-form-item label="位置信息">
                <a-input v-model:value="formData.location" placeholder="如 朝阳区CBD商圈" />
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

        <a-card title="酒店图片管理" size="small" style="margin-top: 16px;">
          <a-tabs v-model:activeKey="activeImageTab">
            <a-tab-pane key="logo" tab="Logo/封面">
              <a-form-item label="酒店Logo">
                <a-upload
                  name="image"
                  list-type="picture-card"
                  :show-upload-list="false"
                  :action="uploadUrl"
                  :headers="uploadHeaders"
                  @change="(info: { file: { status: string; response?: { data: { url: string } } } }) => handleImageUpload(info, 'logo')"
                >
                  <img v-if="formData.logo" :src="getFullUrl(formData.logo)" alt="logo" style="width: 100%; height: 100%; object-fit: cover;" />
                  <div v-else>
                    <PlusOutlined />
                    <div style="margin-top: 8px;">上传Logo</div>
                  </div>
                </a-upload>
                <div class="upload-tip">建议尺寸: 200x200px, 用于列表展示</div>
              </a-form-item>
              <a-form-item label="封面主图">
                <a-upload
                  name="image"
                  list-type="picture-card"
                  :show-upload-list="false"
                  :action="uploadUrl"
                  :headers="uploadHeaders"
                  @change="(info: { file: { status: string; response?: { data: { url: string } } } }) => handleImageUpload(info, 'cover')"
                >
                  <img v-if="formData.image_url" :src="getFullUrl(formData.image_url)" alt="cover" style="width: 100%; height: 100%; object-fit: cover;" />
                  <div v-else>
                    <PlusOutlined />
                    <div style="margin-top: 8px;">上传封面</div>
                  </div>
                </a-upload>
                <div class="upload-tip">建议尺寸: 800x600px, 用于详情页顶部展示</div>
              </a-form-item>
            </a-tab-pane>
            <a-tab-pane key="gallery" tab="门店相册">
              <div class="gallery-section">
                <div class="gallery-header">
                  <a-upload
                    name="image"
                    :show-upload-list="false"
                    :action="uploadUrl"
                    :headers="uploadHeaders"
                    @change="(info: { file: { status: string; response?: { data: { url: string } } } }) => handleGalleryUpload(info)"
                  >
                    <a-button type="primary">
                      <PlusOutlined /> 添加照片
                    </a-button>
                  </a-upload>
                  <span class="upload-tip">支持上传多张门店照片，展示酒店环境</span>
                </div>
                <a-divider />
                <div v-if="hotelImages.length === 0" class="empty-gallery">
                  <a-empty description="暂无门店照片，请点击上方按钮添加" />
                </div>
                <a-row v-else :gutter="[16, 16]" class="gallery-grid">
                  <a-col v-for="(img, index) in hotelImages" :key="img.id" :span="6">
                    <div class="gallery-item">
                      <img :src="getFullUrl(img.image_url)" alt="酒店照片" />
                      <div class="gallery-item-actions">
                        <a-button type="text" danger size="small" @click="deleteImage(img.id)">
                          <DeleteOutlined /> 删除
                        </a-button>
                      </div>
                      <div class="gallery-item-sort">{{ index + 1 }}</div>
                    </div>
                  </a-col>
                </a-row>
              </div>
            </a-tab-pane>
          </a-tabs>
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
import { $notify, NotifyPreset } from '@/utils/notify'
import { Modal } from 'ant-design-vue'
import { SaveOutlined, PlusOutlined, DeleteOutlined } from '@ant-design/icons-vue'
import { useHotelStore } from '@/stores/hotel'
import { hotelManageApi } from '@/api/hotel-manage'
import { hotelApi, HotelImage } from '@/api/hotel'

const hotelStore = useHotelStore()
const loading = ref(false)
const saving = ref(false)
const activeImageTab = ref('logo')
const hotelImages = ref<HotelImage[]>([])
const hotelId = ref<number>(0)

const formData = reactive({
  hotel_name: '', hotel_address: '', hotel_phone: '',
  city: '', location: '',
  starNum: 5, total_rooms: 200, occupancy_rate: 0,
  base_price: 299, default_max_guests: 2,
  checkin_time: null as any, checkout_time: null as any,
  description: '',
  logo: '',
  image_url: ''
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

// 处理Logo和封面图上传
const handleImageUpload = (info: { file: { status: string; response?: { data: { url: string } } } }, type: 'logo' | 'cover') => {
  if (info.file.status === 'uploading') {
    loading.value = true
    return
  }
  if (info.file.status === 'done') {
    const url = info.file.response?.data.url
    if (url) {
      if (type === 'logo') {
        formData.logo = url
      } else {
        formData.image_url = url
      }
      $notify.success({ title: '图片上传成功', description: '图片已成功上传 🖼️' })
    } else {
      $notify.error({ title: '图片上传失败', description: '无效的响应数据，请重试 🔄' })
    }
    loading.value = false
  } else if (info.file.status === 'error') {
    $notify.error({ title: '图片上传失败', description: '上传过程中出现错误，请重试 🖼️' })
    loading.value = false
  }
}

// 处理相册照片上传
const handleGalleryUpload = async (info: { file: { status: string; response?: { data: { url: string } } } }) => {
  if (info.file.status === 'uploading') {
    return
  }
  if (info.file.status === 'done') {
    const url = info.file.response?.data.url
    if (url) {
      try {
        await hotelApi.addHotelImage(hotelId.value, {
          image_url: url,
          image_type: 'gallery',
          sort_order: hotelImages.value.length
        })
        $notify.success({ title: '照片添加成功', description: '相册照片已成功添加 🖼️' })
        loadHotelImages()
      } catch (err) {
        NotifyPreset.operationFailed('照片添加失败')
      }
    } else {
      $notify.error({ title: '图片上传失败', description: '无效的响应数据，请重试 🔄' })
    }
  } else if (info.file.status === 'error') {
    $notify.error({ title: '图片上传失败', description: '上传过程中出现错误，请重试 🖼️' })
  }
}

// 删除照片
const deleteImage = (imageId: number) => {
  Modal.confirm({
    title: '确认删除',
    content: '确定要删除这张照片吗？',
    okText: '删除',
    okType: 'danger',
    cancelText: '取消',
    async onOk() {
      try {
        await hotelApi.deleteHotelImage(hotelId.value, imageId)
        $notify.success({ title: '照片删除成功', description: '相册照片已成功删除 🗑️' })
        loadHotelImages()
      } catch (err) {
        NotifyPreset.operationFailed('照片删除失败')
      }
    }
  })
}

// 加载酒店图片
async function loadHotelImages() {
  if (!hotelId.value) return
  try {
    const images = await hotelApi.getHotelImages(hotelId.value)
    hotelImages.value = images
  } catch (err) {
    console.error('加载酒店图片失败', err)
  }
}

async function loadData() {
  loading.value = true
  try {
    const res: any = await hotelManageApi.getHotelInfo()
    if (res.data) {
      const h = res.data
      hotelId.value = h.id
      Object.assign(formData, {
        hotel_name: h.hotel_name,
        hotel_address: h.hotel_address,
        hotel_phone: h.hotel_phone,
        city: h.city || '',
        location: h.location || '',
        starNum: h.hotel_star,
        total_rooms: h.total_rooms,
        description: h.description,
        logo: h.logo || '',
        image_url: h.image_url || ''
      })
      // 加载图片列表
      await loadHotelImages()
    }
  } catch (err) {
    $notify.error({ title: '加载酒店信息失败', description: '无法加载酒店信息，请稍后重试 🔄' })
  } finally {
    loading.value = false
  }
}

async function handleSave() {
  saving.value = true
  try {
    // 保存酒店基本信息
    await hotelApi.updateHotel(hotelId.value, {
      hotel_name: formData.hotel_name,
      hotel_address: formData.hotel_address,
      hotel_phone: formData.hotel_phone,
      hotel_star: formData.starNum,
      city: formData.city,
      location: formData.location,
      description: formData.description,
      logo: formData.logo,
      image_url: formData.image_url
    })
    NotifyPreset.profileUpdated('酒店信息')
    loadData()
  } catch (err) {
    NotifyPreset.operationFailed('保存酒店信息失败')
  } finally {
    saving.value = false
  }
}

onMounted(loadData)
</script>

<style scoped>
.form-actions { margin-top: 24px; display: flex; gap: 12px; }
.upload-tip {
  color: #999;
  font-size: 12px;
  margin-top: 8px;
}
.gallery-section {
  padding: 16px 0;
}
.gallery-header {
  display: flex;
  align-items: center;
  gap: 16px;
}
.empty-gallery {
  padding: 40px 0;
}
.gallery-grid {
  margin-top: 16px;
}
.gallery-item {
  position: relative;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}
.gallery-item img {
  width: 100%;
  height: 150px;
  object-fit: cover;
  display: block;
}
.gallery-item-actions {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  background: rgba(0,0,0,0.6);
  padding: 8px;
  display: flex;
  justify-content: center;
  opacity: 0;
  transition: opacity 0.3s;
}
.gallery-item:hover .gallery-item-actions {
  opacity: 1;
}
.gallery-item-sort {
  position: absolute;
  top: 8px;
  left: 8px;
  width: 24px;
  height: 24px;
  background: rgba(0,0,0,0.6);
  color: #fff;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
}
</style>
