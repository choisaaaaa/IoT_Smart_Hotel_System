# 硬件概念闭环与实机联调 TODO 计划 (Phase 3)

> **目标**：将当前零散的组件库与架构设计，缝合为能够在电脑上“空跑”的完整 IoT 固件产品，实现“仅待烧录”的巅峰状态。

## 1. 缝合三端 `main.c` (业务逻辑干跑)
- [ ] **客房端 (Room Terminal)**：接入 `hal_actuators` 与 `hal_interactive`，实现 MQTT 指令解析控制继电器，按键按下触发报警上报。
- [ ] **前台端 (Front Desk)**：接入 `hal_interactive`，实现按键消音/广播的 MQTT 消息发送。
- [ ] **楼控端 (Floor Controller)**：接入 `hal_interactive`，实现复位按键检测与状态上报。

## 2. 引入 FreeRTOS 任务隔离 (并发防撞)
- [ ] **按键轮询任务 (`button_poll_task`)**：独立线程，每 50ms 轮询一次按键状态，带简单软件去抖。
- [ ] **传感器采集任务 (`sensor_poll_task`)**：独立线程，定时读取温湿度/烟雾/雷达，打包 cJSON 上报。
- [ ] **音频处理任务 (`audio_task`)**：独立线程，挂起等待唤醒，处理 I2S 录音与播放。

## 3. 网络容灾与状态机 (断线重连)
- [ ] **WiFi 断线重连机制**：在 `service_network` 中增加自动重试逻辑。
- [ ] **MQTT 退避重连机制**：在 `service_mqtt` 中增加指数退避重连。
- [ ] **离线降级模式**：客房端在断网时，依然允许本地刷卡开门或物理按键开灯。

## 4. 彻底消灭硬编码 (NVS 存储)
- [ ] **NVS 配置读取**：系统启动时优先从 NVS 读取 WiFi SSID/Password 和 MQTT Broker URI。
- [ ] **默认后备机制**：若 NVS 为空，再回退使用 `global_config.h` 中的默认值。

## 5. 本地 Node.js 脚本联调 (终极验证)
- [ ] **搭建本地 MQTT Broker**：使用 Aedes 或 Mosquitto。
- [ ] **编写 Mock Server 脚本**：模拟后端下发 `{"cmd":"open_light"}` 等指令。
- [ ] **ESP-IDF 本地编译运行**：在电脑终端运行固件，观察与 Node.js 脚本的真实 JSON 交互日志流。
