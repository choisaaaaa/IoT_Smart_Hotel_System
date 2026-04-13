<template>
  <a-modal
    :open="visible"
    @update:open="(val: boolean) => emit('update:visible', val)"
    :title="`完善${currentConfig?.title}信息`"
    width="700px"
    :footer="null"
    :closable="!isRequired"
    :mask-closable="!isRequired"
  >
    <div class="wizard-container">
      <a-alert
        v-if="isRequired"
        message="此分类包含AI管家回复客人的关键信息，请完善以下内容"
        type="warning"
        show-icon
        style="margin-bottom: 16px"
      />

      <a-form
        ref="formRef"
        :model="formData"
        layout="vertical"
      >
        <a-row :gutter="16">
          <a-col :span="field.type === 'textarea' ? 24 : 12" v-for="field in currentConfig?.fields" :key="field.key">
            <a-form-item
              :label="field.label + (field.required ? ' *' : '')"
              :required="field.required"
            >
              <template v-if="field.type === 'textarea'">
                <a-textarea
                  v-model:value="formData[field.key]"
                  :placeholder="field.placeholder"
                  :rows="3"
                />
              </template>
              <template v-else-if="field.type === 'select'">
                <a-select
                  v-model:value="formData[field.key]"
                  :placeholder="field.placeholder"
                  style="width: 100%"
                >
                  <a-select-option v-for="opt in field.options" :key="opt" :value="opt">{{ opt }}</a-select-option>
                </a-select>
              </template>
              <template v-else-if="field.type === 'multiselect'">
                <a-select
                  v-model:value="formData[field.key]"
                  mode="multiple"
                  :placeholder="field.placeholder"
                  style="width: 100%"
                >
                  <a-select-option v-for="opt in field.options" :key="opt" :value="opt">{{ opt }}</a-select-option>
                </a-select>
              </template>
              <template v-else>
                <a-input
                  v-model:value="formData[field.key]"
                  :placeholder="field.placeholder"
                />
              </template>
              <div v-if="field.hint" class="field-hint">{{ field.hint }}</div>
            </a-form-item>
          </a-col>
        </a-row>
      </a-form>

      <div class="completion-tips" v-if="currentConfig?.completionTips?.length">
        <div class="tips-title">💡 填写建议：</div>
        <ul>
          <li v-for="(tip, index) in currentConfig.completionTips" :key="index">{{ tip }}</li>
        </ul>
      </div>

      <div class="wizard-footer">
        <a-space>
          <a-button @click="handleSkip" v-if="!isRequired">跳过</a-button>
          <a-button type="primary" @click="handleSave" :loading="saving">保存</a-button>
        </a-space>
      </div>
    </div>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, reactive, watch } from 'vue'
import { message } from 'ant-design-vue'
import { createOrUpdateKnowledge } from '@/api/knowledge-base'
import type { KnowledgeCategoryConfig } from '@/config/knowledge-base.config'

const props = defineProps<{
  visible: boolean
  category: string
  currentConfig?: KnowledgeCategoryConfig
  isRequired?: boolean
}>()

const emit = defineEmits<{
  'update:visible': [value: boolean]
  'saved': []
  'skipped': []
}>()

const formRef = ref()
const formData = reactive<Record<string, any>>({})
const saving = ref(false)

watch(() => props.currentConfig, (config) => {
  if (config) {
    // 初始化表单数据
    config.fields.forEach(field => {
      if (field.type === 'multiselect') {
        formData[field.key] = []
      } else {
        formData[field.key] = ''
      }
    })
  }
}, { immediate: true })

const generateContent = (): string => {
  const config = props.currentConfig
  if (!config) return ''

  let content = config.defaultContent

  // 替换所有占位符
  config.fields.forEach(field => {
    const value = formData[field.key]
    const placeholder = `{{${field.key}}}`
    
    if (Array.isArray(value)) {
      content = content.replace(placeholder, value.join('、'))
    } else {
      content = content.replace(placeholder, value || '')
    }

    // 处理条件语句 {{#if field}}...{{/if}}
    const ifRegex = new RegExp(`{{#if ${field.key}}}(.*?){{/if}}`, 'gs')
    if (value && value !== '' && (!Array.isArray(value) || value.length > 0)) {
      content = content.replace(ifRegex, '$1')
    } else {
      content = content.replace(ifRegex, '')
    }
  })

  // 清理多余的空行
  content = content.replace(/\n{3,}/g, '\n\n').trim()

  return content
}

const handleSave = async () => {
  // 验证必填字段
  const config = props.currentConfig
  if (!config) return

  const missingFields = config.fields
    .filter(f => f.required && !formData[f.key])
    .map(f => f.label)

  if (missingFields.length > 0) {
    message.warning(`请填写必填项：${missingFields.join('、')}`)
    return
  }

  saving.value = true
  try {
    const content = generateContent()
    
    await createOrUpdateKnowledge(props.category, {
      title: config.title,
      content,
      keywords: config.fields.map(f => f.label).join(','),
      is_active: true,
      sort_order: 100
    })

    message.success('保存成功')
    emit('update:visible', false)
    emit('saved')
  } catch (error) {
    console.error('保存失败:', error)
  } finally {
    saving.value = false
  }
}

const handleSkip = () => {
  emit('update:visible', false)
  emit('skipped')
}
</script>

<style scoped>
.wizard-container {
  padding: 8px 0;
}

.field-hint {
  color: #999;
  font-size: 12px;
  margin-top: 4px;
}

.completion-tips {
  background: #f6ffed;
  border: 1px solid #b7eb8f;
  border-radius: 4px;
  padding: 12px 16px;
  margin: 16px 0;
}

.tips-title {
  font-weight: 500;
  color: #52c41a;
  margin-bottom: 8px;
}

.completion-tips ul {
  margin: 0;
  padding-left: 20px;
  color: #666;
}

.completion-tips li {
  margin-bottom: 4px;
}

.wizard-footer {
  display: flex;
  justify-content: flex-end;
  margin-top: 24px;
  padding-top: 16px;
  border-top: 1px solid #f0f0f0;
}
</style>
