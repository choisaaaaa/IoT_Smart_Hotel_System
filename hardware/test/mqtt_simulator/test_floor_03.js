const mqtt = require('mqtt');

// 1. 配置参数
const BROKER_URL = 'mqtt://8.134.166.69:1883'; // 云端真实 IP
const OPTIONS = {
    clientId: 'floor_03',
    username: 'iot_user',
    password: 'IotHotel2026',
    clean: true,
    connectTimeout: 4000,
    reconnectPeriod: 1000,
};

const DEVICE_ID = 'floor_03';

// 辅助函数：获取 ISO8601 时间戳
function getTimestamp() {
    return new Date().toISOString();
}

console.log(`[Floor_03] 🟢 正在连接到后端云服务器 ${BROKER_URL}...`);
const client = mqtt.connect(BROKER_URL, OPTIONS);

client.on('connect', () => {
    console.log(`[Floor_03] ✅ MQTT 连接成功！`);

    // 2. 注册上线 (规范 6.1.1)
    const statusTopic = `hotel/device/status/floor/${DEVICE_ID}`;
    const statusPayload = {
        device_id: DEVICE_ID,
        device_type: "floor",
        status: "online",
        firmware_version: "v1.1.0_sim",
        timestamp: getTimestamp()
    };
    client.publish(statusTopic, JSON.stringify(statusPayload));
    console.log(`[Floor_03] 📤 已发送上线状态`);

    // 3. 订阅楼层群控指令 (如公共走廊照明)
    const cmdTopic = `hotel/device/command/floor/${DEVICE_ID}`;
    client.subscribe(cmdTopic, (err) => {
        if (!err) console.log(`[Floor_03] 📥 已订阅群控指令 Topic: ${cmdTopic}`);
    });

    // 4. 定时上报走廊公共环境数据 (光照)
    setInterval(() => {
        const light = +(300 + Math.random() * 200).toFixed(0); // 300-500 lux
        
        const lightPayload = {
            device_id: DEVICE_ID,
            sensor_type: "light",
            value: light,
            unit: "lux",
            timestamp: getTimestamp()
        };
        client.publish(`hotel/device/data/light/${DEVICE_ID}`, JSON.stringify(lightPayload));
        console.log(`[Floor_03] 📤 上报公共走廊光照: ${light} lux`);

    }, 20000); // 每 20 秒上报一次走廊光照
});

// 5. 监听云端楼层指令并回传执行结果
client.on('message', (topic, message) => {
    try {
        const cmd = JSON.parse(message.toString());
        console.log(`\n[Floor_03] 🔔 收到楼控群控指令 (Topic: ${topic})`);
        console.log(`           动作: ${cmd.command_type}, ID: ${cmd.command_id}`);
        console.log(`           正在切换走廊继电器组... (耗时500ms)`);

        setTimeout(() => {
            const replyTopic = `hotel/device/command/result`;
            const replyPayload = {
                device_id: DEVICE_ID,
                command_id: cmd.command_id,
                command_type: cmd.command_type,
                status: "success",
                result: "走廊设备动作完成",
                timestamp: getTimestamp()
            };
            client.publish(replyTopic, JSON.stringify(replyPayload));
            console.log(`[Floor_03] 📤 已群发执行结果回执 -> 成功`);
        }, 500);

    } catch (e) {
        console.error(`[Floor_03] ❌ 解析指令失败: ${message.toString()}`);
    }
});

client.on('error', (err) => {
    console.error(`[Floor_03] ❌ MQTT 连接错误:`, err);
});
