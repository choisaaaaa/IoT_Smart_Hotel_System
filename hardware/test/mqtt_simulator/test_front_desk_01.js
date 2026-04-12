const mqtt = require('mqtt');

// 1. 配置参数
const BROKER_URL = 'mqtt://8.134.166.69:1883'; // 云端真实 IP
const OPTIONS = {
    clientId: 'front_desk_01',
    username: 'iot_user',
    password: 'IotHotel2026',
    clean: true,
    connectTimeout: 4000,
    reconnectPeriod: 1000,
};

const DEVICE_ID = 'front_desk_01';
const startTime = Date.now();
let commandSeq = 4000;

// 辅助函数：获取 ISO8601 时间戳
function getTimestamp() {
    return new Date().toISOString();
}

console.log(`[Front_Desk_01] 🟢 正在连接到后端云服务器 ${BROKER_URL}...`);
const client = mqtt.connect(BROKER_URL, OPTIONS);

client.on('connect', () => {
    console.log(`[Front_Desk_01] ✅ MQTT 连接成功！`);

    // 2. 注册上线 (规范 6.1.1)
    const statusTopic = `hotel/device/status/front_desk/${DEVICE_ID}`;
    const statusPayload = {
        device_id: DEVICE_ID,
        device_type: "front_desk",
        status: "online",
        firmware_version: "v1.1.0_sim",
        timestamp: getTimestamp()
    };
    client.publish(statusTopic, JSON.stringify(statusPayload));
    console.log(`[Front_Desk_01] 📤 已发送上线状态`);

    // 3. 订阅执行回执，验证前台观察链路
    const resultTopic = 'hotel/device/command/result';
    client.subscribe(resultTopic, (err) => {
        if (!err) console.log(`[Front_Desk_01] 📥 已订阅回执 Topic: ${resultTopic}`);
    });

    // 4. 模拟前台按键触发事件（广播/消音）
    setInterval(() => {
        const eventPayload = {
            device_id: DEVICE_ID,
            device_type: "front_desk",
            event_type: "front_broadcast_pressed",
            detail: "前台广播按钮触发(脚本模拟)",
            timestamp: getTimestamp()
        };
        client.publish('hotel/security/event', JSON.stringify(eventPayload));
        console.log(`[Front_Desk_01] 📤 已上报前台事件: front_broadcast_pressed`);
    }, 45000);

    // 5. 模拟前台下发房间指令（呼入/挂断）
    setInterval(() => {
        const cmdTopic = 'hotel/device/command/room/room_301';
        const incomingCallPayload = {
            command_id: ++commandSeq,
            device_id: "room_301",
            command_type: "incoming_call",
            call_id: `call_${Date.now()}`,
            caller_id: DEVICE_ID,
            created_by: DEVICE_ID,
            timestamp: getTimestamp()
        };
        client.publish(cmdTopic, JSON.stringify(incomingCallPayload));
        console.log(`[Front_Desk_01] 📤 下发命令: incoming_call -> room_301`);

        setTimeout(() => {
            const hangupPayload = {
                command_id: ++commandSeq,
                device_id: "room_301",
                command_type: "hangup_call",
                call_id: incomingCallPayload.call_id,
                created_by: DEVICE_ID,
                timestamp: getTimestamp()
            };
            client.publish(cmdTopic, JSON.stringify(hangupPayload));
            console.log(`[Front_Desk_01] 📤 下发命令: hangup_call -> room_301`);
        }, 6000);
    }, 70000);

    // 6. 定时发送心跳保活数据 (规范 6.1.2)
    setInterval(() => {
        const uptimeSeconds = Math.floor((Date.now() - startTime) / 1000);
        const memUsage = Math.floor(20 + Math.random() * 10); // 模拟 20-30% 的内存占用
        const signalStrength = Math.floor(-40 - Math.random() * 20); // 模拟 -40 到 -60 dBm 的信号
        
        const heartbeatPayload = {
            device_id: DEVICE_ID,
            status: "online",
            battery_level: 100, // 前台通常插电
            signal_strength: signalStrength,
            uptime: uptimeSeconds,
            memory_usage: memUsage,
            cpu_usage: 15,
            timestamp: getTimestamp()
        };
        client.publish(statusTopic, JSON.stringify(heartbeatPayload));
        console.log(`[Front_Desk_01] 💓 发送心跳包 (运行时长: ${uptimeSeconds}s, 信号: ${signalStrength}dBm)`);

    }, 30000); // 前台端每 30 秒发一次心跳
});

client.on('message', (topic, message) => {
    if (topic !== 'hotel/device/command/result') return;
    try {
        const result = JSON.parse(message.toString());
        console.log(`[Front_Desk_01] 📩 收到回执: dev=${result.device_id}, cmd=${result.command_type}, status=${result.status}`);
    } catch (e) {
        console.error(`[Front_Desk_01] ❌ 回执解析失败: ${message.toString()}`);
    }
});

client.on('error', (err) => {
    console.error(`[Front_Desk_01] ❌ MQTT 连接错误:`, err);
});
