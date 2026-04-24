<template>
  <div class="room-type-manage">
    <a-card title="房型管理" :bordered="false">
      <template #extra>
        <a-button type="primary" @click="handleAdd">
          <template #icon><PlusOutlined /></template>
          添加房型
        </a-button>
      </template>

      <a-table
        :columns="columns"
        :data-source="roomTypes"
        :loading="loading"
        row-key="id"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'action'">
            <a-space>
              <a-button type="link" @click="handleEdit(record)">编辑</a-button>
              <a-popconfirm
                title="确定要删除此房型吗？"
                @confirm="handleDelete(record.id)"
              >
                <a-button type="link" danger>删除</a-button>
              </a-popconfirm>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

    <a-modal
      v-model:open="modalVisible"
      :title="editingId ? '编辑房型' : '添加房型'"
      @ok="handleModalOk"
      :confirm-loading="submitLoading"
    >
      <a-form :model="formState" layout="vertical" ref="formRef">
        <a-form-item
          label="房型名称"
          name="name"
          :rules="[{ required: true, message: '请输入房型名称' }]"
        >
          <a-input v-model:value="formState.name" placeholder="如：豪华大床房" />
        </a-form-item>
        <a-form-item
          label="房型代码"
          name="code"
          :rules="[{ required: true, message: '请输入房型代码' }]"
        >
          <a-input v-model:value="formState.code" placeholder="如：DELUXE_KING" />
        </a-form-item>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item
              label="基础价格"
              name="base_price"
              :rules="[{ required: true, message: '请输入价格' }]"
            >
              <a-input-number v-model:value="formState.base_price" style="width: 100%" :min="0" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="面积 (㎡)" name="area">
              <a-input-number v-model:value="formState.area" style="width: 100%" :min="0" />
            </a-form-item>
          </a-col>
        </a-row>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="床型" name="bed_type">
              <a-select v-model:value="formState.bed_type">
                <a-select-option value="single">单人床</a-select-option>
                <a-select-option value="double">双人床</a-select-option>
                <a-select-option value="king">特大床</a-select-option>
                <a-select-option value="twin">双床</a-select-option>
              </a-select>
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="最大入住人数" name="max_guests">
              <a-input-number v-model:value="formState.max_guests" style="width: 100%" :min="1" />
            </a-form-item>
          </a-col>
        </a-row>
        <a-form-item label="描述" name="description">
          <a-textarea v-model:value="formState.description" :rows="3" />
        </a-form-item>
        <a-form-item label="房型图片" name="images">
          <a-upload
            v-model:file-list="fileList"
            name="image"
            list-type="picture-card"
            :action="uploadUrl"
            :headers="uploadHeaders"
            @change="handleUploadChange"
          >
            <div v-if="fileList.length < 5">
              <plus-outlined />
              <div style="margin-top: 8px">上传图片</div>
            </div>
          </a-upload>
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { PlusOutlined } from '@ant-design/icons-vue'
import { $notify, NotifyPreset } from '@/utils/notify'
import { roomTypeApi } from '@/api/room-type'
import type { RoomTypeInfo } from '@/types'

const columns = [
  { title: '名称', dataIndex: 'name', key: 'name' },
  { title: '代码', dataIndex: 'code', key: 'code' },
  { title: '基础价格', dataIndex: 'base_price', key: 'base_price', customRender: ({ text }: any) => `￥${text}` },
  { title: '面积', dataIndex: 'area', key: 'area', customRender: ({ text }: any) => `${text}㎡` },
  { title: '床型', dataIndex: 'bed_type', key: 'bed_type' },
  { title: '最大人数', dataIndex: 'max_guests', key: 'max_guests' },
  { title: '操作', key: 'action' }
]

const roomTypes = ref<RoomTypeInfo[]>([])
const loading = ref(false)
const modalVisible = ref(false)
const submitLoading = ref(false)
const editingId = ref<number | null>(null)
const formRef = ref()
const fileList = ref<any[]>([])

const uploadUrl = '/api/v1/upload/image'
const uploadHeaders = {
  Authorization: `Bearer ${localStorage.getItem('auth_token')}`
}

const getFullUrl = (url: string) => {
  if (!url) return ''
  if (url.startsWith('http')) return url
  return url.startsWith('/') ? url : '/' + url
}

const formState = reactive<Partial<RoomTypeInfo>>({
  name: '',
  code: '',
  base_price: '0',
  area: 0,
  bed_type: 'single',
  max_guests: 1,
  description: '',
  images: []
})

const fetchRoomTypes = async () => {
  loading.value = true
  try {
    const res = await roomTypeApi.getRoomTypeList()
    roomTypes.value = (res.data as any) || []
  } catch (error) {
    $notify.error({ title: '获取房型列表失败', description: '无法加载房型数据，请稍后重试 🔄' })
  } finally {
    loading.value = false
  }
}

const handleAdd = () => {
  editingId.value = null
  fileList.value = []
  Object.assign(formState, {
    name: '',
    code: '',
    base_price: '0',
    area: 0,
    bed_type: 'single',
    max_guests: 1,
    description: '',
    images: []
  })
  modalVisible.value = true
}

const handleEdit = (record: RoomTypeInfo) => {
  editingId.value = record.id
  Object.assign(formState, record)
  // 设置已上传图片列表
  if (record.images && Array.isArray(record.images)) {
    fileList.value = record.images.map((url, index) => ({
      uid: `-${index}`,
      name: url.split('/').pop(),
      status: 'done',
      url: getFullUrl(url),
      response: { data: { url } }
    }))
  } else {
    fileList.value = []
  }
  modalVisible.value = true
}

const handleUploadChange = (info: any) => {
  if (info.file.status === 'done') {
    $notify.success({ title: '图片上传成功', description: '房型图片已成功上传 🖼️' })
  } else if (info.file.status === 'error') {
    $notify.error({ title: '图片上传失败', description: '上传过程中出现错误，请重试 🖼️' })
  }
}

const handleModalOk = async () => {
  try {
    await formRef.value.validateFields()
    submitLoading.value = true
    
    // 整理图片列表
    formState.images = fileList.value
      .filter(file => file.status === 'done')
      .map(file => file.response?.data?.url || file.url?.replace(getFullUrl(''), ''))

    if (editingId.value) {
      await roomTypeApi.updateRoomType(editingId.value, formState)
      NotifyPreset.profileUpdated('房型信息')
    } else {
      await roomTypeApi.createRoomType(formState)
      $notify.success({ title: '创建房型成功', description: '新房型已成功添加 ✅' })
    }
    modalVisible.value = false
    fetchRoomTypes()
  } catch (error) {
    const err = error as any
    const backendMessage = err?.response?.data?.message || err?.message
    NotifyPreset.operationFailed(backendMessage || '保存失败')
  } finally {
    submitLoading.value = false
  }
}

const handleDelete = async (id: number) => {
  try {
    await roomTypeApi.deleteRoomType(id)
    $notify.success({ title: '删除房型成功', description: '房型已成功从系统中移除 🗑️' })
    fetchRoomTypes()
  } catch (error) {
    NotifyPreset.operationFailed('删除房型失败')
  }
}

onMounted(() => {
  fetchRoomTypes()
})
</script>

<style scoped>
.room-type-manage {
  padding: 0;
}
</style>
