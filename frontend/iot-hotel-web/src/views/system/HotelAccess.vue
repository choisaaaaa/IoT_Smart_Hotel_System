<template>
  <div class="hotel-access-container">
    <a-card title="分店系统快速接入" :bordered="false">
      <template #extra>
        <a-input-search
          v-model:value="searchKeyword"
          placeholder="搜索酒店名称或地址"
          style="width: 300px"
          @search="fetchHotels"
        />
      </template>

      <a-table
        :columns="columns"
        :data-source="hotels"
        :loading="loading"
        row-key="id"
        :pagination="pagination"
        @change="handleTableChange"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'image'">
            <a-avatar :src="record.image" shape="square" :size="64" />
          </template>
          <template v-if="column.key === 'star'">
            <a-rate :value="record.star" disabled />
          </template>
          <template v-if="column.key === 'action'">
            <a-space>
              <a-button type="primary" size="small" @click="enterHotelSystem(record, 'admin')">
                <template #icon><SettingOutlined /></template>
                进入管理端
              </a-button>
              <a-button type="default" size="small" @click="enterHotelSystem(record, 'reception')">
                <template #icon><CustomerServiceOutlined /></template>
                进入前台端
              </a-button>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { $notify, NotifyPreset } from '@/utils/notify'
import { SettingOutlined, CustomerServiceOutlined } from '@ant-design/icons-vue'
import request from '@/api/request'
import { useHotelStore } from '@/stores/hotel'
import { useAppStore } from '@/stores/app'

const router = useRouter()
const hotelStore = useHotelStore()
const appStore = useAppStore()

const loading = ref(false)
const searchKeyword = ref('')
const hotels = ref([])
const pagination = reactive({
  current: 1,
  pageSize: 10,
  total: 0
})

const columns = [
  { title: '封面', key: 'image', width: 100 },
  { title: '酒店名称', dataIndex: 'name', key: 'name' },
  { title: '地址', dataIndex: 'location', key: 'location' },
  { title: '星级', dataIndex: 'star', key: 'star' },
  { title: '操作', key: 'action', width: 250 }
]

async function fetchHotels() {
  loading.value = true
  try {
    const res = await request.get('/hotels/search', {
      params: {
        destination: searchKeyword.value,
        page: pagination.current,
        pageSize: pagination.pageSize
      }
    })
    hotels.value = res.data.hotels
    pagination.total = res.data.total || res.data.hotels.length // 后端 search 接口目前没返回 total，先用 length
  } catch (error) {
    NotifyPreset.operationFailed('获取酒店列表失败')
  } finally {
    loading.value = false
  }
}

function handleTableChange(pag: any) {
  pagination.current = pag.current
  pagination.pageSize = pag.pageSize
  fetchHotels()
}

async function enterHotelSystem(hotel: any, type: 'admin' | 'reception') {
  try {
    // 调用切换酒店 API 获取新 Token
    const res = await request.post('/auth/switch-hotel', {
      hotel_id: hotel.id
    })

    if (res.data.token) {
      // 更新 Token (必须使用 auth_token 以配合 request.ts)
      localStorage.setItem('auth_token', res.data.token)
      
      // 更新用户信息中的酒店 ID 和名称
      if (appStore.userInfo) {
        appStore.setUserInfo({
          ...appStore.userInfo,
          hotel_id: hotel.id,
          hotel_name: hotel.name
        })
      }
      
      // 更新酒店 Store
      hotelStore.setCurrentHotelId(hotel.id)
      
      // 成功切换提示
      $notify.success({ title: '切换成功', description: `已切换到酒店: ${hotel.name} 🏨` })

      // 稍微延迟后跳转，确保 Store 已更新
      setTimeout(() => {
        if (type === 'admin') {
          router.push('/hotel-admin/dashboard')
        } else {
          router.push('/reception/dashboard')
        }
      }, 500)
    }
  } catch (error) {
    NotifyPreset.operationFailed('切换酒店失败')
  }
}

onMounted(fetchHotels)
</script>

<style scoped>
.hotel-access-container {
  padding: 0;
}
</style>
