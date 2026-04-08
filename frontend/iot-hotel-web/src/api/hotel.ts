import axios from 'axios'
import type { ApiResponse } from '@/types'

export interface RoomInfo {
  id: number
  room_number: string
  room_name: string
  room_type: string
  room_price: number
  floor: number
  area: number
  bed_type: string
  max_guests: number
  room_status: 'available' | 'occupied' | 'maintenance'
  facilities: string[]
  available_count?: number
}

export interface HotelInfo {
  id: number
  name: string
  location: string
  star: number
  rating: number
  review_count: number
  price: number
  image: string
  promotion?: string
  rooms: RoomInfo[]
}

export interface SearchParams {
  destination?: string
  check_in: string
  check_out: string
  rooms: number
  guests: number
}

class HotelApi {
  private api = axios.create({
    baseURL: 'http://localhost:9000/api/v1',
    timeout: 10000
  })

  // 搜索酒店
  async searchHotels(params: SearchParams): Promise<HotelInfo[]> {
    const response = await this.api.get<ApiResponse<HotelInfo[]>>('/hotels/search', { params })
    return response.data.data || []
  }

  // 获取酒店详情
  async getHotelDetail(hotelId: number): Promise<HotelInfo> {
    const response = await this.api.get<ApiResponse<HotelInfo>>(`/hotels/${hotelId}`)
    return response.data.data!
  }

  // 查询客房余量
  async getRoomAvailability(hotelId: number, checkIn: string, checkOut: string): Promise<RoomInfo[]> {
    const response = await this.api.get<ApiResponse<RoomInfo[]>>(
      `/hotels/${hotelId}/rooms/availability`,
      {
        params: { check_in: checkIn, check_out: checkOut }
      }
    )
    return response.data.data || []
  }

  // 创建预订
  async createBooking(bookingData: {
    hotel_id: number
    room_id: number
    check_in: string
    check_out: string
    guest_name: string
    guest_phone: string
    guest_id_type: string
    guest_id_number: string
    remark?: string
  }): Promise<{ booking_no: string }> {
    const response = await this.api.post<ApiResponse<{ booking_no: string }>>(
      '/bookings',
      bookingData
    )
    return response.data.data!
  }
}

export const hotelApi = new HotelApi()
