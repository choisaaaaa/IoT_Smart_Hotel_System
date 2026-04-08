const mqtt = require('mqtt');

// 1. 配置参数
const BROKER_URL = 'mqtt://8.134.166.69:1883'; // 云端真实 IP
const OPTIONS = {
    clientId: 'room_301',
    username: 'iot_user',
    password: 'IotHotel2026',
    clean: true,
    connectTimeout: 4000,
    reconnectPeriod: 1000,
};

const DEVICE_ID = 'room_301';

// 辅助函数：获取 ISO8601 时间戳
function getTimestamp() {
    return new Date().toISOString();
}

console.log(`[Room_301] 🟢 正在连接到后端云服务器 ${BROKER_URL}...`);
const client = mqtt.connect(BROKER_URL, OPTIONS);

client.on('connect', () => {
    console.log(`[Room_301] ✅ MQTT 连接成功！`);

    // 2. 注册上线 (规范 6.1.1)
    const statusTopic = `hotel/device/status/room/${DEVICE_ID}`;
    const statusPayload = {
        device_id: DEVICE_ID,
        hotel_id: 1, // 指定酒店 ID
        device_type: "room",
        status: "online",
        firmware_version: "v1.1.0_sim",
        timestamp: getTimestamp()
    };
    client.publish(statusTopic, JSON.stringify(statusPayload));
    console.log(`[Room_301] 📤 已发送上线状态`);

    // 3. 订阅房间控制指令 (规范 11.4)
    const cmdTopic = `hotel/device/command/room/${DEVICE_ID}`;
    client.subscribe(cmdTopic, (err) => {
        if (!err) console.log(`[Room_301] 📥 已订阅云端指令 Topic: ${cmdTopic}`);
    });

    // 4. 定时上报环境数据 (温度和湿度)
    setInterval(() => {
        const temp = +(20 + Math.random() * 5).toFixed(1); // 20-25℃
        const hum = +(40 + Math.random() * 20).toFixed(1); // 40-60%

        const tempPayload = {
            device_id: DEVICE_ID,
            sensor_type: "temperature",
            value: temp,
            unit: "℃",
            timestamp: getTimestamp()
        };
        client.publish(`hotel/device/data/temperature/${DEVICE_ID}`, JSON.stringify(tempPayload));
        console.log(`[Room_301] 📤 上报温度: ${temp} ℃`);

        const humPayload = {
            device_id: DEVICE_ID,
            sensor_type: "humidity",
            value: hum,
            unit: "%",
            timestamp: getTimestamp()
        };
        client.publish(`hotel/device/data/humidity/${DEVICE_ID}`, JSON.stringify(humPayload));
        console.log(`[Room_301] 📤 上报湿度: ${hum} %`);

    }, 10000); // 每 10 秒上报一次

    // 5. 偶尔模拟一个安防事件 (如有人刷卡开门)
    setInterval(() => {
        const eventPayload = {
            device_id: DEVICE_ID,
            event_type: "door_open",
            event_data: {
                room_id: 301,
                door_type: "main"
            },
            level: "info",
            timestamp: getTimestamp()
        };
        client.publish(`hotel/security/event`, JSON.stringify(eventPayload));
        console.log(`[Room_301] 🚨 触发安防事件: 房门被打开`);
    }, 45000); // 每 45 秒触发一次
});

// 6. 监听云端指令并回传执行结果
client.on('message', (topic, message) => {
    try {
        const cmd = JSON.parse(message.toString());
        console.log(`\n[Room_301] 🔔 收到云端指令 (Topic: ${topic})`);
        console.log(`             动作: ${cmd.command_type}, ID: ${cmd.command_id}`);
        console.log(`             正在模拟执行... (耗时1秒)`);

        // 组装执行结果回执 (规范 4.2.4)
        setTimeout(() => {
            const replyTopic = `hotel/device/command/result`;
            const replyPayload = {
                device_id: DEVICE_ID,
                command_id: cmd.command_id,
                command_type: cmd.command_type,
                status: "success",
                result: "硬件模拟执行成功",
                timestamp: getTimestamp()
            };
            client.publish(replyTopic, JSON.stringify(replyPayload));
            console.log(`[Room_301] 📤 已回传执行结果回执 -> 成功`);
        }, 1000);

    } catch (e) {
        console.error(`[Room_301] ❌ 收到非标准 JSON 指令, 解析失败: ${message.toString()}`);
    }
});

client.on('error', (err) => {
    console.error(`[Room_301] ❌ MQTT 连接错误:`, err);
});
