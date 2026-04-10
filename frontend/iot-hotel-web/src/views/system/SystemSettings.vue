<template>
  <div class="system-settings">
    <a-card title="系统全局配置" :bordered="false">
      <a-form layout="vertical">
        <a-form-item label="会员计划名称" extra="此名称将显示在用户的会员卡顶部，支持自定义品牌名。">
          <a-input v-model:value="configs.member_program_name" placeholder="请输入会员计划名称，如 IOT, SMART HOTEL 等" />
        </a-form-item>
        
        <a-divider />
        
        <a-form-item>
          <a-button type="primary" :loading="saving" @click="handleSave">
            保存配置
          </a-button>
        </a-form-item>
      </a-form>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { message } from 'ant-design-vue'
import { systemConfigApi } from '@/api/system-config'

const saving = ref(false)
const configs = reactive({
  member_program_name: ''
})

const fetchConfigs = async () => {
  try {
    const res = await systemConfigApi.getAllConfigs()
    if (res.data) {
      Object.assign(configs, res.data)
    }
  } catch (error) {
    message.error('获取配置失败')
  }
}

const handleSave = async () => {
  try {
    saving.value = true
    await systemConfigApi.updateConfigs(configs)
    message.success('系统配置更新成功')
  } catch (error) {
    message.error('更新配置失败')
  } finally {
    saving.value = false
  }
}

onMounted(() => {
  fetchConfigs()
})
</script>

<style scoped>
.system-settings {
  max-width: 800px;
  margin: 0 auto;
}
</style>
