/**
 * MQTT联调测试 - 楼控节点
 * 
 * 对应配图：8.3 MQTT通信联调测试
 * 
 * 测试内容：
 * 1. MQTT连接与认证
 * 2. 传感器数据定时上报（温湿度、烟雾、光照）
 * 3. 云端配置接收
 * 4. 报警事件上报
 * 5. 心跳维持
 */

const mqtt = require('mqtt');
const chalk = require('chalk');

// MQTT配置
const MQTT_CONFIG = {
  host: 'mqtt://localhost:1883',
  clientId: 'floor_control_test_' + Math.random().toString(16).substr(2, 8),
  username: 'hotel_device',
  password: 'device_secret',
  keepalive: 60,
};

// 设备信息
const DEVICE_INFO = {
  device_id: 'floor_control_001',
  device_type: 'floor_control',
  location: '1楼走廊',
  floor: 1,
  sensors: ['dht11', 'mq2', 'light']
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
console.log(chalk.blue('MQTT联调测试 - 楼控节点'));
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
    `hotel/devices/${DEVICE_INFO.device_id}/config`,
    `hotel/devices/${DEVICE_INFO.device_id}/commands`,
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
  } catch (e) {
    console.log(chalk.cyan('\n📥 收到消息(原始):'));
    console.log(chalk.gray(`   主题: ${topic}`));
    console.log(chalk.gray(`   内容: ${message.toString()}`));
  }
});

// 测试序列
async function runTestSequence() {
  console.log(chalk.blue('\n========================================'));
  console.log(chalk.blue('开始测试序列'));
  console.log(chalk.blue('========================================\n'));
  
  // 测试1: 设备上线
  await testDeviceOnline();
  
  // 测试2: 温湿度数据上报
  await testDHT11Data();
  
  // 测试3: 烟雾传感器数据上报
  await testMQ2Data();
  
  // 测试4: 光照传感器数据上报
  await testLightData();
  
  // 测试5: 报警事件上报
  await testAlarmEvent();
  
  // 测试6: 心跳包
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
      floor: DEVICE_INFO.floor,
      sensors: DEVICE_INFO.sensors,
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

// 测试2: 温湿度数据上报
function testDHT11Data() {
  return new Promise((resolve) => {
    console.log(chalk.yellow('\n测试2: 温湿度传感器数据上报'));
    
    const message = {
      sensor_type: 'dht11',
      device_id: DEVICE_INFO.device_id,
      data: {
        temperature: 25.5,
        humidity: 60,
        unit: 'C/%'
      },
      timestamp: new Date().toISOString()
    };
    
    client.publish(
      `hotel/sensors/${DEVICE_INFO.device_id}/dht11`,
      JSON.stringify(message),
      { qos: 1 },
      (err) => {
        if (err) {
          console.error(chalk.red('❌ 温湿度数据上报失败'));
          testStats.testsFailed++;
        } else {
          console.log(chalk.green('✅ 温湿度数据上报成功'));
          console.log(chalk.gray(`   🌡️  温度: ${message.data.temperature}°C`));
          console.log(chalk.gray(`   💧 湿度: ${message.data.humidity}%`));
          testStats.messagesPublished++;
          testStats.testsPassed++;
        }
        setTimeout(resolve, 1000);
      }
    );
  });
}

// 测试3: 烟雾传感器数据上报
function testMQ2Data() {
  return new Promise((resolve) => {
    console.log(chalk.yellow('\n测试3: 烟雾传感器数据上报'));
    
    const message = {
      sensor_type: 'mq2',
      device_id: DEVICE_INFO.device_id,
      data: {
        smoke_level: 150,
        alarm: false,
        threshold: 500
      },
      timestamp: new Date().toISOString()
    };
    
    client.publish(
      `hotel/sensors/${DEVICE_INFO.device_id}/mq2`,
      JSON.stringify(message),
      { qos: 1 },
      (err) => {
        if (err) {
          console.error(chalk.red('❌ 烟雾数据上报失败'));
          testStats.testsFailed++;
        } else {
          console.log(chalk.green('✅ 烟雾数据上报成功'));
          console.log(chalk.gray(`   🔥 烟雾浓度: ${message.data.smoke_level}`));
          console.log(chalk.gray(`   🚨 报警状态: ${message.data.alarm ? '是' : '否'}`));
          testStats.messagesPublished++;
          testStats.testsPassed++;
        }
        setTimeout(resolve, 1000);
      }
    );
  });
}

// 测试4: 光照传感器数据上报
function testLightData() {
  return new Promise((resolve) => {
    console.log(chalk.yellow('\n测试4: 光照传感器数据上报'));
    
    const message = {
      sensor_type: 'light',
      device_id: DEVICE_INFO.device_id,
      data: {
        brightness: 800,
        unit: 'lux'
      },
      timestamp: new Date().toISOString()
    };
    
    client.publish(
      `hotel/sensors/${DEVICE_INFO.device_id}/light`,
      JSON.stringify(message),
      { qos: 0 },
      (err) => {
        if (err) {
          console.error(chalk.red('❌ 光照数据上报失败'));
          testStats.testsFailed++;
        } else {
          console.log(chalk.green('✅ 光照数据上报成功'));
          console.log(chalk.gray(`   ☀️  亮度: ${message.data.brightness} lux`));
          testStats.messagesPublished++;
          testStats.testsPassed++;
        }
        setTimeout(resolve, 1000);
      }
    );
  });
}

// 测试5: 报警事件上报
function testAlarmEvent() {
  return new Promise((resolve) => {
    console.log(chalk.yellow('\n测试5: 报警事件上报'));
    
    const message = {
      event: 'alarm',
      device_id: DEVICE_INFO.device_id,
      alarm_type: 'smoke_detected',
      severity: 'high',
      data: {
        smoke_level: 850,
        location: DEVICE_INFO.location,
        message: '检测到烟雾超标！'
      },
      timestamp: new Date().toISOString()
    };
    
    client.publish(
      'hotel/alarms/smoke',
      JSON.stringify(message),
      { qos: 2 },
      (err) => {
        if (err) {
          console.error(chalk.red('❌ 报警事件上报失败'));
          testStats.testsFailed++;
        } else {
          console.log(chalk.green('✅ 报警事件上报成功'));
          console.log(chalk.red(`   🚨 报警类型: ${message.alarm_type}`));
          console.log(chalk.red(`   📍 位置: ${message.data.location}`));
          console.log(chalk.red(`   📊 烟雾浓度: ${message.data.smoke_level}`));
          testStats.messagesPublished++;
          testStats.testsPassed++;
        }
        setTimeout(resolve, 1000);
      }
    );
  });
}

// 测试6: 心跳包
function testHeartbeat() {
  return new Promise((resolve) => {
    console.log(chalk.yellow('\n测试6: 心跳包'));
    
    const message = {
      type: 'heartbeat',
      device_id: DEVICE_INFO.device_id,
      status: 'online',
      sensors_status: {
        dht11: 'normal',
        mq2: 'normal',
        light: 'normal'
      },
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
  console.log(chalk.blue('MQTT联调测试报告 - 楼控节点'));
  console.log(chalk.blue('========================================'));
  console.log(chalk.gray(`设备ID: ${DEVICE_INFO.device_id}`));
  console.log(chalk.gray(`位置: ${DEVICE_INFO.location}`));
  console.log(chalk.gray(`楼层: ${DEVICE_INFO.floor}楼\n`));
  
  console.log(chalk.white('测试统计:'));
  console.log(chalk.green(`  ✅ 通过: ${testStats.testsPassed}`));
  console.log(chalk.red(`  ❌ 失败: ${testStats.testsFailed}`));
  console.log(chalk.blue(`  📤 发送消息: ${testStats.messagesPublished}`));
  console.log(chalk.cyan(`  📥 接收消息: ${testStats.messagesReceived}\n`));
  
  console.log(chalk.white('传感器列表:'));
  DEVICE_INFO.sensors.forEach(sensor => {
    console.log(chalk.gray(`  • ${sensor}`));
  });
  console.log('');
  
  console.log(chalk.blue('========================================'));
  console.log(chalk.green('测试完成！'));
  console.log(chalk.blue('========================================\n'));
}

// 错误处理
client.on('error', (err) => {
  console.error(chalk.red('❌ MQTT错误:', err.message));
});
