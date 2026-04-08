# 🛠️ 硬件组通讯规范适配 TODO List (Phase 1.5)

本文档基于《硬件层通讯规范.md》（v1.1.0）梳理，旨在指导硬件组在无实体开发板的“真空期”进行纯软件层的格式规范化与通讯对齐（SIL 软件在环联调）。

> **当前首要目标：** 打通设备与云端双向软总线，确保后端能正确解析上报数据，设备能正确提取下发指令。

---

## 阶段一：基础设施层适配 (Infrastructure)

- [x] **配置宏全局对齐**
  - **任务**：检查并确保所有终端 `main.c` 中的 MQTT Broker 地址均引用 `global_config.h` 中的 `GLOBAL_MQTT_BROKER_URI`。
  - **验收**：彻底消除硬编码 IP。
- [x] **引入时间同步机制 (NTP/SNTP)**
  - **任务**：在 `service_network` 配网成功后，新增获取网络真实时间的逻辑。封装形如 `get_iso8601_timestamp()` 的接口。
  - **验收**：满足后端所有 JSON 报文强制要求 `timestamp` 的标准（格式: `YYYY-MM-DDTHH:mm:ss.sssZ`）。
- [x] **引入 JSON 序列化库**
  - **任务**：在 `common_components` 或业务工程的 CMake 配置中统一引入 `cJSON` 库（ESP-IDF 原生支持）。
  - **验收**：在后续报文组装中全面替换易出错的 `snprintf` 字符串硬拼接方式。

---

## 阶段二：客房端业务流规范化 (Room Terminal)

- [x] **Client ID 规范化**
  - **任务**：连接 MQTT 时，Client ID 严格使用 `room_{房间号}` 格式（如 `room_301`）。
- [x] **设备上线注册流 (REST API/MQTT)**
  - **任务**：启动后，按照规范 6.1.1 组装包含硬件版本、MAC 地址等详尽信息的 JSON。
  - **任务**：通过 `hotel/device/status/room/room_{房间号}` Topic 发送上线状态 (`"status": "online"`)。
- [x] **心跳与状态保活**
  - **任务**：设计 FreeRTOS 定时任务，定期按照规范 6.1.2 上报包含内存占用、WiFi 信号等信息的设备心跳 JSON。
- [x] **环境传感器数据上报改造**
  - **任务**：废弃旧的温湿度合并上报逻辑。
  - **任务**：按 4.2.2 规范拆分 Topic：温度发往 `hotel/device/data/temperature/room_{id}`，湿度发往 `hotel/device/data/humidity/room_{id}`。
  - **验收**：JSON 严格包含 `sensor_type`、`value`、`unit` 和 `timestamp` 四个字段。
- [x] **安防事件（门禁/SOS）上报改造**
  - **任务**：将开门事件发往统一安防 Topic：`hotel/security/event`。
  - **验收**：JSON 结构必须嵌套 `event_data` 对象，且明确事件级别（`"level": "info"` 或 `"critical"`）。
- [x] **下发指令拆包与回执响应**
  - **任务**：订阅 `hotel/device/command/room/room_{id}`。
  - **任务**：解析云端指令 JSON，提取 `command_id` 和 `command_type`（如 `light_on`, `air_off`）。
  - **核心验收**：执行动作后，必须向 `hotel/device/command/result` 发送执行结果回执（含 `status: success/failed`）。

---

## 阶段三：前台管理端业务流规范化 (Front Desk Terminal)

- [x] **Client ID 规范化**
  - **任务**：严格使用 `front_desk_{编号}` 格式（如 `front_desk_01`）。
- [x] **基础生命周期报文**
  - **任务**：实现合规的上线注册报文、心跳保活报文及离线遗嘱消息 (Will Message)。
- [x] **发卡事件上报预研**
  - **任务**：梳理前台 RC522 模块读写房卡成功后，向后端同步发卡/退卡状态的专有 JSON 结构（需与后端开发人员协商具体指令类型并补充到通讯规范中）。

---

## 阶段四：楼控端业务流规范化 (Floor Controller)

- [x] **Client ID 规范化**
  - **任务**：严格使用 `floor_{编号}` 格式（如 `floor_01`）。
- [x] **公共区域传感器上报**
  - **任务**：按照客房端的传感器规范，建立走廊温湿度、光照传感器的数据定频上报逻辑。
- [x] **群控指令解析**
  - **任务**：实现对楼层公共照明（如 `command_type: light_on`, `command_value: {"floor_id": 3}`）的批量控制解析与回执响应逻辑。
