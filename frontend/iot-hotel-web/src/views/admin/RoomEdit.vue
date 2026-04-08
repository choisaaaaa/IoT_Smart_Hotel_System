<template>
  <div class="room-edit">
    <div class="toolbar">
      <a-space>
        <a-input-search v-model:value="searchKey" placeholder="搜索房号/名称" style="width: 220px;" allow-clear />
      </a-space>
      <a-space>
        <a-button type="primary" @click="showAddModal">
          <template #icon><PlusOutlined /></template>
          新增房间
        </a-button>
        <a-button @click="fetchRooms">
          <template #icon><ReloadOutlined /></template>
          刷新
        </a-button>
      </a-space>
    </div>

    <a-spin :spinning="loading">
      <a-tabs v-model:activeKey="activeFloorTab" type="card">
        <a-tab-pane v-for="floorGroup in groupedRooms" :key="floorGroup.floor" :tab="`${floorGroup.floor} 楼`" class="floor-pane">
          <a-table
            :columns="columns"
            :data-source="filterRooms(floorGroup.rooms)"
            :pagination="false"
            row-key="id"
            size="middle"
          >
            <template #bodyCell="{ column, record }">
              <template v-if="column.key === 'room_status'">
                <a-tag :color="statusColor(record.room_status)">{{ statusText(record.room_status) }}</a-tag>
              </template>
              <template v-if="column.key === 'room_type'">
                <span>{{ record.room_type_name || record.room_type }}</span>
              </template>
              <template v-if="column.key === 'action'">
                <a-space>
                  <a-button type="link" size="small" @click="editRoom(record)">编辑</a-button>
                  <a-popconfirm title="确定删除此房间？" @confirm="handleDelete(record.id)">
                    <a-button type="link" size="small" danger>删除</a-button>
                  </a-popconfirm>
                </a-space>
              </template>
            </template>
          </a-table>
        </a-tab-pane>
      </a-tabs>
      <a-empty v-if="!groupedRooms.length" description="暂无房间数据" />
    </a-spin>

    <a-modal v-model:open="modalVisible" :title="editingId ? '编辑房间' : '新增房间'" @ok="saveRoom" width="600px" :confirmLoading="submitLoading">
      <a-form :model="formModel" layout="vertical" ref="formRef">
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="房号" name="room_number" :rules="[{ required: true, message: '请输入房号' }]">
              <a-input v-model:value="formModel.room_number" placeholder="如 101" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="房型" name="room_type_id" :rules="[{ required: true, message: '请选择房型' }]">
              <a-select v-model:value="formModel.room_type_id" placeholder="选择房型" @change="handleTypeChange">
                <a-select-option v-for="type in roomTypes" :key="type.id" :value="type.id">
                  {{ type.name }}
                </a-select-option>
              </a-select>
            </a-form-item>
          </a-col>
        </a-row>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="楼层" name="floor" :rules="[{ required: true, message: '请输入楼层' }]">
              <a-input-number v-model:value="formModel.floor" :min="1" :max="100" style="width: 100%;" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="状态" name="room_status">
              <a-select v-model:value="formModel.room_status">
                <a-select-option value="available">空闲</a-select-option>
                <a-select-option value="occupied">已入住</a-select-option>
                <a-select-option value="maintenance">维修</a-select-option>
                <a-select-option value="cleaning">清洁</a-select-option>
                <a-select-option value="reserved">已预订</a-select-option>
              </a-select>
            </a-form-item>
          </a-col>
        </a-row>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="价格(元/晚)" name="room_price">
              <a-input-number v-model:value="formModel.room_price" :min="0" :precision="2" style="width: 100%;" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="面积(m²)" name="area">
              <a-input-number v-model:value="formModel.area" :min="0" :precision="2" style="width: 100%;" />
            </a-form-item>
          </a-col>
        </a-row>
        <a-form-item label="描述" name="description">
          <a-textarea v-model:value="formModel.description" :rows="3" />
        </a-form-item>
        <a-form-item label="房间图片" name="images">
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
import { message } from 'ant-design-vue'
import { PlusOutlined, ReloadOutlined } from '@ant-design/icons-vue'
import type { RoomInfo, RoomTypeInfo } from '@/types'
import { roomApi } from '@/api/room'
import { roomTypeApi } from '@/api/room-type'

const loading = ref(false)
const submitLoading = ref(false)
const searchKey = ref('')
const activeFloorTab = ref<number>(1)
const groupedRooms = ref<{ floor: number; rooms: RoomInfo[] }[]>([])
const roomTypes = ref<RoomTypeInfo[]>([])
const modalVisible = ref(false)
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
  return `${window.location.origin.replace(':3001', ':9000')}${url}`
}

const formModel = reactive<Partial<RoomInfo>>({
  room_number: '',
  room_type_id: undefined,
  room_name: '',
  floor: 1,
  area: '0',
  room_price: '0',
  room_status: 'available',
  description: '',
  images: []
})

const columns = [
  { title: '房号', dataIndex: 'room_number', key: 'room_number', width: 100 },
  { title: '房型', dataIndex: 'room_type_name', key: 'room_type', width: 150 },
  { title: '价格', dataIndex: 'room_price', key: 'room_price', width: 120, customRender: ({ text }: any) => `￥${text}` },
  { title: '状态', dataIndex: 'room_status', key: 'room_status', width: 120 },
  { title: '描述', dataIndex: 'description', key: 'description', ellipsis: true },
  { title: '操作', key: 'action', width: 150, fixed: 'right' as const }
]

const fetchRooms = async () => {
  loading.value = true
  try {
    const res = await roomApi.getRoomsByFloor()
    groupedRooms.value = (res.data as any) || []
    if (groupedRooms.value.length > 0 && !groupedRooms.value.find(g => g.floor === activeFloorTab.value)) {
      activeFloorTab.value = groupedRooms.value[0].floor
    }
  } catch (error) {
    message.error('获取房间数据失败')
  } finally {
    loading.value = false
  }
}

const fetchRoomTypes = async () => {
  try {
    const res = await roomTypeApi.getRoomTypeList()
    roomTypes.value = (res.data as any) || []
  } catch (error) {
    message.error('获取房型数据失败')
  }
}

const filterRooms = (rooms: RoomInfo[]) => {
  if (!searchKey.value) return rooms
  const k = searchKey.value.toLowerCase()
  return rooms.filter(r => r.room_number.includes(k) || (r.room_name && r.room_name.toLowerCase().includes(k)))
}

const statusColor = (s: string) => {
  return ({ available: 'success', occupied: 'error', maintenance: 'warning', cleaning: 'processing', reserved: 'default' } as any)[s] || 'default'
}

const statusText = (s: string) => {
  return ({ available: '空闲', occupied: '已入住', maintenance: '维修', cleaning: '清洁', reserved: '已预订' } as any)[s] || s
}

const showAddModal = () => {
  editingId.value = null
  fileList.value = []
  Object.assign(formModel, {
    room_number: '',
    room_type_id: undefined,
    room_name: '',
    floor: 1,
    area: '0',
    room_price: '0',
    room_status: 'available',
    description: '',
    images: []
  })
  modalVisible.value = true
}

const editRoom = (room: RoomInfo) => {
  editingId.value = room.id
  Object.assign(formModel, {
    ...room,
    room_price: Number(room.room_price),
    area: Number(room.area)
  })
  // 设置已上传图片列表
  if (room.images && Array.isArray(room.images)) {
    fileList.value = room.images.map((url, index) => ({
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
    message.success('图片上传成功')
  } else if (info.file.status === 'error') {
    message.error('图片上传失败')
  }
}

const handleTypeChange = (typeId: number) => {
  const type = roomTypes.value.find(t => t.id === typeId)
  if (type) {
    formModel.room_price = Number(type.base_price)
    formModel.area = String(type.area)
    formModel.room_name = type.name
  }
}

const saveRoom = async () => {
  try {
    await formRef.value.validateFields()
    submitLoading.value = true

    // 整理图片列表
    formModel.images = fileList.value
      .filter(file => file.status === 'done')
      .map(file => file.response?.data?.url || file.url?.replace(getFullUrl(''), ''))

    if (editingId.value) {
      await roomApi.updateRoom(editingId.value, formModel)
      message.success('更新房间成功')
    } else {
      await roomApi.createRoom(formModel)
      message.success('创建房间成功')
    }
    modalVisible.value = false
    fetchRooms()
  } catch (error) {
    message.error('保存失败')
  } finally {
    submitLoading.value = false
  }
}

const handleDelete = async (id: number) => {
  try {
    await roomApi.deleteRoom(id)
    message.success('房间已删除')
    fetchRooms()
  } catch (error) {
    message.error('删除失败')
  }
}

onMounted(() => {
  fetchRooms()
  fetchRoomTypes()
})
</script>

<style scoped>
.toolbar { display: flex; justify-content: space-between; margin-bottom: 16px; }
.floor-pane { background: #fff; padding: 0; min-height: 200px; }
</style>
