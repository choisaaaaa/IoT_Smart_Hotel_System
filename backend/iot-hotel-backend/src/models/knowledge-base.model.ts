export interface KnowledgeBase {
  id: number;
  hotel_id: number;
  category: string;
  title: string;
  content: string;
  keywords?: string | null;
  is_active: number;
  sort_order: number;
  created_by?: number | null;
  updated_by?: number | null;
  created_at: string;
  updated_at: string;
}

export interface KnowledgeBaseInput {
  title?: string;
  content?: string;
  keywords?: string | null;
  is_active?: number;
  sort_order?: number;
}

export type CategoryType = 'restaurant' | 'gym' | 'wifi' | 'nearby' | 'checkout' | 'breakfast' | 'room_service' | 'policy' | 'other';

export const CATEGORIES: Record<CategoryType, { label: string; icon: string }> = {
  restaurant: { label: '餐厅信息', icon: '🍽️' },
  gym: { label: '健身中心', icon: '💪' },
  wifi: { label: '网络服务', icon: '📶' },
  nearby: { label: '周边推荐', icon: '🏪' },
  checkout: { label: '退房须知', icon: '📋' },
  breakfast: { label: '早餐服务', icon: '🥐' },
  room_service: { label: '客房服务', icon: '🛏️' },
  policy: { label: '酒店政策', icon: '📜' },
  other: { label: '其他信息', icon: 'ℹ️' }
};
