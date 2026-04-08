import request from './request'
import type { ApiResponse } from '@/types'

export interface CallRecord {
  call_id: string
  caller_type: string
  caller_id: string
  callee_type: string
  callee_id: string
  status: 'calling' | 'outgoing' | 'ringing' | 'connected' | 'ended' | 'rejected'
  started_at: string
  answered_at?: string
  ended_at?: string
  duration_sec?: number
}

export const callApi = {
  outbound: (data: { caller_id: string; callee_type: 'room' | 'front_desk' | 'ai' | 'app'; callee_id: string; caller_type?: 'front_desk' | 'ai' | 'app'; type?: 'voice' }) =>
    request.post<ApiResponse<CallRecord>>('/calls/outbound', data),

  answer: (callId: string) =>
    request.post<ApiResponse<CallRecord>>(`/calls/${callId}/answer`),

  reject: (callId: string) =>
    request.post<ApiResponse<CallRecord>>(`/calls/${callId}/reject`),

  hangup: (callId: string) =>
    request.post<ApiResponse<CallRecord>>(`/calls/${callId}/hangup`),

  getStatus: (callId: string) =>
    request.get<ApiResponse<CallRecord>>(`/calls/${callId}/status`),

  getActive: () =>
    request.get<ApiResponse<{ items: CallRecord[] }>>('/calls/active'),

  getHistory: (params?: { page?: number; limit?: number; room_id?: string; start_time?: string; end_time?: string }) =>
    request.get<ApiResponse<{ total: number; page: number; limit: number; items: CallRecord[] }>>('/calls/history', { params }),

  getStats: (params?: { room_id?: string; start_time?: string; end_time?: string }) =>
    request.get<ApiResponse<{
      total_calls: number
      total_duration_sec: number
      answered_calls: number
      missed_calls: number
      rejected_calls: number
      avg_duration_sec: number
      answer_rate: number
    }>>('/calls/stats', { params })
}
