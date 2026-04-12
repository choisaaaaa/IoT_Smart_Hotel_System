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

  const users = [
    { username: 'reception_01', password: 'password123', role: 'staff', hotel_id: 1 },
    { username: 'reception_02', password: 'password123', role: 'staff', hotel_id: 1 },
    { username: 'manager_01', password: 'password123', role: 'hotel_admin', hotel_id: 1 }
  ];

  // 使用一个已知的 bcrypt hash (对应密码 password123)
  const hash = '$2a$10$ewpcUMIv5Uf7ZQVeG/9XO.XkZ9PgT0M44JjcKasNZC4XMmjYSPZum';

  for (const user of users) {
    try {
      await conn.query(
        "INSERT INTO users (username, password, role, hotel_id) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE role=VALUES(role), hotel_id=VALUES(hotel_id)",
        [user.username, hash, user.role, user.hotel_id]
      );
      console.log(`User ${user.username} seeded successfully.`);
    } catch (err) {
      console.error(`Error seeding user ${user.username}:`, err.message);
    }
  }

  await conn.end()
  console.log('Seed receptionist accounts done.');
}

run().catch(error => {
  console.error(error);
  process.exit(1);
});
