"""
楼控节点仿真器 - 主程序 (现代化美化版)
"""
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

import tkinter as tk
from tkinter import ttk, messagebox
import random
import threading
import time
from datetime import datetime
from common.device_base import BaseDeviceEmulator
from common.config import (
    CMD_LIGHT_ON, CMD_LIGHT_OFF,
    CMD_BROADCAST_START, CMD_BROADCAST_STOP, CMD_FLOOR_RESET
)

class FloorControllerEmulator(BaseDeviceEmulator):
    """楼控节点仿真器"""
    
    def __init__(self, root):
        self.device_id = "floor_03"
        self.floor_id_var = tk.StringVar(value="03")
        
        # 业务状态
        self.light_on = False
        self.is_broadcasting = False
        self.is_alarm = False
        
        super().__init__(
            root=root,
            title=f"智慧酒店 - 楼控节点仿真器 ({self.device_id})",
            device_id=self.device_id,
            device_type="floor",
            width=850,
            height=750
        )

        # 启动传感器模拟线程
        self._stop_sensors = threading.Event()
        threading.Thread(target=self._sensor_loop, daemon=True).start()

    def _init_biz_ui(self):
        """初始化楼控特有业务界面"""
        # 1. 楼层概览卡片
        self._create_card(self.biz_frame, "楼层实时概览").pack(fill=tk.X, pady=(0, 20))
        status_body = self.last_card_body
        
        info_f = tk.Frame(status_body, bg="white")
        info_f.pack(fill=tk.X)
        tk.Label(info_f, text="📍 当前位置:", font=("Arial", 10), bg="white", fg=self.colors['text_secondary']).pack(side=tk.LEFT)
        tk.Label(info_f, text=f"第 {self.floor_id_var.get()} 层公共区域", 
                 font=("Arial", 12, "bold"), bg="white", fg=self.colors['primary']).pack(side=tk.LEFT, padx=15)

        # 2. 传感器实时监控
        self._create_card(self.biz_frame, "环境传感器实时监控").pack(fill=tk.X, pady=(0, 20))
        sensor_body = self.last_card_body
        
        self.temp_var = tk.StringVar(value="24.5℃")
        self.humi_var = tk.StringVar(value="50%")
        self.aqi_var = tk.StringVar(value="良好")
        
        s_grid = tk.Frame(sensor_body, bg="white")
        s_grid.pack(fill=tk.X)
        
        # 统一传感器卡片样式
        def create_sensor_item(parent, label, var, color):
            f = tk.Frame(parent, bg="white", padx=10, pady=10)
            f.pack(side=tk.LEFT, expand=True)
            tk.Label(f, text=label, font=("Arial", 10), bg="white", fg=self.colors['text_secondary']).pack()
            tk.Label(f, textvariable=var, font=("Arial", 20, "bold"), bg="white", fg=color).pack(pady=5)
            return f

        create_sensor_item(s_grid, "环境温度", self.temp_var, self.colors['danger'])
        create_sensor_item(s_grid, "相对湿度", self.humi_var, self.colors['primary'])
        create_sensor_item(s_grid, "空气质量", self.aqi_var, self.colors['success'])

        # 3. 公共设施控制
        self._create_card(self.biz_frame, "楼层设施模拟控制").pack(fill=tk.X, pady=(0, 20))
        pub_body = self.last_card_body
        
        btn_style = {"width": 12, "relief": tk.FLAT, "font": ("Arial", 10, "bold"), "pady": 10}
        
        # 走廊灯
        light_f = tk.Frame(pub_body, bg="white")
        light_f.pack(fill=tk.X, pady=8)
        tk.Label(light_f, text="🔅 走廊照明系统控制:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        self.light_btn = tk.Button(light_f, text="OFF", bg="#595959", fg="white", 
                                  command=self._toggle_light, **btn_style)
        self.light_btn.pack(side=tk.RIGHT)
        
        # 公共广播
        bc_f = tk.Frame(pub_body, bg="white")
        bc_f.pack(fill=tk.X, pady=8)
        tk.Label(bc_f, text="📢 应急语音广播系统:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        self.bc_status = tk.Label(bc_f, text="● 系统就绪", 
                                 font=("Arial", 10, "bold"), fg=self.colors['text_secondary'], bg="white")
        self.bc_status.pack(side=tk.RIGHT, padx=15)

        # 4. 安全警报
        self._create_card(self.biz_frame, "紧急安全警报系统").pack(fill=tk.BOTH, expand=True)
        safe_body = self.last_card_body
        
        self.alarm_btn = tk.Button(safe_body, text="🛑 模拟触发全楼层消防报警", font=("Arial", 12, "bold"), 
                                  bg=self.colors['danger'], fg="white", pady=20, 
                                  command=self._trigger_alarm, relief=tk.RAISED, cursor="hand2")
        self.alarm_btn.pack(fill=tk.X, pady=10)
        
        tk.Button(safe_body, text="手动复位报警系统", command=self._reset_alarm, 
                  bg="#595959", fg="white", font=("Arial", 10), relief=tk.FLAT, pady=10).pack(fill=tk.X, pady=5)

    # --- 业务逻辑 ---
    def _sensor_loop(self):
        """模拟环境数据波动并上报"""
        while True:
            if self.mqtt_client and self.connected:
                temp = round(random.uniform(22, 26), 1)
                humi = random.randint(40, 60)
                aqi = random.randint(10, 45)
                
                self.root.after(0, lambda: self.temp_var.set(f"{temp}℃"))
                self.root.after(0, lambda: self.humi_var.set(f"{humi}%"))
                self.root.after(0, lambda: self.aqi_var.set("优" if aqi < 35 else "良"))
                
                # 上报 MQTT
                self.mqtt_client.publish(f"hotel/sensor/data/floor/{self.floor_id_var.get()}", {
                    "device_id": self.device_id,
                    "sensors": {"temp": temp, "humi": humi, "aqi": aqi}
                })
            time.sleep(10)

    def _toggle_light(self, from_cloud=False):
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
            self.mqtt_client.publish(f"hotel/security/alarm/floor/{self.floor_id_var.get()}", {
                "device_id": self.device_id, "type": "fire_alarm", "level": "critical"
            })

    def _reset_alarm(self):
        self.is_alarm = False
        self.alarm_btn.config(text="🔴 模拟触发消防报警", bg=self.colors['danger'])
        self._log("警报已人工复位")

    def _on_mqtt_message(self, topic, payload):
        super()._on_mqtt_message(topic, payload)
        cmd_type = payload.get('command_type')
        
        if cmd_type == 'light_on': self._toggle_light(True)
        elif cmd_type == 'light_off': self._toggle_light(True)
        elif cmd_type == 'broadcast_start':
            self.is_broadcasting = True
            self.bc_status.config(text="● 正在播放...", fg=self.colors['danger'])
            self._log("接收到云端广播指令：正在全楼层播放...")
        elif cmd_type == 'broadcast_stop':
            self.is_broadcasting = False
            self.bc_status.config(text="● 就绪", fg=self.colors['text_secondary'])
            self._log("广播已停止")

if __name__ == "__main__":
    root = tk.Tk()
    app = FloorControllerEmulator(root)
    app.run()
