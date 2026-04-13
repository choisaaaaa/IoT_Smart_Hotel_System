import request from './request'

export interface KnowledgeBase {
  id: number
  hotel_id: number
  category: string
  title: string
  content: string
  keywords?: string | null
  is_active: number
  sort_order: number
  created_by?: number | null
  updated_by?: number | null
  created_at: string
  updated_at: string
}

export type CategoryType = 'restaurant' | 'gym' | 'wifi' | 'nearby' | 'checkout' | 'breakfast' | 'room_service' | 'policy' | 'other'

export const CATEGORIES: Record<CategoryType, { label: string; icon: string; color: string }> = {
  restaurant: { label: '餐厅信息', icon: '🍽️', color: '#f5222d' },
  gym: { label: '健身中心', icon: '💪', color: '#fa8c16' },
  wifi: { label: '网络服务', icon: '📶', color: '#1890ff' },
  nearby: { label: '周边推荐', icon: '🏪', color: '#52c41a' },
  checkout: { label: '退房须知', icon: '📋', color: '#722ed1' },
  breakfast: { label: '早餐服务', icon: '🥐', color: '#eb2f96' },
  room_service: { label: '客房服务', icon: '🛏️', color: '#13c2c2' },
  policy: { label: '酒店政策', icon: '📜', color: '#faad14' },
  other: { label: '其他信息', icon: 'ℹ️', color: '#8c8c8c' }
}

export const getKnowledgeList = (params?: { category?: string; is_active?: number }) => {
  return request.get('/knowledge-base', { params })
}

export const getKnowledgeById = (id: number) => {
  return request.get(`/knowledge-base/${id}`)
}

export const createOrUpdateKnowledge = (category: string, data: Partial<KnowledgeBase>) => {
  return request.put(`/knowledge-base/${category}`, data)
}

export const toggleKnowledgeActive = (id: number) => {
  return request.patch(`/knowledge-base/${id}/toggle`)
}

export const deleteKnowledge = (id: number) => {
  return request.delete(`/knowledge-base/${id}`)
}

export const initDefaultKnowledge = () => {
  return request.get('/knowledge-base/init')
}
