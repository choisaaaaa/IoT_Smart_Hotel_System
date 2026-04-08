import request from './request'
import type { BookingInfo, PaginatedResponse, ApiResponse } from '@/types'

export const bookingApi = {
  getBookingList: (params?: { page?: number; pageSize?: number; status?: string; guest_name?: string }) =>
    request.get<PaginatedResponse<BookingInfo>>('/bookings', { params }),

  createBooking: (data: Partial<BookingInfo>) =>
    request.post<ApiResponse<BookingInfo>>('/bookings', data),

  updateBookingStatus: (id: number, status: string) =>
    request.patch<ApiResponse<BookingInfo>>(`/bookings/${id}/status`, { status })
}
