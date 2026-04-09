const mqtt = require('mqtt');

const client = mqtt.connect('mqtt://localhost:1883');

client.on('connect', () => {
  console.log('✅ MQTT 连接成功！');
  
  // 订阅测试主题
  client.subscribe('test/topic', (err) => {
    if (err) {
      console.error('❌ 订阅失败:', err);
    } else {
      console.log('✅ 订阅成功');
      
      // 发布测试消息
      client.publish('test/topic', 'Hello from test script');
      console.log('📤 已发送测试消息');
    }
  });
});

client.on('message', (topic, message) => {
  console.log('📨 收到消息:', topic, message.toString());
  client.end();
});

client.on('error', (err) => {
  console.error('❌ MQTT 连接错误:', err.message);
  process.exit(1);
});

client.on('offline', () => {
  console.log('⚠️ MQTT 离线');
});

// 5秒后超时
setTimeout(() => {
  console.log('⏱️ 测试超时');
  client.end();
  process.exit(0);
}, 5000);
