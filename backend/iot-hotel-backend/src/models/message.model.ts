export interface Message {
  id: number;
  hotel_id: number;
  room_id: number;
  booking_id: number | null;
  guest_id: number | null;
  sender_type: 'guest' | 'front_desk' | 'system';
  sender_id: number | null;
  sender_name: string | null;
  content: string;
  is_read: boolean;
  read_at: string | null;
  created_at: string;
}

export interface MessageInput {
  hotel_id?: number;
  room_id: number;
  booking_id?: number;
  guest_id?: number;
  sender_type: 'guest' | 'front_desk' | 'system';
  sender_id?: number;
  sender_name?: string;
  content: string;
}

export interface RoomConversation {
  room_id: number;
  room_number: string;
  hotel_id: number;
  last_message: string | null;
  last_message_time: string | null;
  unread_count: number;
  guest_name: string | null;
}
