import request from './request'
import type { BookingInfo, PaginatedResponse, ApiResponse } from '@/types'

export const bookingApi = {
  getBookingList: (params?: { page?: number; pageSize?: number; status?: string; guest_name?: string; hotel_id?: number; checkin_date?: string; checkout_date?: string }) =>
    request.get<PaginatedResponse<BookingInfo>>('/bookings', { params }),

  createBooking: (data: Partial<BookingInfo> & { hotel_id: number }) =>
    request.post<ApiResponse<BookingInfo>>('/bookings', data),

  lookupBooking: (keyword: string) =>
    request.get<ApiResponse<{
      id: number
      booking_no: string
      guest_name: string
      guest_phone: string
      room_id: number
      room_type_id: number
      hotel_id: number
      room_name: string
      check_in: string
      check_out: string
      status: string
    }>>('/bookings/lookup', { params: { keyword } }),

  checkinOnline: (id: number, data: {
    guest_phone: string
    real_name: string
    id_type: string
    id_number: string
    arrival_time?: string | null
    plate_number?: string | null
    room_id: number
  }) =>
    request.post<ApiResponse<{
      booking_id: number
      booking_no: string
      room_id: number
      room_name: string
      room_pin: string
    }>>(`/bookings/${id}/checkin-online`, data),

  getCalculatedPrice: (params: { 
    room_id?: number; 
    room_type_id?: number;
    rate_plan_id?: number;
    check_in_date: string; 
    check_out_date: string; 
    guest_phone?: string; 
    coupon_id?: number;
    manual_discount?: number;
    manual_reduce?: number;
  }) =>
    request.get<ApiResponse<{ total_price: number; discount_rate: number }>>('/bookings/calculate-price', { params }),

  updateBookingStatus: (id: number, status: string, hotelId?: number) =>
    request.patch<ApiResponse<BookingInfo>>(`/bookings/${id}/status`, { status, ...(hotelId ? { hotel_id: hotelId } : {}) }),

  checkin: (id: number, data?: { 
    guest_name?: string; 
    guest_phone?: string; 
    guest_id_number?: string;
    manual_discount?: number;
    manual_reduce?: number;
    total_price?: number;
  }) =>
    request.put<ApiResponse<null>>(`/bookings/${id}/checkin`, data || {}),

  calculateExtendPrice: (id: number, data: { new_check_out_date: string; coupon_id?: number; used_points?: number }) =>
    request.post<ApiResponse<{
      base_price: number
      discount_rate: number
      member_discount: number
      coupon_discount: number
      points_discount: number
      used_points: number
      total_price: number
      extend_nights: number
    }>>(`/bookings/${id}/extend-price`, data),

  extendStay: (id: number, data: { new_check_out_date: string; coupon_id?: number; used_points?: number; payment_method?: string }) =>
    request.put<ApiResponse<{
      booking_id: number
      new_check_out_date: string
      extend_nights: number
      additional_price: number
      new_total_price: number
      need_payment: boolean
      payment_id: number | null
      coupon_used: boolean
    }>>(`/bookings/${id}/extend`, data),
}
