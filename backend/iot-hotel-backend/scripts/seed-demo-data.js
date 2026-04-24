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

  const [hotels] = await conn.query("SELECT id, hotel_name FROM hotels WHERE hotel_name IN ('测试酒店A','测试酒店B')")
  const hotelMap = {}
  hotels.forEach(item => {
    hotelMap[item.hotel_name] = item.id
  })

  const roomSeeds = []
  function appendRooms(hotelName, start) {
    const hid = hotelMap[hotelName]
    for (let i = 0; i < 5; i += 1) {
      const roomNumber = String(start + i)
      roomSeeds.push({
        hotel_id: hid,
        room_number: roomNumber,
        room_name: `${hotelName}-${roomNumber}`,
        room_price: i < 2 ? 299 : i < 4 ? 399 : 499,
        floor: Math.floor((start + i) / 100),
        room_type: i < 2 ? 'standard' : i < 4 ? 'deluxe' : 'suite',
        bed_type: i % 2 === 0 ? 'double' : 'twin',
        max_guests: i < 4 ? 2 : 3,
        room_status: i === 0 ? 'occupied' : i === 1 ? 'maintenance' : 'available'
      })
    }
  }

  appendRooms('测试酒店A', 801)
  appendRooms('测试酒店B', 901)

  for (const room of roomSeeds) {
    await conn.query(
      "INSERT INTO rooms (room_number, room_type, room_name, room_price, room_status, floor, area, bed_type, max_guests, description, facilities, images, hotel_id, room_id, image_url) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE room_type=VALUES(room_type), room_name=VALUES(room_name), room_price=VALUES(room_price), room_status=VALUES(room_status), floor=VALUES(floor), bed_type=VALUES(bed_type), max_guests=VALUES(max_guests), hotel_id=VALUES(hotel_id), room_id=id, image_url=VALUES(image_url)",
      [room.room_number, room.room_type, room.room_name, room.room_price, room.room_status, room.floor, 32.5, room.bed_type, room.max_guests, '初始化演示客房', JSON.stringify(['WiFi', '空调']), JSON.stringify([]), room.hotel_id, null, '']
    )
  }

  const [rooms] = await conn.query("SELECT id, room_number, hotel_id, room_price FROM rooms WHERE room_number IN ('801','802','803','804','805','901','902','903','904','905')")
  const roomMap = {}
  rooms.forEach(item => {
    roomMap[item.room_number] = item
  })

  const bookingSeeds = [
    { no: 'BK_DEMO_A_001', room: '801', name: '王测试A1', phone: '13800001001', in: '2026-04-09', out: '2026-04-11', status: 'confirmed' },
    { no: 'BK_DEMO_A_002', room: '803', name: '王测试A2', phone: '13800001002', in: '2026-04-10', out: '2026-04-12', status: 'pending' },
    { no: 'BK_DEMO_B_001', room: '901', name: '李测试B1', phone: '13800002001', in: '2026-04-09', out: '2026-04-11', status: 'checked_in' },
    { no: 'BK_DEMO_B_002', room: '903', name: '李测试B2', phone: '13800002002', in: '2026-04-10', out: '2026-04-12', status: 'pending' }
  ]

  for (const booking of bookingSeeds) {
    const room = roomMap[booking.room]
    if (!room) continue
    const days = Math.max(1, Math.ceil((new Date(booking.out) - new Date(booking.in)) / 86400000))
    const total = Number(room.room_price) * days
    await conn.query(
      "INSERT INTO bookings (booking_number, hotel_id, room_id, guest_name, guest_phone, guest_id_number, check_in_date, check_out_date, guest_count, special_requests, payment_method, total_price, deposit, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE hotel_id=VALUES(hotel_id), room_id=VALUES(room_id), guest_name=VALUES(guest_name), guest_phone=VALUES(guest_phone), check_in_date=VALUES(check_in_date), check_out_date=VALUES(check_out_date), total_price=VALUES(total_price), status=VALUES(status)",
      [booking.no, room.hotel_id, room.id, booking.name, booking.phone, null, booking.in, booking.out, 1, '演示订单', 'balance', total, 0, booking.status]
    )
  }

  const deviceSeeds = [
    { id: 'DEV_A_001', name: 'A门锁801', type: 'lock', room: '801', hotel: '测试酒店A' },
    { id: 'DEV_A_002', name: 'A空调803', type: 'ac', room: '803', hotel: '测试酒店A' },
    { id: 'DEV_B_001', name: 'B门锁901', type: 'lock', room: '901', hotel: '测试酒店B' },
    { id: 'DEV_B_002', name: 'B空调903', type: 'ac', room: '903', hotel: '测试酒店B' }
  ]

  for (const device of deviceSeeds) {
    const room = roomMap[device.room]
    const hid = hotelMap[device.hotel]
    await conn.query(
      "INSERT INTO devices (device_id, device_type, device_name, device_key, device_status, firmware_version, last_seen, audit_status, room_id, area, ip_address, mac_address, hotel_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE device_name=VALUES(device_name), device_status=VALUES(device_status), audit_status=VALUES(audit_status), room_id=VALUES(room_id), hotel_id=VALUES(hotel_id), last_seen=VALUES(last_seen)",
      [device.id, device.type, device.name, `KEY_${device.id}`, 'online', 'v1.0.0', new Date(), 'approved', room ? room.id : null, 'guest-room', '192.168.1.10', `AA:BB:CC:${device.id.slice(-2)}:00:01`, hid]
    )
  }

  // 语音 Agent 桥接要求 devices.audit_status=approved；旧演示 ID 与接口测试/仿真器配置一致
  let defaultHotelId = hotelMap['测试酒店A'] || hotelMap['测试酒店B']
  if (!defaultHotelId) {
    const [hrows] = await conn.query('SELECT id FROM hotels ORDER BY id LIMIT 1')
    defaultHotelId = hrows[0]?.id
  }
  if (defaultHotelId) {
    const legacyFrontDeskIds = [
      { id: 'front_desk_02', name: '智能前台终端' },
      { id: 'front_desk_01', name: '智能前台终端(旧)' }
    ]
    for (const d of legacyFrontDeskIds) {
      await conn.query(
        "INSERT INTO devices (device_id, device_type, device_name, device_key, device_status, firmware_version, last_seen, audit_status, room_id, area, ip_address, mac_address, hotel_id) VALUES (?, 'front_desk', ?, ?, ?, ?, ?, 'approved', NULL, 'lobby', NULL, NULL, ?) ON DUPLICATE KEY UPDATE device_type='front_desk', device_name=VALUES(device_name), audit_status='approved', hotel_id=VALUES(hotel_id), last_seen=VALUES(last_seen)",
        [d.id, d.name, `KEY_${d.id}`, 'online', 'v1.2.0', new Date(), defaultHotelId]
      )
    }
  }

  for (const hotelName of ['测试酒店A', '测试酒店B']) {
    const hid = hotelMap[hotelName]
    await conn.query(
      "UPDATE hotels SET total_rooms=(SELECT COUNT(*) FROM rooms WHERE hotel_id=?), occupied_rooms=(SELECT COUNT(*) FROM rooms WHERE hotel_id=? AND room_status='occupied'), occupancy_rate=ROUND((SELECT COUNT(*) FROM rooms WHERE hotel_id=? AND room_status='occupied') * 100 / NULLIF((SELECT COUNT(*) FROM rooms WHERE hotel_id=?),0),2) WHERE id=?",
      [hid, hid, hid, hid, hid]
    )
  }

  await conn.end()
  console.log('seed demo data done')
}

run().catch(error => {
  console.error(error)
  process.exit(1)
})
