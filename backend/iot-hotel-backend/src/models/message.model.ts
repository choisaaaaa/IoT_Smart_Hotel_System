 export interface Message {
  id: number;
  room_id: number;
  booking_id: number | null;
  guest_id: number | null;
  sender_type: 'guest' | 'front_desk' | 'ai';
  sender_id: string;
  content: string;
  is_read: boolean;
  created_at: string;
}

export interface MessageInput {
  room_id: number;
  booking_id?: number;
  guest_id?: number;
  sender_type: 'guest' | 'front_desk' | 'ai';
  sender_id: string;
  content: string;
}
