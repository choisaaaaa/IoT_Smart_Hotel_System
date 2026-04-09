const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
require('dotenv').config({ path: './.env' });

async function run() {
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'iot_hotel_system'
  });

  const saltRounds = 10;
  const hashedPassword = await bcrypt.hash('123456', saltRounds);

  const testUsers = [
    {
      username: 'guest01',
      password: hashedPassword,
      email: 'guest01@example.com',
      role: 'user',
      permissions: JSON.stringify(['read', 'book_room'])
    },
    {
      username: 'manager01',
      password: hashedPassword,
      email: 'manager01@example.com',
      role: 'admin',
      permissions: JSON.stringify(['read', 'write', 'manage_users', 'view_reports'])
    },
    {
      username: 'staff02',
      password: hashedPassword,
      email: 'staff02@example.com',
      role: 'staff',
      permissions: JSON.stringify(['read', 'write', 'manage_bookings'])
    }
  ];

  for (const user of testUsers) {
    try {
      await conn.query(
        'INSERT INTO users (username, password, email, role, permissions) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE role=VALUES(role), permissions=VALUES(permissions)',
        [user.username, user.password, user.email, user.role, user.permissions]
      );
      console.log(`User ${user.username} created/updated successfully.`);
    } catch (err) {
      console.error(`Error creating user ${user.username}:`, err.message);
    }
  }

  await conn.end();
  console.log('Test users seeding done.');
}

run().catch(error => {
  console.error(error);
  process.exit(1);
});
