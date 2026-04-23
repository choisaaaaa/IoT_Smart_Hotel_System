import mqtt from 'mqtt';

/**
 * MQTT连接测试（云端环境）
 * 
 * ⚠️ 警告: 此测试需要在云端环境或能连接云端MQTT的环境中运行
 * 本地运行会失败，因为无法连接到云端的MQTT Broker
 * 
 * 运行方式:
 * 1. 将代码部署到云端服务器
 * 2. 或在本地配置VPN连接到云端内网
 * 3. 或使用本地MQTT Broker进行测试
 */

describe('MQTT连接测试（云端环境）', () => {
  const MQTT_CONFIG = {
    host: 'mqtt://8.134.166.69:1883', // 云端MQTT地址
    username: 'hotel_device',
    password: 'device_secret',
    keepalive: 60,
    reconnectPeriod: 5000,
  };

  let client: mqtt.MqttClient;

  // 跳过所有测试如果环境变量设置
  const shouldSkip = process.env.SKIP_MQTT_TESTS === 'true';

  beforeEach((done) => {
    if (shouldSkip) {
      done();
      return;
    }

    client = mqtt.connect(MQTT_CONFIG.host, {
      username: MQTT_CONFIG.username,
      password: MQTT_CONFIG.password,
      keepalive: MQTT_CONFIG.keepalive,
      reconnectPeriod: MQTT_CONFIG.reconnectPeriod,
    });

    client.on('connect', () => {
      console.log('✅ MQTT连接成功');
      done();
    });

    client.on('error', (err) => {
      console.error('❌ MQTT连接失败:', err.message);
      done();
    });
  });

  afterEach((done) => {
    if (client) {
      client.end(true, {}, done);
    } else {
      done();
    }
  });

  (shouldSkip ? describe.skip : describe)('MQTT基础连接', () => {
    it('应该能连接到云端MQTT Broker', (done) => {
      expect(client.connected).toBe(true);
      done();
    });

    it('应该能订阅主题', (done) => {
      const testTopic = 'test/subscription';
      
      client.subscribe(testTopic, (err) => {
        if (err) {
          done(err);
          return;
        }
        console.log(`✅ 订阅成功: ${testTopic}`);
        expect(true).toBe(true);
        done();
      });
    });

    it('应该能发布消息', (done) => {
      const testTopic = 'test/publish';
      const testMessage = JSON.stringify({ test: 'message', timestamp: Date.now() });

      client.publish(testTopic, testMessage, { qos: 1 }, (err) => {
        if (err) {
          done(err);
          return;
        }
        console.log(`✅ 消息发布成功: ${testTopic}`);
        expect(true).toBe(true);
        done();
      });
    });

    it('应该能接收订阅的消息', (done) => {
      const testTopic = 'test/receive';
      const testMessage = JSON.stringify({ test: 'receive', timestamp: Date.now() });

      client.subscribe(testTopic, (err) => {
        if (err) {
          done(err);
          return;
        }

        client.on('message', (topic, message) => {
          if (topic === testTopic) {
            console.log(`✅ 收到消息: ${topic} - ${message.toString()}`);
            expect(topic).toBe(testTopic);
            done();
          }
        });

        // 延迟发布，确保订阅完成
        setTimeout(() => {
          client.publish(testTopic, testMessage, { qos: 1 });
        }, 100);
      });
    });
  });

  (shouldSkip ? describe.skip : describe)('酒店业务场景', () => {
    it('应该能订阅设备状态主题', (done) => {
      const deviceTopic = 'hotel/devices/+/status';
      
      client.subscribe(deviceTopic, (err) => {
        if (err) {
          done(err);
          return;
        }
        console.log(`✅ 订阅设备状态主题: ${deviceTopic}`);
        expect(true).toBe(true);
        done();
      });
    });

    it('应该能发布设备控制指令', (done) => {
      const controlTopic = 'hotel/devices/room_101_light/commands';
      const command = JSON.stringify({
        command: 'turn_on',
        timestamp: Date.now()
      });

      client.publish(controlTopic, command, { qos: 1 }, (err) => {
        if (err) {
          done(err);
          return;
        }
        console.log(`✅ 设备控制指令发布成功`);
        expect(true).toBe(true);
        done();
      });
    });

    it('应该能接收传感器数据', (done) => {
      const sensorTopic = 'hotel/sensors/+/data';
      
      client.subscribe(sensorTopic, (err) => {
        if (err) {
          done(err);
          return;
        }

        client.on('message', (topic, message) => {
          if (topic.startsWith('hotel/sensors/')) {
            console.log(`✅ 收到传感器数据: ${topic}`);
            const data = JSON.parse(message.toString());
            expect(data).toHaveProperty('timestamp');
            done();
          }
        });

        // 模拟传感器数据上报
        setTimeout(() => {
          const testData = JSON.stringify({
            temperature: 25.5,
            humidity: 60,
            timestamp: Date.now()
          });
          client.publish('hotel/sensors/room_101/data', testData, { qos: 1 });
        }, 100);
      });
    });
  });

  (shouldSkip ? describe.skip : describe)('连接稳定性', () => {
    it('应该能保持连接一段时间', (done) => {
      const keepAliveTime = 3000; // 3秒

      setTimeout(() => {
        expect(client.connected).toBe(true);
        console.log('✅ 连接保持稳定');
        done();
      }, keepAliveTime);
    });

    it('应该能自动重连', (done) => {
      let reconnected = false;

      client.on('reconnect', () => {
        console.log('🔄 正在重连...');
      });

      client.on('connect', () => {
        if (reconnected) {
          console.log('✅ 重连成功');
          done();
        }
      });

      // 模拟断开连接
      setTimeout(() => {
        reconnected = true;
        client.end(true);
      }, 500);
    });
  });
});

/**
 * 使用说明：
 * 
 * 1. 在云端环境运行：
 *    npm test -- mqtt-connection.test.ts
 * 
 * 2. 本地跳过MQTT测试：
 *    SKIP_MQTT_TESTS=true npm test -- mqtt-connection.test.ts
 * 
 * 3. 使用本地MQTT Broker测试：
 *    修改 MQTT_CONFIG.host 为 'mqtt://localhost:1883'
 */
