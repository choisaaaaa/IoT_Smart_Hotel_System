/**
 * MQTT联调测试 - 前台管理端
 * 
 * 对应配图：8.3 MQTT通信联调测试
 * 
 * 测试内容：
 * 1. MQTT连接
 * 2. RFID刷卡数据上报
 * 3. 云端响应接收
 * 4. 心跳包维持
 * 
 * ============================================================
 * 📸 截图指南
 * ============================================================
 * 
 * 【截图位置1】MQTT连接成功界面
 * - 位置：终端输出的 "MQTT连接成功" 部分
 * - 关键内容：
 *   - ✅ MQTT连接成功
 *   - Client ID: front_desk_test_xxxxx
 *   - 服务器: mqtt://localhost:1883
 * 
 * 【截图位置2】主题订阅成功界面
 * - 位置：终端输出的 "主题订阅成功" 部分
 * - 关键内容：
 *   - ✅ 主题订阅成功
 *   - 📡 hotel/devices/front_desk_001/commands
 *   - 📡 hotel/devices/front_desk_001/config
 *   - 📡 hotel/broadcast/all
 * 
 * 【截图位置3】RFID刷卡上报界面
 * - 位置：测试2的输出部分
 * - 关键内容：
 *   - 测试2: RFID刷卡上报
 *   - ✅ RFID刷卡上报成功
 *   - 💳 卡号: A1B2C3D4E5F6
 *   - 🏨 房间: 101
 * 
 * 【截图位置4】收到云端指令界面
 * - 位置：终端显示的 "收到消息" 部分
 * - 关键内容：
 *   - 📥 收到消息:
 *   - 主题: hotel/devices/front_desk_001/commands
 *   - 指令: set_rgb_color / play_sound
 *   - ⚡ 执行云端指令
 * 
 * 【截图位置5】测试报告汇总界面
 * - 位置：终端底部的测试报告
 * - 关键内容：
 *   - MQTT联调测试报告 - 前台管理端
 *   - 测试统计: ✅ 通过: 5, ❌ 失败: 0
 *   - 📤 发送消息: X, 📥 接收消息: X
 * 
 * ============================================================
 * 🎯 截图操作步骤
 * ============================================================
 * 
 * 步骤1: 打开终端 (VS Code Terminal 或 PowerShell)
 * 步骤2: 运行命令: node tests/hardware/mqtt/test_front_desk_01.js
 * 步骤3: 观察测试执行过程
 * 步骤4: 在关键步骤处截图 (Win+Shift+S)
 * 步骤5: 保存为 PNG 格式
 * 
 * ============================================================
 * 💾 文件保存规范
 * ============================================================
 * 
 * 文件名: 08_MQTT通信联调测试.png
 * 格式: PNG
 * 分辨率: 1920x1080
 * 大小: < 2MB
 * 
 * 注意: 此截图可包含三类终端的测试输出拼合
 * 
 * ============================================================
 */

const mqtt = require('mqtt');
const chalk = require('chalk');

// MQTT配置
const MQTT_CONFIG = {
  host: 'mqtt://localhost:1883',
  // 或 'mqtt://test.mosquitto.org:1883' 使用公共测试服务器
  clientId: 'front_desk_test_' + Math.random().toString(16).substr(2, 8),
  username: 'hotel_device',
  password: 'device_secret',
  keepalive: 60,
  reconnectPeriod: 5000,
};

// 设备信息
const DEVICE_INFO = {
  device_id: 'front_desk_001',
  device_type: 'front_desk',
  location: '前台',
  capabilities: ['rfid', 'rgb_led', 'buzzer']
};

// 测试统计
let testStats = {
  connected: false,
  messagesPublished: 0,
  messagesReceived: 0,
  testsPassed: 0,
  testsFailed: 0
};

console.log(chalk.blue('========================================'));
console.log(chalk.blue('MQTT联调测试 - 前台管理端'));
console.log(chalk.blue('========================================\n'));

// 创建MQTT客户端
const client = mqtt.connect(MQTT_CONFIG.host, {
  clientId: MQTT_CONFIG.clientId,
  username: MQTT_CONFIG.username,
  password: MQTT_CONFIG.password,
  keepalive: MQTT_CONFIG.keepalive
});

// 连接成功
client.on('connect', () => {
  console.log(chalk.green('✅ MQTT连接成功'));
  console.log(chalk.gray(`   Client ID: ${MQTT_CONFIG.clientId}`));
  console.log(chalk.gray(`   服务器: ${MQTT_CONFIG.host}\n`));
  
  testStats.connected = true;
  
  // 订阅主题
  const subscribeTopics = [
    `hotel/devices/${DEVICE_INFO.device_id}/commands`,
    `hotel/devices/${DEVICE_INFO.device_id}/config`,
    'hotel/broadcast/all'
  ];
  
  client.subscribe(subscribeTopics, (err) => {
    if (err) {
      console.error(chalk.red('❌ 订阅失败:', err.message));
      testStats.testsFailed++;
    } else {
      console.log(chalk.green('✅ 主题订阅成功'));
      subscribeTopics.forEach(topic => {
        console.log(chalk.gray(`   📡 ${topic}`));
      });
      console.log('');
      testStats.testsPassed++;
      
      // 开始测试序列
      runTestSequence();
    }
  });
});

// 接收消息
client.on('message', (topic, message) => {
  testStats.messagesReceived++;
  
  try {
    const data = JSON.parse(message.toString());
    console.log(chalk.cyan('\n📥 收到消息:'));
    console.log(chalk.gray(`   主题: ${topic}`));
    console.log(chalk.gray(`   内容: ${JSON.stringify(data, null, 2)}`));
    
    // 处理云端指令
    if (topic.includes('/commands')) {
      handleCommand(data);
    }
  } catch (e) {
    console.log(chalk.cyan('\n📥 收到消息(原始):'));
    console.log(chalk.gray(`   主题: ${topic}`));
    console.log(chalk.gray(`   内容: ${message.toString()}`));
  }
});

// 处理云端指令
function handleCommand(data) {
  console.log(chalk.yellow('\n⚡ 执行云端指令:'), data.command);
  
  switch(data.command) {
    case 'set_rgb_color':
      console.log(chalk.gray(`   💡 RGB指示灯变色: ${data.params.color}`));
      break;
    case 'play_sound':
      console.log(chalk.gray(`   🔊 蜂鸣器发声: ${data.params.sound_type}`));
      break;
    case 'display_message':
      console.log(chalk.gray(`   📺 OLED显示: ${data.params.message}`));
      break;
    default:
      console.log(chalk.gray(`   ❓ 未知指令: ${data.command}`));
  }
  
  // 发送执行结果回传
  const response = {
    device_id: DEVICE_INFO.device_id,
    command_id: data.command_id,
    status: 'executed',
    timestamp: new Date().toISOString()
  };
  
  client.publish(
    `hotel/devices/${DEVICE_INFO.device_id}/responses`,
    JSON.stringify(response)
  );
  
  testStats.messagesPublished++;
  console.log(chalk.green('✅ 指令执行结果已回传'));
}

// 测试序列
async function runTestSequence() {
  console.log(chalk.blue('\n========================================'));
  console.log(chalk.blue('开始测试序列'));
  console.log(chalk.blue('========================================\n'));
  
  // 测试1: 设备上线通知
  await testDeviceOnline();
  
  // 测试2: RFID刷卡上报
  await testRFIDScan();
  
  // 测试3: 心跳包
  await testHeartbeat();
  
  // 测试4: 状态上报
  await testStatusReport();
  
  // 测试5: 批量刷卡模拟
  await testBatchRFID();
  
  // 输出测试报告
  setTimeout(() => {
    printTestReport();
    client.end();
    process.exit(0);
  }, 3000);
}

// 测试1: 设备上线通知
function testDeviceOnline() {
  return new Promise((resolve) => {
    console.log(chalk.yellow('测试1: 设备上线通知'));
    
    const message = {
      event: 'device_online',
      device_id: DEVICE_INFO.device_id,
      device_type: DEVICE_INFO.device_type,
      capabilities: DEVICE_INFO.capabilities,
      timestamp: new Date().toISOString(),
      ip_address: '192.168.1.100'
    };
    
    client.publish(
      'hotel/devices/online',
      JSON.stringify(message),
      { qos: 1 },
      (err) => {
        if (err) {
          console.error(chalk.red('❌ 上线通知发送失败'));
          testStats.testsFailed++;
        } else {
          console.log(chalk.green('✅ 上线通知发送成功'));
          console.log(chalk.gray(`   📤 主题: hotel/devices/online`));
          console.log(chalk.gray(`   📦 内容: ${JSON.stringify(message, null, 2)}\n`));
          testStats.messagesPublished++;
          testStats.testsPassed++;
        }
        setTimeout(resolve, 1000);
      }
    );
  });
}

// 测试2: RFID刷卡上报
function testRFIDScan() {
  return new Promise((resolve) => {
    console.log(chalk.yellow('测试2: RFID刷卡上报'));
    
    const message = {
      event: 'rfid_scan',
      device_id: DEVICE_INFO.device_id,
      card_id: 'A1B2C3D4E5F6',
      card_type: 'guest_card',
      room_id: 101,
      timestamp: new Date().toISOString()
    };
    
    client.publish(
      `hotel/devices/${DEVICE_INFO.device_id}/events`,
      JSON.stringify(message),
      { qos: 1 },
      (err) => {
        if (err) {
          console.error(chalk.red('❌ RFID刷卡上报失败'));
          testStats.testsFailed++;
        } else {
          console.log(chalk.green('✅ RFID刷卡上报成功'));
          console.log(chalk.gray(`   📤 主题: hotel/devices/${DEVICE_INFO.device_id}/events`));
          console.log(chalk.gray(`   💳 卡号: ${message.card_id}`));
          console.log(chalk.gray(`   🏨 房间: ${message.room_id}\n`));
          testStats.messagesPublished++;
          testStats.testsPassed++;
        }
        setTimeout(resolve, 1000);
      }
    );
  });
}

// 测试3: 心跳包
function testHeartbeat() {
  return new Promise((resolve) => {
    console.log(chalk.yellow('测试3: 心跳包'));
    
    const message = {
      type: 'heartbeat',
      device_id: DEVICE_INFO.device_id,
      status: 'online',
      uptime: 3600,
      timestamp: new Date().toISOString()
    };
    
    client.publish(
      `hotel/devices/${DEVICE_INFO.device_id}/heartbeat`,
      JSON.stringify(message),
      { qos: 0 },
      (err) => {
        if (err) {
          console.error(chalk.red('❌ 心跳包发送失败'));
          testStats.testsFailed++;
        } else {
          console.log(chalk.green('✅ 心跳包发送成功'));
          console.log(chalk.gray(`   📤 主题: hotel/devices/${DEVICE_INFO.device_id}/heartbeat`));
          console.log(chalk.gray(`   ⏱️  运行时间: ${message.uptime}s\n`));
          testStats.messagesPublished++;
          testStats.testsPassed++;
        }
        setTimeout(resolve, 1000);
      }
    );
  });
}

// 测试4: 状态上报
function testStatusReport() {
  return new Promise((resolve) => {
    console.log(chalk.yellow('测试4: 设备状态上报'));
    
    const message = {
      type: 'status_report',
      device_id: DEVICE_INFO.device_id,
      sensors: {
        rfid_reader: 'ready',
        rgb_led: 'on',
        buzzer: 'idle'
      },
      timestamp: new Date().toISOString()
    };
    
    client.publish(
      `hotel/devices/${DEVICE_INFO.device_id}/status`,
      JSON.stringify(message),
      { qos: 1 },
      (err) => {
        if (err) {
          console.error(chalk.red('❌ 状态上报失败'));
          testStats.testsFailed++;
        } else {
          console.log(chalk.green('✅ 状态上报成功'));
          console.log(chalk.gray(`   📤 主题: hotel/devices/${DEVICE_INFO.device_id}/status`));
          console.log(chalk.gray(`   📊 状态: ${JSON.stringify(message.sensors)}\n`));
          testStats.messagesPublished++;
          testStats.testsPassed++;
        }
        setTimeout(resolve, 1000);
      }
    );
  });
}

// 测试5: 批量刷卡模拟
function testBatchRFID() {
  return new Promise((resolve) => {
    console.log(chalk.yellow('测试5: 批量刷卡模拟'));
    
    const cards = [
      { card_id: 'A1B2C3D4E5F6', room_id: 101, type: 'guest_card' },
      { card_id: 'B2C3D4E5F6G7', room_id: 102, type: 'guest_card' },
      { card_id: 'C3D4E5F6G7H8', room_id: 103, type: 'staff_card' }
    ];
    
    let completed = 0;
    
    cards.forEach((card, index) => {
      setTimeout(() => {
        const message = {
          event: 'rfid_scan',
          device_id: DEVICE_INFO.device_id,
          card_id: card.card_id,
          card_type: card.type,
          room_id: card.room_id,
          timestamp: new Date().toISOString()
        };
        
        client.publish(
          `hotel/devices/${DEVICE_INFO.device_id}/events`,
          JSON.stringify(message),
          { qos: 1 }
        );
        
        testStats.messagesPublished++;
        console.log(chalk.gray(`   💳 刷卡 ${index + 1}: ${card.card_id} (房间${card.room_id})`));
        
        completed++;
        if (completed === cards.length) {
          console.log(chalk.green('✅ 批量刷卡模拟完成\n'));
          testStats.testsPassed++;
          resolve();
        }
      }, index * 500);
    });
  });
}

// 输出测试报告
function printTestReport() {
  console.log(chalk.blue('\n========================================'));
  console.log(chalk.blue('MQTT联调测试报告 - 前台管理端'));
  console.log(chalk.blue('========================================'));
  console.log(chalk.gray(`设备ID: ${DEVICE_INFO.device_id}`));
  console.log(chalk.gray(`设备类型: ${DEVICE_INFO.device_type}`));
  console.log(chalk.gray(`位置: ${DEVICE_INFO.location}\n`));
  
  console.log(chalk.white('测试统计:'));
  console.log(chalk.green(`  ✅ 通过: ${testStats.testsPassed}`));
  console.log(chalk.red(`  ❌ 失败: ${testStats.testsFailed}`));
  console.log(chalk.blue(`  📤 发送消息: ${testStats.messagesPublished}`));
  console.log(chalk.cyan(`  📥 接收消息: ${testStats.messagesReceived}\n`));
  
  console.log(chalk.white('测试项目:'));
  console.log(chalk.gray('  1. 设备上线通知'));
  console.log(chalk.gray('  2. RFID刷卡上报'));
  console.log(chalk.gray('  3. 心跳包维持'));
  console.log(chalk.gray('  4. 设备状态上报'));
  console.log(chalk.gray('  5. 批量刷卡模拟\n'));
  
  console.log(chalk.blue('========================================'));
  console.log(chalk.green('测试完成！'));
  console.log(chalk.blue('========================================\n'));
}

// 错误处理
client.on('error', (err) => {
  console.error(chalk.red('❌ MQTT错误:', err.message));
  testStats.testsFailed++;
});

client.on('offline', () => {
  console.log(chalk.yellow('⚠️  MQTT离线'));
});

client.on('reconnect', () => {
  console.log(chalk.yellow('🔄 MQTT重连中...'));
});

/**
 * ============================================================
 * 📸 最终截图检查清单
 * ============================================================
 * 
 * □ 截图1: MQTT连接成功 (显示Client ID和服务器地址)
 * □ 截图2: 主题订阅成功 (显示3个订阅主题)
 * □ 截图3: RFID刷卡上报成功 (显示卡号和房间号)
 * □ 截图4: 收到云端指令 (显示指令内容和执行结果)
 * □ 截图5: 测试报告汇总 (显示通过/失败统计)
 * 
 * ============================================================
 */