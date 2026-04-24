import request from './request'
import type { ApiResponse } from '@/types'

export interface RoomMessage {
  id: number
  hotel_id: number
  room_id: number
  booking_id: number | null
  guest_id: number | null
  sender_type: 'guest' | 'front_desk' | 'system'
  sender_id: number | null
  sender_name: string | null
  content: string
  is_read: boolean
  read_at: string | null
  created_at: string
  room_number?: string
}

export interface RoomConversation {
  room_id: number
  room_number: string
  hotel_id: number
  last_message: string | null
  last_message_time: string | null
  unread_count: number
  guest_name: string | null
}

export const messageApi = {
  send: (data: {
    room_id: number
    sender_type: string
    content: string
    hotel_id?: number
    booking_id?: number
    guest_id?: number
    sender_name?: string
  }) => request.post<ApiResponse<RoomMessage>>('/messages', data),

  getMessages: (params: {
    room_id?: number
    hotel_id?: number
    is_read?: number
    page?: number
    pageSize?: number
    before_id?: number
  }) => request.get<ApiResponse<{ list: RoomMessage[]; total: number; page: number; pageSize: number }>>('/messages', { params }),

  getUnreadCount: (params?: { room_id?: number; hotel_id?: number }) =>
    request.get<ApiResponse<{ count: number }>>('/messages/unread-count', { params }),

  markAsRead: (id: number) =>
    request.put<ApiResponse<null>>(`/messages/${id}/read`),

  markAllAsRead: (data?: { room_id?: number; hotel_id?: number }) =>
    request.put<ApiResponse<{ affected: number }>>('/messages/read-all', data),

  getConversations: (params?: { hotel_id?: number }) =>
    request.get<ApiResponse<RoomConversation[]>>('/messages/conversations', { params }),

  deleteMessage: (id: number) =>
    request.delete<ApiResponse<null>>(`/messages/${id}`),

  deleteRoomMessages: (roomId: number) =>
    request.delete<ApiResponse<{ affected: number }>>(`/messages/room/${roomId}`),
}
