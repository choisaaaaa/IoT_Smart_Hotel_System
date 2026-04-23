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
import queue
import base64
import io
try:
    import pyaudio
    HAS_PYAUDIO = True
except ImportError:
    HAS_PYAUDIO = False
from datetime import datetime
from common.device_base import BaseDeviceEmulator
from common.rfid_simulator import RFIDCardSimulator
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
        self.room_id = "" # 初始为空，由配网或资产同步填充
        self.rfid = RFIDCardSimulator()
        self.card_uid_var = tk.StringVar(value="")
        
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

        # 通话状态
        self.current_call_id = None
        self.is_in_call = False
        self._call_audio_stream = None
        self._call_output_stream = None
        self._audio_lock = threading.Lock()
        self._audio_in_queue = queue.Queue(maxsize=50) # 约 6 秒缓存

        self._stop_sensors = threading.Event()
        self._alarm_beep_thread = None  # 报警蜂鸣器线程
        self._stop_alarm_beep = threading.Event()  # 停止蜂鸣器事件
        
        # 硬件组件状态 - 按照接线教程添加
        self.relay_status = [False, False, False, False]  # 四路继电器状态
        self.millimeter_wave_detected = False  # 毫米波雷达检测状态
        self.ir_receiver_enabled = True  # 红外接收使能
        self.ir_transmitter_enabled = True  # 红外发射使能
        self.ec11_position = 0  # EC11旋转编码器位置
        self.ec11_button_pressed = False  # EC11按键状态
        self.sos_button_pressed = False  # SOS按键状态
        self.ptt_button_pressed = False  # PTT/接听按键状态
        self.scene_button_pressed = False  # 场景按键状态
        self.rfid_card_present = False  # RFID卡片状态
        self.power_card_inserted = False  # 插卡取电状态
        self.spi_flash_w25q64 = True  # W25Q64 SPI Flash状态

        super().__init__(
            root=root,
            title=f"智慧酒店 - 客房终端仿真器",
            device_id=None, # 让基类自动生成或从配置加载唯一物理ID
            device_type="room",
            width=1050,
            height=950
        )

        self._sync_room_info()
        self._draw_card()

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
        # ========== 第一批：通信骨架 (RC522 + OLED + 毫米波) ==========
        self._create_card(self.biz_frame, "第一批：通信骨架 (RC522 SPI + OLED I2C + 毫米波雷达)").pack(fill=tk.X, pady=(0, 15))
        comm_body = self.last_card_body
        
        comm_grid = tk.Frame(comm_body, bg="white")
        comm_grid.pack(fill=tk.X, pady=10)
        
        # RC522状态
        rc522_frame = tk.Frame(comm_grid, bg="#f5f5f5", padx=10, pady=10)
        rc522_frame.pack(side=tk.LEFT, expand=True, fill=tk.BOTH, padx=5)
        tk.Label(rc522_frame, text="📟 RC522 RFID", font=("Arial", 10, "bold"), bg="#f5f5f5").pack()
        self.rfid_status_label = tk.Label(rc522_frame, text="✓ 就绪", font=("Arial", 9), bg="#f5f5f5", fg=self.colors['success'])
        self.rfid_status_label.pack()
        
        # 放置卡片区域
        rfid_input_f = tk.Frame(rc522_frame, bg="#f5f5f5")
        rfid_input_f.pack(pady=5)
        tk.Entry(rfid_input_f, textvariable=self.card_uid_var, width=10, font=("Consolas", 9)).pack(side=tk.LEFT, padx=2)
        tk.Button(rfid_input_f, text="放置", command=self._place_card, 
                  bg="#e0e0e0", font=("Arial", 8)).pack(side=tk.LEFT)
        
        rc522_btn_f = tk.Frame(rc522_frame, bg="#f5f5f5")
        rc522_btn_f.pack()
        tk.Button(rc522_btn_f, text="刷卡开门", command=self._simulate_card_swipe,
                  relief=tk.FLAT, bg=self.colors['primary'], fg="white", font=("Arial", 8)).pack(side=tk.LEFT, padx=2)
        self.power_card_btn = tk.Button(rc522_btn_f, text="插卡取电", command=self._toggle_power_card,
                  relief=tk.FLAT, bg=self.colors['warning'], fg="white", font=("Arial", 8))
        self.power_card_btn.pack(side=tk.LEFT, padx=2)
        
        # 卡片图形显示
        self.card_canvas = tk.Canvas(rc522_frame, width=120, height=80, bg="#f5f5f5", highlightthickness=0)
        self.card_canvas.pack(pady=5)
        self._draw_card()
        
        # OLED状态
        oled_frame = tk.Frame(comm_grid, bg="#f5f5f5", padx=10, pady=10)
        oled_frame.pack(side=tk.LEFT, expand=True, fill=tk.BOTH, padx=5)
        tk.Label(oled_frame, text="📺 OLED显示屏", font=("Arial", 10, "bold"), bg="#f5f5f5").pack()
        tk.Label(oled_frame, text="✓ 正常显示", font=("Arial", 9), bg="#f5f5f5", fg=self.colors['success']).pack()
        tk.Label(oled_frame, text="I2C: SDA→GPIO21 SCL→GPIO8\n3V3供电", 
                 font=("Consolas", 8), bg="#f5f5f5", fg="#666").pack(pady=5)
        
        # 毫米波雷达状态
        radar_frame = tk.Frame(comm_grid, bg="#f5f5f5", padx=10, pady=10)
        radar_frame.pack(side=tk.LEFT, expand=True, fill=tk.BOTH, padx=5)
        tk.Label(radar_frame, text="📡 毫米波雷达", font=("Arial", 10, "bold"), bg="#f5f5f5").pack()
        self.radar_status_label = tk.Label(radar_frame, text="○ 无人", font=("Arial", 9), bg="#f5f5f5", fg="#999")
        self.radar_status_label.pack()
        tk.Label(radar_frame, text="S3KM1110: OT2→GPIO16\n3V3供电", 
                 font=("Consolas", 8), bg="#f5f5f5", fg="#666").pack(pady=5)
        tk.Button(radar_frame, text="模拟有人", command=self._simulate_radar_detect,
                  relief=tk.FLAT, bg=self.colors['warning'], fg="white", font=("Arial", 8)).pack()
        
        # W25Q64状态
        flash_frame = tk.Frame(comm_grid, bg="#f5f5f5", padx=10, pady=10)
        flash_frame.pack(side=tk.LEFT, expand=True, fill=tk.BOTH, padx=5)
        tk.Label(flash_frame, text="💾 W25Q64", font=("Arial", 10, "bold"), bg="#f5f5f5").pack()
        tk.Label(flash_frame, text="✓ 正常", font=("Arial", 9), bg="#f5f5f5", fg=self.colors['success']).pack()
        tk.Label(flash_frame, text="SPI Flash 8MB\nCS→GPIO9", 
                 font=("Consolas", 8), bg="#f5f5f5", fg="#666").pack(pady=5)

        # ========== OLED显示屏 ==========
        self._create_card(self.biz_frame, "OLED 状态显示屏 (SSD1306)").pack(fill=tk.X, pady=(0, 15))
        oled_body = self.last_card_body

        self.oled_canvas = tk.Canvas(oled_body, width=600, height=140, bg="black", highlightthickness=0)
        self.oled_canvas.pack(pady=5, expand=True)
        self._update_oled()

        # ========== 第二批：四路继电器 ==========
        self._create_card(self.biz_frame, "第二批：四路继电器控制 (低电平触发)").pack(fill=tk.X, pady=(0, 15))
        relay_body = self.last_card_body
        
        relay_grid = tk.Frame(relay_body, bg="white")
        relay_grid.pack(fill=tk.X, pady=10)
        
        relay_configs = [
            ("继电器1\n主灯", "GPIO17", 0),
            ("继电器2\n空调", "GPIO18", 1),
            ("继电器3\n窗帘", "GPIO5", 2),
            ("继电器4\n插座", "GPIO6", 3),
        ]
        
        self.relay_buttons = []
        for label, gpio, idx in relay_configs:
            relay_frame = tk.Frame(relay_grid, bg="#f5f5f5", padx=15, pady=10)
            relay_frame.pack(side=tk.LEFT, expand=True, padx=5)
            
            tk.Label(relay_frame, text=label, font=("Arial", 10, "bold"), bg="#f5f5f5").pack()
            tk.Label(relay_frame, text=f"IN{idx+1}→{gpio}", font=("Consolas", 8), bg="#f5f5f5", fg="#666").pack()
            
            btn = tk.Button(relay_frame, text="● 断开", bg="#999", fg="white",
                           relief=tk.FLAT, font=("Arial", 9, "bold"), width=8,
                           command=lambda i=idx: self._toggle_relay(i))
            btn.pack(pady=5)
            self.relay_buttons.append(btn)
        
        # 继电器电源信息
        relay_info = tk.Frame(relay_body, bg="#fff7e6", padx=10, pady=8)
        relay_info.pack(fill=tk.X, pady=5)
        tk.Label(relay_info, text="⚠️ 供电信息:", font=("Arial", 9, "bold"), bg="#fff7e6", fg="#fa8c16").pack(side=tk.LEFT)
        tk.Label(relay_info, text="DC+→电源模块+5V | DC-→电源模块GND(共地) | 低电平触发", 
                 font=("Consolas", 9), bg="#fff7e6", fg="#666").pack(side=tk.LEFT, padx=10)

        # ========== 第三批：红外 + EC11 + 按键 ==========
        self._create_card(self.biz_frame, "第三批：红外收发 + EC11编码器 + 功能按键").pack(fill=tk.X, pady=(0, 15))
        input_body = self.last_card_body
        
        input_grid = tk.Frame(input_body, bg="white")
        input_grid.pack(fill=tk.X, pady=10)
        
        # 红外接收
        ir_rx_frame = tk.Frame(input_grid, bg="#f5f5f5", padx=10, pady=10)
        ir_rx_frame.pack(side=tk.LEFT, expand=True, fill=tk.BOTH, padx=5)
        tk.Label(ir_rx_frame, text="📡 红外接收 (1838)", font=("Arial", 10, "bold"), bg="#f5f5f5").pack()
        tk.Label(ir_rx_frame, text="S→GPIO48 (IR_RX)\n中间→3V3  −→GND", 
                 font=("Consolas", 8), bg="#f5f5f5", fg="#666").pack(pady=5)
        self.ir_rx_var = tk.BooleanVar(value=True)
        tk.Checkbutton(ir_rx_frame, text="使能接收", variable=self.ir_rx_var,
                       bg="#f5f5f5", font=("Arial", 9)).pack()
        tk.Button(ir_rx_frame, text="模拟接收信号", command=self._simulate_ir_receive,
                  relief=tk.FLAT, bg=self.colors['primary'], fg="white", font=("Arial", 8)).pack(pady=5)
        
        # 红外发射
        ir_tx_frame = tk.Frame(input_grid, bg="#f5f5f5", padx=10, pady=10)
        ir_tx_frame.pack(side=tk.LEFT, expand=True, fill=tk.BOTH, padx=5)
        tk.Label(ir_tx_frame, text="📡 红外发射", font=("Arial", 10, "bold"), bg="#f5f5f5").pack()
        tk.Label(ir_tx_frame, text="GPIO47→100Ω电阻→发射管\n阳极(长)→阴极(短)→GND", 
                 font=("Consolas", 8), bg="#f5f5f5", fg="#666").pack(pady=5)
        self.ir_tx_var = tk.BooleanVar(value=True)
        tk.Checkbutton(ir_tx_frame, text="使能发射", variable=self.ir_tx_var,
                       bg="#f5f5f5", font=("Arial", 9)).pack()
        tk.Button(ir_tx_frame, text="发射测试", command=self._simulate_ir_transmit,
                  relief=tk.FLAT, bg=self.colors['warning'], fg="white", font=("Arial", 8)).pack(pady=5)
        
        # EC11旋转编码器
        ec11_frame = tk.Frame(input_grid, bg="#f5f5f5", padx=10, pady=10)
        ec11_frame.pack(side=tk.LEFT, expand=True, fill=tk.BOTH, padx=5)
        tk.Label(ec11_frame, text="🔄 EC11编码器", font=("Arial", 10, "bold"), bg="#f5f5f5").pack()
        tk.Label(ec11_frame, text="CLK→GPIO2\nDT→GPIO38 SW→GPIO4", 
                 font=("Consolas", 8), bg="#f5f5f5", fg="#666").pack(pady=5)
        self.ec11_pos_var = tk.StringVar(value="位置: 0")
        tk.Label(ec11_frame, textvariable=self.ec11_pos_var, font=("Arial", 9), bg="#f5f5f5").pack()
        ec11_btn_frame = tk.Frame(ec11_frame, bg="#f5f5f5")
        ec11_btn_frame.pack(pady=5)
        tk.Button(ec11_btn_frame, text="←", command=lambda: self._rotate_ec11(-1),
                  relief=tk.FLAT, bg="#e0e0e0", width=3).pack(side=tk.LEFT, padx=2)
        tk.Button(ec11_btn_frame, text="按键", command=self._press_ec11,
                  relief=tk.FLAT, bg=self.colors['primary'], fg="white", font=("Arial", 8)).pack(side=tk.LEFT, padx=5)
        tk.Button(ec11_btn_frame, text="→", command=lambda: self._rotate_ec11(1),
                  relief=tk.FLAT, bg="#e0e0e0", width=3).pack(side=tk.LEFT, padx=2)
        
        # 功能按键
        btn_frame = tk.Frame(input_grid, bg="#f5f5f5", padx=10, pady=10)
        btn_frame.pack(side=tk.LEFT, expand=True, fill=tk.BOTH, padx=5)
        tk.Label(btn_frame, text="🔘 功能按键", font=("Arial", 10, "bold"), bg="#f5f5f5").pack()
        
        # SOS键
        self.sos_btn = tk.Button(btn_frame, text="🆘 SOS", bg="#ff4d4f", fg="white",
                                 relief=tk.RAISED, font=("Arial", 9, "bold"), width=8,
                                 command=self._press_sos)
        self.sos_btn.pack(pady=3)
        tk.Label(btn_frame, text="GPIO7", font=("Consolas", 8), bg="#f5f5f5", fg="#666").pack()
        
        # PTT/接听键
        self.ptt_btn = tk.Button(btn_frame, text="📞 PTT/接听", bg="#52c41a", fg="white",
                                 relief=tk.RAISED, font=("Arial", 9, "bold"), width=10,
                                 command=self._press_ptt)
        self.ptt_btn.pack(pady=3)
        tk.Label(btn_frame, text="GPIO1 (短按接听/长按Agent)", font=("Consolas", 8), bg="#f5f5f5", fg="#666").pack()
        
        # 场景键
        self.scene_btn = tk.Button(btn_frame, text="🎭 场景", bg="#1890ff", fg="white",
                                   relief=tk.RAISED, font=("Arial", 9, "bold"), width=8,
                                   command=self._press_scene)
        self.scene_btn.pack(pady=3)
        tk.Label(btn_frame, text="GPIO20 (慎用)", font=("Consolas", 8), bg="#f5f5f5", fg="#666").pack()

        # ========== 第四批：I2S音频 ==========
        self._create_card(self.biz_frame, "第四批：I2S音频系统 (麦克风+功放)").pack(fill=tk.X, pady=(0, 15))
        audio_body = self.last_card_body
        
        audio_grid = tk.Frame(audio_body, bg="white")
        audio_grid.pack(fill=tk.X, pady=10)
        
        # I2S麦克风
        mic_frame = tk.Frame(audio_grid, bg="#f5f5f5", padx=15, pady=10)
        mic_frame.pack(side=tk.LEFT, expand=True, fill=tk.BOTH, padx=5)
        tk.Label(mic_frame, text="🎤 I2S麦克风", font=("Arial", 10, "bold"), bg="#f5f5f5").pack()
        tk.Label(mic_frame, text="BCLK→GPIO41\nWS/LRCLK→GPIO42\nDATA→GPIO39", 
                 font=("Consolas", 8), bg="#f5f5f5", fg="#666").pack(pady=5)
        self.mic_status = tk.Label(mic_frame, text="状态: 就绪", font=("Arial", 9), bg="#f5f5f5", fg=self.colors['success'])
        self.mic_status.pack()
        
        # 功放
        amp_frame = tk.Frame(audio_grid, bg="#f5f5f5", padx=15, pady=10)
        amp_frame.pack(side=tk.LEFT, expand=True, fill=tk.BOTH, padx=5)
        tk.Label(amp_frame, text="🔊 功放模块", font=("Arial", 10, "bold"), bg="#f5f5f5").pack()
        tk.Label(amp_frame, text="SDA/DATA→GPIO40\nVCC→电源模块5V\nGND→共地", 
                 font=("Consolas", 8), bg="#f5f5f5", fg="#666").pack(pady=5)
        self.amp_status = tk.Label(amp_frame, text="状态: 就绪", font=("Arial", 9), bg="#f5f5f5", fg=self.colors['success'])
        self.amp_status.pack()
        
        # 音频控制
        audio_ctrl = tk.Frame(audio_grid, bg="#f5f5f5", padx=15, pady=10)
        audio_ctrl.pack(side=tk.LEFT, expand=True, fill=tk.BOTH, padx=5)
        tk.Label(audio_ctrl, text="🎵 音频控制", font=("Arial", 10, "bold"), bg="#f5f5f5").pack()
        tk.Button(audio_ctrl, text="测试录音", command=self._test_mic,
                  relief=tk.FLAT, bg=self.colors['primary'], fg="white", font=("Arial", 9)).pack(pady=3)
        tk.Button(audio_ctrl, text="测试播放", command=self._test_speaker,
                  relief=tk.FLAT, bg=self.colors['success'], fg="white", font=("Arial", 9)).pack(pady=3)
        tk.Button(audio_ctrl, text="蜂鸣器测试", command=lambda: self._beep(2),
                  relief=tk.FLAT, bg=self.colors['warning'], fg="white", font=("Arial", 9)).pack(pady=3)

        # ========== 基础电器控制 ==========
        ctrl_container = tk.Frame(self.biz_frame, bg=self.colors['bg'])
        ctrl_container.pack(fill=tk.X, pady=(0, 15))

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

        # ========== 房间资产设置 ==========
        self._create_card(self.biz_frame, "房间资产设置").pack(fill=tk.X, pady=(0, 15))
        room_settings_body = self.last_card_body

        settings_f = tk.Frame(room_settings_body, bg="white")
        settings_f.pack(fill=tk.X)

        tk.Label(settings_f, text="当前房号:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        self.room_num_entry = tk.Entry(settings_f, width=10, font=("Arial", 10, "bold"))
        self.room_num_entry.insert(0, self.room_number_var.get() or self.room_id)
        self.room_num_entry.pack(side=tk.LEFT, padx=10)

        tk.Button(settings_f, text="应用并同步", bg=self.colors['primary'], fg="white",
                  command=self._apply_room_change, relief=tk.FLAT, font=("Arial", 9, "bold"), padx=10).pack(side=tk.LEFT)

        # ========== AI语音交互 ==========
        self._create_card(self.biz_frame, "AI 语音交互与话务终端").pack(fill=tk.BOTH, expand=True)
        ai_body = self.last_card_body

        # 呼叫控制区
        call_ctrl = tk.Frame(ai_body, bg="white")
        call_ctrl.pack(fill=tk.X, pady=(0, 10))

        self.call_btn = tk.Button(call_ctrl, text="📞 呼叫前台", bg=self.colors['primary'], fg="white",
                                 command=self._initiate_call, relief=tk.FLAT, font=("Arial", 10, "bold"),
                                 padx=15, pady=6)
        self.call_btn.pack(side=tk.LEFT)

        self.hangup_btn = tk.Button(call_ctrl, text="挂断", bg=self.colors['danger'], fg="white",
                                   command=self._hangup_call_manual, relief=tk.FLAT, font=("Arial", 10, "bold"),
                                   padx=15, pady=6)
        self.hangup_btn.pack(side=tk.LEFT, padx=10)
        self.hangup_btn.config(state=tk.DISABLED)

        # 语音输入区
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

        self.ai_chat = scrolledtext.ScrolledText(ai_body, height=8, bg="#f9f9f9", bd=0,
                                                 font=("Microsoft YaHei", 10), padx=15, pady=15)
        self.ai_chat.pack(fill=tk.BOTH, expand=True, pady=(0, 10))
        self.ai_chat.config(state=tk.DISABLED)
        self._add_chat("assistant", "您好，我是您的智能管家。您可以对我说\"开灯\"、\"帮我叫前台\"或者\"我想睡觉了\"。")

    def _toggle_power_card(self):
        """切换插卡取电状态"""
        self.power_card_inserted = not self.power_card_inserted
        if self.power_card_inserted:
            self.power_card_btn.config(text="取走房卡", bg="#595959")
            self._log("房卡已插入取电槽，开启全屋电力 (继电器4)")
            self._beep(1)
            # 开启继电器4 (插座/总电)
            if not self.relay_status[3]:
                self._toggle_relay(3)
            # 开启主灯
            if not self.light_on:
                self._toggle_light()
        else:
            self.power_card_btn.config(text="放置取电", bg=self.colors['warning'])
            self._log("房卡已取走，10秒后将自动断电...", "WARNING")
            self._beep(2)
            
            # 模拟延时断电
            def delayed_power_off():
                time.sleep(10)
                if not self.power_card_inserted:
                    self._log("延时断电触发：关闭全屋电力")
                    if self.relay_status[3]: self._toggle_relay(3)
                    if self.light_on: self._toggle_light()
                    if self.air_on: self._toggle_ac()
                    self._update_oled()
            
            threading.Thread(target=delayed_power_off, daemon=True).start()
        
        self._update_oled()
        self._report_occupancy() # 立即上报一次状态

    def _report_occupancy(self):
        """上报房间占用状态"""
        if self.mqtt_client and self.connected:
            self.mqtt_client.publish_occupancy_data(
                pir_activity=self.millimeter_wave_detected,
                card_power_state=self.power_card_inserted,
                power_consumption=120.5 if self.power_card_inserted else 5.0
            )

    def _simulate_card_swipe(self):
        """模拟 RFID 刷卡开门"""
        if not self.mqtt_client or not self.connected:
            self._log("未连接到服务器，无法校验刷卡", "ERROR")
            return
        
        success, result = self.rfid.swipe_card()
        if not success:
            # 只有在完全没放置卡片时，才弹出窗口要求输入 UID（用于测试未探测到的卡片）
            from tkinter import simpledialog
            uid_hex = simpledialog.askstring("RFID 模拟", "未探测到物理卡片，请输入模拟 UID (8位十六进制):", initialvalue="A1B2C3D4")
            if not uid_hex: return
            uid_hex = uid_hex.strip().upper()
        else:
            # 只要感应区有卡（哪怕是空白卡），直接读取其 UID 进行鉴权
            uid_hex = result['uid']

        self._log(f"探测到卡片 [UID: {uid_hex}]，正在请求云端鉴权...")
        self._beep(1)
        self.rfid_status_label.config(text="● 正在校验...", fg=self.colors['primary'])
        
        # 发送刷卡事件到服务器
        self.mqtt_client.publish_card_uid_event(uid_hex, room_id=self.room_id_var.get())
        
        # 3秒后恢复状态
        self.root.after(3000, lambda: self.rfid_status_label.config(text="✓ 就绪", fg=self.colors['success']))
    
    def _place_card(self):
        uid = self.card_uid_var.get()
        success, msg = self.rfid.place_card(uid)
        self.card_uid_var.set(self.rfid.uid)
        self._log(msg)
        self._draw_card()
        
        # 上报 card_uid_detected 事件，以便后端知道当前发卡器上有卡
        if self.mqtt_client and self.connected:
            self.mqtt_client.publish_security_event("card_uid_detected", level="info", event_data={
                "card_uid": self.rfid.uid,
                "device_id": self.device_id
            })

    def _draw_card(self):
        self.card_canvas.delete("all")
        cx, cy = 60, 40 # 针对客房端较小的 canvas 调整中心
        if self.rfid.has_card:
            # 绘制放置在读卡器上的卡片 (缩小版)
            self.card_canvas.create_rectangle(cx-50, cy-35, cx+50, cy+35,
                                             fill="#FFD700", outline="#B8860B", width=2)
            self.card_canvas.create_rectangle(cx-40, cy-15, cx-25, cy+5, fill="#C0C0C0", outline="#A0A0A0")

            if self.rfid.uid:
                self.card_canvas.create_text(cx+5, cy-10, text=f"UID: {self.rfid.uid}", font=("Consolas", 8, "bold"), fill="#595959")
            
            if self.rfid.card_data:
                room_id = self.rfid.card_data.get("room_id", "")
                self.card_canvas.create_text(cx+5, cy+15, text=f"ROOM: {room_id}", font=("Consolas", 10, "bold"), fill="#333")
            else:
                self.card_canvas.create_text(cx+5, cy+10, text="GUEST CARD", font=("Arial", 8), fill="#8B4513")
        else:
            # 绘制空的读卡器区域
            self.card_canvas.create_rectangle(cx-50, cy-35, cx+50, cy+35,
                                             fill="#f0f0f0", outline="#cccccc", dash=(4, 4), width=1)
            self.card_canvas.create_text(cx, cy, text="无卡", font=("Microsoft YaHei", 8), fill="#999")

    def _clear_card(self):
        """清除卡片状态"""
        self.rfid_card_present = False
        self.rfid_status_label.config(text="✓ 就绪", fg=self.colors['success'])
    
    def _simulate_radar_detect(self):
        """模拟毫米波雷达检测"""
        self.millimeter_wave_detected = True
        self.radar_status_label.config(text="● 有人", fg=self.colors['danger'])
        self._log("毫米波雷达检测到人体存在 (GPIO16)")
        self.root.after(3000, self._clear_radar)
    
    def _clear_radar(self):
        """清除雷达检测"""
        self.millimeter_wave_detected = False
        self.radar_status_label.config(text="○ 无人", fg="#999")
    
    def _toggle_relay(self, idx):
        """切换继电器状态"""
        self.relay_status[idx] = not self.relay_status[idx]
        status_text = "● 闭合" if self.relay_status[idx] else "● 断开"
        status_color = self.colors['success'] if self.relay_status[idx] else "#999"
        self.relay_buttons[idx].config(text=status_text, bg=status_color)
        self._log(f"继电器{idx+1}状态: {'闭合' if self.relay_status[idx] else '断开'}")
    
    def _simulate_ir_receive(self):
        """模拟红外接收"""
        if self.ir_rx_var.get():
            self._log("红外接收器接收到信号 (GPIO48)")
            self._beep(1)
        else:
            self._log("红外接收器已禁用", "WARNING")
    
    def _simulate_ir_transmit(self):
        """模拟红外发射"""
        if self.ir_tx_var.get():
            self._log("红外发射器发送信号 (GPIO47)")
            self._beep(1)
        else:
            self._log("红外发射器已禁用", "WARNING")
    
    def _rotate_ec11(self, direction):
        """旋转EC11编码器"""
        self.ec11_position += direction
        self.ec11_pos_var.set(f"位置: {self.ec11_position}")
        self._log(f"EC11编码器旋转: {'顺时针' if direction > 0 else '逆时针'} (CLK→GPIO2 DT→GPIO38)")
    
    def _press_ec11(self):
        """按下EC11按键"""
        self.ec11_button_pressed = True
        self._log("EC11按键按下 (GPIO4)")
        self._beep(1)
        self.root.after(200, lambda: setattr(self, 'ec11_button_pressed', False))
    
    def _press_sos(self):
        """按下SOS按键"""
        self.sos_button_pressed = True
        self.sos_btn.config(bg="#d9363e", relief=tk.SUNKEN)
        self._log("!!! SOS报警按键按下 (GPIO7) !!!", "ERROR")
        self._beep(3)
        
        # 触发报警
        if self.mqtt_client and self.connected:
            self.mqtt_client.publish_security_event("sos_alarm", level="critical", event_data={
                "room_id": self.room_id,
                "type": "room_sos",
                "message": f"房间{self.room_id} SOS报警"
            })
        
        self.root.after(500, lambda: self.sos_btn.config(bg="#ff4d4f", relief=tk.RAISED))
        self.root.after(500, lambda: setattr(self, 'sos_button_pressed', False))
    
    def _press_ptt(self):
        """按下PTT/接听按键"""
        self.ptt_button_pressed = True
        self.ptt_btn.config(bg="#389e0d", relief=tk.SUNKEN)
        self._log("PTT/接听按键按下 (GPIO1)")
        self._beep(1)
        
        # 短按接听/结束通话
        if self.is_in_call:
            self._hangup_call_manual()
        else:
            self._initiate_call()
        
        self.root.after(200, lambda: self.ptt_btn.config(bg="#52c41a", relief=tk.RAISED))
        self.root.after(200, lambda: setattr(self, 'ptt_button_pressed', False))
    
    def _press_scene(self):
        """按下场景按键"""
        self.scene_button_pressed = True
        self.scene_btn.config(bg="#096dd9", relief=tk.SUNKEN)
        self._log("场景按键按下 (GPIO20)")
        self._beep(1)
        self._apply_scene(CMD_VAL_WELCOME)
        self.root.after(200, lambda: self.scene_btn.config(bg="#1890ff", relief=tk.RAISED))
        self.root.after(200, lambda: setattr(self, 'scene_button_pressed', False))
    
    def _test_mic(self):
        """测试麦克风"""
        self.mic_status.config(text="状态: 测试中...", fg=self.colors['warning'])
        self._log("I2S麦克风测试中... (GPIO39 DATA)")
        self.root.after(2000, lambda: self.mic_status.config(text="状态: 正常", fg=self.colors['success']))
        self._beep(1)
    
    def _test_speaker(self):
        """测试扬声器"""
        self.amp_status.config(text="状态: 测试中...", fg=self.colors['warning'])
        self._log("功放测试中... (GPIO40 DATA)")
        self._beep(2)
        self.root.after(2000, lambda: self.amp_status.config(text="状态: 正常", fg=self.colors['success']))

    def _beep(self, count=1):
        """覆盖基类蜂鸣器，确保异步播放"""
        super()._beep(count)

    def _update_oled(self):
        self.oled_canvas.delete("all")
        w = 600
        h = 140
        self.oled_canvas.create_rectangle(0, 0, w, h, fill="#000000")
        self.oled_canvas.create_rectangle(5, 5, w-5, h-5, outline="#333333", width=1)

        # 如果有报警信息，优先显示
        if hasattr(self, 'oled_alarm_text') and self.oled_alarm_text:
            self.oled_canvas.create_text(w//2, h//2, text=self.oled_alarm_text, fill="#ff0000", 
                                        font=("Consolas", 28, "bold"), anchor=tk.CENTER)
            self.oled_canvas.create_text(w//2, h-20, text="PLEASE EVACUATE!", fill="#ff6600", 
                                        font=("Consolas", 12), anchor=tk.CENTER)
        else:
            display_room = self.room_number_var.get() or self.room_id
            self.oled_canvas.create_text(30, 40, text=f"ROOM: {display_room}", fill="#00FF00", font=("Consolas", 22, "bold"), anchor=tk.W)
            self.oled_canvas.create_text(30, 80, text=f"TEMP: {self.temp_val}C | HUMI: 55%", fill="white", font=("Consolas", 14), anchor=tk.W)
            status_str = f"LIGHT: {'ON' if self.light_on else 'OFF'} | AC: {'ON' if self.air_on else 'OFF'} | DOOR: {'OPEN' if self.door_unlocked else 'LOCKED'}"
            self.oled_canvas.create_text(30, 115, text=status_str, fill="#1890ff", font=("Consolas", 12), anchor=tk.W)
            
            # 显示雷达和房卡状态
            power_str = "CARD: " + ("INSERTED" if self.power_card_inserted else "REMOVED")
            power_color = "#52c41a" if self.power_card_inserted else "#faad14"
            self.oled_canvas.create_text(w-30, 80, text=power_str, fill=power_color, font=("Consolas", 10, "bold"), anchor=tk.E)

            radar_str = "RADAR: " + ("DETECT" if self.millimeter_wave_detected else "CLEAR")
            radar_color = "#ff4d4f" if self.millimeter_wave_detected else "#52c41a"
            self.oled_canvas.create_text(w-30, 115, text=radar_str, fill=radar_color, font=("Consolas", 10), anchor=tk.E)

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
        
        # 联动第四路继电器 (假设为门锁继电器)
        if not self.relay_status[3]:
            self._toggle_relay(3)
            
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
        
        # 关闭第四路继电器
        if self.relay_status[3]:
            self._toggle_relay(3)
            
        self._update_oled()
        self._log(f"{'[云端]' if from_cloud else '[本地]'} 门锁已锁定")

        if self._door_relock_timer:
            self.root.after_cancel(self._door_relock_timer)
            self._door_relock_timer = None

    def _auto_relock_door(self):
        if self.door_unlocked:
            self.door_unlocked = False
            self.door_btn.config(text="已锁定", bg=self.colors['success'])
            
            # 自动关闭第四路继电器
            if self.relay_status[3]:
                self._toggle_relay(3)
                
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

                self._log(f"传感器数据上报: 温度={temp}℃ 湿度={humi}% 光照={light_val}lx 门锁={'开' if self.door_unlocked else '锁'}")
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

        # 后端发送指令到 hotel/device/command/room/{device_id}
        # 同时订阅 device_id 和 room_id 两个主题，确保能收到指令
        cmd_topic = f"{TOPIC_DEVICE_COMMAND_PREFIX}/room/{self.device_id}"
        self.mqtt_client.subscribe(cmd_topic)
        self._log(f"已订阅客房指令主题 (device_id): {cmd_topic}")

        # 如果 room_id 与 device_id 不同，也订阅 room_id 主题
        if self.room_id and self.room_id != self.device_id:
            room_cmd_topic = f"{TOPIC_DEVICE_COMMAND_PREFIX}/room/{self.room_id}"
            self.mqtt_client.subscribe(room_cmd_topic)
            self._log(f"已订阅客房指令主题 (room_id): {room_cmd_topic}")

        # 订阅全局客房指令主题（用于接收全局消警等指令）
        all_cmd_topic = f"{TOPIC_DEVICE_COMMAND_PREFIX}/room/all"
        self.mqtt_client.subscribe(all_cmd_topic)
        self._log(f"已订阅全局客房指令主题: {all_cmd_topic}")

        # 订阅全局安防事件主题，实现联动报警
        self.mqtt_client.subscribe("hotel/security/event", self._on_security_event_from_others)
        self._log("已订阅全局安防事件主题: hotel/security/event")

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
        self.mqtt_client.register_command_handler("incoming_call", self._handle_incoming_call)
        self.mqtt_client.register_command_handler("answer_call", self._answer_call)
        self.mqtt_client.register_command_handler("call_answered", self._answer_call)
        self.mqtt_client.register_command_handler("hangup_call", self._handle_hangup_call)
        self.mqtt_client.register_command_handler("reject_call", self._handle_hangup_call)
        # 注册报警复位指令
        self.mqtt_client.register_command_handler("alarm_reset", self._handle_alarm_reset)
        # 注册房卡同步指令
        self.mqtt_client.register_command_handler("room_card_op", self._handle_room_card_op)

    def _handle_alarm_reset(self, data):
        """处理报警复位指令"""
        self._log("[Web指令] 收到消警指令，复位报警状态")
        # 清除OLED报警显示
        self.oled_alarm_text = None
        self._update_oled()
        self._beep(1)
        # 停止持续蜂鸣器
        self._stop_continuous_beep()
        return True

    def _handle_room_card_op(self, data):
        """处理房卡同步指令 (来自后端同步卡片信息)"""
        try:
            cmd_value = data.get('command_value', '{}')
            if isinstance(cmd_value, str):
                import json
                cmd_value = json.loads(cmd_value)
            
            action = cmd_value.get('action', '')
            card_uid = cmd_value.get('card_uid', '')
            
            # 如果 UID 匹配当前放置的卡片
            if card_uid == self.rfid.uid:
                if action == 'sync':
                    card_type = cmd_value.get('card_type', 'guest')
                    room_number = cmd_value.get('room_number', '')
                    holder_name = cmd_value.get('holder_name', '')
                    
                    self._log(f"[MQTT] 收到卡片同步: UID={card_uid}, 类型={card_type}, 房间={room_number}")
                    # 更新本地模拟器卡片数据
                    self.rfid.issue_card(room_number, card_type=card_type, holder_name=holder_name)
                    self._draw_card()
                    return True
                elif action == 'sync_clear':
                    self._log(f"[MQTT] 收到同步反馈: UID {card_uid} 为未知卡片")
                    self.rfid.reset_card()
                    self._draw_card()
                    return True
            return False
        except Exception as e:
            self._log(f"处理房卡同步指令失败: {e}", "ERROR")
            return False

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
                
                # 提取当前房间所在楼层
                # 房间ID格式可能是 "301" 或 "room_301"
                my_floor = ''
                if '_' in self.room_id:
                    room_num = self.room_id.split('_')[1]
                    my_floor = room_num[0] if room_num else ''
                else:
                    my_floor = self.room_id[0] if self.room_id else ''
                
                # 如果报警来自同一楼层，或者没有指定楼层（全楼报警），则联动
                should_trigger = False
                if not floor_id:
                    should_trigger = True  # 没有指定楼层，全楼报警
                elif floor_id == my_floor:
                    should_trigger = True  # 同楼层
                elif floor_id == self.room_id:
                    should_trigger = True  # 指定了本房间
                
                if should_trigger:
                    self._log(f"🔥 收到联动报警: 设备 {device_id} 触发消防报警", "ERROR")
                    self._trigger_alarm_from_other(device_id, room_id or floor_id, "fire")
            
            # 处理SOS报警联动
            elif event_type == 'sos_alarm':
                self._log(f"🆘 收到联动报警: 设备 {device_id} 触发SOS报警", "ERROR")
                self._trigger_alarm_from_other(device_id, event_data.get('room_id', 'unknown'), "sos")
                
        except Exception as e:
            self._log(f"处理联动报警事件失败: {e}", "ERROR")

    def _trigger_alarm_from_other(self, source_device, location, alarm_type):
        """由其他设备触发的联动报警"""
        # 在OLED上显示报警信息
        self.oled_alarm_text = f"ALERT! {alarm_type.upper()}"
        self._update_oled()
        
        # 蜂鸣器响3声
        self._beep(3)
        
        # 启动持续蜂鸣器（5秒后）
        self._start_continuous_beep()
        
        # 灯光闪烁效果（开灯-关灯-开灯）
        original_light = self.light_on
        self._set_light(True, from_cloud=True)
        self.root.after(500, lambda: self._set_light(False, from_cloud=True))
        self.root.after(1000, lambda: self._set_light(True, from_cloud=True))
        self.root.after(1500, lambda: self._set_light(False, from_cloud=True))
        self.root.after(2000, lambda: self._set_light(original_light, from_cloud=True))
        
        # 在AI聊天窗口显示报警信息
        alarm_msg = f"⚠️ 联动报警: {location} 发生{alarm_type}报警！请保持冷静，等待救援。"
        self._add_chat("assistant", alarm_msg)
        
        # 5秒后清除OLED报警显示
        self.root.after(5000, lambda: setattr(self, 'oled_alarm_text', None) or self._update_oled())
        
        # 上报联动报警事件
        if self.mqtt_client and self.connected:
            self.mqtt_client.publish_security_event("fire_alarm_linked", level="critical", event_data={
                "room_id": self.room_id,
                "source_device": source_device,
                "location": location,
                "type": f"linked_{alarm_type}_alarm",
                "message": f"房间{self.room_id}收到联动报警"
            })

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

    def _initiate_call(self):
        if not self.connected:
            messagebox.showwarning("提示", "网络未连接，无法发起呼叫")
            return
            
        self._log("正在发起呼叫前台...")
        self.call_btn.config(state=tk.DISABLED, text="正在呼叫...")
        self.hangup_btn.config(state=tk.NORMAL)
        
        # 模拟物理按键触发呼叫：向后端发送呼叫请求信令
        call_id = f"CALL{int(time.time())}{random.randint(100, 999)}"
        self.current_call_id = call_id
        
        if self.mqtt_client and self.connected:
            # 协议：硬件主动发起呼叫信令
            self.mqtt_client.publish(f"hotel/call/signaling/{call_id}", {
                "caller_type": "room",
                "caller_id": self.room_id,
                "device_id": self.unique_device_id,
                "callee_type": "front_desk",
                "callee_id": "all",
                "type": "voice",
                "action": "initiate"
            })
            self._add_chat("assistant", "正在为您接通前台，请稍候...")
        else:
            self._log("MQTT未连接，呼叫失败", "ERROR")
            self._reset_call_ui()

    def _hangup_call_manual(self):
        if not self.current_call_id:
            return
            
        self._log("正在挂断通话...")
        if self.mqtt_client and self.connected:
            self.mqtt_client.publish(f"hotel/call/signaling/{self.current_call_id}", {
                "action": "hangup",
                "call_id": self.current_call_id,
                "device_id": self.unique_device_id
            })
        
        self._handle_hangup_call({})
        self._reset_call_ui()

    def _reset_call_ui(self):
        self.call_btn.config(state=tk.NORMAL, text="📞 呼叫前台")
        self.hangup_btn.config(state=tk.DISABLED)

    def _handle_incoming_call(self, data):
        caller = data.get('created_by', '前台')
        self.current_call_id = data.get('call_id')
        self._log(f"收到来电: {caller}, CallID: {self.current_call_id}")
        self._add_chat("assistant", f"📞 {caller}正在呼叫您...")
        
        self.root.after(0, lambda: self.call_btn.config(state=tk.DISABLED, text="来电中..."))
        self.root.after(0, lambda: self.hangup_btn.config(state=tk.NORMAL))
        
        # 自动接听模拟（硬件设备通常需要物理按键，这里模拟自动接听或通过UI接听）
        self.root.after(1000, lambda: self._answer_call(data))
        
        # 模拟来电提示
        self._log("来电灯光提示中...")
        return True

    def _answer_call(self, data):
        if not self.current_call_id and data.get('call_id'):
            self.current_call_id = data.get('call_id')
            
        if not self.current_call_id:
            self._log("未找到通话ID，无法接听", "WARNING")
            return
        
        self.is_in_call = True
        self._log(f"通话已建立: {self.current_call_id}")
        self._add_chat("assistant", "通话已接通...")
        
        self.root.after(0, lambda: self.call_btn.config(state=tk.DISABLED, text="通话中..."))
        self.root.after(0, lambda: self.hangup_btn.config(state=tk.NORMAL))
        
        # 订阅音频主题 (下行：Cloud -> Hardware)
        audio_topic_down = f"hotel/call/audio/{self.current_call_id}/down"
        self.mqtt_client.subscribe(audio_topic_down)
        
        # 启动音频采集与播放
        if HAS_PYAUDIO:
            self._start_call_audio()
        else:
            self._log("未检测到 pyaudio，无法进行语音通话", "WARNING")
            self._add_chat("assistant", "[系统] 未检测到麦克风，通话仅信令在线")

    def _start_call_audio(self):
        try:
            if not self.pyaudio_instance:
                self.pyaudio_instance = pyaudio.PyAudio()
            
            # 打开输入流
            self._call_audio_stream = self.pyaudio_instance.open(
                format=pyaudio.paInt16,
                channels=1,
                rate=16000,
                input=True,
                frames_per_buffer=2048
            )
            
            # 打开输出流
            self._call_output_stream = self.pyaudio_instance.open(
                format=pyaudio.paInt16,
                channels=1,
                rate=16000,
                output=True,
                frames_per_buffer=2048
            )
            
            # 清空队列
            while not self._audio_in_queue.empty():
                try: self._audio_in_queue.get_nowait()
                except: break

            # 启动发送和播放线程
            threading.Thread(target=self._call_audio_sender_loop, daemon=True).start()
            threading.Thread(target=self._call_audio_playback_loop, daemon=True).start()
            self._log("通话音频链路已开启 (已启用抖动缓冲)")
        except Exception as e:
            self._log(f"开启音频链路失败: {e}", "ERROR")

    def _call_audio_sender_loop(self):
        # 上行流：Hardware -> Cloud
        audio_topic_up = f"hotel/call/audio/{self.current_call_id}/up"
        while self.is_in_call:
            try:
                with self._audio_lock:
                    if not self._call_audio_stream:
                        break
                    data = self._call_audio_stream.read(2048, exception_on_overflow=False)
                
                if self.mqtt_client and self.connected:
                    self.mqtt_client.publish_binary(audio_topic_up, data)
            except Exception as e:
                if self.is_in_call:
                    self._log(f"发送通话音频异常: {e}", "ERROR")
                break

    def _call_audio_playback_loop(self):
        """独立的音频播放线程，从队列中读取并写入声卡，防止阻塞 MQTT 回调"""
        # 初始缓冲：等待队列中有至少 2 个包再开始播放，减少抖动
        prebuffer_size = 2
        while self.is_in_call:
            try:
                # 获取数据（带超时以检查 is_in_call 状态）
                data = self._audio_in_queue.get(timeout=1.0)
                
                # 如果是刚开始，等待缓冲
                if prebuffer_size > 0 and self._audio_in_queue.qsize() < prebuffer_size:
                    # 继续等待更多数据
                    continue
                else:
                    prebuffer_size = 0 # 缓冲完成

                with self._audio_lock:
                    if self._call_output_stream:
                        self._call_output_stream.write(data)
                
                self._audio_in_queue.task_done()
            except queue.Empty:
                prebuffer_size = 2 # 队列空了，重新开始缓冲
                continue
            except Exception as e:
                if self.is_in_call:
                    self._log(f"音频播放异常: {e}", "ERROR")
                break

    def _handle_hangup_call(self, data):
        self._log("收到挂断信号")
        self.is_in_call = False
        self._stop_call_audio()
        self.current_call_id = None
        self._add_chat("assistant", "通话已挂断")
        self.root.after(0, self._reset_call_ui)
        return True

    def _stop_call_audio(self):
        with self._audio_lock:
            if self._call_audio_stream:
                try:
                    self._call_audio_stream.stop_stream()
                    self._call_audio_stream.close()
                except: pass
                self._call_audio_stream = None
                
            if self._call_output_stream:
                try:
                    self._call_output_stream.stop_stream()
                    self._call_output_stream.close()
                except: pass
                self._call_output_stream = None

    def _on_mqtt_message(self, topic, payload):
        # 1. 处理通话音频流 (下行：Cloud -> Hardware)
        if topic.endswith('/down') and "hotel/call/audio/" in topic and self.is_in_call:
            try:
                # 将音频数据放入队列，由独立线程播放，避免阻塞 MQTT 主循环
                self._audio_in_queue.put_nowait(payload)
            except queue.Full:
                # 如果队列满了，丢弃最旧的包以保持实时性
                try:
                    self._audio_in_queue.get_nowait()
                    self._audio_in_queue.put_nowait(payload)
                except: pass
            return

        # 2. 处理 JSON 业务指令与配置
        try:
            # 兼容 bytes 和 str
            if isinstance(payload, bytes):
                try:
                    payload = payload.decode('utf-8')
                except: pass
            
            data = json.loads(payload) if isinstance(payload, str) else payload
            if not data: return

            # 通用指令路由 (Cloud -> Hardware)
            cmd_type = data.get('command_type', '')
            if not cmd_type and 'action' in data: # 兼容信令格式
                cmd_type = data.get('action')

            if cmd_type:
                handler = self.mqtt_client.command_handlers.get(cmd_type)
                if handler:
                    self._log(f"收到云端指令: {cmd_type}")
                    # 确保在主线程执行 UI 相关操作
                    self.root.after(0, lambda: handler(data))
                else:
                    self._log(f"收到未注册指令: {cmd_type or topic}")
        except Exception as e:
            # 如果是二进制音频流但不符合主题过滤，忽略解析错误
            if not isinstance(payload, bytes):
                self._log(f"消息解析异常: {e}", "ERROR")

    def _update_audit_status_display(self):
        super()._update_audit_status_display()

    def _on_ai_response(self, data):
        super()._on_ai_response(data)
        text = data.get('response') or data.get('text')
        self.root.after(0, lambda: self._add_chat("assistant", text))
        self.root.after(0, lambda: self.ai_status_var.set("空闲"))
        self._log(f"AI 回复已收到 (长度:{len(text or '')})")
        
        # 处理 AI 下发的动作指令
        actions = data.get('actions', [])
        for action in actions:
            if action.get('type') == 'call_front_desk':
                self._initiate_call()
            elif action.get('type') == 'hangup_call':
                self._hangup_call_manual()


if __name__ == "__main__":
    root = tk.Tk()
    app = RoomTerminalEmulator(root)
    app.run()
