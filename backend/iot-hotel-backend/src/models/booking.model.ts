export interface Booking {
  id: number;
  hotel_id: number;
  booking_number: string;
  room_id: number;
  guest_name: string;
  guest_phone: string;
  guest_id_number: string;
  check_in_date: string;
  check_out_date: string;
  guest_count: number;
  special_requests: string;
  payment_method: string;
  total_price: number;
  deposit: number;
  status: string;
  created_at: string;
  updated_at: string;
  check_in_time: string;
  check_out_time: string;
  cancelled_at: string;
}

export interface BookingInput {
  hotel_id: number;
  room_id: number;
  guest_name: string;
  guest_phone: string;
  guest_id_number?: string;
  check_in_date: string;
  check_out_date: string;
  guest_count?: number;
  special_requests?: string;
  payment_method?: string;
}

export interface BookingQuery {
  page?: number;
  pageSize?: number;
  hotel_id?: number;
  status?: string;
  guest_name?: string;
}

export interface BookingStatusUpdate {
  status: 'confirmed' | 'checked_in' | 'checked_out' | 'cancelled';
}
