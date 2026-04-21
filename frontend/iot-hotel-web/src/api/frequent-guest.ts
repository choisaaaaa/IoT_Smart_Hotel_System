import request from './request'
import type { ApiResponse } from '@/types'

export interface FrequentGuest {
  id?: number
  user_id?: number
  name: string
  phone: string
  id_type: 'idcard' | 'passport'
  id_number: string
  created_at?: string
  updated_at?: string
}

class GuestService {
  async list() {
    const res = await request.get<ApiResponse<{ guests: FrequentGuest[] }>>('/frequent-guests')
    return res.data
  }

  async create(data: FrequentGuest) {
    const res = await request.post<ApiResponse<FrequentGuest>>('/frequent-guests', data)
    return res.data
  }

  async update(id: number, data: FrequentGuest) {
    const res = await request.put<ApiResponse<FrequentGuest>>(`/frequent-guests/${id}`, data)
    return res.data
  }

  async remove(id: number) {
    const res = await request.delete<ApiResponse<any>>(`/frequent-guests/${id}`)
    return res.data
  }
}

export default new GuestService()
