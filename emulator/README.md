# 智慧酒店硬件层仿真器

用于模拟智慧酒店物联网控制系统中的三个硬件终端：前台管理端、楼控节点、客房终端。

## 功能特性

### 前台管理端仿真器
- ✅ RFID卡开卡/验卡/刷卡模拟
- ✅ 刷卡联动客房门锁
- ✅ 广播呼叫/消音控制
- ✅ MQTT连接与心跳上报

### 楼控节点仿真器
- ✅ 温湿度光照传感器模拟（支持手动调节和自动波动）
- ✅ 走廊灯光控制
- ✅ 消防报警按钮
- ✅ 传感器数据定时上报（30秒）

### 客房终端仿真器
- ✅ OLED显示屏模拟
- ✅ 灯/空调/窗帘/门锁控制
- ✅ 4种场景模式（迎宾/阅读/夜灯/睡眠）
- ✅ 语音通话模拟
- ✅ SOS紧急呼叫
- ✅ 门锁8秒自动回锁
- ✅ 传感器数据定时上报（15秒）

## 安装依赖

```bash
pip install -r requirements.txt
```

依赖:
- paho-mqtt >= 1.6.0

## 运行方式

### 开发运行

```bash
# 运行前台管理端
cd front_desk
python main.py

# 运行楼控节点
cd floor_controller
python main.py

# 运行客房终端
cd room_terminal
python main.py
```

### 打包为exe

```bash
python build.py
```

打包完成后，在 `dist/` 目录下会生成三个独立的exe文件。

## 使用说明

1. **配置MQTT Broker**
   - 默认地址: `172.20.10.3:1883`
   - 可在界面中修改

2. **连接MQTT**
   - 点击"连接"按钮连接MQTT Broker
   - 连接成功后设备会自动发送上线状态

3. **操作设备**
   - 每个仿真器都有对应的操作面板
   - 操作会触发MQTT消息上报
   - 可以在日志窗口查看消息详情

4. **三端联动**
   - 前台刷卡 → 自动发送开锁指令到客房
   - 前台广播 → 客房接收来电

## MQTT主题

### 设备状态
- `hotel/device/status/front_desk/front_desk_01`
- `hotel/device/status/floor/floor_03`
- `hotel/device/status/room/room_301`

### 控制指令
- `hotel/device/command/front_desk/front_desk_01`
- `hotel/device/command/floor/floor_03`
- `hotel/device/command/room/room_301`

### 传感器数据
- `hotel/device/data/temperature/{device_id}`
- `hotel/device/data/humidity/{device_id}`
- `hotel/device/data/light/{device_id}`

### 其他
- `hotel/device/command/result` - 指令执行结果
- `hotel/security/event` - 安防事件

## 项目结构

```
emulator/
├── common/              # 公共模块
│   ├── mqtt_client.py   # MQTT客户端封装
│   ├── config.py        # 配置常量
│   ├── logger.py        # 日志系统
│   └── device_base.py   # 设备基类
├── front_desk/          # 前台管理端
│   └── main.py
├── floor_controller/    # 楼控节点
│   └── main.py
├── room_terminal/       # 客房终端
│   └── main.py
├── build.py             # 打包脚本
├── requirements.txt     # 依赖列表
└── README.md            # 使用说明
```

## 开发计划

- [x] 基础框架搭建
- [x] 前台管理端仿真器
- [x] 楼控节点仿真器
- [x] 客房终端仿真器
- [x] 打包脚本
- [ ] 多实例支持
- [ ] 自动化测试脚本
- [ ] Web远程控制界面

## 注意事项

1. 确保MQTT Broker已启动并可访问
2. 三个仿真器可以同时运行，模拟完整的三端交互
3. 打包后的exe文件可以独立运行，无需Python环境

## 作者

智慧酒店开发团队
