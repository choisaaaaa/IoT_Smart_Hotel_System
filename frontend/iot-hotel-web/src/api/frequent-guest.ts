import axios from 'axios'
import type { AxiosInstance } from 'axios'

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
  private api: AxiosInstance

  constructor() {
    this.api = axios.create({
      baseURL: 'http://localhost:9000/api/v1',
      timeout: 10000,
      headers: {
        'Content-Type': 'application/json'
      }
    })

    this.api.interceptors.request.use((config) => {
      const token = localStorage.getItem('auth_token')
      if (token) {
        config.headers.Authorization = `Bearer ${token}`
      }
      return config
    })
  }

  async list() {
    const res = await this.api.get('/frequent-guests')
    return res.data
  }

  async create(data: FrequentGuest) {
    const res = await this.api.post('/frequent-guests', data)
    return res.data
  }

  async update(id: number, data: FrequentGuest) {
    const res = await this.api.put(`/frequent-guests/${id}`, data)
    return res.data
  }

  async remove(id: number) {
    const res = await this.api.delete(`/frequent-guests/${id}`)
    return res.data
  }
}

export default new GuestService()
