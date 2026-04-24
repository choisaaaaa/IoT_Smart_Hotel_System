<template>
  <div class="floor-manage">
    <a-card title="楼层管理" :bordered="false">
      <template #extra>
        <a-button type="primary" @click="handleAdd">
          <template #icon><PlusOutlined /></template>
          添加楼层
        </a-button>
      </template>

      <a-table
        :columns="columns"
        :data-source="floors"
        :loading="loading"
        row-key="id"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'floor_plan_image'">
            <a-image
              v-if="record.floor_plan_image"
              :width="50"
              :src="getFullUrl(record.floor_plan_image)"
            />
            <span v-else>-</span>
          </template>
          <template v-if="column.key === 'action'">
            <a-space>
              <a-button type="link" @click="handleEdit(record)">编辑</a-button>
              <a-popconfirm
                title="确定要删除此楼层吗？"
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
      :title="editingId ? '编辑楼层' : '添加楼层'"
      @ok="handleModalOk"
      :confirm-loading="submitLoading"
    >
      <a-form :model="formState" layout="vertical" ref="formRef">
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item
              label="楼层号"
              name="floor_number"
              :rules="[{ required: true, message: '请输入楼层号' }]"
            >
              <a-input-number v-model:value="formState.floor_number" style="width: 100%" :min="-5" :max="100" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item
              label="楼层名称"
              name="floor_name"
              :rules="[{ required: true, message: '请输入楼层名称' }]"
            >
              <a-input v-model:value="formState.floor_name" placeholder="如：1楼" />
            </a-form-item>
          </a-col>
        </a-row>
        
        <a-form-item label="楼层平面图" name="floor_plan_image">
          <a-upload
            name="image"
            list-type="picture-card"
            :show-upload-list="false"
            :action="uploadUrl"
            :headers="uploadHeaders"
            @change="handleUploadChange"
          >
            <img v-if="formState.floor_plan_image" :src="getFullUrl(formState.floor_plan_image)" alt="floor plan" style="width: 100%" />
            <div v-else>
              <plus-outlined />
              <div style="margin-top: 8px">上传平面图</div>
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
import { ref, reactive, onMounted } from 'vue'
import { PlusOutlined } from '@ant-design/icons-vue'
import { $notify, NotifyPreset } from '@/utils/notify'
import { floorApi } from '@/api/floor'
import type { FloorInfo } from '@/types'

const columns = [
  { title: '楼层号', dataIndex: 'floor_number', key: 'floor_number', sorter: (a: any, b: any) => a.floor_number - b.floor_number },
  { title: '名称', dataIndex: 'floor_name', key: 'floor_name' },
  { title: '平面图', dataIndex: 'floor_plan_image', key: 'floor_plan_image' },
  { title: '描述', dataIndex: 'description', key: 'description', ellipsis: true },
  { title: '操作', key: 'action' }
]

const floors = ref<FloorInfo[]>([])
const loading = ref(false)
const modalVisible = ref(false)
const submitLoading = ref(false)
const editingId = ref<number | null>(null)
const formRef = ref()

const formState = reactive<Partial<FloorInfo>>({
  floor_number: 1,
  floor_name: '',
  floor_plan_image: '',
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

const fetchFloors = async () => {
  loading.value = true
  try {
    const res = await floorApi.getFloorList()
    floors.value = (res.data as any) || []
  } catch (error) {
    $notify.error({ title: '获取楼层列表失败', description: '无法加载楼层数据，请稍后重试 🔄' })
  } finally {
    loading.value = false
  }
}

const handleAdd = () => {
  editingId.value = null
  Object.assign(formState, {
    floor_number: floors.value.length > 0 ? Math.max(...floors.value.map(f => f.floor_number)) + 1 : 1,
    floor_name: '',
    floor_plan_image: '',
    description: ''
  })
  modalVisible.value = true
}

const handleEdit = (record: FloorInfo) => {
  editingId.value = record.id
  Object.assign(formState, record)
  modalVisible.value = true
}

const handleUploadChange = (info: any) => {
  if (info.file.status === 'done') {
    const res = info.file.response
    if (res.code === 200) {
      formState.floor_plan_image = res.data.url
      $notify.success({ title: '图片上传成功', description: '楼层平面图已成功上传 🖼️' })
    } else {
      $notify.error({ title: '上传失败', description: res.message || '图片上传出现错误 🖼️' })
    }
  } else if (info.file.status === 'error') {
    $notify.error({ title: '图片上传失败', description: '上传过程中出现错误，请重试 🖼️' })
  }
}

const handleModalOk = async () => {
  try {
    await formRef.value.validateFields()
    submitLoading.value = true
    if (editingId.value) {
      await floorApi.updateFloor(editingId.value, formState)
      NotifyPreset.profileUpdated('楼层信息')
    } else {
      await floorApi.createFloor(formState)
      $notify.success({ title: '创建楼层成功', description: '新楼层已成功添加 ✅' })
    }
    modalVisible.value = false
    fetchFloors()
  } catch (error: any) {
    NotifyPreset.operationFailed(error.response?.data?.message || '保存楼层失败')
  } finally {
    submitLoading.value = false
  }
}

const handleDelete = async (id: number) => {
  try {
    await floorApi.deleteFloor(id)
    $notify.success({ title: '删除楼层成功', description: '楼层已成功从系统中移除 🗑️' })
    fetchFloors()
  } catch (error: any) {
    NotifyPreset.operationFailed(error.response?.data?.message || '删除楼层失败')
  }
}

onMounted(() => {
  fetchFloors()
})
</script>

<style scoped>
.floor-manage {
  padding: 0;
}
</style>
