export interface Review {
  id: number;
  hotel_id: number;
  room_type_id: number | null;
  order_id: number;
  order_type: string;
  member_id: number | null;
  user_id: number | null;
  score: number;
  environment_rating: number;
  facility_rating: number;
  comfort_rating: number;
  content: string;
  photos: string[];
  reply: string | null;
  replied_at: string | null;
  is_deleted: number;
  created_at: string;
  updated_at: string;
  member_name?: string;
  member_phone?: string;
  user_avatar?: string;
  hotel_name?: string;
  room_type_name?: string;
}

export interface ReviewInput {
  order_id: number;
  hotel_id?: number;
  room_type_id?: number;
  score: number;
  environment_rating?: number;
  facility_rating?: number;
  comfort_rating?: number;
  content: string;
  photos?: string[];
}

export interface ReviewQuery {
  page?: number;
  pageSize?: number;
  hotel_id?: number;
  user_id?: number;
  order_type?: string;
}

export interface ReviewStats {
  total_reviews: number;
  avg_score: string;
  avg_environment: string;
  avg_facility: string;
  avg_comfort: string;
  good_count: number;
  medium_count: number;
  bad_count: number;
  distribution: { score: number; count: number }[];
}

export interface ReviewAppeal {
  id: number;
  review_id: number;
  hotel_id: number;
  appellant_id: number;
  appeal_reason: string;
  status: 'pending' | 'approved' | 'rejected';
  handler_id: number | null;
  handle_reason: string | null;
  handled_at: string | null;
  created_at: string;
  updated_at: string;
}
