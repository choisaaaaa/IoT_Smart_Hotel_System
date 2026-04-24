<template>
  <div class="system-settings">
    <a-card title="会员方案配置" :bordered="false">
      <a-form layout="vertical">
        <a-form-item label="会员计划名称" extra="此名称将显示在用户的会员卡顶部，支持自定义品牌名。">
          <a-input v-model:value="configs.member_program_name" placeholder="请输入会员计划名称，如 IOT, SMART HOTEL 等" />
        </a-form-item>

        <a-divider>积分与成长值规则</a-divider>
        <div style="display: flex; gap: 20px; flex-wrap: wrap;">
          <a-form-item label="积分获取倍率" extra="每消费1元获得的积分数 (基础值)" style="flex: 1; min-width: 200px;">
            <a-input-number v-model:value="configs.points_rate" :min="0" style="width: 100%" />
          </a-form-item>
          <a-form-item label="积分抵扣倍率" extra="多少积分抵扣1元" style="flex: 1; min-width: 200px;">
            <a-input-number v-model:value="configs.points_redeem_rate" :min="1" style="width: 100%" />
          </a-form-item>
          <a-form-item label="成长值获取倍率" extra="每消费1元获得的成长值" style="flex: 1; min-width: 200px;">
            <a-input-number v-model:value="configs.exp_rate" :min="0" :step="0.01" style="width: 100%" />
          </a-form-item>
        </div>
        
        <div style="display: flex; gap: 20px; flex-wrap: wrap;">
          <a-form-item label="签到赠送积分" extra="每日签到可获得的积分" style="flex: 1; min-width: 200px;">
            <a-input-number v-model:value="configs.checkin_points" :min="0" style="width: 100%" />
          </a-form-item>
          <a-form-item label="签到赠送成长值" extra="每日签到可获得的成长值" style="flex: 1; min-width: 200px;">
            <a-input-number v-model:value="configs.checkin_exp" :min="0" style="width: 100%" />
          </a-form-item>
        </div>
        
        <a-divider>会员等级方案</a-divider>
        <p class="section-desc">配置不同等级会员的折扣率、积分倍率及升级门槛。企业用户可完全自定义各等级名称与权益。</p>
        
        <a-table :dataSource="configs.member_scheme" :columns="columns" :pagination="false" size="small">
          <template #bodyCell="{ column, record, index }">
            <template v-if="column.key === 'name'">
              <a-input v-model:value="record.name" size="small" />
            </template>
            <template v-if="column.key === 'discount'">
              <a-input-number v-model:value="record.discount" :min="0" :max="1" :step="0.01" size="small" style="width: 70px" />
            </template>
            <template v-if="column.key === 'points_multiplier'">
              <a-input-number v-model:value="record.points_multiplier" :min="1" :step="0.1" size="small" style="width: 70px" />
            </template>
            <template v-if="column.key === 'min_experience'">
              <a-input-number v-model:value="record.min_experience" :min="0" size="small" style="width: 90px" />
            </template>
            <template v-if="column.key === 'color'">
              <input type="color" v-model="record.color" style="width: 30px; height: 24px; padding: 0; border: none; vertical-align: middle;" />
            </template>
            <template v-if="column.key === 'benefits'">
              <a-input v-model:value="record.benefits" size="small" placeholder="如：延迟退房, 免费早餐" />
            </template>
          </template>
        </a-table>

        <a-divider />
        
        <a-form-item>
          <a-button type="primary" :loading="saving" @click="handleSave" size="large">
            保存全局配置
          </a-button>
        </a-form-item>
      </a-form>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { $notify, NotifyPreset } from '@/utils/notify'
import { systemConfigApi } from '@/api/system-config'
import { useAppStore } from '@/stores/app'

const appStore = useAppStore()

const saving = ref(false)
const configs = ref<Record<string, any>>({
  member_program_name: '',
  member_scheme: [],
  points_rate: 10,
  points_redeem_rate: 10,
  exp_rate: 0.1,
  checkin_points: 50,
  checkin_exp: 10
})

const columns = [
  { title: '等级ID', dataIndex: 'key', key: 'key', width: 80 },
  { title: '等级名称', dataIndex: 'name', key: 'name', width: 120 },
  { title: '折扣率', dataIndex: 'discount', key: 'discount', width: 100 },
  { title: '积分倍率', dataIndex: 'points_multiplier', key: 'points_multiplier', width: 100 },
  { title: '升级经验', dataIndex: 'min_experience', key: 'min_experience', width: 110 },
  { title: '颜色', dataIndex: 'color', key: 'color', width: 60 },
  { title: '会员权益', dataIndex: 'benefits', key: 'benefits' },
]

const fetchConfigs = async () => {
  try {
    const res = await systemConfigApi.getAllConfigs()
    if (res.data) {
      configs.value = { ...configs.value, ...res.data }
      // 确保 member_scheme 是数组，如果后端返回的是字符串则解析
      if (typeof configs.value.member_scheme === 'string') {
        try {
          configs.value.member_scheme = JSON.parse(configs.value.member_scheme)
        } catch (e) {
          configs.value.member_scheme = []
        }
      } else if (!Array.isArray(configs.value.member_scheme)) {
        configs.value.member_scheme = []
      }
    }
  } catch (error) {
    NotifyPreset.operationFailed('获取配置失败')
  }
}

const handleSave = async () => {
  try {
    saving.value = true
    await systemConfigApi.updateConfigs(configs.value)
    // 更新全局状态，使用深拷贝确保响应式数据纯净同步
    appStore.setSystemConfigs(JSON.parse(JSON.stringify(configs.value)))
    $notify.success({ title: '保存成功', description: '会员方案配置已更新并生效 ✅' })
  } catch (error) {
    NotifyPreset.operationFailed('更新配置失败')
  } finally {
    saving.value = false
  }
}

onMounted(() => {
  fetchConfigs()
})
</script>

<script lang="ts">
export default {
  name: 'SystemSettings'
}
</script>

<style scoped>
.system-settings {
  max-width: 1000px;
  margin: 0 auto;
}
.section-desc {
  color: rgba(0, 0, 0, 0.45);
  margin-bottom: 16px;
}
</style>
