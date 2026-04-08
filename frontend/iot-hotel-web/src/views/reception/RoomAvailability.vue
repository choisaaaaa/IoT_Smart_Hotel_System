<template>
  <div class="room-availability">
    <a-card :bordered="false" class="filter-card">
      <div class="filter-header">
        <div class="filter-left">
          <a-space>
            <a-select v-model:value="filterFloor" placeholder="楼层" style="width: 100px" allow-clear @change="refreshData">
              <a-select-option v-for="f in hotelStore.floors" :key="f.floor" :value="f.floor">{{ f.floor }}层</a-select-option>
            </a-select>
            <a-select v-model:value="filterStatus" placeholder="状态" style="width: 120px" allow-clear @change="refreshData">
              <a-select-option v-for="(v, k) in statusMap" :key="k" :value="k">{{ v.label }}</a-select-option>
            </a-select>
            <a-button @click="refreshData" :loading="loading">
              <template #icon><SyncOutlined /></template>
              刷新
            </a-button>
          </a-space>
        </div>
        <div class="filter-right">
          <a-radio-group v-model:value="viewMode" button-style="solid">
            <a-radio-button value="grid">视图模式</a-radio-button>
            <a-radio-button value="table">列表模式</a-radio-button>
          </a-radio-group>
        </div>
      </div>

      <div class="status-legend">
        <a-space :size="24">
          <div v-for="(v, k) in statusMap" :key="k" class="legend-item">
            <span class="dot" :style="{ backgroundColor: v.color }"></span>
            <span class="label">{{ v.label }}</span>
          </div>
        </a-space>
      </div>
    </a-card>

    <div v-if="viewMode === 'grid'" class="grid-container">
      <div v-for="group in hotelStore.groupedRooms" :key="group.floor" class="floor-section">
        <div class="floor-title">{{ group.floor }}层</div>
        <div class="room-grid">
          <div 
            v-for="room in group.rooms" 
            :key="room.id" 
            class="room-card"
            :class="[room.status]"
            @click="showRoomDetail(room)"
          >
            <div class="room-num">{{ room.room_number }}</div>
            <div class="room-type">{{ room.room_name }}</div>
            <div class="room-icon">
              <component :is="statusMap[room.status]?.icon || InfoCircleOutlined" />
            </div>
          </div>
        </div>
      </div>
    </div>

    <a-table 
      v-else 
      :columns="columns" 
      :data-source="hotelStore.rooms" 
      :loading="loading"
      class="room-table"
    >
      <template #bodyCell="{ column, record }">
        <template v-if="column.key === 'status'">
          <a-tag :color="statusMap[record.status]?.color">{{ statusMap[record.status]?.label }}</a-tag>
        </template>
        <template v-if="column.key === 'action'">
          <a-button type="link" size="small" @click="showRoomDetail(record)">详情</a-button>
        </template>
      </template>
    </a-table>

    <!-- Room Detail Drawer -->
    <a-drawer
      v-model:open="drawerVisible"
      :title="`房间 ${currentRoom?.room_number} 详情`"
      placement="right"
      width="400"
    >
      <div v-if="currentRoom" class="room-detail">
        <div class="detail-header" :class="currentRoom.status">
          <component :is="statusMap[currentRoom.status]?.icon" style="font-size: 48px" />
          <h3>{{ statusMap[currentRoom.status]?.label }}</h3>
        </div>
        <a-descriptions :column="1" bordered>
          <a-descriptions-item label="房号">{{ currentRoom.room_number }}</a-descriptions-item>
          <a-descriptions-item label="房型">{{ currentRoom.room_name }}</a-descriptions-item>
          <a-descriptions-item label="价格">¥{{ currentRoom.room_price }} / 晚</a-descriptions-item>
          <a-descriptions-item label="面积">{{ currentRoom.area }} m²</a-descriptions-item>
          <a-descriptions-item label="入住状态">
            {{ currentRoom.status === 'occupied' ? '客人在住' : '空闲' }}
          </a-descriptions-item>
        </a-descriptions>
        
        <div class="detail-actions" style="margin-top: 24px">
          <a-space direction="vertical" block>
            <a-button v-if="currentRoom.status === 'available'" type="primary" block>办理入住</a-button>
            <a-button v-if="currentRoom.status === 'cleaning'" type="primary" block>完成打扫</a-button>
            <a-button v-if="currentRoom.status === 'occupied'" block>下发指令</a-button>
            <a-button block>修改状态</a-button>
          </a-space>
        </div>
      </div>
    </a-drawer>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { message } from 'ant-design-vue'
import type { RoomInfo } from '@/types'
import { useHotelStore } from '@/stores/hotel'

import {
  CheckCircleOutlined, CloseCircleOutlined,
  SyncOutlined, InfoCircleOutlined,
  RestOutlined, CoffeeOutlined,
  CalendarOutlined
} from '@ant-design/icons-vue'

const hotelStore = useHotelStore()
const loading = ref(false)
const viewMode = ref<'table' | 'grid'>('grid')
const filterFloor = ref<number | undefined>()
const filterStatus = ref<string | undefined>()
const drawerVisible = ref(false)
const currentRoom = ref<any>(null)

const statusMap: Record<string, any> = {
  available: { label: '空闲', color: '#52c41a', icon: CheckCircleOutlined },
  occupied: { label: '在住', color: '#1890ff', icon: InfoCircleOutlined },
  maintenance: { label: '维修', color: '#f5222d', icon: CloseCircleOutlined },
  cleaning: { label: '待扫', color: '#faad14', icon: RestOutlined },
  reserved: { label: '已预订', color: '#722ed1', icon: CalendarOutlined }
}

const columns = [
  { title: '房号', dataIndex: 'room_number', width: 80 },
  { title: '名称', dataIndex: 'room_name', ellipsis: true },
  { title: '房型', dataIndex: 'room_type', width: 100 },
  { title: '价格(元/晚)', dataIndex: 'room_price', key: 'room_price', width: 120 },
  { title: '状态', dataIndex: 'status', key: 'status', width: 110 },
  { title: '楼层', dataIndex: 'floor', width: 60 },
  { title: '面积(m²)', dataIndex: 'area', width: 90 },
  { title: '操作', key: 'action', width: 200 }
]

function showRoomDetail(room: RoomInfo) {
  currentRoom.value = room
  drawerVisible.value = true
}

async function refreshData() {
  loading.value = true
  try {
    await hotelStore.fetchRooms()
  } catch (error) {
    message.error('刷新房态失败')
  } finally {
    loading.value = false
  }
}

onMounted(refreshData)
</script>

<style scoped>
.room-availability { padding: 0; }
.filter-card { margin-bottom: 16px; }
.filter-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.status-legend { padding-top: 12px; border-top: 1px solid #f0f0f0; }
.legend-item { display: flex; align-items: center; gap: 8px; }
.dot { width: 10px; height: 10px; border-radius: 50%; }
.grid-container { display: flex; flex-direction: column; gap: 24px; }
.floor-section { background: #fff; padding: 20px; border-radius: 8px; }
.floor-title { font-size: 18px; font-weight: bold; margin-bottom: 16px; color: #333; border-left: 4px solid #1890ff; padding-left: 12px; }
.room-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: 16px; }
.room-card { 
  background: #fff; border: 1px solid #f0f0f0; border-radius: 8px; padding: 16px; 
  cursor: pointer; transition: all 0.3s; position: relative; overflow: hidden;
  box-shadow: 0 2px 8px rgba(0,0,0,0.04);
}
.room-card:hover { transform: translateY(-4px); box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
.room-num { font-size: 20px; font-weight: bold; margin-bottom: 4px; }
.room-type { font-size: 12px; color: #666; margin-bottom: 8px; }
.room-icon { position: absolute; right: 12px; top: 12px; font-size: 24px; opacity: 0.2; }

/* Status Colors */
.room-card.available { border-top: 4px solid #52c41a; }
.room-card.occupied { border-top: 4px solid #1890ff; background: #f0f7ff; }
.room-card.maintenance { border-top: 4px solid #f5222d; background: #fff1f0; }
.room-card.cleaning { border-top: 4px solid #faad14; background: #fffbe6; }
.room-card.reserved { border-top: 4px solid #722ed1; background: #f9f0ff; }

.room-detail { text-align: center; }
.detail-header { padding: 32px 0; margin-bottom: 24px; border-radius: 8px; }
.detail-header.available { background: #f6ffed; color: #52c41a; }
.detail-header.occupied { background: #e6f7ff; color: #1890ff; }
.detail-header.maintenance { background: #fff2f0; color: #ff4d4f; }
.detail-header.cleaning { background: #fffbe6; color: #faad14; }
.detail-header.reserved { background: #f9f0ff; color: #722ed1; }
</style>
