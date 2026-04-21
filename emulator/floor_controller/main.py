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
        self.device_id = "floor_03"
        self.floor_id_var = tk.StringVar(value="03")

        self.light_on = False
        self.is_broadcasting = False
        self.is_alarm = False

        self._stop_sensors = threading.Event()

        super().__init__(
            root=root,
            title=f"智慧酒店 - 楼控节点仿真器",
            device_id=self.device_id,
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

        self._create_card(self.biz_frame, "紧急安全警报系统").pack(fill=tk.BOTH, expand=True)
        safe_body = self.last_card_body

        self.alarm_btn = tk.Button(safe_body, text="🛑 模拟触发全楼层消防报警", font=("Arial", 12, "bold"),
                                  bg=self.colors['danger'], fg="white", pady=20,
                                  command=self._trigger_alarm, relief=tk.RAISED, cursor="hand2")
        self.alarm_btn.pack(fill=tk.X, pady=10)

        tk.Button(safe_body, text="手动复位报警系统", command=self._reset_alarm,
                  bg="#595959", fg="white", font=("Arial", 10), relief=tk.FLAT, pady=10).pack(fill=tk.X, pady=5)

    def _sensor_loop(self):
        while not self._stop_sensors.is_set():
            if self.mqtt_client and self.connected:
                temp = round(random.uniform(22, 26), 1)
                humi = random.randint(40, 60)
                smoke = random.randint(0, 30)
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
        if self.mqtt_client and self.connected:
            self.mqtt_client.publish_security_event("fire_alarm", level="critical", event_data={
                "floor_id": self.floor_id_var.get(),
                "type": "fire_alarm",
                "message": f"第{self.floor_id_var.get()}层消防报警触发"
            })

    def _reset_alarm(self):
        self.is_alarm = False
        self.alarm_btn.config(text="🛑 模拟触发全楼层消防报警", bg=self.colors['danger'])
        self._log("警报已人工复位")

    def _on_connected(self):
        cmd_topic = f"{TOPIC_DEVICE_COMMAND_PREFIX}/floor/{self.device_id}"
        self.mqtt_client.subscribe(cmd_topic)
        self._log(f"已订阅楼控指令主题: {cmd_topic}")

        self._register_command_handlers()

        self._stop_sensors.clear()
        threading.Thread(target=self._sensor_loop, daemon=True).start()
        self._log("传感器数据上报已启动(30秒间隔)")

    def _register_command_handlers(self):
        self.mqtt_client.register_command_handler(f"{CMD_LIGHT}:{CMD_VAL_ON}", self._handle_light_on)
        self.mqtt_client.register_command_handler(f"{CMD_LIGHT}:{CMD_VAL_OFF}", self._handle_light_off)
        self.mqtt_client.register_command_handler(CMD_BROADCAST_START, self._handle_broadcast_start)
        self.mqtt_client.register_command_handler(CMD_BROADCAST_STOP, self._handle_broadcast_stop)
        self.mqtt_client.register_command_handler(CMD_FLOOR_RESET, self._handle_floor_reset)

    def _handle_light_on(self, data):
        self.root.after(0, lambda: self._toggle_light(from_cloud=True, turn_on=True))
        return True

    def _handle_light_off(self, data):
        self.root.after(0, lambda: self._toggle_light(from_cloud=True, turn_on=False))
        return True

    def _handle_broadcast_start(self, data):
        self.is_broadcasting = True
        self.root.after(0, lambda: self.bc_status.config(text="● 正在播放...", fg=self.colors['danger']))
        self._log("接收到云端广播指令：正在全楼层播放...")
        return True

    def _handle_broadcast_stop(self, data):
        self.is_broadcasting = False
        self.root.after(0, lambda: self.bc_status.config(text="● 就绪", fg=self.colors['text_secondary']))
        self._log("广播已停止")
        return True

    def _handle_floor_reset(self, data):
        self._reset_alarm()
        self._toggle_light(from_cloud=True, turn_on=False)
        self.is_broadcasting = False
        self.root.after(0, lambda: self.bc_status.config(text="● 就绪", fg=self.colors['text_secondary']))
        self._log("楼层已复位")
        return True

    def _on_mqtt_message(self, topic, payload):
        super()._on_mqtt_message(topic, payload)
        try:
            data = json.loads(payload) if isinstance(payload, str) else payload
            cmd_type = data.get('command_type', '')
            cmd_value = data.get('command_value', '')
            self._log(f"消息回调: topic={topic} cmd={cmd_type} val={cmd_value}")
        except Exception as e:
            self._log(f"处理消息异常: {e}", "ERROR")


if __name__ == "__main__":
    root = tk.Tk()
    app = FloorControllerEmulator(root)
    app.run()
