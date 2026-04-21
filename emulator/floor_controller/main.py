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
from datetime import datetime
from common.device_base import BaseDeviceEmulator
from common.config import (
    CMD_LIGHT_ON, CMD_LIGHT_OFF,
    CMD_BROADCAST_START, CMD_BROADCAST_STOP, CMD_FLOOR_RESET
)


class SensorSimulator:
    """传感器模拟器"""
    
    def __init__(self):
        # 初始值
        self.temperature = 25.0
        self.humidity = 60.0
        self.light = 450.0
        self.air_quality_adc = 500.0  # 空气质量ADC值
        self.light_adc = 800.0  # 光照ADC值
        self.human_present = False  # 人体感应
        
        # 波动范围
        self.temp_range = (18.0, 32.0)
        self.humidity_range = (30.0, 80.0)
        self.light_range = (0.0, 1000.0)
        self.air_quality_range = (200.0, 800.0)
    
    def update(self):
        """更新传感器数据（模拟波动）"""
        # 温度随机波动 ±0.5
        self.temperature += random.uniform(-0.5, 0.5)
        self.temperature = max(self.temp_range[0], min(self.temp_range[1], self.temperature))
        
        # 湿度随机波动 ±1
        self.humidity += random.uniform(-1.0, 1.0)
        self.humidity = max(self.humidity_range[0], min(self.humidity_range[1], self.humidity))
        
        # 光照随机波动 ±20
        self.light += random.uniform(-20.0, 20.0)
        self.light = max(self.light_range[0], min(self.light_range[1], self.light))
        
        # 空气质量ADC随机波动
        self.air_quality_adc += random.uniform(-30.0, 30.0)
        self.air_quality_adc = max(self.air_quality_range[0], min(self.air_quality_range[1], self.air_quality_adc))
        
        # 光照ADC与光照值联动
        self.light_adc = self.light * 1.5 + random.uniform(-20, 20)
        
        # 人体感应随机变化（30%概率变化）
        if random.random() < 0.3:
            self.human_present = random.choice([True, False])
    
    def set_temperature(self, value):
        self.temperature = float(value)
    
    def set_humidity(self, value):
        self.humidity = float(value)
    
    def set_light(self, value):
        self.light = float(value)
    
    def get_values(self):
        return {
            "temperature": round(self.temperature, 1),
            "humidity": round(self.humidity, 1),
            "light": round(self.light, 1),
            "air_quality_adc": round(self.air_quality_adc, 0),
            "light_adc": round(self.light_adc, 0),
            "human_present": self.human_present
        }


class FloorControllerEmulator(BaseDeviceEmulator):
    """楼控节点仿真器"""
    
    def __init__(self, root):
        self.device_id = "floor_03"
        self.floor_id_var = tk.StringVar(value="03")  # 用于配置对话框
        
        super().__init__(
            root=root,
            title=f"智慧酒店 - 楼控节点仿真器 ({self.device_id})",
            device_id=self.device_id,
            device_type="floor",
            width=800,
            height=700
        )
        
        # 传感器模拟器
        self.sensors = SensorSimulator()
        
        # 执行器状态
        self.corridor_light_on = False
        self.broadcast_active = False
        
        # 传感器上报控制
        self.auto_report = True
        self.report_interval = 30  # 秒
        self._stop_report = threading.Event()
        self._report_thread = None
    
    def _create_ui(self):
        """创建UI界面"""
        super()._create_ui()
        
        # 创建内容面板
        content_frame = ttk.Frame(self.main_frame)
        content_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        content_frame.columnconfigure(0, weight=1)
        
        # 传感器数据面板
        self._create_sensor_panel(content_frame)
        
        # 执行器控制面板
        self._create_actuator_panel(content_frame)
        
        # 安防控制面板
        self._create_security_panel(content_frame)
    
    def _create_sensor_panel(self, parent):
        """创建传感器面板"""
        sensor_frame = ttk.LabelFrame(parent, text="传感器数据 (自动上报/30秒)", padding="10")
        sensor_frame.grid(row=0, column=0, sticky=(tk.W, tk.E), padx=5, pady=5)
        
        # 温度
        temp_frame = ttk.Frame(sensor_frame)
        temp_frame.pack(side=tk.LEFT, padx=20)
        
        ttk.Label(temp_frame, text="🌡️ 温度", font=("Arial", 12)).pack()
        self.temp_var = tk.StringVar(value="25.0°C")
        ttk.Label(temp_frame, textvariable=self.temp_var, font=("Arial", 20, "bold")).pack()
        self.temp_scale = ttk.Scale(
            temp_frame, from_=40, to=10, orient=tk.VERTICAL, length=100,
            command=self._on_temp_change
        )
        self.temp_scale.set(25)
        self.temp_scale.pack(pady=5)
        
        # 湿度
        hum_frame = ttk.Frame(sensor_frame)
        hum_frame.pack(side=tk.LEFT, padx=20)
        
        ttk.Label(hum_frame, text="💧 湿度", font=("Arial", 12)).pack()
        self.humidity_var = tk.StringVar(value="60.0%")
        ttk.Label(hum_frame, textvariable=self.humidity_var, font=("Arial", 20, "bold")).pack()
        self.humidity_scale = ttk.Scale(
            hum_frame, from_=90, to=20, orient=tk.VERTICAL, length=100,
            command=self._on_humidity_change
        )
        self.humidity_scale.set(60)
        self.humidity_scale.pack(pady=5)
        
        # 光照
        light_frame = ttk.Frame(sensor_frame)
        light_frame.pack(side=tk.LEFT, padx=20)
        
        ttk.Label(light_frame, text="☀️ 光照", font=("Arial", 12)).pack()
        self.light_var = tk.StringVar(value="450 lux")
        ttk.Label(light_frame, textvariable=self.light_var, font=("Arial", 20, "bold")).pack()
        self.light_scale = ttk.Scale(
            light_frame, from_=1000, to=0, orient=tk.VERTICAL, length=100,
            command=self._on_light_change
        )
        self.light_scale.set(450)
        self.light_scale.pack(pady=5)
        
        # 空气质量
        air_frame = ttk.Frame(sensor_frame)
        air_frame.pack(side=tk.LEFT, padx=20)
        
        ttk.Label(air_frame, text="🌫️ 空气质量", font=("Arial", 12)).pack()
        self.air_var = tk.StringVar(value="500")
        ttk.Label(air_frame, textvariable=self.air_var, font=("Arial", 14, "bold")).pack()
        
        # 人体感应
        human_frame = ttk.Frame(sensor_frame)
        human_frame.pack(side=tk.LEFT, padx=20)
        
        ttk.Label(human_frame, text="🚶 人体感应", font=("Arial", 12)).pack()
        self.human_var = tk.StringVar(value="无")
        self.human_label = ttk.Label(human_frame, textvariable=self.human_var, font=("Arial", 14, "bold"))
        self.human_label.pack()
        
        # 控制选项
        ctrl_frame = ttk.Frame(sensor_frame)
        ctrl_frame.pack(side=tk.LEFT, padx=20)
        
        self.auto_report_var = tk.BooleanVar(value=True)
        ttk.Checkbutton(
            ctrl_frame, text="自动上报", variable=self.auto_report_var,
            command=self._toggle_auto_report
        ).pack(anchor=tk.W, pady=5)
        
        ttk.Button(ctrl_frame, text="立即上报", command=self._manual_report).pack(pady=5)
        ttk.Button(ctrl_frame, text="随机数据", command=self._randomize_sensors).pack(pady=5)
    
    def _create_actuator_panel(self, parent):
        """创建执行器面板"""
        actuator_frame = ttk.LabelFrame(parent, text="执行器控制", padding="10")
        actuator_frame.grid(row=1, column=0, sticky=(tk.W, tk.E), padx=5, pady=5)
        
        # 走廊灯光
        light_frame = ttk.Frame(actuator_frame)
        light_frame.pack(fill=tk.X, pady=5)
        
        ttk.Label(light_frame, text="走廊灯光:", font=("Arial", 12)).pack(side=tk.LEFT, padx=5)
        
        self.light_status_var = tk.StringVar(value="关闭")
        ttk.Label(light_frame, textvariable=self.light_status_var, font=("Arial", 12)).pack(side=tk.LEFT, padx=10)
        
        # 灯光可视化
        self.light_canvas = tk.Canvas(light_frame, width=50, height=30, bg="#333", highlightthickness=1)
        self.light_canvas.pack(side=tk.LEFT, padx=10)
        
        ttk.Button(light_frame, text="开启", command=lambda: self._set_light(True)).pack(side=tk.LEFT, padx=5)
        ttk.Button(light_frame, text="关闭", command=lambda: self._set_light(False)).pack(side=tk.LEFT, padx=5)
        
        # 广播状态
        broadcast_frame = ttk.Frame(actuator_frame)
        broadcast_frame.pack(fill=tk.X, pady=5)
        
        ttk.Label(broadcast_frame, text="广播状态:", font=("Arial", 12)).pack(side=tk.LEFT, padx=5)
        
        self.broadcast_var = tk.StringVar(value="停止")
        ttk.Label(broadcast_frame, textvariable=self.broadcast_var, font=("Arial", 12)).pack(side=tk.LEFT, padx=10)
        
        ttk.Button(broadcast_frame, text="启动广播", command=self._start_broadcast).pack(side=tk.LEFT, padx=5)
        ttk.Button(broadcast_frame, text="停止广播", command=self._stop_broadcast).pack(side=tk.LEFT, padx=5)
    
    def _create_security_panel(self, parent):
        """创建安防面板"""
        security_frame = ttk.LabelFrame(parent, text="安防控制", padding="10")
        security_frame.grid(row=2, column=0, sticky=(tk.W, tk.E), padx=5, pady=5)
        
        # 消防报警按钮
        self.alarm_btn = tk.Button(
            security_frame, text="🔴 消防报警按钮", bg="#ff4444", fg="white",
            font=("Arial", 14, "bold"), command=self._trigger_alarm
        )
        self.alarm_btn.pack(pady=10)
        
        ttk.Button(security_frame, text="复位", command=self._reset_alarm).pack(pady=5)
    
    def _on_temp_change(self, value):
        """温度滑块变化"""
        self.sensors.set_temperature(float(value))
        self.temp_var.set(f"{self.sensors.temperature:.1f}°C")
    
    def _on_humidity_change(self, value):
        """湿度滑块变化"""
        self.sensors.set_humidity(float(value))
        self.humidity_var.set(f"{self.sensors.humidity:.1f}%")
    
    def _on_light_change(self, value):
        """光照滑块变化"""
        self.sensors.set_light(float(value))
        self.light_var.set(f"{int(self.sensors.light)} lux")
    
    def _toggle_auto_report(self):
        """切换自动上报"""
        self.auto_report = self.auto_report_var.get()
        if self.auto_report and self.connected:
            self._start_report_thread()
        else:
            self._stop_report.set()
    
    def _start_report_thread(self):
        """启动上报线程"""
        self._stop_report.clear()
        self._report_thread = threading.Thread(target=self._report_loop, daemon=True)
        self._report_thread.start()
    
    def _report_loop(self):
        """上报循环"""
        while not self._stop_report.is_set():
            if self.connected and self.auto_report:
                self.sensors.update()
                self._update_sensor_display()
                self._report_sensors()
            for _ in range(self.report_interval):
                if self._stop_report.is_set():
                    break
                time.sleep(1)
    
    def _update_sensor_display(self):
        """更新传感器显示"""
        values = self.sensors.get_values()
        self.temp_var.set(f"{values['temperature']:.1f}°C")
        self.humidity_var.set(f"{values['humidity']:.1f}%")
        self.light_var.set(f"{int(values['light'])} lux")
        self.air_var.set(f"{int(values['air_quality_adc'])}")
        self.human_var.set("有人" if values['human_present'] else "无人")
        # 根据人体感应改变颜色
        if values['human_present']:
            self.human_label.config(foreground="green")
        else:
            self.human_label.config(foreground="gray")
    
    def _report_sensors(self):
        """上报传感器数据"""
        if self.mqtt_client and self.connected:
            values = self.sensors.get_values()
            self.mqtt_client.publish_sensor_data("temperature", values["temperature"], "℃")
            self.mqtt_client.publish_sensor_data("humidity", values["humidity"], "%")
            self.mqtt_client.publish_sensor_data("light", values["light"], "lux")
            self.mqtt_client.publish_sensor_data("air_quality_adc", values["air_quality_adc"], "adc")
            self.mqtt_client.publish_sensor_data("light_adc", values["light_adc"], "adc")
            self.mqtt_client.publish_sensor_data("human_present", 1.0 if values["human_present"] else 0.0, "bool")
            self.logger.info(f"传感器上报: T={values['temperature']}°C, H={values['humidity']}%, "
                           f"L={values['light']}lux, Air={values['air_quality_adc']}, "
                           f"Human={'有' if values['human_present'] else '无'}")
    
    def _manual_report(self):
        """手动上报"""
        self._report_sensors()
    
    def _randomize_sensors(self):
        """随机化传感器数据"""
        self.sensors.temperature = random.uniform(20.0, 30.0)
        self.sensors.humidity = random.uniform(40.0, 70.0)
        self.sensors.light = random.uniform(100.0, 800.0)
        self.sensors.air_quality_adc = random.uniform(200.0, 800.0)
        self.sensors.human_present = random.choice([True, False])
        
        # 更新UI
        self.temp_scale.set(self.sensors.temperature)
        self.humidity_scale.set(self.sensors.humidity)
        self.light_scale.set(self.sensors.light)
        
        self._on_temp_change(self.sensors.temperature)
        self._on_humidity_change(self.sensors.humidity)
        self._on_light_change(self.sensors.light)
        self._update_sensor_display()
    
    def _set_light(self, on):
        """设置走廊灯光"""
        self.corridor_light_on = on
        status = "开启" if on else "关闭"
        self.light_status_var.set(status)
        
        # 更新可视化
        color = "#FFFF00" if on else "#333333"
        self.light_canvas.config(bg=color)
        
        self.logger.info(f"走廊灯光{status}")
        
        # 上报状态
        if self.mqtt_client and self.connected:
            self._publish_status()
    
    def _start_broadcast(self):
        """启动广播"""
        self.broadcast_active = True
        self.broadcast_var.set("运行中")
        self.logger.info("广播已启动")
    
    def _stop_broadcast(self):
        """停止广播"""
        self.broadcast_active = False
        self.broadcast_var.set("停止")
        self.logger.info("广播已停止")
    
    def _trigger_alarm(self):
        """触发消防报警"""
        self.logger.critical("消防报警触发！")
        
        # 视觉反馈
        self.alarm_btn.config(bg="#ff0000", text="⚠️ 报警中！")
        
        # 发送安防事件
        if self.mqtt_client and self.connected:
            self.mqtt_client.publish_security_event(
                "floor_alarm_pressed",
                level="critical",
                event_data={"device_id": self.device_id}
            )
    
    def _reset_alarm(self):
        """复位报警"""
        self.alarm_btn.config(bg="#ff4444", text="🔴 消防报警按钮")
        self.logger.info("报警已复位")
    
    def _publish_status(self):
        """发布设备状态"""
        if self.mqtt_client and self.connected:
            topic = f"hotel/device/status/floor/{self.device_id}"
            payload = {
                "device_id": self.device_id,
                "device_type": "floor",
                "status": "online",
                "corridor_light_on": self.corridor_light_on,
                "timestamp": datetime.now().isoformat()
            }
            self.mqtt_client.publish(topic, payload)
    
    def _register_command_handlers(self):
        """注册命令处理器"""
        self.mqtt_client.register_command_handler(CMD_LIGHT_ON, self._handle_light_on)
        self.mqtt_client.register_command_handler(CMD_LIGHT_OFF, self._handle_light_off)
        self.mqtt_client.register_command_handler(CMD_BROADCAST_START, self._handle_broadcast_start)
        self.mqtt_client.register_command_handler(CMD_BROADCAST_STOP, self._handle_broadcast_stop)
        self.mqtt_client.register_command_handler(CMD_FLOOR_RESET, self._handle_floor_reset)
    
    def _handle_light_on(self, data):
        """处理开灯命令"""
        self.root.after(0, lambda: self._set_light(True))
        return True
    
    def _handle_light_off(self, data):
        """处理关灯命令"""
        self.root.after(0, lambda: self._set_light(False))
        return True
    
    def _handle_broadcast_start(self, data):
        """处理启动广播命令"""
        self.root.after(0, self._start_broadcast)
        return True
    
    def _handle_broadcast_stop(self, data):
        """处理停止广播命令"""
        self.root.after(0, self._stop_broadcast)
        return True
    
    def _handle_floor_reset(self, data):
        """处理楼控复位命令"""
        self.root.after(0, lambda: self._set_light(False))
        self.root.after(0, self._stop_broadcast)
        return True
    
    def _on_connected(self):
        """连接成功"""
        if self.auto_report:
            self._start_report_thread()
        self._publish_status()
    
    def _on_disconnected(self):
        """断开连接"""
        self._stop_report.set()
    
    def _show_config_dialog(self):
        """显示配置对话框"""
        dialog = tk.Toplevel(self.root)
        dialog.title("设备配置")
        dialog.geometry("300x150")
        dialog.transient(self.root)
        dialog.grab_set()
        
        ttk.Label(dialog, text="楼层编号:").pack(pady=(20, 5))
        id_entry = ttk.Entry(dialog, textvariable=self.floor_id_var, width=10)
        id_entry.pack()
        
        def save_config():
            new_id = f"floor_{self.floor_id_var.get()}"
            if new_id != self.device_id:
                self.device_id = new_id
                self.device_id_label.config(text=f"设备ID: {self.device_id}")
                self.root.title(f"智慧酒店 - 楼控节点仿真器 ({self.device_id})")
                if self.connected:
                    messagebox.showinfo("提示", "设备ID已更改，请重新连接MQTT")
                    self.disconnect()
            dialog.destroy()
        
        ttk.Button(dialog, text="保存", command=save_config).pack(pady=20)


def main():
    """主函数"""
    root = tk.Tk()
    app = FloorControllerEmulator(root)
    app.run()


if __name__ == "__main__":
    main()
