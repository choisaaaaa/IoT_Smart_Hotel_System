import mysql from 'mysql2/promise';
import dotenv from 'dotenv';
import path from 'path';

// 加载环境变量，强制覆盖
const result = dotenv.config({ path: path.resolve(__dirname, '.env'), override: true });
if (result.error) {
  console.error('❌ 加载 .env 文件失败:', result.error);
} else {
  console.log('✅ .env 文件加载成功');
  console.log('加载的 DB_HOST:', process.env.DB_HOST);
}

async function testConnection() {
  console.log('--- 数据库连接测试开始 ---');
  console.log(`正在尝试连接到: ${process.env.DB_HOST}:${process.env.DB_PORT}`);
  console.log(`用户: ${process.env.DB_USER}`);
  console.log(`数据库: ${process.env.DB_NAME}`);

  try {
    const connection = await mysql.createConnection({
      host: '8.134.166.69',
      port: 3306,
      user: 'iot_user',
      password: 'Iot2026.',
      database: 'iot_hotel_system',
      connectTimeout: 10000, // 10秒超时
    });

    console.log('✅ 数据库连接成功！');
    
    // 执行一个简单的查询
    const [rows]: any = await connection.execute('SELECT 1 + 1 AS result');
    console.log(`✅ 查询测试成功: 1 + 1 = ${rows[0].result}`);

    // 检查表是否存在
    const [tables]: any = await connection.execute('SHOW TABLES');
    console.log(`✅ 成功获取表列表，共有 ${tables.length} 个表`);
    
    await connection.end();
    console.log('--- 测试结束：连接一切正常 ---');
    process.exit(0);
  } catch (error: any) {
    console.error('❌ 数据库连接失败！');
    console.error('错误代码:', error.code);
    console.error('错误消息:', error.message);
    
    if (error.code === 'ETIMEDOUT') {
      console.error('建议: 请检查云服务器防火墙是否已开启 3306 端口入站规则。');
    } else if (error.code === 'ER_ACCESS_DENIED_ERROR') {
      console.error('建议: 请检查用户名和密码是否正确，并确认该用户拥有远程访问权限。');
    } else if (error.code === 'ENOTFOUND') {
      console.error('建议: 无法解析主机地址，请检查 DB_HOST 是否填写正确。');
    }
    
    process.exit(1);
  }
}

testConnection();
