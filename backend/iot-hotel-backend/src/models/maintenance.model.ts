export interface MaintenanceTicket {
  id: number;
  hotel_id: number;
  ticket_no: string;
  room_id: number;
  fault_type: string;
  fault_description: string;
  photos: string[];
  priority: string;
  status: string;
  created_at: string;
  updated_at: string;
  completed_at: string;
  repair_description: string;
  repair_cost: number;
}

export interface MaintenanceTicketInput {
  hotel_id: number;
  room_id: number;
  fault_type: string;
  fault_description: string;
  photos?: string[];
  priority?: string;
}

export interface MaintenanceTicketQuery {
  page?: number;
  pageSize?: number;
  hotel_id?: number;
  status?: string;
  fault_type?: string;
  priority?: string;
}

export interface MaintenanceTicketUpdate {
  repairer?: string;
  repair_description?: string;
  repair_cost?: number;
}
