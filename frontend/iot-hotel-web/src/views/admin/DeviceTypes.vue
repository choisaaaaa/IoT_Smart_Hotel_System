<template>
  <div class="device-types">
    <a-card title="设备类型管理" :bordered="false">
      <template #extra>
        <a-button type="primary" @click="showAddModal">
          <PlusOutlined /> 添加类型
        </a-button>
      </template>

      <a-table
        :columns="columns"
        :data-source="deviceTypes"
        :loading="loading"
        row-key="id"
        size="middle"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'icon'">
            <component :is="record.icon || 'AppstoreOutlined'" style="font-size: 24px;" />
          </template>
          <template v-if="column.key === 'status'">
            <a-switch
              :checked="record.status === 'active'"
              @change="(checked) => toggleStatus(record, checked)"
            />
          </template>
          <template v-if="column.key === 'action'">
            <a-space>
              <a-button type="link" @click="showEditModal(record)">编辑</a-button>
              <a-button type="link" danger @click="deleteType(record.id)">删除</a-button>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

    <!-- 添加/编辑弹窗 -->
    <a-modal
      v-model:open="modalVisible"
      :title="isEdit ? '编辑设备类型' : '添加设备类型'"
      @ok="handleSubmit"
      :confirmLoading="submitting"
    >
      <a-form :model="formData" layout="vertical">
        <a-form-item label="类型名称" required>
          <a-input v-model:value="formData.name" placeholder="如：智能门锁" />
        </a-form-item>
        <a-form-item label="类型标识" required>
          <a-input v-model:value="formData.code" placeholder="如：smart_lock" :disabled="isEdit" />
        </a-form-item>
        <a-form-item label="描述">
          <a-textarea v-model:value="formData.description" rows="3" />
        </a-form-item>
        <a-form-item label="图标">
          <a-input v-model:value="formData.icon" placeholder="如：LockOutlined" />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { PlusOutlined } from '@ant-design/icons-vue'
import { message } from 'ant-design-vue'

const loading = ref(false)
const deviceTypes = ref<any[]>([])
const modalVisible = ref(false)
const isEdit = ref(false)
const submitting = ref(false)

const formData = ref({
  id: undefined as number | undefined,
  name: '',
  code: '',
  description: '',
  icon: 'AppstoreOutlined'
})

const columns = [
  { title: '图标', key: 'icon', width: 80, align: 'center' },
  { title: '类型名称', dataIndex: 'name', key: 'name' },
  { title: '类型标识', dataIndex: 'code', key: 'code' },
  { title: '描述', dataIndex: 'description', key: 'description' },
  { title: '状态', key: 'status', width: 100 },
  { title: '操作', key: 'action', width: 150 }
]

// 模拟数据
const mockData = [
  { id: 1, name: '智能门锁', code: 'smart_lock', description: '客房智能门锁设备', icon: 'LockOutlined', status: 'active' },
  { id: 2, name: '空调控制器', code: 'ac', description: '空调温度控制', icon: 'HeatMapOutlined', status: 'active' },
  { id: 3, name: '灯光控制器', code: 'light', description: '灯光开关和亮度控制', icon: 'BulbOutlined', status: 'active' },
  { id: 4, name: '窗帘控制器', code: 'curtain', description: '窗帘开合控制', icon: 'ColumnWidthOutlined', status: 'active' },
  { id: 5, name: '烟雾探测器', code: 'smoke_detector', description: '烟雾报警检测', icon: 'AlertOutlined', status: 'active' },
  { id: 6, name: '门磁传感器', code: 'door_sensor', description: '门窗开关检测', icon: 'GatewayOutlined', status: 'active' },
  { id: 7, name: '窗户传感器', code: 'window_sensor', description: '窗户开关检测', icon: 'WindowsOutlined', status: 'active' },
  { id: 8, name: '温湿度传感器', code: 'temp_humidity', description: '温度和湿度检测', icon: 'CloudOutlined', status: 'active' }
]

const fetchDeviceTypes = async () => {
  loading.value = true
  try {
    // 模拟API调用
    await new Promise(resolve => setTimeout(resolve, 500))
    deviceTypes.value = mockData
  } catch (error) {
    message.error('获取设备类型失败')
  } finally {
    loading.value = false
  }
}

const showAddModal = () => {
  isEdit.value = false
  formData.value = {
    id: undefined,
    name: '',
    code: '',
    description: '',
    icon: 'AppstoreOutlined'
  }
  modalVisible.value = true
}

const showEditModal = (record: any) => {
  isEdit.value = true
  formData.value = { ...record }
  modalVisible.value = true
}

const handleSubmit = async () => {
  if (!formData.value.name || !formData.value.code) {
    message.error('请填写完整信息')
    return
  }

  submitting.value = true
  try {
    // 模拟API调用
    await new Promise(resolve => setTimeout(resolve, 500))
    
    if (isEdit.value) {
      const index = deviceTypes.value.findIndex(item => item.id === formData.value.id)
      if (index > -1) {
        deviceTypes.value[index] = { ...formData.value }
      }
      message.success('更新成功')
    } else {
      const newId = Math.max(...deviceTypes.value.map(item => item.id)) + 1
      deviceTypes.value.push({
        ...formData.value,
        id: newId,
        status: 'active'
      })
      message.success('添加成功')
    }
    modalVisible.value = false
  } catch (error) {
    message.error('操作失败')
  } finally {
    submitting.value = false
  }
}

const deleteType = async (id: number) => {
  try {
    // 模拟API调用
    await new Promise(resolve => setTimeout(resolve, 300))
    deviceTypes.value = deviceTypes.value.filter(item => item.id !== id)
    message.success('删除成功')
  } catch (error) {
    message.error('删除失败')
  }
}

const toggleStatus = async (record: any, checked: boolean) => {
  try {
    record.status = checked ? 'active' : 'inactive'
    message.success(`已${checked ? '启用' : '禁用'}该设备类型`)
  } catch (error) {
    message.error('操作失败')
  }
}

onMounted(() => {
  fetchDeviceTypes()
})
</script>

<style scoped>
.device-types { padding: 0; }
</style>
