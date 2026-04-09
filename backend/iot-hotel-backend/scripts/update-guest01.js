const mysql = require('mysql2/promise');

async function updateGuest01() {
  const connection = await mysql.createConnection({
    host: '8.134.166.69',
    port: 3306,
    user: 'iot_user',
    password: 'Iot2026.',
    database: 'iot_hotel_system'
  });

  try {
    console.log('更新房间101的入住信息为guest01...');

    // 获取房间ID
    const [roomRows] = await connection.execute(
      'SELECT id FROM rooms WHERE room_number = ?',
      ['101']
    );
    
    if (roomRows.length === 0) {
      console.log('房间101不存在');
      return;
    }
    
    const roomId = roomRows[0].id;

    // 更新现有预订为guest01，并延长退房日期
    const [result] = await connection.execute(
      `UPDATE bookings 
       SET guest_name = ?, 
           guest_phone = ?,
           check_in_date = CURDATE(),
           check_out_date = DATE_ADD(CURDATE(), INTERVAL 1 DAY),
           check_in_time = NOW()
       WHERE room_id = ? 
       AND status = 'checked_in'`,
      ['guest01', '13800138001', roomId]
    );

    console.log('更新结果:', result);

    if (result.affectedRows > 0) {
      console.log('成功更新为guest01！');
      
      // 验证结果
      const [booking] = await connection.execute(
        `SELECT b.*, r.room_number 
         FROM bookings b 
         JOIN rooms r ON b.room_id = r.id 
         WHERE b.room_id = ? AND b.status = 'checked_in'`,
        [roomId]
      );
      console.log('当前入住信息:', booking[0]);
    } else {
      console.log('没有记录被更新，创建新的预订...');
      
      const { v4: uuidv4 } = require('uuid');
      const bookingNumber = `BK${new Date().getFullYear()}${String(new Date().getMonth() + 1).padStart(2, '0')}${String(new Date().getDate()).padStart(2, '0')}${uuidv4().slice(0, 8).toUpperCase()}`;
      
      await connection.execute(
        `INSERT INTO bookings (
          booking_number, hotel_id, room_id, guest_name, guest_phone, 
          guest_id_number, check_in_date, check_out_date, guest_count,
          payment_method, total_price, deposit, status, check_in_time
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
        [
          bookingNumber, 1, roomId, 'guest01', '13800138001',
          '110101199001011234', new Date().toISOString().split('T')[0],
          new Date(Date.now() + 86400000).toISOString().split('T')[0],
          1, 'balance', 299.00, 0.00, 'checked_in'
        ]
      );
      
      console.log('新预订创建成功！');
    }

  } catch (error) {
    console.error('更新失败:', error);
  } finally {
    await connection.end();
  }
}

updateGuest01();
