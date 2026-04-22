import request from './request'
import type { ApiResponse } from '@/types'

export interface AIResponse {
  text: string
  audioUrl?: string
  action?: string
  target?: string
  response?: string
  callId?: number
  frontDeskCount?: number
}

export const aiButlerApi = {
  chat: (data: { room_id: string; text?: string; audio?: string; session_id?: string }) =>
    request.post<ApiResponse<AIResponse>>('/ai-butler/chat', data),

  verify: (roomId: string) =>
    request.post<ApiResponse<{
      accessible: boolean
      guestName: string
      checkInDate: string
      checkOutDate: string
      roomList: string[]
      frontDeskOnline: boolean
      frontDeskCount: number
      hotelName: string
    }>>('/ai-butler/verify', { room_id: roomId }),

  wake: (roomId: string, text: string) =>
    request.post<ApiResponse<{ isWake: boolean; accessible: boolean; guestName?: string }>>('/ai-butler/wake', { room_id: roomId, text }),

  broadcast: (roomId: string, text: string) =>
    request.post<ApiResponse<{ room_id: string; device_id: string }>>('/ai-butler/broadcast', { room_id: roomId, text })
}
