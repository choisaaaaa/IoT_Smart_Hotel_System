const mysql = require('mysql2/promise')
require('dotenv').config({ path: './.env' })

async function run() {
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME
  })

  console.log('开始创建完整测试数据...')

  // ==========================================
  // 1. 创建测试酒店数据
  // ==========================================
  console.log('创建酒店数据...')
  const hotelData = [
    {
      hotel_name: '智慧花园酒店',
      hotel_address: '广州市天河区珠江新城花城大道1号',
      hotel_phone: '020-12345678',
      hotel_star: 5,
      total_rooms: 120,
      occupied_rooms: 85,
      occupancy_rate: 70.83,
      logo: 'https://example.com/hotel3-logo.jpg',
      description: '位于珠江新城核心地段的五星级智能酒店，拥有完善的IoT智能客房系统',
      city: '广州市',
      location: '珠江新城花城大道1号',
      star_rating: 5,
      rating: 4.85,
      review_count: 328,
      image_url: JSON.stringify(['https://example.com/hotel3-1.jpg', 'https://example.com/hotel3-2.jpg']),
      promotion: '新客首住8折优惠'
    },
    {
      hotel_name: '云端精品酒店',
      hotel_address: '深圳市南山区科技园南区2号',
      hotel_phone: '0755-87654321',
      hotel_star: 4,
      total_rooms: 80,
      occupied_rooms: 52,
      occupancy_rate: 65.00,
      logo: 'https://example.com/hotel4-logo.jpg',
      description: '科技园区的精品智能酒店，专为商务人士打造',
      city: '深圳市',
      location: '南山区科技园南区2号',
      star_rating: 4,
      rating: 4.65,
      review_count: 186,
      image_url: JSON.stringify(['https://example.com/hotel4-1.jpg']),
      promotion: '连住3晚享7折'
    },
    {
      hotel_name: '山水度假村',
      hotel_address: '杭州市西湖区龙井路88号',
      hotel_phone: '0571-88886666',
      hotel_star: 5,
      total_rooms: 200,
      occupied_rooms: 156,
      occupancy_rate: 78.00,
      logo: 'https://example.com/hotel5-logo.jpg',
      description: '依山傍水的度假型智能酒店，融合自然景观与智能科技',
      city: '杭州市',
      location: '西湖区龙井路88号',
      star_rating: 5,
      rating: 4.92,
      review_count: 512,
      image_url: JSON.stringify(['https://example.com/hotel5-1.jpg', 'https://example.com/hotel5-2.jpg', 'https://example.com/hotel5-3.jpg']),
      promotion: '周末特惠套餐'
    },
    {
      hotel_name: '都市便捷酒店',
      hotel_address: '成都市锦江区春熙路168号',
      hotel_phone: '028-66668888',
      hotel_star: 3,
      total_rooms: 150,
      occupied_rooms: 120,
      occupancy_rate: 80.00,
      logo: 'https://example.com/hotel6-logo.jpg',
      description: '位于春熙路商圈的经济型智能酒店，性价比高',
      city: '成都市',
      location: '锦江区春熙路168号',
      star_rating: 3,
      rating: 4.45,
      review_count: 892,
      image_url: JSON.stringify(['https://example.com/hotel6-1.jpg']),
      promotion: '会员专享价'
    }
  ]

  for (const hotel of hotelData) {
    await conn.query(
      `INSERT INTO hotels (hotel_name, hotel_address, hotel_phone, hotel_star, total_rooms, occupied_rooms, occupancy_rate, logo, description, city, location, star_rating, rating, review_count, image_url, promotion, hotel_id) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) 
       ON DUPLICATE KEY UPDATE 
       hotel_address=VALUES(hotel_address), hotel_phone=VALUES(hotel_phone), description=VALUES(description), city=VALUES(city), location=VALUES(location)`,
      [hotel.hotel_name, hotel.hotel_address, hotel.hotel_phone, hotel.hotel_star, hotel.total_rooms, hotel.occupied_rooms, hotel.occupancy_rate, hotel.logo, hotel.description, hotel.city, hotel.location, hotel.star_rating, hotel.rating, hotel.review_count, hotel.image_url, hotel.promotion, null]
    )
  }

  // 获取所有酒店ID映射
  const [hotels] = await conn.query("SELECT id, hotel_name FROM hotels")
  const hotelMap = {}
  hotels.forEach(item => {
    hotelMap[item.hotel_name] = item.id
  })
  console.log('酒店数据创建完成:', Object.keys(hotelMap))

  // ==========================================
  // 2. 创建房间类型数据
  // ==========================================
  console.log('创建房间类型数据...')
  const roomTypeData = [
    { name: '标准大床房', code: 'standard_king', base_price: 299.00, area: 28.00, bed_type: 'king', max_guests: 2, facilities: JSON.stringify(['WiFi', '空调', '电视', '独立卫浴', '吹风机', '电热水壶']), description: '舒适的标准大床房，配备1.8米大床', images: JSON.stringify(['https://example.com/room/std-king-1.jpg']), hotel_name: '智联酒店' },
    { name: '豪华双床房', code: 'deluxe_twin', base_price: 399.00, area: 35.00, bed_type: 'twin', max_guests: 2, facilities: JSON.stringify(['WiFi', '空调', '电视', '独立卫浴', '迷你吧', '保险箱', '浴袍']), description: '宽敞明亮的豪华双床房', images: JSON.stringify(['https://example.com/room/dlx-twin-1.jpg']), hotel_name: '智联酒店' },
    { name: '商务套房', code: 'business_suite', base_price: 599.00, area: 55.00, bed_type: 'king', max_guests: 2, facilities: JSON.stringify(['WiFi', '空调', '电视', '独立卫浴', '迷你吧', '保险箱', '浴袍', '会客区', '办公区']), description: '专为商务人士设计的套房', images: JSON.stringify(['https://example.com/room/biz-suite-1.jpg']), hotel_name: '智联酒店' },
    { name: '总统套房', code: 'presidential', base_price: 1999.00, area: 120.00, bed_type: 'king', max_guests: 4, facilities: JSON.stringify(['WiFi', '空调', '电视', '独立卫浴', '迷你吧', '保险箱', '浴袍', '会客区', '餐厅', '厨房', '按摩浴缸', '桑拿房']), description: '顶级奢华的总统套房', images: JSON.stringify(['https://example.com/room/presidential-1.jpg']), hotel_name: '智联酒店' },
    { name: '智能标准房', code: 'smart_standard', base_price: 399.00, area: 30.00, bed_type: 'king', max_guests: 2, facilities: JSON.stringify(['WiFi', '空调', '智能电视', '独立卫浴', '智能灯光', '语音控制']), description: '配备全套IoT智能设备的标准房', images: JSON.stringify(['https://example.com/room/std-king-3.jpg']), hotel_name: '智慧花园酒店' },
    { name: '智能豪华房', code: 'smart_deluxe', base_price: 599.00, area: 40.00, bed_type: 'king', max_guests: 2, facilities: JSON.stringify(['WiFi', '空调', '智能电视', '独立卫浴', '智能灯光', '语音控制', '智能窗帘', '环境监测']), description: '全面升级的智能豪华房', images: JSON.stringify(['https://example.com/room/smart-dlx-3.jpg']), hotel_name: '智慧花园酒店' },
    { name: '景观套房', code: 'view_suite', base_price: 899.00, area: 70.00, bed_type: 'king', max_guests: 2, facilities: JSON.stringify(['WiFi', '空调', '智能电视', '独立卫浴', '智能灯光', '语音控制', '智能窗帘', '环境监测', '观景阳台']), description: '可欣赏城市景观的智能套房', images: JSON.stringify(['https://example.com/room/view-suite-3.jpg']), hotel_name: '智慧花园酒店' },
    { name: '山景别墅', code: 'villa_mountain', base_price: 2999.00, area: 200.00, bed_type: 'king', max_guests: 6, facilities: JSON.stringify(['WiFi', '空调', '智能电视', '独立卫浴', '智能灯光', '语音控制', '私人泳池', '温泉', '花园']), description: '独立山景别墅，极致私密与奢华', images: JSON.stringify(['https://example.com/room/villa-5.jpg']), hotel_name: '山水度假村' },
    { name: '经济大床房', code: 'budget_king', base_price: 159.00, area: 20.00, bed_type: 'king', max_guests: 2, facilities: JSON.stringify(['WiFi', '空调', '电视', '独立卫浴']), description: '经济实惠的大床房', images: JSON.stringify(['https://example.com/room/budget-6.jpg']), hotel_name: '都市便捷酒店' },
    { name: '舒适双床房', code: 'comfort_twin', base_price: 189.00, area: 22.00, bed_type: 'twin', max_guests: 2, facilities: JSON.stringify(['WiFi', '空调', '电视', '独立卫浴']), description: '舒适的双床房', images: JSON.stringify(['https://example.com/room/comfort-6.jpg']), hotel_name: '都市便捷酒店' }
  ]

  for (const rt of roomTypeData) {
    const hotelId = hotelMap[rt.hotel_name]
    if (!hotelId) continue
    await conn.query(
      `INSERT INTO room_types (name, code, base_price, area, bed_type, max_guests, facilities, description, images, hotel_id) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) 
       ON DUPLICATE KEY UPDATE base_price=VALUES(base_price), description=VALUES(description)`,
      [rt.name, rt.code, rt.base_price, rt.area, rt.bed_type, rt.max_guests, rt.facilities, rt.description, rt.images, hotelId]
    )
  }

  // 获取房间类型ID映射
  const [roomTypes] = await conn.query("SELECT id, code, hotel_id FROM room_types")
  const roomTypeMap = {}
  roomTypes.forEach(item => {
    roomTypeMap[`${item.hotel_id}_${item.code}`] = item.id
  })
  console.log('房间类型数据创建完成')

  // ==========================================
  // 3. 创建测试房间数据
  // ==========================================
  console.log('创建房间数据...')
  const roomData = [
    // 酒店1 (智联酒店)
    { hotel_name: '智联酒店', room_number: '101', room_type: 'standard', room_type_code: 'standard_king', room_name: '标准大床房-101', room_price: 299.00, room_status: 'available', floor: 1, area: 28.00, bed_type: 'king', max_guests: 2 },
    { hotel_name: '智联酒店', room_number: '102', room_type: 'standard', room_type_code: 'standard_king', room_name: '标准大床房-102', room_price: 299.00, room_status: 'available', floor: 1, area: 28.00, bed_type: 'king', max_guests: 2 },
    { hotel_name: '智联酒店', room_number: '201', room_type: 'deluxe', room_type_code: 'deluxe_twin', room_name: '豪华双床房-201', room_price: 399.00, room_status: 'available', floor: 2, area: 35.00, bed_type: 'twin', max_guests: 2 },
    { hotel_name: '智联酒店', room_number: '202', room_type: 'deluxe', room_type_code: 'deluxe_twin', room_name: '豪华双床房-202', room_price: 399.00, room_status: 'occupied', floor: 2, area: 35.00, bed_type: 'twin', max_guests: 2 },
    { hotel_name: '智联酒店', room_number: '301', room_type: 'suite', room_type_code: 'business_suite', room_name: '商务套房-301', room_price: 599.00, room_status: 'available', floor: 3, area: 55.00, bed_type: 'king', max_guests: 2 },
    { hotel_name: '智联酒店', room_number: '801', room_type: 'presidential', room_type_code: 'presidential', room_name: '总统套房-801', room_price: 1999.00, room_status: 'available', floor: 8, area: 120.00, bed_type: 'king', max_guests: 4 },
    // 酒店3 (智慧花园酒店)
    { hotel_name: '智慧花园酒店', room_number: 'A101', room_type: 'standard', room_type_code: 'smart_standard', room_name: '智能标准房-A101', room_price: 399.00, room_status: 'available', floor: 1, area: 30.00, bed_type: 'king', max_guests: 2 },
    { hotel_name: '智慧花园酒店', room_number: 'A102', room_type: 'standard', room_type_code: 'smart_standard', room_name: '智能标准房-A102', room_price: 399.00, room_status: 'available', floor: 1, area: 30.00, bed_type: 'king', max_guests: 2 },
    { hotel_name: '智慧花园酒店', room_number: 'A201', room_type: 'deluxe', room_type_code: 'smart_deluxe', room_name: '智能豪华房-A201', room_price: 599.00, room_status: 'available', floor: 2, area: 40.00, bed_type: 'king', max_guests: 2 },
    { hotel_name: '智慧花园酒店', room_number: 'A202', room_type: 'deluxe', room_type_code: 'smart_deluxe', room_name: '智能豪华房-A202', room_price: 599.00, room_status: 'occupied', floor: 2, area: 40.00, bed_type: 'king', max_guests: 2 },
    { hotel_name: '智慧花园酒店', room_number: 'B501', room_type: 'suite', room_type_code: 'view_suite', room_name: '景观套房-B501', room_price: 899.00, room_status: 'available', floor: 5, area: 70.00, bed_type: 'king', max_guests: 2 },
    { hotel_name: '智慧花园酒店', room_number: 'B502', room_type: 'suite', room_type_code: 'view_suite', room_name: '景观套房-B502', room_price: 899.00, room_status: 'available', floor: 5, area: 70.00, bed_type: 'king', max_guests: 2 },
    // 酒店5 (山水度假村)
    { hotel_name: '山水度假村', room_number: 'V01', room_type: 'villa', room_type_code: 'villa_mountain', room_name: '山景别墅-V01', room_price: 2999.00, room_status: 'available', floor: 1, area: 200.00, bed_type: 'king', max_guests: 6 },
    { hotel_name: '山水度假村', room_number: 'V02', room_type: 'villa', room_type_code: 'villa_mountain', room_name: '山景别墅-V02', room_price: 2999.00, room_status: 'occupied', floor: 1, area: 200.00, bed_type: 'king', max_guests: 6 },
    // 酒店6 (都市便捷酒店)
    { hotel_name: '都市便捷酒店', room_number: '301', room_type: 'standard', room_type_code: 'budget_king', room_name: '经济大床房-301', room_price: 159.00, room_status: 'available', floor: 3, area: 20.00, bed_type: 'king', max_guests: 2 },
    { hotel_name: '都市便捷酒店', room_number: '302', room_type: 'standard', room_type_code: 'budget_king', room_name: '经济大床房-302', room_price: 159.00, room_status: 'available', floor: 3, area: 20.00, bed_type: 'king', max_guests: 2 },
    { hotel_name: '都市便捷酒店', room_number: '303', room_type: 'standard', room_type_code: 'comfort_twin', room_name: '舒适双床房-303', room_price: 189.00, room_status: 'available', floor: 3, area: 22.00, bed_type: 'twin', max_guests: 2 },
    { hotel_name: '都市便捷酒店', room_number: '401', room_type: 'standard', room_type_code: 'budget_king', room_name: '经济大床房-401', room_price: 159.00, room_status: 'cleaning', floor: 4, area: 20.00, bed_type: 'king', max_guests: 2 }
  ]

  for (const room of roomData) {
    const hotelId = hotelMap[room.hotel_name]
    if (!hotelId) continue
    const roomTypeId = roomTypeMap[`${hotelId}_${room.room_type_code}`]
    await conn.query(
      `INSERT INTO rooms (hotel_id, room_number, room_type, room_type_id, room_name, room_price, room_status, floor, area, bed_type, max_guests, description, facilities, images, image_url) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) 
       ON DUPLICATE KEY UPDATE room_type=VALUES(room_type), room_name=VALUES(room_name), room_price=VALUES(room_price), room_status=VALUES(room_status)`,
      [hotelId, room.room_number, room.room_type, roomTypeId, room.room_name, room.room_price, room.room_status, room.floor, room.area, room.bed_type, room.max_guests, room.room_name, JSON.stringify(['WiFi', '空调', '电视']), JSON.stringify([]), '']
    )
  }
  console.log('房间数据创建完成')

  // ==========================================
  // 4. 创建测试会员数据
  // ==========================================
  console.log('创建会员数据...')
  const memberData = [
    { phone: '13800138001', password: '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', name: '张三', id_number: '110101199001011234', member_level: 'standard', experience: 100, last_checkin_date: '2026-04-01', points: 500, balance: 200.00, total_spent: 1500.00, total_stays: 3 },
    { phone: '13800138002', password: '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', name: '李四', id_number: '310101199002022345', member_level: 'gold', experience: 2500, last_checkin_date: '2026-03-28', points: 3500, balance: 500.00, total_spent: 8500.00, total_stays: 12 },
    { phone: '13800138003', password: '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', name: '王五', id_number: '440106199003033456', member_level: 'platinum', experience: 8000, last_checkin_date: '2026-04-05', points: 12000, balance: 1000.00, total_spent: 25000.00, total_stays: 28 },
    { phone: '13800138004', password: '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', name: '赵六', id_number: '500101199004044567', member_level: 'diamond', experience: 15000, last_checkin_date: '2026-04-08', points: 25000, balance: 2000.00, total_spent: 50000.00, total_stays: 45 },
    { phone: '13800138005', password: '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', name: '陈七', id_number: '330102199005055678', member_level: 'standard', experience: 0, last_checkin_date: null, points: 100, balance: 0.00, total_spent: 0.00, total_stays: 0 },
    { phone: '13800138006', password: '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', name: '刘八', id_number: '420106199006066789', member_level: 'gold', experience: 1800, last_checkin_date: '2026-03-15', points: 2800, balance: 300.00, total_spent: 6800.00, total_stays: 8 },
    { phone: '13800138007', password: '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', name: '周九', id_number: '510107199007077890', member_level: 'standard', experience: 50, last_checkin_date: '2026-04-02', points: 200, balance: 50.00, total_spent: 800.00, total_stays: 1 },
    { phone: '13800138008', password: '$2a$10$N9qo8uLOickgx2ZMRZoMy.MqrqQzBZN0UfGNEJH0OQIh0P1K1NG6a', name: '吴十', id_number: '610104199008088901', member_level: 'platinum', experience: 6000, last_checkin_date: '2026-03-20', points: 8500, balance: 800.00, total_spent: 18000.00, total_stays: 20 }
  ]

  for (const member of memberData) {
    await conn.query(
      `INSERT INTO members (phone, password, name, id_number, member_level, experience, last_checkin_date, points, balance, total_spent, total_stays) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) 
       ON DUPLICATE KEY UPDATE name=VALUES(name), member_level=VALUES(member_level), points=VALUES(points), balance=VALUES(balance)`,
      [member.phone, member.password, member.name, member.id_number, member.member_level, member.experience, member.last_checkin_date, member.points, member.balance, member.total_spent, member.total_stays]
    )
  }

  // 获取会员ID映射
  const [members] = await conn.query("SELECT id, phone FROM members WHERE phone LIKE '138001380%'")
  const memberMap = {}
  members.forEach(item => {
    memberMap[item.phone] = item.id
  })
  console.log('会员数据创建完成:', members.length, '个会员')

  // ==========================================
  // 5. 创建测试优惠券数据
  // ==========================================
  console.log('创建优惠券数据...')
  const couponData = [
    { coupon_name: '新客专享券', coupon_code: 'NEWBIE100', coupon_type: 'cash', discount_value: 100.00, min_amount: 300.00, total_count: 1000, is_multiple_use: 0, received_count: 156, valid_from: '2026-01-01', valid_to: '2026-12-31', hotel_id: 0 },
    { coupon_name: '满减优惠券', coupon_code: 'DISCOUNT50', coupon_type: 'cash', discount_value: 50.00, min_amount: 200.00, total_count: 2000, is_multiple_use: 0, received_count: 423, valid_from: '2026-01-01', valid_to: '2026-06-30', hotel_id: 0 },
    { coupon_name: '周末特惠券', coupon_code: 'WEEKEND80', coupon_type: 'cash', discount_value: 80.00, min_amount: 500.00, total_count: 500, is_multiple_use: 0, received_count: 89, valid_from: '2026-04-01', valid_to: '2026-12-31', hotel_id: 0 },
    { coupon_name: '连住优惠', coupon_code: 'STAY3NIGHTS', coupon_type: 'cash', discount_value: 150.00, min_amount: 800.00, total_count: 300, is_multiple_use: 0, received_count: 45, valid_from: '2026-04-01', valid_to: '2026-09-30', hotel_id: 0 },
    { coupon_name: '智联酒店专享券', coupon_code: 'HOTEL1VIP', coupon_type: 'cash', discount_value: 200.00, min_amount: 600.00, total_count: 200, is_multiple_use: 0, received_count: 23, valid_from: '2026-04-01', valid_to: '2026-12-31', hotel_id: hotelMap['智联酒店'] || 1 },
    { coupon_name: '智慧花园新客券', coupon_code: 'HOTEL3NEW', coupon_type: 'cash', discount_value: 120.00, min_amount: 400.00, total_count: 300, is_multiple_use: 0, received_count: 67, valid_from: '2026-04-01', valid_to: '2026-08-31', hotel_id: hotelMap['智慧花园酒店'] || 3 },
    { coupon_name: '会员生日券', coupon_code: 'BIRTHDAY200', coupon_type: 'cash', discount_value: 200.00, min_amount: 0.00, total_count: 10000, is_multiple_use: 1, received_count: 523, valid_from: '2026-01-01', valid_to: '2026-12-31', hotel_id: 0 },
    { coupon_name: '钻石会员专享', coupon_code: 'DIAMOND300', coupon_type: 'cash', discount_value: 300.00, min_amount: 1000.00, total_count: 100, is_multiple_use: 0, received_count: 12, valid_from: '2026-04-01', valid_to: '2026-12-31', hotel_id: 0 }
  ]

  for (const coupon of couponData) {
    await conn.query(
      `INSERT INTO coupons (coupon_name, coupon_code, coupon_type, discount_value, min_amount, total_count, is_multiple_use, received_count, valid_from, valid_to, hotel_id) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) 
       ON DUPLICATE KEY UPDATE coupon_name=VALUES(coupon_name), discount_value=VALUES(discount_value), received_count=VALUES(received_count)`,
      [coupon.coupon_name, coupon.coupon_code, coupon.coupon_type, coupon.discount_value, coupon