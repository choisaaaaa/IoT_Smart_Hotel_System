<template>
  <div class="hotel-management">
    <a-card title="酒店维护" :bordered="false">
      <template #extra>
        <a-button type="primary" @click="handleAdd">
          <template #icon><PlusOutlined /></template>
          新增酒店
        </a-button>
      </template>

      <div class="search-bar" style="margin-bottom: 16px;">
        <a-input-search
          v-model:value="searchKey"
          placeholder="搜索酒店名称/编号/城市"
          style="width: 300px"
          allow-clear
        />
      </div>

      <a-table
        :columns="columns"
        :data-source="filteredHotels"
        :loading="loading"
        row-key="id"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'logo'">
            <a-avatar v-if="record.logo" :src="getFullUrl(record.logo)" shape="square" />
            <a-avatar v-else shape="square">{{ record.hotel_name.charAt(0) }}</a-avatar>
          </template>
          <template v-if="column.key === 'star'">
            <a-rate :value="record.hotel_star" disabled style="font-size: 14px" />
          </template>
          <template v-if="column.key === 'action'">
            <a-space>
              <a-button type="link" @click="handleEdit(record)">编辑</a-button>
              <a-popconfirm
                title="确定要删除此酒店吗？这将删除该酒店下的所有数据！"
                @confirm="handleDelete(record.id)"
                ok-text="确定"
                cancel-text="取消"
              >
                <a-button type="link" danger>删除</a-button>
              </a-popconfirm>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

    <!-- 编辑/新增弹窗 -->
    <a-modal
      v-model:open="modalVisible"
      :title="editingId ? '编辑酒店' : '新增酒店'"
      @ok="handleModalOk"
      :confirm-loading="submitLoading"
      width="700px"
    >
      <a-form :model="formState" layout="vertical" ref="formRef">
        <a-row :gutter="16">
          <a-col :span="16">
            <a-form-item label="酒店名称" name="hotel_name" :rules="[{ required: true, message: '请输入酒店名称' }]">
              <a-input v-model:value="formState.hotel_name" />
            </a-form-item>
          </a-col>
          <a-col :span="8">
            <a-form-item label="酒店编号" name="hotel_code" :rules="[{ required: true, message: '请输入酒店编号' }]">
              <a-input v-model:value="formState.hotel_code" placeholder="如：H001" />
            </a-form-item>
          </a-col>
        </a-row>

        <a-row :gutter="16">
          <a-col :span="8">
            <a-form-item label="城市" name="city" :rules="[{ required: true, message: '请输入城市' }]">
              <a-input v-model:value="formState.city" placeholder="如：北京" />
            </a-form-item>
          </a-col>
          <a-col :span="16">
            <a-form-item label="详细地址" name="hotel_address">
              <a-input v-model:value="formState.hotel_address" />
            </a-form-item>
          </a-col>
        </a-row>

        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="联系电话" name="hotel_phone">
              <a-input v-model:value="formState.hotel_phone" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="星级" name="hotel_star">
              <a-select v-model:value="formState.hotel_star">
                <a-select-option :value="1">一星级</a-select-option>
                <a-select-option :value="2">二星级</a-select-option>
                <a-select-option :value="3">三星级</a-select-option>
                <a-select-option :value="4">四星级</a-select-option>
                <a-select-option :value="5">五星级</a-select-option>
              </a-select>
            </a-form-item>
          </a-col>
        </a-row>

        <a-form-item label="酒店 Logo" name="logo">
          <a-upload
            name="image"
            list-type="picture-card"
            :show-upload-list="false"
            :action="uploadUrl"
            :headers="uploadHeaders"
            @change="handleUploadChange"
          >
            <img v-if="formState.logo" :src="getFullUrl(formState.logo)" alt="logo" style="width: 100%" />
            <div v-else>
              <plus-outlined />
              <div style="margin-top: 8px">上传 Logo</div>
            </div>
          </a-upload>
        </a-form-item>

        <a-form-item label="描述" name="description">
          <a-textarea v-model:value="formState.description" :rows="3" />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { PlusOutlined } from '@ant-design/icons-vue'
import { $notify, NotifyPreset } from '@/utils/notify'
import { hotelManageApi, type HotelManageInfo } from '@/api/hotel-manage'

const columns = [
  { title: 'Logo', key: 'logo', width: 80 },
  { title: '编号', dataIndex: 'hotel_code', key: 'hotel_code', width: 100 },
  { title: '名称', dataIndex: 'hotel_name', key: 'hotel_name' },
  { title: '城市', dataIndex: 'city', key: 'city', width: 100 },
  { title: '星级', key: 'star', width: 150 },
  { title: '电话', dataIndex: 'hotel_phone', key: 'hotel_phone', width: 150 },
  { title: '操作', key: 'action', width: 150 }
]

const hotels = ref<HotelManageInfo[]>([])
const loading = ref(false)
const searchKey = ref('')
const modalVisible = ref(false)
const submitLoading = ref(false)
const editingId = ref<number | null>(null)
const formRef = ref()

const formState = reactive<Partial<HotelManageInfo>>({
  hotel_name: '',
  hotel_code: '',
  hotel_address: '',
  city: '',
  hotel_phone: '',
  hotel_star: 3,
  logo: '',
  description: ''
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

const filteredHotels = computed(() => {
  if (!searchKey.value) return hotels.value
  const k = searchKey.value.toLowerCase()
  return hotels.value.filter(h => 
    h.hotel_name.toLowerCase().includes(k) || 
    h.hotel_code?.toLowerCase().includes(k) || 
    h.city?.toLowerCase().includes(k)
  )
})

const fetchHotels = async () => {
  loading.value = true
  try {
    const res: any = await hotelManageApi.getAllHotels()
    hotels.value = res.data || []
  } catch (error) {
    NotifyPreset.operationFailed('获取酒店列表失败')
  } finally {
    loading.value = false
  }
}

const handleAdd = () => {
  editingId.value = null
  Object.assign(formState, {
    hotel_name: '',
    hotel_code: '',
    hotel_address: '',
    city: '',
    hotel_phone: '',
    hotel_star: 3,
    logo: '',
    description: ''
  })
  modalVisible.value = true
}

const handleEdit = (record: HotelManageInfo) => {
  editingId.value = record.id
  Object.assign(formState, record)
  modalVisible.value = true
}

const handleUploadChange = (info: any) => {
  if (info.file.status === 'done') {
    const res = info.file.response
    if (res.code === 200) {
      formState.logo = res.data.url
      $notify.success({ title: '上传成功', description: '图片已上传成功 📷' })
    }
  }
}

const handleModalOk = async () => {
  try {
    await formRef.value.validateFields()
    submitLoading.value = true
    if (editingId.value) {
      await hotelManageApi.updateHotelInfo(editingId.value, formState)
      $notify.success({ title: '更新成功', description: '酒店信息已更新 ✅' })
    } else {
      await hotelManageApi.createHotel(formState)
      $notify.success({ title: '创建成功', description: '新酒店已创建成功 🏨' })
    }
    modalVisible.value = false
    fetchHotels()
  } catch (error: any) {
    NotifyPreset.operationFailed(error.response?.data?.message || '保存失败')
  } finally {
    submitLoading.value = false
  }
}

const handleDelete = async (id: number) => {
  try {
    await hotelManageApi.deleteHotel(id)
    $notify.success({ title: '删除成功', description: '酒店已删除 🗑️' })
    fetchHotels()
  } catch (error) {
    NotifyPreset.operationFailed('删除酒店失败')
  }
}

onMounted(() => {
  fetchHotels()
})
</script>

<style scoped>
.hotel-management { padding: 0; }
</style>
