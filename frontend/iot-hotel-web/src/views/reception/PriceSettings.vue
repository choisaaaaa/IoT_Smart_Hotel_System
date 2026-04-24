<template>
  <div class="price-settings">
    <a-card>
      <template #title>房价设置</template>
      <template #extra>
        <a-button @click="fetchRoomTypes" :loading="loading">刷新</a-button>
      </template>

      <a-table
        :columns="columns"
        :data-source="roomTypes"
        :loading="loading"
        :pagination="{ pageSize: 10 }"
        row-key="id"
        size="middle"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'base_price'">
            <a-input-number
              v-model:value="record.base_price_edit"
              :min="0"
              :precision="2"
              style="width: 130px;"
            />
          </template>
          <template v-if="column.key === 'action'">
            <a-button type="link" size="small" @click="savePrice(record)">保存</a-button>
          </template>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { $notify, NotifyPreset } from '@/utils/notify'
import { roomTypeApi } from '@/api/room-type'

const loading = ref(false)
const roomTypes = ref<any[]>([])

const columns = [
  { title: '房型名称', dataIndex: 'name', width: 180 },
  { title: '房型编码', dataIndex: 'code', width: 120 },
  { title: '基准房价(元/晚)', dataIndex: 'base_price', key: 'base_price', width: 180 },
  { title: '可住人数', dataIndex: 'max_guests', width: 100 },
  { title: '操作', key: 'action', width: 100 }
]

async function fetchRoomTypes() {
  loading.value = true
  try {
    const res: any = await roomTypeApi.getRoomTypeList()
    roomTypes.value = (res.data || []).map((item: any) => ({
      ...item,
      base_price_edit: Number(item.base_price)
    }))
  } catch (error) {
    $notify.error({ title: '获取房型列表失败', description: '无法加载房型数据，请稍后重试 🔄' })
  } finally {
    loading.value = false
  }
}

async function savePrice(record: any) {
  try {
    await roomTypeApi.updateRoomType(record.id, {
      base_price: Number(record.base_price_edit)
    })
    record.base_price = Number(record.base_price_edit)
    NotifyPreset.profileUpdated(`房型 ${record.name} 价格`)
  } catch (error) {
    NotifyPreset.operationFailed('保存房价失败')
  }
}

onMounted(fetchRoomTypes)
</script>
