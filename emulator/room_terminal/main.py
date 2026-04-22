"""
客房终端仿真器 - 主程序
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
import base64
from datetime import datetime
from common.device_base import BaseDeviceEmulator
from common.config import (
    CMD_LIGHT, CMD_AIR, CMD_CURTAIN, CMD_DOOR, CMD_SCENE,
    CMD_INCOMING_CALL, CMD_HANGUP_CALL,
    CMD_VAL_ON, CMD_VAL_OFF, CMD_VAL_UNLOCK, CMD_VAL_LOCK,
    CMD_VAL_OPEN, CMD_VAL_CLOSE,
    CMD_VAL_WELCOME, CMD_VAL_SLEEP, CMD_VAL_LEAVE, CMD_VAL_READING,
    SENSOR_TEMPERATURE, SENSOR_HUMIDITY, SENSOR_LIGHT, SENSOR_DOOR,
    TOPIC_AI_REQUEST, TOPIC_AI_RESPONSE,
    TOPIC_DEVICE_COMMAND_PREFIX
)


class RoomTerminalEmulator(BaseDeviceEmulator):
    def __init__(self, root):
        self.room_id = "301"
        self.device_id = f"room_{self.room_id}"

        self.light_on = False
        self.air_on = False
        self.temp_val = 26
        self.curtain_open = False
        self.door_unlocked = False
        self.ai_conversation = []
        self.is_recording = False
        self.audio_frames = []
        self.pyaudio_instance = None
        self.audio_stream = None
        self._door_relock_timer = None

        self._stop_sensors = threading.Event()

        super().__init__(
            root=root,
            title=f"智慧酒店 - 客房终端仿真器",
            device_id=self.device_id,
            device_type="room",
            width=950,
            height=850
        )

        self._sync_room_info()

    def _sync_room_info(self):
        old_room_id = self.room_id
        if self.room_id_var.get():
            self.room_id = self.room_id_var.get()
            # 不重建 device_id，保持配置中的原始 device_id
            self._log(f"已同步房间信息: ID={self.room_id}, 编号={self.room_number_var.get()}")

            if old_room_id != self.room_id and self.mqtt_client and self.connected:
                new_topic = TOPIC_AI_RESPONSE.format(self.device_id)
                self.mqtt_client.subscribe(new_topic)
                self._log(f"已重新订阅 AI 主题: {new_topic}")

    def _on_config_updated(self):
        self._sync_room_info()
        self._update_oled()
        if hasattr(self, 'room_num_entry'):
            self.room_num_entry.delete(0, tk.END)
            self.room_num_entry.insert(0, self.room_number_var.get() or self.room_id)
        self._log("收到云端配置更新，已重载界面")

    def _apply_room_change(self):
        new_num = self.room_num_entry.get().strip()
        if not new_num:
            messagebox.showwarning("提示", "请输入有效的房间号")
            return

        self._log(f"正在申请变更房间号为: {new_num}...")
        self.room_number_var.set(new_num)
        self._register_device_to_web()

    def _init_biz_ui(self):
        self._create_card(self.biz_frame, "OLED 状态显示屏").pack(fill=tk.X, pady=(0, 20))
        oled_body = self.last_card_body

        self.oled_canvas = tk.Canvas(oled_body, width=600, height=140, bg="black", highlightthickness=0)
        self.oled_canvas.pack(pady=5, expand=True)
        self._update_oled()

        ctrl_container = tk.Frame(self.biz_frame, bg=self.colors['bg'])
        ctrl_container.pack(fill=tk.X, pady=(0, 20))

        btn_style = {"width": 10, "relief": tk.FLAT, "font": ("Arial", 10, "bold"), "pady": 8}

        left_ctrl = tk.Frame(ctrl_container, bg=self.colors['bg'])
        left_ctrl.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=(0, 10))
        self._create_card(left_ctrl, "基础电器控制").pack(fill=tk.BOTH, expand=True)
        elec_body = self.last_card_body

        light_f = tk.Frame(elec_body, bg="white")
        light_f.pack(fill=tk.X, pady=8)
        tk.Label(light_f, text="💡 房间主灯:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        self.light_btn = tk.Button(light_f, text="OFF", bg="#595959", fg="white",
                                  command=self._toggle_light, **btn_style)
        self.light_btn.pack(side=tk.RIGHT)

        curtain_f = tk.Frame(elec_body, bg="white")
        curtain_f.pack(fill=tk.X, pady=8)
        tk.Label(curtain_f, text="🪟 电动窗帘:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        self.curtain_btn = tk.Button(curtain_f, text="已关闭", bg="#595959", fg="white",
                                    command=self._toggle_curtain, **btn_style)
        self.curtain_btn.pack(side=tk.RIGHT)

        door_f = tk.Frame(elec_body, bg="white")
        door_f.pack(fill=tk.X, pady=8)
        tk.Label(door_f, text="🚪 智能门锁:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        self.door_btn = tk.Button(door_f, text="已锁定", bg=self.colors['success'], fg="white",
                                 command=self._toggle_door, **btn_style)
        self.door_btn.pack(side=tk.RIGHT)

        right_ctrl = tk.Frame(ctrl_container, bg=self.colors['bg'])
        right_ctrl.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=(10, 0))
        self._create_card(right_ctrl, "室内环境调节").pack(fill=tk.BOTH, expand=True)
        env_body = self.last_card_body

        ac_f = tk.Frame(env_body, bg="white")
        ac_f.pack(fill=tk.X, pady=8)
        tk.Label(ac_f, text="❄️ 变频空调:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        self.ac_btn = tk.Button(ac_f, text="OFF", bg="#595959", fg="white",
                               command=self._toggle_ac, **btn_style)
        self.ac_btn.pack(side=tk.RIGHT)

        temp_f = tk.Frame(env_body, bg="white")
        temp_f.pack(fill=tk.X, pady=12)
        tk.Label(temp_f, text="设定温度:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        tk.Button(temp_f, text="-", width=4, font=("Arial", 10, "bold"), command=lambda: self._adj_temp(-1)).pack(side=tk.RIGHT, padx=2)
        self.temp_label = tk.Label(temp_f, text=f"{self.temp_val}℃", font=("Arial", 12, "bold"), bg="white", fg=self.colors['danger'])
        self.temp_label.pack(side=tk.RIGHT, padx=15)
        tk.Button(temp_f, text="+", width=4, font=("Arial", 10, "bold"), command=lambda: self._adj_temp(1)).pack(side=tk.RIGHT, padx=2)

        scene_f = tk.Frame(env_body, bg="white")
        scene_f.pack(fill=tk.X, pady=8)
        tk.Label(scene_f, text="🎭 场景模式:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        scene_btn_f = tk.Frame(scene_f, bg="white")
        scene_btn_f.pack(side=tk.RIGHT)
        for label, mode in [("迎宾", CMD_VAL_WELCOME), ("阅读", CMD_VAL_READING), ("睡眠", CMD_VAL_SLEEP)]:
            tk.Button(scene_btn_f, text=label, bg=self.colors['primary'], fg="white",
                     command=lambda m=mode: self._apply_scene(m),
                     relief=tk.FLAT, font=("Arial", 9, "bold"), padx=8, pady=4).pack(side=tk.LEFT, padx=3)

        self._create_card(self.biz_frame, "房间资产设置").pack(fill=tk.X, pady=(0, 20))
        room_settings_body = self.last_card_body

        settings_f = tk.Frame(room_settings_body, bg="white")
        settings_f.pack(fill=tk.X)

        tk.Label(settings_f, text="当前房号:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        self.room_num_entry = tk.Entry(settings_f, width=10, font=("Arial", 10, "bold"))
        self.room_num_entry.insert(0, self.room_number_var.get() or self.room_id)
        self.room_num_entry.pack(side=tk.LEFT, padx=10)

        tk.Button(settings_f, text="应用并同步", bg=self.colors['primary'], fg="white",
                  command=self._apply_room_change, relief=tk.FLAT, font=("Arial", 9, "bold"), padx=10).pack(side=tk.LEFT)

        self._create_card(self.biz_frame, "AI 语音交互管家").pack(fill=tk.BOTH, expand=True)
        ai_body = self.last_card_body

        input_container = tk.Frame(ai_body, bg="white")
        input_container.pack(fill=tk.X, side=tk.BOTTOM, pady=(10, 0))

        self.mic_btn = tk.Button(input_container, text="🎤 语音输入", bg=self.colors['primary'], fg="white",
                                command=self._toggle_mic, relief=tk.FLAT, font=("Arial", 10, "bold"),
                                padx=20, pady=8)
        self.mic_btn.pack(side=tk.RIGHT, padx=(10, 0))

        input_inner = tk.Frame(input_container, bg="#f5f5f5", padx=2, pady=2)
        input_inner.pack(side=tk.LEFT, fill=tk.X, expand=True)

        self.ai_input = tk.Entry(input_inner, font=("Arial", 11), bd=0, bg="#f5f5f5",
                                 highlightthickness=0)
        self.ai_input.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=10, pady=8)
        self.ai_input.bind("<Return>", lambda e: self._send_ai())

        self.ai_chat = scrolledtext.ScrolledText(ai_body, height=10, bg="#f9f9f9", bd=0,
                                                 font=("Microsoft YaHei", 10), padx=15, pady=15)
        self.ai_chat.pack(fill=tk.BOTH, expand=True, pady=(0, 10))
        self.ai_chat.config(state=tk.DISABLED)
        self._add_chat("assistant", "您好，我是您的智能管家。您可以对我说\"开灯\"、\"帮我叫前台\"或者\"我想睡觉了\"。")

    def _update_oled(self):
        self.oled_canvas.delete("all")
        w = 600
        h = 140
        self.oled_canvas.create_rectangle(0, 0, w, h, fill="#000000")
        self.oled_canvas.create_rectangle(5, 5, w-5, h-5, outline="#333333", width=1)

        display_room = self.room_number_var.get() or self.room_id
        self.oled_canvas.create_text(30, 40, text=f"ROOM: {display_room}", fill="#00FF00", font=("Consolas", 22, "bold"), anchor=tk.W)
        self.oled_canvas.create_text(30, 80, text=f"TEMP: {self.temp_val}C | HUMI: 55%", fill="white", font=("Consolas", 14), anchor=tk.W)
        status_str = f"LIGHT: {'ON' if self.light_on else 'OFF'} | AC: {'ON' if self.air_on else 'OFF'} | DOOR: {'OPEN' if self.door_unlocked else 'LOCKED'}"
        self.oled_canvas.create_text(30, 115, text=status_str, fill="#1890ff", font=("Consolas", 12), anchor=tk.W)

        if self.connected:
            self.oled_canvas.create_text(w-30, 30, text="● Online", fill="#52c41a", font=("Arial", 9, "bold"), anchor=tk.E)
        else:
            self.oled_canvas.create_text(w-30, 30, text="● Offline", fill="#ff4d4f", font=("Arial", 9, "bold"), anchor=tk.E)

    def _add_chat(self, role, msg):
        self.ai_chat.config(state=tk.NORMAL)
        tag = "user" if role == "user" else "ai"
        prefix = "👤 您: " if role == "user" else "🤖 管家: "
        color = self.colors['primary'] if role == "user" else "#333333"
        self.ai_chat.insert(tk.END, f"{prefix}{msg}\n\n", tag)
        self.ai_chat.tag_config(tag, foreground=color)
        self.ai_chat.see(tk.END)
        self.ai_chat.config(state=tk.DISABLED)

    def _toggle_light(self, from_cloud=False):
        self.light_on = not self.light_on
        status = "ON" if self.light_on else "OFF"
        color = self.colors['success'] if self.light_on else "#595959"
        self.light_btn.config(text=status, bg=color)
        self._update_oled()
        self._log(f"{'[云端]' if from_cloud else '[本地]'} 灯光已切换至 {status}")
        if not from_cloud:
            self._report_device_event("light_changed", "on" if self.light_on else "off")

    def _set_light(self, on, from_cloud=False):
        if self.light_on == on:
            return
        self.light_on = on
        status = "ON" if self.light_on else "OFF"
        color = self.colors['success'] if self.light_on else "#595959"
        self.light_btn.config(text=status, bg=color)
        self._update_oled()
        self._log(f"{'[云端]' if from_cloud else '[本地]'} 灯光已切换至 {status}")

    def _toggle_ac(self, from_cloud=False):
        self.air_on = not self.air_on
        status = "ON" if self.air_on else "OFF"
        color = self.colors['success'] if self.air_on else "#595959"
        self.ac_btn.config(text=status, bg=color)
        self._update_oled()
        self._log(f"{'[云端]' if from_cloud else '[本地]'} 空调已切换至 {status}")
        if not from_cloud:
            self._report_device_event("air_changed", "on" if self.air_on else "off")

    def _set_ac(self, on, from_cloud=False):
        if self.air_on == on:
            return
        self.air_on = on
        status = "ON" if self.air_on else "OFF"
        color = self.colors['success'] if self.air_on else "#595959"
        self.ac_btn.config(text=status, bg=color)
        self._update_oled()
        self._log(f"{'[云端]' if from_cloud else '[本地]'} 空调已切换至 {status}")

    def _adj_temp(self, delta, from_cloud=False):
        self.temp_val = max(16, min(30, self.temp_val + delta))
        self.temp_label.config(text=f"{self.temp_val}℃")
        self._update_oled()
        self._log(f"{'[云端]' if from_cloud else '[本地]'} 调节温度至 {self.temp_val}℃")

    def _set_temp(self, temp, from_cloud=False):
        try:
            temp_int = int(temp)
            if 16 <= temp_int <= 30:
                self.temp_val = temp_int
                self.temp_label.config(text=f"{self.temp_val}℃")
                self._update_oled()
                self._log(f"{'[云端]' if from_cloud else '[本地]'} 设定温度至 {self.temp_val}℃")
        except (ValueError, TypeError):
            self._log(f"无效温度值: {temp}", "WARNING")

    def _toggle_curtain(self, from_cloud=False):
        self.curtain_open = not self.curtain_open
        status = "已开启" if self.curtain_open else "已关闭"
        self.curtain_btn.config(text=status, bg=self.colors['primary'] if self.curtain_open else "#595959")
        self._log(f"{'[云端]' if from_cloud else '[本地]'} 窗帘{status}")
        if not from_cloud:
            self._report_device_event("curtain_changed", "open" if self.curtain_open else "close")

    def _set_curtain(self, open_val, from_cloud=False):
        if self.curtain_open == open_val:
            return
        self.curtain_open = open_val
        status = "已开启" if self.curtain_open else "已关闭"
        self.curtain_btn.config(text=status, bg=self.colors['primary'] if self.curtain_open else "#595959")
        self._log(f"{'[云端]' if from_cloud else '[本地]'} 窗帘{status}")

    def _toggle_door(self, from_cloud=False):
        self.door_unlocked = not self.door_unlocked
        status = "已开启" if self.door_unlocked else "已锁定"
        self.door_btn.config(text=status, bg=self.colors['danger'] if self.door_unlocked else self.colors['success'])
        self._update_oled()
        self._log(f"{'[云端]' if from_cloud else '[本地]'} 门锁{status}")

        if self._door_relock_timer:
            self.root.after_cancel(self._door_relock_timer)
            self._door_relock_timer = None

        if self.door_unlocked:
            self._door_relock_timer = self.root.after(8000, self._auto_relock_door)
            self._log("门锁将在8秒后自动回锁")

    def _unlock_door(self, from_cloud=False):
        if self.door_unlocked:
            return
        self.door_unlocked = True
        self.door_btn.config(text="已开启", bg=self.colors['danger'])
        self._update_oled()
        self._log(f"{'[云端]' if from_cloud else '[本地]'} 门锁已开启")

        if self._door_relock_timer:
            self.root.after_cancel(self._door_relock_timer)
        self._door_relock_timer = self.root.after(8000, self._auto_relock_door)
        self._log("门锁将在8秒后自动回锁")

    def _lock_door(self, from_cloud=False):
        if not self.door_unlocked:
            return
        self.door_unlocked = False
        self.door_btn.config(text="已锁定", bg=self.colors['success'])
        self._update_oled()
        self._log(f"{'[云端]' if from_cloud else '[本地]'} 门锁已锁定")

        if self._door_relock_timer:
            self.root.after_cancel(self._door_relock_timer)
            self._door_relock_timer = None

    def _auto_relock_door(self):
        if self.door_unlocked:
            self.door_unlocked = False
            self.door_btn.config(text="已锁定", bg=self.colors['success'])
            self._update_oled()
            self._log("门锁已自动回锁")
            self._door_relock_timer = None

            if self.mqtt_client and self.connected:
                self.mqtt_client.publish_sensor_data(SENSOR_DOOR, "locked", "status")

    def _apply_scene(self, scene):
        self._log(f"正在执行场景模式: {scene}")
        if scene == CMD_VAL_WELCOME:
            self._set_light(True, from_cloud=True)
            self._set_ac(True, from_cloud=True)
            self._set_curtain(True, from_cloud=True)
            self._set_temp(24, from_cloud=True)
            self._log("迎宾模式：灯光开启、空调开启、窗帘开启、温度24℃")
        elif scene == CMD_VAL_READING:
            self._set_light(True, from_cloud=True)
            self._set_ac(True, from_cloud=True)
            self._set_curtain(False, from_cloud=True)
            self._set_temp(25, from_cloud=True)
            self._log("阅读模式：灯光开启、空调开启、窗帘关闭、温度25℃")
        elif scene == CMD_VAL_SLEEP:
            self._set_light(False, from_cloud=True)
            self._set_curtain(False, from_cloud=True)
            self._set_temp(26, from_cloud=True)
            if self.air_on:
                pass
            else:
                self._set_ac(True, from_cloud=True)
            self._log("睡眠模式：灯光关闭、窗帘关闭、空调26℃")
        elif scene == CMD_VAL_LEAVE:
            self._set_light(False, from_cloud=True)
            self._set_ac(False, from_cloud=True)
            self._set_curtain(False, from_cloud=True)
            self._log("外出模式：所有设备已关闭")

    def _sensor_loop(self):
        while not self._stop_sensors.is_set():
            if self.mqtt_client and self.connected:
                temp = round(random.uniform(22, 28), 1)
                humi = random.randint(40, 65)
                light_val = random.randint(50, 300)

                self.mqtt_client.publish_sensor_data(SENSOR_TEMPERATURE, temp, "℃")
                self.mqtt_client.publish_sensor_data(SENSOR_HUMIDITY, humi, "%")
                self.mqtt_client.publish_sensor_data(SENSOR_LIGHT, light_val, "lx")
                self.mqtt_client.publish_sensor_data(SENSOR_DOOR, "unlocked" if self.door_unlocked else "locked", "status")

                self._log(f"传感器数据已上报: 温度={temp}℃ 湿度={humi}% 光照={light_val}lx 门锁={'开' if self.door_unlocked else '锁'}")
            time.sleep(15)

    def _send_ai(self):
        text = self.ai_input.get().strip()
        if not text:
            return
        self.ai_input.delete(0, tk.END)
        self._add_chat("user", text)

        if self.mqtt_client and self.connected:
            self.ai_status_var.set("思考中...")
            self.mqtt_client.publish(TOPIC_AI_REQUEST.format(self.device_id), {
                "room_id": self.device_id,
                "device_id": self.device_id,
                "text": text,
                "timestamp": datetime.now().isoformat()
            })
        else:
            self._add_chat("assistant", "对不起，网络未连接，无法提供AI服务。")

    def _toggle_mic(self):
        try:
            import pyaudio
        except ImportError:
            self._log("未检测到 pyaudio 库，将使用模拟语音输入。", "WARNING")
            self._toggle_mic_simulated()
            return

        if not self.is_recording:
            self._start_real_recording(pyaudio)
        else:
            self._stop_real_recording()

    def _start_real_recording(self, pyaudio_module):
        try:
            self.is_recording = True
            self.mic_btn.config(text="🛑 停止", bg=self.colors['danger'])
            self.ai_status_var.set("正在聆听...")
            self._log("开始录音...")

            self.audio_frames = []
            self.pyaudio_instance = pyaudio_module.PyAudio()

            self.audio_stream = self.pyaudio_instance.open(
                format=pyaudio_module.paInt16,
                channels=1,
                rate=16000,
                input=True,
                frames_per_buffer=1024
            )

            def record_thread():
                while self.is_recording:
                    try:
                        data = self.audio_stream.read(1024, exception_on_overflow=False)
                        self.audio_frames.append(data)
                    except Exception as e:
                        print(f"录音数据读取错误: {e}")
                        break

            threading.Thread(target=record_thread, daemon=True).start()

        except Exception as e:
            self._log(f"无法打开麦克风: {e}", "ERROR")
            self.is_recording = False
            self.mic_btn.config(text="🎤 语音", bg=self.colors['primary'])
            self.ai_status_var.set("空闲")

    def _stop_real_recording(self):
        self.is_recording = False
        self.mic_btn.config(text="🎤 语音", bg=self.colors['primary'])
        self.ai_status_var.set("处理中...")
        self._log("停止录音，正在上传至后端 ASR...")

        try:
            if self.audio_stream:
                self.audio_stream.stop_stream()
                self.audio_stream.close()

            if self.pyaudio_instance:
                self.pyaudio_instance.terminate()

            raw_pcm = b''.join(self.audio_frames)

            if not raw_pcm:
                self._log("未采集到有效音频数据", "WARNING")
                self.ai_status_var.set("空闲")
                return

            audio_base64 = base64.b64encode(raw_pcm).decode('utf-8')

            if self.mqtt_client and self.connected:
                self.ai_status_var.set("思考中...")
                self.mqtt_client.publish(TOPIC_AI_REQUEST.format(self.device_id), {
                    "room_id": self.device_id,
                    "device_id": self.device_id,
                    "audio_data": audio_base64,
                    "timestamp": datetime.now().isoformat()
                })
                self._add_chat("user", "[语音消息]")
            else:
                self._add_chat("assistant", "网络未连接，无法上传语音。")

        except Exception as e:
            self._log(f"录音处理失败: {e}", "ERROR")
            self.ai_status_var.set("空闲")

    def _toggle_mic_simulated(self):
        if not self.is_recording:
            self.is_recording = True
            self.mic_btn.config(text="🛑 停止", bg=self.colors['danger'])
            self.ai_status_var.set("正在聆听...")
            self.root.after(3000, self._toggle_mic)
        else:
            self.is_recording = False
            self.mic_btn.config(text="🎤 语音", bg=self.colors['primary'])
            self.ai_status_var.set("识别中...")
            sim_text = random.choice(["帮我开灯", "调高两度", "现在几点了", "我想看电影"])
            self.ai_input.insert(0, sim_text)
            self._send_ai()

    def _report_device_event(self, event, val):
        if self.mqtt_client and self.connected:
            self.mqtt_client.publish(f"hotel/device/event/room/{self.room_id}", {
                "device_id": self.device_id,
                "event": event,
                "value": val,
                "timestamp": datetime.now().isoformat()
            })

    def _on_connected(self):
        ai_topic = TOPIC_AI_RESPONSE.format(self.device_id)
        self.mqtt_client.subscribe(ai_topic)
        self._log(f"已订阅 AI 主题: {ai_topic}")

        cmd_topic = f"{TOPIC_DEVICE_COMMAND_PREFIX}/room/{self.device_id}"
        self.mqtt_client.subscribe(cmd_topic)
        self._log(f"已订阅客房指令主题: {cmd_topic}")

        self._register_command_handlers()

        self._stop_sensors.clear()
        threading.Thread(target=self._sensor_loop, daemon=True).start()
        self._log("传感器数据上报已启动(15秒间隔)")

    def _register_command_handlers(self):
        self.mqtt_client.register_command_handler(f"{CMD_LIGHT}:{CMD_VAL_ON}", self._handle_light_on)
        self.mqtt_client.register_command_handler(f"{CMD_LIGHT}:{CMD_VAL_OFF}", self._handle_light_off)
        self.mqtt_client.register_command_handler(f"{CMD_AIR}:{CMD_VAL_ON}", self._handle_air_on)
        self.mqtt_client.register_command_handler(f"{CMD_AIR}:{CMD_VAL_OFF}", self._handle_air_off)
        self.mqtt_client.register_command_handler(CMD_AIR, self._handle_air_cmd)
        self.mqtt_client.register_command_handler(f"{CMD_CURTAIN}:{CMD_VAL_OPEN}", self._handle_curtain_open)
        self.mqtt_client.register_command_handler(f"{CMD_CURTAIN}:{CMD_VAL_CLOSE}", self._handle_curtain_close)
        self.mqtt_client.register_command_handler(f"{CMD_DOOR}:{CMD_VAL_UNLOCK}", self._handle_door_unlock)
        self.mqtt_client.register_command_handler(f"{CMD_DOOR}:{CMD_VAL_LOCK}", self._handle_door_lock)
        self.mqtt_client.register_command_handler(f"{CMD_SCENE}:{CMD_VAL_WELCOME}", self._handle_scene_welcome)
        self.mqtt_client.register_command_handler(f"{CMD_SCENE}:{CMD_VAL_SLEEP}", self._handle_scene_sleep)
        self.mqtt_client.register_command_handler(f"{CMD_SCENE}:{CMD_VAL_LEAVE}", self._handle_scene_leave)
        self.mqtt_client.register_command_handler(f"{CMD_SCENE}:{CMD_VAL_READING}", self._handle_scene_reading)
        self.mqtt_client.register_command_handler(CMD_INCOMING_CALL, self._handle_incoming_call)
        self.mqtt_client.register_command_handler(CMD_HANGUP_CALL, self._handle_hangup_call)

    def _handle_light_on(self, data):
        self.root.after(0, lambda: self._set_light(True, from_cloud=True))
        return True

    def _handle_light_off(self, data):
        self.root.after(0, lambda: self._set_light(False, from_cloud=True))
        return True

    def _handle_air_on(self, data):
        self.root.after(0, lambda: self._set_ac(True, from_cloud=True))
        return True

    def _handle_air_off(self, data):
        self.root.after(0, lambda: self._set_ac(False, from_cloud=True))
        return True

    def _handle_air_cmd(self, data):
        cmd_value = data.get('command_value', '')
        if cmd_value == CMD_VAL_ON:
            self.root.after(0, lambda: self._set_ac(True, from_cloud=True))
        elif cmd_value == CMD_VAL_OFF:
            self.root.after(0, lambda: self._set_ac(False, from_cloud=True))
        elif cmd_value.startswith('temp:'):
            temp_str = cmd_value.split(':')[1]
            self.root.after(0, lambda: self._set_temp(temp_str, from_cloud=True))
            self.root.after(0, lambda: self._set_ac(True, from_cloud=True))
        return True

    def _handle_curtain_open(self, data):
        self.root.after(0, lambda: self._set_curtain(True, from_cloud=True))
        return True

    def _handle_curtain_close(self, data):
        self.root.after(0, lambda: self._set_curtain(False, from_cloud=True))
        return True

    def _handle_door_unlock(self, data):
        self.root.after(0, lambda: self._unlock_door(from_cloud=True))
        return True

    def _handle_door_lock(self, data):
        self.root.after(0, lambda: self._lock_door(from_cloud=True))
        return True

    def _handle_scene_welcome(self, data):
        self.root.after(0, lambda: self._apply_scene(CMD_VAL_WELCOME))
        return True

    def _handle_scene_sleep(self, data):
        self.root.after(0, lambda: self._apply_scene(CMD_VAL_SLEEP))
        return True

    def _handle_scene_leave(self, data):
        self.root.after(0, lambda: self._apply_scene(CMD_VAL_LEAVE))
        return True

    def _handle_scene_reading(self, data):
        self.root.after(0, lambda: self._apply_scene(CMD_VAL_READING))
        return True

    def _handle_incoming_call(self, data):
        caller = data.get('created_by', '前台')
        self._log(f"收到来电: {caller}")
        self._add_chat("assistant", f"📞 {caller}正在呼叫您...")
        return True

    def _handle_hangup_call(self, data):
        self._log("通话已结束")
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

    def _on_ai_response(self, data):
        text = data.get('response') or data.get('text')
        self.root.after(0, lambda: self._add_chat("assistant", text))
        self.root.after(0, lambda: self.ai_status_var.set("空闲"))
        self._log(f"AI 回复已收到 (长度:{len(text or '')})")


if __name__ == "__main__":
    root = tk.Tk()
    app = RoomTerminalEmulator(root)
    app.run()
