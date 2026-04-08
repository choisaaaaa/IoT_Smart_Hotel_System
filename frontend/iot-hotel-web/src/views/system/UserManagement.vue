<template>
  <div class="user-management">
    <a-card :title="isSystem ? '全系统用户管理' : '门店用户管理'" :bordered="false">
      <template #extra>
        <a-button type="primary" @click="handleAdd">
          <template #icon><PlusOutlined /></template>
          新增用户
        </a-button>
      </template>

      <div class="search-bar" style="margin-bottom: 16px; display: flex; gap: 16px;">
        <a-input-search
          v-model:value="searchKey"
          placeholder="搜索用户名/邮箱"
          style="width: 250px"
          allow-clear
          @search="fetchUsers"
        />
        <a-select
          v-model:value="roleFilter"
          placeholder="按角色过滤"
          style="width: 150px"
          allow-clear
          @change="fetchUsers"
        >
          <a-select-option value="system" v-if="isSystem">系统管理员</a-select-option>
          <a-select-option value="admin">门店管理员</a-select-option>
          <a-select-option value="staff">门店员工</a-select-option>
          <a-select-option value="user">普通用户</a-select-option>
        </a-select>
        <a-select
          v-if="isSystem"
          v-model:value="hotelFilter"
          placeholder="按酒店过滤"
          style="width: 200px"
          allow-clear
          show-search
          :filter-option="filterHotelOption"
          @change="fetchUsers"
        >
          <a-select-option v-for="h in hotels" :key="h.id" :value="h.id">
            {{ h.hotel_name }} ({{ h.hotel_code }})
          </a-select-option>
        </a-select>
      </div>

      <a-table
        :columns="columns"
        :data-source="users"
        :loading="loading"
        :pagination="pagination"
        row-key="id"
        @change="handleTableChange"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'role'">
            <a-tag :color="getRoleColor(record.role)">{{ getRoleText(record.role) }}</a-tag>
          </template>
          <template v-if="column.key === 'hotel'">
            <span v-if="record.role === 'system'">系统级</span>
            <span v-else-if="record.hotel_name">{{ record.hotel_name }}</span>
            <span v-else style="color: #999">未绑定</span>
          </template>
          <template v-if="column.key === 'action'">
            <a-space>
              <a-button type="link" @click="handleEdit(record)">编辑</a-button>
              <a-popconfirm
                v-if="record.username !== 'admin' && record.username !== appStore.userInfo?.username"
                title="确定要删除此用户吗？"
                @confirm="handleDelete(record.id)"
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
      :title="editingId ? '编辑用户' : '新增用户'"
      @ok="handleModalOk"
      :confirm-loading="submitLoading"
    >
      <a-form :model="formState" layout="vertical" ref="formRef" :rules="rules">
        <a-form-item label="用户名" name="username">
          <a-input v-model:value="formState.username" :disabled="!!editingId" />
        </a-form-item>
        <a-form-item label="密码" name="password" :rules="editingId ? [] : [{ required: true, message: '请输入密码' }]">
          <a-input-password v-model:value="formState.password" :placeholder="editingId ? '留空表示不修改' : '请输入密码'" />
        </a-form-item>
        <a-form-item label="邮箱" name="email">
          <a-input v-model:value="formState.email" />
        </a-form-item>
        <a-form-item label="角色" name="role">
          <a-select v-model:value="formState.role">
            <a-select-option value="system" v-if="isSystem">系统管理员</a-select-option>
            <a-select-option value="admin">门店管理员</a-select-option>
            <a-select-option value="staff">门店员工</a-select-option>
            <a-select-option value="user">普通用户</a-select-option>
          </a-select>
        </a-form-item>
        <a-form-item 
          label="所属门店" 
          name="hotel_id" 
          v-if="formState.role !== 'system'"
          :rules="formState.role !== 'user' ? [{ required: true, message: '请选择绑定酒店' }] : []"
        >
          <a-select
            v-model:value="formState.hotel_id"
            placeholder="请选择酒店"
            show-search
            :filter-option="filterHotelOption"
          >
            <a-select-option v-for="h in filteredHotelOptions" :key="h.id" :value="h.id">
              {{ h.hotel_name }}
            </a-select-option>
          </a-select>
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed, reactive } from 'vue'
import { PlusOutlined } from '@ant-design/icons-vue'
import { message } from 'ant-design-vue'
import { useAppStore } from '@/stores/app'
import axios from '@/api/request'
import { hotelManageApi } from '@/api/hotel-manage'

interface UserItem {
  id: number
  username: string
  email?: string
  role: string
  hotel_id?: number
  hotel_name?: string
  created_at?: string
}

interface HotelOption {
  id: number
  hotel_name: string
  hotel_code?: string
}

const appStore = useAppStore()
const isSystem = computed(() => appStore.userInfo?.role === 'system')

const filteredHotelOptions = computed(() => {
  if (isSystem.value) {
    return hotels.value
  }
  // 如果是 Admin 角色，只返回他自己所属的酒店
  if (appStore.userInfo?.hotel_id) {
    return [{
      id: appStore.userInfo.hotel_id,
      hotel_name: appStore.userInfo.hotel_name || '当前门店'
    }]
  }
  return []
})

const loading = ref(false)
const users = ref<UserItem[]>([])
const hotels = ref<HotelOption[]>([])
const searchKey = ref('')
const roleFilter = ref(undefined)
const hotelFilter = ref(undefined)
const modalVisible = ref(false)
const editingId = ref(null)
const submitLoading = ref(false)
const formRef = ref<any>(null)

const pagination = reactive({
  current: 1,
  pageSize: 10,
  total: 0,
  showSizeChanger: true
})

const formState = reactive({
  username: '',
  password: '',
  email: '',
  role: 'user',
  hotel_id: undefined
})

const rules = {
  username: [{ required: true, message: '请输入用户名' }],
  role: [{ required: true, message: '请选择角色' }]
}

const columns = [
  { title: '用户名', dataIndex: 'username', key: 'username' },
  { title: '邮箱', dataIndex: 'email', key: 'email' },
  { title: '角色', dataIndex: 'role', key: 'role' },
  { title: '所属酒店', key: 'hotel' },
  { title: '创建时间', dataIndex: 'created_at', key: 'created_at' },
  { title: '操作', key: 'action', width: 150 }
]

const getRoleColor = (role: string) => {
  const colors: any = { system: 'red', admin: 'blue', staff: 'green', user: 'orange' }
  return colors[role] || 'default'
}

const getRoleText = (role: string) => {
  const texts: any = { system: '系统管理员', admin: '门店管理员', staff: '门店员工', user: '普通用户' }
  return texts[role] || role
}

const filterHotelOption = (input: string, option: any) => {
  return option.children[0].toLowerCase().indexOf(input.toLowerCase()) >= 0
}

const fetchUsers = async () => {
  loading.value = true
  try {
    const res = await axios.get('/users', {
      params: {
        page: pagination.current,
        limit: pagination.pageSize,
        keyword: searchKey.value,
        role: roleFilter.value,
        hotel_id: hotelFilter.value
      }
    })
    users.value = res.data.users
    pagination.total = res.data.total
  } catch (error) {
    message.error('获取用户列表失败')
  } finally {
    loading.value = false
  }
}

const fetchHotels = async () => {
  // 不论什么角色都去获取酒店列表，方便填充选项
  try {
    const res: any = await hotelManageApi.getAllHotels()
    hotels.value = res.data || []
  } catch (error) {}
}

const handleTableChange = (pag: any) => {
  pagination.current = pag.current
  pagination.pageSize = pag.pageSize
  fetchUsers()
}

const handleAdd = () => {
  editingId.value = null
  Object.assign(formState, {
    username: '',
    password: '',
    email: '',
    role: isSystem.value ? 'admin' : 'staff',
    hotel_id: appStore.userInfo?.hotel_id
  })
  modalVisible.value = true
}

const handleEdit = (record: any) => {
  editingId.value = record.id
  Object.assign(formState, {
    username: record.username,
    password: '',
    email: record.email,
    role: record.role,
    hotel_id: record.hotel_id || appStore.userInfo?.hotel_id
  })
  modalVisible.value = true
}

const handleModalOk = async () => {
  if (!formRef.value) return
  try {
    await formRef.value.validate()
    submitLoading.value = true
    if (editingId.value) {
      await axios.put(`/users/${editingId.value}`, formState)
      message.success('更新成功')
    } else {
      await axios.post('/users', formState)
      message.success('创建成功')
    }
    modalVisible.value = false
    fetchUsers()
  } catch (error: any) {
    message.error(error.response?.data?.message || '操作失败')
  } finally {
    submitLoading.value = false
  }
}

const handleDelete = async (id: number) => {
  try {
    await axios.delete(`/users/${id}`)
    message.success('删除成功')
    fetchUsers()
  } catch (error) {
    message.error('删除失败')
  }
}

onMounted(() => {
  fetchUsers()
  fetchHotels()
})
</script>

<style scoped>
.user-management {
  padding: 0;
}
.search-bar {
  background: #fff;
}
</style>
