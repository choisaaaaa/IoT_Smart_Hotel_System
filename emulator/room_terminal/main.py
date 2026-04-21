"""
客房终端仿真器 - 主程序 (现代化美化版)
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
import tempfile
import io
import wave
from datetime import datetime
from common.device_base import BaseDeviceEmulator
from common.config import (
    CMD_LIGHT_ON, CMD_LIGHT_OFF,
    CMD_AIR_ON, CMD_AIR_OFF,
    CMD_CURTAIN_OPEN, CMD_CURTAIN_CLOSE,
    CMD_DOOR_UNLOCK, CMD_DOOR_LOCK,
    CMD_INCOMING_CALL, CMD_HANGUP_CALL,
    CMD_SCENE_WELCOME, CMD_SCENE_READING, CMD_SCENE_NIGHT, CMD_SCENE_SLEEP, CMD_SCENE_NEXT,
    TOPIC_AI_RESPONSE, TOPIC_AI_REQUEST
)

class RoomTerminalEmulator(BaseDeviceEmulator):
    """客房终端仿真器"""

    def __init__(self, root):
        self.room_id = "301"
        self.device_id = f"room_{self.room_id}"
        
        # 内部状态
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

        super().__init__(
            root=root,
            title=f"智慧酒店 - 客房终端仿真器 ({self.device_id})",
            device_id=self.device_id,
            device_type="room",
            width=950,
            height=850
        )

    def _init_biz_ui(self):
        """初始化客房特有的业务界面"""
        # 1. 顶部 OLED 模拟屏
        self._create_card(self.biz_frame, "OLED 状态显示屏").pack(fill=tk.X, pady=(0, 20))
        oled_body = self.last_card_body
        
        self.oled_canvas = tk.Canvas(oled_body, width=600, height=140, bg="black", highlightthickness=0)
        self.oled_canvas.pack(pady=5, expand=True)
        self._update_oled()

        # 2. 设备控制中心 (两列布局)
        ctrl_container = tk.Frame(self.biz_frame, bg=self.colors['bg'])
        ctrl_container.pack(fill=tk.X, pady=(0, 20))
        
        # 统一控制按钮高度和样式
        btn_style = {"width": 10, "relief": tk.FLAT, "font": ("Arial", 10, "bold"), "pady": 8}

        # 左侧: 基础电器
        left_ctrl = tk.Frame(ctrl_container, bg=self.colors['bg'])
        left_ctrl.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=(0, 10))
        self._create_card(left_ctrl, "基础电器控制").pack(fill=tk.BOTH, expand=True)
        elec_body = self.last_card_body
        
        # 灯光
        light_f = tk.Frame(elec_body, bg="white")
        light_f.pack(fill=tk.X, pady=8)
        tk.Label(light_f, text="💡 房间主灯:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        self.light_btn = tk.Button(light_f, text="OFF", bg="#595959", fg="white", 
                                  command=self._toggle_light, **btn_style)
        self.light_btn.pack(side=tk.RIGHT)

        # 窗帘
        curtain_f = tk.Frame(elec_body, bg="white")
        curtain_f.pack(fill=tk.X, pady=8)
        tk.Label(curtain_f, text="🪟 电动窗帘:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        self.curtain_btn = tk.Button(curtain_f, text="已关闭", bg="#595959", fg="white", 
                                    command=self._toggle_curtain, **btn_style)
        self.curtain_btn.pack(side=tk.RIGHT)

        # 门锁
        door_f = tk.Frame(elec_body, bg="white")
        door_f.pack(fill=tk.X, pady=8)
        tk.Label(door_f, text="🚪 智能门锁:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        self.door_btn = tk.Button(door_f, text="已锁定", bg=self.colors['success'], fg="white", 
                                 command=self._toggle_door, **btn_style)
        self.door_btn.pack(side=tk.RIGHT)

        # 右侧: 环境调节
        right_ctrl = tk.Frame(ctrl_container, bg=self.colors['bg'])
        right_ctrl.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=(10, 0))
        self._create_card(right_ctrl, "室内环境调节").pack(fill=tk.BOTH, expand=True)
        env_body = self.last_card_body
        
        # 空调
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

        # 3. AI 语音助手对话框
        self._create_card(self.biz_frame, "AI 语音交互管家").pack(fill=tk.BOTH, expand=True)
        ai_body = self.last_card_body
        
        # 输入框容器 - 先 pack 底部容器，确保它可见
        input_container = tk.Frame(ai_body, bg="white")
        input_container.pack(fill=tk.X, side=tk.BOTTOM, pady=(10, 0))
        
        # 语音按钮固定在右侧
        self.mic_btn = tk.Button(input_container, text="🎤 语音输入", bg=self.colors['primary'], fg="white", 
                                command=self._toggle_mic, relief=tk.FLAT, font=("Arial", 10, "bold"),
                                padx=20, pady=8)
        self.mic_btn.pack(side=tk.RIGHT, padx=(10, 0))

        # 输入框背景占据剩余空间
        input_inner = tk.Frame(input_container, bg="#f5f5f5", padx=2, pady=2)
        input_inner.pack(side=tk.LEFT, fill=tk.X, expand=True)
        
        self.ai_input = tk.Entry(input_inner, font=("Arial", 11), bd=0, bg="#f5f5f5", 
                                 highlightthickness=0)
        self.ai_input.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=10, pady=8)
        self.ai_input.bind("<Return>", lambda e: self._send_ai())

        # 聊天记录 - 最后 pack 并设置 expand=True，它会占据中间剩余的所有空间
        self.ai_chat = scrolledtext.ScrolledText(ai_body, height=10, bg="#f9f9f9", bd=0, 
                                                 font=("Microsoft YaHei", 10), padx=15, pady=15)
        self.ai_chat.pack(fill=tk.BOTH, expand=True, pady=(0, 10))
        self.ai_chat.config(state=tk.DISABLED)
        self._add_chat("assistant", "您好，我是您的智能管家。您可以对我说“开灯”、“帮我叫前台”或者“我想睡觉了”。")

    # --- 业务逻辑 ---
    def _update_oled(self):
        self.oled_canvas.delete("all")
        w = 600
        h = 140
        # 绘制背景
        self.oled_canvas.create_rectangle(0, 0, w, h, fill="#000000")
        # 装饰性边框
        self.oled_canvas.create_rectangle(5, 5, w-5, h-5, outline="#333333", width=1)
        
        # 房间信息
        self.oled_canvas.create_text(30, 40, text=f"ROOM: {self.room_id}", fill="#00FF00", font=("Consolas", 22, "bold"), anchor=tk.W)
        self.oled_canvas.create_text(30, 80, text=f"TEMP: {self.temp_val}C | HUMI: 55%", fill="white", font=("Consolas", 14), anchor=tk.W)
        status_str = f"LIGHT: {'ON' if self.light_on else 'OFF'} | AC: {'ON' if self.air_on else 'OFF'} | DOOR: {'OPEN' if self.door_unlocked else 'LOCKED'}"
        self.oled_canvas.create_text(30, 115, text=status_str, fill="#1890ff", font=("Consolas", 12), anchor=tk.W)
        
        # 模拟动画
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
        if not from_cloud: self._report_event("light_changed", "on" if self.light_on else "off")

    def _toggle_ac(self, from_cloud=False):
        self.air_on = not self.air_on
        status = "ON" if self.air_on else "OFF"
        color = self.colors['success'] if self.air_on else "#595959"
        self.ac_btn.config(text=status, bg=color)
        self._update_oled()
        self._log(f"{'[云端]' if from_cloud else '[本地]'} 空调已切换至 {status}")

    def _adj_temp(self, delta):
        self.temp_val = max(16, min(30, self.temp_val + delta))
        self.temp_label.config(text=f"{self.temp_val}℃")
        self._update_oled()
        self._log(f"调节温度至 {self.temp_val}℃")

    def _toggle_curtain(self):
        self.curtain_open = not self.curtain_open
        status = "已开启" if self.curtain_open else "已关闭"
        self.curtain_btn.config(text=status, bg=self.colors['primary'] if self.curtain_open else "#595959")
        self._log(f"窗帘{status}")

    def _toggle_door(self):
        self.door_unlocked = not self.door_unlocked
        status = "已开启" if self.door_unlocked else "已锁定"
        self.door_btn.config(text=status, bg=self.colors['danger'] if self.door_unlocked else self.colors['success'])
        self._log(f"门锁{status}")
        if self.door_unlocked: # 5秒后自动锁定
            self.root.after(5000, lambda: self._toggle_door() if self.door_unlocked else None)

    def _send_ai(self):
        text = self.ai_input.get().strip()
        if not text: return
        self.ai_input.delete(0, tk.END)
        self._add_chat("user", text)
        
        if self.mqtt_client and self.connected:
            self.ai_status_var.set("思考中...")
            self.mqtt_client.publish(TOPIC_AI_REQUEST.format(self.room_id), {
                "room_id": self.room_id, "device_id": self.device_id, "text": text,
                "timestamp": datetime.now().isoformat()
            })
        else:
            self._add_chat("assistant", "对不起，网络未连接，无法提供AI服务。")

    def _toggle_mic(self):
        try:
            import pyaudio
        except ImportError:
            self._log("未检测到 pyaudio 库，将使用模拟语音输入。请运行 'pip install pyaudio' 以启用真实录音。", "WARNING")
            self._toggle_mic_simulated()
            return

        if not self.is_recording:
            self._start_real_recording(pyaudio)
        else:
            self._stop_real_recording()

    def _start_real_recording(self, pyaudio_module):
        """开始真实的硬件录音"""
        try:
            self.is_recording = True
            self.mic_btn.config(text="🛑 停止", bg=self.colors['danger'])
            self.ai_status_var.set("正在聆听...")
            self._log("开始录音...")
            
            self.audio_frames = []
            self.pyaudio_instance = pyaudio_module.PyAudio()
            
            # 配置录音参数 (16k, 单声道, 16bit - ASR 通用标准)
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
        """停止录音并发送数据"""
        self.is_recording = False
        self.mic_btn.config(text="🎤 语音", bg=self.colors['primary'])
        self.ai_status_var.set("处理中...")
        self._log("停止录音，正在上传至后端 ASR...")
        
        try:
            # 停止流
            if self.audio_stream:
                self.audio_stream.stop_stream()
                self.audio_stream.close()
            
            if self.pyaudio_instance:
                self.pyaudio_instance.terminate()
            
            # 将音频帧转换为 WAV 格式的 base64
            buffer = io.BytesIO()
            with wave.open(buffer, 'wb') as wf:
                wf.setnchannels(1)
                wf.setsampwidth(2) # 16-bit
                wf.setframerate(16000)
                wf.writeframes(b''.join(self.audio_frames))
            
            audio_base64 = base64.b64encode(buffer.getvalue()).decode('utf-8')
            
            # 发送 AI 请求（带音频数据）
            if self.mqtt_client and self.connected:
                self.ai_status_var.set("思考中...")
                self.mqtt_client.publish(TOPIC_AI_REQUEST.format(self.room_id), {
                    "room_id": self.room_id,
                    "device_id": self.device_id,
                    "audio_data": audio_base64, # 发送原始音频
                    "timestamp": datetime.now().isoformat()
                })
                self._add_chat("user", "[语音消息]")
            else:
                self._add_chat("assistant", "网络未连接，无法上传语音。")
                
        except Exception as e:
            self._log(f"录音处理失败: {e}", "ERROR")
            self.ai_status_var.set("空闲")

    def _toggle_mic_simulated(self):
        """原有的模拟录音逻辑（作为 fallback）"""
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

    def _report_event(self, event, val):
        if self.mqtt_client and self.connected:
            self.mqtt_client.publish(f"hotel/device/event/room/{self.room_id}", {
                "device_id": self.device_id, "event": event, "value": val
            })

    def _on_mqtt_message(self, topic, payload):
        """覆盖基类消息处理"""
        super()._on_mqtt_message(topic, payload)
        cmd_type = payload.get('command_type')
        cmd_val = payload.get('command_value')
        
        success = False
        msg = "未知操作"
        
        if cmd_type == 'light_on' and not self.light_on: self._toggle_light(True); success=True; msg="灯光已开启"
        elif cmd_type == 'light_off' and self.light_on: self._toggle_light(True); success=True; msg="灯光已关闭"
        elif cmd_type == 'set_temp': self.temp_val = int(cmd_val); self._adj_temp(0); success=True; msg=f"温度已设为{cmd_val}"
        
        # 反馈执行结果
        if self.mqtt_client and self.connected:
            self.mqtt_client.publish("hotel/device/command/result", {
                "device_id": self.device_id, "command_id": payload.get('command_id', 0),
                "status": "success" if success else "failed", "result": msg
            })

    def _on_ai_response(self, data):
        """处理 AI 响应"""
        text = data.get('response') or data.get('text')
        self.root.after(0, lambda: self._add_chat("assistant", text))
        self.root.after(0, lambda: self.ai_status_var.set("空闲"))
        self._log(f"AI 回复: {text}")

if __name__ == "__main__":
    root = tk.Tk()
    app = RoomTerminalEmulator(root)
    app.run()
