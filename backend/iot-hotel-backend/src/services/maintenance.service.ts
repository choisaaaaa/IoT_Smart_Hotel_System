import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { v4 as uuidv4 } from 'uuid';

export interface MaintenanceTicket extends RowDataPacket {
  id: number;
  ticket_no: string;
  room_id: number;
  fault_type: string;
  fault_description: string;
  photos: string;
  priority: string;
  status: string;
  created_at: Date;
  updated_at: Date;
  completed_at: Date;
  repair_description: string;
  repair_cost: number;
  repairer?: string;
  assigned_at?: Date;
  room_number?: string;
}

export interface MaintenanceTicketListResponse {
  list: MaintenanceTicket[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

export class MaintenanceTicketService {
  static async getMaintenanceTickets(params: {
    page?: number;
    pageSize?: number;
    status?: string;
    fault_type?: string;
    priority?: string;
    hotelId: number;
  }): Promise<MaintenanceTicketListResponse> {
    try {
      const { page = 1, pageSize = 10, status, fault_type, priority, hotelId } = params;
      const offset = (Number(page) - 1) * Number(pageSize);

      let whereClause = 'WHERE m.hotel_id = ?';
      const paramsArray: any[] = [hotelId];

      if (status) {
        whereClause += ' AND m.status = ?';
        paramsArray.push(status);
      }

      if (fault_type) {
        whereClause += ' AND m.fault_type = ?';
        paramsArray.push(fault_type);
      }

      if (priority) {
        whereClause += ' AND m.priority = ?';
        paramsArray.push(priority);
      }

      const [totalRows] = await pool.query<RowDataPacket[]>(`SELECT COUNT(*) as total FROM maintenance_tickets m ${whereClause}`, paramsArray);
      const total = (totalRows[0] as any).total;

      const [rows] = await pool.query<RowDataPacket[]>(
        `SELECT m.*, r.room_number FROM maintenance_tickets m LEFT JOIN rooms r ON m.room_id = r.id ${whereClause} ORDER BY m.id DESC LIMIT ? OFFSET ?`,
        [...paramsArray, Number(pageSize), offset]
      );

      return {
        list: rows as MaintenanceTicket[],
        total,
        page: Number(page),
        pageSize: Number(pageSize),
        totalPages: Math.ceil(total / Number(pageSize))
      };
    } catch (error) {
      logger.error('获取报修工单列表失败:', error);
      throw new Error('获取报修工单列表失败');
    }
  }

  static async getMaintenanceTicketById(id: number, hotelId: number): Promise<MaintenanceTicket | null> {
    try {
      const [rows] = await pool.query<RowDataPacket[]>(
        'SELECT m.*, r.room_number FROM maintenance_tickets m LEFT JOIN rooms r ON m.room_id = r.id WHERE m.id = ? AND m.hotel_id = ?',
        [id, hotelId]
      );
      return (rows[0] as MaintenanceTicket) || null;
    } catch (error) {
      logger.error('获取报修工单详情失败:', error);
      throw new Error('获取报修工单详情失败');
    }
  }

  static async createMaintenanceTicket(data: {
    hotel_id: number;
    room_id: number;
    fault_type: string;
    fault_description: string;
    photos: string[];
    priority: string;
  }): Promise<{ id: number; ticket_no: string }> {
    try {
      const { hotel_id, room_id, fault_type, fault_description, photos, priority } = data;

      const ticketNo = `MT${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${uuidv4().slice(0, 8).toUpperCase()}`;

      const [result] = await pool.query<ResultSetHeader>(
        'INSERT INTO maintenance_tickets (hotel_id, ticket_no, room_id, fault_type, fault_description, photos, priority, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [hotel_id, ticketNo, room_id, fault_type, fault_description, JSON.stringify(photos || []), priority, 'pending']
      );

      return {
        id: result.insertId,
        ticket_no: ticketNo
      };
    } catch (error) {
      logger.error('创建报修工单失败:', error);
      throw new Error('创建报修工单失败');
    }
  }

  static async assignTicket(id: number, hotelId: number, repairer: string): Promise<boolean> {
    try {
      const [result] = await pool.query<ResultSetHeader>(
        'UPDATE maintenance_tickets SET status = ?, repairer = ?, assigned_at = CURRENT_TIMESTAMP WHERE id = ? AND hotel_id = ?',
        ['assigned', repairer, id, hotelId]
      );
      return result.affectedRows > 0;
    } catch (error) {
      logger.error('分配维修人员失败:', error);
      throw new Error('分配维修人员失败');
    }
  }

  static async completeTicket(id: number, hotelId: number, repair_description: string, repair_cost: number): Promise<boolean> {
    try {
      const [result] = await pool.query<ResultSetHeader>(
        'UPDATE maintenance_tickets SET status = ?, repair_description = ?, repair_cost = ?, completed_at = CURRENT_TIMESTAMP WHERE id = ? AND hotel_id = ?',
        ['completed', repair_description, repair_cost, id, hotelId]
      );
      return result.affectedRows > 0;
    } catch (error) {
      logger.error('完成报修工单失败:', error);
      throw new Error('完成报修工单失败');
    }
  }
}
