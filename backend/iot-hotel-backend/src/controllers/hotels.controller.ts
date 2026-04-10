import { Router, Response } from 'express';
import { AuthRequest, successResponse, errorResponse, sendSuccess, sendError } from '../types';
import dayjs from 'dayjs';
import db from '../config/database';
import { LEVEL_DISCOUNTS } from '../config/constants';

const router = Router();

function parseFacilities(raw: unknown): string[] {
  if (!raw) return [];
  if (Array.isArray(raw)) return raw.map(item => String(item).trim()).filter(Boolean);
  const text = String(raw).trim();
  if (!text) return [];
  if (text.startsWith('[')) {
    try {
      const parsed = JSON.parse(text);
      if (Array.isArray(parsed)) {
        return parsed.map(item => String(item).trim()).filter(Boolean);
      }
    } catch {
      return text.split(/[，,]/).map(item => item.trim()).filter(Boolean);
    }
  }
  return text.split(/[，,]/).map(item => item.trim()).filter(Boolean);
}

// 搜索酒店
export async function search(req: AuthRequest, res: Response) {
  try {
    const { destination, check_in, check_out, rooms = 1, guests = 2 } = req.query;

    // 查询酒店列表
    // 为了防止获取不到数据，暂时移除 ra.available_rooms > 0 的硬性过滤，改为在结果中显示
    const sql = `
      SELECT
        h.*,
        IFNULL(ra.available_rooms, 0) AS available_rooms,
        IFNULL(ra.min_price, h.hotel_star * 100) AS min_price
      FROM hotels h
      LEFT JOIN (
        SELECT
          r.hotel_id,
          COUNT(*) AS available_rooms,
          MIN(r.room_price) AS min_price
        FROM rooms r
        WHERE r.room_status = 'available'
        GROUP BY r.hotel_id
      ) ra ON ra.hotel_id = h.id
      WHERE (h.hotel_name LIKE ? OR h.hotel_address LIKE ? OR h.location LIKE ?)
    `;

    const keyword = `%${destination || ''}%`;
    const [hotels]: any = await db.execute(sql, [keyword, keyword, keyword]);

    sendSuccess(res, {
      hotels: hotels.map((h: any) => ({
        id: h.id,
        name: h.hotel_name || h.name || '智联酒店',
        location: h.hotel_address || h.location || '酒店地址',
        star: h.hotel_star || h.star_rating || 5,
        rating: h.rating || 4.5,
        reviewCount: h.review_count || 100,
        price: h.min_price || 299,
        image: h.logo || h.image_url || 'https://images.unsplash.com/photo-1566073771259-6a8506099945?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80',
        availableRooms: h.available_rooms
      }))
    });
  } catch (error) {
    console.error('搜索酒店失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

// 获取酒店详情
export async function detail(req: AuthRequest, res: Response) {
  try {
    const { id } = req.params;

    const [hotels]: any = await db.execute(
      'SELECT * FROM hotels WHERE id = ?',
      [id]
    );

    if (hotels.length === 0) {
      return sendError(res, errorResponse('酒店不存在', 404));
    }

    const hotel = hotels[0];

    sendSuccess(res, {
      hotel: {
        id: hotel.id,
        name: hotel.hotel_name || hotel.name,
        location: hotel.hotel_address || hotel.location,
        star: hotel.hotel_star || hotel.star_rating,
        rating: hotel.rating || 4.5,
        reviewCount: hotel.review_count || 100,
        image: hotel.logo || hotel.image_url
      }
    });
  } catch (error) {
    console.error('获取酒店详情失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

// 获取房型可用性
export const getRoomAvailability = async (req: AuthRequest, res: Response) => {
  try {
    const { hotelId } = req.params;
    const { check_in, check_out } = req.query;

    if (!check_in || !check_out) {
      return sendError(res, errorResponse('请选择入住和退房日期', 400));
    }

    // 获取当前登录用户的会员折扣
    let discountRate = 1.0;
    const userPhone = req.user?.phone || req.user?.username;
    if (userPhone) {
      const [memberRows]: any = await db.execute('SELECT member_level FROM members WHERE phone = ?', [userPhone]);
      if (memberRows.length > 0) {
        discountRate = LEVEL_DISCOUNTS[memberRows[0].member_level] || 1.0;
      }
    }

    // 1. 获取物理房间及其房型元数据
    const roomsSql = `
      SELECT 
        r.id as room_id,
        r.room_number,
        r.room_name,
        r.room_type as code,
        r.room_price,
        r.floor,
        r.area,
        r.bed_type,
        r.max_guests,
        r.room_status,
        r.facilities as room_facilities,
        rt.name as type_name,
        rt.id as room_type_id,
        COALESCE(r.facilities, rt.facilities) as facilities,
        COALESCE(r.images, rt.images) as images
      FROM rooms r
      LEFT JOIN room_types rt ON r.room_type = rt.code AND (rt.hotel_id = r.hotel_id OR rt.hotel_id = 0)
      WHERE r.hotel_id = ? AND r.room_status = 'available'
    `;

    const [rooms]: any = await db.execute(roomsSql, [hotelId]);

    // 2. 获取所有相关的子房价方案
    const [ratePlans]: any = await db.execute(
      'SELECT * FROM rate_plans WHERE hotel_id = ? AND is_active = 1',
      [hotelId]
    );

    // 3. 按房型分组并组合方案
    const groupedRooms: any = {};
    
    rooms.forEach((r: any) => {
      if (!groupedRooms[r.code]) {
        groupedRooms[r.code] = {
          code: r.code,
          name: r.type_name || r.room_name,
          room_type_id: r.room_type_id,
          room_id: r.room_id,
          hotel_id: r.hotel_id || hotelId,
          area: r.area,
          bedType: r.bed_type === 'king' ? '大床' : r.bed_type === 'twin' ? '双床' : '单床',
          maxGuests: r.max_guests,
          facilities: parseFacilities(r.facilities),
          images: parseFacilities(r.images),
          availableCount: 0,
          room_price: r.room_price,
          plans: []
        };
      }
      groupedRooms[r.code].availableCount++;
    });

    // 为每个房型匹配方案并计算今日价格 (简化处理，取第一天的价格)
    for (const code in groupedRooms) {
      const type = groupedRooms[code];
      const typePlans = ratePlans.filter((p: any) => p.room_type_id === type.room_type_id);
      
      // 始终包含一个标准方案 (id: null)
      const allPlans = [
        {
          id: null,
          plan_name: '标准价',
          base_price: 0, // 标准价直接用房型基准价
          meal_plan: 'none',
          breakfast_count: 0,
          cancellation_policy: 'free',
          cancel_time_limit: 0,
          payment_type: 'all',
          is_guaranteed: 0,
          prepayment_ratio: 0
        },
        ...typePlans
      ];

      for (const plan of allPlans) {
        // 查询该日期该方案的价格
        const [priceRows]: any = await db.execute(
          'SELECT final_price FROM room_prices WHERE room_type_id = ? AND price_date = ? AND (rate_plan_id = ? OR (rate_plan_id IS NULL AND ? IS NULL))',
          [type.room_type_id, check_in, plan.id, plan.id]
        );

        const baseRoomPrice = rooms.find((r: any) => r.code === code)?.room_price || 0;
        // 优先级：日历价格 > 方案底价 > 房型底价
        let finalPrice = baseRoomPrice;
        if (priceRows.length > 0) {
          finalPrice = priceRows[0].final_price;
        } else if (plan.id && plan.base_price > 0) {
          finalPrice = plan.base_price;
        }

        type.plans.push({
          id: plan.id,
          name: plan.plan_name,
          price: finalPrice, // 选房列表显示方案原价，明细里再算优惠
          mealPlan: plan.meal_plan,
          breakfastCount: plan.breakfast_count || 0,
          cancelPolicy: plan.cancellation_policy,
          cancelTimeLimit: plan.cancel_time_limit || 0,
          paymentType: plan.payment_type,
          isGuaranteed: !!plan.is_guaranteed,
          prepaymentRatio: plan.prepayment_ratio || 0,
          hasBreakfast: plan.meal_plan !== 'none',
          freeCancel: plan.cancellation_policy === 'free'
        });
      }
    }

    sendSuccess(res, {
      roomTypes: Object.values(groupedRooms)
    });
  } catch (error) {
    console.error('查询客房可用性失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
}

export default router;
