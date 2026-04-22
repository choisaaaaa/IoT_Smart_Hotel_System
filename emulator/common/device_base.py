import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
import json
import time
import threading
import uuid
import os
import requests
import base64
import io
from datetime import datetime
try:
    import pygame
    HAS_PYGAME = True
except ImportError:
    HAS_PYGAME = False

from .mqtt_client import MQTTClient
from .logger import Logger
from .config import TOPIC_DEVICE_COMMAND_PREFIX, TOPIC_AI_REQUEST, TOPIC_AI_RESPONSE

class BaseDeviceEmulator:
    """设备仿真器基类"""

    def __init__(self, root, title, device_id, device_type, width=800, height=600):
        self.root = root
        self.root.title(title)
        self.root.geometry(f"{width}x{height}")

        self.device_id = device_id
        self.device_type = device_type
        self.mqtt_client = None
        self.connected = False

        # 音频锁，防止多线程竞争播放器资源
        self._audio_lock = threading.Lock()

        # 初始化音频
        self._init_audio()

        # 立即初始化 logger 以防后续报错
        self.logger = Logger(str(self.device_id) if self.device_id else f"{self.device_type}_emu")

        # 生成唯一的设备ID，用于注册（如果配置中没有则生成）
        self.unique_device_id = self._generate_device_id()

        # 配置变量
        self.broker_var = tk.StringVar(value="8.134.166.69")
        self.port_var = tk.StringVar(value="1883")
        self.backend_url_var = tk.StringVar(value="http://localhost:9000")  # 后端API地址，本地开发默认localhost
        self.device_key_var = tk.StringVar(value="")  # 设备密钥
        self.hotel_id_var = tk.StringVar(value="")    # 酒店ID
        self.room_id_var = tk.StringVar(value="")     # 房间数据库ID
        self.room_number_var = tk.StringVar(value="") # 房间显示编号
        self.area_var = tk.StringVar(value="")        # 区域名称
        self.audit_status_var = tk.StringVar(value="未注册")
        self.ai_status_var = tk.StringVar(value="空闲")

        # 检查是否需要配网初始化
        self.configured = self._check_if_configured()

        # 如果已配置，确保 unique_device_id 从配置中加载，否则生成新的
        if self.configured:
            # unique_device_id 已经在 _check_if_configured 中被加载（如果存在）
            pass

        if not self.configured:
            self._show_setup_wizard()
        else:
            self._init_ui()
            self._log(f"设备仿真器已启动: {self.device_id} ({self.device_type})")
            self._log(f"设备物理ID: {self.unique_device_id}")

    def _generate_device_id(self):
        """生成唯一的物理设备ID"""
        import uuid
        # 获取MAC地址作为部分标识（模拟真实硬件）
        prefix = self.device_type[:3].upper()
        unique_id = f"{prefix}_{uuid.uuid4().hex[:12].upper()}"
        return unique_id

    def _check_if_configured(self):
        """检查配置文件是否存在且有效"""
        config_path = f"{self.device_type}_config.json"
        if os.path.exists(config_path):
            try:
                with open(config_path, 'r') as f:
                    config = json.load(f)
                    self.hotel_id_var.set(str(config.get('hotel_id', '')))
                    self.room_id_var.set(str(config.get('room_id', '')))
                    self.room_number_var.set(config.get('room_number', ''))
                    self.area_var.set(config.get('area', ''))
                    self.backend_url_var.set(config.get('backend_url', 'http://localhost:9000'))
                    self.broker_var.set(config.get('mqtt_broker', '8.134.166.69'))

                    # 加载已有的设备ID，保持身份一致
                    saved_device_id = config.get('device_id')
                    
                    # 检查是否是硬编码的旧 ID，如果是，则强制重置为唯一 ID
                    legacy_ids = ["room_301", "floor_03", "front_desk_01", "room_302", "floor_01"]
                    if saved_device_id in legacy_ids:
                        print(f"检测到硬编码旧 ID: {saved_device_id}，正在重置为唯一物理 ID...")
                        self.unique_device_id = self._generate_device_id()
                        self.device_id = self.unique_device_id
                        return False # 强制进入配网流程或重新注册

                    if saved_device_id:
                        self.unique_device_id = saved_device_id
                        # 更新设备ID变量，确保子类一致
                        self.device_id = saved_device_id
                        self.device_id_var.set(f" ID: {self.device_id}")

                    # 如果配置中有密钥，也加载
                    saved_key = config.get('device_key')
                    if saved_key:
                        self.device_key_var.set(saved_key)

                    return True
            except Exception as e:
                print(f"加载配置失败: {e}")
        return False

    def _save_config(self, config_data):
        """保存配置到文件"""
        config_path = f"{self.device_type}_config.json"
        try:
            with open(config_path, 'w') as f:
                json.dump(config_data, f)
            return True
        except Exception as e:
            print(f"保存配置失败: {e}")
        return False

    def _show_setup_wizard(self):
        """显示初始化向导"""
        setup_win = tk.Toplevel(self.root)
        setup_win.title("设备初始化配网")
        setup_win.geometry("450x500")
        setup_win.transient(self.root)
        setup_win.grab_set()

        tk.Label(setup_win, text="欢迎使用智慧酒店设备仿真器", font=("Arial", 12, "bold")).pack(pady=10)
        tk.Label(setup_win, text="请完成初始配置以连接系统", font=("Arial", 10)).pack(pady=5)

        form_frame = tk.Frame(setup_win, padx=20)
        form_frame.pack(fill=tk.BOTH, expand=True)

        # 后端地址（决定酒店列表来源）
        tk.Label(form_frame, text="后端 API 地址:").grid(row=0, column=0, sticky=tk.W, pady=8)
        backend_entry = tk.Entry(form_frame)
        backend_entry.insert(0, self.backend_url_var.get() or "http://localhost:9000")
        backend_entry.grid(row=0, column=1, sticky=tk.EW, pady=8)

        # 酒店选择
        tk.Label(form_frame, text="所属酒店:").grid(row=1, column=0, sticky=tk.W, pady=8)
        self.hotel_select = ttk.Combobox(form_frame, state="readonly")
        self.hotel_select.grid(row=1, column=1, sticky=tk.EW, pady=8)

        # 刷新按钮
        tk.Button(form_frame, text="🔄 刷新", command=lambda: self._fetch_hotel_list(backend_entry.get())).grid(row=1, column=2, padx=5)

        # 初始加载酒店列表
        self.hotels_data = []
        self._fetch_hotel_list(backend_entry.get())

        tk.Label(form_frame, text="MQTT Broker:").grid(row=2, column=0, sticky=tk.W, pady=8)
        mqtt_entry = tk.Entry(form_frame)
        mqtt_entry.insert(0, self.broker_var.get() or "8.134.166.69")
        mqtt_entry.grid(row=2, column=1, sticky=tk.EW, pady=8)

        tk.Label(form_frame, text="MQTT Port:").grid(row=3, column=0, sticky=tk.W, pady=8)
        port_entry = tk.Entry(form_frame)
        port_entry.insert(0, "1883")
        port_entry.grid(row=3, column=1, sticky=tk.EW, pady=8)

        def save_and_close():
            selection_idx = self.hotel_select.current()
            if selection_idx < 0:
                messagebox.showerror("错误", "请先选择所属酒店")
                return

            selected_hotel = self.hotels_data[selection_idx]
            hotel_id = selected_hotel['id']
            backend_url = backend_entry.get()
            mqtt_broker = mqtt_entry.get()
            mqtt_port = port_entry.get()

            self.hotel_id_var.set(str(hotel_id))
            self.backend_url_var.set(backend_url)
            self.broker_var.set(mqtt_broker)
            self.port_var.set(mqtt_port)

            config = {
                "hotel_id": int(hotel_id),
                "backend_url": backend_url,
                "mqtt_broker": mqtt_broker,
                "mqtt_port": mqtt_port,
                "device_id": self.unique_device_id,
                "device_type": self.device_type,
                "room_id": self.room_id_var.get(),
                "room_number": self.room_number_var.get(),
                "area": self.area_var.get()
            }

            if self._save_config(config):
                self.configured = True
                setup_win.destroy()
                if not hasattr(self, 'main_container'):
                    self._init_ui()
                self._log(f"初始化成功！所属酒店: {selected_hotel['name']}", "SUCCESS")

        tk.Button(setup_win, text="保存并进入系统", command=save_and_close, bg=self.colors['primary'] if hasattr(self, 'colors') else "#1890ff", fg="white", font=("Arial", 10, "bold"), pady=10).pack(fill=tk.X, padx=40, pady=20)

    def _fetch_hotel_list(self, backend_url):
        """从后端获取酒店列表 (已修复 urllib 未定义错误)"""
        try:
            # 去掉末尾斜杠
            base_url = backend_url.rstrip('/')
            url = f"{base_url}/api/v1/hotels/search?destination="

            # 自动修正 localhost 为 127.0.0.1
            if "localhost" in url:
                url = url.replace("localhost", "127.0.0.1")

            def do_fetch():
                try:
                    # 使用 requests 库，它更稳定且能自动处理系统代理
                    response = requests.get(url, timeout=5)
                    if response.status_code == 200:
                        result = response.json()
                        # 兼容多种返回格式
                        hotels = []
                        if isinstance(result, dict):
                            if 'data' in result and 'hotels' in result['data']:
                                hotels = result['data']['hotels']
                            elif 'success' in result and isinstance(result.get('data'), list):
                                hotels = result['data']

                        if hotels:
                            self.hotels_data = hotels
                            values = [f"{h['name']} (ID: {h['id']})" for h in hotels]
                            # 在主线程更新UI
                            self.root.after(0, lambda: self._update_hotel_select(values))
                        else:
                            self.root.after(0, lambda: self.hotel_select.config(values=["未搜索到酒店"]))
                    else:
                        self.root.after(0, lambda: self.hotel_select.config(values=[f"请求失败 ({response.status_code})"]))
                except Exception as e:
                    print(f"获取酒店列表过程出错: {e}")
                    self.root.after(0, lambda: self.hotel_select.config(values=["获取失败，请检查网络"]))

            threading.Thread(target=do_fetch, daemon=True).start()
        except Exception as e:
            print(f"初始化酒店列表线程失败: {e}")

    def _update_hotel_select(self, values):
        """更新酒店下拉框内容"""
        self.hotel_select['values'] = values
        if values:
            # 尝试根据已有的 hotel_id 自动选中
            current_id = self.hotel_id_var.get()
            found = False
            if current_id:
                for i, h in enumerate(self.hotels_data):
                    if str(h['id']) == current_id:
                        self.hotel_select.current(i)
                        found = True
                        break
            if not found:
                self.hotel_select.current(0)

    def _reconfigure(self):
        """重新弹出配网配置对话框 (支持酒店列表获取)"""
        dialog = tk.Toplevel(self.root)
        dialog.title("设备网络与资产配置")
        dialog.geometry("480x580")
        dialog.transient(self.root)
        dialog.grab_set()

        main_f = tk.Frame(dialog, padx=20, pady=20)
        main_f.pack(fill=tk.BOTH, expand=True)

        tk.Label(main_f, text="设备配网与资产参数修改", font=("Arial", 12, "bold")).pack(pady=(0, 20))

        # 配置表单
        form = tk.Frame(main_f)
        form.pack(fill=tk.X)

        # 1. 后端 API 地址 (决定酒店列表)
        tk.Label(form, text="后端 API 地址:").grid(row=0, column=0, sticky=tk.W, pady=8)
        backend_entry = tk.Entry(form)
        backend_entry.insert(0, self.backend_url_var.get() or "http://localhost:9000")
        backend_entry.grid(row=0, column=1, sticky=tk.EW, pady=8)

        # 2. 酒店选择
        tk.Label(form, text="所属酒店:").grid(row=1, column=0, sticky=tk.W, pady=8)
        self.hotel_select = ttk.Combobox(form, state="readonly")
        self.hotel_select.grid(row=1, column=1, sticky=tk.EW, pady=8)

        # 刷新按钮
        tk.Button(form, text="🔄 刷新", command=lambda: self._fetch_hotel_list(backend_entry.get())).grid(row=1, column=2, padx=5)

        # 初始加载
        self.hotels_data = []
        self._fetch_hotel_list(backend_entry.get())

        # 3. MQTT 配置
        tk.Label(form, text="MQTT Broker:").grid(row=2, column=0, sticky=tk.W, pady=8)
        mqtt_entry = tk.Entry(form)
        mqtt_entry.insert(0, self.broker_var.get() or "8.134.166.69")
        mqtt_entry.grid(row=2, column=1, sticky=tk.EW, pady=8)

        tk.Label(form, text="MQTT Port:").grid(row=3, column=0, sticky=tk.W, pady=8)
        port_entry = tk.Entry(form)
        port_entry.insert(0, self.port_var.get() or "1883")
        port_entry.grid(row=3, column=1, sticky=tk.EW, pady=8)

        def save():
            selection_idx = self.hotel_select.current()
            if selection_idx < 0:
                messagebox.showerror("错误", "请先选择所属酒店")
                return

            selected_hotel = self.hotels_data[selection_idx]
            hotel_id = selected_hotel['id']
            backend_url = backend_entry.get()
            mqtt_broker = mqtt_entry.get()
            mqtt_port = port_entry.get()

            self.hotel_id_var.set(str(hotel_id))
            self.backend_url_var.set(backend_url)
            self.broker_var.set(mqtt_broker)
            self.port_var.set(mqtt_port)

            # 保存并同步
            self._save_config({
                'hotel_id': int(hotel_id),
                'backend_url': backend_url,
                'mqtt_broker': mqtt_broker,
                'mqtt_port': mqtt_port,
                'device_id': self.unique_device_id,
                'device_type': self.device_type,
                'room_id': self.room_id_var.get(),
                'room_number': self.room_number_var.get(),
                'area': self.area_var.get()
            })

            dialog.destroy()
            self._log(f"配置已更新至: {selected_hotel['name']}，正在同步云端...", "INFO")
            self._register_device_to_web()

        tk.Button(main_f, text="确认并保存", bg=self.colors['primary'], fg="white",
                  command=save, pady=10, font=("Arial", 10, "bold")).pack(fill=tk.X, pady=(20, 0))

    def _register_device_to_web(self, callback=None):
        """通过 HTTP API 注册/同步设备信息"""
        def do_register():
            try:
                hotel_id = self.hotel_id_var.get()
                backend_url = self.backend_url_var.get()
                room_num = self.room_number_var.get()

                if not hotel_id:
                    self._log("未配置酒店ID，无法注册", "WARNING")
                    return

                # 自动修正 localhost 为 127.0.0.1 以避免某些环境下的解析问题
                if "localhost" in backend_url:
                    backend_url = backend_url.replace("localhost", "127.0.0.1")

                register_url = f"{backend_url}/api/v1/devices/register"

                payload = {
                    "device_id": self.unique_device_id,
                    "device_type": self.device_type,
                    "device_name": f"{self.device_type}_{self.unique_device_id[-4:]}",
                    "hotel_id": int(hotel_id),
                    "room_number": room_num, # 允许模拟器主动申领房号
                    "firmware_version": "v1.2.0-smart",
                    "ip_address": "127.0.0.1"
                }

                self._log(f"正在同步云端配置: {register_url}")

                # 使用 requests 发送请求，它会自动处理系统代理
                response = requests.post(register_url, json=payload, timeout=10)

                if response.status_code == 200:
                    result = response.json()
                    if result.get('success'):
                        data = result.get('data', {})
                        self._log(f"云端同步成功: {data.get('status', 'ok')}", "SUCCESS")

                        # 更新本地资产信息
                        if data.get('room_id'): self.room_id_var.set(str(data['room_id']))
                        if data.get('room_number'): self.room_number_var.set(data['room_number'])
                        if data.get('area'): self.area_var.set(data['area'])

                        # 更新密钥
                        if data.get('device_key'):
                            self.device_key_var.set(data['device_key'])
                            if self.mqtt_client:
                                self.mqtt_client.device_key = data['device_key']

                        # 更新审核状态
                        status = data.get('audit_status') or data.get('status')
                        if self.mqtt_client:
                            if status == 'approved':
                                self.mqtt_client.audit_status = "approved"
                            elif status == 'pending':
                                self.mqtt_client.audit_status = "pending"
                        
                        # 触发 UI 更新回调
                        if hasattr(self, '_on_config_updated'):
                            self.root.after(0, self._on_config_updated)

                        self.root.after(0, self._update_audit_status_display)

                        # 持久化
                        self._save_config({
                            'hotel_id': int(hotel_id),
                            'room_id': data.get('room_id'),
                            'room_number': data.get('room_number'),
                            'area': data.get('area'),
                            'backend_url': self.backend_url_var.get(),
                            'mqtt_broker': self.broker_var.get(),
                            'mqtt_port': self.port_var.get(),
                            'device_id': self.unique_device_id,
                            'device_type': self.device_type,
                            'device_key': self.device_key_var.get()
                        })

                        # 执行成功回调
                        if callback:
                            self.root.after(0, lambda: callback(data))
                    else:
                        self._log(f"同步失败: {result.get('message')}", "ERROR")
                else:
                    self._log(f"后端返回错误: {response.status_code}", "ERROR")

            except requests.exceptions.ConnectionError:
                self._log("无法连接到后端服务器，请检查公网/内网地址是否正确", "ERROR")
            except Exception as e:
                self._log(f"同步过程发生异常: {str(e)}", "ERROR")

        threading.Thread(target=do_register, daemon=True).start()

    def _init_ui(self):
        """初始化通用UI组件 - 现代化扁平化设计"""
        # 定义颜色主题
        self.colors = {
            'primary': '#1890ff',
            'success': '#52c41a',
            'warning': '#faad14',
            'danger': '#ff4d4f',
            'bg': '#f0f2f5',
            'card': '#ffffff',
            'text': '#262626',
            'text_secondary': '#8c8c8c',
            'border': '#f0f0f0'
        }

        self.root.configure(bg=self.colors['bg'])

        # 顶部状态栏
        self.status_frame = tk.Frame(self.root, bg=self.colors['card'], height=60, bd=0)
        self.status_frame.pack(side=tk.TOP, fill=tk.X)
        self.status_frame.pack_propagate(False)

        # 标题与ID
        title_container = tk.Frame(self.status_frame, bg=self.colors['card'])
        title_container.pack(side=tk.LEFT, padx=20)

        tk.Label(title_container, text=f"{self.device_type.upper()}", font=("Arial", 11, "bold"),
                 bg=self.colors['primary'], fg="white", padx=10, pady=4).pack(side=tk.LEFT)
        self.device_id_var = tk.StringVar(value=self.device_id)
        tk.Label(title_container, textvariable=self.device_id_var, font=("Consolas", 11),
                 bg=self.colors['card'], fg=self.colors['text']).pack(side=tk.LEFT, padx=8)

        # 连接状态
        self.conn_indicator = tk.Canvas(self.status_frame, width=14, height=14, bg=self.colors['card'], highlightthickness=0)
        self.conn_indicator.pack(side=tk.LEFT, padx=(30, 0))
        self.conn_dot = self.conn_indicator.create_oval(2, 2, 12, 12, fill=self.colors['danger'], outline="")

        self.conn_status_label = tk.Label(self.status_frame, text="已断开", font=("Arial", 10),
                                         bg=self.colors['card'], fg=self.colors['danger'])
        self.conn_status_label.pack(side=tk.LEFT, padx=8)

        # 审核状态
        tk.Label(self.status_frame, text="|  审核:", font=("Arial", 10), bg=self.colors['card'],
                 fg=self.colors['text_secondary']).pack(side=tk.LEFT, padx=(20, 0))
        self.audit_status_label = tk.Label(self.status_frame, textvariable=self.audit_status_var,
                                          font=("Arial", 10, "bold"), bg=self.colors['card'], fg=self.colors['text_secondary'])
        self.audit_status_label.pack(side=tk.LEFT, padx=5)

        # 控制面板布局
        self.main_container = tk.Frame(self.root, bg=self.colors['bg'], padx=20, pady=20)
        self.main_container.pack(fill=tk.BOTH, expand=True)

        # 左侧: 业务控制区 (带滚动条)
        self.biz_canvas = tk.Canvas(self.main_container, bg=self.colors['bg'], highlightthickness=0)
        self.biz_scrollbar = ttk.Scrollbar(self.main_container, orient="vertical", command=self.biz_canvas.yview)
        self.biz_canvas.configure(yscrollcommand=self.biz_scrollbar.set)

        self.biz_scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        self.biz_canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        # 容器 Frame
        self.biz_frame = tk.Frame(self.biz_canvas, bg=self.colors['bg'])
        self.biz_canvas_window = self.biz_canvas.create_window((0, 0), window=self.biz_frame, anchor="nw")

        # 绑定事件以自适应宽度和滚动范围
        self.biz_frame.bind("<Configure>", self._on_biz_frame_configure)
        self.biz_canvas.bind("<Configure>", self._on_biz_canvas_configure)

        # 绑定鼠标滚轮 (仅在鼠标进入画布区域时生效)
        self.biz_canvas.bind("<Enter>", self._bind_mousewheel)
        self.biz_canvas.bind("<Leave>", self._unbind_mousewheel)

        # 右侧: 系统管理区
        self.sys_sidebar = tk.Frame(self.main_container, bg=self.colors['bg'], width=300)
        self.sys_sidebar.pack(side=tk.RIGHT, fill=tk.Y, padx=(20, 0))
        self.sys_sidebar.pack_propagate(False)

        # 1. 网络连接卡片
        self._create_card(self.sys_sidebar, "网络连接").pack(fill=tk.X, pady=(0, 20))
        net_body = self.last_card_body

        self.conn_btn = tk.Button(net_body, text="连接系统", command=self._toggle_connection,
                                 bg=self.colors['success'], fg="white", font=("Arial", 10, "bold"),
                                 relief=tk.FLAT, cursor="hand2", pady=10)
        self.conn_btn.pack(fill=tk.X, pady=5)

        self.reconfig_btn = tk.Button(net_body, text="重新配网 / 注册", command=self._reconfigure,
                                     bg=self.colors['warning'], fg="white", font=("Arial", 10),
                                     relief=tk.FLAT, cursor="hand2", pady=8)
        self.reconfig_btn.pack(fill=tk.X, pady=5)

        self.sync_btn = tk.Button(net_body, text="同步云端资产信息", command=self._register_device_to_web,
                                 bg=self.colors['primary'], fg="white", font=("Arial", 10),
                                 relief=tk.FLAT, cursor="hand2", pady=8)
        self.sync_btn.pack(fill=tk.X, pady=5)

        # 2. AI助手卡片
        self._create_card(self.sys_sidebar, "AI 管家").pack(fill=tk.X, pady=(0, 20))
        ai_body = self.last_card_body

        ai_status_container = tk.Frame(ai_body, bg=self.colors['card'])
        ai_status_container.pack(fill=tk.X)
        tk.Label(ai_status_container, text="当前状态:", bg=self.colors['card'], font=("Arial", 10), fg=self.colors['text_secondary']).pack(side=tk.LEFT)
        tk.Label(ai_status_container, textvariable=self.ai_status_var, font=("Arial", 10, "bold"),
                 bg=self.colors['card'], fg=self.colors['primary']).pack(side=tk.LEFT, padx=8)

        # 3. 系统日志卡片
        self._create_card(self.sys_sidebar, "系统实时日志").pack(fill=tk.BOTH, expand=True)
        log_body = self.last_card_body

        self.log_text = scrolledtext.ScrolledText(log_body, font=("Consolas", 9), bg="#1e1e1e", fg="#d4d4d4",
                                                 insertbackground="white", bd=0, padx=10, pady=10)
        self.log_text.pack(fill=tk.BOTH, expand=True)

        # 4. 初始化业务特有UI (由子类实现)
        if hasattr(self, '_init_biz_ui'):
            self._init_biz_ui()

    def _create_card(self, parent, title):
        """创建一个美观的卡片容器"""
        card = tk.Frame(parent, bg=self.colors['card'], highlightthickness=1, highlightbackground=self.colors['border'])

        # 卡片标题栏
        header = tk.Frame(card, bg='#fafafa', height=40)
        header.pack(fill=tk.X)
        header.pack_propagate(False)

        # 装饰性线条
        tk.Frame(header, bg=self.colors['primary'], width=4).pack(side=tk.LEFT, fill=tk.Y)
        tk.Label(header, text=title, font=("Arial", 10, "bold"), bg='#fafafa', fg=self.colors['text']).pack(side=tk.LEFT, padx=12)

        # 卡片内容区
        self.last_card_body = tk.Frame(card, bg=self.colors['card'], padx=15, pady=15)
        self.last_card_body.pack(fill=tk.BOTH, expand=True)

        return card

    def _log(self, message, level="INFO"):
        """统一日志记录方法，同时记录到系统日志和GUI"""
        timestamp = datetime.now().strftime('%H:%M:%S')
        log_msg = f"[{timestamp}] [{level}] {message}\n"

        # 记录到系统日志 (console)
        if hasattr(self, 'logger'):
            if level == "INFO": self.logger.info(message)
            elif level == "ERROR": self.logger.error(message)
            elif level == "WARNING": self.logger.warning(message)

        # 记录到 GUI
        if hasattr(self, 'log_text') and self.log_text:
            try:
                self.log_text.insert(tk.END, log_msg)
                self.log_text.see(tk.END)

                # 设置颜色
                if level == "ERROR":
                    self.log_text.tag_add("error", "end-2c linestart", "end-1c")
                    self.log_text.tag_config("error", foreground=self.colors['danger'])
                elif level == "WARNING":
                    self.log_text.tag_add("warning", "end-2c linestart", "end-1c")
                    self.log_text.tag_config("warning", foreground=self.colors['warning'])
                elif level == "SUCCESS":
                    self.log_text.tag_add("success", "end-2c linestart", "end-1c")
                    self.log_text.tag_config("success", foreground=self.colors['success'])
            except Exception:
                pass

    def _toggle_connection(self):
        """切换连接状态"""
        if not self.connected:
            self._connect()
        else:
            self._disconnect()

    def _connect(self):
        """开始连接流程"""
        try:
            broker = self.broker_var.get()
            port = int(self.port_var.get())
            hotel_id = self.hotel_id_var.get()
            device_key = self.device_key_var.get()

            self._log(f"正在建立系统连接...")

            def on_registered(server_data=None):
                # 提取审核状态
                effective_status = None
                if server_data:
                    effective_status = server_data.get('audit_status') or server_data.get('status')

                # 2. 初始化MQTT客户端
                self.mqtt_client = MQTTClient(
                    self.unique_device_id,
                    self.device_type,
                    broker,
                    port,
                    self.device_key_var.get(), # 使用最新的 key
                    hotel_id=int(self.hotel_id_var.get()) if self.hotel_id_var.get() else 1,
                    audit_status=effective_status
                )

                if self.mqtt_client.connect():
                    self.connected = True
                    self.conn_indicator.itemconfig(self.conn_dot, fill=self.colors['success'])
                    self.conn_status_label.config(text="已连接", fg=self.colors['success'])
                    self.conn_btn.config(text="断开连接", bg=self.colors['danger'])
                    self._log("MQTT 连接成功", "SUCCESS")

                    # 设置回调
                    self.mqtt_client.on_message = self._on_mqtt_message
                    self.mqtt_client.on_ai_response = self._on_ai_response

                    # 订阅配置更新主题
                    config_topic = f"hotel/device/config/{self.device_type}/{self.unique_device_id}"
                    self.mqtt_client.subscribe(config_topic, self._on_config_push)

                    # 发布在线状态
                    self.mqtt_client.publish_online_status()

                    # 触发子类连接成功回调
                    if hasattr(self, '_on_connected'):
                        self._on_connected()
                else:
                    self._log("连接失败，请检查网络或 Broker 地址", "ERROR")

            # 1. 首先尝试通过HTTP API注册/同步设备信息，成功后再连接MQTT
            self._register_device_to_web(callback=on_registered)

        except Exception as e:
            self._log(f"连接过程出错: {e}", "ERROR")

    def _disconnect(self):
        """断开连接"""
        if self.mqtt_client:
            self.mqtt_client.disconnect()

        self.connected = False
        self.conn_indicator.itemconfig(self.conn_dot, fill=self.colors['danger'])
        self.conn_status_label.config(text="已断开", fg=self.colors['danger'])
        self.conn_btn.config(text="连接系统", bg=self.colors['success'])
        self._log("已安全断开系统连接")

    def _on_mqtt_message(self, topic, payload):
        """处理通用的MQTT消息（子类应覆盖此方法）"""
        self._log(f"接收消息 [{topic}]: {payload}")

    def _on_config_push(self, topic, payload):
        """处理云端推送的配置更新"""
        try:
            data = json.loads(payload)
            self._log(f"收到云端配置推送: {data.get('audit_status')}", "SUCCESS")

            # 更新审核状态
            status = data.get('audit_status')
            if status:
                if self.mqtt_client:
                    self.mqtt_client.audit_status = status

            # 更新密钥
            device_key = data.get('device_key')
            if device_key:
                self.device_key_var.set(device_key)
                if self.mqtt_client:
                    self.mqtt_client.device_key = device_key

            # 更新资产信息
            if data.get('room_id'): self.room_id_var.set(str(data['room_id']))
            if data.get('room_number'): self.room_number_var.set(data['room_number'])
            if data.get('area'): self.area_var.set(data['area'])

            # 触发 UI 更新回调
            if hasattr(self, '_on_config_updated'):
                self.root.after(0, self._on_config_updated)

            # 更新状态显示
            self.root.after(0, self._update_audit_status_display)

            # 持久化
            self._save_config({
                'hotel_id': int(self.hotel_id_var.get() or data.get('hotel_id', 1)),
                'room_id': self.room_id_var.get(),
                'room_number': self.room_number_var.get(),
                'area': self.area_var.get(),
                'backend_url': self.backend_url_var.get(),
                'mqtt_broker': self.broker_var.get(),
                'mqtt_port': self.port_var.get(),
                'device_id': self.unique_device_id,
                'device_type': self.device_type,
                'device_key': self.device_key_var.get()
            })

        except Exception as e:
            self._log(f"解析云端配置失败: {e}", "ERROR")

    def _on_ai_response(self, data):
        """处理AI响应消息并播放音频"""
        text = data.get('response') or data.get('text')
        audio_base64 = data.get('audio_base64') or data.get('audio_data')

        self._log(f"AI管家回复: {text}")
        self.ai_status_var.set("播放中...")

        # 实际播放音频
        if audio_base64:
            self._log("正在播放语音答复...")
            try:
                audio_data = base64.b64decode(audio_base64)
                # 尝试播放
                self._play_audio_stream(audio_data)
            except Exception as e:
                self._log(f"音频播放失败: {e}", "ERROR")

        # 延迟恢复状态
        self.root.after(3000, lambda: self.ai_status_var.set("空闲"))

    def _init_audio(self):
        """初始化音频播放器"""
        self.audio_enabled = False
        if HAS_PYGAME:
            try:
                # 预设参数，减少延迟和潜在冲突
                pygame.mixer.pre_init(44100, -16, 2, 2048)
                pygame.mixer.init()
                self.audio_enabled = True
                self.logger.info("Pygame Mixer 初始化成功")
            except Exception as e:
                print(f"音频初始化失败: {e}")

    def _play_audio_stream(self, data):
        """播放音频流数据 (线程安全并防止重叠卡死)"""
        if not self.audio_enabled:
            return

        def play_thread():
            with self._audio_lock:
                try:
                    # 停止之前的播放以防冲突
                    if pygame.mixer.music.get_busy():
                        pygame.mixer.music.stop()
                        pygame.mixer.music.unload() # 释放旧资源

                    # 识别音频格式或假设为 MP3/WAV
                    f = io.BytesIO(data)
                    pygame.mixer.music.load(f)
                    pygame.mixer.music.play()
                    while pygame.mixer.music.get_busy():
                        time.sleep(0.1)
                except Exception as e:
                    self.logger.error(f"播放流媒体失败: {e}")

        # 使用 daemon 线程，程序退出时自动终止
        threading.Thread(target=play_thread, daemon=True).start()

    def _play_beep(self, frequency=1000, duration=200):
        """异步播放模拟蜂鸣器声音 (避免卡死UI)"""
        def beep_thread():
            try:
                import winsound
                # winsound.Beep 是同步阻塞的，必须放在独立线程
                winsound.Beep(frequency, duration)
            except (ImportError, Exception):
                pass

        threading.Thread(target=beep_thread, daemon=True).start()

    def _update_audit_status_display(self):
        """更新审核状态显示"""
        if self.mqtt_client:
            audit_status = self.mqtt_client.audit_status
            status_map = {
                "pending": ("待审核", self.colors['warning']),
                "approved": ("已激活", self.colors['success']),
                "active": ("已激活", self.colors['success']),
                "registered": ("已激活", self.colors['success']),
                "rejected": ("被拒绝", self.colors['danger'])
            }
            text, color = status_map.get(audit_status, ("未注册", self.colors['text_secondary']))
            self.audit_status_var.set(text)
            self.audit_status_label.config(fg=color)

    def _on_biz_frame_configure(self, event):
        """更新滚动区域范围"""
        self.biz_canvas.configure(scrollregion=self.biz_canvas.bbox("all"))

    def _on_biz_canvas_configure(self, event):
        """同步 Canvas 宽度到内层 Frame"""
        self.biz_canvas.itemconfig(self.biz_canvas_window, width=event.width)

    def _on_mousewheel(self, event):
        """处理鼠标滚轮"""
        self.biz_canvas.yview_scroll(int(-1 * (event.delta / 120)), "units")

    def _bind_mousewheel(self, event):
        """当鼠标进入时绑定滚轮事件"""
        self.biz_canvas.bind_all("<MouseWheel>", self._on_mousewheel)

    def _unbind_mousewheel(self, event):
        """当鼠标离开时取消绑定滚轮事件"""
        self.biz_canvas.unbind_all("<MouseWheel>")

    def run(self):
        if self.device_key_var.get() and self.broker_var.get():
            self.root.after(1500, self._auto_connect)
        self.root.mainloop()

    def _auto_connect(self):
        if not self.connected:
            self._log("检测到已有配置，自动连接中...")
            self._connect()
