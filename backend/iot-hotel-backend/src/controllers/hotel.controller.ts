import { Request, Response } from 'express';
import { successResponse, errorResponse, AuthRequest } from '../types';
import { HotelService } from '../services/hotel.service';
import pool, { ResultSetHeader, RowDataPacket } from '../config/database';
import logger from '../utils/logger';
import { isSystemAdmin, isHotelAdmin, normalizeRole, CANONICAL_ROLES } from '../utils/role';

export const get = async (req: AuthRequest, res: Response) => {
  try {
    let hotelId = req.user?.hotel_id;
    const userRole = normalizeRole(req.user?.role);

    // 如果是集团超管 (Hotel ID 为 0 或 角色为 system)
    if (isSystemAdmin(userRole) || hotelId === 0) {
      // 集团超管返回一个虚拟的集团信息，或者根据 query 指定酒店
      const queryHotelId = req.query.hotel_id;
      if (queryHotelId) {
        const id = parseInt(queryHotelId as string);
        const hotel = await HotelService.getHotelById(id);
        if (!hotel) return res.status(404).json(errorResponse('酒店不存在'));
        return res.json(successResponse(hotel, '获取指定酒店信息成功'));
      }

      // 返回虚拟的集团信息
      return res.json(successResponse({
        id: 0,
        hotel_name: '智联酒店集团总部',
        hotel_address: '云端管理中心',
        hotel_phone: '400-888-8888',
        logo: null,
        description: '全球领先的智联酒店管理系统'
      }, '获取集团总部信息成功'));
    }

    if (hotelId === undefined || hotelId === null) {
      return res.status(401).json(errorResponse('未授权，缺少酒店绑定信息'));
    }

    const hotel = await HotelService.getHotelById(hotelId);

    if (!hotel) {
      return res.status(404).json(errorResponse('酒店信息不存在'));
    }

    res.json(successResponse(hotel, '获取酒店信息成功'));
  } catch (error) {
    logger.error('获取酒店信息失败:', error.message);
    res.status(500).json(errorResponse('获取酒店信息失败'));
  }
};

/**
 * 获取所有酒店 (仅限 System 角色)
 */
export const getAll = async (req: AuthRequest, res: Response) => {
  try {
    if (isSystemAdmin(req.user?.role)) {
      const hotels = await HotelService.getAllHotels();
      res.json(successResponse(hotels, '获取所有酒店成功'));
    } else if (isHotelAdmin(req.user?.role)) {
      const hotelId = req.user?.hotel_id;
      if (!hotelId) {
        return res.status(400).json(errorResponse('未关联酒店'));
      }
      const hotel = await HotelService.getHotelById(hotelId);
      res.json(successResponse([hotel], '获取本店信息成功'));
    } else {
      return res.status(403).json(errorResponse('无权访问酒店列表'));
    }
  } catch (error) {
    logger.error('获取酒店列表失败:', error.message);
    res.status(500).json(errorResponse('获取酒店列表失败'));
  }
};

/**
 * 创建新酒店 (仅限 System 角色)
 */
export const create = async (req: AuthRequest, res: Response) => {
  try {
    if (!isSystemAdmin(req.user?.role)) {
      return res.status(403).json(errorResponse('无权创建酒店'));
    }
    const id = await HotelService.createHotel(req.body);
    res.status(201).json(successResponse({ id }, '酒店创建成功'));
  } catch (error: any) {
    logger.error('创建酒店失败:', error.message);
    res.status(500).json(errorResponse(error.message || '创建酒店失败'));
  }
};

export const update = async (req: AuthRequest, res: Response) => {
  try {
    let hotelId = req.user?.hotel_id;

    // 如果是 system 角色，允许指定修改哪个酒店
    if (isSystemAdmin(req.user?.role) && req.params.id) {
      hotelId = parseInt(req.params.id);
    } else if (isSystemAdmin(req.user?.role) && !hotelId) {
      hotelId = 1;
    }

    if (hotelId === undefined || hotelId === null) {
      return res.status(401).json(errorResponse('未授权，缺少酒店信息'));
    }

    const success = await HotelService.updateHotel(hotelId, req.body);

    if (!success) {
      res.status(404).json(errorResponse('酒店信息不存在'));
      return;
    }

    res.json(successResponse(null, '更新酒店信息成功'));
  } catch (error) {
    logger.error('更新酒店信息失败:', error.message);
    res.status(500).json(errorResponse('更新酒店信息失败'));
  }
};

/**
 * 删除酒店 (仅限 System 角色)
 */
export const remove = async (req: AuthRequest, res: Response) => {
  try {
    if (!isSystemAdmin(req.user?.role)) {
      return res.status(403).json(errorResponse('无权删除酒店'));
    }
    const id = parseInt(req.params.id);
    const success = await HotelService.deleteHotel(id);

    if (!success) {
      return res.status(404).json(errorResponse('酒店不存在'));
    }

    res.json(successResponse(null, '酒店删除成功'));
  } catch (error) {
    logger.error('删除酒店失败:', error.message);
    res.status(500).json(errorResponse('删除酒店失败'));
  }
};

/**
 * 获取酒店统计数据
 */
export const getStatistics = async (req: AuthRequest, res: Response) => {
  try {
    let hotelId = req.user?.hotel_id;
    const userRole = normalizeRole(req.user?.role);

    // 如果是集团超管 (Hotel ID 为 0 或 角色为 system)
    if (isSystemAdmin(userRole) || hotelId === 0) {
      // 统计所有酒店的数据
      // 1. 房间状态统计 (所有酒店)
      const [roomStats] = await pool.query<RowDataPacket[]>(
        'SELECT room_status, COUNT(*) as count FROM rooms GROUP BY room_status'
      );
      const roomStatsArray = roomStats as any[];
      const totalRooms = roomStatsArray.reduce((sum: number, r: any) => sum + (r.count as number), 0);
      const occupiedRooms = roomStatsArray.filter((r: any) => r.room_status === 'occupied').reduce((sum: number, r: any) => sum + (r.count as number), 0);
      const occupancyRate = totalRooms > 0 ? occupiedRooms / totalRooms : 0;

      const year = req.query.year ? parseInt(req.query.year as string) : new Date().getFullYear();
      const month = req.query.month ? parseInt(req.query.month as string) : new Date().getMonth() + 1;

      // 2. 收入与订单统计 (所有酒店)
      const [revenueResult] = await pool.query<RowDataPacket[]>(
        `SELECT COALESCE(SUM(total_price), 0) as total_revenue, COUNT(*) as total_orders
         FROM bookings WHERE YEAR(check_in_date) = ? AND MONTH(check_in_date) = ? AND status != 'cancelled'`,
        [year, month]
      );
      const revenueData = revenueResult[0] as any;

      // 3. 平均房价统计 (所有酒店)
      const [avgPriceResult] = await pool.query<RowDataPacket[]>(
        `SELECT COALESCE(AVG(room_price), 0) as avg_room_price FROM rooms`
      );
      const avgPriceData = avgPriceResult[0] as any;

      // 4. 月度营收趋势 (所有酒店)
      const [monthlyRevenue] = await pool.query<RowDataPacket[]>(
        `SELECT MONTH(check_in_date) as m, COALESCE(SUM(total_price), 0) as revenue
         FROM bookings WHERE YEAR(check_in_date) = ? AND status != 'cancelled'
         GROUP BY MONTH(check_in_date)`,
        [year]
      );
      const monthlyRevenueArray = Array(12).fill(0);
      (monthlyRevenue as any[]).forEach((r: any) => {
        monthlyRevenueArray[(r.m as number) - 1] = parseFloat(r.revenue as string) || 0;
      });

      // 5. 今日预订简报 (所有酒店)
      const [bookingStats] = await pool.query<RowDataPacket[]>(
        'SELECT status, COUNT(*) as count FROM bookings WHERE DATE(check_in_date) = CURDATE() GROUP BY status'
      );

      // 6. 待处理维保 (所有酒店)
      let pendingMaintenance = 0;
      try {
        const [maintenanceStats] = await pool.query<RowDataPacket[]>(
          'SELECT COUNT(*) as count FROM maintenance_tickets WHERE status = "pending"'
        );
        pendingMaintenance = (maintenanceStats[0] as any)?.count || 0;
      } catch (e) {}

      // 7. 集团全局额外统计
      const [hotelCountResult] = await pool.query<RowDataPacket[]>('SELECT COUNT(*) as count FROM hotels');
      const [memberCountResult] = await pool.query<RowDataPacket[]>('SELECT COUNT(*) as count FROM members');
      const [deviceCountResult] = await pool.query<RowDataPacket[]>('SELECT COUNT(*) as count FROM devices');
      const [topHotels] = await pool.query<RowDataPacket[]>(
        `SELECT h.hotel_name, COALESCE(SUM(b.total_price), 0) as revenue
         FROM hotels h
         LEFT JOIN bookings b ON h.id = b.hotel_id AND b.status != 'cancelled'
         GROUP BY h.id ORDER BY revenue DESC LIMIT 5`
      );

      return res.json(successResponse({
        total_revenue: parseFloat(revenueData?.total_revenue as string) || 0,
        total_orders: revenueData?.total_orders || 0,
        avg_room_price: parseFloat(avgPriceData?.avg_room_price as string) || 0,
        occupancy_rate: occupancyRate,
        monthly_revenue: monthlyRevenueArray,
        room_stats: roomStats,
        booking_stats: bookingStats,
        pending_maintenance: pendingMaintenance,
        hotel_count: (hotelCountResult[0] as any).count,
        member_count: (memberCountResult[0] as any).count,
        device_count: (deviceCountResult[0] as any).count,
        top_hotels: topHotels,
        is_global_stats: true
      }, '获取集团全局统计数据成功'));
    }

    // 原有的单酒店逻辑
    if (!hotelId) {
      // 如果是普通用户，尝试从其最近的预订中获取酒店 ID
      const [lastBooking] = await pool.query<RowDataPacket[]>(
        'SELECT hotel_id FROM bookings WHERE user_id = ? OR guest_phone = ? ORDER BY id DESC LIMIT 1',
        [req.user?.id, req.user?.username]
      );
      hotelId = (lastBooking[0] as any)?.hotel_id || 1;
    }

    const year = req.query.year ? parseInt(req.query.year as string) : new Date().getFullYear();
    const month = req.query.month ? parseInt(req.query.month as string) : new Date().getMonth() + 1;

    // 1. 房间状态统计
    const [roomStats] = await pool.query<RowDataPacket[]>(
      'SELECT room_status, COUNT(*) as count FROM rooms WHERE hotel_id = ? GROUP BY room_status',
      [hotelId]
    );

    const roomStatsArray = roomStats as any[];
    const totalRooms = roomStatsArray.reduce((sum: number, r: any) => sum + (r.count as number), 0);
    const occupiedRooms = roomStatsArray.filter((r: any) => r.room_status === 'occupied').reduce((sum: number, r: any) => sum + (r.count as number), 0);
    const occupancyRate = totalRooms > 0 ? occupiedRooms / totalRooms : 0;

    // 2. 收入与订单统计
    const [revenueResult] = await pool.query<RowDataPacket[]>(
      `SELECT COALESCE(SUM(total_price), 0) as total_revenue, COUNT(*) as total_orders
       FROM bookings WHERE hotel_id = ? AND YEAR(check_in_date) = ? AND MONTH(check_in_date) = ? AND status != 'cancelled'`,
      [hotelId, year, month]
    );
    const revenueData = revenueResult[0] as any;

    // 3. 平均房价统计
    const [avgPriceResult] = await pool.query<RowDataPacket[]>(
      `SELECT COALESCE(AVG(room_price), 0) as avg_room_price FROM rooms WHERE hotel_id = ?`,
      [hotelId]
    );
    const avgPriceData = avgPriceResult[0] as any;

    // 4. 月度营收趋势
    const [monthlyRevenue] = await pool.query<RowDataPacket[]>(
      `SELECT MONTH(check_in_date) as m, COALESCE(SUM(total_price), 0) as revenue
       FROM bookings WHERE hotel_id = ? AND YEAR(check_in_date) = ? AND status != 'cancelled'
       GROUP BY MONTH(check_in_date)`,
      [hotelId, year]
    );

    const monthlyRevenueArray = Array(12).fill(0);
    (monthlyRevenue as any[]).forEach((r: any) => {
      monthlyRevenueArray[(r.m as number) - 1] = parseFloat(r.revenue as string) || 0;
    });

    // 5. 今日预订简报
    const [bookingStats] = await pool.query<RowDataPacket[]>(
      'SELECT status, COUNT(*) as count FROM bookings WHERE hotel_id = ? AND DATE(check_in_date) = CURDATE() GROUP BY status',
      [hotelId]
    );

    // 6. 待处理维保
    let pendingMaintenance = 0;
    try {
      const [maintenanceStats] = await pool.query<RowDataPacket[]>(
        'SELECT COUNT(*) as count FROM maintenance_tickets WHERE hotel_id = ? AND status = "pending"',
        [hotelId]
      );
      pendingMaintenance = (maintenanceStats[0] as any)?.count || 0;
    } catch (e) {
      logger.warn('维保表可能不存在或查询失败');
    }

    res.json(successResponse({
      total_revenue: parseFloat(revenueData?.total_revenue as string) || 0,
      total_orders: revenueData?.total_orders || 0,
      avg_room_price: parseFloat(avgPriceData?.avg_room_price as string) || 0,
      occupancy_rate: occupancyRate,
      monthly_revenue: monthlyRevenueArray,
      rooms: roomStats,
      bookings: bookingStats,
      pending_maintenance: pendingMaintenance
    }, '获取统计数据成功'));
  } catch (error) {
    logger.error('获取统计数据失败:', error.message);
    // 降级返回部分数据，而不是 500
    res.json(successResponse({
      total_revenue: 0,
      total_orders: 0,
      avg_room_price: 0,
      occupancy_rate: 0,
      monthly_revenue: Array(12).fill(0),
      rooms: [],
      bookings: [],
      pending_maintenance: 0
    }, '获取统计数据失败(降级)'));
  }
};
