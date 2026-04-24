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
        row-key="code"
        size="middle"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'icon'">
            <component :is="record.icon || 'AppstoreOutlined'" style="font-size: 24px;" />
          </template>
          <template v-if="column.key === 'count'">
            <a-badge :count="record.count" :number-style="{ backgroundColor: '#1890ff' }" :overflow-count="999" />
          </template>
          <template v-if="column.key === 'action'">
            <a-space>
              <a-button type="link" @click="showEditModal(record)">编辑</a-button>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

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
import { $notify, NotifyPreset } from '@/utils/notify'
import request from '@/api/request'

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

const typeConfig: Record<string, { name: string; description: string; icon: string }> = {
  smart_lock: { name: '智能门锁', description: '客房智能门锁设备', icon: 'LockOutlined' },
  ac: { name: '空调控制器', description: '空调温度控制', icon: 'HeatMapOutlined' },
  light: { name: '灯光控制器', description: '灯光开关和亮度控制', icon: 'BulbOutlined' },
  curtain: { name: '窗帘控制器', description: '窗帘开合控制', icon: 'ColumnWidthOutlined' },
  smoke_detector: { name: '烟雾探测器', description: '烟雾报警检测', icon: 'AlertOutlined' },
  door_sensor: { name: '门磁传感器', description: '门窗开关检测', icon: 'GatewayOutlined' },
  window_sensor: { name: '窗户传感器', description: '窗户开关检测', icon: 'WindowsOutlined' },
  temp_humidity: { name: '温湿度传感器', description: '温度和湿度检测', icon: 'CloudOutlined' },
  sensor: { name: '传感器', description: '通用环境传感器', icon: 'CloudOutlined' },
  thermostat: { name: '温控器', description: '温度控制设备', icon: 'HeatMapOutlined' },
  tv: { name: '智能电视', description: '客房电视控制', icon: 'VideoCameraOutlined' },
  humidifier: { name: '加湿器', description: '湿度调节设备', icon: 'CloudOutlined' }
}

const columns = [
  { title: '图标', key: 'icon', width: 80, align: 'center' },
  { title: '类型名称', dataIndex: 'name', key: 'name' },
  { title: '类型标识', dataIndex: 'code', key: 'code' },
  { title: '描述', dataIndex: 'description', key: 'description' },
  { title: '设备数量', key: 'count', width: 100 },
  { title: '操作', key: 'action', width: 100 }
]

const fetchDeviceTypes = async () => {
  loading.value = true
  try {
    const res: any = await request.get('/devices')
    if (res.data?.code === 200 || res.data) {
      const data = res.data?.data ?? res.data
      let deviceList: any[] = []
      if (Array.isArray(data)) {
        deviceList = data
      } else if (data?.list) {
        deviceList = data.list
      }

      const typeMap = new Map<string, number>()
      deviceList.forEach((d: any) => {
        const type = d.device_type || d.type || 'unknown'
        typeMap.set(type, (typeMap.get(type) || 0) + 1)
      })

      deviceTypes.value = Array.from(typeMap.entries()).map(([code, count]) => {
        const config = typeConfig[code] || { name: code, description: '', icon: 'AppstoreOutlined' }
        return {
          code,
          name: config.name,
          description: config.description,
          icon: config.icon,
          count,
          status: 'active'
        }
      })
    }
  } catch (error) {
    $notify.error({ title: '获取设备类型失败', description: '无法加载设备类型列表，请稍后重试 🔄' })
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
    $notify.error({ title: '信息不完整', description: '请填写设备类型名称和编码 📋' })
    return
  }

  submitting.value = true
  try {
    if (isEdit.value) {
      const index = deviceTypes.value.findIndex(item => item.code === formData.value.code)
      if (index > -1) {
        deviceTypes.value[index] = { ...deviceTypes.value[index], ...formData.value }
      }
      NotifyPreset.profileUpdated('设备类型')
    } else {
      typeConfig[formData.value.code] = {
        name: formData.value.name,
        description: formData.value.description || '',
        icon: formData.value.icon || 'AppstoreOutlined'
      }
      deviceTypes.value.push({
        ...formData.value,
        count: 0,
        status: 'active'
      })
      $notify.success({ title: '添加成功', description: '新设备类型已成功添加 ✅' })
    }
    modalVisible.value = false
  } catch (error) {
    NotifyPreset.operationFailed()
  } finally {
    submitting.value = false
  }
}

onMounted(() => {
  fetchDeviceTypes()
})
</script>

<style scoped>
.device-types { padding: 0; }
</style>
