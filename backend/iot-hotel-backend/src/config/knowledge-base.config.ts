// AI知识库配置 - 定义各分类的必填字段和补充提示

export interface KnowledgeField {
  key: string;
  label: string;
  placeholder: string;
  required: boolean;
  type: 'text' | 'textarea' | 'time' | 'select' | 'multiselect';
  options?: string[];
  hint?: string;
}

export interface KnowledgeCategoryConfig {
  category: string;
  title: string;
  icon: string;
  color: string;
  fields: KnowledgeField[];
  defaultContent: string;
  completionTips: string[];
}

export const KNOWLEDGE_BASE_CONFIG: KnowledgeCategoryConfig[] = [
  {
    category: 'restaurant',
    title: '餐厅信息',
    icon: '🍽️',
    color: '#f5222d',
    fields: [
      { key: 'breakfast_time', label: '早餐时间', placeholder: '例如：07:00 - 10:00', required: true, type: 'text', hint: '格式：HH:MM - HH:MM' },
      { key: 'breakfast_location', label: '早餐地点', placeholder: '例如：1楼西餐厅', required: true, type: 'text' },
      { key: 'lunch_time', label: '午餐时间', placeholder: '例如：11:30 - 14:00', required: false, type: 'text' },
      { key: 'dinner_time', label: '晚餐时间', placeholder: '例如：17:30 - 21:00', required: false, type: 'text' },
      { key: 'room_service', label: '客房送餐', placeholder: '例如：24小时可用，额外收取15%服务费', required: true, type: 'text' },
      { key: 'special_dishes', label: '特色菜品', placeholder: '例如：本帮红烧肉、清蒸鲈鱼、松茸炖鸡汤', required: false, type: 'textarea', hint: '每行一个菜品' },
      { key: 'reservation_phone', label: '预订电话', placeholder: '例如：内线8888', required: false, type: 'text' }
    ],
    defaultContent: `🍽️ **餐厅营业时间**

• **早餐**：{{breakfast_time}}（{{breakfast_location}}）
• **午餐**：{{lunch_time}}
• **晚餐**：{{dinner_time}}
• **客房送餐**：{{room_service}}

**特色菜品**：
{{special_dishes}}

**预订电话**：{{reservation_phone}}

---
⚠️ **请门店经理根据实际情况编辑此内容**`,
    completionTips: [
      '请确认早餐的具体时间和地点',
      '如有特色菜品，建议列出3-5个招牌菜',
      '客房送餐的服务时间和收费标准需要明确'
    ]
  },
  {
    category: 'gym',
    title: '健身中心',
    icon: '💪',
    color: '#fa8c16',
    fields: [
      { key: 'open_time', label: '开放时间', placeholder: '例如：06:00 - 23:00', required: true, type: 'text' },
      { key: 'location', label: '位置', placeholder: '例如：3楼（电梯直达）', required: true, type: 'text' },
      { key: 'facilities', label: '设施配置', placeholder: '例如：跑步机、器械区、瑜伽室、恒温泳池', required: true, type: 'multiselect', options: ['跑步机', '器械区', '瑜伽室', '恒温泳池', '篮球场', '羽毛球场', '乒乓球室'] },
      { key: 'usage_rules', label: '使用规则', placeholder: '例如：凭房卡免费使用，泳池需佩戴泳帽', required: true, type: 'textarea' },
      { key: 'has_pool', label: '是否有泳池', placeholder: '', required: false, type: 'select', options: ['有', '无'] },
      { key: 'pool_temp', label: '泳池水温', placeholder: '例如：28°C', required: false, type: 'text', hint: '如有泳池请填写' }
    ],
    defaultContent: `💪 **健身中心设施与服务**

• **开放时间**：{{open_time}}
• **位置**：{{location}}
• **设施配置**：{{facilities}}

**使用规则**：
{{usage_rules}}
{{#if has_pool}}
• 泳池水温：{{pool_temp}}
{{/if}}

---
⚠️ **请门店经理根据实际情况编辑此内容**`,
    completionTips: [
      '请确认健身房的具体开放时间',
      '列出所有可用的健身设施',
      '如有泳池，请说明水温和使用要求（如泳帽）'
    ]
  },
  {
    category: 'wifi',
    title: '网络服务',
    icon: '📶',
    color: '#1890ff',
    fields: [
      { key: 'ssid_5g', label: '5G网络名称', placeholder: '例如：Hotel_Smart_5G', required: true, type: 'text' },
      { key: 'ssid_24g', label: '2.4G网络名称', placeholder: '例如：Hotel_Smart_2.4G', required: false, type: 'text' },
      { key: 'password', label: 'WiFi密码', placeholder: '例如：guest2024', required: true, type: 'text', hint: '建议使用简单易记的密码' },
      { key: 'bandwidth', label: '带宽说明', placeholder: '例如：每个房间独立100Mbps光纤', required: false, type: 'text' },
      { key: 'coverage', label: '覆盖范围', placeholder: '例如：全酒店覆盖（客房、大堂、餐厅、会议室）', required: false, type: 'textarea' },
      { key: 'support_phone', label: '技术支持', placeholder: '例如：内线9999', required: false, type: 'text' }
    ],
    defaultContent: `📶 **WiFi连接信息**

• **5G网络名称（SSID）**：{{ssid_5g}}
{{#if ssid_24g}}
• **2.4G网络名称（SSID）**：{{ssid_24g}}
{{/if}}
• **登录密码**：{{password}}
• **带宽保障**：{{bandwidth}}
• **覆盖范围**：{{coverage}}

**常见问题**：
- 连接失败请重启设备后重试
- 密码区分大小写
- 如仍无法连接，可致电{{support_phone}}报修

---
⚠️ **请门店经理修改为实际的WiFi名称和密码**`,
    completionTips: [
      '请务必填写正确的WiFi名称和密码',
      '建议同时提供2.4G和5G网络名称',
      '密码建议使用简单易记的组合'
    ]
  },
  {
    category: 'nearby',
    title: '周边推荐',
    icon: '🏪',
    color: '#52c41a',
    fields: [
      { key: 'metro_station', label: '地铁站', placeholder: '例如：步行3分钟至XX地铁站（2号线/5号线）', required: false, type: 'text' },
      { key: 'taxi_stand', label: '出租车停靠点', placeholder: '例如：大堂门口设有出租车停靠点', required: false, type: 'text' },
      { key: 'airport_bus', label: '机场大巴', placeholder: '例如：每小时一班（07:00-22:00）', required: false, type: 'text' },
      { key: 'shopping', label: '购物娱乐', placeholder: '例如：万达广场（步行10分钟）、7-Eleven（酒店楼下）', required: false, type: 'textarea' },
      { key: 'hospital', label: '医疗资源', placeholder: '例如：社区医院（步行5分钟）、市第一人民医院（车程15分钟）', required: false, type: 'textarea' },
      { key: 'attractions', label: '景点推荐', placeholder: '例如：市博物馆（免费，需预约，步行15分钟）', required: false, type: 'textarea' }
    ],
    defaultContent: `🏪 **周边生活配套**

**交通出行**：
{{#if metro_station}}
- 地铁站：{{metro_station}}
{{/if}}
{{#if taxi_stand}}
- 出租车：{{taxi_stand}}
{{/if}}
{{#if airport_bus}}
- 机场大巴：{{airport_bus}}
{{/if}}

**购物娱乐**：
{{shopping}}

**医疗资源**：
{{hospital}}

**景点推荐**：
{{attractions}}

---
⚠️ **请门店经理补充实际的周边信息**`,
    completionTips: [
      '建议提供至少一种交通方式（地铁/公交/出租车）',
      '列出周边便利设施（便利店、药店、餐厅）',
      '如有知名景点，可简要介绍'
    ]
  },
  {
    category: 'checkout',
    title: '退房须知',
    icon: '📋',
    color: '#722ed1',
    fields: [
      { key: 'checkout_time', label: '标准退房时间', placeholder: '例如：12:00前', required: true, type: 'text' },
      { key: 'late_checkout', label: '延迟退房政策', placeholder: '例如：14:00前需提前一天申请，18:00前加收半天房费', required: true, type: 'textarea' },
      { key: 'express_checkout', label: '快速退房方式', placeholder: '例如：可将房卡投入大堂"快速退房箱"', required: true, type: 'textarea' },
      { key: 'invoice_info', label: '发票说明', placeholder: '例如：电子发票即时发送至预留邮箱', required: false, type: 'text' },
      { key: 'deposit_refund', label: '押金退还', placeholder: '例如：3个工作日内原路退还', required: false, type: 'text' }
    ],
    defaultContent: `📋 **退房流程与政策**

**标准退房时间**：{{checkout_time}}

**延迟退房选项**：
{{late_checkout}}

**快速退房**：
{{express_checkout}}

**注意事项**：
- 请检查随身物品避免遗漏
- 迷你吧消费已自动计入账单
{{#if invoice_info}}
- {{invoice_info}}
{{/if}}
{{#if deposit_refund}}
- 押金退还：{{deposit_refund}}
{{/if}}

---
⚠️ **请门店经理确认实际退房政策**`,
    completionTips: [
      '请确认标准退房时间',
      '明确延迟退房的收费标准',
      '说明发票获取方式'
    ]
  },
  {
    category: 'breakfast',
    title: '早餐服务',
    icon: '🥐',
    color: '#eb2f96',
    fields: [
      { key: 'breakfast_time', label: '用餐时间', placeholder: '例如：07:00 - 10:00（最后入场09:30）', required: true, type: 'text' },
      { key: 'location', label: '用餐地点', placeholder: '例如：1楼西餐厅', required: true, type: 'text' },
      { key: 'type', label: '餐食类型', placeholder: '例如：自助早餐', required: true, type: 'select', options: ['自助早餐', '中式套餐', '西式套餐', '中西合璧'] },
      { key: 'chinese_items', label: '中式菜品', placeholder: '例如：粥品、包子、油条、面条档口', required: false, type: 'textarea' },
      { key: 'western_items', label: '西式菜品', placeholder: '例如：面包烘焙、培根、香肠、煎蛋', required: false, type: 'textarea' },
      { key: 'drinks', label: '饮品', placeholder: '例如：现磨咖啡、鲜榨果汁、牛奶', required: false, type: 'textarea' },
      { key: 'special_needs', label: '特殊需求', placeholder: '例如：儿童餐具、素食选项、外带早餐盒', required: false, type: 'textarea' }
    ],
    defaultContent: `🥐 **早餐详情**

**用餐时间**：{{breakfast_time}}

**地点**：{{location}}

**餐食类型**（{{type}}）：
{{#if chinese_items}}
- **中式区**：{{chinese_items}}
{{/if}}
{{#if western_items}}
- **西式区**：{{western_items}}
{{/if}}
{{#if drinks}}
- **饮品区**：{{drinks}}
{{/if}}

**特殊需求**：
{{special_needs}}

---
⚠️ **请门店经理完善早餐详细信息**`,
    completionTips: [
      '请确认早餐的具体时间和地点',
      '列出主要的早餐品类',
      '说明是否有特殊饮食需求的服务'
    ]
  },
  {
    category: 'room_service',
    title: '客房服务',
    icon: '🛏️',
    color: '#13c2c2',
    fields: [
      { key: 'cleaning_time', label: '日常保洁时间', placeholder: '例如：每日09:00-16:00', required: true, type: 'text' },
      { key: 'turndown_service', label: '夜床服务', placeholder: '例如：18:00-21:00自动开启', required: false, type: 'text' },
      { key: 'laundry_service', label: '洗衣服务', placeholder: '例如：09:00-20:00，当日取件需12:00前送洗', required: false, type: 'textarea' },
      { key: 'borrowable_items', label: '物品借用', placeholder: '例如：转换插头、充电器、熨斗、婴儿床', required: true, type: 'textarea' },
      { key: 'paid_services', label: '付费服务', placeholder: '例如：迷你吧商品、送水服务（2元/瓶）', required: false, type: 'textarea' },
      { key: 'service_hotline', label: '服务热线', placeholder: '例如：内线6666', required: true, type: 'text' }
    ],
    defaultContent: `🛏️ **客房服务项目**

**基础服务**：
- **日常保洁**：{{cleaning_time}}（挂"请勿打扰"牌则不打扰）
{{#if turndown_service}}
- **夜床服务**：{{turndown_service}}
{{/if}}
{{#if laundry_service}}
- **洗衣服务**：{{laundry_service}}
{{/if}}

**物品借用**（免费）：
{{borrowable_items}}

{{#if paid_services}}
**付费服务**：
{{paid_services}}
{{/if}}

**紧急联系电话**：
- 客房服务中心：{{service_hotline}}

---
⚠️ **请门店经理补充完整的客房服务列表**`,
    completionTips: [
      '请确认保洁服务的时间',
      '列出所有可免费借用的物品',
      '明确客房服务中心的联系方式'
    ]
  },
  {
    category: 'policy',
    title: '酒店政策',
    icon: '📜',
    color: '#faad14',
    fields: [
      { key: 'checkin_time', label: '入住时间', placeholder: '例如：14:00后', required: true, type: 'text' },
      { key: 'id_required', label: '证件要求', placeholder: '例如：需出示有效身份证件原件', required: true, type: 'text' },
      { key: 'deposit', label: '押金政策', placeholder: '例如：500元/晚，支持现金或信用卡预授权', required: true, type: 'text' },
      { key: 'no_smoking', label: '禁烟政策', placeholder: '例如：禁止在客房吸烟，违者罚款500元', required: true, type: 'text' },
      { key: 'pet_policy', label: '宠物政策', placeholder: '例如：禁止携带宠物（导盲犬除外）', required: true, type: 'text' },
      { key: 'visitor_policy', label: '访客政策', placeholder: '例如：访客需在前台登记，23:00前离开', required: false, type: 'text' },
      { key: 'parking', label: '停车信息', placeholder: '例如：地下停车场B1-B3层，每小时5元，住店客人8折', required: false, type: 'textarea' }
    ],
    defaultContent: `📜 **入住与安全政策**

**入住规定**：
- 入住时间：{{checkin_time}}
- {{id_required}}
- 押金：{{deposit}}

**安全须知**：
- {{no_smoking}}
- {{pet_policy}}
{{#if visitor_policy}}
- {{visitor_policy}}
{{/if}}
- 贵重物品建议使用房间保险箱或寄存前台

{{#if parking}}
**停车信息**：
{{parking}}
{{/if}}

---
⚠️ **请门店经理更新为实际酒店政策**`,
    completionTips: [
      '请确认入住时间和证件要求',
      '明确押金金额和支付方式',
      '说明禁烟、宠物等重要政策'
    ]
  }
];

// 获取分类配置
export function getCategoryConfig(category: string): KnowledgeCategoryConfig | undefined {
  return KNOWLEDGE_BASE_CONFIG.find(c => c.category === category);
}

// 获取所有分类
export function getAllCategories(): { category: string; title: string; icon: string; color: string }[] {
  return KNOWLEDGE_BASE_CONFIG.map(c => ({
    category: c.category,
    title: c.title,
    icon: c.icon,
    color: c.color
  }));
}

// 检查内容完成度
export function checkCompletion(content: string, category: string): { isComplete: boolean; missingFields: string[] } {
  const config = getCategoryConfig(category);
  if (!config) {return { isComplete: false, missingFields: [] };}

  const missingFields: string[] = [];
  
  for (const field of config.fields) {
    if (field.required) {
      // 检查内容中是否包含该字段的占位符或实际内容
      const placeholder = `{{${field.key}}}`;
      const hasPlaceholder = content.includes(placeholder);
      const hasContent = !hasPlaceholder && content.includes(field.label);
      
      if (hasPlaceholder || !hasContent) {
        missingFields.push(field.label);
      }
    }
  }

  return {
    isComplete: missingFields.length === 0,
    missingFields
  };
}
