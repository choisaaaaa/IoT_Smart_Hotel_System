/**
 * 详细API接口测试
 * 测试关键接口的实际运行情况
 */

const axios = require('axios');

const BASE_URL = 'http://localhost:9000/api/v1';
const SERVER_URL = 'http://localhost:9000';

const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m'
};

async function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

async function runAPITests() {
  log('\n======================================================================', 'cyan');
  log('  详细API接口测试', 'cyan');
  log('======================================================================\n', 'cyan');

  let token = null;
  const testPhone = '13900000006'; // 顾客测试账号
  const testPassword = '123123';

  // 1. 健康检查
  log('1. 健康检查测试', 'blue');
  try {
    const healthRes = await axios.get(`${SERVER_URL}/health`);
    log(`   GET /health - 状态: ${healthRes.status}`, 'green');
    log(`   响应: ${JSON.stringify(healthRes.data)}`, 'green');
  } catch (error) {
    log(`   GET /health - 错误: ${error.message}`, 'red');
  }

  // 2. 系统信息
  log('\n2. 系统信息测试', 'blue');
  try {
    const infoRes = await axios.get(`${SERVER_URL}/`);
    log(`   GET / - 状态: ${infoRes.status}`, 'green');
    log(`   版本: ${infoRes.data.version}`, 'green');
  } catch (error) {
    log(`   GET / - 错误: ${error.message}`, 'red');
  }

  // 3. 解锁测试账号（如果被锁定）
  log('\n3. 账户解锁测试', 'blue');
  try {
    // 尝试使用正确密码登录
    const unlockRes = await axios.post(`${BASE_URL}/auth/login`, {
      phone: testPhone,
      password: testPassword
    });
    if (unlockRes.status === 200) {
      log(`   账户 ${testPhone} 未被锁定，登录成功`, 'green');
      token = unlockRes.data?.data?.token;
    }
  } catch (error) {
    if (error.response?.status === 429) {
      log(`   账户 ${testPhone} 已被锁定，使用其他账号测试`, 'yellow');
    } else {
      log(`   登录错误: ${error.response?.data?.message || error.message}`, 'yellow');
    }
  }

  // 4. 使用未锁定账号登录
  log('\n4. 登录测试 (13900000007)', 'blue');
  try {
    const loginRes = await axios.post(`${BASE_URL}/auth/login`, {
      phone: '13900000007',
      password: '123123'
    });
    if (loginRes.status === 200) {
      log(`   登录成功!`, 'green');
      token = loginRes.data?.data?.token;
      log(`   Token: ${token?.substring(0, 50)}...`, 'green');
    }
  } catch (error) {
    if (error.response?.status === 429) {
      log(`   账户已被锁定: ${error.response?.data?.message}`, 'yellow');
    } else {
      log(`   登录失败: ${error.response?.data?.message || error.message}`, 'yellow');
    }
  }

  // 5. 受保护接口测试
  if (token) {
    log('\n5. 受保护接口测试', 'blue');

    // 5.1 获取用户信息
    try {
      const userRes = await axios.get(`${BASE_URL}/users/me`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      log(`   GET /users/me - 状态: ${userRes.status}`, 'green');
      log(`   用户: ${userRes.data?.data?.username || userRes.data?.data?.phone}`, 'green');
    } catch (error) {
      log(`   GET /users/me - 错误: ${error.response?.status}`, 'red');
    }

    // 5.2 获取酒店列表
    try {
      const hotelsRes = await axios.get(`${BASE_URL}/hotels`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      log(`   GET /hotels - 状态: ${hotelsRes.status}`, 'green');
      log(`   酒店数量: ${hotelsRes.data?.data?.length || 0}`, 'green');
    } catch (error) {
      log(`   GET /hotels - 错误: ${error.response?.status}`, 'red');
    }

    // 5.3 获取设备列表
    try {
      const devicesRes = await axios.get(`${BASE_URL}/devices`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      log(`   GET /devices - 状态: ${devicesRes.status}`, 'green');
      log(`   设备数量: ${devicesRes.data?.data?.length || 0}`, 'green');
    } catch (error) {
      log(`   GET /devices - 错误: ${error.response?.status}`, 'red');
    }
  } else {
    log('\n5. 受保护接口测试 - 跳过 (无有效token)', 'yellow');
  }

  // 6. 无效Token测试
  log('\n6. 安全测试 - 无效Token', 'blue');
  try {
    const invalidRes = await axios.get(`${BASE_URL}/users`, {
      headers: { Authorization: 'Bearer invalid_token_12345' }
    });
    log(`   GET /users (无效Token) - 状态: ${invalidRes.status}`, 'red');
  } catch (error) {
    if (error.response?.status === 401) {
      log(`   无效Token正确返回401 ✓`, 'green');
    } else {
      log(`   意外状态: ${error.response?.status}`, 'yellow');
    }
  }

  // 7. 错误处理测试
  log('\n7. 错误处理测试', 'blue');
  try {
    await axios.get(`${SERVER_URL}/api/v1/nonexistent-endpoint`);
  } catch (error) {
    if (error.response?.status === 404) {
      log(`   404响应: ${JSON.stringify(error.response.data)}`, 'green');
      if (!error.response.data.stack) {
        log(`   不泄露stack信息 ✓`, 'green');
      }
    }
  }

  // 8. 安全头测试
  log('\n8. 安全响应头测试', 'blue');
  try {
    const res = await axios.get(`${SERVER_URL}/`);
    const headers = res.headers;

    log(`   X-Request-Id: ${headers['x-request-id'] ? '存在 ✓' : '缺失 ✗'}`, headers['x-request-id'] ? 'green' : 'red');
    log(`   Strict-Transport-Security: ${headers['strict-transport-security'] ? '存在 ✓' : '缺失 ✗'}`, headers['strict-transport-security'] ? 'green' : 'red');
    log(`   X-Content-Type-Options: ${headers['x-content-type-options'] ? '存在 ✓' : '缺失 ✗'}`, headers['x-content-type-options'] ? 'green' : 'red');
    log(`   X-Frame-Options: ${headers['x-frame-options'] ? '存在 ✓' : '缺失 ✗'}`, headers['x-frame-options'] ? 'green' : 'red');
    log(`   Content-Security-Policy: ${headers['content-security-policy'] ? '存在 ✓' : '缺失 ✗'}`, headers['content-security-policy'] ? 'green' : 'red');
  } catch (error) {
    log(`   错误: ${error.message}`, 'red');
  }

  // 9. WebSocket连接测试
  log('\n9. WebSocket连接测试', 'blue');
  try {
    const { io } = require('socket.io-client');
    const socket = io(SERVER_URL, {
      transports: ['websocket'],
      timeout: 5000
    });

    socket.on('connect', () => {
      log(`   WebSocket连接成功! ID: ${socket.id}`, 'green');
      socket.disconnect();
    });

    socket.on('connect_error', (err) => {
      log(`   WebSocket连接错误: ${err.message}`, 'yellow');
    });
  } catch (error) {
    log(`   Socket.io客户端导入错误，跳过WebSocket测试`, 'yellow');
  }

  log('\n======================================================================', 'cyan');
  log('  API接口测试完成', 'cyan');
  log('======================================================================\n', 'cyan');
}

runAPITests().catch(err => {
  log(`测试异常: ${err.message}`, 'red');
  process.exit(1);
});
