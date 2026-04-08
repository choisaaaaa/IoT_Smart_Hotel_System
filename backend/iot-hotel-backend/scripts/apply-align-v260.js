const fs = require('fs')
const path = require('path')
const mysql = require('mysql2/promise')
require('dotenv').config({ path: path.join(__dirname, '../.env') })

const IGNORE_CODES = new Set([
  'ER_DUP_FIELDNAME',
  'ER_DUP_KEYNAME',
  'ER_CANT_CREATE_TABLE',
  'ER_DUP_ENTRY',
  'ER_FK_DUP_NAME'
])

async function run() {
  const sqlPath = path.join(__dirname, '../database/migrations/align_api_schema_v260.sql')
  const raw = fs.readFileSync(sqlPath, 'utf8')
  const statements = raw
    .split(/;\s*\n/g)
    .map(s => s.trim())
    .filter(Boolean)

  const conn = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    multipleStatements: true
  })

  try {
    for (const statement of statements) {
      try {
        await conn.query(statement)
      } catch (error) {
        if (!IGNORE_CODES.has(error.code)) {
          throw error
        }
      }
    }
    console.log('align_api_schema_v260 applied')
  } finally {
    await conn.end()
  }
}

run().catch(error => {
  console.error(error.code || error.message)
  process.exit(1)
})
