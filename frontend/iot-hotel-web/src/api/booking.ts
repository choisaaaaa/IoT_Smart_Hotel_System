import request from './request'
import type { BookingInfo, PaginatedResponse, ApiResponse } from '@/types'

export const bookingApi = {
  getBookingList: (params?: { page?: number; pageSize?: number; status?: string; guest_name?: string }) =>
    request.get<PaginatedResponse<BookingInfo>>('/bookings', { params }),

  createBooking: (data: Partial<BookingInfo>) =>
    request.post<ApiResponse<BookingInfo>>('/bookings', data),

  lookupBooking: (keyword: string) =>
    request.get<ApiResponse<{
      id: number
      booking_no: string
      guest_name: string
      guest_phone: string
      room_id: number
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
    plate_number?: string
  }) =>
    request.post<ApiResponse<{
      booking_id: number
      booking_no: string
      room_id: number
      room_name: string
      room_pin: string
    }>>(`/bookings/${id}/checkin-online`, data),

  updateBookingStatus: (id: number, status: string) =>
    request.patch<ApiResponse<BookingInfo>>(`/bookings/${id}/status`, { status })
}
