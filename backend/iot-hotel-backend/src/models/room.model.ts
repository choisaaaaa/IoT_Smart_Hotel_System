export interface Room {
  id: number;
  hotel_id: number;
  room_number: string;
  room_type: string;
  room_name: string;
  room_price: number;
  room_status: string;
  floor: number;
  area: number;
  bed_type: string;
  max_guests: number;
  description: string;
  facilities: any[];
  images: string[];
  created_at: string;
  updated_at: string;
}

export interface RoomInput {
  hotel_id: number;
  room_number: string;
  room_type?: string;
  room_name?: string;
  room_price?: number;
  room_status?: string;
  floor?: number;
  area?: number;
  bed_type?: string;
  max_guests?: number;
  description?: string;
  facilities?: any[];
  images?: string[];
}

export interface RoomQuery {
  page?: number;
  pageSize?: number;
  hotel_id?: number;
  status?: string;
  type?: string;
}
