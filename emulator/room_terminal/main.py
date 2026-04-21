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


class RoomDeviceController:
    """客房设备控制器"""
    
    def __init__(self):
        # 设备状态
        self.light_on = False
        self.air_on = False
        self.curtain_open = False
        self.door_unlocked = False
        
        # 自动回锁计时
        self.auto_lock_timer = None
        self.auto_lock_delay = 8  # 8秒自动回锁
    
    def set_light(self, on):
        self.light_on = on
        return True
    
    def set_air(self, on):
        self.air_on = on
        return True
    
    def set_curtain(self, open_):
        self.curtain_open = open_
        return True
    
    def unlock_door(self, callback=None):
        """开锁 - 8秒后自动回锁"""
        self.door_unlocked = True
        
        # 取消之前的定时器
        if self.auto_lock_timer:
            self.auto_lock_timer.cancel()
        
        # 设置新的定时器
        self.auto_lock_timer = threading.Timer(self.auto_lock_delay, self._auto_lock, args=[callback])
        self.auto_lock_timer.start()
        
        return True
    
    def lock_door(self):
        """手动锁门"""
        if self.auto_lock_timer:
            self.auto_lock_timer.cancel()
            self.auto_lock_timer = None
        self.door_unlocked = False
        return True
    
    def _auto_lock(self, callback=None):
        """自动回锁"""
        self.door_unlocked = False
        if callback:
            callback()
    
    def get_status(self):
        return {
            "light_on": self.light_on,
            "air_on": self.air_on,
            "curtain_open": self.curtain_open,
            "door_unlocked": self.door_unlocked
        }


class SceneManager:
    """场景管理器"""
    
    SCENES = {
        "welcome": {"name": "迎宾", "light": True, "air": True, "curtain": True, "led": (255, 180, 120)},
        "reading": {"name": "阅读", "light": True, "air": True, "curtain": False, "led": (255, 255, 255)},
        "night": {"name": "夜灯", "light": False, "air": False, "curtain": False, "led": (16, 32, 96)},
        "sleep": {"name": "睡眠", "light": False, "air": False, "curtain": False, "led": (0, 0, 0)}
    }
    
    def __init__(self):
        self.current_scene = "welcome"
        self.scene_list = ["welcome", "reading", "night", "sleep"]
    
    def apply_scene(self, scene_name):
        """应用场景"""
        if scene_name in self.SCENES:
            self.current_scene = scene_name
            return self.SCENES[scene_name]
        return None
    
    def next_scene(self):
        """切换到下一场景"""
        current_idx = self.scene_list.index(self.current_scene)
        next_idx = (current_idx + 1) % len(self.scene_list)
        return self.apply_scene(self.scene_list[next_idx])
    
    def get_current_scene_name(self):
        return self.SCENES.get(self.current_scene, {}).get("name", "未知")


class CallManager:
    """通话管理器"""
    
    def __init__(self):
        self.is_on_call = False
        self.call_id = ""
        self.caller_id = ""
    
    def incoming_call(self, call_id, caller_id):
        """接收来电"""
        self.is_on_call = True
        self.call_id = call_id
        self.caller_id = caller_id
        return True
    
    def hangup(self):
        """挂断"""
        self.is_on_call = False
        self.call_id = ""
        self.caller_id = ""
        return True
    
    def get_status(self):
        return {
            "is_on_call": self.is_on_call,
            "call_id": self.call_id,
            "caller_id": self.caller_id
        }


class RoomTerminalEmulator(BaseDeviceEmulator):
    """客房终端仿真器"""
    
    def __init__(self, root):
        self.room_id = "301"
        self.device_id = f"room_{self.room_id}"
        
        # 先初始化子类特有属性（在调用父类__init__之前）
        self.devices = RoomDeviceController()
        self.scenes = SceneManager()
        self.call = CallManager()
        self.temperature = 25.0
        self.humidity = 60.0
        self.light_adc = 800.0  # 光照ADC值
        self.air_quality_adc = 500.0  # 空气质量ADC值
        self.auto_report = True
        self._stop_report = threading.Event()
        self._report_thread = None
        self.room_id_var = tk.StringVar(value=self.room_id)  # 用于配置对话框
        
        # AI对话相关
        self.ai_dialog = None
        self.ai_conversation = []  # AI对话历史
        self.is_recording = False  # 是否正在录音
        self.audio_player = None  # 音频播放器
        
        super().__init__(
            root=root,
            title=f"智慧酒店 - 客房终端仿真器 ({self.device_id})",
            device_id=self.device_id,
            device_type="room",
            width=950,
            height=800
        )
    
    def _create_ui(self):
        """创建UI界面"""
        super()._create_ui()
        
        # 创建内容面板
        content_frame = ttk.Frame(self.main_frame)
        content_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        content_frame.columnconfigure(0, weight=1)
        
        # OLED显示屏
        self._create_oled_panel(content_frame)
        
        # 设备控制
        self._create_device_panel(content_frame)
        
        # 场景和通话
        self._create_scene_call_panel(content_frame)
        
        # 安防
        self._create_security_panel(content_frame)
        
        # AI助手按钮
        self._create_ai_button(content_frame)
    
    def _create_ai_button(self, parent):
        """创建AI助手按钮"""
        ai_frame = ttk.Frame(parent)
        ai_frame.grid(row=4, column=0, sticky=(tk.W, tk.E), padx=5, pady=5)
        
        self.ai_btn = tk.Button(
            ai_frame, text="🤖 呼叫AI助手", bg="#4CAF50", fg="white",
            font=("Arial", 14, "bold"), command=self._open_ai_dialog
        )
        self.ai_btn.pack(pady=10)
    
    def _open_ai_dialog(self):
        """打开AI对话窗口"""
        if self.ai_dialog is not None and self.ai_dialog.winfo_exists():
            self.ai_dialog.lift()
            return
        
        self.ai_dialog = tk.Toplevel(self.root)
        self.ai_dialog.title(f"AI助手 - 房间{self.room_id}")
        self.ai_dialog.geometry("500x600")
        self.ai_dialog.transient(self.root)
        
        # 对话历史显示区
        history_frame = ttk.LabelFrame(self.ai_dialog, text="对话历史", padding="5")
        history_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        
        self.ai_history_text = scrolledtext.ScrolledText(
            history_frame, wrap=tk.WORD, font=("Microsoft YaHei", 11),
            bg="#f5f5f5", state=tk.DISABLED
        )
        self.ai_history_text.pack(fill=tk.BOTH, expand=True)
        
        # 输入区
        input_frame = ttk.Frame(self.ai_dialog)
        input_frame.pack(fill=tk.X, padx=10, pady=5)
        
        self.ai_input_var = tk.StringVar()
        ai_entry = ttk.Entry(input_frame, textvariable=self.ai_input_var, font=("Microsoft YaHei", 12))
        ai_entry.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 5))
        ai_entry.bind("<Return>", lambda e: self._send_ai_message())
        
        ttk.Button(input_frame, text="发送", command=self._send_ai_message).pack(side=tk.LEFT)
        
        # 麦克风按钮
        self.mic_btn = tk.Button(
            self.ai_dialog, text="🎤 按住说话", bg="#2196F3", fg="white",
            font=("Arial", 12, "bold"), command=self._toggle_recording
        )
        self.mic_btn.pack(fill=tk.X, padx=10, pady=5)
        
        # 状态标签
        self.ai_status_var = tk.StringVar(value="就绪")
        ttk.Label(self.ai_dialog, textvariable=self.ai_status_var, font=("Arial", 10)).pack(pady=5)
        
        # 添加欢迎语
        self._add_ai_message("assistant", "您好！我是您的客房AI助手，请问有什么可以帮您？\n您可以问我：\n• 打开/关闭灯光\n• 调节空调温度\n• 切换场景模式\n• 查询房间状态")
    
    def _add_ai_message(self, role, content):
        """添加消息到对话历史"""
        self.ai_history_text.config(state=tk.NORMAL)
        
        if role == "user":
            self.ai_history_text.insert(tk.END, f"\n👤 您: {content}\n", "user")
            self.ai_history_text.tag_config("user", foreground="#0066cc", font=("Microsoft YaHei", 11, "bold"))
        else:
            self.ai_history_text.insert(tk.END, f"\n🤖 AI: {content}\n", "assistant")
            self.ai_history_text.tag_config("assistant", foreground="#333333", font=("Microsoft YaHei", 11))
        
        self.ai_history_text.see(tk.END)
        self.ai_history_text.config(state=tk.DISABLED)
        
        # 保存到历史
        self.ai_conversation.append({"role": role, "content": content, "time": datetime.now().isoformat()})
    
    def _send_ai_message(self):
        """发送消息到AI"""
        message = self.ai_input_var.get().strip()
        if not message:
            return
        
        self.ai_input_var.set("")
        self._add_ai_message("user", message)
        
        # 发送到MQTT
        if self.mqtt_client and self.connected:
            self.ai_status_var.set("正在思考...")
            topic = TOPIC_AI_REQUEST.format(self.room_id)
            payload = {
                "room_id": self.room_id,
                "device_id": self.device_id,
                "message": message,
                "conversation_id": f"conv_{int(time.time())}",
                "timestamp": datetime.now().isoformat()
            }
            self.mqtt_client.publish(topic, payload)
            self.logger.info(f"发送AI请求: {message}")
        else:
            self._add_ai_message("assistant", "抱歉，MQTT未连接，无法与AI通信。")
    
    def _toggle_recording(self):
        """切换录音状态"""
        if not self.is_recording:
            self._start_recording()
        else:
            self._stop_recording()
    
    def _start_recording(self):
        """开始录音"""
        # 检查麦克风权限（模拟）
        try:
            # 尝试导入pyaudio，如果失败则使用模拟模式
            import pyaudio
            self.has_microphone = True
        except ImportError:
            self.has_microphone = False
            self.logger.warning("未安装pyaudio，使用模拟麦克风模式")
        
        self.is_recording = True
        self.mic_btn.config(text="🔴 录音中 (点击停止)", bg="#f44336")
        self.ai_status_var.set("正在聆听...")
        
        if self.has_microphone:
            # 启动录音线程
            self._recording_thread = threading.Thread(target=self._record_audio, daemon=True)
            self._recording_thread.start()
        else:
            # 模拟录音 - 3秒后自动停止
            self.root.after(3000, self._stop_recording)
    
    def _stop_recording(self):
        """停止录音"""
        self.is_recording = False
        self.mic_btn.config(text="🎤 按住说话", bg="#2196F3")
        self.ai_status_var.set("识别中...")
        
        # 模拟语音识别结果
        simulated_text = self._simulate_speech_recognition()
        self.ai_input_var.set(simulated_text)
        self._send_ai_message()
    
    def _record_audio(self):
        """录音（需要pyaudio）"""
        try:
            import pyaudio
            import wave
            
            CHUNK = 1024
            FORMAT = pyaudio.paInt16
            CHANNELS = 1
            RATE = 16000
            
            p = pyaudio.PyAudio()
            stream = p.open(format=FORMAT, channels=CHANNELS, rate=RATE, input=True, frames_per_buffer=CHUNK)
            
            frames = []
            while self.is_recording:
                data = stream.read(CHUNK, exception_on_overflow=False)
                frames.append(data)
            
            stream.stop_stream()
            stream.close()
            p.terminate()
            
            # 保存录音（可选）
            # self._save_audio(frames)
            
        except Exception as e:
            self.logger.error(f"录音失败: {e}")
            self.root.after(0, lambda: self.ai_status_var.set(f"录音失败: {e}"))
    
    def _simulate_speech_recognition(self):
        """模拟语音识别结果"""
        # 随机返回一些常见的语音指令
        commands = [
            "打开灯光",
            "关闭空调",
            "切换到睡眠模式",
            "打开窗帘",
            "房间温度是多少",
            "帮我叫前台"
        ]
        return random.choice(commands)
    
    def _on_ai_response(self, topic, payload):
        """AI响应回调"""
        try:
            data = json.loads(payload)
            response = data.get("response", "")
            actions = data.get("actions", [])
            audio_url = data.get("audio_url", "")  # AI语音URL
            audio_base64 = data.get("audio_base64", "")  # Base64编码的音频
            
            self.root.after(0, lambda: self._add_ai_message("assistant", response))
            self.root.after(0, lambda: self.ai_status_var.set("就绪"))
            
            # 播放AI返回的语音
            if audio_url:
                self._play_audio_from_url(audio_url)
            elif audio_base64:
                self._play_audio_from_base64(audio_base64)
            
            # 执行AI返回的动作
            for action in actions:
                self._execute_ai_action(action)
            
            self.logger.info(f"收到AI响应: {response}")
        except Exception as e:
            self.logger.error(f"处理AI响应失败: {e}")
    
    def _play_audio_from_url(self, url):
        """从URL播放音频"""
        try:
            # 尝试使用pygame播放
            import pygame
            import requests
            import tempfile
            
            self.logger.info(f"正在下载音频: {url}")
            response = requests.get(url, timeout=10)
            
            if response.status_code == 200:
                # 保存到临时文件
                with tempfile.NamedTemporaryFile(delete=False, suffix=".mp3") as f:
                    f.write(response.content)
                    temp_path = f.name
                
                # 播放音频
                self._play_audio_file(temp_path)
            else:
                self.logger.error(f"下载音频失败: HTTP {response.status_code}")
        except ImportError:
            self.logger.warning("未安装pygame/requests，无法播放网络音频")
        except Exception as e:
            self.logger.error(f"播放音频失败: {e}")
    
    def _play_audio_from_base64(self, base64_data):
        """从Base64播放音频"""
        try:
            import base64
            import tempfile
            
            # 解码Base64
            audio_bytes = base64.b64decode(base64_data)
            
            # 保存到临时文件
            with tempfile.NamedTemporaryFile(delete=False, suffix=".mp3") as f:
                f.write(audio_bytes)
                temp_path = f.name
            
            # 播放音频
            self._play_audio_file(temp_path)
            
        except Exception as e:
            self.logger.error(f"播放Base64音频失败: {e}")
    
    def _play_audio_file(self, file_path):
        """播放音频文件"""
        try:
            import pygame
            
            # 初始化pygame mixer
            if not pygame.mixer.get_init():
                pygame.mixer.init()
            
            # 加载并播放
            pygame.mixer.music.load(file_path)
            pygame.mixer.music.play()
            
            self.logger.info(f"正在播放音频: {file_path}")
            
            # 启动线程监控播放状态
            def monitor_playback():
                while pygame.mixer.music.get_busy():
                    time.sleep(0.1)
                # 播放完成后删除临时文件
                try:
                    os.remove(file_path)
                except:
                    pass
            
            threading.Thread(target=monitor_playback, daemon=True).start()
            
        except ImportError:
            self.logger.warning("未安装pygame，无法播放音频")
        except Exception as e:
            self.logger.error(f"播放音频文件失败: {e}")
    
    def _execute_ai_action(self, action):
        """执行AI动作"""
        action_type = action.get("type", "")
        
        if action_type == "light_on":
            self.root.after(0, lambda: self._set_device_state("light", True))
        elif action_type == "light_off":
            self.root.after(0, lambda: self._set_device_state("light", False))
        elif action_type == "air_on":
            self.root.after(0, lambda: self._set_device_state("air", True))
        elif action_type == "air_off":
            self.root.after(0, lambda: self._set_device_state("air", False))
        elif action_type == "curtain_open":
            self.root.after(0, lambda: self._set_device_state("curtain", True))
        elif action_type == "curtain_close":
            self.root.after(0, lambda: self._set_device_state("curtain", False))
        elif action_type == "scene":
            scene_name = action.get("scene", "welcome")
            self.root.after(0, lambda: self._apply_scene(scene_name))
    
    def _set_device_state(self, device, state):
        """设置设备状态"""
        if device == "light":
            self.devices.set_light(state)
        elif device == "air":
            self.devices.set_air(state)
        elif device == "curtain":
            self.devices.set_curtain(state)
        
        self._update_device_ui()
        self._update_oled()
    
    def _create_oled_panel(self, parent):
        """创建OLED显示屏面板"""
        oled_frame = ttk.LabelFrame(parent, text="OLED显示屏", padding="10")
        oled_frame.grid(row=0, column=0, sticky=(tk.W, tk.E), padx=5, pady=5)
        
        # OLED画布
        self.oled_canvas = tk.Canvas(oled_frame, width=400, height=100, bg="black", highlightthickness=2)
        self.oled_canvas.pack()
        
        self._update_oled()
    
    def _update_oled(self):
        """更新OLED显示"""
        self.oled_canvas.delete("all")
        
        # 背景
        self.oled_canvas.create_rectangle(0, 0, 400, 100, fill="black", outline="")
        
        # 房间号
        self.oled_canvas.create_text(10, 15, text=f"Room: {self.room_id}", fill="white", font=("Consolas", 12), anchor=tk.W)
        
        # IP地址
        ip = "192.168.1.100" if self.connected else "Disconnected"
        self.oled_canvas.create_text(10, 35, text=f"IP: {ip}", fill="white", font=("Consolas", 10), anchor=tk.W)
        
        # 温湿度
        self.oled_canvas.create_text(10, 55, text=f"T:{self.temperature:.1f}C H:{self.humidity:.1f}%", 
                                     fill="white", font=("Consolas", 10), anchor=tk.W)
        
        # 当前场景
        scene_name = self.scenes.get_current_scene_name()
        self.oled_canvas.create_text(10, 75, text=f"[{scene_name}模式]", 
                                     fill="#00ff00", font=("Consolas", 11, "bold"), anchor=tk.W)
        
        # 设备状态指示
        status_x = 250
        # 灯
        light_color = "#FFFF00" if self.devices.light_on else "#333333"
        self.oled_canvas.create_oval(status_x, 10, status_x+15, 25, fill=light_color, outline="")
        self.oled_canvas.create_text(status_x+25, 17, text="灯", fill="white", font=("Consolas", 9), anchor=tk.W)
        
        # 空调
        air_color = "#00FFFF" if self.devices.air_on else "#333333"
        self.oled_canvas.create_oval(status_x, 35, status_x+15, 50, fill=air_color, outline="")
        self.oled_canvas.create_text(status_x+25, 42, text="空调", fill="white", font=("Consolas", 9), anchor=tk.W)
        
        # 门锁
        door_color = "#FF0000" if self.devices.door_unlocked else "#00FF00"
        door_text = "开" if self.devices.door_unlocked else "锁"
        self.oled_canvas.create_oval(status_x, 60, status_x+15, 75, fill=door_color, outline="")
        self.oled_canvas.create_text(status_x+25, 67, text=f"门{door_text}", fill="white", font=("Consolas", 9), anchor=tk.W)
    
    def _create_device_panel(self, parent):
        """创建设备控制面板"""
        device_frame = ttk.LabelFrame(parent, text="设备控制", padding="10")
        device_frame.grid(row=1, column=0, sticky=(tk.W, tk.E), padx=5, pady=5)
        
        # 第一行 - 灯、空调、窗帘
        row1 = ttk.Frame(device_frame)
        row1.pack(fill=tk.X, pady=5)
        
        # 主灯
        light_frame = ttk.LabelFrame(row1, text="💡 主灯", padding="5")
        light_frame.pack(side=tk.LEFT, padx=10)
        self.light_status = ttk.Label(light_frame, text="关闭", font=("Arial", 12))
        self.light_status.pack()
        ttk.Button(light_frame, text="开关", command=self._toggle_light).pack(pady=5)
        
        # 空调
        air_frame = ttk.LabelFrame(row1, text="❄️ 空调", padding="5")
        air_frame.pack(side=tk.LEFT, padx=10)
        self.air_status = ttk.Label(air_frame, text="关闭", font=("Arial", 12))
        self.air_status.pack()
        ttk.Button(air_frame, text="开关", command=self._toggle_air).pack(pady=5)
        
        # 窗帘
        curtain_frame = ttk.LabelFrame(row1, text="🪟 窗帘", padding="5")
        curtain_frame.pack(side=tk.LEFT, padx=10)
        self.curtain_status = ttk.Label(curtain_frame, text="关闭", font=("Arial", 12))
        self.curtain_status.pack()
        ttk.Button(curtain_frame, text="开/关", command=self._toggle_curtain).pack(pady=5)
        
        # 第二行 - 门锁、氛围灯
        row2 = ttk.Frame(device_frame)
        row2.pack(fill=tk.X, pady=5)
        
        # 门锁
        door_frame = ttk.LabelFrame(row2, text="🚪 门锁", padding="5")
        door_frame.pack(side=tk.LEFT, padx=10)
        self.door_status = ttk.Label(door_frame, text="锁定", font=("Arial", 12))
        self.door_status.pack()
        ttk.Button(door_frame, text="解锁(8s回锁)", command=self._unlock_door).pack(pady=5)
        ttk.Button(door_frame, text="手动锁定", command=self._lock_door).pack(pady=5)
        
        # 氛围灯
        led_frame = ttk.LabelFrame(row2, text="🎨 氛围灯", padding="5")
        led_frame.pack(side=tk.LEFT, padx=10)
        self.led_canvas = tk.Canvas(led_frame, width=50, height=50, bg="#333", highlightthickness=1)
        self.led_canvas.pack()
        self._update_led(255, 180, 120)  # 默认迎宾色
    
    def _update_led(self, r, g, b):
        """更新氛围灯颜色"""
        color = f"#{r:02x}{g:02x}{b:02x}"
        self.led_canvas.delete("all")
        self.led_canvas.create_oval(5, 5, 45, 45, fill=color, outline="")
    
    def _create_scene_call_panel(self, parent):
        """创建场景和通话面板"""
        frame = ttk.Frame(parent)
        frame.grid(row=2, column=0, sticky=(tk.W, tk.E), padx=5, pady=5)
        frame.columnconfigure(0, weight=1)
        frame.columnconfigure(1, weight=1)
        
        # 场景控制
        scene_frame = ttk.LabelFrame(frame, text="场景模式", padding="10")
        scene_frame.grid(row=0, column=0, sticky=(tk.W, tk.E), padx=5)
        
        scene_btn_frame = ttk.Frame(scene_frame)
        scene_btn_frame.pack()
        
        ttk.Button(scene_btn_frame, text="迎宾", command=lambda: self._apply_scene("welcome")).pack(side=tk.LEFT, padx=2)
        ttk.Button(scene_btn_frame, text="阅读", command=lambda: self._apply_scene("reading")).pack(side=tk.LEFT, padx=2)
        ttk.Button(scene_btn_frame, text="夜灯", command=lambda: self._apply_scene("night")).pack(side=tk.LEFT, padx=2)
        ttk.Button(scene_btn_frame, text="睡眠", command=lambda: self._apply_scene("sleep")).pack(side=tk.LEFT, padx=2)
        ttk.Button(scene_btn_frame, text="下一场景", command=self._next_scene).pack(side=tk.LEFT, padx=5)
        
        # 通话控制
        call_frame = ttk.LabelFrame(frame, text="语音通话", padding="10")
        call_frame.grid(row=0, column=1, sticky=(tk.W, tk.E), padx=5)
        
        self.call_status = ttk.Label(call_frame, text="空闲", font=("Arial", 14))
        self.call_status.pack()
        
        self.caller_label = ttk.Label(call_frame, text="")
        self.caller_label.pack()
        
        call_btn_frame = ttk.Frame(call_frame)
        call_btn_frame.pack(pady=5)
        
        ttk.Button(call_btn_frame, text="接听", command=self._answer_call).pack(side=tk.LEFT, padx=5)
        ttk.Button(call_btn_frame, text="挂断", command=self._hangup_call).pack(side=tk.LEFT, padx=5)
    
    def _create_security_panel(self, parent):
        """创建安防面板"""
        security_frame = ttk.LabelFrame(parent, text="安防", padding="10")
        security_frame.grid(row=3, column=0, sticky=(tk.W, tk.E), padx=5, pady=5)
        
        # SOS按钮
        self.sos_btn = tk.Button(
            security_frame, text="🆘 SOS紧急呼叫", bg="#ff4444", fg="white",
            font=("Arial", 16, "bold"), command=self._trigger_sos
        )
        self.sos_btn.pack(pady=10)
        
        # 传感器显示
        sensor_frame = ttk.Frame(security_frame)
        sensor_frame.pack(fill=tk.X, pady=5)
        
        ttk.Label(sensor_frame, text="传感器数据 (15s上报):").pack(side=tk.LEFT)
        self.sensor_label = ttk.Label(sensor_frame, text="温度25.0°C 湿度60.0%", font=("Consolas", 10))
        self.sensor_label.pack(side=tk.LEFT, padx=10)
        
        ttk.Button(sensor_frame, text="立即上报", command=self._report_sensors).pack(side=tk.RIGHT)
    
    def _toggle_light(self):
        """切换灯光"""
        new_state = not self.devices.light_on
        self.devices.set_light(new_state)
        self._update_device_ui()
        self._update_oled()
        
        if self.mqtt_client and self.connected:
            self.mqtt_client.publish_command_result(0, CMD_LIGHT_ON if new_state else CMD_LIGHT_OFF, True)
    
    def _toggle_air(self):
        """切换空调"""
        new_state = not self.devices.air_on
        self.devices.set_air(new_state)
        self._update_device_ui()
        self._update_oled()
        
        if self.mqtt_client and self.connected:
            self.mqtt_client.publish_command_result(0, CMD_AIR_ON if new_state else CMD_AIR_OFF, True)
    
    def _toggle_curtain(self):
        """切换窗帘"""
        new_state = not self.devices.curtain_open
        self.devices.set_curtain(new_state)
        self._update_device_ui()
        self._update_oled()
        
        if self.mqtt_client and self.connected:
            self.mqtt_client.publish_command_result(0, CMD_CURTAIN_OPEN if new_state else CMD_CURTAIN_CLOSE, True)
    
    def _unlock_door(self):
        """解锁门"""
        def on_auto_lock():
            self.root.after(0, self._update_device_ui)
            self.root.after(0, self._update_oled)
            if self.mqtt_client and self.connected:
                self.mqtt_client.publish_command_result(0, CMD_DOOR_LOCK, True, "门锁自动回锁完成")
        
        self.devices.unlock_door(on_auto_lock)
        self._update_device_ui()
        self._update_oled()
        
        if self.mqtt_client and self.connected:
            self.mqtt_client.publish_command_result(0, CMD_DOOR_UNLOCK, True)
    
    def _lock_door(self):
        """手动锁门"""
        self.devices.lock_door()
        self._update_device_ui()
        self._update_oled()
        
        if self.mqtt_client and self.connected:
            self.mqtt_client.publish_command_result(0, CMD_DOOR_LOCK, True)
    
    def _update_device_ui(self):
        """更新设备UI"""
        status = self.devices.get_status()
        
        self.light_status.config(text="开启" if status["light_on"] else "关闭")
        self.air_status.config(text="开启" if status["air_on"] else "关闭")
        self.curtain_status.config(text="开启" if status["curtain_open"] else "关闭")
        self.door_status.config(text="解锁" if status["door_unlocked"] else "锁定")
    
    def _apply_scene(self, scene_name):
        """应用场景"""
        scene = self.scenes.apply_scene(scene_name)
        if scene:
            self.devices.set_light(scene["light"])
            self.devices.set_air(scene["air"])
            self.devices.set_curtain(scene["curtain"])
            self._update_led(*scene["led"])
            self._update_device_ui()
            self._update_oled()
            self.logger.info(f"已切换到{scene['name']}场景")
    
    def _next_scene(self):
        """下一场景"""
        scene = self.scenes.next_scene()
        if scene:
            self.devices.set_light(scene["light"])
            self.devices.set_air(scene["air"])
            self.devices.set_curtain(scene["curtain"])
            self._update_led(*scene["led"])
            self._update_device_ui()
            self._update_oled()
    
    def _answer_call(self):
        """接听电话"""
        if self.call.is_on_call:
            self.logger.info("接听来电")
    
    def _hangup_call(self):
        """挂断电话"""
        self.call.hangup()
        self._update_call_ui()
        
        if self.mqtt_client and self.connected:
            self.mqtt_client.publish_command_result(0, CMD_HANGUP_CALL, True)
    
    def _update_call_ui(self):
        """更新通话UI"""
        status = self.call.get_status()
        if status["is_on_call"]:
            self.call_status.config(text="通话中", foreground="green")
            self.caller_label.config(text=f"来自: {status['caller_id']}")
        else:
            self.call_status.config(text="空闲", foreground="black")
            self.caller_label.config(text="")
    
    def _trigger_sos(self):
        """触发SOS"""
        self.logger.critical("SOS紧急呼叫触发！")
        self.sos_btn.config(bg="#ff0000", text="⚠️ 呼叫中！")
        
        if self.mqtt_client and self.connected:
            self.mqtt_client.publish_security_event(
                "room_sos_pressed",
                level="critical",
                event_data={"room_id": int(self.room_id)}
            )
        
        # 3秒后恢复
        self.root.after(3000, lambda: self.sos_btn.config(bg="#ff4444", text="🆘 SOS紧急呼叫"))
    
    def _report_sensors(self):
        """上报传感器数据"""
        if self.mqtt_client and self.connected:
            self.mqtt_client.publish_sensor_data("temperature", self.temperature, "℃")
            self.mqtt_client.publish_sensor_data("humidity", self.humidity, "%")
            self.mqtt_client.publish_sensor_data("light_adc", self.light_adc, "adc")
            self.mqtt_client.publish_sensor_data("air_quality_adc", self.air_quality_adc, "adc")
            self.logger.info(f"传感器上报: T={self.temperature:.1f}°C, H={self.humidity:.1f}%, "
                           f"Light={self.light_adc:.0f}, Air={self.air_quality_adc:.0f}")
    
    def _sensor_report_loop(self):
        """传感器上报循环"""
        while not self._stop_report.is_set():
            if self.connected and self.auto_report:
                # 模拟传感器波动
                self.temperature += random.uniform(-0.3, 0.3)
                self.humidity += random.uniform(-0.5, 0.5)
                self.light_adc += random.uniform(-20, 20)
                self.air_quality_adc += random.uniform(-30, 30)
                
                self.root.after(0, self._update_oled)
                self._report_sensors()
            
            for _ in range(15):  # 15秒间隔
                if self._stop_report.is_set():
                    break
                time.sleep(1)
    
    def _register_command_handlers(self):
        """注册命令处理器"""
        handlers = {
            CMD_LIGHT_ON: lambda d: self._handle_cmd(CMD_LIGHT_ON, self.devices.set_light, True),
            CMD_LIGHT_OFF: lambda d: self._handle_cmd(CMD_LIGHT_OFF, self.devices.set_light, False),
            CMD_AIR_ON: lambda d: self._handle_cmd(CMD_AIR_ON, self.devices.set_air, True),
            CMD_AIR_OFF: lambda d: self._handle_cmd(CMD_AIR_OFF, self.devices.set_air, False),
            CMD_CURTAIN_OPEN: lambda d: self._handle_cmd(CMD_CURTAIN_OPEN, self.devices.set_curtain, True),
            CMD_CURTAIN_CLOSE: lambda d: self._handle_cmd(CMD_CURTAIN_CLOSE, self.devices.set_curtain, False),
            CMD_DOOR_UNLOCK: self._handle_door_unlock,
            CMD_DOOR_LOCK: lambda d: self._handle_cmd(CMD_DOOR_LOCK, self.devices.lock_door),
            CMD_INCOMING_CALL: self._handle_incoming_call,
            CMD_HANGUP_CALL: lambda d: self._handle_cmd(CMD_HANGUP_CALL, self.call.hangup),
            CMD_SCENE_WELCOME: lambda d: self._handle_scene("welcome"),
            CMD_SCENE_READING: lambda d: self._handle_scene("reading"),
            CMD_SCENE_NIGHT: lambda d: self._handle_scene("night"),
            CMD_SCENE_SLEEP: lambda d: self._handle_scene("sleep"),
            CMD_SCENE_NEXT: lambda d: self._handle_scene("next"),
        }
        
        for cmd, handler in handlers.items():
            self.mqtt_client.register_command_handler(cmd, handler)
        
        # 订阅AI响应主题
        ai_topic = TOPIC_AI_RESPONSE.format(self.room_id)
        self.mqtt_client.subscribe(ai_topic, self._on_ai_response)
    
    def _handle_cmd(self, cmd_type, action, *args):
        """通用命令处理"""
        try:
            result = action(*args) if args else action()
            self.root.after(0, self._update_device_ui)
            self.root.after(0, self._update_oled)
            return result
        except Exception as e:
            self.logger.error(f"执行命令失败: {e}")
            return False
    
    def _handle_door_unlock(self, data):
        """处理开锁命令"""
        def on_auto_lock():
            self.root.after(0, self._update_device_ui)
            self.root.after(0, self._update_oled)
        
        self.devices.unlock_door(on_auto_lock)
        self.root.after(0, self._update_device_ui)
        self.root.after(0, self._update_oled)
        return True
    
    def _handle_incoming_call(self, data):
        """处理来电/广播"""
        call_id = data.get("call_id", "")
        caller_id = data.get("caller_id", "")
        broadcast_audio_url = data.get("broadcast_audio_url", "")  # 广播语音URL
        broadcast_text = data.get("broadcast_text", "")  # 广播文本
        
        self.call.incoming_call(call_id, caller_id)
        self.root.after(0, self._update_call_ui)
        
        # 播放广播语音
        if broadcast_audio_url:
            self._play_audio_from_url(broadcast_audio_url)
        elif broadcast_text:
            self.logger.info(f"收到广播: {broadcast_text}")
            # 可以在这里调用TTS播放广播文本
        
        return True
    
    def _handle_scene(self, scene_name):
        """处理场景命令"""
        if scene_name == "next":
            scene = self.scenes.next_scene()
        else:
            scene = self.scenes.apply_scene(scene_name)
        
        if scene:
            self.devices.set_light(scene["light"])
            self.devices.set_air(scene["air"])
            self.devices.set_curtain(scene["curtain"])
            self.root.after(0, lambda: self._update_led(*scene["led"]))
            self.root.after(0, self._update_device_ui)
            self.root.after(0, self._update_oled)
        return True
    
    def _on_ai_response(self, topic, payload):
        """AI响应回调"""
        self.logger.info(f"收到AI响应: {payload}")
    
    def _on_connected(self):
        """连接成功"""
        self._stop_report.clear()
        self._report_thread = threading.Thread(target=self._sensor_report_loop, daemon=True)
        self._report_thread.start()
        self._update_oled()
    
    def _on_disconnected(self):
        """断开连接"""
        self._stop_report.set()
        self._update_oled()
    
    def _show_config_dialog(self):
        """显示配置对话框"""
        dialog = tk.Toplevel(self.root)
        dialog.title("设备配置")
        dialog.geometry("300x150")
        dialog.transient(self.root)
        dialog.grab_set()
        
        ttk.Label(dialog, text="房间号:").pack(pady=(20, 5))
        id_entry = ttk.Entry(dialog, textvariable=self.room_id_var, width=10)
        id_entry.pack()
        
        def save_config():
            new_room_id = self.room_id_var.get()
            new_device_id = f"room_{new_room_id}"
            if new_device_id != self.device_id:
                self.room_id = new_room_id
                self.device_id = new_device_id
                self.device_id_label.config(text=f"设备ID: {self.device_id}")
                self.root.title(f"智慧酒店 - 客房终端仿真器 ({self.device_id})")
                self._update_oled()
                if self.connected:
                    messagebox.showinfo("提示", "设备ID已更改，请重新连接MQTT")
                    self.disconnect()
            dialog.destroy()
        
        ttk.Button(dialog, text="保存", command=save_config).pack(pady=20)


def main():
    """主函数"""
    root = tk.Tk()
    app = RoomTerminalEmulator(root)
    app.run()


if __name__ == "__main__":
    main()
