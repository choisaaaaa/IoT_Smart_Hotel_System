import os
import json
import uuid
import time
import threading
import urllib.request
import base64
from datetime import datetime
import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox
import paho.mqtt.client as mqtt
from .mqtt_client import MQTTClient
from .logger import Logger, get_log_buffer
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
        self.room_id_var = tk.StringVar(value="")     # 房间ID
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
                    self.backend_url_var.set(config.get('backend_url', 'http://localhost:9000'))
                    self.broker_var.set(config.get('mqtt_broker', '8.134.166.69'))
                    
                    # 加载已有的设备ID，保持身份一致
                    saved_device_id = config.get('device_id')
                    if saved_device_id:
                        self.unique_device_id = saved_device_id
                        # 更新设备ID变量，确保子类一致
                        self.device_id = saved_device_id
                    
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
        setup_win.geometry("400x450")
        setup_win.transient(self.root)
        setup_win.grab_set()

        tk.Label(setup_win, text="欢迎使用智慧酒店设备仿真器", font=("Arial", 12, "bold")).pack(pady=10)
        tk.Label(setup_win, text="请完成初始配置以连接系统", font=("Arial", 10)).pack(pady=5)

        form_frame = tk.Frame(setup_win, padx=20)
        form_frame.pack(fill=tk.BOTH, expand=True)

        tk.Label(form_frame, text="酒店选择:").grid(row=0, column=0, sticky=tk.W, pady=5)
        self.hotel_select = ttk.Combobox(form_frame, state="readonly")
        self.hotel_select.grid(row=0, column=1, sticky=tk.EW, pady=5)
        
        # 刷新酒店列表按钮
        tk.Button(form_frame, text="刷新列表", command=lambda: self._fetch_hotel_list(backend_entry.get())).grid(row=0, column=2, padx=5)

        tk.Label(form_frame, text="后端 API 地址:").grid(row=1, column=0, sticky=tk.W, pady=5)
        backend_entry = tk.Entry(form_frame)
        backend_entry.insert(0, self.backend_url_var.get() or "http://localhost:9000")
        backend_entry.grid(row=1, column=1, sticky=tk.EW, pady=5)
        
        # 初始加载酒店列表
        self.hotels_data = []
        self._fetch_hotel_list(backend_entry.get())

        tk.Label(form_frame, text="MQTT Broker:").grid(row=2, column=0, sticky=tk.W, pady=5)
        mqtt_entry = tk.Entry(form_frame)
        mqtt_entry.insert(0, self.broker_var.get() or "8.134.166.69")
        mqtt_entry.grid(row=2, column=1, sticky=tk.EW, pady=5)

        tk.Label(form_frame, text="MQTT Port:").grid(row=3, column=0, sticky=tk.W, pady=5)
        port_entry = tk.Entry(form_frame)
        port_entry.insert(0, "1883")
        port_entry.grid(row=3, column=1, sticky=tk.EW, pady=5)

        def save_and_close():
            # 从下拉框获取选中的酒店ID
            selection_idx = self.hotel_select.current()
            if selection_idx < 0:
                messagebox.showerror("错误", "请先选择所属酒店")
                return
            
            selected_hotel = self.hotels_data[selection_idx]
            hotel_id = selected_hotel['id']
            backend_url = backend_entry.get()
            mqtt_broker = mqtt_entry.get()
            mqtt_port = port_entry.get()

            if not all([hotel_id, backend_url, mqtt_broker, mqtt_port]):
                messagebox.showerror("错误", "请填写完整信息")
                return

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
                "device_type": self.device_type
            }

            if self._save_config(config):
                self.configured = True
                setup_win.destroy()
                self._init_ui()
                self._log("设备初始化成功", "SUCCESS")
                self._log(f"设备物理ID: {self.unique_device_id}")
                self._log(f"所属酒店: {selected_hotel['name']} (ID: {hotel_id})")

        tk.Button(setup_win, text="完成配置并启动", command=save_and_close, bg="#1890ff", fg="white", padx=20).pack(pady=20)

    def _fetch_hotel_list(self, backend_url):
        """从后端获取酒店列表"""
        try:
            # 去掉末尾斜杠
            base_url = backend_url.rstrip('/')
            url = f"{base_url}/api/v1/hotels/search?destination="
            
            # 兼容性处理：如果是 localhost 且请求失败，尝试使用 127.0.0.1
            url = url.replace('localhost', '127.0.0.1')
            
            # 强制禁用代理
            proxy_handler = urllib.request.ProxyHandler({})
            opener = urllib.request.build_opener(proxy_handler)
            
            def do_fetch():
                try:
                    with opener.open(url, timeout=5) as response:
                        result = json.loads(response.read().decode('utf-8'))
                        # 兼容两种格式：{ success: true, data: { hotels: [...] } } 或直接数据
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
                except Exception as e:
                    print(f"获取酒店列表失败: {e}")
                    self.root.after(0, lambda: self.hotel_select.config(values=["获取失败，请检查后端地址"]))

            threading.Thread(target=do_fetch, daemon=True).start()
        except Exception as e:
            print(f"启动获取酒店列表线程失败: {e}")

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
        """重新进入配网流程"""
        if self.connected:
            if not messagebox.askyesno("确认", "重新配网需要先断开当前连接，是否继续？"):
                return
            self._disconnect()
        
        # 弹出确认对话框
        if messagebox.askyesno("重置确认", "重新配网将保留设备物理ID，但允许修改酒店ID和后端地址。是否继续？"):
            self._show_setup_wizard()

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
        tk.Label(title_container, text=f" ID: {self.device_id}", font=("Consolas", 11), 
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
                                          font=("Arial", 10, "bold"), bg=self.colors['card'], fg=self.colors['warning'])
        self.audit_status_label.pack(side=tk.LEFT, padx=5)

        # 控制面板布局
        self.main_container = tk.Frame(self.root, bg=self.colors['bg'], padx=20, pady=20)
        self.main_container.pack(fill=tk.BOTH, expand=True)

        # 左侧: 业务控制区 (由子类填充)
        self.biz_frame = tk.Frame(self.main_container, bg=self.colors['bg'])
        self.biz_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

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
            
            # 1. 首先尝试通过HTTP API注册设备
            self._register_device_to_web()

            # 2. 初始化MQTT客户端
            self.mqtt_client = MQTTClient(
                self.unique_device_id, 
                self.device_type, 
                broker, 
                port, 
                device_key,
                hotel_id=int(hotel_id) if hotel_id else 1
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
                
                # 发布在线状态
                self.mqtt_client.publish_online_status()
            else:
                self._log("连接失败，请检查网络或 Broker 地址", "ERROR")
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

    def _register_device_to_web(self):
        """通过HTTP API注册设备到Web后台"""
        try:
            hotel_id = self.hotel_id_var.get()
            backend_url = self.backend_url_var.get()
            
            self._log(f"开始注册设备到Web后台...")
            self._log(f"后端地址: {backend_url}")
            self._log(f"酒店ID: {hotel_id}")
            self._log(f"设备ID: {self.unique_device_id}")
            
            if not hotel_id:
                self._log("未配置酒店ID，跳过HTTP注册", "WARNING")
                return
            
            # 兼容性处理：如果是 localhost 且请求失败，尝试使用 127.0.0.1
            current_backend_url = backend_url.replace('localhost', '127.0.0.1')
            
            # 构建注册数据
            register_data = {
                "device_id": self.unique_device_id,
                "device_type": self.device_type,
                "device_name": f"{self.device_type}_{self.unique_device_id[-6:]}",
                "firmware_version": "v1.1.0-emulator",
                "hotel_id": int(hotel_id),
                "ip_address": "127.0.0.1",
                "mac_address": "00:00:00:00:00:00"
            }
            
            self._log(f"注册数据: {register_data}")
            
            # 发送HTTP POST请求到后端
            register_url = f"{current_backend_url}/api/v1/devices/register"
            self._log(f"注册URL: {register_url}")
            
            # 强制禁用代理，避免 localhost 请求走系统代理导致失败
            proxy_handler = urllib.request.ProxyHandler({})
            opener = urllib.request.build_opener(proxy_handler)
            
            req = urllib.request.Request(
                register_url,
                data=json.dumps(register_data).encode('utf-8'),
                headers={'Content-Type': 'application/json'},
                method='POST'
            )
            
            # 在后台线程中发送请求
            def do_register():
                try:
                    self._log("正在发送注册请求...")
                    # 使用 opener 以确保不走代理
                    with opener.open(req, timeout=10) as response:
                        result = json.loads(response.read().decode('utf-8'))
                        self._log(f"注册响应: {result}")
                        if result.get('success'):
                            status = result.get('data', {}).get('status', 'unknown')
                            self._log(f"设备注册成功: {status}", "SUCCESS")
                            # 更新审核状态
                            if self.mqtt_client:
                                if status == 'approved':
                                    self.mqtt_client.audit_status = "approved"
                                elif status == 'pending':
                                    self.mqtt_client.audit_status = "pending"
                                # 更新UI显示
                                self.root.after(0, self._update_audit_status_display)
                            # 如果已审核，更新密钥
                            if result.get('data', {}).get('device_key'):
                                self.device_key_var.set(result['data']['device_key'])
                                if self.mqtt_client:
                                    self.mqtt_client.device_key = result['data']['device_key']
                                # 保存更新后的配置（含密钥）
                                self._save_config({
                                    'hotel_id': int(hotel_id),
                                    'backend_url': backend_url,
                                    'mqtt_broker': self.broker_var.get(),
                                    'mqtt_port': self.port_var.get(),
                                    'device_id': self.unique_device_id,
                                    'device_type': self.device_type,
                                    'device_key': self.device_key_var.get()
                                })
                        else:
                            self._log(f"设备注册失败: {result.get('message')}", "WARNING")
                except urllib.error.HTTPError as e:
                    self._log(f"HTTP注册请求失败: {e.code} - {e.reason}", "ERROR")
                    try:
                        error_body = e.read().decode('utf-8')
                        self._log(f"错误详情: {error_body}", "ERROR")
                    except:
                        pass
                except urllib.error.URLError as e:
                    self._log(f"网络连接错误: {e.reason}", "ERROR")
                    self._log("请检查后端是否正在运行，且地址是否正确。如果是本地开发，建议使用 http://127.0.0.1:9000", "WARNING")
                except Exception as e:
                    self._log(f"HTTP注册请求发生未知错误: {e}", "ERROR")
            
            threading.Thread(target=do_register, daemon=True).start()
            
        except Exception as e:
            self._log(f"设备注册准备失败: {e}", "ERROR")

    def _on_mqtt_message(self, topic, payload):
        """处理通用的MQTT消息（子类应覆盖此方法）"""
        self._log(f"接收消息 [{topic}]: {payload}")

    def _on_ai_response(self, data):
        """处理AI响应消息"""
        text = data.get('response') or data.get('text')
        audio_base64 = data.get('audio_base64') or data.get('audio_data')
        
        self._log(f"AI管家回复: {text}")
        self.ai_status_var.set("播放中...")
        
        # 模拟播放语音
        if audio_base64:
            self._log("正在播放语音答复...")
            # 实际项目中这里可以使用 pygame.mixer 或 pydub 播放音频
            # 为了演示，我们只记录日志
        
        # 延迟恢复状态
        self.root.after(3000, lambda: self.ai_status_var.set("空闲"))

    def _update_audit_status_display(self):
        """更新审核状态显示"""
        if self.mqtt_client:
            audit_status = self.mqtt_client.audit_status
            status_map = {
                "pending": ("待审核", self.colors['warning']),
                "approved": ("已激活", self.colors['success']),
                "rejected": ("被拒绝", self.colors['danger'])
            }
            text, color = status_map.get(audit_status, ("未注册", self.colors['text_secondary']))
            self.audit_status_var.set(text)
            self.audit_status_label.config(fg=color)

    def run(self):
        """运行主循环"""
        self.root.mainloop()
