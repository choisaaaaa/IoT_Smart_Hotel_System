/**
 * 为语音 AI 管家补齐数据：
 * 1) 将 devices.room_301 关联到本酒店 room_number=301
 * 2) 若该房无在住 guest（check_out_time IS NULL），插入演示 booking + guest
 *
 * 使用：在 backend/iot-hotel-backend 下执行
 *   node scripts/ensure-room-301-ai-guest.js
 */
const path = require('path')
const mysql = require('mysql2/promise')
require('dotenv').config({ path: path.resolve(__dirname, '../.env') })

const DEVICE_ID = process.env.AI_DEMO_DEVICE_ID || 'room_301'
const ROOM_NO = process.env.AI_DEMO_ROOM_NUMBER || '301'

async function run() {
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME
  })

  const [devRows] = await conn.query(
    'SELECT device_id, hotel_id, room_id FROM devices WHERE device_id = ?',
    [DEVICE_ID]
  )
  if (devRows.length === 0) {
    throw new Error(`未找到设备 ${DEVICE_ID}，请先在平台注册/录入设备`)
  }
  const dev = devRows[0]
  const hotelId = dev.hotel_id
  console.log(`[设备] ${DEVICE_ID} hotel_id=${hotelId} room_id=${dev.room_id}`)

  let roomId = dev.room_id
  if (!roomId) {
    const [r1] = await conn.query(
      'SELECT id, room_number, hotel_id FROM rooms WHERE hotel_id = ? AND room_number = ? LIMIT 1',
      [hotelId, ROOM_NO]
    )
    if (r1.length === 0) {
      const [ins] = await conn.query(
        `INSERT INTO rooms (hotel_id, room_number, room_type, room_name, room_price, room_status, floor, max_guests)
         VALUES (?, ?, 'standard', CONCAT('客房', ?), 399.00, 'occupied', 3, 2)`,
        [hotelId, ROOM_NO, ROOM_NO]
      )
      roomId = ins.insertId
      console.log(`[房间] 已创建 hotel=${hotelId} room_number=${ROOM_NO} id=${roomId}`)
    } else {
      roomId = r1[0].id
      console.log(`[房间] 已存在 room_number=${ROOM_NO} id=${roomId}`)
    }
    await conn.query('UPDATE devices SET room_id = ? WHERE device_id = ?', [roomId, DEVICE_ID])
    console.log(`[设备] 已绑定 room_id=${roomId}`)
  } else {
    console.log(`[设备] 已有 room_id=${roomId}，跳过绑定`)
  }

  const [guestOpen] = await conn.query(
    'SELECT g.id, g.guest_name FROM guests g WHERE g.room_id = ? AND g.check_out_time IS NULL ORDER BY g.check_in_time DESC LIMIT 1',
    [roomId]
  )
  if (guestOpen.length > 0) {
    console.log(`[在住] 已存在: guest_id=${guestOpen[0].id} name=${guestOpen[0].guest_name}`)
    await conn.end()
    return
  }

  const bookingNo = `BK_AI_AUTO_${Date.now()}`
  const guestName = '演示住客'
  const guestPhone = '13800003001'
  const today = new Date().toISOString().slice(0, 10)
  const tomorrow = new Date(Date.now() + 86400000).toISOString().slice(0, 10)

  const [bkIns] = await conn.query(
    `INSERT INTO bookings (booking_number, hotel_id, room_id, guest_name, guest_phone, check_in_date, check_out_date,
     guest_count, special_requests, payment_method, total_price, deposit, status, check_in_time, check_out_time)
     VALUES (?, ?, ?, ?, ?, ?, ?, 1, 'AI 演示自动入住', 'balance', 0, 0, 'checked_in', NOW(), NULL)`,
    [bookingNo, hotelId, roomId, guestName, guestPhone, today, tomorrow]
  )
  const bookingId = bkIns.insertId
  console.log(`[订单] 已创建 booking_id=${bookingId} ${bookingNo}`)

  const [gIns] = await conn.query(
    `INSERT INTO guests (booking_id, guest_name, guest_phone, room_id, check_in_time, check_out_time, guest_count)
     VALUES (?, ?, ?, ?, NOW(), NULL, 1)`,
    [bookingId, guestName, guestPhone, roomId]
  )
  console.log(`[住客] 已创建 guest_id=${gIns.insertId}（未退房，可供 AI 管家 verifyGuestAccess）`)

  await conn.end()
  console.log('完成。可重新在板子上试语音助手。')
}

run().catch((e) => {
  console.error(e)
  process.exit(1)
})
