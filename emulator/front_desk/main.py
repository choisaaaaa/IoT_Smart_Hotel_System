"""
前台管理端仿真器 - 主程序
"""
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
import random
import json
import requests
import threading
import time
from datetime import datetime
from common.device_base import BaseDeviceEmulator
from common.mqtt_client import MQTTClient
from common.rfid_simulator import RFIDCardSimulator
from common.config import (
    CMD_LIGHT, CMD_DOOR, CMD_SCENE,
    CMD_ISSUE_CARD, CMD_VERIFY_CARD, CMD_SWIPE_CARD,
    CMD_INCOMING_CALL, CMD_HANGUP_CALL,
    CMD_VAL_ON, CMD_VAL_OFF, CMD_VAL_UNLOCK, CMD_VAL_LOCK,
    CMD_VAL_WELCOME,
    TOPIC_DEVICE_COMMAND_PREFIX, TOPIC_SECURITY_EVENT
)

class FrontDeskEmulator(BaseDeviceEmulator):
    def __init__(self, root):
        self.rfid = RFIDCardSimulator()
        self.target_room_var = tk.StringVar(value="301")
        self.card_uid_var = tk.StringVar(value="") # 新增：用于手动输入卡片 UID
        self.last_card_room = ""
        self.front_id_var = tk.StringVar(value="")
        self.led_color = (0, 0, 255)
        self.led_wall_colors = ["#ffffff"] * 8  # 8颗客房状态灯
        self.rooms_mapping = ["", "", "", "", "", "", "", ""]
        self._alarm_beep_thread = None  # 报警蜂鸣器线程
        self._stop_alarm_beep = threading.Event()  # 停止蜂鸣器事件

        # 硬件组件状态
        self.button_mute_pressed = False  # 消音键
        self.button_broadcast_pressed = False  # 广播键
        self.buzzer_enabled = True  # 蜂鸣器使能状态
        self.spi_connected = True  # SPI接口状态
        self.uart_connected = True  # UART接口状态

        super().__init__(
            root=root,
            title=f"智慧酒店 - 前台管理端仿真器",
            device_id=None, # 让基类自动生成或从配置加载唯一物理ID
            device_type="front_desk",
            width=1000,
            height=900
        )

        self._sync_info()

    def _sync_info(self):
        if self.area_var.get():
            self._log(f"已同步位置信息: {self.area_var.get()}")

    def _on_config_updated(self):
        self._sync_info()
        self._log("收到云端配置更新")

    def _init_biz_ui(self):
        # ========== 第一部分：通信骨架 ==========
        self._create_card(self.biz_frame, "第一部分：通信骨架 (RC522 SPI + 状态灯)").pack(fill=tk.X, pady=(0, 15))
        comm_body = self.last_card_body

        # SPI接口状态
        spi_frame = tk.Frame(comm_body, bg="white")
        spi_frame.pack(fill=tk.X, pady=5)
        tk.Label(spi_frame, text="🔌 SPI接口 (RC522):", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        self.spi_status_label = tk.Label(spi_frame, text="✓ 已连接", font=("Arial", 10, "bold"),
                                         bg="white", fg=self.colors['success'])
        self.spi_status_label.pack(side=tk.LEFT, padx=10)
        tk.Button(spi_frame, text="模拟断开/连接", command=self._toggle_spi,
                  relief=tk.FLAT, font=("Arial", 9), padx=10).pack(side=tk.RIGHT)

        # GPIO引脚状态显示
        gpio_frame = tk.Frame(comm_body, bg="#f5f5f5", padx=10, pady=8)
        gpio_frame.pack(fill=tk.X, pady=5)
        tk.Label(gpio_frame, text="📌 GPIO引脚分配:", font=("Consolas", 9, "bold"), bg="#f5f5f5").pack(anchor=tk.W)
        gpio_text = "SDA/SS→GPIO10 | SCK→GPIO12 | MOSI→GPIO11 | MISO→GPIO13 | 3V3供电 | GND共地 | IRQ/RST不接"
        tk.Label(gpio_frame, text=gpio_text, font=("Consolas", 9), bg="#f5f5f5", fg="#666").pack(anchor=tk.W, pady=2)

        # ========== 第二部分：RFID读写器 ==========
        self._create_card(self.biz_frame, "第二部分：RFID智能房卡读写器 (RC522)").pack(fill=tk.X, pady=(0, 15))
        rfid_body = self.last_card_body

        viz_container = tk.Frame(rfid_body, bg="white")
        viz_container.pack(fill=tk.X, pady=10)

        self.card_canvas = tk.Canvas(viz_container, width=240, height=140, bg="white", highlightthickness=0)
        self.card_canvas.pack(side=tk.LEFT, padx=20)

        info_f = tk.Frame(viz_container, bg="white")
        info_f.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        tk.Label(info_f, text="当前卡片状态:", font=("Arial", 10), bg="white", fg=self.colors['text_secondary']).pack(anchor=tk.W)
        self.card_status_var = tk.StringVar(value="未检出有效卡片")
        tk.Label(info_f, textvariable=self.card_status_var, font=("Arial", 12, "bold"), bg="white", fg=self.colors['primary']).pack(anchor=tk.W, pady=5)

        # UID 输入
        uid_input_f = tk.Frame(info_f, bg="white")
        uid_input_f.pack(anchor=tk.W, pady=5)
        tk.Label(uid_input_f, text="卡片 UID (可选):", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        tk.Entry(uid_input_f, textvariable=self.card_uid_var, font=("Consolas", 11), width=12, bg="#f5f5f5", bd=0).pack(side=tk.LEFT, padx=10)
        tk.Label(uid_input_f, text="(留空自动生成)", font=("Arial", 8), bg="white", fg="#999").pack(side=tk.LEFT)

        tk.Label(info_f, text="目标房间号:", font=("Arial", 10), bg="white", fg=self.colors['text_secondary']).pack(anchor=tk.W, pady=(10, 0))
        room_input_f = tk.Frame(info_f, bg="#f5f5f5", padx=2, pady=2)
        room_input_f.pack(anchor=tk.W, pady=5)
        tk.Entry(room_input_f, textvariable=self.target_room_var, font=("Arial", 12, "bold"), width=10, bd=0, bg="#f5f5f5").pack(padx=10, pady=5)

        self._draw_card()

        btn_grid = tk.Frame(rfid_body, bg="white")
        btn_grid.pack(fill=tk.X, pady=15)

        btn_style = {"width": 12, "relief": tk.FLAT, "font": ("Arial", 10, "bold"), "pady": 10}

        self.place_card_btn = tk.Button(btn_grid, text="📥 放置卡片", bg=self.colors['primary'], fg="white", command=self._place_card, **btn_style)
        self.place_card_btn.pack(side=tk.LEFT, expand=True, padx=5)

        self.remove_card_btn = tk.Button(btn_grid, text="📤 收回卡片", bg="#595959", fg="white", command=self._remove_card, state=tk.DISABLED, **btn_style)
        self.remove_card_btn.pack(side=tk.LEFT, expand=True, padx=5)

        tk.Button(btn_grid, text="🔍 读取校验", bg=self.colors['info'], fg="white", command=self._verify_card, **btn_style).pack(side=tk.LEFT, expand=True, padx=5)

        # 移除冗余的写入和刷卡按钮，保持界面简洁
        # tk.Button(btn_grid, text="🆕 写入数据", bg=self.colors['success'], fg="white", command=self._issue_card, **btn_style).pack(side=tk.LEFT, expand=True, padx=5)
        # tk.Button(btn_grid, text="📟 模拟刷卡", bg=self.colors['warning'], fg="white", command=self._swipe_card, **btn_style).pack(side=tk.LEFT, expand=True, padx=5)

        # ========== 第三部分：客房状态灯墙 ==========
        self._create_card(self.biz_frame, "第三部分：客房状态可视化灯墙 (WS2812B x 8)").pack(fill=tk.X, pady=(0, 15))
        wall_body = self.last_card_body

        self.wall_canvas = tk.Canvas(wall_body, width=800, height=100, bg="#262626", highlightthickness=0)
        self.wall_canvas.pack(pady=10)
        self._update_led_wall()

        legend_f = tk.Frame(wall_body, bg="white")
        legend_f.pack(fill=tk.X)
        colors_legend = [("⚪ 空置", "#ffffff"), ("🟢 已入住", "#52c41a"), ("🔴 SOS/火警", "#ff4d4f"), ("🟡 清洁中", "#faad14"), ("🔵 维修中", "#1890ff")]
        for text, color in colors_legend:
            lbl = tk.Label(legend_f, text=text, font=("Arial", 9), bg="white", fg=color, padx=10)
            lbl.pack(side=tk.LEFT)

        # 灯带控制
        led_ctrl_frame = tk.Frame(wall_body, bg="white")
        led_ctrl_frame.pack(fill=tk.X, pady=10)
        tk.Label(led_ctrl_frame, text="💡 灯带测试:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        tk.Button(led_ctrl_frame, text="全亮白色", command=lambda: self._set_all_leds("#ffffff"),
                  relief=tk.FLAT, bg="#f0f0f0", padx=10).pack(side=tk.LEFT, padx=5)
        tk.Button(led_ctrl_frame, text="全亮红色", command=lambda: self._set_all_leds("#ff4d4f"),
                  relief=tk.FLAT, bg="#ff4d4f", fg="white", padx=10).pack(side=tk.LEFT, padx=5)
        tk.Button(led_ctrl_frame, text="彩虹效果", command=self._rainbow_leds,
                  relief=tk.FLAT, bg=self.colors['primary'], fg="white", padx=10).pack(side=tk.LEFT, padx=5)

        # ========== 第四部分：硬件交互外设 ==========
        self._create_card(self.biz_frame, "第四部分：硬件交互外设模拟 (蜂鸣器+按键+LED)").pack(fill=tk.X, pady=(0, 15))
        hw_body = self.last_card_body

        # 左侧运行指示灯
        led_container = tk.Frame(hw_body, bg="white")
        led_container.pack(side=tk.LEFT, fill=tk.Y, padx=10)

        self.led_canvas = tk.Canvas(led_container, width=60, height=60, bg="white", highlightthickness=0)
        self.led_canvas.pack(pady=5)
        self._update_led()
        tk.Label(led_container, text="运行指示灯\n(GPIO38)", font=("Arial", 9), bg="white", fg=self.colors['text_secondary']).pack()

        # 中间按键区
        btn_container = tk.Frame(hw_body, bg="white")
        btn_container.pack(side=tk.LEFT, fill=tk.Y, padx=30)

        # 消音键
        self.mute_btn = tk.Button(btn_container, text="🔇\n消音", bg="#f0f0f0", fg="#333",
                                  font=("Arial", 11, "bold"), width=6, height=2, relief=tk.RAISED,
                                  command=self._press_mute_button)
        self.mute_btn.pack(pady=5)
        tk.Label(btn_container, text="按键1: GPIO5", font=("Arial", 8), bg="white", fg="#666").pack()

        # 广播键
        self.broadcast_btn = tk.Button(btn_container, text="📢\n广播", bg="#f0f0f0", fg="#333",
                                       font=("Arial", 11, "bold"), width=6, height=2, relief=tk.RAISED,
                                       command=self._press_broadcast_button)
        self.broadcast_btn.pack(pady=5)
        tk.Label(btn_container, text="按键2: GPIO6", font=("Arial", 8), bg="white", fg="#666").pack()

        # 右侧蜂鸣器
        buzzer_container = tk.Frame(hw_body, bg="white")
        buzzer_container.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True, padx=20)

        tk.Label(buzzer_container, text="🔊 有源蜂鸣器测试 (GPIO38):", font=("Arial", 10, "bold"), bg="white").pack(anchor=tk.W, pady=5)

        buzzer_ctrl = tk.Frame(buzzer_container, bg="white")
        buzzer_ctrl.pack(fill=tk.X, pady=5)

        tk.Button(buzzer_ctrl, text="短鸣(操作成功)", bg=self.colors['success'], fg="white",
                  command=lambda: self._beep(1), **btn_style).pack(side=tk.LEFT, padx=5)
        tk.Button(buzzer_ctrl, text="双鸣(异常提醒)", bg=self.colors['danger'], fg="white",
                  command=lambda: self._beep(2), **btn_style).pack(side=tk.LEFT, padx=5)
        tk.Button(buzzer_ctrl, text="长鸣(报警)", bg="#ff4d4f", fg="white",
                  command=lambda: self._beep(5), **btn_style).pack(side=tk.LEFT, padx=5)

        # 蜂鸣器使能开关
        self.buzzer_switch_var = tk.BooleanVar(value=True)
        tk.Checkbutton(buzzer_container, text="蜂鸣器使能", variable=self.buzzer_switch_var,
                       bg="white", font=("Arial", 9)).pack(anchor=tk.W, pady=5)

        # ========== 第五部分：客房语音与远程控制 ==========
        self._create_card(self.biz_frame, "第五部分：客房语音与远程控制").pack(fill=tk.X, pady=(0, 15))
        ctrl_body = self.last_card_body

        call_f = tk.Frame(ctrl_body, bg="white")
        call_f.pack(fill=tk.X, pady=10)
        tk.Label(call_f, text="📢 应急广播呼叫:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        tk.Button(call_f, text="发送语音提醒", bg=self.colors['danger'], fg="white", command=self._broadcast_call, **btn_style).pack(side=tk.RIGHT)

        hangup_f = tk.Frame(ctrl_body, bg="white")
        hangup_f.pack(fill=tk.X, pady=10)
        tk.Label(hangup_f, text="🔇 停止呼叫/消音:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        tk.Button(hangup_f, text="强制挂断", bg="#595959", fg="white", command=self._hangup_call, **btn_style).pack(side=tk.RIGHT)

        door_f = tk.Frame(ctrl_body, bg="white")
        door_f.pack(fill=tk.X, pady=10)
        tk.Label(door_f, text="🚪 远程开锁:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        tk.Button(door_f, text="远程开门", bg=self.colors['warning'], fg="white", command=self._remote_unlock, **btn_style).pack(side=tk.RIGHT)

        # ========== 第六部分：SOS报警系统 ==========
        self._create_card(self.biz_frame, "第六部分：紧急安全警报系统 (SOS按键)").pack(fill=tk.X, pady=(0, 15))
        sos_body = self.last_card_body

        sos_container = tk.Frame(sos_body, bg="white")
        sos_container.pack(fill=tk.X, pady=10)

        self.sos_btn = tk.Button(sos_container, text="🆘\nSOS", bg=self.colors['danger'], fg="white",
                                font=("Arial", 16, "bold"), width=8, height=3, relief=tk.RAISED,
                                command=self._trigger_sos)
        self.sos_btn.pack(side=tk.LEFT, padx=20)

        sos_info = tk.Frame(sos_container, bg="white")
        sos_info.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=20)
        tk.Label(sos_info, text="110一键报警按键", font=("Arial", 12, "bold"), bg="white", fg=self.colors['danger']).pack(anchor=tk.W)
        tk.Label(sos_info, text="• 触发后联动全楼报警", font=("Arial", 10), bg="white", fg="#666").pack(anchor=tk.W, pady=2)
        tk.Label(sos_info, text="• 蜂鸣器持续鸣响", font=("Arial", 10), bg="white", fg="#666").pack(anchor=tk.W, pady=2)
        tk.Label(sos_info, text="• 灯墙红色闪烁", font=("Arial", 10), bg="white", fg="#666").pack(anchor=tk.W, pady=2)

        # ========== 第七部分：工业级接口 ==========
        self._create_card(self.biz_frame, "第七部分：工业级接口模拟 (RS485/UART)").pack(fill=tk.BOTH, expand=True)
        iface_body = self.last_card_body

        iface_f = tk.Frame(iface_body, bg="white")
        iface_f.pack(fill=tk.X)

        self.rs485_status = tk.Label(iface_f, text="[RS485] 🚒 消防主机: 运行正常 (MODBUS RTU, ID:01)", font=("Consolas", 9), bg="white", fg="#52c41a")
        self.rs485_status.pack(anchor=tk.W)

        self.uart_status = tk.Label(iface_f, text="[UART] 🚔 公安终端: 已连接 (SAM模块, 115200bps)", font=("Consolas", 9), bg="white", fg="#52c41a")
        self.uart_status.pack(anchor=tk.W, pady=(5, 0))

        # UART控制按钮
        uart_ctrl = tk.Frame(iface_body, bg="white")
        uart_ctrl.pack(fill=tk.X, pady=10)
        tk.Button(uart_ctrl, text="模拟UART断开", command=self._toggle_uart,
                  relief=tk.FLAT, font=("Arial", 9), padx=15).pack(side=tk.LEFT, padx=5)
        tk.Button(uart_ctrl, text="发送测试帧", command=self._send_test_frame,
                  relief=tk.FLAT, bg=self.colors['primary'], fg="white", font=("Arial", 9), padx=15).pack(side=tk.LEFT, padx=5)

        self.iface_log = scrolledtext.ScrolledText(iface_body, height=4, font=("Consolas", 8), bg="#262626", fg="#d4d4d4", bd=0)
        self.iface_log.pack(fill=tk.X, pady=10)
        self._log_iface("System boot: SPI initialization complete. RC522 ready.")
        self._log_iface("System boot: UART SAM module connected.")
        self._log_iface("System boot: RS485 MODBUS RTU master ready.")

    def _toggle_spi(self):
        """切换SPI接口状态"""
        self.spi_connected = not self.spi_connected
        if self.spi_connected:
            self.spi_status_label.config(text="✓ 已连接", fg=self.colors['success'])
            self._log("SPI接口已连接")
        else:
            self.spi_status_label.config(text="✗ 已断开", fg=self.colors['danger'])
            self._log("SPI接口已断开", "WARNING")

    def _toggle_uart(self):
        """切换UART接口状态"""
        self.uart_connected = not self.uart_connected
        if self.uart_connected:
            self.uart_status.config(text="[UART] 🚔 公安终端: 已连接 (SAM模块, 115200bps)", fg="#52c41a")
            self._log("UART接口已连接")
        else:
            self.uart_status.config(text="[UART] 🚔 公安终端: 已断开", fg="#ff4d4f")
            self._log("UART接口已断开", "WARNING")

    def _send_test_frame(self):
        """发送测试帧"""
        test_frame = "AA 55 01 03 00 00 04"
        self._log_iface(f"[TX] {test_frame}")
        self._log(f"发送测试帧: {test_frame}")

    def _press_mute_button(self):
        """按下消音键"""
        self.button_mute_pressed = True
        self.mute_btn.config(bg="#d9d9d9", relief=tk.SUNKEN)
        self._log("消音键按下 (GPIO5)")
        self._beep(1)
        # 停止持续蜂鸣器
        self._stop_continuous_beep()
        self.root.after(200, lambda: self.mute_btn.config(bg="#f0f0f0", relief=tk.RAISED))
        self.root.after(200, lambda: setattr(self, 'button_mute_pressed', False))

    def _press_broadcast_button(self):
        """按下广播键"""
        self.button_broadcast_pressed = True
        self.broadcast_btn.config(bg="#d9d9d9", relief=tk.SUNKEN)
        self._log("广播键按下 (GPIO6)")
        self._beep(1)
        self._broadcast_call()
        self.root.after(200, lambda: self.broadcast_btn.config(bg="#f0f0f0", relief=tk.RAISED))
        self.root.after(200, lambda: setattr(self, 'button_broadcast_pressed', False))

    def _set_all_leds(self, color):
        """设置所有LED颜色"""
        for i in range(8):
            self.led_wall_colors[i] = color
        self._update_led_wall()
        self._log(f"灯墙颜色设置为: {color}")

    def _rainbow_leds(self):
        """彩虹效果"""
        rainbow = ["#ff0000", "#ff7f00", "#ffff00", "#00ff00", "#0000ff", "#4b0082", "#9400d3", "#ff00ff"]
        for i in range(8):
            self.led_wall_colors[i] = rainbow[i]
        self._update_led_wall()
        self._log("灯墙彩虹效果已应用")

    def _connect(self):
        super()._connect()
        if self.connected:
            self._on_connected()

    def _disconnect(self):
        super()._disconnect()
        self._on_disconnected()

    def _place_card(self):
        # 获取手动输入的 UID (如果提供)
        custom_uid = self.card_uid_var.get()
        success, msg = self.rfid.place_card(custom_uid)
        if success:
            # 按钮状态不需要互斥锁定，允许用户连续点击重新“放置”以更新 UID 或重置状态
            self.place_card_btn.config(text="🔄 重新放置")
            self.remove_card_btn.config(state=tk.NORMAL)

            self._draw_card()
            self._beep(1)
            self._log(msg)

            # 关键：当卡片放置时，立即向云端上报卡片探测事件，以便 Web 端获取 UID
            if self.mqtt_client and self.connected:
                self.mqtt_client.publish_card_uid_event(self.rfid.uid)
                self._log(f"已上报卡片探测事件: UID={self.rfid.uid}")

    def _remove_card(self):
        success, msg = self.rfid.remove_card()
        if success:
            self.place_card_btn.config(text="📥 放置卡片", state=tk.NORMAL)
            self.remove_card_btn.config(state=tk.DISABLED)
            self._draw_card()
            self._log(msg)

    def _draw_card(self):
        self.card_canvas.delete("all")
        cx, cy = 120, 70
        if self.rfid.has_card:
            # 绘制放置在读卡器上的卡片
            self.card_canvas.create_rectangle(cx-100, cy-60, cx+100, cy+60,
                                             fill="#FFD700", outline="#B8860B", width=3)
            self.card_canvas.create_rectangle(cx-80, cy-20, cx-50, cy+10, fill="#C0C0C0", outline="#A0A0A0")

            if self.rfid.uid:
                self.card_canvas.create_text(cx+10, cy-15, text=f"UID: {self.rfid.uid}", font=("Consolas", 10, "bold"), fill="#595959")

            if self.rfid.card_data:
                room_id = self.rfid.card_data.get("room_id", "")
                card_type = self.rfid.card_data.get("card_type", "guest")
                holder_name = self.rfid.card_data.get("holder_name", "")

                type_map = {
                    'guest': 'GUEST CARD',
                    'master': 'MASTER CARD',
                    'floor': 'FLOOR CARD',
                    'staff': 'STAFF CARD',
                    'emergency': 'EMERGENCY CARD'
                }

                type_text = type_map.get(card_type, 'SMART CARD')
                self.card_canvas.create_text(cx+10, cy+10, text=type_text, font=("Arial", 9, "bold"), fill="#8B4513")

                if card_type == 'guest':
                    self.card_canvas.create_text(cx+10, cy+35, text=f"ROOM: {room_id}", font=("Consolas", 14, "bold"), fill="#333")
                else:
                    self.card_canvas.create_text(cx+10, cy+35, text=f"HOLDER: {holder_name[:10]}", font=("Consolas", 11, "bold"), fill="#333")
            else:
                self.card_canvas.create_text(cx+10, cy+10, text="HOTEL SMART CARD", font=("Arial", 9), fill="#8B4513")

            status_text = "已放置: "
            if self.rfid.card_data:
                ct = self.rfid.card_data.get('card_type', 'guest')
                if ct == 'guest': status_text += f"房间 {self.rfid.card_data.get('room_id')}"
                else: status_text += f"特权卡 ({ct})"
            else:
                status_text += "空白卡"
            self.card_status_var.set(status_text)
        else:
            # 绘制空的读卡器区域
            self.card_canvas.create_rectangle(cx-100, cy-60, cx+100, cy+60,
                                             fill="#f0f0f0", outline="#cccccc", dash=(4, 4), width=1)
            self.card_canvas.create_text(cx, cy, text="感应区无卡", font=("Microsoft YaHei", 10), fill="#999")
            self.card_status_var.set("读卡器空闲")

    def _update_led_wall(self):
        self.wall_canvas.delete("all")
        for i in range(8):
            x = 50 + i * 100
            y = 50
            color = self.led_wall_colors[i]
            # 绘制LED灯珠
            self.wall_canvas.create_oval(x-25, y-25, x+25, y+25, fill=color, outline="#444", width=2)
            # 绘制光晕
            if color != "#ffffff":
                self.wall_canvas.create_oval(x-35, y-35, x+35, y+35, outline=color, width=1)
            # 绘制房号
            self.wall_canvas.create_text(x, y+45, text=self.rooms_mapping[i], fill="#ccc", font=("Arial", 9))

    def _log_iface(self, msg):
        timestamp = datetime.now().strftime('%H:%M:%S.%f')[:-3]
        if hasattr(self, 'iface_log'):
            self.iface_log.insert(tk.END, f"[{timestamp}] {msg}\n")
            self.iface_log.see(tk.END)

    def _trigger_sos(self):
        self._log("!!! SOS 110一键报警已触发 !!!", "ERROR")
        self._beep(3)
        self._update_led(255, 0, 0)
        self._log_iface("UART: Sending SOS signal to police terminal...")
        self._log_iface("RS485: Broadcast alarm signal to fire host...")

        if self.mqtt_client and self.connected:
            self.mqtt_client.publish_security_event("sos_alarm", level="critical", event_data={
                "device_id": self.device_id,
                "type": "front_desk_sos",
                "message": "前台物理SOS按键被按下"
            })

        # 红色闪烁动画
        def flash(count):
            if count <= 0: return
            self.sos_btn.config(bg="white", fg="red")
            self.root.after(200, lambda: self.sos_btn.config(bg="red", fg="white"))
            self.root.after(400, lambda: flash(count-1))
        flash(5)

    def _update_led(self, r=0, g=0, b=255):
        self.led_color = (r, g, b)
        color = f"#{r:02x}{g:02x}{b:02x}"
        self.led_canvas.delete("all")
        self.led_canvas.create_oval(10, 10, 50, 50, fill=color, outline="")

    def _beep(self, count=1):
        if not self.buzzer_switch_var.get():
            return
        original_color = self.led_color
        self._update_led(255, 255, 0)
        self._play_beep(1000 if count == 1 else 2000, 200)
        self.root.after(100, lambda: self._update_led(*original_color))

        if count > 1:
            for i in range(1, count):
                self.root.after(i * 200, lambda: self._update_led(255, 255, 0))
                self.root.after(i * 200, lambda: self._play_beep(1000 if count == 1 else 2000, 200))
                self.root.after(i * 200 + 100, lambda: self._update_led(*original_color))

    def _issue_card(self):
        room_id = self.target_room_var.get()
        if not room_id:
            return messagebox.showwarning("提示", "请输入目标房间号")

        success, msg = self.rfid.issue_card(room_id)
        self._draw_card()

        if success:
            self._update_led(0, 255, 0)
            self._beep(1)
            self._log(msg)

            if self.mqtt_client and self.connected:
                # 模拟写卡物理事件上报
                self.mqtt_client.publish_card_uid_event(self.rfid.uid, room_id)

                self.mqtt_client.publish_security_event("card_issued", level="info", event_data={
                    "room_id": room_id,
                    "action": "issue",
                    "operator": self.device_id
                })
        else:
            self._update_led(255, 0, 0)
            self._beep(2)
            messagebox.showerror("写卡失败", msg)

        self.root.after(3000, lambda: self._update_led(0, 0, 255))

    def _verify_card(self):
        success, msg = self.rfid.verify_card()
        self._draw_card()

        if success:
            self._update_led(0, 255, 0)
            self._beep(1)
            self._log(msg)
        else:
            self._update_led(255, 0, 0)
            self._beep(2)

        self.root.after(3000, lambda: self._update_led(0, 0, 255))

    def _swipe_card(self):
        success, result = self.rfid.swipe_card()

        if success:
            uid_hex = result['uid']
            card_data = result['data']

            if not card_data:
                self._log(f"刷卡无效: 卡片 {uid_hex} 尚未写入数据", "ERROR")
                self._beep(2)
                return

            room_id = card_data['room_id']
            self.last_card_room = room_id
            self._update_led(0, 255, 0)
            self._beep(1)
            self._log(f"刷卡通过 [UID: {uid_hex}]，房间 {room_id}，正在上报卡片事件并请求开锁...")

            if self.mqtt_client and self.connected:
                self.mqtt_client.publish_card_uid_event(uid_hex, room_id=room_id)
                self._log(f"已上报卡片UID: {uid_hex} 房间: {room_id}")

                self.mqtt_client.publish_to_room(room_id, CMD_DOOR, CMD_VAL_UNLOCK)
                self._log(f"已发送开锁指令到房间{room_id}: command_type=door, command_value=unlock")
        else:
            self._update_led(255, 0, 0)
            self._beep(2)
            self._log(result, "ERROR")

        self.root.after(3000, lambda: self._update_led(0, 0, 255))

    def _request_rfid_verify(self, uid_hex, room_id):
        def do_verify():
            try:
                backend_url = self.backend_url_var.get()
                if "localhost" in backend_url:
                    backend_url = backend_url.replace("localhost", "127.0.0.1")

                verify_url = f"{backend_url}/api/v1/rfid-access/verify"
                payload = {
                    "card_uid": uid_hex,
                    "room_id": room_id,
                    "device_id": self.device_id,
                    "device_key": self.mqtt_client.device_key
                }
                self._log(f"正在请求后端验证卡片权限: {verify_url}")
                response = requests.post(verify_url, json=payload, timeout=5)

                if response.status_code == 200:
                    result = response.json()
                    if result.get('success') or result.get('data', {}).get('authorized'):
                        self._log(f"后端验证通过: 房卡权限有效", "SUCCESS")
                    else:
                        self._log(f"后端验证失败: {result.get('message', '权限不足')}", "WARNING")
                else:
                    self._log(f"后端验证请求失败: HTTP {response.status_code}", "WARNING")
            except Exception as e:
                self._log(f"后端验证请求异常: {e}", "WARNING")

        threading.Thread(target=do_verify, daemon=True).start()

    def _remove_card(self):
        self.rfid.remove_card()
        self._draw_card()
        self._log("卡片已移除")

    def _remote_unlock(self):
        room_id = self.target_room_var.get()
        if self.mqtt_client and self.connected:
            self.mqtt_client.publish_to_room(room_id, CMD_DOOR, CMD_VAL_UNLOCK)
            self._log(f"已发送远程开锁指令到房间{room_id}")
            self._beep(1)
        else:
            messagebox.showwarning("警告", "MQTT未连接")

    def _broadcast_call(self):
        room_id = self.target_room_var.get()
        if self.mqtt_client and self.connected:
            extra = {
                "call_id": f"call_{self.device_id}_{int(datetime.now().timestamp())}",
                "caller_id": self.device_id,
                "broadcast_text": f"前台呼叫房间{room_id}，请接听",
                "broadcast_audio_url": ""
            }
            self.mqtt_client.publish_to_room(room_id, CMD_INCOMING_CALL, extra_data=extra)
            self._log(f"已向房间{room_id}发送广播呼叫")
            self._beep(1)
        else:
            messagebox.showwarning("警告", "MQTT未连接")

    def _hangup_call(self):
        room_id = self.target_room_var.get()
        if self.mqtt_client and self.connected:
            extra = {
                "call_id": f"call_{self.device_id}_latest"
            }
            self.mqtt_client.publish_to_room(room_id, CMD_HANGUP_CALL, extra_data=extra)
            self._log(f"已向房间{room_id}发送挂断指令")
            self._beep(1)
        else:
            messagebox.showwarning("警告", "MQTT未连接")

    def _on_connected(self):
        # 订阅业务 ID 的指令主题 (用于后端下发指令)
        # 路径必须匹配后端 hotel/device/command/front_desk/{device_id}
        biz_cmd_topic = f"{TOPIC_DEVICE_COMMAND_PREFIX}/front_desk/{self.device_id}"
        self.mqtt_client.subscribe(biz_cmd_topic)
        self._log(f"已订阅指令主题: {biz_cmd_topic}")

        # 同时保留物理 ID 的订阅 (用于兼容性)
        phy_cmd_topic = f"{TOPIC_DEVICE_COMMAND_PREFIX}/front_desk/{self.unique_device_id}"
        self.mqtt_client.subscribe(phy_cmd_topic)
        self._log(f"已订阅物理指令主题: {phy_cmd_topic}")

        # 订阅全局前台指令主题（用于接收全局消警等指令）
        all_cmd_topic = f"{TOPIC_DEVICE_COMMAND_PREFIX}/front_desk/all"
        self.mqtt_client.subscribe(all_cmd_topic)
        self._log(f"已订阅全局前台指令主题: {all_cmd_topic}")

        # 订阅客房状态事件以更新灯墙
        self.mqtt_client.subscribe("hotel/device/event/room/+", self._on_room_event)
        self.mqtt_client.subscribe("hotel/security/event", self._on_security_event)

        # 订阅通话信令主题（用于接收客房呼叫）
        self.mqtt_client.subscribe("hotel/call/signaling", self._on_call_signaling)
        self._log("已订阅通话信令主题: hotel/call/signaling")

        self._register_command_handlers()
        self._update_led(0, 0, 255)
        self._beep(2)

    def _on_room_event(self, topic, payload):
        try:
            data = json.loads(payload)
            room_id = topic.split('/')[-1]
            event = data.get('event')
            val = data.get('value')

            # 更新灯墙
            if room_id in self.rooms_mapping:
                idx = self.rooms_mapping.index(room_id)
                if event == "check_in":
                    self.led_wall_colors[idx] = "#52c41a"
                elif event == "check_out":
                    self.led_wall_colors[idx] = "#ffffff"
                elif event == "cleaning":
                    self.led_wall_colors[idx] = "#faad14"
                elif event == "maintenance":
                    self.led_wall_colors[idx] = "#1890ff"
                self.root.after(0, self._update_led_wall)
        except:
            pass

    def _on_security_event(self, topic, payload):
        """处理安防事件，实现联动报警"""
        try:
            data = json.loads(payload)
            event_type = data.get('event_type')
            event_data = data.get('data', {})
            device_id = data.get('device_id', '')

            # 忽略自己触发的报警
            if device_id == self.unique_device_id:
                return

            # 处理消防报警联动
            if event_type == "fire_alarm":
                room_id = event_data.get('room_id')
                floor_id = event_data.get('floor_id')
                location = room_id or floor_id

                self._log(f"🔥 收到联动报警: {device_id} 触发消防报警", "ERROR")

                # 更新灯墙显示报警房间
                if location and location in self.rooms_mapping:
                    idx = self.rooms_mapping.index(location)
                    self.led_wall_colors[idx] = "#ff4d4f"
                    self.root.after(0, self._update_led_wall)

                # 蜂鸣器响3声
                self._beep(3)

                # 启动持续蜂鸣器（5秒后）
                self._start_continuous_beep()

                # LED变红
                self._update_led(255, 0, 0)
                self.root.after(3000, lambda: self._update_led(0, 0, 255))

                # 更新SOS按钮状态
                self.sos_btn.config(text="🔥 联动报警中", bg="#000000", fg="#ff4d4f")
                self.root.after(5000, lambda: self.sos_btn.config(text="🆘\nSOS", bg="red", fg="white"))

            # 处理SOS报警联动
            elif event_type == "sos_alarm":
                room_id = event_data.get('room_id')
                self._log(f"🆘 收到联动报警: {device_id} 触发SOS报警", "ERROR")

                if room_id and room_id in self.rooms_mapping:
                    idx = self.rooms_mapping.index(room_id)
                    self.led_wall_colors[idx] = "#ff4d4f"
                    self.root.after(0, self._update_led_wall)

                self._beep(3)
                self._update_led(255, 0, 0)
                self.root.after(3000, lambda: self._update_led(0, 0, 255))

        except Exception as e:
            self._log(f"处理安防事件失败: {e}", "ERROR")

    def _on_call_signaling(self, topic, payload):
        """处理通话信令（接收客房呼叫）"""
        try:
            data = json.loads(payload) if isinstance(payload, str) else payload
            action = data.get('action', '')
            call_id = data.get('call_id', '')
            caller_type = data.get('caller_type', '')
            caller_id = data.get('caller_id', '')

            # 忽略自己发送的消息
            if data.get('device_id') == self.unique_device_id:
                return

            if action == 'initiate' and caller_type == 'room':
                # 收到客房呼叫
                self._log(f"📞 收到客房 {caller_id} 的呼叫，Call ID: {call_id}")
                self._handle_incoming_call_from_room(data)
            elif action == 'hangup' and caller_type == 'room':
                # 客房挂断
                self._log(f"📞 客房 {caller_id} 挂断通话")
                self._handle_call_hangup(data)
        except Exception as e:
            self._log(f"处理通话信令失败: {e}", "ERROR")

    def _handle_incoming_call_from_room(self, data):
        """处理来自客房的来电"""
        caller_id = data.get('caller_id', '未知房间')
        call_id = data.get('call_id', '')

        self._log(f"处理客房来电: {caller_id}")
        self._beep(2)

        # 可以在这里添加接听逻辑，例如弹窗提示
        # 暂时自动接听并发送接听信令
        answer_data = {
            "action": "answer",
            "call_id": call_id,
            "caller_type": "front_desk",
            "device_id": self.unique_device_id,
            "callee_id": caller_id
        }
        self.mqtt_client.publish("hotel/call/signaling", answer_data)
        self.mqtt_client.publish(f"hotel/call/signaling/{call_id}", answer_data)
        self._log(f"已接听客房 {caller_id} 的呼叫")

    def _handle_call_hangup(self, data):
        """处理通话挂断"""
        self._beep(1)
        self._log("通话已结束")

    def _start_continuous_beep(self):
        """启动持续蜂鸣器（5秒后开始持续响）"""
        def continuous_beep():
            # 等待5秒
            time.sleep(5)

            # 如果还在报警状态，开始持续蜂鸣
            while not self._stop_alarm_beep.is_set():
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

    def _on_disconnected(self):
        self._update_led(255, 0, 0)

    def _register_command_handlers(self):
        # 注册房卡相关指令处理器
        self.mqtt_client.register_command_handler(CMD_ISSUE_CARD, self._handle_issue_card)
        self.mqtt_client.register_command_handler(CMD_VERIFY_CARD, self._handle_verify_card)
        self.mqtt_client.register_command_handler(CMD_SWIPE_CARD, self._handle_swipe_card)
        # 注册蜂鸣器测试指令
        self.mqtt_client.register_command_handler("buzzer", self._handle_buzzer_command)
        # 注册房间控制指令处理器
        self.mqtt_client.register_command_handler(CMD_DOOR, self._handle_door_command)
        self.mqtt_client.register_command_handler(CMD_LIGHT, self._handle_light_command)
        self.mqtt_client.register_command_handler(CMD_SCENE, self._handle_scene_command)
        # 注册通话相关指令
        self.mqtt_client.register_command_handler(CMD_INCOMING_CALL, self._handle_incoming_call)
        self.mqtt_client.register_command_handler(CMD_HANGUP_CALL, self._handle_hangup_call)
        # 注册通用room_card_op指令（Web端发卡使用）
        self.mqtt_client.register_command_handler("room_card_op", self._handle_room_card_op)
        # 注册报警复位指令
        self.mqtt_client.register_command_handler("alarm_reset", self._handle_alarm_reset)
        self._log("已注册所有指令处理器")

    def _handle_alarm_reset(self, data):
        """处理报警复位指令"""
        self._log("[Web指令] 收到消警指令，复位报警状态")
        # 复位灯墙颜色
        for i in range(8):
            self.led_wall_colors[i] = "#ffffff"
        self.root.after(0, self._update_led_wall)
        self._beep(1)
        # 停止持续蜂鸣器
        self._stop_continuous_beep()
        return True

    def _handle_buzzer_command(self, data):
        """处理蜂鸣器控制指令"""
        try:
            cmd_value = data.get('command_value', '{}')
            if isinstance(cmd_value, str):
                import json
                cmd_value = json.loads(cmd_value)

            count = cmd_value.get('count', 1)
            self._log(f"[Web指令] 触发蜂鸣器: {count} 次")
            self._beep(count)
            return True
        except Exception as e:
            self._log(f"处理蜂鸣器指令失败: {e}", "ERROR")
            return False

    def _handle_issue_card(self, data):
        room_id = data.get('command_value', {}).get('room_id', self.target_room_var.get()) if isinstance(data.get('command_value'), dict) else self.target_room_var.get()
        if not room_id:
            self._log("开卡失败: 未指定房间号", "ERROR")
            return False
        success, msg = self.rfid.issue_card(room_id)
        self.root.after(0, self._draw_card)
        self._beep(1 if success else 2)
        if success:
            self._log(f"[Web指令] 开卡成功: 房间 {room_id}")
            # 更新灯墙状态为已入住
            self._update_room_status_on_wall(room_id, "check_in")
        else:
            self._log(f"[Web指令] 开卡失败: {msg}", "ERROR")
        return success

    def _handle_verify_card(self, data):
        success, msg = self.rfid.verify_card()
        self.root.after(0, self._draw_card)
        self._beep(1 if success else 2)
        self._log(f"[Web指令] 验卡: {msg}")
        return success

    def _handle_swipe_card(self, data):
        success, result = self.rfid.swipe_card()
        if success:
            self.last_card_room = result
            if self.mqtt_client and self.connected:
                self.mqtt_client.publish_to_room(result, CMD_DOOR, CMD_VAL_UNLOCK)
            self._log(f"[Web指令] 刷卡通过，已发送开锁指令到房间 {result}")
        else:
            self._log(f"[Web指令] 刷卡失败: {result}", "ERROR")
        self.root.after(0, self._draw_card)
        self._beep(1 if success else 2)
        return success

    def _handle_room_card_op(self, data):
        """处理Web端发来的房卡操作指令"""
        try:
            cmd_value = data.get('command_value', '{}')
            if isinstance(cmd_value, str):
                import json
                cmd_value = json.loads(cmd_value)
            action = cmd_value.get('action', 'issue')
            room_number = cmd_value.get('room_number', '')
            booking_id = cmd_value.get('booking_id', '')

            self._log(f"[Web指令] 收到房卡操作: action={action}, room={room_number}, booking={booking_id}")

            if action == 'issue' or action == 'sync':
                card_type = cmd_value.get('card_type', 'guest')
                holder_name = cmd_value.get('holder_name', '')
                card_uid = cmd_value.get('card_uid', '')

                # 如果是发卡操作，且后端指定了 UID，我们尝试匹配或强制更新
                if action == 'issue' and card_uid:
                    if not self.rfid.has_card:
                        self._log(f"发卡失败: 物理感应区无卡片，但后端要求写入 {card_uid}", "ERROR")
                        return False
                    if self.rfid.uid != card_uid:
                        self._log(f"UID 警告: 当前卡片 {self.rfid.uid} 与后端预期 {card_uid} 不符，将强制更新...", "WARNING")
                        self.rfid.uid = card_uid # 强制同步 UID (模拟物理层面的 UID 确认)

                # 如果是同步指令且 UID 匹配，更新本地显示
                if action == 'sync':
                    if card_uid != self.rfid.uid:
                        return False
                    self._log(f"[MQTT] 收到同步指令: 发现已知卡片 {card_uid} ({card_type})")

                # 设置目标房间 (仅针对客房卡)
                if card_type == 'guest' and room_number:
                    self.target_room_var.set(room_number)

                # 执行开卡或同步信息
                target_id = room_number if card_type == 'guest' else ''
                success, msg = self.rfid.issue_card(target_id, card_type=card_type, holder_name=holder_name)

                self.root.after(0, self._draw_card)
                self._beep(1 if success else 2)
                if success:
                    self._update_led(0, 255, 0)
                    if card_type == 'guest' and room_number:
                        self._update_room_status_on_wall(room_number, "check_in")
                    self._log(f"[Web指令] { '发卡' if action=='issue' else '同步' }成功: 类型={card_type}, UID={self.rfid.uid}")

                    if action == 'issue' and self.mqtt_client and self.connected:
                        self.mqtt_client.publish_security_event("card_issued", level="info", event_data={
                            "card_uid": self.rfid.uid,
                            "room_id": room_number,
                            "card_type": card_type,
                            "booking_id": booking_id,
                            "action": "issue",
                            "operator": self.device_id
                        })
                return success

            elif action == 'sync_clear':
                # 收到清除同步指令 (说明是未知卡片)
                card_uid = cmd_value.get('card_uid', '')
                if card_uid == self.rfid.uid:
                    self.rfid.reset_card() # 擦除数据状态
                    self.root.after(0, self._draw_card)
                    self._log(f"[MQTT] 收到同步反馈: UID {card_uid} 为空白卡")
                return True

            elif action == 'revoke' or action == 'deactivate':
                # 执行退卡或作废
                card_uid = self.rfid.uid
                self.rfid.remove_card()
                self.root.after(0, self._draw_card)
                self._beep(1)
                self._update_led(255, 165, 0)
                if room_number:
                    self._update_room_status_on_wall(room_number, "check_out")
                self._log(f"[Web指令] { '退卡' if action=='revoke' else '作废' }成功: 房间 {room_number or 'N/A'}")

                if self.mqtt_client and self.connected:
                    self.mqtt_client.publish_security_event("card_revoked", level="info", event_data={
                        "card_uid": card_uid,
                        "room_id": room_number,
                        "booking_id": booking_id,
                        "action": action
                    })

                self.root.after(3000, lambda: self._update_led(0, 0, 255))
                return True

            return False
        except Exception as e:
            self._log(f"[Web指令] 处理房卡操作失败: {e}", "ERROR")
            return False

    def _handle_door_command(self, data):
        """处理门锁控制指令"""
        cmd_value = data.get('command_value', '')
        room_id = data.get('room_id', self.target_room_var.get())
        self._log(f"[Web指令] 门锁控制: {cmd_value}, 房间: {room_id}")
        if cmd_value == CMD_VAL_UNLOCK:
            self._beep(1)
            self._update_led(0, 255, 0)
            self.root.after(1000, lambda: self._update_led(0, 0, 255))
        return True

    def _handle_light_command(self, data):
        """处理灯光控制指令"""
        cmd_value = data.get('command_value', '')
        self._log(f"[Web指令] 灯光控制: {cmd_value}")
        return True

    def _handle_scene_command(self, data):
        """处理场景控制指令"""
        cmd_value = data.get('command_value', '')
        self._log(f"[Web指令] 场景控制: {cmd_value}")
        return True

    def _handle_incoming_call(self, data):
        """处理来电指令"""
        extra = data.get('extra_data', {})
        call_id = extra.get('call_id', 'unknown')
        broadcast_text = extra.get('broadcast_text', '收到来电')
        self._log(f"[Web指令] 来电: {broadcast_text} (Call ID: {call_id})")
        self._beep(2)
        self._update_led(255, 255, 0)  # 黄色闪烁
        self.root.after(2000, lambda: self._update_led(0, 0, 255))
        return True

    def _handle_hangup_call(self, data):
        """处理挂断指令"""
        extra = data.get('extra_data', {})
        call_id = extra.get('call_id', 'unknown')
        self._log(f"[Web指令] 挂断通话 (Call ID: {call_id})")
        return True

    def _update_room_status_on_wall(self, room_id, status):
        """更新灯墙上的房间状态"""
        if room_id in self.rooms_mapping:
            idx = self.rooms_mapping.index(room_id)
            if status == "check_in":
                self.led_wall_colors[idx] = "#52c41a"  # 绿色-已入住
            elif status == "check_out":
                self.led_wall_colors[idx] = "#ffffff"  # 白色-空置
            elif status == "cleaning":
                self.led_wall_colors[idx] = "#faad14"  # 黄色-清洁中
            elif status == "maintenance":
                self.led_wall_colors[idx] = "#1890ff"  # 蓝色-维修中
            self.root.after(0, self._update_led_wall)

    def _on_mqtt_message(self, topic, payload):
        super()._on_mqtt_message(topic, payload)
        try:
            data = json.loads(payload) if isinstance(payload, str) else payload
            cmd_type = data.get('command_type', '')
            cmd_value = data.get('command_value', '')
            device_id = data.get('device_id', '')
            self._log(f"[MQTT消息] Topic: {topic}, Cmd: {cmd_type}, Value: {cmd_value}, Target: {device_id}")
        except Exception as e:
            self._log(f"处理消息异常: {e}", "ERROR")


if __name__ == "__main__":
    root = tk.Tk()
    app = FrontDeskEmulator(root)
    app.run()
