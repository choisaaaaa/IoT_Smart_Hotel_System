export interface ApiResponse<T = any> {
  code: number
  message: string
  data: T
  timestamp: number
}

export interface PaginatedResponse<T = any> extends ApiResponse<{
  list: T[]
  total: number
  page: number
  pageSize: number
  totalPages: number
}> {}

export interface HotelInfo {
  id: number
  hotel_name: string
  hotel_address: string
  hotel_phone: string
  hotel_star: number
  total_rooms: number
  occupied_rooms: number
  occupancy_rate: string
  logo: string | null
  description: string
  created_at: string
  updated_at: string
}

export interface RoomTypeInfo {
  id: number
  name: string
  code: string
  base_price: string | number
  area: number
  bed_type: string
  max_guests: number
  facilities: string[]
  description: string
  images?: string[]
  created_at: string
  updated_at: string
}

export interface FloorInfo {
  id: number
  floor_number: number
  floor_name: string
  floor_plan_image?: string
  description?: string
  created_at: string
  updated_at: string
}

export interface RoomInfo {
  id: number
  hotel_id: number
  room_number: string
  room_type: string
  room_type_id: number
  room_name: string
  room_price: string | number
  room_status: 'available' | 'occupied' | 'maintenance' | 'cleaning' | 'reserved'
  floor: number
  area: string | number
  bed_type: 'single' | 'double' | 'king' | 'twin'
  max_guests: number
  description: string
  facilities: string[]
  images: string[] | null
  created_at: string
  updated_at: string
  // Join fields
  room_type_name?: string
  room_type_code?: string
}

export interface DeviceInfo {
  id: number
  device_id: string
  device_type: 'main' | 'sub1' | 'sub2' | 'sensor' | 'actuator'
  device_name: string
  device_key: string
  device_status: 'online' | 'offline' | 'error' | 'unknown'
  firmware_version: string
  last_seen: string
  audit_status: 'pending' | 'approved' | 'rejected'
  room_id?: number
  room_number?: string
  area?: string
  ip_address?: string
  mac_address?: string
  created_at: string
  updated_at: string
}

export interface BookingInfo {
  id: number
  booking_number: string
  room_id: number
  guest_name: string
  guest_phone: string
  check_in_date: string
  check_out_date: string
  guest_count: number
  payment_method: string
  total_price: string
  status: string
  created_at: string
  updated_at: string
}

export interface SensorDataPayload {
  device_id: string
  sensor_type: string
  value: number | string
  unit?: string
  timestamp?: string
}

export interface DeviceStatusPayload {
  device_id: string
  status: string
  firmware_version?: string
  signal_strength?: number
  battery_level?: number
}

export interface CommandResultPayload {
  command_id: string
  device_id: string
  command_type: string
  result: string
  value?: any
  error_code?: string
}