const mysql = require('mysql2/promise');
require('dotenv').config({ path: '../../.env' });

async function querySchema() {
    const connection = await mysql.createConnection({
        host: process.env.DB_HOST || 'localhost',
        port: process.env.DB_PORT || 3307,
        user: process.env.DB_USER || 'root',
        password: process.env.DB_PASSWORD || 'IotHotel2026',
        database: process.env.DB_NAME || 'iot_hotel_system'
    });

    try {
        const [tables] = await connection.query('SHOW TABLES');
        const schema = {};

        for (const tableRow of tables) {
            const tableName = Object.values(tableRow)[0];
            const [columns] = await connection.query(`DESCRIBE \`${tableName}\``);
            schema[tableName] = columns;
        }

        console.log(JSON.stringify(schema, null, 2));
    } catch (err) {
        console.error('Error querying database:', err);
    } finally {
        await connection.end();
    }
}

querySchema();
