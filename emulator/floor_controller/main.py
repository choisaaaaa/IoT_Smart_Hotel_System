"""
楼控节点仿真器 - 主程序
"""
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

import tkinter as tk
from tkinter import ttk, messagebox
import random
import threading
import time
import json
from datetime import datetime
from common.device_base import BaseDeviceEmulator
from common.config import (
    CMD_LIGHT, CMD_AIR, CMD_CURTAIN, CMD_DOOR,
    CMD_BROADCAST_START, CMD_BROADCAST_STOP, CMD_FLOOR_RESET,
    CMD_VAL_ON, CMD_VAL_OFF, CMD_VAL_OPEN, CMD_VAL_CLOSE,
    SENSOR_TEMPERATURE, SENSOR_HUMIDITY, SENSOR_LIGHT, SENSOR_SMOKE,
    TOPIC_DEVICE_COMMAND_PREFIX
)


class FloorControllerEmulator(BaseDeviceEmulator):
    def __init__(self, root):
        self.floor_id_var = tk.StringVar(value="")

        self.light_on = False
        self.is_broadcasting = False
        self.is_alarm = False
        self.led_status_colors = ["#52c41a"] * 5  # 5颗状态灯

        self._stop_sensors = threading.Event()
        self._alarm_beep_thread = None  # 报警蜂鸣器线程
        self._stop_alarm_beep = threading.Event()  # 停止蜂鸣器事件

        super().__init__(
            root=root,
            title=f"智慧酒店 - 楼控节点仿真器",
            device_id=None, # 让基类自动生成或从配置加载唯一物理ID
            device_type="floor",
            width=850,
            height=750
        )

        self._sync_position()

    def _sync_position(self):
        if self.area_var.get():
            area = self.area_var.get()
            import re
            match = re.search(r'\d+', area)
            if match:
                self.floor_id_var.set(match.group())
            self._log(f"已同步位置信息: {area}")

    def _on_config_updated(self):
        self._sync_position()
        if hasattr(self, 'pos_label'):
            self.pos_label.config(text=f"{self.area_var.get() or '公共区域'}")
        self._log("收到云端配置更新，已重载界面")

    def _init_biz_ui(self):
        self._create_card(self.biz_frame, "楼层实时概览").pack(fill=tk.X, pady=(0, 20))
        status_body = self.last_card_body

        info_f = tk.Frame(status_body, bg="white")
        info_f.pack(fill=tk.X)
        tk.Label(info_f, text="📍 当前位置:", font=("Arial", 10), bg="white", fg=self.colors['text_secondary']).pack(side=tk.LEFT)

        display_pos = self.area_var.get() or f"第 {self.floor_id_var.get()} 层公共区域"
        self.pos_label = tk.Label(info_f, text=display_pos,
                                 font=("Arial", 12, "bold"), bg="white", fg=self.colors['primary'])
        self.pos_label.pack(side=tk.LEFT, padx=15)

        self._create_card(self.biz_frame, "环境传感器实时监控").pack(fill=tk.X, pady=(0, 20))
        sensor_body = self.last_card_body

        self.temp_var = tk.StringVar(value="24.5℃")
        self.humi_var = tk.StringVar(value="50%")
        self.smoke_var = tk.StringVar(value="0")
        self.light_var = tk.StringVar(value="300lx")

        s_grid = tk.Frame(sensor_body, bg="white")
        s_grid.pack(fill=tk.X)

        def create_sensor_item(parent, label, var, color):
            f = tk.Frame(parent, bg="white", padx=10, pady=10)
            f.pack(side=tk.LEFT, expand=True)
            tk.Label(f, text=label, font=("Arial", 10), bg="white", fg=self.colors['text_secondary']).pack()
            tk.Label(f, textvariable=var, font=("Arial", 20, "bold"), bg="white", fg=color).pack(pady=5)
            return f

        create_sensor_item(s_grid, "环境温度", self.temp_var, self.colors['danger'])
        create_sensor_item(s_grid, "相对湿度", self.humi_var, self.colors['primary'])
        create_sensor_item(s_grid, "烟雾浓度", self.smoke_var, self.colors['warning'])
        create_sensor_item(s_grid, "光照强度", self.light_var, self.colors['success'])

        self._create_card(self.biz_frame, "楼层设施模拟控制").pack(fill=tk.X, pady=(0, 20))
        pub_body = self.last_card_body

        btn_style = {"width": 12, "relief": tk.FLAT, "font": ("Arial", 10, "bold"), "pady": 10}

        light_f = tk.Frame(pub_body, bg="white")
        light_f.pack(fill=tk.X, pady=8)
        tk.Label(light_f, text="🔅 走廊照明系统控制:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        self.light_btn = tk.Button(light_f, text="OFF", bg="#595959", fg="white",
                                  command=self._toggle_light, **btn_style)
        self.light_btn.pack(side=tk.RIGHT)

        bc_f = tk.Frame(pub_body, bg="white")
        bc_f.pack(fill=tk.X, pady=8)
        tk.Label(bc_f, text="📢 应急语音广播系统:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        self.bc_status = tk.Label(bc_f, text="● 系统就绪",
                                 font=("Arial", 10, "bold"), fg=self.colors['text_secondary'], bg="white")
        self.bc_status.pack(side=tk.RIGHT, padx=15)

        self._create_card(self.biz_frame, "硬件交互外设模拟 (RGB LED & Buzzer)").pack(fill=tk.X, pady=(0, 20))
        hw_body = self.last_card_body

        led_f = tk.Frame(hw_body, bg="white")
        led_f.pack(side=tk.LEFT, padx=10)
        self.led_canvas = tk.Canvas(led_f, width=250, height=60, bg="white", highlightthickness=0)
        self.led_canvas.pack()
        self._update_led_status()
        tk.Label(led_f, text="RGB 状态指示灯 (WS2812B x 5)", font=("Arial", 9), bg="white", fg=self.colors['text_secondary']).pack()

        buzzer_f = tk.Frame(hw_body, bg="white")
        buzzer_f.pack(side=tk.RIGHT, expand=True, fill=tk.X, padx=20)
        tk.Button(buzzer_f, text="🔊 蜂鸣器测试", bg=self.colors['primary'], fg="white",
                  command=lambda: self._beep(1), relief=tk.FLAT, font=("Arial", 9, "bold")).pack(fill=tk.X)

        self._create_card(self.biz_frame, "紧急安全警报系统").pack(fill=tk.BOTH, expand=True)
        safe_body = self.last_card_body

        self.alarm_btn = tk.Button(safe_body, text="🛑 模拟触发全楼层消防报警", font=("Arial", 12, "bold"),
                                  bg=self.colors['danger'], fg="white", pady=20,
                                  command=self._trigger_alarm, relief=tk.RAISED, cursor="hand2")
        self.alarm_btn.pack(fill=tk.X, pady=10)

        tk.Button(safe_body, text="手动复位报警系统", command=self._reset_alarm,
                  bg="#595959", fg="white", font=("Arial", 10), relief=tk.FLAT, pady=10).pack(fill=tk.X, pady=5)

    def _update_led_status(self):
        self.led_canvas.delete("all")
        for i in range(5):
            x = 30 + i * 45
            y = 30
            color = self.led_status_colors[i]
            self.led_canvas.create_oval(x-15, y-15, x+15, y+15, fill=color, outline="#444", width=2)
            if color != "#52c41a":
                self.led_canvas.create_oval(x-20, y-20, x+20, y+20, outline=color, width=1)

    def _beep(self, count=1):
        self._play_beep(1000 if count == 1 else 2000, 200)
        self.led_status_colors[4] = "#ffff00"
        self._update_led_status()
        self.root.after(200, lambda: self._reset_led_status())

        if count > 1:
            for i in range(1, count):
                self.root.after(i * 400, lambda: self._play_beep(1000 if count == 1 else 2000, 200))
                self.root.after(i * 400, lambda: self._set_led_color(4, "#ffff00"))
                self.root.after(i * 400 + 200, lambda: self._reset_led_status())

    def _set_led_color(self, idx, color):
        self.led_status_colors[idx] = color
        self._update_led_status()

    def _reset_led_status(self):
        if self.is_alarm:
            self.led_status_colors = ["#ff4d4f"] * 5
        elif self.is_broadcasting:
            self.led_status_colors = ["#1890ff"] * 5
        else:
            self.led_status_colors = ["#52c41a"] * 5
        self._update_led_status()

    def _sensor_loop(self):
        while not self._stop_sensors.is_set():
            if self.mqtt_client and self.connected:
                temp = round(random.uniform(22, 26), 1)
                humi = random.randint(40, 60)
                smoke = random.randint(0, 30)
                # 随机触发烟雾报警 (0.5% 概率)
                if random.random() < 0.005:
                    smoke = random.randint(100, 300)

                light_val = random.randint(100, 500)

                self.root.after(0, lambda: self.temp_var.set(f"{temp}℃"))
                self.root.after(0, lambda: self.humi_var.set(f"{humi}%"))
                self.root.after(0, lambda: self.smoke_var.set(f"{smoke}"))
                self.root.after(0, lambda: self.light_var.set(f"{light_val}lx"))

                self.mqtt_client.publish_sensor_data(SENSOR_TEMPERATURE, temp, "℃")
                self.mqtt_client.publish_sensor_data(SENSOR_HUMIDITY, humi, "%")
                self.mqtt_client.publish_sensor_data(SENSOR_SMOKE, smoke, "ppm")
                self.mqtt_client.publish_sensor_data(SENSOR_LIGHT, light_val, "lx")

                self._log(f"传感器数据已上报: 温度={temp}℃ 湿度={humi}% 烟雾={smoke}ppm 光照={light_val}lx")

                # 烟雾报警逻辑
                if smoke > 80 and not self.is_alarm:
                    self.root.after(0, self._trigger_alarm)
            time.sleep(30)

    def _toggle_light(self, from_cloud=False, turn_on=None):
        if turn_on is not None:
            self.light_on = turn_on
        else:
            self.light_on = not self.light_on
        status = "ON" if self.light_on else "OFF"
        color = self.colors['success'] if self.light_on else "#595959"
        self.light_btn.config(text=status, bg=color)
        self._log(f"{'[云端]' if from_cloud else '[本地]'} 楼层照明已切换至 {status}")

    def _trigger_alarm(self):
        self.is_alarm = True
        self.alarm_btn.config(text="🔥 警报生效中...", bg="#000000")
        self._log("紧急警报已触发！正在通知中控室...", "ERROR")
        self._beep(3)
        self.led_status_colors = ["#ff4d4f"] * 5
        self._update_led_status()
        
        # 启动持续蜂鸣器（5秒后）
        self._start_continuous_beep()

        if self.mqtt_client and self.connected:
            self.mqtt_client.publish_security_event("fire_alarm", level="critical", event_data={
                "floor_id": self.floor_id_var.get(),
                "type": "fire_alarm",
                "message": f"第{self.floor_id_var.get()}层消防报警触发"
            })

    def _start_continuous_beep(self):
        """启动持续蜂鸣器（5秒后开始持续响）"""
        def continuous_beep():
            # 等待5秒
            time.sleep(5)
            
            # 如果还在报警状态，开始持续蜂鸣
            while self.is_alarm and not self._stop_alarm_beep.is_set():
                try:
                    import winsound
                    winsound.Beep(2000, 500)  # 响500ms
                    time.sleep(0.2)  # 间隔200ms
                except Exception:
                    time.sleep(1)
        
        # 停止之前的蜂鸣器线程
        self._stop_alarm_beep.set()
        if self._alarm_beep_thread and self._alarm_beep_thread.is_alive():
            self._alarm_beep_thread.join(timeout=1)
        
        # 重置停止事件并启动新线程
        self._stop_alarm_beep.clear()
        self._alarm_beep_thread = threading.Thread(target=continuous_beep, daemon=True)
        self._alarm_beep_thread.start()

    def _stop_continuous_beep(self):
        """停止持续蜂鸣器"""
        self._stop_alarm_beep.set()
        if self._alarm_beep_thread and self._alarm_beep_thread.is_alive():
            self._alarm_beep_thread.join(timeout=1)

    def _reset_alarm(self):
        self.is_alarm = False
        self.alarm_btn.config(text="🛑 模拟触发全楼层消防报警", bg=self.colors['danger'])
        self._log("警报已人工复位")
        self._reset_led_status()
        self._stop_continuous_beep()  # 停止持续蜂鸣器

    def _on_security_event_from_others(self, topic, payload):
        """处理来自其他设备的安防事件，实现联动报警"""
        try:
            import json
            data = json.loads(payload) if isinstance(payload, str) else payload
            event_type = data.get('event_type', '')
            event_data = data.get('data', {})
            device_id = data.get('device_id', '')
            
            # 忽略自己触发的报警
            if device_id == self.unique_device_id:
                return
            
            # 处理消防报警联动
            if event_type == 'fire_alarm':
                floor_id = event_data.get('floor_id', '')
                room_id = event_data.get('room_id', '')
                
                # 如果报警来自同一楼层，或者没有指定楼层（全楼报警），则联动
                my_floor = self.floor_id_var.get()
                if not floor_id or floor_id == my_floor:
                    self._log(f"🔥 收到联动报警: 设备 {device_id} 触发消防报警", "ERROR")
                    self._trigger_alarm_from_other(device_id, room_id or floor_id)
            
            # 处理SOS报警联动
            elif event_type == 'sos_alarm':
                self._log(f"🆘 收到联动报警: 设备 {device_id} 触发SOS报警", "ERROR")
                self._trigger_alarm_from_other(device_id, event_data.get('room_id', 'unknown'))
                
        except Exception as e:
            self._log(f"处理联动报警事件失败: {e}", "ERROR")

    def _trigger_alarm_from_other(self, source_device, location):
        """由其他设备触发的联动报警"""
        if self.is_alarm:
            return  # 已经在报警状态，不再重复触发
            
        self.is_alarm = True
        self.alarm_btn.config(text=f"🔥 联动报警: {location}", bg="#000000")
        self._log(f"联动报警生效！来源: {source_device}, 位置: {location}", "ERROR")
        
        # 蜂鸣器响3声
        self._beep(3)
        
        # LED全部变红
        self.led_status_colors = ["#ff4d4f"] * 5
        self._update_led_status()
        
        # 上报联动报警事件
        if self.mqtt_client and self.connected:
            self.mqtt_client.publish_security_event("fire_alarm_linked", level="critical", event_data={
                "floor_id": self.floor_id_var.get(),
                "source_device": source_device,
                "location": location,
                "type": "linked_fire_alarm",
                "message": f"第{self.floor_id_var.get()}层收到联动消防报警"
            })

    def _on_connected(self):
        # 使用物理 ID (unique_device_id) 进行订阅，确保与云端标识一致
        cmd_topic = f"{TOPIC_DEVICE_COMMAND_PREFIX}/floor/{self.unique_device_id}"
        self.mqtt_client.subscribe(cmd_topic)
        self._log(f"已订阅楼控指令主题: {cmd_topic}")

        # 订阅全局楼控指令主题（用于接收全局消警等指令）
        all_cmd_topic = f"{TOPIC_DEVICE_COMMAND_PREFIX}/floor/all"
        self.mqtt_client.subscribe(all_cmd_topic)
        self._log(f"已订阅全局楼控指令主题: {all_cmd_topic}")

        # 订阅全局安防事件主题，实现联动报警
        self.mqtt_client.subscribe("hotel/security/event", self._on_security_event_from_others)
        self._log("已订阅全局安防事件主题: hotel/security/event")

        self._register_command_handlers()

        self._stop_sensors.clear()
        threading.Thread(target=self._sensor_loop, daemon=True).start()
        self._log("传感器数据上报已启动(30秒间隔)")

    def _register_command_handlers(self):
        # 注册照明控制指令
        self.mqtt_client.register_command_handler(f"{CMD_LIGHT}:{CMD_VAL_ON}", self._handle_light_on)
        self.mqtt_client.register_command_handler(f"{CMD_LIGHT}:{CMD_VAL_OFF}", self._handle_light_off)
        self.mqtt_client.register_command_handler(CMD_LIGHT, self._handle_light_command)
        # 注册广播控制指令
        self.mqtt_client.register_command_handler(CMD_BROADCAST_START, self._handle_broadcast_start)
        self.mqtt_client.register_command_handler(CMD_BROADCAST_STOP, self._handle_broadcast_stop)
        # 注册楼层复位指令
        self.mqtt_client.register_command_handler(CMD_FLOOR_RESET, self._handle_floor_reset)
        # 注册安防相关指令
        self.mqtt_client.register_command_handler("alarm_ack", self._handle_alarm_ack)
        self.mqtt_client.register_command_handler("alarm_reset", self._handle_alarm_reset)
        # 注册空调/窗帘控制指令
        self.mqtt_client.register_command_handler(CMD_AIR, self._handle_air_command)
        self.mqtt_client.register_command_handler(CMD_CURTAIN, self._handle_curtain_command)
        self._log("已注册所有楼控指令处理器")

    def _handle_light_on(self, data):
        self.root.after(0, lambda: self._toggle_light(from_cloud=True, turn_on=True))
        self._log("[Web指令] 照明开启")
        return True

    def _handle_light_off(self, data):
        self.root.after(0, lambda: self._toggle_light(from_cloud=True, turn_on=False))
        self._log("[Web指令] 照明关闭")
        return True

    def _handle_light_command(self, data):
        """处理通用灯光指令"""
        cmd_value = data.get('command_value', '')
        if cmd_value == CMD_VAL_ON or cmd_value == 'on':
            self.root.after(0, lambda: self._toggle_light(from_cloud=True, turn_on=True))
            self._log("[Web指令] 照明开启")
        elif cmd_value == CMD_VAL_OFF or cmd_value == 'off':
            self.root.after(0, lambda: self._toggle_light(from_cloud=True, turn_on=False))
            self._log("[Web指令] 照明关闭")
        return True

    def _handle_broadcast_start(self, data):
        self.is_broadcasting = True
        self.root.after(0, lambda: self.bc_status.config(text="● 正在播放...", fg=self.colors['danger']))
        self.led_status_colors = ["#1890ff"] * 5  # 蓝色表示广播中
        self.root.after(0, self._update_led_status)
        self._beep(1)
        self._log("[Web指令] 应急广播开始")
        return True

    def _handle_broadcast_stop(self, data):
        self.is_broadcasting = False
        self.root.after(0, lambda: self.bc_status.config(text="● 就绪", fg=self.colors['text_secondary']))
        self._reset_led_status()
        self._log("[Web指令] 应急广播停止")
        return True

    def _handle_floor_reset(self, data):
        self._reset_alarm()
        self._toggle_light(from_cloud=True, turn_on=False)
        self.is_broadcasting = False
        self.root.after(0, lambda: self.bc_status.config(text="● 就绪", fg=self.colors['text_secondary']))
        self._reset_led_status()
        self._beep(1)
        self._log("[Web指令] 楼层系统复位")
        return True

    def _handle_alarm_ack(self, data):
        """处理报警确认指令"""
        self._log("[Web指令] 报警已确认")
        self._beep(1)
        # LED变为黄色闪烁表示已确认但未复位
        self.led_status_colors = ["#faad14"] * 5
        self.root.after(0, self._update_led_status)
        return True

    def _handle_alarm_reset(self, data):
        """处理报警复位指令"""
        self._reset_alarm()
        self._log("[Web指令] 报警已复位")
        self._beep(1)
        return True

    def _handle_air_command(self, data):
        """处理空调控制指令"""
        cmd_value = data.get('command_value', '')
        self._log(f"[Web指令] 空调控制: {cmd_value}")
        return True

    def _handle_curtain_command(self, data):
        """处理窗帘控制指令"""
        cmd_value = data.get('command_value', '')
        self._log(f"[Web指令] 窗帘控制: {cmd_value}")
        return True

    def _on_mqtt_message(self, topic, payload):
        super()._on_mqtt_message(topic, payload)
        try:
            data = json.loads(payload) if isinstance(payload, str) else payload
            cmd_type = data.get('command_type', '')
            cmd_value = data.get('command_value', '')
            device_id = data.get('device_id', '')
            self._log(f"[MQTT消息] Topic: {topic}, Cmd: {cmd_type}, Value: {cmd_value}, Target: {device_id}")
            
            # 处理复合指令键值 (如 "light:on")
            if ':' in cmd_type and cmd_value == '':
                parts = cmd_type.split(':')
                if len(parts) == 2:
                    data['command_type'] = parts[0]
                    data['command_value'] = parts[1]
                    # 重新触发指令处理
                    composite_key = cmd_type
                    if composite_key in self.mqtt_client.command_handlers:
                        handler = self.mqtt_client.command_handlers[composite_key]
                        if handler:
                            handler(data)
        except Exception as e:
            self._log(f"处理消息异常: {e}", "ERROR")


if __name__ == "__main__":
    root = tk.Tk()
    app = FloorControllerEmulator(root)
    app.run()
