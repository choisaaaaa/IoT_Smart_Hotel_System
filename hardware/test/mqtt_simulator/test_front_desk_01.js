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

    // 3. 定时发送心跳保活数据 (规范 6.1.2)
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

client.on('error', (err) => {
    console.error(`[Front_Desk_01] ❌ MQTT 连接错误:`, err);
});
