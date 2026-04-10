import request from './request'
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
  async searchHotels(params: SearchParams): Promise<HotelInfo[]> {
    const response: any = await request.get<ApiResponse<{ hotels: HotelInfo[] }>>('/hotels/search', { params })
    const payload = response?.data
    if (Array.isArray(payload?.hotels)) return payload.hotels
    if (Array.isArray(payload)) return payload
    return []
  }

  async getHotelDetail(hotelId: number): Promise<HotelInfo> {
    const response: any = await request.get<ApiResponse<{ hotel: HotelInfo }>>(`/hotels/${hotelId}`)
    const payload = response?.data
    return payload?.hotel || payload
  }

  async getRoomAvailability(hotelId: number, checkIn: string, checkOut: string): Promise<RoomInfo[]> {
    const response: any = await request.get<ApiResponse<{ rooms: RoomInfo[] }>>(
      `/hotels/${hotelId}/rooms/availability`,
      {
        params: { check_in: checkIn, check_out: checkOut }
      }
    )
    const payload = response?.data
    if (Array.isArray(payload?.rooms)) return payload.rooms
    if (Array.isArray(payload)) return payload
    return []
  }

  async createBooking(bookingData: {
    room_id: number
    check_in_date: string
    check_out_date: string
    guest_name: string
    guest_phone: string
    guest_id_number: string
    guest_count?: number
    special_requests?: string
    payment_method?: string
    coupon_id?: number
    status?: string
  }): Promise<any> {
    const response: any = await request.post<ApiResponse<any>>(
      '/bookings',
      bookingData
    )
    return response?.data
  }
}

export const hotelApi = new HotelApi()
