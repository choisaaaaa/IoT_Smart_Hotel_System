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

export interface HotelImage {
  id: number
  image_url: string
  image_type: 'cover' | 'gallery' | 'room'
  sort_order: number
  is_active: number
  created_at: string
}

export interface HotelDetail {
  id: number
  hotel_name: string
  hotel_address: string
  hotel_phone: string
  hotel_star: number
  star_rating: number
  rating: number
  review_count: number
  description: string
  city: string
  location: string
  logo: string
  image_url: string
  promotion: string
  created_at: string
  updated_at: string
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

  // 获取酒店详情（带图片列表）
  async getHotelDetailWithImages(hotelId: number): Promise<{ hotel: HotelDetail; images: HotelImage[] }> {
    const response: any = await request.get<ApiResponse<{ hotel: HotelDetail; images: HotelImage[] }>>(`/hotels/${hotelId}/detail`)
    return response?.data || { hotel: {} as HotelDetail, images: [] }
  }

  // 更新酒店信息
  async updateHotel(hotelId: number, data: Partial<HotelDetail>): Promise<any> {
    const response: any = await request.put<ApiResponse<any>>(`/hotels/${hotelId}`, data)
    return response?.data
  }

  // 获取酒店图片列表
  async getHotelImages(hotelId: number): Promise<HotelImage[]> {
    const response: any = await request.get<ApiResponse<{ images: HotelImage[] }>>(`/hotels/${hotelId}/images`)
    return response?.data?.images || []
  }

  // 添加酒店图片
  async addHotelImage(hotelId: number, data: { image_url: string; image_type?: string; sort_order?: number }): Promise<any> {
    const response: any = await request.post<ApiResponse<any>>(`/hotels/${hotelId}/images`, data)
    return response?.data
  }

  // 更新酒店图片
  async updateHotelImage(hotelId: number, imageId: number, data: Partial<HotelImage>): Promise<any> {
    const response: any = await request.put<ApiResponse<any>>(`/hotels/${hotelId}/images/${imageId}`, data)
    return response?.data
  }

  // 删除酒店图片
  async deleteHotelImage(hotelId: number, imageId: number): Promise<any> {
    const response: any = await request.delete<ApiResponse<any>>(`/hotels/${hotelId}/images/${imageId}`)
    return response?.data
  }

  async getRoomAvailability(hotelId: number, checkIn: string, checkOut: string): Promise<any> {
    const response: any = await request.get<ApiResponse<{ roomTypes: any[] }>>(
      `/hotels/${hotelId}/rooms/availability`,
      {
        params: { check_in: checkIn, check_out: checkOut }
      }
    )
    return response.data || response
  }

  async createBooking(bookingData: {
    room_id?: number
    room_type_id?: number
    rate_plan_id?: number
    check_in_date: string
    check_out_date: string
    guest_name: string
    guest_phone: string
    guest_id_number: string
    guest_count?: number
    special_requests?: string
    payment_method?: string
    coupon_id?: number
    used_points?: number
    status?: string
  }): Promise<any> {
    const response: any = await request.post<ApiResponse<any>>(
      '/bookings',
      bookingData
    )
    return response?.data
  }

  async getStatistics(year?: number, month?: number): Promise<any> {
    const response: any = await request.get<ApiResponse<any>>('/hotel/statistics', {
      params: { year, month }
    })
    return response?.data
  }
}

export const hotelApi = new HotelApi()
