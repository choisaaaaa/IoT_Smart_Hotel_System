export interface Call {
  id: number;
  hotel_id: number;
  call_id: string;
  caller_type: 'room' | 'front_desk' | 'ai' | 'app';
  caller_id: string;
  callee_type: 'room' | 'front_desk' | 'ai' | 'app';
  callee_id: string;
  status: 'calling' | 'outgoing' | 'ringing' | 'connected' | 'ended' | 'rejected' | 'missed' | 'busy';
  started_at: string;
  answered_at: string | null;
  ended_at: string | null;
  duration_sec: number;
  recording_url: string | null;
  created_at: string;
}

export interface CallInput {
  hotel_id: number;
  caller_type: 'room' | 'front_desk' | 'ai' | 'app';
  caller_id: string;
  callee_type: 'room' | 'front_desk' | 'ai' | 'app';
  callee_id: string;
  type: 'voice' | 'video';
}

export interface CallStatusUpdate {
  status: 'connected' | 'ended' | 'rejected' | 'missed' | 'busy';
  answered_at?: string;
  ended_at?: string;
  duration_sec?: number;
  recording_url?: string;
}

export interface CallQuery {
  page?: number;
  pageSize?: number;
  hotel_id?: number;
  room_id?: string;
  start_time?: string;
  end_time?: string;
}

export interface CallStats {
  total_calls: number;
  total_duration_sec: number;
  answered_calls: number;
  missed_calls: number;
  rejected_calls: number;
  avg_duration_sec: number;
  answer_rate: number;
}
