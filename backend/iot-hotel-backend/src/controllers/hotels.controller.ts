import { Router, Response } from 'express';
import { AuthRequest, successResponse, errorResponse, sendSuccess, sendError } from '../types';
import dayjs from 'dayjs';
import db from '../config/database';
import { LEVEL_DISCOUNTS } from '../config/constants';
import { isHotelAdmin, isSystemAdmin } from '../utils/role';
import logger from '../utils/logger';

const router = Router();

function parseFacilities(raw: unknown): string[] {
  if (!raw) {return [];}
  if (Array.isArray(raw)) {return raw.map(item => String(item).trim()).filter(Boolean);}
  const text = String(raw).trim();
  if (!text) {return [];}
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

    // 1. 获取所有房型基础信息
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

    // 2. 获取每个房型的实际物理房间数量
    const [roomCounts]: any = await db.execute(
      `SELECT room_type_id, COUNT(*) as total_rooms
       FROM rooms
       WHERE hotel_id = ? AND room_type_id IS NOT NULL
       GROUP BY room_type_id`,
      [hotelId]
    );
    const roomCountMap: Record<number, number> = {};
    roomCounts.forEach((r: any) => {
      roomCountMap[r.room_type_id] = r.total_rooms;
    });

    // 3. 获取指定日期范围内每个房型已预订/已入住的房间数
    const [bookedCounts]: any = await db.execute(
      `SELECT room_type_id, COUNT(*) as booked_count
       FROM bookings
       WHERE hotel_id = ?
         AND status IN ('confirmed', 'checked_in', 'pending')
         AND check_in_date < ? AND check_out_date > ?
       GROUP BY room_type_id`,
      [hotelId, check_out, check_in]
    );
    const bookedCountMap: Record<number, number> = {};
    bookedCounts.forEach((b: any) => {
      bookedCountMap[b.room_type_id] = b.booked_count;
    });

    // 4. 获取所有相关的子房价方案
    const [ratePlans]: any = await db.execute(
      'SELECT * FROM rate_plans WHERE hotel_id = ? AND is_active = 1',
      [hotelId]
    );

    // 5. 组织房型基础结构（只包含有物理房间的房型）
    const groupedRooms: any = {};
    
    roomTypesData.forEach((rt: any) => {
      const physicalRooms = roomCountMap[rt.room_type_id] || 0;
      if (physicalRooms === 0) return;
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
        physicalRooms,
        bookedCount: bookedCountMap[rt.room_type_id] || 0,
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
          default_inventory: type.physicalRooms
        },
        ...typePlans
      ];

      for (const plan of allPlans) {
        let minInventory = 999;
        let totalPrice = 0;

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
            const priceInventory = priceRows[0].inventory_count !== null
              ? Math.max(0, priceRows[0].inventory_count - priceRows[0].sold_count)
              : type.physicalRooms;
            dayInventory = Math.min(priceInventory, type.physicalRooms);
          } else {
            dayPrice = (plan.id && plan.base_price > 0) ? plan.base_price : type.room_price;
            dayInventory = type.physicalRooms;
          }

          totalPrice += dayPrice;
          minInventory = Math.min(minInventory, dayInventory);
        }

        minInventory = Math.max(0, minInventory - type.bookedCount);

        type.plans.push({
          id: plan.id,
          name: plan.plan_name,
          price: Math.floor(totalPrice / stayNights * 100) / 100,
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
      
      type.availableCount = Math.max(...type.plans.map((p: any) => p.inventory));
    }

    // 过滤掉所有方案库存都为0的房型
    const availableRoomTypes = Object.values(groupedRooms).filter((type: any) => {
      return type.plans.some((p: any) => p.inventory > 0);
    });

    sendSuccess(res, {
      roomTypes: availableRoomTypes
    });
  } catch (error) {
    console.error('查询客房可用性失败:', error);
    sendError(res, errorResponse('服务器错误', 500));
  }
};

// ==================== 酒店图片管理接口 ====================

// 获取酒店图片列表
export const getHotelImages = async (req: AuthRequest, res: Response) => {
  try {
    const { hotelId } = req.params;

    const [images]: any = await db.execute(
      `SELECT id, image_url, image_type, sort_order, is_active, created_at
       FROM hotel_images
       WHERE hotel_id = ? AND is_active = 1
       ORDER BY sort_order ASC, id DESC`,
      [hotelId]
    );

    sendSuccess(res, { images });
  } catch (error) {
    logger.error('获取酒店图片失败:', error);
    sendError(res, errorResponse('获取酒店图片失败', 500));
  }
};

// 上传酒店图片
export const addHotelImage = async (req: AuthRequest, res: Response) => {
  try {
    const { hotelId } = req.params;
    const { image_url, image_type = 'gallery', sort_order = 0 } = req.body;

    if (!image_url) {
      return sendError(res, errorResponse('图片URL不能为空', 400));
    }

    // 权限检查：酒店管理员只能管理自己酒店的图片
    const userRole = req.user?.role;
    const userHotelId = req.user?.hotel_id;

    if (!isSystemAdmin(userRole) && !isHotelAdmin(userRole)) {
      return sendError(res, errorResponse('无权操作', 403));
    }

    if (isHotelAdmin(userRole) && userHotelId !== Number(hotelId)) {
      return sendError(res, errorResponse('只能管理自己酒店的图片', 403));
    }

    const [result]: any = await db.execute(
      `INSERT INTO hotel_images (hotel_id, image_url, image_type, sort_order)
       VALUES (?, ?, ?, ?)`,
      [hotelId, image_url, image_type, sort_order]
    );

    logger.info(`酒店 ${hotelId} 添加图片成功: ${image_url}`);
    sendSuccess(res, { id: result.insertId }, '图片添加成功');
  } catch (error) {
    logger.error('添加酒店图片失败:', error);
    sendError(res, errorResponse('添加图片失败', 500));
  }
};

// 删除酒店图片
export const deleteHotelImage = async (req: AuthRequest, res: Response) => {
  try {
    const { hotelId, imageId } = req.params;

    // 权限检查
    const userRole = req.user?.role;
    const userHotelId = req.user?.hotel_id;

    if (!isSystemAdmin(userRole) && !isHotelAdmin(userRole)) {
      return sendError(res, errorResponse('无权操作', 403));
    }

    if (isHotelAdmin(userRole) && userHotelId !== Number(hotelId)) {
      return sendError(res, errorResponse('只能管理自己酒店的图片', 403));
    }

    await db.execute(
      'DELETE FROM hotel_images WHERE id = ? AND hotel_id = ?',
      [imageId, hotelId]
    );

    logger.info(`酒店 ${hotelId} 删除图片 ${imageId} 成功`);
    sendSuccess(res, null, '图片删除成功');
  } catch (error) {
    logger.error('删除酒店图片失败:', error);
    sendError(res, errorResponse('删除图片失败', 500));
  }
};

// 更新酒店图片信息
export const updateHotelImage = async (req: AuthRequest, res: Response) => {
  try {
    const { hotelId, imageId } = req.params;
    const { image_type, sort_order, is_active } = req.body;

    // 权限检查
    const userRole = req.user?.role;
    const userHotelId = req.user?.hotel_id;

    if (!isSystemAdmin(userRole) && !isHotelAdmin(userRole)) {
      return sendError(res, errorResponse('无权操作', 403));
    }

    if (isHotelAdmin(userRole) && userHotelId !== Number(hotelId)) {
      return sendError(res, errorResponse('只能管理自己酒店的图片', 403));
    }

    const updates: string[] = [];
    const values: any[] = [];

    if (image_type !== undefined) {
      updates.push('image_type = ?');
      values.push(image_type);
    }
    if (sort_order !== undefined) {
      updates.push('sort_order = ?');
      values.push(sort_order);
    }
    if (is_active !== undefined) {
      updates.push('is_active = ?');
      values.push(is_active);
    }

    if (updates.length === 0) {
      return sendError(res, errorResponse('没有要更新的字段', 400));
    }

    values.push(imageId, hotelId);

    await db.execute(
      `UPDATE hotel_images SET ${updates.join(', ')} WHERE id = ? AND hotel_id = ?`,
      values
    );

    logger.info(`酒店 ${hotelId} 更新图片 ${imageId} 成功`);
    sendSuccess(res, null, '图片更新成功');
  } catch (error) {
    logger.error('更新酒店图片失败:', error);
    sendError(res, errorResponse('更新图片失败', 500));
  }
};

// ==================== 酒店信息管理接口 ====================

// 更新酒店信息
export const updateHotel = async (req: AuthRequest, res: Response) => {
  try {
    const { hotelId } = req.params;
    const {
      hotel_name,
      hotel_address,
      hotel_phone,
      hotel_star,
      description,
      city,
      location,
      logo,
      image_url,
      promotion
    } = req.body;

    // 权限检查
    const userRole = req.user?.role;
    const userHotelId = req.user?.hotel_id;

    if (!isSystemAdmin(userRole) && !isHotelAdmin(userRole)) {
      return sendError(res, errorResponse('无权操作', 403));
    }

    if (isHotelAdmin(userRole) && userHotelId !== Number(hotelId)) {
      return sendError(res, errorResponse('只能管理自己酒店的信息', 403));
    }

    const updates: string[] = [];
    const values: any[] = [];

    if (hotel_name !== undefined) {
      updates.push('hotel_name = ?');
      values.push(hotel_name);
    }
    if (hotel_address !== undefined) {
      updates.push('hotel_address = ?');
      values.push(hotel_address);
    }
    if (hotel_phone !== undefined) {
      updates.push('hotel_phone = ?');
      values.push(hotel_phone);
    }
    if (hotel_star !== undefined) {
      updates.push('hotel_star = ?');
      values.push(hotel_star);
    }
    if (description !== undefined) {
      updates.push('description = ?');
      values.push(description);
    }
    if (city !== undefined) {
      updates.push('city = ?');
      values.push(city);
    }
    if (location !== undefined) {
      updates.push('location = ?');
      values.push(location);
    }
    if (logo !== undefined) {
      updates.push('logo = ?');
      values.push(logo);
    }
    if (image_url !== undefined) {
      updates.push('image_url = ?');
      values.push(image_url);
    }
    if (promotion !== undefined) {
      updates.push('promotion = ?');
      values.push(promotion);
    }

    if (updates.length === 0) {
      return sendError(res, errorResponse('没有要更新的字段', 400));
    }

    values.push(hotelId);

    await db.execute(
      `UPDATE hotels SET ${updates.join(', ')} WHERE id = ?`,
      values
    );

    logger.info(`酒店 ${hotelId} 信息更新成功`);
    sendSuccess(res, null, '酒店信息更新成功');
  } catch (error) {
    logger.error('更新酒店信息失败:', error);
    sendError(res, errorResponse('更新酒店信息失败', 500));
  }
};

// 获取酒店详情（带图片列表）
export const getHotelDetailWithImages = async (req: AuthRequest, res: Response) => {
  try {
    const { hotelId } = req.params;

    // 获取酒店基本信息
    const [hotels]: any = await db.execute(
      'SELECT * FROM hotels WHERE id = ?',
      [hotelId]
    );

    if (hotels.length === 0) {
      return sendError(res, errorResponse('酒店不存在', 404));
    }

    const hotel = hotels[0];

    // 获取酒店图片列表
    const [images]: any = await db.execute(
      `SELECT id, image_url, image_type, sort_order
       FROM hotel_images
       WHERE hotel_id = ? AND is_active = 1
       ORDER BY sort_order ASC, id DESC`,
      [hotelId]
    );

    sendSuccess(res, {
      hotel: {
        id: hotel.id,
        hotel_name: hotel.hotel_name,
        hotel_address: hotel.hotel_address,
        hotel_phone: hotel.hotel_phone,
        hotel_star: hotel.hotel_star,
        star_rating: hotel.star_rating,
        rating: hotel.rating,
        review_count: hotel.review_count,
        description: hotel.description,
        city: hotel.city,
        location: hotel.location,
        logo: hotel.logo,
        image_url: hotel.image_url,
        promotion: hotel.promotion,
        created_at: hotel.created_at,
        updated_at: hotel.updated_at
      },
      images: images || []
    });
  } catch (error) {
    logger.error('获取酒店详情失败:', error);
    sendError(res, errorResponse('获取酒店详情失败', 500));
  }
};

export default router;
