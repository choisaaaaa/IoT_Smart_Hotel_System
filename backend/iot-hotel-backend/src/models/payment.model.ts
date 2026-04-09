export interface Payment {
  id: number;
  hotel_id: number;
  payment_no: string;
  order_type: string;
  order_id: number;
  amount: number;
  payment_method: string;
  status: string;
  transaction_no: string;
  paid_at: string;
  description: string;
  created_at: string;
  updated_at: string;
}

export interface PaymentInput {
  hotel_id: number;
  order_type: string;
  order_id: number;
  amount: number;
  payment_method: string;
  description?: string;
}

export interface PaymentQuery {
  page?: number;
  pageSize?: number;
  hotel_id?: number;
  status?: string;
  order_type?: string;
}
