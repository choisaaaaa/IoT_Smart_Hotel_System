"""
前台管理端仿真器 - 主程序
"""
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

import tkinter as tk
from tkinter import ttk, messagebox
import random
import json
import requests
import threading
import time
from datetime import datetime
from common.device_base import BaseDeviceEmulator
from common.mqtt_client import MQTTClient
from common.config import (
    CMD_LIGHT, CMD_DOOR, CMD_SCENE,
    CMD_ISSUE_CARD, CMD_VERIFY_CARD, CMD_SWIPE_CARD,
    CMD_INCOMING_CALL, CMD_HANGUP_CALL,
    CMD_VAL_ON, CMD_VAL_OFF, CMD_VAL_UNLOCK, CMD_VAL_LOCK,
    CMD_VAL_WELCOME,
    TOPIC_DEVICE_COMMAND_PREFIX, TOPIC_SECURITY_EVENT
)


class RFIDCardSimulator:
    def __init__(self):
        self.card_data = None
        self.has_card = False

    def issue_card(self, room_id):
        self.card_data = {"room_id": room_id, "issued_at": datetime.now().isoformat()}
        self.has_card = True
        return True, f"开卡成功: 房间{room_id}"

    def verify_card(self):
        if not self.has_card:
            return False, "未检测到有效房卡"
        room_id = self.card_data.get("room_id", "unknown")
        return True, f"验卡通过: 房间{room_id}"

    def swipe_card(self):
        if not self.has_card:
            return False, "未检测到有效房卡"
        room_id = self.card_data.get("room_id", "unknown")
        return True, room_id

    def remove_card(self):
        self.has_card = False
        self.card_data = None

    def insert_card(self, room_id=None):
        if room_id:
            self.card_data = {"room_id": room_id, "issued_at": datetime.now().isoformat()}
        self.has_card = True


class FrontDeskEmulator(BaseDeviceEmulator):
    def __init__(self, root):
        self.rfid = RFIDCardSimulator()
        self.target_room_var = tk.StringVar(value="")
        self.last_card_room = ""
        self.front_id_var = tk.StringVar(value="")
        self.led_color = (0, 0, 255)
        self.led_wall_colors = ["#ffffff"] * 8  # 8颗客房状态灯
        self.rooms_mapping = ["", "", "", "", "", "", "", ""]
        self._alarm_beep_thread = None  # 报警蜂鸣器线程
        self._stop_alarm_beep = threading.Event()  # 停止蜂鸣器事件

        super().__init__(
            root=root,
            title=f"智慧酒店 - 前台管理端仿真器",
            device_id=None, # 让基类自动生成或从配置加载唯一物理ID
            device_type="front_desk",
            width=950,
            height=800
        )

        self._sync_info()

    def _sync_info(self):
        if self.area_var.get():
            self._log(f"已同步位置信息: {self.area_var.get()}")

    def _on_config_updated(self):
        self._sync_info()
        self._log("收到云端配置更新")

    def _init_biz_ui(self):
        self._create_card(self.biz_frame, "客房状态可视化灯墙 (WS2812B x 8)").pack(fill=tk.X, pady=(0, 20))
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

        self._create_card(self.biz_frame, "RFID 智能房卡读写器").pack(fill=tk.X, pady=(0, 20))
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

        tk.Label(info_f, text="目标房间号:", font=("Arial", 10), bg="white", fg=self.colors['text_secondary']).pack(anchor=tk.W, pady=(10, 0))
        room_input_f = tk.Frame(info_f, bg="#f5f5f5", padx=2, pady=2)
        room_input_f.pack(anchor=tk.W, pady=5)
        tk.Entry(room_input_f, textvariable=self.target_room_var, font=("Arial", 12, "bold"), width=10, bd=0, bg="#f5f5f5").pack(padx=10, pady=5)

        self._draw_card()

        btn_grid = tk.Frame(rfid_body, bg="white")
        btn_grid.pack(fill=tk.X, pady=15)

        btn_style = {"width": 12, "relief": tk.FLAT, "font": ("Arial", 10, "bold"), "pady": 10}

        tk.Button(btn_grid, text="🆕 开卡写入", bg=self.colors['primary'], fg="white", command=self._issue_card, **btn_style).pack(side=tk.LEFT, expand=True, padx=5)
        tk.Button(btn_grid, text="🔍 验卡读取", bg=self.colors['success'], fg="white", command=self._verify_card, **btn_style).pack(side=tk.LEFT, expand=True, padx=5)
        tk.Button(btn_grid, text="📟 模拟刷卡", bg=self.colors['warning'], fg="white", command=self._swipe_card, **btn_style).pack(side=tk.LEFT, expand=True, padx=5)
        tk.Button(btn_grid, text="🗑️ 移除卡片", bg="#595959", fg="white", command=self._remove_card, **btn_style).pack(side=tk.LEFT, expand=True, padx=5)

        self._create_card(self.biz_frame, "客房语音与远程控制").pack(fill=tk.X, pady=(0, 20))
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

        self._create_card(self.biz_frame, "硬件交互外设模拟").pack(fill=tk.X, pady=(0, 20))
        hw_body = self.last_card_body

        # 左侧指示灯
        led_container = tk.Frame(hw_body, bg="white")
        led_container.pack(side=tk.LEFT, fill=tk.Y, padx=10)

        self.led_canvas = tk.Canvas(led_container, width=60, height=60, bg="white", highlightthickness=0)
        self.led_canvas.pack(pady=5)
        self._update_led()
        tk.Label(led_container, text="运行指示灯", font=("Arial", 9), bg="white", fg=self.colors['text_secondary']).pack()

        # 中间SOS按键
        sos_container = tk.Frame(hw_body, bg="white")
        sos_container.pack(side=tk.LEFT, fill=tk.Y, padx=30)

        self.sos_btn = tk.Button(sos_container, text="🆘\nSOS", bg=self.colors['danger'], fg="white",
                                font=("Arial", 14, "bold"), width=6, height=3, relief=tk.RAISED,
                                command=self._trigger_sos)
        self.sos_btn.pack(pady=5)
        tk.Label(sos_container, text="110一键报警", font=("Arial", 9), bg="white", fg=self.colors['danger']).pack()

        # 右侧蜂鸣器
        buzzer_container = tk.Frame(hw_body, bg="white")
        buzzer_container.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True, padx=20)

        tk.Label(buzzer_container, text="蜂鸣器手动测试:", font=("Arial", 10), bg="white").pack(anchor=tk.W, pady=5)
        tk.Button(buzzer_container, text="🔊 短鸣(操作成功)", bg=self.colors['success'], fg="white",
                  command=lambda: self._beep(1), **btn_style).pack(fill=tk.X, pady=5)
        tk.Button(buzzer_container, text="🔇 双鸣(异常提醒)", bg=self.colors['danger'], fg="white",
                  command=lambda: self._beep(2), **btn_style).pack(fill=tk.X, pady=5)

        # 4. UART/RS485 接口模拟日志
        self._create_card(self.biz_frame, "工业级接口模拟 (RS485/UART)").pack(fill=tk.BOTH, expand=True)
        iface_body = self.last_card_body

        iface_f = tk.Frame(iface_body, bg="white")
        iface_f.pack(fill=tk.X)

        self.rs485_status = tk.Label(iface_f, text="[RS485] 🚒 消防主机: 运行正常 (MODBUS RTU, ID:01)", font=("Consolas", 9), bg="white", fg="#52c41a")
        self.rs485_status.pack(anchor=tk.W)

        self.uart_status = tk.Label(iface_f, text="[UART] 🚔 公安终端: 已连接 (SAM模块, 115200bps)", font=("Consolas", 9), bg="white", fg="#52c41a")
        self.uart_status.pack(anchor=tk.W, pady=(5, 0))

        self.iface_log = scrolledtext.ScrolledText(iface_body, height=4, font=("Consolas", 8), bg="#262626", fg="#d4d4d4", bd=0)
        self.iface_log.pack(fill=tk.X, pady=10)
        self._log_iface("System boot: RS485 initialization complete.")
        self._log_iface("System boot: UART SAM module connected.")

    def _connect(self):
        super()._connect()
        if self.connected:
            self._on_connected()

    def _disconnect(self):
        super()._disconnect()
        self._on_disconnected()

    def _draw_card(self):
        self.card_canvas.delete("all")
        cx, cy = 120, 70
        if self.rfid.has_card:
            self.card_canvas.create_rectangle(cx-100, cy-60, cx+100, cy+60,
                                             fill="#FFD700", outline="#B8860B", width=3, round=10)
            self.card_canvas.create_rectangle(cx-80, cy-20, cx-50, cy+10, fill="#C0C0C0", outline="#A0A0A0")

            self.card_canvas.create_text(cx+10, cy-10, text="HOTEL SMART CARD", font=("Arial", 10, "bold"), fill="#8B4513")
            if self.rfid.card_data:
                room_id = self.rfid.card_data.get("room_id", "")
                self.card_canvas.create_text(cx+10, cy+20, text=f"ROOM: {room_id}", font=("Consolas", 14, "bold"), fill="#333")
            self.card_status_var.set(f"已插入: 房间 {self.rfid.card_data.get('room_id', '???')}" if self.rfid.card_data else "空白卡片")
        else:
            self.card_canvas.create_rectangle(cx-100, cy-60, cx+100, cy+60,
                                             fill="#f9f9f9", outline="#dddddd", dash=(5, 5), width=2)
            self.card_canvas.create_text(cx, cy, text="请插入房卡", font=("Microsoft YaHei", 10), fill="#999")
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
        success, msg = self.rfid.issue_card(room_id)
        self._draw_card()

        if success:
            self._update_led(0, 255, 0)
            self._beep(1)
            self._log(msg)

            if self.mqtt_client and self.connected:
                self.mqtt_client.publish_security_event("card_issued", level="info", event_data={
                    "room_id": room_id,
                    "action": "issue",
                    "operator": self.device_id
                })
        else:
            self._update_led(255, 0, 0)
            self._beep(2)

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
            room_id = result
            self.last_card_room = room_id
            self._update_led(0, 255, 0)
            self._beep(1)
            self._log(f"刷卡通过，房间{room_id}，正在上报卡片事件并请求开锁...")

            if self.mqtt_client and self.connected:
                uid_hex = "".join([f"{random.randint(0, 255):02X}" for _ in range(4)])
                self.mqtt_client.publish_card_uid_event(uid_hex, room_id=room_id)
                self._log(f"已上报卡片UID: {uid_hex} 房间: {room_id}")

                self.mqtt_client.publish_to_room(room_id, CMD_DOOR, CMD_VAL_UNLOCK)
                self._log(f"已发送开锁指令到房间{room_id}: command_type=door, command_value=unlock")

                self._request_rfid_verify(uid_hex, room_id)
        else:
            self._update_led(255, 0, 0)
            self._beep(2)
            self._log(result, "WARNING")

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
        # 使用物理 ID (unique_device_id) 进行订阅
        cmd_topic = f"{TOPIC_DEVICE_COMMAND_PREFIX}/front_desk/{self.unique_device_id}"
        self.mqtt_client.subscribe(cmd_topic)
        self._log(f"已订阅前台指令主题: {cmd_topic}")

        # 订阅全局前台指令主题（用于接收全局消警等指令）
        all_cmd_topic = f"{TOPIC_DEVICE_COMMAND_PREFIX}/front_desk/all"
        self.mqtt_client.subscribe(all_cmd_topic)
        self._log(f"已订阅全局前台指令主题: {all_cmd_topic}")

        # 订阅客房状态事件以更新灯墙
        self.mqtt_client.subscribe("hotel/device/event/room/+", self._on_room_event)
        self.mqtt_client.subscribe("hotel/security/event", self._on_security_event)

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
                self.root.after(5000, lambda: self.sos_btn.config(text="🚨 110一键报警", bg="red", fg="white"))
            
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
            
            if action == 'issue':
                # 设置目标房间
                if room_number:
                    self.target_room_var.set(room_number)
                # 执行开卡
                success, msg = self.rfid.issue_card(room_number or self.target_room_var.get())
                self.root.after(0, self._draw_card)
                self._beep(1 if success else 2)
                if success:
                    self._update_led(0, 255, 0)
                    self._update_room_status_on_wall(room_number, "check_in")
                    self._log(f"[Web指令] 发卡成功: 房间 {room_number}")
                    # 上报发卡成功事件
                    if self.mqtt_client and self.connected:
                        self.mqtt_client.publish_security_event("card_issued", level="info", event_data={
                            "room_id": room_number,
                            "booking_id": booking_id,
                            "action": "issue",
                            "operator": self.device_id
                        })
                else:
                    self._update_led(255, 0, 0)
                    self._log(f"[Web指令] 发卡失败: {msg}", "ERROR")
                self.root.after(3000, lambda: self._update_led(0, 0, 255))
                return success
            
            elif action == 'revoke':
                # 执行退卡
                self.rfid.remove_card()
                self.root.after(0, self._draw_card)
                self._beep(1)
                self._update_led(255, 165, 0)  # 橙色表示退卡
                self._update_room_status_on_wall(room_number, "check_out")
                self._log(f"[Web指令] 退卡成功: 房间 {room_number}")
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
