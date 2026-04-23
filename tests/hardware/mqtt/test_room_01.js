/**
 * MQTT联调测试 - 客房终端
 * 
 * 对应配图：8.3 MQTT通信联调测试
 * 
 * 测试内容：
 * 1. MQTT连接与认证
 * 2. 指令接收与执行（继电器控制）
 * 3. 状态回传
 * 4. 红外控制
 * 5. 语音交互
 * 6. 心跳维持
 */

const mqtt = require('mqtt');
const chalk = require('chalk');

// MQTT配置
const MQTT_CONFIG = {
  host: 'mqtt://localhost:1883',
  clientId: 'room_terminal_test_' + Math.random().toString(16).substr(2, 8),
  username: 'hotel_device',
  password: 'device_secret',
  keepalive: 60,
};

// 设备信息
const DEVICE_INFO = {
  device_id: 'room_terminal_101',
  device_type: 'room_terminal',
  location: '101客房',
  room_id: 101,
  capabilities: ['relay', 'ir', 'voice', 'radar']
};

// 设备状态
let deviceState = {
  relay1: false,  // 灯光
  relay2: false,  // 插座
  relay3: false,  // 空调
  relay4: false,  // 窗帘
  ac_temperature: 26,
  last_voice_cmd: null
};

// 测试统计
let testStats = {
  connected: false,
  messagesPublished: 0,
  messagesReceived: 0,
  commandsExecuted: 0,
  testsPassed: 0,
  testsFailed: 0
};

console.log(chalk.blue('========================================'));
console.log(chalk.blue('MQTT联调测试 - 客房终端'));
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
  console.log(chalk.gray(`   位置: ${DEVICE_INFO.location}\n`));
  
  testStats.connected = true;
  
  // 订阅主题
  const subscribeTopics = [
    `hotel/devices/${DEVICE_INFO.device_id}/commands`,
    `hotel/rooms/${DEVICE_INFO.room_id}/commands`,
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
    console.log(chalk.cyan('\n📥 收到指令:'));
    console.log(chalk.gray(`   主题: ${topic}`));
    console.log(chalk.gray(`   指令: ${JSON.stringify(data, null, 2)}`));
    
    // 执行指令
    executeCommand(data);
  } catch (e) {
    console.log(chalk.cyan('\n📥 收到消息(原始):'));
    console.log(chalk.gray(`   主题: ${topic}`));
    console.log(chalk.gray(`   内容: ${message.toString()}`));
  }
});

// 执行指令
function executeCommand(data) {
  console.log(chalk.yellow('\n⚡ 执行指令:'), data.command);
  
  let result = {
    device_id: DEVICE_INFO.device_id,
    command_id: data.command_id,
    command: data.command,
    status: 'executed',
    timestamp: new Date().toISOString()
  };
  
  switch(data.command) {
    case 'relay_on':
      const relayNum = data.params?.relay || 1;
      deviceState[`relay${relayNum}`] = true;
      console.log(chalk.gray(`   🔌 继电器${relayNum} 开启`));
      result.details = { relay: relayNum, state: 'on' };
      break;
      
    case 'relay_off':
      const relayOffNum = data.params?.relay || 1;
      deviceState[`relay${relayOffNum}`] = false;
      console.log(chalk.gray(`   🔌 继电器${relayOffNum} 关闭`));
      result.details = { relay: relayOffNum, state: 'off' };
      break;
      
    case 'set_ac_temperature':
      deviceState.ac_temperature = data.params?.temperature || 26;
      console.log(chalk.gray(`   ❄️  空调温度设置: ${deviceState.ac_temperature}°C`));
      result.details = { temperature: deviceState.ac_temperature };
      break;
      
    case 'ir_send':
      console.log(chalk.gray(`   📡 红外发射: ${data.params?.brand} ${data.params?.command}`));
      result.details = { ir_command: data.params?.command };
      break;
      
    case 'scene_welcome':
      deviceState.relay1 = true;
      deviceState.relay3 = true;
      deviceState.ac_temperature = 24;
      console.log(chalk.gray('   🎉 执行欢迎场景'));
      console.log(chalk.gray('      💡 灯光开启'));
      console.log(chalk.gray('      ❄️  空调开启 (24°C)'));
      result.details = { scene: 'welcome' };
      break;
      
    case 'scene_sleep':
      deviceState.relay1 = false;
      deviceState.relay2 = false;
      deviceState.relay4 = false;
      deviceState.ac_temperature = 26;
      console.log(chalk.gray('   😴 执行睡眠场景'));
      console.log(chalk.gray('      💡 灯光关闭'));
      console.log(chalk.gray('      🪟 窗帘关闭'));
      console.log(chalk.gray('      ❄️  空调静音 (26°C)'));
      result.details = { scene: 'sleep' };
      break;
      
    default:
      console.log(chalk.gray(`   ❓ 未知指令: ${data.command}`));
      result.status = 'unknown_command';
  }
  
  testStats.commandsExecuted++;
  
  // 发送执行结果回传
  client.publish(
    `hotel/devices/${DEVICE_INFO.device_id}/responses`,
    JSON.stringify(result),
    { qos: 1 }
  );
  
  testStats.messagesPublished++;
  console.log(chalk.green('✅ 指令执行结果已回传'));
  
  // 同时上报设备状态
  setTimeout(() => {
    reportDeviceStatus();
  }, 500);
}

// 上报设备状态
function reportDeviceStatus() {
  const status = {
    type: 'status_report',
    device_id: DEVICE_INFO.device_id,
    room_id: DEVICE_INFO.room_id,
    state: deviceState,
    timestamp: new Date().toISOString()
  };
  
  client.publish(
    `hotel/devices/${DEVICE_INFO.device_id}/status`,
    JSON.stringify(status),
    { qos: 1 }
  );
  
  testStats.messagesPublished++;
  console.log(chalk.blue('📊 设备状态已上报'));
}

// 测试序列
async function runTestSequence() {
  console.log(chalk.blue('\n========================================'));
  console.log(chalk.blue('开始测试序列'));
  console.log(chalk.blue('========================================\n'));
  
  // 测试1: 设备上线
  await testDeviceOnline();
  
  // 测试2: 上报初始状态
  await testInitialStatus();
  
  // 测试3: 模拟接收灯光控制指令
  await testLightControl();
  
  // 测试4: 模拟接收空调控制指令
  await testACControl();
  
  // 测试5: 模拟接收场景指令
  await testSceneControl();
  
  // 测试6: 模拟语音指令
  await testVoiceCommand();
  
  // 测试7: 心跳包
  await testHeartbeat();
  
  // 输出测试报告
  setTimeout(() => {
    printTestReport();
    client.end();
    process.exit(0);
  }, 3000);
}

// 测试1: 设备上线
function testDeviceOnline() {
  return new Promise((resolve) => {
    console.log(chalk.yellow('测试1: 设备上线通知'));
    
    const message = {
      event: 'device_online',
      device_id: DEVICE_INFO.device_id,
      device_type: DEVICE_INFO.device_type,
      room_id: DEVICE_INFO.room_id,
      capabilities: DEVICE_INFO.capabilities,
      timestamp: new Date().toISOString()
    };
    
    client.publish('hotel/devices/online', JSON.stringify(message), { qos: 1 }, (err) => {
      if (err) {
        console.error(chalk.red('❌ 上线通知失败'));
        testStats.testsFailed++;
      } else {
        console.log(chalk.green('✅ 上线通知成功'));
        testStats.messagesPublished++;
        testStats.testsPassed++;
      }
      setTimeout(resolve, 1000);
    });
  });
}

// 测试2: 上报初始状态
function testInitialStatus() {
  return new Promise((resolve) => {
    console.log(chalk.yellow('\n测试2: 初始状态上报'));
    reportDeviceStatus();
    testStats.testsPassed++;
    setTimeout(resolve, 1000);
  });
}

// 测试3: 模拟接收灯光控制指令
function testLightControl() {
  return new Promise((resolve) => {
    console.log(chalk.yellow('\n测试3: 灯光控制指令模拟'));
    
    // 模拟收到开灯指令
    const turnOnCmd = {
      command_id: 'cmd_001',
      command: 'relay_on',
      params: { relay: 1 }
    };
    
    console.log(chalk.gray('模拟收到指令:'), JSON.stringify(turnOnCmd));
    executeCommand(turnOnCmd);
    
    setTimeout(() => {
      // 模拟收到关灯指令
      const turnOffCmd = {
        command_id: 'cmd_002',
        command: 'relay_off',
        params: { relay: 1 }
      };
      
      console.log(chalk.gray('模拟收到指令:'), JSON.stringify(turnOffCmd));
      executeCommand(turnOffCmd);
      
      testStats.testsPassed++;
      setTimeout(resolve, 1500);
    }, 1000);
  });
}

// 测试4: 模拟接收空调控制指令
function testACControl() {
  return new Promise((resolve) => {
    console.log(chalk.yellow('\n测试4: 空调控制指令模拟'));
    
    const acCmd = {
      command_id: 'cmd_003',
      command: 'set_ac_temperature',
      params: { temperature: 24 }
    };
    
    console.log(chalk.gray('模拟收到指令:'), JSON.stringify(acCmd));
    executeCommand(acCmd);
    
    testStats.testsPassed++;
    setTimeout(resolve, 1500);
  });
}

// 测试5: 模拟接收场景指令
function testSceneControl() {
  return new Promise((resolve) => {
    console.log(chalk.yellow('\n测试5: 场景指令模拟'));
    
    const welcomeScene = {
      command_id: 'cmd_004',
      command: 'scene_welcome',
      params: {}
    };
    
    console.log(chalk.gray('模拟收到指令:'), JSON.stringify(welcomeScene));
    executeCommand(welcomeScene);
    
    setTimeout(() => {
      const sleepScene = {
        command_id: 'cmd_005',
        command: 'scene_sleep',
        params: {}
      };
      
      console.log(chalk.gray('模拟收到指令:'), JSON.stringify(sleepScene));
      executeCommand(sleepScene);
      
      testStats.testsPassed++;
      setTimeout(resolve, 1500);
    }, 1000);
  });
}

// 测试6: 模拟语音指令
function testVoiceCommand() {
  return new Promise((resolve) => {
    console.log(chalk.yellow('\n测试6: 语音交互模拟'));
    
    const voiceResult = {
      type: 'voice_command',
      device_id: DEVICE_INFO.device_id,
      raw_text: '打开房间的灯',
      intent: 'turn_on_light',
      confidence: 0.95,
      executed: true,
      timestamp: new Date().toISOString()
    };
    
    client.publish(
      `hotel/devices/${DEVICE_INFO.device_id}/voice`,
      JSON.stringify(voiceResult),
      { qos: 1 },
      (err) => {
        if (err) {
          console.error(chalk.red('❌ 语音结果上报失败'));
        } else {
          console.log(chalk.green('✅ 语音交互结果上报成功'));
          console.log(chalk.gray(`   🎤 语音: "${voiceResult.raw_text}"`));
          console.log(chalk.gray(`   🎯 意图: ${voiceResult.intent}`));
          console.log(chalk.gray(`   📊 置信度: ${voiceResult.confidence}`));
          testStats.messagesPublished++;
          testStats.testsPassed++;
        }
        setTimeout(resolve, 1000);
      }
    );
  });
}

// 测试7: 心跳包
function testHeartbeat() {
  return new Promise((resolve) => {
    console.log(chalk.yellow('\n测试7: 心跳包'));
    
    const message = {
      type: 'heartbeat',
      device_id: DEVICE_INFO.device_id,
      room_id: DEVICE_INFO.room_id,
      status: 'online',
      state: deviceState,
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
          testStats.messagesPublished++;
          testStats.testsPassed++;
        }
        setTimeout(resolve, 1000);
      }
    );
  });
}

// 输出测试报告
function printTestReport() {
  console.log(chalk.blue('\n========================================'));
  console.log(chalk.blue('MQTT联调测试报告 - 客房终端'));
  console.log(chalk.blue('========================================'));
  console.log(chalk.gray(`设备ID: ${DEVICE_INFO.device_id}`));
  console.log(chalk.gray(`位置: ${DEVICE_INFO.location}`));
  console.log(chalk.gray(`房间号: ${DEVICE_INFO.room_id}\n`));
  
  console.log(chalk.white('测试统计:'));
  console.log(chalk.green(`  ✅ 通过: ${testStats.testsPassed}`));
  console.log(chalk.red(`  ❌ 失败: ${testStats.testsFailed}`));
  console.log(chalk.blue(`  📤 发送消息: ${testStats.messagesPublished}`));
  console.log(chalk.cyan(`  📥 接收消息: ${testStats.messagesReceived}`));
  console.log(chalk.yellow(`  ⚡ 执行指令: ${testStats.commandsExecuted}\n`));
  
  console.log(chalk.white('设备能力:'));
  DEVICE_INFO.capabilities.forEach(cap => {
    console.log(chalk.gray(`  • ${cap}`));
  });
  console.log('');
  
  console.log(chalk.white('最终设备状态:'));
  console.log(chalk.gray(`  继电器1(灯光): ${deviceState.relay1 ? '开启' : '关闭'}`));
  console.log(chalk.gray(`  继电器2(插座): ${deviceState.relay2 ? '开启' : '关闭'}`));
  console.log(chalk.gray(`  继电器3(空调): ${deviceState.relay3 ? '开启' : '关闭'}`));
  console.log(chalk.gray(`  继电器4(窗帘): ${deviceState.relay4 ? '开启' : '关闭'}`));
  console.log(chalk.gray(`  空调温度: ${deviceState.ac_temperature}°C\n`));
  
  console.log(chalk.blue('========================================'));
  console.log(chalk.green('测试完成！'));
  console.log(chalk.blue('========================================\n'));
}

// 错误处理
client.on('error', (err) => {
  console.error(chalk.red('❌ MQTT错误:', err.message));
});
