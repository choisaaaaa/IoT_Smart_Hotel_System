const mysql = require('mysql2/promise');
const { v4: uuidv4 } = require('uuid');

async function checkInGuest01() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3306'),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'iot_hotel_system'
  });

  try {
    console.log('开始为 guest01 办理 101 房间入住...');

    // 1. 检查房间101是否存在
    const [rooms] = await connection.execute(
      'SELECT id, room_number, room_status FROM rooms WHERE room_number = ?',
      ['101']
    );

    if (rooms.length === 0) {
      console.log('房间101不存在，创建房间...');
      await connection.execute(
        `INSERT INTO rooms (hotel_id, room_number, room_type, room_name, room_price, room_status, floor) 
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [1, '101', 'standard', '标准间101', 299.00, 'available', 1]
      );
      console.log('房间101创建成功');
    } else {
      console.log('房间101存在:', rooms[0]);
    }

    // 获取房间ID
    const [roomRows] = await connection.execute(
      'SELECT id FROM rooms WHERE room_number = ?',
      ['101']
    );
    const roomId = roomRows[0].id;

    // 2. 检查是否已有入住记录
    const [existing] = await connection.execute(
      `SELECT * FROM bookings 
       WHERE room_id = ? 
       AND status = 'checked_in'
       AND check_in_date <= CURDATE() 
       AND check_out_date >= CURDATE()`,
      [roomId]
    );

    if (existing.length > 0) {
      console.log('房间101已有入住记录:', existing[0]);
      await connection.end();
      return;
    }

    // 3. 创建预订并办理入住
    const bookingNumber = `BK${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${uuidv4().slice(0, 8).toUpperCase()}`;
    
    const [result] = await connection.execute(
      `INSERT INTO bookings (
        booking_number, hotel_id, room_id, guest_name, guest_phone, 
        guest_id_number, check_in_date, check_out_date, guest_count,
        payment_method, total_price, deposit, status, check_in_time
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
      [
        bookingNumber,
        1,
        roomId,
        'guest01',
        '13800138001',
        '110101199001011234',
        new Date().toISOString().split('T')[0],
        new Date(Date.now() + 86400000).toISOString().split('T')[0],
        1,
        'balance',
        299.00,
        0.00,
        'checked_in'
      ]
    );

    console.log('预订创建成功，ID:', result.insertId);

    // 4. 更新房间状态
    await connection.execute(
      'UPDATE rooms SET room_status = ? WHERE id = ?',
      ['occupied', roomId]
    );
    console.log('房间状态已更新为 occupied');

    // 5. 验证结果
    const [booking] = await connection.execute(
      `SELECT b.*, r.room_number 
       FROM bookings b 
       JOIN rooms r ON b.room_id = r.id 
       WHERE b.id = ?`,
      [result.insertId]
    );

    console.log('入住信息:', booking[0]);
    console.log('guest01 已成功入住 101 房间！');

  } catch (error) {
    console.error('办理入住失败:', error);
  } finally {
    await connection.end();
  }
}

checkInGuest01();
