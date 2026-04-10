
<template>
  <div class="price-calendar">
    <a-card title="房型价格日历" :bordered="false">
      <template #extra>
        <a-space>
          <span class="label">选择房型:</span>
          <a-select v-model:value="selectedRoomTypeId" style="width: 200px" @change="fetchCalendar">
            <a-select-option v-for="type in roomTypes" :key="type.id" :value="type.id">
              {{ type.name }}
            </a-select-option>
          </a-select>
        </a-space>
      </template>

      <div class="calendar-container">
        <a-calendar v-model:value="currentMonth" @panelChange="onPanelChange">
          <template #dateCellRender="{ current }">
            <div class="price-cell" @click.stop="openEditModal(current)">
              <template v-if="getPriceForDate(current)">
                <div class="base-price">基准: ¥{{ getPriceForDate(current).base_price }}</div>
                <div class="final-price">
                  <span class="label">现价:</span>
                  <span class="val">¥{{ getPriceForDate(current).final_price }}</span>
                </div>
                <div class="discount-tag" v-if="getPriceForDate(current).discount_rate < 1">
                  {{ Math.round(getPriceForDate(current).discount_rate * 100) / 10 }}折
                </div>
              </template>
              <template v-else-if="selectedRoomType">
                <div class="base-price placeholder">房型基准价</div>
                <div class="final-price">
                  <span class="label">现价:</span>
                  <span class="val">¥{{ selectedRoomType.base_price }}</span>
                </div>
                <div class="status-tag default">默认价</div>
              </template>
              <a-button type="link" size="small" class="edit-btn">
                {{ getPriceForDate(current) ? '修改' : '设置' }}
              </a-button>
            </div>
          </template>
        </a-calendar>
      </div>
    </a-card>

    <!-- 价格编辑弹窗 -->
    <a-modal
      v-model:open="modalVisible"
      :title="`设置价格 - ${selectedDateStr}`"
      @ok="handleSavePrice"
      :confirmLoading="submitLoading"
    >
      <a-form layout="vertical">
        <a-form-item label="当日基准价 (元)">
          <a-input-number v-model:value="editForm.base_price" style="width: 100%" :min="0" />
        </a-form-item>
        <a-form-item label="折扣率 (1.0 为不打折, 0.85 为 85 折)">
          <a-input-number v-model:value="editForm.discount_rate" style="width: 100%" :min="0" :max="1" :step="0.01" />
        </a-form-item>
        <div class="final-price-preview">
          <div class="preview-title">预计结算价格预览</div>
          <div class="level-prices">
            <div class="level-price-item">
              <span class="label">执行价 (基础):</span>
              <span class="val">¥{{ (editForm.base_price * editForm.discount_rate).toFixed(2) }}</span>
            </div>
            <div v-for="(discount, level) in levelDiscounts" :key="level" class="level-price-item">
              <span class="label">{{ getLevelLabel(level) }} ({{ Math.round(discount * 100) / 10 }}折):</span>
              <span class="val">¥{{ (editForm.base_price * editForm.discount_rate * discount).toFixed(2) }}</span>
            </div>
          </div>
        </div>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, computed } from 'vue'
import { message } from 'ant-design-vue'
import request from '@/api/request'
import dayjs, { Dayjs } from 'dayjs'

const roomTypes = ref<any[]>([])
const selectedRoomTypeId = ref<number | null>(null)
const currentMonth = ref<Dayjs>(dayjs())
const calendarData = ref<any[]>([])
const levelDiscounts = ref<Record<string, number>>({})
const loading = ref(false)

const selectedRoomType = computed(() => {
  return roomTypes.value.find(t => t.id === selectedRoomTypeId.value)
})

const getLevelLabel = (level: string) => {
  const labels: Record<string, string> = {
    'diamond': '钻石会员',
    'platinum': '铂金会员',
    'gold': '金卡会员',
    'silver': '银卡会员',
    'standard': '普通会员'
  }
  return labels[level] || level
}

const fetchLevelDiscounts = async () => {
  try {
    const res = await request.get('/members/discounts')
    levelDiscounts.value = res.data || {}
  } catch (error) {
    console.error('获取会员折扣失败:', error)
  }
}

const modalVisible = ref(false)
const submitLoading = ref(false)
const selectedDateStr = ref('')
const editForm = reactive({
  base_price: 0,
  discount_rate: 1.0
})

const fetchRoomTypes = async () => {
  try {
    const res = await request.get('/room-types')
    roomTypes.value = res.data || []
    if (roomTypes.value.length > 0) {
      selectedRoomTypeId.value = roomTypes.value[0].id
      fetchCalendar()
    }
  } catch (error) {
    message.error('获取房型失败')
  }
}

const fetchCalendar = async () => {
  if (!selectedRoomTypeId.value) return
  
  const start = currentMonth.value.startOf('month').format('YYYY-MM-DD')
  const end = currentMonth.value.endOf('month').format('YYYY-MM-DD')
  
  loading.value = true
  try {
    const res = await request.get('/price-calendar', {
      params: {
        room_type_id: selectedRoomTypeId.value,
        start_date: start,
        end_date: end
      }
    })
    calendarData.value = res.data || []
  } catch (error) {
    message.error('获取价格日历失败')
  } finally {
    loading.value = false
  }
}

const onPanelChange = (value: Dayjs) => {
  currentMonth.value = value
  fetchCalendar()
}

const getPriceForDate = (date: Dayjs) => {
  const dateStr = date.format('YYYY-MM-DD')
  return calendarData.value.find(item => dayjs(item.price_date).format('YYYY-MM-DD') === dateStr)
}

const openEditModal = (date: Dayjs) => {
  const existing = getPriceForDate(date)
  selectedDateStr.value = date.format('YYYY-MM-DD')
  
  if (existing) {
    editForm.base_price = Number(existing.base_price)
    editForm.discount_rate = Number(existing.discount_rate)
  } else {
    const type = roomTypes.value.find(t => t.id === selectedRoomTypeId.value)
    editForm.base_price = type ? Number(type.base_price) : 0
    editForm.discount_rate = 1.0
  }
  
  modalVisible.value = true
}

const handleSavePrice = async () => {
  submitLoading.value = true
  try {
    await request.post('/price-calendar/set', {
      room_type_id: selectedRoomTypeId.value,
      prices: [{
        date: selectedDateStr.value,
        base_price: editForm.base_price,
        discount_rate: editForm.discount_rate
      }]
    })
    message.success('价格设置成功')
    modalVisible.value = false
    fetchCalendar()
  } catch (error) {
    message.error('保存失败')
  } finally {
    submitLoading.value = false
  }
}

onMounted(() => {
  fetchRoomTypes()
  fetchLevelDiscounts()
})
</script>

<style scoped>
.calendar-container {
  margin-top: 20px;
  background: #fff;
  padding: 12px;
}

.price-cell {
  height: 100%;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  position: relative;
  padding: 4px;
  cursor: pointer;
  transition: background 0.3s;
}

.price-cell:hover {
  background: #f0f5ff;
}

.base-price {
  font-size: 11px;
  color: #999;
  text-decoration: line-through;
}

.base-price.placeholder {
  text-decoration: none;
  font-style: italic;
  opacity: 0.7;
}

.final-price {
  font-size: 13px;
  font-weight: bold;
  color: #f5222d;
  margin: 2px 0;
}

.discount-tag {
  background: #fff1f0;
  color: #f5222d;
  font-size: 10px;
  padding: 0 4px;
  border-radius: 4px;
}

.status-tag.default {
  background: #f5f5f5;
  color: #8c8c8c;
  font-size: 10px;
  padding: 0 4px;
  border-radius: 4px;
}

.edit-btn {
  opacity: 0;
  transition: opacity 0.3s;
}

.price-cell:hover .edit-btn {
  opacity: 1;
}

.final-price-preview {
  margin-top: 16px;
  padding: 16px;
  background: #f8f9fa;
  border-radius: 12px;
  border: 1px solid #e8e8e8;
}

.preview-title {
  font-size: 14px;
  font-weight: 600;
  color: #1a1a1a;
  margin-bottom: 12px;
  padding-bottom: 8px;
  border-bottom: 1px solid #eee;
}

.level-prices {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.level-price-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 13px;
}

.level-price-item .label {
  color: #666;
}

.level-price-item .val {
  color: #f5222d;
  font-weight: 700;
  font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', 'Consolas', monospace;
}

.level-price-item:first-child {
  padding-bottom: 4px;
  margin-bottom: 4px;
  border-bottom: 1px dashed #eee;
}

.level-price-item:first-child .val {
  color: #1a1a1a;
  font-size: 15px;
}
</style>
