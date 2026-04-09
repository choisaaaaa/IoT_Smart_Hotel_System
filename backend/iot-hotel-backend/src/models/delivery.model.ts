export interface DeliveryOrder {
  id: number;
  hotel_id: number;
  order_no: string;
  room_id: number;
  item_name: string;
  quantity: number;
  note: string;
  status: string;
  created_at: string;
  updated_at: string;
  completed_at: string;
}

export interface DeliveryOrderInput {
  hotel_id: number;
  room_id: number;
  item_name: string;
  quantity: number;
  note?: string;
}

export interface DeliveryOrderQuery {
  page?: number;
  pageSize?: number;
  hotel_id?: number;
  status?: string;
}
