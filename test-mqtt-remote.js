const mqtt = require('mqtt');

// 连接到远程 MQTT 服务器
const client = mqtt.connect('mqtt://8.134.166.69:1883', {
  connectTimeout: 5000,
  reconnectPeriod: 0  // 不重连，测试一次即可
});

console.log('🔗 正在连接 MQTT 服务器: 8.134.166.69:1883...');

client.on('connect', () => {
  console.log('✅ MQTT 连接成功！');
  
  // 订阅测试主题
  client.subscribe('test/connection', (err) => {
    if (err) {
      console.error('❌ 订阅失败:', err);
      client.end();
      return;
    }
    console.log('✅ 订阅成功: test/connection');
    
    // 发布测试消息
    const message = `Hello from local test at ${new Date().toLocaleString()}`;
    client.publish('test/connection', message, (err) => {
      if (err) {
        console.error('❌ 发布失败:', err);
      } else {
        console.log('📤 已发送测试消息:', message);
      }
    });
  });
});

client.on('message', (topic, message) => {
  console.log('📨 收到消息:', topic, '->', message.toString());
  console.log('✅ MQTT 验证成功！服务器工作正常。');
  client.end();
});

client.on('error', (err) => {
  console.error('❌ MQTT 连接错误:', err.message);
  if (err.message.includes('ECONNREFUSED')) {
    console.log('💡 提示: 无法连接到服务器，请检查:');
    console.log('   1. 服务器是否运行');
    console.log('   2. 防火墙是否允许 1883 端口');
    console.log('   3. 安全组是否开放 1883 端口');
  }
  process.exit(1);
});

client.on('offline', () => {
  console.log('⚠️ MQTT 离线');
});

client.on('close', () => {
  console.log('🔌 连接已关闭');
});

// 10秒后超时
setTimeout(() => {
  console.log('⏱️ 测试超时，关闭连接');
  client.end();
  process.exit(0);
}, 10000);
