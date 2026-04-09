# 智慧酒店硬件组 - 核心组件池 (Common Components) 说明

## 1. 架构定位与设计理念

本目录（`common_components`）存放跨终端复用、高内聚、低耦合的底层硬件抽象层（HAL）与基础服务组件（Services）。
本系统中的 **客房端 (Room Terminal)**、**前台端 (Front Desk)** 以及 **楼控端 (Floor Controller)** 均共享引用本组件池。

**核心设计理念：接口封装，底层屏蔽**。
业务研发人员无需关注底层 GPIO 寄存器状态、I2C/SPI 协议时序以及 MQTT 网络底层握手过程。只需在 `main.c` 中 `#include` 对应头文件并调用高级 API，即可完成硬件控制与业务上报。此设计旨在提升全局协同开发效率。

> **接入与调用规范：**
> 请参阅 [《核心组件池 (Common Components) 使用教程》](./USAGE_TUTORIAL.md) 获取具体配置与代码调用示例。

---

## 2. Mock (模拟) 开发声明与切换规范

鉴于项目目前可能处于无硬件联调期，本目录下的所有 `.c` 源文件均原生支持 **Mock（模拟）** 实现模式：
- **上层接口 (`.h`) 具备稳定性**：业务层代码可直接调用相关 API，无需评估后续硬件接入导致的重构风险。
- **底层实现 (`.c`) 为模拟状态**：当前涉及底层总线的操作暂通过 `ESP_LOGI` 输出虚拟日志，或返回模拟的合法数据（如传感器预设数值、预定义房卡 UID）。

> **硬件对接规范**：
> 在物理硬件交付后，底层驱动开发人员**仅需补充本目录下 `.c` 文件中的 `TODO` 桩函数模块**（替换为真实的寄存器或总线操作）。
> **业务层代码 (`main.c`) 无需调整，重新编译即可切换至物理机运行环境。**

---

## 3. 核心模块与 API 手册

### 3.1 服务层 (Service 层) - 核心业务支撑
* **`service_mqtt` (网络通信核心)**
  * **依赖组件**: `mqtt` (已适配 ESP-IDF v6.0 独立组件库)
  * **核心 API**: `service_mqtt_start(uri, client_id)`, `service_mqtt_publish(topic, payload)`, `service_mqtt_subscribe(topic, cb)`
  * **功能**: 提供标准的 MQTT 报文收发网关接口，内置断线重连机制。
* **`service_network` (网络配置与持久化服务)**
  * **依赖组件**: `nvs_flash`, `freertos`
  * **核心 API**: `service_network_provisioning_start(cb)`, `service_network_read_nvs_string(key, out, len)`
  * **功能**: 封装 Web Captive Portal 强制配网逻辑及 NVS 存储提取接口（用于提取房号等持久化数据）。

### 3.2 硬件抽象层 (HAL 层) - 业务逻辑控制
* **`hal_actuators` (强电执行单元)**
  * **核心 API**: `hal_actuators_set_state(ACTUATOR_RELAY_CH4, true)`
  * **功能**: 屏蔽高低电平反转与光耦隔离逻辑，提供基于业务语义的灯光、门锁、窗帘控制接口。
* **`hal_sensors` (环境感知传感器)**
  * **核心 API**: `hal_sensors_read_all(&sensor_data_struct)`
  * **功能**: 封装 ADC 转换及单总线数据读取过程，统一返回标准化温湿度与空气质量结构体。
* **`hal_interactive` (声光交互与输入)**
  * **核心 API**: `hal_interactive_beep(count, duration)`, `hal_interactive_set_led_color(index, r, g, b)`
  * **功能**: 抽象 WS2812 协议及有源蜂鸣器时序，提供标准化的状态指示逻辑。
* **`hal_audio` (音频与对讲采集)**
  * **核心 API**: `hal_audio_record_chunk()`, `hal_audio_play_chunk()`
  * **功能**: 针对 I2S 麦克风及 DAC 音频模块进行抽象，内置 G.711 录音编码。
* **`hal_infrared` (红外控制)**
  * **核心 API**: `hal_infrared_send_ac_command(brand, temp)`
  * **功能**: 基于 RMT 模块抽象红外载波发射逻辑，业务层直接传入温度与品牌枚举变量。

### 3.3 驱动层 (Driver 层) - 底层外设通信
* **`driver_rc522` (射频鉴权 RFID)**
  * **核心 API**: `driver_rc522_init()`, `driver_rc522_read_sector(sector, key, out_data)`
  * **功能**: 封装底层 SPI/I2C 通信指令。基于扇区密钥加密读取机制设计，规避纯 UID 模式的安全漏洞。
* **`driver_oled` (本地显示驱动)**
  * **核心 API**: `driver_oled_show_text_line(line, text)`
  * **功能**: 简化 I2C OLED 屏幕驱动流程。业务层仅需指定行号与字符文本，底层自动完成字模映射与像素换算。

#### 已登记驱动清单（按分层目录 `drivers/`）

- 执行/交互：`driver_sg90`、`driver_relay`、`driver_buzzer_active`、`driver_rgb_led`、`driver_ec11`
- 传感采集：`driver_dht11`、`driver_mq2`、`driver_ldr`、`driver_ntc`、`driver_potentiometer`、`driver_rd03_simple`、`driver_rd03_uart`
- 通信与存储：`driver_rc522`、`driver_w25q64`
- 显示与红外：`driver_oled`、`driver_ir_tx`、`driver_ir_rx`
- 音频相关：`driver_inmp441`、`driver_lmd2718_mic`、`driver_ns4168`、`driver_pam8403`

> 注：音频链路建议主线为 **LMD2718 + NS4168**；`INMP441`、`PAM8403` 保留为兼容/备选。