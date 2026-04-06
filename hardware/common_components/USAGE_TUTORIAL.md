# 智慧酒店硬件组 - 核心组件池 (Common Components) 使用教程

对于前台端、楼控端等其他终端模块的开发人员，若需复用组件库提供的基础服务（如门禁鉴权、MQTT 通信、传感器读取等），请按以下流程进行工程配置与接口调用：

---

## 1. 声明公共组件目录路径

在目标项目级配置环境（例如 `hardware/front_desk_terminal/CMakeLists.txt`）中，**必须在 `project()` 声明前**，将公共组件目录添加至编译系统环境变量：

```cmake
cmake_minimum_required(VERSION 3.16)

# 将外部公共组件池路径映射至编译配置中
set(EXTRA_COMPONENT_DIRS "../common_components")

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(front_desk_terminal) # 当前工程名称
```

---

## 2. 按需引入业务依赖模块

在主业务代码模块的配置层（例如 `hardware/front_desk_terminal/main/CMakeLists.txt`）内，根据功能场景填写 `REQUIRES` 参数。**按需引入机制可有效优化最终固件体积**。

```cmake
# 根据前台端需求示例，配置射频读取、MQTT 通信与声光交互依赖
idf_component_register(SRCS "main.c"
                    INCLUDE_DIRS "."
                    REQUIRES driver_rc522 service_mqtt hal_interactive)
```

---

## 3. 业务代码引入与接口调用

完成上述配置后，在应用层 `main.c` 文件中直接包含相应的头文件并调用系统级接口，无需操作底层 GPIO 或通信寄存器：

```c
#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "hal_interactive.h"
#include "service_mqtt.h"

void app_main(void) {
    // 初始化并建立 MQTT 服务器连接 (服务层抽象)
    // 内部集成了 WiFi 接入、断线重连与 MQTT 鉴权协议
    service_mqtt_start("mqtt://hotel-backend-ip:1883", "front_desk_01");
    
    // 执行硬件级别声光提示 (HAL 层抽象，隔离 GPIO 操作)
    hal_interactive_beep(1, 200);                  // 设置蜂鸣器单次短鸣，持续 200ms
    hal_interactive_set_led_color(0, 0, 255, 0);   // 将 0 号 LED 节点设为标准绿色
    
    // 向后端服务发布标准协议 JSON 报文
    service_mqtt_publish("hotel/frontdesk/status", "{\"status\":\"online\"}");
}
```

> **参考说明**：有关公共组件库的具体功能描述及可用接口名录，请参阅 [《核心组件池 (Common Components) 说明》](./README.md)。

---

## 4. 跨平台/非 ESP-IDF 环境接入指南

本公共组件库采用 ESP-IDF 原生的 CMake 构建系统与 FreeRTOS 调度框架编写。对于不使用原生 ESP-IDF 开发环境的开发人员，请根据自身所用的 IDE 采取以下兼容策略：

### 方案 A：使用 PlatformIO 环境（推荐兼容方案）
PlatformIO 对 ESP-IDF 具有良好的原生支持，支持双框架混编。开发人员可以在不放弃原有 Arduino 业务代码习惯的前提下，无缝调用本组件库。

1. 修改工程目录下的 `platformio.ini`，将框架指定为 `espidf` 或开启双框架混编：
   ```ini
   [env:esp32dev]
   platform = espressif32
   board = esp32dev
   ; 启用双框架混编：底层用 ESP-IDF 构建组件库，顶层继续用 Arduino 语法
   framework = arduino, espidf 
   ```
2. 在工程根目录下创建/修改 `CMakeLists.txt`，按照本文 **第 1 步与第 2 步** 引入组件目录与依赖。
3. 编译时，PlatformIO 将自动利用 CMake 体系编译公共组件库，业务代码中可毫无阻碍地 `#include` 并调用 `service_mqtt_publish()` 等高级接口。

### 方案 B：使用纯 Arduino IDE 环境（不推荐，存在降级风险）
由于官方 Arduino IDE 不支持 CMake 依赖管理体系，且无法自动解析包含 `idf_component.yml` 的外部依赖，**无法实现一键复用**。

若开发人员必须坚持使用 Arduino IDE：
1. **手动移植**：需将 `common_components` 下对应的 `.c` 与 `.h` 文件手动复制或打包为 ZIP 库，导入至 Arduino 工程内。
2. **依赖平替**：因 Arduino 环境下缺失部分 ESP-IDF 专属底层 API 与官方组件（如 `espressif/mqtt`），开发人员需自行寻找并替换等效的 Arduino 库（如使用 `PubSubClient` 平替 MQTT 服务），且需自行负责这些替代库的稳定性测试与维护工作。

> **架构组建议**：为确保网络层（如 MQTT 鉴权、断线重连）与门禁鉴权层的极高稳定性，强烈建议涉及相关业务模块的开发人员统一采用原生 ESP-IDF 或 PlatformIO 混编架构。