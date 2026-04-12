import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { v4 as uuidv4 } from 'uuid';

export interface DeliveryOrder extends RowDataPacket {
  id: number;
  order_no: string;
  room_id: number;
  item_name: string;
  quantity: number;
  note: string;
  status: string;
  created_at: Date;
  updated_at: Date;
  completed_at: Date;
  room_number?: string;
}

export interface DeliveryOrderListResponse {
  list: DeliveryOrder[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

export class DeliveryOrderService {
  static async getDeliveryOrders(params: {
    page?: number;
    pageSize?: number;
    status?: string;
    hotelId: number;
  }): Promise<DeliveryOrderListResponse> {
    try {
      const { page = 1, pageSize = 10, status, hotelId } = params;
      const offset = (Number(page) - 1) * Number(pageSize);

      let whereClause = 'WHERE d.hotel_id = ?';
      const paramsArray: any[] = [hotelId];

      if (status) {
        whereClause += ' AND d.status = ?';
        paramsArray.push(status);
      }

      const [totalRows] = await pool.query<RowDataPacket[]>(`SELECT COUNT(*) as total FROM delivery_orders d ${whereClause}`, paramsArray);
      const total = (totalRows[0] as any).total;

      const [rows] = await pool.query<RowDataPacket[]>(
        `SELECT d.*, r.room_number FROM delivery_orders d LEFT JOIN rooms r ON d.room_id = r.id ${whereClause} ORDER BY d.id DESC LIMIT ? OFFSET ?`,
        [...paramsArray, Number(pageSize), offset]
      );

      return {
        list: rows as DeliveryOrder[],
        total,
        page: Number(page),
        pageSize: Number(pageSize),
        totalPages: Math.ceil(total / Number(pageSize))
      };
    } catch (error) {
      logger.error('获取送物订单列表失败:', error.message);
      throw new Error('获取送物订单列表失败');
    }
  }

  static async getDeliveryOrderById(id: number, hotelId: number): Promise<DeliveryOrder | null> {
    try {
      const [rows] = await pool.query<RowDataPacket[]>(
        'SELECT d.*, r.room_number FROM delivery_orders d LEFT JOIN rooms r ON d.room_id = r.id WHERE d.id = ? AND d.hotel_id = ?',
        [id, hotelId]
      );
      return (rows[0] as DeliveryOrder) || null;
    } catch (error) {
      logger.error('获取送物订单详情失败:', error.message);
      throw new Error('获取送物订单详情失败');
    }
  }

  static async createDeliveryOrder(data: {
    hotel_id: number;
    room_id: number;
    item_name: string;
    quantity: number;
    note: string;
  }): Promise<{ id: number; order_no: string }> {
    try {
      const { hotel_id, room_id, item_name, quantity, note } = data;

      const orderNo = `DEL${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${uuidv4().slice(0, 8).toUpperCase()}`;

      const [result] = await pool.query<ResultSetHeader>(
        'INSERT INTO delivery_orders (hotel_id, order_no, room_id, item_name, quantity, note, status) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [hotel_id, orderNo, room_id, item_name, quantity, note, 'pending']
      );

      return {
        id: result.insertId,
        order_no: orderNo
      };
    } catch (error) {
      logger.error('创建送物订单失败:', error.message);
      throw new Error('创建送物订单失败');
    }
  }

  static async completeDeliveryOrder(id: number, hotelId: number): Promise<boolean> {
    try {
      const [result] = await pool.query<ResultSetHeader>(
        'UPDATE delivery_orders SET status = ?, completed_at = CURRENT_TIMESTAMP WHERE id = ? AND hotel_id = ?',
        ['completed', id, hotelId]
      );
      return result.affectedRows > 0;
    } catch (error) {
      logger.error('完成送物订单失败:', error.message);
      throw new Error('完成送物订单失败');
    }
  }
}
