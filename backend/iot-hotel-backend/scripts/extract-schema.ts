import mysql from 'mysql2/promise';
import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

async function extractSchema() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3306'),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'iot_hotel_system'
  });

  try {
    const [tables] = await connection.query<any[]>('SHOW TABLES');
    const dbName = process.env.DB_NAME || 'iot_hotel_system';
    const tableKey = `Tables_in_${dbName}`;

    const schema: any = {};

    for (const tableRow of tables) {
      const tableName = tableRow[tableKey];
      
      // Get columns
      const [columns] = await connection.query<any[]>(`SHOW FULL COLUMNS FROM \`${tableName}\``);
      
      // Get foreign keys
      const [fks] = await connection.query<any[]>(`
        SELECT 
          COLUMN_NAME, 
          REFERENCED_TABLE_NAME, 
          REFERENCED_COLUMN_NAME 
        FROM 
          INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
        WHERE 
          TABLE_SCHEMA = ? AND 
          TABLE_NAME = ? AND 
          REFERENCED_TABLE_NAME IS NOT NULL
      `, [dbName, tableName]);

      schema[tableName] = columns.map(col => ({
        field: col.Field,
        type: col.Type,
        null: col.Null,
        key: col.Key,
        default: col.Default,
        extra: col.Extra,
        comment: col.Comment,
        fk: fks.find(fk => fk.COLUMN_NAME === col.Field)
      }));
    }

    console.log(JSON.stringify(schema, null, 2));
  } catch (error) {
    console.error('Error extracting schema:', error);
  } finally {
    await connection.end();
  }
}

extractSchema();
