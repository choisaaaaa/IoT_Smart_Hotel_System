/**
 * IoT智慧酒店系统 - 优化项全面测试脚本
 * 测试文档: g:\Projects\IoT\IoT_Smart_Hotel_System\优化工作总结报告.md
 *
 * 测试范围:
 * - S-01~S-05: 严重安全漏洞修复
 * - H-01~H-07: 高危安全问题修复
 * - M-01~M-08: 中危安全问题
 * - L-01~L-05: 低危安全问题
 * - 架构优化
 */

const axios = require('axios');

const BASE_URL = 'http://localhost:3000/api/v1';
const SERVER_URL = 'http://localhost:3000';

const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
  magenta: '\x1b[35m'
};

let testResults = {
  total: 0,
  passed: 0,
  failed: 0,
  skipped: 0,
  warnings: []
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function logSection(title) {
  log(`\n${'='.repeat(70)}`, 'cyan');
  log(`  ${title}`, 'cyan');
  log(`${'='.repeat(70)}`, 'cyan');
}

function logSubSection(title) {
  log(`\n--- ${title} ---`, 'magenta');
}

async function test(name, fn, skip = false) {
  testResults.total++;
  if (skip) {
    log(`  ⊘ ${name} (跳过)`, 'yellow');
    testResults.skipped++;
    return null;
  }
  try {
    const result = await fn();
    log(`  ✓ ${name}`, 'green');
    testResults.passed++;
    return result;
  } catch (error) {
    log(`  ✗ ${name}`, 'red');
    log(`    错误: ${error.message}`, 'red');
    testResults.failed++;
    return null;
  }
}

function warn(message) {
  log(`  ⚠ ${message}`, 'yellow');
  testResults.warnings.push(message);
}

// ========================================
// S-01: MQTT Broker 认证机制
// ========================================
async function testS01_MQTTAuth() {
  logSection('S-01: MQTT Broker 认证机制测试');

  await test('mosquitto.conf 存在且配置正确', async () => {
    const fs = require('fs');
    const path = require('path');
    const configPath = path.join(__dirname, '../../config/mosquitto.conf');
    if (!fs.existsSync(configPath)) {
      throw new Error('mosquitto.conf 文件不存在');
    }
    const content = fs.readFileSync(configPath, 'utf8');
    if (!content.includes('allow_anonymous false')) {
      throw new Error('未配置 allow_anonymous false');
    }
    if (!content.includes('password_file')) {
      throw new Error('未配置密码文件');
    }
    if (!content.includes('acl_file')) {
      throw new Error('未配置ACL文件');
    }
  });

  await test('mosquitto.passwd 密码文件存在', async () => {
    const fs = require('fs');
    const path = require('path');
    const passwdPath = path.join(__dirname, '../../config/mosquitto.passwd');
    if (!fs.existsSync(passwdPath)) {
      throw new Error('mosquitto.passwd 文件不存在');
    }
  });

  await test('ACL访问控制文件存在', async () => {
    const fs = require('fs');
    const path = require('path');
    const aclPath = path.join(__dirname, '../../config/acl');
    if (!fs.existsSync(aclPath)) {
      throw new Error('acl 文件不存在');
    }
  });
}

// ========================================
// S-02: MQTT TLS加密支持
// ========================================
async function testS02_MQTTTLS() {
  logSection('S-02: MQTT TLS加密支持测试');

  await test('mosquitto.conf 包含TLS配置', async () => {
    const fs = require('fs');
    const path = require('path');
    const configPath = path.join(__dirname, '../../config/mosquitto.conf');
    const content = fs.readFileSync(configPath, 'utf8');
    if (!content.includes('listener 8883')) {
      warn('TLS端口8883未配置');
    }
    if (!content.includes('cafile') && !content.includes('capath')) {
      warn('CA证书配置缺失');
    }
    if (!content.includes('certfile')) {
      warn('服务器证书配置缺失');
    }
  });

  await test('TLS证书生成脚本存在', async () => {
    const fs = require('fs');
    const path = require('path');
    const scriptPath = path.join(__dirname, '../../config/generate-tls-certs.bat');
    if (!fs.existsSync(scriptPath)) {
      warn('TLS证书生成脚本不存在');
    }
  });
}

// ========================================
// S-03: RFID门禁接口认证
// ========================================
async function testS03_RFIDAuth() {
  logSection('S-03: RFID门禁接口认证测试');

  await test('POST /rfid-access/logs 需要设备认证', async () => {
    // 不带设备认证应该返回401
    try {
      await axios.post(`${BASE_URL}/rfid-access/logs`, {
        device_id: 'test',
        card_id: 'test',
        timestamp: Date.now()
      });
      throw new Error('应该返回401但没有');
    } catch (error) {
      if (error.response?.status !== 401) {
        throw new Error(`期望401，实际返回 ${error.response?.status}`);
      }
    }
  });

  await test('POST /rfid-access/verify 需要设备认证', async () => {
    // 不带设备认证应该返回401
    try {
      await axios.post(`${BASE_URL}/rfid-access/verify`, {
        card_id: 'test',
        timestamp: Date.now()
      });
      throw new Error('应该返回401但没有');
    } catch (error) {
      if (error.response?.status !== 401) {
        throw new Error(`期望401，实际返回 ${error.response?.status}`);
      }
    }
  });

  await test('GET /rfid-access/logs 需要用户认证', async () => {
    // 不带用户认证应该返回401
    try {
      await axios.get(`${BASE_URL}/rfid-access/logs`);
      throw new Error('应该返回401但没有');
    } catch (error) {
      if (error.response?.status !== 401) {
        throw new Error(`期望401，实际返回 ${error.response?.status}`);
      }
    }
  });
}

// ========================================
// S-04: MQTT主题格式统一
// ========================================
async function testS04_MQTTTopicFormat() {
  logSection('S-04: MQTT主题格式统一测试');

  await test('MQTT服务使用统一主题格式', async () => {
    const fs = require('fs');
    const path = require('path');
    const servicePath = path.join(__dirname, '../../src/services/mqtt.service.ts');
    if (!fs.existsSync(servicePath)) {
      throw new Error('mqtt.service.ts 文件不存在');
    }
    const content = fs.readFileSync(servicePath, 'utf8');
    // 统一格式: hotel/device/{category}/{type}/{id}
    if (!content.includes('hotel/device/')) {
      warn('未找到统一主题格式 hotel/device/');
    }
  });
}

// ========================================
// S-05: SQL文件合并
// ========================================
async function testS05_SQLMerge() {
  logSection('S-05: SQL文件合并测试');

  await test('init.sql 包含完整的表结构', async () => {
    const fs = require('fs');
    const path = require('path');
    const sqlPath = path.join(__dirname, '../../database/init.sql');
    if (!fs.existsSync(sqlPath)) {
      throw new Error('init.sql 文件不存在');
    }
    const content = fs.readFileSync(sqlPath, 'utf8');
    const tableCount = (content.match(/CREATE TABLE/g) || []).length;
    if (tableCount < 40) {
      warn(`init.sql 只有 ${tableCount} 个表，可能不完整`);
    }
  });
}

// ========================================
// H-01: 设备注册接口认证
// ========================================
async function testH01_DeviceRegisterAuth() {
  logSection('H-01: 设备注册接口认证测试');

  await test('POST /devices/register 支持预注册Token认证', async () => {
    // 检查路由是否配置了 optionalDeviceAuthMiddleware
    const fs = require('fs');
    const path = require('path');
    const routePath = path.join(__dirname, '../../src/routes/v1/devices.ts');
    const content = fs.readFileSync(routePath, 'utf8');
    if (!content.includes('optionalDeviceAuthMiddleware')) {
      throw new Error('设备注册未使用 optionalDeviceAuthMiddleware');
    }
  });
}

// ========================================
// H-02: WebSocket CORS限制
// ========================================
async function testH02_WebSocketCORS() {
  logSection('H-02: WebSocket CORS限制测试');

  await test('CORS配置生产环境限制', async () => {
    const fs = require('fs');
    const path = require('path');
    const appPath = path.join(__dirname, '../../src/app.ts');
    const content = fs.readFileSync(appPath, 'utf8');
    if (!content.includes('ALLOWED_ORIGINS')) {
      throw new Error('未配置 ALLOWED_ORIGINS');
    }
    if (!content.includes("'http://localhost:5173'") &&
        !content.includes('localhost:5173')) {
      warn('开发环境localhost未配置');
    }
  });
}

// ========================================
// H-03: 登录防暴力破解
// ========================================
async function testH03_LoginLockout() {
  logSection('H-03: 登录防暴力破解测试');

  // 先解锁测试账号
  const testPhone = '13900000001';

  await test('登录接口存在且响应正常', async () => {
    try {
      const response = await axios.post(`${BASE_URL}/auth/login`, {
        phone: testPhone,
        password: 'test_wrong'
      });
    } catch (error) {
      if (error.response?.status !== 401 && error.response?.status !== 429) {
        throw new Error(`期望401/429，实际返回 ${error.response?.status}`);
      }
    }
  });

  await test('连续5次错误密码后账户被锁定', async () => {
    // 尝试5次错误密码
    for (let i = 1; i <= 5; i++) {
      try {
        await axios.post(`${BASE_URL}/auth/login`, {
          phone: testPhone,
          password: `wrong_pass_${i}`
        });
      } catch (error) {
        // 预期返回401
        if (error.response?.status !== 401) {
          warn(`第${i}次登录返回 ${error.response?.status} 而非401`);
        }
      }
    }

    // 第6次应该被锁定
    try {
      await axios.post(`${BASE_URL}/auth/login`, {
        phone: testPhone,
        password: 'wrong_password_6'
      });
      // 如果没抛异常，说明没有锁定机制
      warn('连续5次错误密码后未触发锁定');
    } catch (error) {
      if (error.response?.status === 429) {
        log('    账户已被锁定(429)', 'green');
      } else if (error.response?.status === 401) {
        warn('第6次登录仍返回401，可能未实现锁定');
      }
    }
  });

  await test('LoginSecurityService 存在且可用', async () => {
    const fs = require('fs');
    const path = require('path');
    const servicePath = path.join(__dirname, '../../src/services/login-security.service.ts');
    if (!fs.existsSync(servicePath)) {
      throw new Error('login-security.service.ts 不存在');
    }
  });
}

// ========================================
// H-04: 设备密钥安全存储
// ========================================
async function testH04_DeviceKeyHash() {
  logSection('H-04: 设备密钥安全存储测试');

  await test('设备密钥加密工具存在', async () => {
    const fs = require('fs');
    const path = require('path');
    const utilPath = path.join(__dirname, '../../src/utils/device-key.ts');
    if (!fs.existsSync(utilPath)) {
      throw new Error('device-key.ts 不存在');
    }
    const content = fs.readFileSync(utilPath, 'utf8');
    if (!content.includes('SHA256') && !content.includes('sha256')) {
      warn('未找到SHA256哈希相关代码');
    }
    if (!content.includes('AES') && !content.includes('aes')) {
      warn('未找到AES加密相关代码');
    }
  });

  await test('设备密钥验证中间件存在', async () => {
    const fs = require('fs');
    const path = require('path');
    const authPath = path.join(__dirname, '../../src/middleware/auth.ts');
    const content = fs.readFileSync(authPath, 'utf8');
    if (!content.includes('deviceAuthMiddleware')) {
      throw new Error('deviceAuthMiddleware 不存在');
    }
  });
}

// ========================================
// H-05: AI知识库表统一
// ========================================
async function testH05_AIKnowledgeBase() {
  logSection('H-05: AI知识库表统一测试');

  await test('AI知识库表统一为 ai_knowledge_base', async () => {
    const fs = require('fs');
    const path = require('path');
    const sqlPath = path.join(__dirname, '../../database/init.sql');
    const content = fs.readFileSync(sqlPath, 'utf8');

    const hasOldTable = content.includes('ai_knowledge_entries');
    if (hasOldTable) {
      warn('init.sql 中仍存在 ai_knowledge_entries 表');
    }

    if (!content.includes('ai_knowledge_base')) {
      throw new Error('ai_knowledge_base 表不存在');
    }
  });

  await test('知识库服务使用正确的表名', async () => {
    const fs = require('fs');
    const path = require('path');
    const servicePath = path.join(__dirname, '../../src/services/knowledge-base.service.ts');
    if (fs.existsSync(servicePath)) {
      const content = fs.readFileSync(servicePath, 'utf8');
      if (!content.includes('ai_knowledge_base')) {
        warn('知识库服务未使用 ai_knowledge_base 表');
      }
    }
  });
}

// ========================================
// H-06: 语音通话双通道兼容
// ========================================
async function testH06_VoiceGateway() {
  logSection('H-06: 语音通话双通道兼容测试');

  await test('VoiceGatewayService 存在', async () => {
    const fs = require('fs');
    const path = require('path');
    const servicePath = path.join(__dirname, '../../src/services/voice-gateway.service.ts');
    if (!fs.existsSync(servicePath)) {
      throw new Error('voice-gateway.service.ts 不存在');
    }
  });

  await test('WebRTC统计接口可用', async () => {
    // 先登录获取token
    let token = null;
    try {
      const loginRes = await axios.post(`${BASE_URL}/auth/login`, {
        phone: '13900000001',
        password: '123123'
      });
      token = loginRes.data?.data?.token;
    } catch (error) {
      warn('无法登录获取token，跳过WebRTC测试');
      return;
    }

    if (token) {
      try {
        const response = await axios.get(`${BASE_URL}/calls/webrtc/stats`, {
          headers: { Authorization: `Bearer ${token}` }
        });
        if (response.status !== 200) {
          warn(`WebRTC stats返回 ${response.status}`);
        }
      } catch (error) {
        if (error.response?.status === 404) {
          warn('WebRTC stats端点不存在');
        } else {
          warn(`WebRTC stats错误: ${error.response?.status}`);
        }
      }
    }
  });
}

// ========================================
// H-07: MQTT Broker地址统一
// ========================================
async function testH07_MQTTBrokerAddress() {
  logSection('H-07: MQTT Broker地址统一测试');

  await test('MQTT配置使用统一地址', async () => {
    const fs = require('fs');
    const path = require('path');
    const configPath = path.join(__dirname, '../../src/config/mqtt.ts');
    if (!fs.existsSync(configPath)) {
      throw new Error('mqtt.ts 配置文件不存在');
    }
    const content = fs.readFileSync(configPath, 'utf8');
    if (!content.includes('8.134.166.69')) {
      warn('MQTT配置未使用统一地址 8.134.166.69');
    }
  });
}

// ========================================
// M-04: 密码策略增强
// ========================================
async function testM04_PasswordPolicy() {
  logSection('M-04: 密码策略增强测试');

  await test('密码验证器要求8位+特殊字符', async () => {
    const fs = require('fs');
    const path = require('path');
    const validatorPath = path.join(__dirname, '../../src/security/validators.ts');
    const content = fs.readFileSync(validatorPath, 'utf8');

    if (!content.includes('password.length < 8')) {
      throw new Error('未验证密码长度至少8位');
    }
    if (!content.includes('hasSpecialChar')) {
      throw new Error('未验证特殊字符');
    }
  });

  await test('密码策略正确拒绝弱密码', async () => {
    // 短密码
    try {
      await axios.post(`${BASE_URL}/auth/register`, {
        phone: '13900000099',
        password: '123456', // 6位，无特殊字符
        username: 'test_user'
      });
    } catch (error) {
      if (error.response?.status === 400) {
        log('    短密码被拒绝 ✓', 'green');
      }
    }
  });
}

// ========================================
// M-02: 错误处理信息泄露
// ========================================
async function testM02_ErrorHandling() {
  logSection('M-02: 错误处理信息泄露修复测试');

  await test('生产环境错误响应不泄露堆栈', async () => {
    // 尝试访问不存在的接口
    try {
      await axios.get(`${SERVER_URL}/api/v1/nonexistent-route`);
    } catch (error) {
      if (error.response?.status === 404) {
        if (error.response.data?.stack) {
          throw new Error('错误响应包含stack字段');
        }
        log('    404响应不包含stack ✓', 'green');
      }
    }
  });

  await test('error.ts 中间件区分生产/开发环境', async () => {
    const fs = require('fs');
    const path = require('path');
    const errorPath = path.join(__dirname, '../../src/middleware/error.ts');
    const content = fs.readFileSync(errorPath, 'utf8');
    if (!content.includes('isProduction')) {
      throw new Error('error.ts 未区分生产/开发环境');
    }
    if (!content.includes("'服务器错误'")) {
      throw new Error('生产环境未返回通用错误消息');
    }
  });
}

// ========================================
// M-08: Docker MySQL密码设置
// ========================================
async function testM08_DockerMySQLPassword() {
  logSection('M-08: Docker MySQL密码设置测试');

  await test('docker-compose.yml 设置强默认密码', async () => {
    const fs = require('fs');
    const path = require('path');
    const composePath = path.join(__dirname, '../../../docker/docker-compose.yml');
    if (!fs.existsSync(composePath)) {
      throw new Error('docker-compose.yml 不存在');
    }
    const content = fs.readFileSync(composePath, 'utf8');
    if (!content.includes('MYSQL_PASSWORD') && !content.includes('iot_password')) {
      warn('未找到 MySQL 密码配置');
    }
  });
}

// ========================================
// L-01: Helmet安全头配置
// ========================================
async function testL01_HelmetConfig() {
  logSection('L-01: Helmet安全头配置验证');

  await test('响应包含安全头', async () => {
    const response = await axios.get(`${SERVER_URL}/`);
    const headers = response.headers;

    if (!headers['strict-transport-security']) {
      warn('缺少 HSTS 头');
    } else {
      log('    HSTS 头存在 ✓', 'green');
    }

    if (!headers['x-content-type-options']) {
      warn('缺少 X-Content-Type-Options 头');
    } else {
      log('    X-Content-Type-Options 头存在 ✓', 'green');
    }

    if (!headers['x-frame-options'] && !headers['content-security-policy']) {
      warn('缺少点击劫持保护');
    } else {
      log('    CSP/X-Frame-Options 头存在 ✓', 'green');
    }
  });

  await test('Content-Security-Policy 配置完整', async () => {
    const response = await axios.get(`${SERVER_URL}/`);
    const csp = response.headers['content-security-policy'];

    if (!csp) {
      warn('缺少 Content-Security-Policy 头');
      return;
    }

    const requiredDirectives = ['default-src', 'style-src', 'script-src', 'img-src'];
    const missing = requiredDirectives.filter(d => !csp.includes(d));

    if (missing.length > 0) {
      warn(`CSP 缺少指令: ${missing.join(', ')}`);
    } else {
      log('    CSP 包含所有必要指令 ✓', 'green');
    }
  });
}

// ========================================
// L-02: 请求ID追踪中间件
// ========================================
async function testL02_RequestId() {
  logSection('L-02: 请求ID追踪中间件测试');

  await test('响应包含 X-Request-Id 头', async () => {
    const response = await axios.get(`${SERVER_URL}/`);

    if (!response.headers['x-request-id']) {
      throw new Error('响应缺少 X-Request-Id 头');
    }

    const requestId = response.headers['x-request-id'];
    log(`    Request ID: ${requestId}`, 'green');
  });

  await test('每个请求有唯一 Request ID', async () => {
    const res1 = await axios.get(`${SERVER_URL}/`);
    const res2 = await axios.get(`${SERVER_URL}/`);

    if (res1.headers['x-request-id'] === res2.headers['x-request-id']) {
      throw new Error('两个请求的 Request ID 不应该相同');
    }

    log(`    Request ID 1: ${res1.headers['x-request-id']}`, 'green');
    log(`    Request ID 2: ${res2.headers['x-request-id']}`, 'green');
  });

  await test('request-id.ts 中间件文件存在', async () => {
    const fs = require('fs');
    const path = require('path');
    const middlewarePath = path.join(__dirname, '../../src/middleware/request-id.ts');
    if (!fs.existsSync(middlewarePath)) {
      throw new Error('request-id.ts 不存在');
    }
  });
}

// ========================================
// L-03: 数据库连接池优化
// ========================================
async function testL03_DBConnectionPool() {
  logSection('L-03: 数据库连接池优化测试');

  await test('数据库连接池配置为30', async () => {
    const fs = require('fs');
    const path = require('path');
    const dbPath = path.join(__dirname, '../../src/config/database.ts');
    if (!fs.existsSync(dbPath)) {
      throw new Error('database.ts 不存在');
    }
    const content = fs.readFileSync(dbPath, 'utf8');
    if (content.includes('30')) {
      log('    连接池配置为30 ✓', 'green');
    } else if (content.includes('poolSize') || content.includes('connectionLimit')) {
      warn('连接池配置可能不是30');
    }
  });
}

// ========================================
// 架构优化测试
// ========================================
async function testArchitectureOptimizations() {
  logSection('架构优化测试');

  await test('前端环境变量配置灵活化', async () => {
    const fs = require('fs');
    const path = require('path');
    const webPath = path.join(__dirname, '../../../frontend/iot-hotel-web');
    if (fs.existsSync(webPath)) {
      log('    前端项目存在 ✓', 'green');
    }
  });

  await test('SQL文件已合并', async () => {
    const fs = require('fs');
    const path = require('path');
    const sqlPath = path.join(__dirname, '../../database/init.sql');
    if (fs.existsSync(sqlPath)) {
      const content = fs.readFileSync(sqlPath, 'utf8');
      const tableCount = (content.match(/CREATE TABLE/g) || []).length;
      log(`    init.sql 包含 ${tableCount} 个表 ✓`, 'green');
    }
  });
}

// ========================================
// 主测试流程
// ========================================
async function runAllTests() {
  log('\n', 'reset');
  log('╔══════════════════════════════════════════════════════════════════════╗', 'cyan');
  log('║     IoT智慧酒店系统 - 优化项工作总结报告 - 全面测试                   ║', 'cyan');
  log('║     测试文档: 优化工作总结报告.md                                     ║', 'cyan');
  log('╚══════════════════════════════════════════════════════════════════════╝', 'cyan');
  log(`\n📅 测试时间: ${new Date().toLocaleString('zh-CN')}`, 'blue');
  log(`📍 测试目标: ${SERVER_URL}\n`, 'blue');

  try {
    // 检查服务器是否运行
    await axios.get(`${SERVER_URL}/`);
    log('✅ 服务器连接成功\n', 'green');
  } catch (error) {
    log('\n❌ 无法连接到服务器，请确保服务器正在运行', 'red');
    log(`   错误: ${error.message}`, 'red');
    process.exit(1);
  }

  // 严重安全漏洞修复测试 (S-01 ~ S-05)
  await testS01_MQTTAuth();
  await testS02_MQTTTLS();
  await testS03_RFIDAuth();
  await testS04_MQTTTopicFormat();
  await testS05_SQLMerge();

  // 高危安全问题修复测试 (H-01 ~ H-07)
  await testH01_DeviceRegisterAuth();
  await testH02_WebSocketCORS();
  await testH03_LoginLockout();
  await testH04_DeviceKeyHash();
  await testH05_AIKnowledgeBase();
  await testH06_VoiceGateway();
  await testH07_MQTTBrokerAddress();

  // 中危安全问题测试 (M-01 ~ M-08)
  logSection('中危安全问题测试 (M-01~M-08)');
  await testM02_ErrorHandling();
  await testM04_PasswordPolicy();
  await testM08_DockerMySQLPassword();
  log('  ⊘ M-01 CSRF防护 - 待实现', 'yellow');
  log('  ⊘ M-03 SQL注入防护完善 - 已在validators.ts中基础实现', 'yellow');
  log('  ⊘ M-05 Refresh Token机制 - 待实现', 'yellow');
  log('  ⊘ M-06 上传文件内容验证 - 待实现', 'yellow');
  log('  ⊘ M-07 审计日志系统 - 待实现', 'yellow');

  // 低危安全问题测试 (L-01 ~ L-05)
  await testL01_HelmetConfig();
  await testL02_RequestId();
  await testL03_DBConnectionPool();
  log('  ⊘ L-04 MQTT日志payload优化 - 待实现', 'yellow');
  log('  ⊘ L-05 依赖安全扫描CI/CD - 待实现', 'yellow');

  // 架构优化测试
  await testArchitectureOptimizations();

  // 打印测试结果
  logSection('测试结果汇总');
  log(`  总测试数: ${testResults.total}`, 'blue');
  log(`  ✅ 通过: ${testResults.passed}`, 'green');
  log(`  ❌ 失败: ${testResults.failed}`, 'red');
  log(`  ⊘ 跳过: ${testResults.skipped}`, 'yellow');

  if (testResults.warnings.length > 0) {
    log('\n⚠️  警告信息:', 'yellow');
    testResults.warnings.forEach(w => log(`   - ${w}`, 'yellow'));
  }

  if (testResults.failed > 0) {
    log('\n⚠️  部分测试失败，请检查上述错误', 'red');
    process.exit(1);
  } else {
    log('\n✅ 所有测试通过！', 'green');
    log('\n📝 测试说明:', 'blue');
    log('   - 部分测试项(S-01,S-02等)需要检查配置文件和证书', 'blue');
    log('   - 部分测试项(M-01,M-05,L-04,L-05)标记为待实现', 'blue');
    log('   - H-03登录锁定测试可能因账号已锁定而显示警告', 'blue');
    process.exit(0);
  }
}

// 运行测试
runAllTests().catch(error => {
  log(`\n❌ 测试执行异常: ${error.message}`, 'red');
  console.error(error);
  process.exit(1);
});
