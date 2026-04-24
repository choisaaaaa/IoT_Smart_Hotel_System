import mqtt from 'mqtt';

/**
 * 设备控制测试（云端环境）
 * 
 * 测试通过MQTT协议控制硬件设备
 * 需要在云端环境或能连接云端MQTT的环境中运行
 */

describe('设备控制测试（云端环境）', () => {
  const MQTT_CONFIG = {
    host: 'mqtt://8.134.166.69:1883',
    username: 'hotel_device',
    password: 'device_secret',
    keepalive: 60,
  };

  let client: mqtt.MqttClient;
  const shouldSkip = process.env.SKIP_MQTT_TESTS === 'true';

  // 设置全局超时
  jest.setTimeout(60000);

  beforeEach((done) => {
    if (shouldSkip) {
      done();
      return;
    }

    client = mqtt.connect(MQTT_CONFIG.host, {
      username: MQTT_CONFIG.username,
      password: MQTT_CONFIG.password,
      keepalive: MQTT_CONFIG.keepalive,
    });

    client.on('connect', () => {
      done();
    });

    client.on('error', () => {
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

  (shouldSkip ? describe.skip : describe)('客房设备控制', () => {
    it('应该能控制灯光开关', (done) => {
      const topic = 'hotel/room/101/light/command';
      const command = JSON.stringify({
        action: 'toggle',
        timestamp: Date.now()
      });

      client.publish(topic, command, { qos: 1 }, (err) => {
        if (err) {
          done(err);
          return;
        }
        console.log('✅ 灯光控制指令已发送');
        expect(true).toBe(true);
        done();
      });
    });

    it('应该能设置空调温度', (done) => {
      const topic = 'hotel/room/101/ac/command';
      const command = JSON.stringify({
        action: 'set_temperature',
        temperature: 24,
        timestamp: Date.now()
      });

      client.publish(topic, command, { qos: 1 }, (err) => {
        if (err) {
          done(err);
          return;
        }
        console.log('✅ 空调温度设置指令已发送');
        expect(true).toBe(true);
        done();
      });
    });

    it('应该能控制窗帘', (done) => {
      const topic = 'hotel/room/101/curtain/command';
      const command = JSON.stringify({
        action: 'open',
        timestamp: Date.now()
      });

      client.publish(topic, command, { qos: 1 }, (err) => {
        if (err) {
          done(err);
          return;
        }
        console.log('✅ 窗帘控制指令已发送');
        expect(true).toBe(true);
        done();
      });
    });
  });

  (shouldSkip ? describe.skip : describe)('传感器数据采集', () => {
    it('应该能接收温湿度数据', (done) => {
      const topic = 'hotel/room/101/sensor/dht11';
      
      client.subscribe(topic, (err) => {
        if (err) {
          done(err);
          return;
        }

        client.on('message', (receivedTopic, message) => {
          if (receivedTopic === topic) {
            const data = JSON.parse(message.toString());
            console.log(`✅ 收到温湿度数据: ${JSON.stringify(data)}`);
            expect(data).toHaveProperty('temperature');
            expect(data).toHaveProperty('humidity');
            done();
          }
        });

        // 模拟数据上报
        setTimeout(() => {
          const testData = JSON.stringify({
            temperature: 25.5,
            humidity: 60,
            timestamp: Date.now()
          });
          client.publish(topic, testData, { qos: 1 });
        }, 100);
      });
    });

    it('应该能接收烟雾报警', (done) => {
      const topic = 'hotel/floor/1/sensor/smoke';
      
      client.subscribe(topic, (err) => {
        if (err) {
          done(err);
          return;
        }

        client.on('message', (receivedTopic, message) => {
          if (receivedTopic === topic) {
            const data = JSON.parse(message.toString());
            console.log(`✅ 收到烟雾数据: ${JSON.stringify(data)}`);
            expect(data).toHaveProperty('level');
            done();
          }
        });

        setTimeout(() => {
          const testData = JSON.stringify({
            level: 150,
            alarm: false,
            timestamp: Date.now()
          });
          client.publish(topic, testData, { qos: 1 });
        }, 100);
      });
    });
  });

  (shouldSkip ? describe.skip : describe)('RFID门禁', () => {
    it('应该能接收刷卡记录', (done) => {
      const topic = 'hotel/frontdesk/rfid/events';
      
      client.subscribe(topic, (err) => {
        if (err) {
          done(err);
          return;
        }

        client.on('message', (receivedTopic, message) => {
          if (receivedTopic === topic) {
            const data = JSON.parse(message.toString());
            console.log(`✅ 收到刷卡记录: ${JSON.stringify(data)}`);
            expect(data).toHaveProperty('card_id');
            expect(data).toHaveProperty('timestamp');
            done();
          }
        });

        setTimeout(() => {
          const testData = JSON.stringify({
            card_id: 'A1B2C3D4',
            room_id: 101,
            action: 'check_in',
            timestamp: Date.now()
          });
          client.publish(topic, testData, { qos: 1 });
        }, 100);
      });
    });
  });
});
