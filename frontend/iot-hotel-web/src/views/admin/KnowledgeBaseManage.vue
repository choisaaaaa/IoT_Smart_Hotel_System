<template>
  <div class="knowledge-base-manage">
    <a-card title="AI知识库管理" :bordered="false">
      <template #extra>
        <a-space>
          <a-button type="primary" @click="showInitModal" :loading="initLoading">
            <template #icon><PlusOutlined /></template>
            初始化默认知识库
          </a-button>
        </a-space>
      </template>

      <a-alert 
        message="AI管家将严格基于此知识库内容回复客人，请确保信息的准确性和完整性" 
        type="info" 
        show-icon 
        style="margin-bottom: 16px"
      />

      <!-- 完成度统计 -->
      <a-card v-if="completionStats.total > 0" class="completion-stats" :bordered="false" size="small">
        <div class="stats-header">
          <span class="stats-title">📊 知识库完成度</span>
          <a-progress 
            :percent="Math.round((completionStats.completed / completionStats.total) * 100)" 
            :status="completionStats.completed === completionStats.total ? 'success' : 'active'"
            style="width: 200px"
          />
          <span class="stats-text">{{ completionStats.completed }}/{{ completionStats.total }} 项已完善</span>
        </div>
        <div v-if="completionStats.incompleteCategories.length > 0" class="incomplete-list">
          <a-tag color="orange" v-for="cat in completionStats.incompleteCategories" :key="cat">
            {{ KNOWLEDGE_BASE_CONFIG.find(c => c.category === cat)?.icon }} 
            {{ KNOWLEDGE_BASE_CONFIG.find(c => c.category === cat)?.title }}
            待完善
          </a-tag>
        </div>
      </a-card>

      <div style="margin-bottom: 16px; display: flex; gap: 12px; align-items: center;">
        <span>分类筛选：</span>
        <a-radio-group v-model:value="filterCategory" @change="loadData">
          <a-radio-button value="">全部</a-radio-button>
          <a-radio-button v-for="(cat, key) in CATEGORIES" :key="key" :value="key">
            {{ cat.icon }} {{ cat.label }}
          </a-radio-button>
        </a-radio-group>
      </div>

      <a-table
        :columns="columns"
        :data-source="knowledgeList"
        :loading="loading"
        row-key="id"
        :pagination="false"
      >
        <template #bodyCell="{ column, record }">
          <template v-if="column.key === 'category'">
            <a-tag :color="CATEGORIES[record.category]?.color || '#8c8c8c'">
              {{ CATEGORIES[record.category]?.icon }} {{ CATEGORIES[record.category]?.label || record.category }}
            </a-tag>
          </template>

          <template v-if="column.key === 'title'">
            <div class="title-cell">
              <strong>{{ record.title }}</strong>
              <a-tag v-if="getCompletionStatus(record).isDefault" color="orange" size="small">需完善</a-tag>
            </div>
          </template>

          <template v-if="column.key === 'content_preview'">
            <div class="content-preview">
              {{ stripMarkdown(record.content).substring(0, 100) }}{{ record.content.length > 100 ? '...' : '' }}
            </div>
          </template>

          <template v-if="column.key === 'completion'">
            <div class="completion-cell">
              <a-progress 
                :percent="getCompletionStatus(record).percent" 
                :size="14"
                :show-info="false"
                :status="getCompletionStatus(record).percent === 100 ? 'success' : 'active'"
              />
              <span class="completion-text">{{ getCompletionStatus(record).text }}</span>
            </div>
          </template>

          <template v-if="column.key === 'is_active'">
            <a-switch
              :checked="record.is_active === 1"
              @change="(checked: boolean) => toggleActive(record.id)"
              checked-children="启用"
              un-checked-children="禁用"
              :loading="toggleLoadingMap[record.id]"
            />
          </template>

          <template v-if="column.key === 'sort_order'">
            <a-tag color="blue">{{ record.sort_order }}</a-tag>
          </template>

          <template v-if="column.key === 'action'">
            <a-space>
              <a-button 
                type="link" 
                size="small" 
                @click="editWithWizard(record)"
                v-if="getCompletionStatus(record).isDefault"
              >
                <template #icon><FormOutlined /></template>
                完善
              </a-button>
              <a-button type="link" size="small" @click="editRecord(record)">
                <template #icon><EditOutlined /></template>
                编辑
              </a-button>
            </a-space>
          </template>
        </template>
      </a-table>
    </a-card>

    <!-- 向导编辑模态框 -->
    <KnowledgeBaseWizard
      v-model:visible="wizardVisible"
      :category="currentWizardCategory"
      :current-config="currentWizardConfig"
      @saved="handleWizardSaved"
    />

    <!-- 普通编辑模态框 -->
    <a-modal
      v-model:open="modalVisible"
      :title="editingId ? `编辑：${currentCategory?.label}` : `添加：${currentCategory?.label}`"
      width="800px"
      @ok="handleSubmit"
      :confirm-loading="submitLoading"
      ok-text="保存"
      cancel-text="取消"
    >
      <a-form
        ref="formRef"
        :model="formData"
        :rules="formRules"
        :label-col="{ span: 4 }"
        :wrapper-col="{ span: 20 }"
      >
        <a-form-item label="分类" name="category">
          <a-select v-model:value="formData.category" placeholder="选择分类" disabled>
            <a-select-option v-for="(cat, key) in CATEGORIES" :key="key" :value="key">
              {{ cat.icon }} {{ cat.label }}
            </a-select-option>
          </a-select>
        </a-form-item>

        <a-form-item label="标题" name="title">
          <a-input v-model:value="formData.title" placeholder="输入知识标题" />
        </a-form-item>

        <a-form-item label="内容" name="content">
          <a-textarea
            v-model:value="formData.content"
            placeholder="输入详细内容（支持Markdown格式）"
            :rows="12"
            show-count
            :maxlength="5000"
          />
        </a-form-item>

        <a-form-item label="关键词" name="keywords">
          <a-input
            v-model:value="formData.keywords"
            placeholder="输入关键词，用逗号分隔（用于AI检索匹配）"
          />
          <div class="form-tip">例如：餐厅,早餐,午餐,晚餐,送餐</div>
        </a-form-item>

        <a-form-item label="排序权重" name="sort_order">
          <a-input-number
            v-model:value="formData.sort_order"
            :min="0"
            :max="999"
            style="width: 100%"
          />
          <div class="form-tip">数字越大越优先显示</div>
        </a-form-item>

        <a-form-item label="启用状态" name="is_active">
          <a-switch
            v-model:checked="formData.is_active"
            checked-children="启用"
            un-checked-children="禁用"
          />
        </a-form-item>
      </a-form>
    </a-modal>

    <a-modal
      v-model:open="initModalVisible"
      title="初始化默认知识库"
      @ok="handleInit"
      :confirm-loading="initLoading"
    >
      <p>是否为当前酒店创建默认的知识库模板？</p>
      <p>模板包含以下9个分类的示例内容：</p>
      <ul>
        <li v-for="(cat, key) in CATEGORIES" :key="key">{{ cat.icon }} {{ cat.label }}</li>
      </ul>
      <a-alert message="注意：如果已有数据，将无法重复初始化" type="warning" show-icon />
      <a-divider />
      <p><strong>初始化后需要补充的内容：</strong></p>
      <ul class="init-tips">
        <li><strong>餐厅信息</strong>：早餐时间、地点、特色菜品</li>
        <li><strong>WiFi</strong>：网络名称和密码（必须准确）</li>
        <li><strong>周边推荐</strong>：交通、购物、医疗资源</li>
        <li><strong>酒店政策</strong>：入住时间、押金、禁烟政策</li>
      </ul>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { message } from 'ant-design-vue'
import { EditOutlined, PlusOutlined, FormOutlined } from '@ant-design/icons-vue'
import KnowledgeBaseWizard from '@/components/admin/KnowledgeBaseWizard.vue'
import {
  getKnowledgeList,
  createOrUpdateKnowledge,
  toggleKnowledgeActive,
  initDefaultKnowledge,
  type KnowledgeBase,
  type CategoryType,
  CATEGORIES
} from '@/api/knowledge-base'
import { KNOWLEDGE_BASE_CONFIG, getCategoryConfig, checkCompletion } from '@/config/knowledge-base.config'

const loading = ref(false)
const knowledgeList = ref<KnowledgeBase[]>([])
const filterCategory = ref('')
const modalVisible = ref(false)
const wizardVisible = ref(false)
const initModalVisible = ref(false)
const editingId = ref<number | null>(null)
const submitLoading = ref(false)
const initLoading = ref(false)
const toggleLoadingMap = ref<Record<number, boolean>>({})
const currentWizardCategory = ref('')

const formData = reactive({
  category: '',
  title: '',
  content: '',
  keywords: '',
  sort_order: 50,
  is_active: true
})

const formRules = {
  title: [{ required: true, message: '请输入标题', trigger: 'blur' }],
  content: [{ required: true, message: '请输入内容', trigger: 'blur' }]
}

const currentCategory = computed(() => {
  return CATEGORIES[formData.category as CategoryType]
})

const currentWizardConfig = computed(() => {
  return KNOWLEDGE_BASE_CONFIG.find(c => c.category === currentWizardCategory.value)
})

// 完成度统计
const completionStats = computed(() => {
  const allCategories = KNOWLEDGE_BASE_CONFIG.map(c => c.category)
  const existingCategories = knowledgeList.value.map(k => k.category)
  const incompleteCategories: string[] = []
  let completed = 0

  for (const cat of allCategories) {
    const knowledge = knowledgeList.value.find(k => k.category === cat)
    if (knowledge) {
      const status = checkCompletion(knowledge.content, cat)
      if (status.isComplete) {
        completed++
      } else {
        incompleteCategories.push(cat)
      }
    } else {
      incompleteCategories.push(cat)
    }
  }

  return {
    total: allCategories.length,
    completed,
    existing: existingCategories.length,
    incompleteCategories
  }
})

const columns = [
  {
    title: '分类',
    dataIndex: 'category',
    key: 'category',
    width: 140
  },
  {
    title: '标题',
    dataIndex: 'title',
    key: 'title',
    width: 180
  },
  {
    title: '内容预览',
    dataIndex: 'content',
    key: 'content_preview',
    ellipsis: true
  },
  {
    title: '完成度',
    key: 'completion',
    width: 120,
    align: 'center'
  },
  {
    title: '状态',
    dataIndex: 'is_active',
    key: 'is_active',
    width: 100,
    align: 'center'
  },
  {
    title: '排序',
    dataIndex: 'sort_order',
    key: 'sort_order',
    width: 80,
    align: 'center'
  },
  {
    title: '操作',
    key: 'action',
    width: 150,
    align: 'center'
  }
]

const loadData = async () => {
  loading.value = true
  try {
    const params: any = {}
    if (filterCategory.value) {
      params.category = filterCategory.value
    }
    const res: any = await getKnowledgeList(params)
    knowledgeList.value = res.data || []
  } catch (error) {
    console.error('加载知识库失败:', error)
  } finally {
    loading.value = false
  }
}

// 检查内容是否为默认模板（需要完善）
const getCompletionStatus = (record: KnowledgeBase) => {
  const config = getCategoryConfig(record.category)
  if (!config) return { isDefault: false, percent: 100, text: '-' }

  // 检查是否包含"请门店经理"等默认提示语
  const isDefault = record.content.includes('请门店经理') || 
                    record.content.includes('请根据实际情况') ||
                    record.content.includes('请确认') ||
                    record.content.includes('请补充')

  // 计算完成度
  const completion = checkCompletion(record.content, record.category)
  const totalFields = config.fields.length
  const requiredFields = config.fields.filter(f => f.required).length
  const missingFields = completion.missingFields.length
  
  let percent = 100
  if (isDefault) {
    percent = Math.max(0, 100 - (missingFields * 20))
  }

  return {
    isDefault,
    percent,
    text: isDefault ? `待完善` : '已完成'
  }
}

const editWithWizard = (record: KnowledgeBase) => {
  currentWizardCategory.value = record.category
  wizardVisible.value = true
}

const handleWizardSaved = () => {
  loadData()
}

const editRecord = (record: KnowledgeBase) => {
  editingId.value = record.id
  formData.category = record.category
  formData.title = record.title
  formData.content = record.content
  formData.keywords = record.keywords || ''
  formData.sort_order = record.sort_order
  formData.is_active = record.is_active === 1
  modalVisible.value = true
}

const handleSubmit = async () => {
  submitLoading.value = true
  try {
    await createOrUpdateKnowledge(formData.category, {
      title: formData.title,
      content: formData.content,
      keywords: formData.keywords,
      sort_order: formData.sort_order,
      is_active: formData.is_active ? 1 : 0
    })
    
    message.success('保存成功')
    modalVisible.value = false
    await loadData()
  } catch (error) {
    console.error('保存失败:', error)
  } finally {
    submitLoading.value = false
  }
}

const toggleActive = async (id: number) => {
  toggleLoadingMap.value[id] = true
  try {
    await toggleKnowledgeActive(id)
    message.success('状态更新成功')
    await loadData()
  } catch (error) {
    console.error('切换状态失败:', error)
  } finally {
    toggleLoadingMap.value[id] = false
  }
}

const showInitModal = () => {
  initModalVisible.value = true
}

const handleInit = async () => {
  initLoading.value = true
  try {
    const res: any = await initDefaultKnowledge()
    message.success(res.message || '初始化成功')
    initModalVisible.value = false
    await loadData()
  } catch (error: any) {
    message.error(error?.message || '初始化失败')
  } finally {
    initLoading.value = false
  }
}

const stripMarkdown = (text: string): string => {
  return text
    .replace(/#{1,6}\s/g, '')
    .replace(/\*\*(.*?)\*\*/g, '$1')
    .replace(/\*(.*?)\*/g, '$1')
    .replace(/`(.*?)`/g, '$1')
    .replace(/[-*+]\s/g, '')
    .replace(/\n+/g, ' ')
    .trim()
}

onMounted(() => {
  loadData()
})
</script>

<style scoped>
.knowledge-base-manage {
  padding: 0;
}

.completion-stats {
  background: #f6ffed;
  margin-bottom: 16px;
}

.stats-header {
  display: flex;
  align-items: center;
  gap: 16px;
}

.stats-title {
  font-weight: 500;
}

.stats-text {
  color: #666;
}

.incomplete-list {
  margin-top: 12px;
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.title-cell {
  display: flex;
  align-items: center;
  gap: 8px;
}

.content-preview {
  color: #666;
  font-size: 13px;
  line-height: 1.5;
  max-width: 400px;
}

.completion-cell {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
}

.completion-text {
  font-size: 12px;
  color: #999;
}

.form-tip {
  color: #999;
  font-size: 12px;
  margin-top: 4px;
}

.init-tips {
  color: #666;
}

.init-tips li {
  margin-bottom: 4px;
}
</style>
