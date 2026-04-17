export interface Coupon {
  id: number;
  hotel_id: number;
  hotel_ids?: string; // 适用门店ID列表，逗号分隔，如 "1,2,3"
  coupon_name: string;
  coupon_type: string;
  discount_value: number;
  min_amount: number;
  total_count: number;
  received_count: number;
  valid_from: string;
  valid_to: string;
  created_at: string;
  updated_at: string;
}

export interface CouponInput {
  hotel_id: number;
  hotel_ids?: string; // 适用门店ID列表，逗号分隔，如 "1,2,3"
  coupon_name: string;
  coupon_type: string;
  discount_value: number;
  min_amount: number;
  total_count: number;
  valid_from: string;
  valid_to: string;
}

export interface CouponQuery {
  page?: number;
  pageSize?: number;
  hotel_id?: number;
  status?: string;
}
