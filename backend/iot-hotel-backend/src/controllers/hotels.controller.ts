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

    // 1. 获取所有房型基础信息 (不再受限于物理房间状态)
    const rtSql = `
      SELECT 
        id as room_type_id,
        name as type_name,
        code,
        base_price as room_price,
        area,
        bed_type,
        max_guests,
        facilities,
        images,
        hotel_id,
        default_inventory
      FROM room_types
      WHERE hotel_id = ? OR hotel_id = 0
    `;

    const [roomTypesData]: any = await db.execute(rtSql, [hotelId]);

    // 2. 获取所有相关的子房价方案
    const [ratePlans]: any = await db.execute(
      'SELECT * FROM rate_plans WHERE hotel_id = ? AND is_active = 1',
      [hotelId]
    );

    // 3. 组织房型基础结构
    const groupedRooms: any = {};
    
    roomTypesData.forEach((rt: any) => {
      groupedRooms[rt.code] = {
        code: rt.code,
        name: rt.type_name,
        room_type_id: rt.room_type_id,
        hotel_id: rt.hotel_id === 0 ? hotelId : rt.hotel_id,
        area: rt.area,
        bedType: rt.bed_type === 'king' ? '大床' : rt.bed_type === 'twin' ? '双床' : '单床',
        maxGuests: rt.max_guests,
        facilities: parseFacilities(rt.facilities),
        images: parseFacilities(rt.images),
        availableCount: 0,
        room_price: rt.room_price,
        plans: []
      };
    });

    // 为每个房型匹配方案并计算各日期余量与价格
    const checkInDate = dayjs(check_in as string);
    const checkOutDate = dayjs(check_out as string);
    const stayNights = checkOutDate.diff(checkInDate, 'day');

    for (const code in groupedRooms) {
      const type = groupedRooms[code];
      const typePlans = ratePlans.filter((p: any) => p.room_type_id === type.room_type_id);
      
      const allPlans = [
        {
          id: null,
          plan_name: '标准价',
          base_price: type.room_price,
          meal_plan: 'none',
          breakfast_count: 0,
          cancellation_policy: 'free',
          cancel_time_limit: 0,
          payment_type: 'all',
          is_guaranteed: 0,
          prepayment_ratio: 0,
          default_inventory: type.default_inventory || 10 // 标准方案默认余量
        },
        ...typePlans
      ];

      for (const plan of allPlans) {
        let minInventory = 999;
        let totalPrice = 0;
        let hasNoPriceRecord = false;

        for (let i = 0; i < stayNights; i++) {
          const dateStr = checkInDate.add(i, 'day').format('YYYY-MM-DD');
          
          const [priceRows]: any = await db.execute(
            'SELECT final_price, inventory_count, sold_count FROM room_prices WHERE room_type_id = ? AND price_date = ? AND (rate_plan_id = ? OR (rate_plan_id IS NULL AND ? IS NULL))',
            [type.room_type_id, dateStr, plan.id, plan.id]
          );

          let dayPrice = 0;
          let dayInventory = 0;

          if (priceRows.length > 0) {
            dayPrice = priceRows[0].final_price;
            // 修正：如果 inventory_count 为 0 且没有设置过，可能需要使用默认值
            const totalInv = priceRows[0].inventory_count !== null ? priceRows[0].inventory_count : (plan.default_inventory || 10);
            dayInventory = Math.max(0, totalInv - priceRows[0].sold_count);
          } else {
            hasNoPriceRecord = true;
            // 如果没有价格记录，使用方案底价或房型底价，余量使用默认值
            dayPrice = (plan.id && plan.base_price > 0) ? plan.base_price : type.room_price;
            dayInventory = plan.default_inventory || 10;
          }

          totalPrice += dayPrice;
          minInventory = Math.min(minInventory, dayInventory);
        }

        // 只有当全程都有余量时才返回该方案 (或者返回余量为0)
        type.plans.push({
          id: plan.id,
          name: plan.plan_name,
          price: Math.floor(totalPrice / stayNights * 100) / 100, // 显示平均单晚价格
          total_price: totalPrice,
          inventory: minInventory,
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
      
      // 更新房型的总可用数量（取所有方案中最大的余量，或求和，这里取方案中最大值作为参考）
      type.availableCount = Math.max(...type.plans.map((p: any) => p.inventory));
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
