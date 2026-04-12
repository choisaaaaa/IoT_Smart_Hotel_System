import pool, { RowDataPacket, ResultSetHeader } from '../config/database';
import logger from '../utils/logger';
import { hashPassword, comparePassword } from '../utils/password';

export interface Member extends RowDataPacket {
  id: number;
  phone: string;
  password: string;
  name: string;
  id_number: string;
  member_level: string;
  points: number;
  balance: number;
  total_spent: number;
  total_stays: number;
  created_at: Date;
  updated_at: Date;
}

export interface MemberListResponse {
  list: Member[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

export class MemberService {
  static async getMembers(params: {
    page?: number;
    pageSize?: number;
    level?: string;
  }): Promise<MemberListResponse> {
    try {
      const { page = 1, pageSize = 10, level } = params;
      const offset = (Number(page) - 1) * Number(pageSize);
      
      let whereClause = 'WHERE 1=1';
      const paramsArray: any[] = [];
      
      if (level) {
        whereClause += ' AND member_level = ?';
        paramsArray.push(level);
      }
      
      const [totalRows] = await pool.query<RowDataPacket[]>(`SELECT COUNT(*) as total FROM members ${whereClause}`, paramsArray);
      const total = (totalRows[0] as any).total;
      
      const [rows] = await pool.query<RowDataPacket[]>(
        `SELECT * FROM members ${whereClause} ORDER BY id DESC LIMIT ? OFFSET ?`,
        [...paramsArray, Number(pageSize), offset]
      );
      
      return {
        list: rows as Member[],
        total,
        page: Number(page),
        pageSize: Number(pageSize),
        totalPages: Math.ceil(total / Number(pageSize))
      };
    } catch (error) {
      logger.error('获取会员列表失败:', error.message);
      throw new Error('获取会员列表失败');
    }
  }

  static async getMemberById(id: number): Promise<Member | null> {
    try {
      const [rows] = await pool.query<RowDataPacket[]>('SELECT * FROM members WHERE id = ?', [id]);
      return (rows[0] as Member) || null;
    } catch (error) {
      logger.error('获取会员详情失败:', error.message);
      throw new Error('获取会员详情失败');
    }
  }

  static async getMemberByPhone(phone: string): Promise<Member | null> {
    try {
      const [rows] = await pool.query<RowDataPacket[]>('SELECT * FROM members WHERE phone = ?', [phone]);
      return (rows[0] as Member) || null;
    } catch (error) {
      logger.error('获取会员信息失败:', error.message);
      throw new Error('获取会员信息失败');
    }
  }

  static async registerMember(data: {
    phone: string;
    password: string;
    name: string;
    id_number: string;
  }): Promise<{ id: number }> {
    try {
      const { phone, password, name, id_number } = data;
      
      const [existingRows] = await pool.query<RowDataPacket[]>('SELECT * FROM members WHERE phone = ?', [phone]);
      
      if (existingRows.length > 0) {
        throw new Error('手机号已注册');
      }
      
      const hashedPassword = await hashPassword(password);
      
      const [result] = await pool.query<ResultSetHeader>(
        'INSERT INTO members (phone, password, name, id_number, member_level, points, balance, total_spent, total_stays) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [phone, hashedPassword, name, id_number, 'standard', 0, 0.00, 0.00, 0]
      );
      
      return { id: result.insertId };
    } catch (error) {
      logger.error('注册会员失败:', error.message);
      throw new Error('注册会员失败');
    }
  }

  static async updateMember(id: number, data: Partial<Member>): Promise<boolean> {
    try {
      const { name, id_number, member_level, points, balance, total_spent, total_stays } = data;
      
      const [result] = await pool.query<ResultSetHeader>(
        'UPDATE members SET name = ?, id_number = ?, member_level = ?, points = ?, balance = ?, total_spent = ?, total_stays = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        [name, id_number, member_level, points, balance, total_spent, total_stays, id]
      );
      
      return result.affectedRows > 0;
    } catch (error) {
      logger.error('更新会员信息失败:', error.message);
      throw new Error('更新会员信息失败');
    }
  }

  static async login(phone: string, password: string): Promise<{ id: number; phone: string; name: string; member_level: string; points: number; balance: number } | null> {
    try {
      const member = await this.getMemberByPhone(phone);
      
      if (!member) {
        throw new Error('手机号或密码错误');
      }
      
      const isPasswordValid = await comparePassword(password, member.password);
      
      if (!isPasswordValid) {
        throw new Error('手机号或密码错误');
      }
      
      return {
        id: member.id,
        phone: member.phone,
        name: member.name,
        member_level: member.member_level,
        points: member.points,
        balance: member.balance
      };
    } catch (error) {
      logger.error('会员登录失败:', error.message);
      throw new Error('登录失败');
    }
  }
}
