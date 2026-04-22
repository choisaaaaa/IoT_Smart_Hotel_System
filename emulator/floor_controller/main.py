"""
楼控节点仿真器 - 主程序
"""
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
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
        
        # 硬件组件状态
        self.mq2_smoke_level = 0  # MQ-2烟雾浓度
        self.mq2_alarm_threshold = 80  # 报警阈值
        self.light_sensor_value = 300  # 光敏传感器值
        self.dht11_temp = 24.5  # DHT11温度
        self.dht11_humi = 50  # DHT11湿度
        self.relay_status = False  # 继电器状态
        self.alarm_button_pressed = False  # 报警按键状态
        
        # ADC分压模拟
        self.voltage_divider_enabled = True  # 分压电路使能

        super().__init__(
            root=root,
            title=f"智慧酒店 - 楼控节点仿真器",
            device_id=None, # 让基类自动生成或从配置加载唯一物理ID
            device_type="floor",
            width=950,
            height=850
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
        # ========== 第一部分：楼层实时概览 ==========
        self._create_card(self.biz_frame, "第一部分：楼层实时概览").pack(fill=tk.X, pady=(0, 15))
        status_body = self.last_card_body

        info_f = tk.Frame(status_body, bg="white")
        info_f.pack(fill=tk.X)
        tk.Label(info_f, text="📍 当前位置:", font=("Arial", 10), bg="white", fg=self.colors['text_secondary']).pack(side=tk.LEFT)

        display_pos = self.area_var.get() or f"第 {self.floor_id_var.get()} 层公共区域"
        self.pos_label = tk.Label(info_f, text=display_pos,
                                 font=("Arial", 12, "bold"), bg="white", fg=self.colors['primary'])
        self.pos_label.pack(side=tk.LEFT, padx=15)

        # ========== 第二部分：环境传感器监控 ==========
        self._create_card(self.biz_frame, "第二部分：环境传感器实时监控 (MQ-2+光敏+DHT11)").pack(fill=tk.X, pady=(0, 15))
        sensor_body = self.last_card_body

        self.temp_var = tk.StringVar(value="24.5℃")
        self.humi_var = tk.StringVar(value="50%")
        self.smoke_var = tk.StringVar(value="0 ppm")
        self.light_var = tk.StringVar(value="300 lx")

        s_grid = tk.Frame(sensor_body, bg="white")
        s_grid.pack(fill=tk.X)

        def create_sensor_item(parent, label, var, color, gpio_info):
            f = tk.Frame(parent, bg="white", padx=10, pady=10)
            f.pack(side=tk.LEFT, expand=True)
            tk.Label(f, text=label, font=("Arial", 10, "bold"), bg="white", fg=self.colors['text_secondary']).pack()
            tk.Label(f, textvariable=var, font=("Arial", 18, "bold"), bg="white", fg=color).pack(pady=5)
            tk.Label(f, text=gpio_info, font=("Consolas", 8), bg="white", fg="#999").pack()
            return f

        create_sensor_item(s_grid, "🌡️ 环境温度 (DHT11)", self.temp_var, self.colors['danger'], "GPIO15 单总线")
        create_sensor_item(s_grid, "💧 相对湿度 (DHT11)", self.humi_var, self.colors['primary'], "GPIO15 单总线")
        create_sensor_item(s_grid, "🔥 烟雾浓度 (MQ-2)", self.smoke_var, self.colors['warning'], "GPIO1 ADC(分压)")
        create_sensor_item(s_grid, "☀️ 光照强度 (光敏)", self.light_var, self.colors['success'], "GPIO2 ADC")
        
        # 传感器手动控制区
        sensor_ctrl = tk.Frame(sensor_body, bg="#f5f5f5", padx=10, pady=8)
        sensor_ctrl.pack(fill=tk.X, pady=10)
        
        tk.Label(sensor_ctrl, text="🎮 传感器模拟控制:", font=("Arial", 10, "bold"), bg="#f5f5f5").pack(side=tk.LEFT)
        
        # MQ-2控制
        mq2_frame = tk.Frame(sensor_ctrl, bg="#f5f5f5")
        mq2_frame.pack(side=tk.LEFT, padx=15)
        tk.Label(mq2_frame, text="MQ-2:", font=("Arial", 9), bg="#f5f5f5").pack(side=tk.LEFT)
        self.mq2_scale = tk.Scale(mq2_frame, from_=0, to=500, orient=tk.HORIZONTAL, 
                                  length=120, bg="#f5f5f5", highlightthickness=0)
        self.mq2_scale.set(0)
        self.mq2_scale.pack(side=tk.LEFT, padx=5)
        tk.Button(mq2_frame, text="应用", command=self._apply_mq2, 
                  relief=tk.FLAT, bg=self.colors['primary'], fg="white", font=("Arial", 8)).pack(side=tk.LEFT)
        
        # 光敏控制
        light_frame = tk.Frame(sensor_ctrl, bg="#f5f5f5")
        light_frame.pack(side=tk.LEFT, padx=15)
        tk.Label(light_frame, text="光照:", font=("Arial", 9), bg="#f5f5f5").pack(side=tk.LEFT)
        self.light_scale = tk.Scale(light_frame, from_=0, to=1000, orient=tk.HORIZONTAL, 
                                    length=120, bg="#f5f5f5", highlightthickness=0)
        self.light_scale.set(300)
        self.light_scale.pack(side=tk.LEFT, padx=5)
        tk.Button(light_frame, text="应用", command=self._apply_light, 
                  relief=tk.FLAT, bg=self.colors['primary'], fg="white", font=("Arial", 8)).pack(side=tk.LEFT)
        
        # 分压电路开关
        self.divider_var = tk.BooleanVar(value=True)
        tk.Checkbutton(sensor_ctrl, text="1k+2k分压使能", variable=self.divider_var,
                       bg="#f5f5f5", font=("Arial", 9), command=self._toggle_divider).pack(side=tk.LEFT, padx=15)

        # ========== 第三部分：楼层设施控制 ==========
        self._create_card(self.biz_frame, "第三部分：楼层设施模拟控制 (继电器+照明)").pack(fill=tk.X, pady=(0, 15))
        pub_body = self.last_card_body

        btn_style = {"width": 12, "relief": tk.FLAT, "font": ("Arial", 10, "bold"), "pady": 10}

        light_f = tk.Frame(pub_body, bg="white")
        light_f.pack(fill=tk.X, pady=8)
        tk.Label(light_f, text="🔅 走廊照明系统控制:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        self.light_btn = tk.Button(light_f, text="OFF", bg="#595959", fg="white",
                                  command=self._toggle_light, **btn_style)
        self.light_btn.pack(side=tk.RIGHT)
        
        # 继电器状态显示
        relay_frame = tk.Frame(pub_body, bg="#f5f5f5", padx=10, pady=8)
        relay_frame.pack(fill=tk.X, pady=5)
        tk.Label(relay_frame, text="🔌 继电器模块状态:", font=("Arial", 10, "bold"), bg="#f5f5f5").pack(side=tk.LEFT)
        self.relay_status_label = tk.Label(relay_frame, text="● 断开", font=("Arial", 10), 
                                           bg="#f5f5f5", fg="#999")
        self.relay_status_label.pack(side=tk.LEFT, padx=10)
        tk.Label(relay_frame, text="GPIO17 (IN1) | DC+→电源模块5V | DC-→共地 | 低电平触发", 
                 font=("Consolas", 9), bg="#f5f5f5", fg="#666").pack(side=tk.RIGHT)

        bc_f = tk.Frame(pub_body, bg="white")
        bc_f.pack(fill=tk.X, pady=8)
        tk.Label(bc_f, text="📢 应急语音广播系统:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        self.bc_status = tk.Label(bc_f, text="● 系统就绪",
                                 font=("Arial", 10, "bold"), fg=self.colors['text_secondary'], bg="white")
        self.bc_status.pack(side=tk.RIGHT, padx=15)

        # ========== 第四部分：硬件交互外设 ==========
        self._create_card(self.biz_frame, "第四部分：硬件交互外设模拟 (RGB LED+蜂鸣器+报警键)").pack(fill=tk.X, pady=(0, 15))
        hw_body = self.last_card_body

        # LED状态灯
        led_f = tk.Frame(hw_body, bg="white")
        led_f.pack(side=tk.LEFT, padx=10)
        self.led_canvas = tk.Canvas(led_f, width=250, height=60, bg="white", highlightthickness=0)
        self.led_canvas.pack()
        self._update_led_status()
        tk.Label(led_f, text="RGB 状态指示灯 x5 (WS2812B)", font=("Arial", 9), bg="white", fg=self.colors['text_secondary']).pack()
        
        # GPIO信息显示
        gpio_info = tk.Frame(led_f, bg="white")
        gpio_info.pack(fill=tk.X, pady=5)
        tk.Label(gpio_info, text="GPIO: 状态灯控制", font=("Consolas", 8), bg="white", fg="#999").pack()

        # 蜂鸣器控制
        buzzer_f = tk.Frame(hw_body, bg="white")
        buzzer_f.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=20)
        tk.Label(buzzer_f, text="🔊 蜂鸣器测试:", font=("Arial", 10, "bold"), bg="white").pack(anchor=tk.W)
        
        buzzer_btn_frame = tk.Frame(buzzer_f, bg="white")
        buzzer_btn_frame.pack(fill=tk.X, pady=5)
        tk.Button(buzzer_btn_frame, text="短鸣", bg=self.colors['primary'], fg="white",
                  command=lambda: self._beep(1), relief=tk.FLAT, font=("Arial", 9, "bold"), padx=15).pack(side=tk.LEFT, padx=5)
        tk.Button(buzzer_btn_frame, text="双鸣", bg=self.colors['warning'], fg="white",
                  command=lambda: self._beep(2), relief=tk.FLAT, font=("Arial", 9, "bold"), padx=15).pack(side=tk.LEFT, padx=5)
        tk.Button(buzzer_btn_frame, text="报警鸣", bg=self.colors['danger'], fg="white",
                  command=lambda: self._beep(5), relief=tk.FLAT, font=("Arial", 9, "bold"), padx=15).pack(side=tk.LEFT, padx=5)

        # 楼道报警按键
        alarm_btn_f = tk.Frame(hw_body, bg="white")
        alarm_btn_f.pack(side=tk.RIGHT, padx=20)
        self.alarm_key_btn = tk.Button(alarm_btn_f, text="🚨\n楼道报警", bg="#ff4d4f", fg="white",
                                       font=("Arial", 12, "bold"), width=8, height=3, relief=tk.RAISED,
                                       command=self._press_alarm_button)
        self.alarm_key_btn.pack()
        tk.Label(alarm_btn_f, text="GPIO18 (低电平有效)", font=("Consolas", 8), bg="white", fg="#999").pack(pady=5)

        # ========== 第五部分：紧急安全警报系统 ==========
        self._create_card(self.biz_frame, "第五部分：紧急安全警报系统 (消防联动)").pack(fill=tk.X, pady=(0, 15))
        safe_body = self.last_card_body

        self.alarm_btn = tk.Button(safe_body, text="🛑 模拟触发全楼层消防报警", font=("Arial", 12, "bold"),
                                  bg=self.colors['danger'], fg="white", pady=20,
                                  command=self._trigger_alarm, relief=tk.RAISED, cursor="hand2")
        self.alarm_btn.pack(fill=tk.X, pady=10)

        alarm_ctrl = tk.Frame(safe_body, bg="white")
        alarm_ctrl.pack(fill=tk.X, pady=5)
        tk.Button(alarm_ctrl, text="手动复位报警系统", command=self._reset_alarm,
                  bg="#595959", fg="white", font=("Arial", 10), relief=tk.FLAT, pady=10).pack(side=tk.LEFT, padx=5)
        tk.Button(alarm_ctrl, text="模拟烟雾超标", command=self._simulate_smoke_alarm,
                  bg="#ff7d4f", fg="white", font=("Arial", 10), relief=tk.FLAT, pady=10).pack(side=tk.LEFT, padx=5)
        
        # 报警阈值设置
        threshold_frame = tk.Frame(safe_body, bg="white")
        threshold_frame.pack(fill=tk.X, pady=10)
        tk.Label(threshold_frame, text="烟雾报警阈值:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        self.threshold_scale = tk.Scale(threshold_frame, from_=50, to=300, orient=tk.HORIZONTAL,
                                        length=200, bg="white", highlightthickness=0)
        self.threshold_scale.set(80)
        self.threshold_scale.pack(side=tk.LEFT, padx=10)
        tk.Button(threshold_frame, text="更新阈值", command=self._update_threshold,
                  relief=tk.FLAT, bg=self.colors['primary'], fg="white", font=("Arial", 9)).pack(side=tk.LEFT)

        # ========== 第六部分：电源与接线状态 ==========
        self._create_card(self.biz_frame, "第六部分：电源与接线状态监控").pack(fill=tk.BOTH, expand=True)
        power_body = self.last_card_body
        
        # 电源状态表格
        power_grid = tk.Frame(power_body, bg="white")
        power_grid.pack(fill=tk.X, pady=10)
        
        # 表头
        headers = ["模块", "供电方式", "电压", "电流要求", "GPIO连接", "状态"]
        for i, h in enumerate(headers):
            tk.Label(power_grid, text=h, font=("Arial", 9, "bold"), bg="#f5f5f5", padx=10, pady=5).grid(row=0, column=i, sticky="ew")
        
        # 数据行
        power_data = [
            ["ESP32-S3", "USB供电", "5V→3.3V", "500mA", "-", "✓ 正常"],
            ["MQ-2传感器", "电源模块5V", "5V", "150mA(加热)", "AO→GPIO1(分压)", "✓ 正常"],
            ["光敏传感器", "开发板3V3", "3.3V", "<10mA", "AO→GPIO2", "✓ 正常"],
            ["DHT11", "开发板3V3", "3.3V", "<5mA", "DATA→GPIO15", "✓ 正常"],
            ["继电器", "电源模块5V", "5V", "100mA/路", "IN1→GPIO17", "✓ 正常"],
            ["RGB LED", "开发板3V3", "3.3V", "<60mA", "GPIO控制", "✓ 正常"],
        ]
        
        for row_idx, row_data in enumerate(power_data, 1):
            for col_idx, cell in enumerate(row_data):
                bg_color = "white" if row_idx % 2 == 1 else "#fafafa"
                tk.Label(power_grid, text=cell, font=("Consolas", 9), bg=bg_color, padx=10, pady=4).grid(row=row_idx, column=col_idx, sticky="ew")
        
        # 共地提醒
        warning_frame = tk.Frame(power_body, bg="#fff7e6", padx=10, pady=8)
        warning_frame.pack(fill=tk.X, pady=10)
        tk.Label(warning_frame, text="⚠️ 重要提醒:", font=("Arial", 10, "bold"), bg="#fff7e6", fg="#fa8c16").pack(side=tk.LEFT)
        tk.Label(warning_frame, text="所有外设GND必须与开发板GND共地！电源模块5V/GND与开发板GND已连接。", 
                 font=("Arial", 9), bg="#fff7e6", fg="#666").pack(side=tk.LEFT, padx=10)
        
        # 接线日志
        self.wiring_log = scrolledtext.ScrolledText(power_body, height=4, font=("Consolas", 8), bg="#262626", fg="#d4d4d4", bd=0)
        self.wiring_log.pack(fill=tk.X, pady=10)
        self._log_wiring("System init: Power module 5V output verified: 5.02V")
        self._log_wiring("System init: GND continuity check passed (all modules)")
        self._log_wiring("System init: MQ-2 voltage divider 1k+2k verified, GPIO1 input safe")
        self._log_wiring("System init: All sensors initialized and responding")

    def _log_wiring(self, msg):
        """记录接线日志"""
        timestamp = datetime.now().strftime('%H:%M:%S.%f')[:-3]
        self.wiring_log.insert(tk.END, f"[{timestamp}] {msg}\n")
        self.wiring_log.see(tk.END)

    def _apply_mq2(self):
        """应用MQ-2烟雾值"""
        self.mq2_smoke_level = self.mq2_scale.get()
        self.smoke_var.set(f"{self.mq2_smoke_level} ppm")
        self._log(f"手动设置MQ-2烟雾值: {self.mq2_smoke_level} ppm")
        
        # 检查是否超过阈值
        if self.mq2_smoke_level > self.mq2_alarm_threshold and not self.is_alarm:
            self._log(f"烟雾浓度超过阈值({self.mq2_alarm_threshold})，触发报警！", "ERROR")
            self._trigger_alarm()

    def _apply_light(self):
        """应用光照值"""
        self.light_sensor_value = self.light_scale.get()
        self.light_var.set(f"{self.light_sensor_value} lx")
        self._log(f"手动设置光照值: {self.light_sensor_value} lx")

    def _toggle_divider(self):
        """切换分压电路状态"""
        self.voltage_divider_enabled = self.divider_var.get()
        if self.voltage_divider_enabled:
            self._log("MQ-2分压电路已启用 (1k+2k)")
            self._log_wiring("MQ-2: Voltage divider ENABLED (1k+2k)")
        else:
            self._log("MQ-2分压电路已禁用 ⚠️ 注意GPIO电压！", "WARNING")
            self._log_wiring("MQ-2: Voltage divider DISABLED - WARNING: GPIO may be unsafe!")

    def _press_alarm_button(self):
        """按下楼道报警按键"""
        self.alarm_button_pressed = True
        self.alarm_key_btn.config(bg="#d9363e", relief=tk.SUNKEN)
        self._log("楼道报警按键按下 (GPIO18 低电平触发)")
        self._trigger_alarm()
        self.root.after(200, lambda: self.alarm_key_btn.config(bg="#ff4d4f", relief=tk.RAISED))
        self.root.after(200, lambda: setattr(self, 'alarm_button_pressed', False))

    def _simulate_smoke_alarm(self):
        """模拟烟雾超标报警"""
        self.mq2_smoke_level = random.randint(100, 300)
        self.mq2_scale.set(self.mq2_smoke_level)
        self.smoke_var.set(f"{self.mq2_smoke_level} ppm")
        self._log(f"模拟烟雾超标: {self.mq2_smoke_level} ppm", "WARNING")
        self._trigger_alarm()

    def _update_threshold(self):
        """更新报警阈值"""
        self.mq2_alarm_threshold = self.threshold_scale.get()
        self._log(f"烟雾报警阈值已更新为: {self.mq2_alarm_threshold} ppm")

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
                # 模拟传感器数据波动
                temp = round(self.dht11_temp + random.uniform(-0.5, 0.5), 1)
                humi = max(0, min(100, self.dht11_humi + random.randint(-2, 2)))
                
                # 烟雾值如果没有手动设置，则随机波动
                if self.mq2_scale.get() == self.mq2_smoke_level:
                    smoke = max(0, self.mq2_smoke_level + random.randint(-5, 5))
                else:
                    smoke = self.mq2_smoke_level
                    
                light_val = max(0, min(1000, self.light_sensor_value + random.randint(-20, 20)))

                self.root.after(0, lambda: self.temp_var.set(f"{temp}℃"))
                self.root.after(0, lambda: self.humi_var.set(f"{humi}%"))
                self.root.after(0, lambda: self.smoke_var.set(f"{smoke} ppm"))
                self.root.after(0, lambda: self.light_var.set(f"{light_val} lx"))

                self.mqtt_client.publish_sensor_data(SENSOR_TEMPERATURE, temp, "℃")
                self.mqtt_client.publish_sensor_data(SENSOR_HUMIDITY, humi, "%")
                self.mqtt_client.publish_sensor_data(SENSOR_SMOKE, smoke, "ppm")
                self.mqtt_client.publish_sensor_data(SENSOR_LIGHT, light_val, "lx")

                self._log(f"传感器数据上报: 温度={temp}℃ 湿度={humi}% 烟雾={smoke}ppm 光照={light_val}lx")

                # 烟雾报警逻辑
                if smoke > self.mq2_alarm_threshold and not self.is_alarm:
                    self.root.after(0, self._trigger_alarm)
            time.sleep(30)

    def _toggle_light(self, from_cloud=False, turn_on=None):
        if turn_on is not None:
            self.light_on = turn_on
        else:
            self.light_on = not self.light_on
        
        self.relay_status = self.light_on
        status = "ON" if self.light_on else "OFF"
        color = self.colors['success'] if self.light_on else "#595959"
        self.light_btn.config(text=status, bg=color)
        
        # 更新继电器状态显示
        relay_text = "● 闭合" if self.relay_status else "● 断开"
        relay_color = self.colors['success'] if self.relay_status else "#999"
        self.relay_status_label.config(text=relay_text, fg=relay_color)
        
        self._log(f"{'[云端]' if from_cloud else '[本地]'} 楼层照明已切换至 {status}")
        self._log_wiring(f"Relay GPIO17 {'CLOSED' if self.relay_status else 'OPEN'} -> Light {status}")

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
