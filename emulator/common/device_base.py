"""
设备基类模块
"""
import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox
import threading
import time
import json
import urllib.request
import urllib.error
from .mqtt_client import MQTTClient
from .logger import Logger, get_log_buffer
from .config import TOPIC_DEVICE_COMMAND_PREFIX


class BaseDeviceEmulator:
    """设备仿真器基类"""
    
    def __init__(self, root, title, device_id, device_type, width=800, height=600):
        self.root = root
        self.root.title(title)
        self.root.geometry(f"{width}x{height}")
        
        self.device_id = device_id
        self.device_type = device_type
        self.mqtt_client = None
        
        self.logger = Logger(device_id)
        self.log_buffer = get_log_buffer()
        
        # 状态变量
        self.connected = False
        self.broker_var = tk.StringVar(value="172.20.10.3")
        self.port_var = tk.StringVar(value="1883")
        self.device_key_var = tk.StringVar(value="")  # 设备密钥
        self.hotel_id_var = tk.StringVar(value="")    # 酒店ID
        self.room_id_var = tk.StringVar(value="")     # 房间ID（从Web分配）
        
        # 生成唯一设备标识符
        self.unique_device_id = self._generate_device_id()
        
        self._create_ui()
        self._setup_log_callback()
        
        # 启动房间同步线程
        self._start_room_sync()
    
    def _generate_device_id(self):
        """生成唯一设备标识符"""
        import uuid
        # 格式: 类型_随机字符串
        prefix = self.device_type[:3].upper()
        unique_id = f"{prefix}_{uuid.uuid4().hex[:12].upper()}"
        return unique_id
    
    def _start_room_sync(self):
        """启动房间同步线程 - 从Web后台获取房间分配"""
        self._stop_sync = threading.Event()
        self._sync_thread = threading.Thread(target=self._room_sync_loop, daemon=True)
        self._sync_thread.start()
    
    def _room_sync_loop(self):
        """房间同步循环 - 每5秒检查一次Web分配"""
        while not self._stop_sync.is_set():
            if self.connected and self.mqtt_client and self.mqtt_client.hotel_id:
                self._fetch_room_assignment()
            time.sleep(5)
    
    def _fetch_room_assignment(self):
        """从Web后台获取房间分配"""
        try:
            # 通过MQTT订阅获取房间分配信息
            # 实际项目中这里可能是HTTP API调用
            pass
        except Exception as e:
            self.logger.error(f"获取房间分配失败: {e}")
    
    def _create_ui(self):
        """创建UI界面"""
        # 顶部连接栏
        self._create_connection_bar()
        
        # 主内容区
        self.main_frame = ttk.Frame(self.root, padding="10")
        self.main_frame.grid(row=1, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # 日志区
        self._create_log_area()
        
        # 配置grid权重
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(1, weight=1)
        self.main_frame.columnconfigure(0, weight=1)
        self.main_frame.rowconfigure(0, weight=1)
    
    def _create_connection_bar(self):
        """创建连接栏"""
        conn_frame = ttk.Frame(self.root, padding="10")
        conn_frame.grid(row=0, column=0, sticky=(tk.W, tk.E))
        
        # 显示唯一设备标识符
        ttk.Label(conn_frame, text="标识符:", font=("Arial", 9)).pack(side=tk.LEFT)
        self.unique_id_label = ttk.Label(conn_frame, text=self.unique_device_id, 
                                          font=("Consolas", 9), foreground="blue")
        self.unique_id_label.pack(side=tk.LEFT, padx=5)
        
        ttk.Button(conn_frame, text="📋", width=3, 
                   command=lambda: self._copy_to_clipboard(self.unique_device_id)).pack(side=tk.LEFT)
        
        ttk.Label(conn_frame, text="|").pack(side=tk.LEFT, padx=5)
        
        # 显示分配的房间
        ttk.Label(conn_frame, text="房间:", font=("Arial", 9)).pack(side=tk.LEFT)
        self.room_display = ttk.Label(conn_frame, textvariable=self.room_id_var, 
                                       font=("Arial", 9, "bold"), foreground="green", width=8)
        self.room_display.pack(side=tk.LEFT)
        
        ttk.Button(conn_frame, text="⚙️", width=3, command=self._show_config_dialog).pack(side=tk.LEFT, padx=5)
        
        ttk.Label(conn_frame, text="|").pack(side=tk.LEFT, padx=5)
        
        ttk.Label(conn_frame, text="Broker:").pack(side=tk.LEFT, padx=(5, 2))
        ttk.Entry(conn_frame, textvariable=self.broker_var, width=12).pack(side=tk.LEFT)
        
        ttk.Label(conn_frame, text="Port:").pack(side=tk.LEFT, padx=(5, 2))
        ttk.Entry(conn_frame, textvariable=self.port_var, width=5).pack(side=tk.LEFT)
        
        self.conn_btn = ttk.Button(conn_frame, text="连接", command=self._toggle_connection, width=6)
        self.conn_btn.pack(side=tk.LEFT, padx=10)
        
        self.status_label = ttk.Label(conn_frame, text="● 离线", foreground="red")
        self.status_label.pack(side=tk.LEFT, padx=2)
    
    def _show_config_dialog(self):
        """显示配置对话框（子类重写）"""
        dialog = tk.Toplevel(self.root)
        dialog.title("设备配置")
        dialog.geometry("500x400")
        dialog.transient(self.root)
        dialog.grab_set()
        
        # 唯一设备标识符（只读，用于Web后台注册）
        ttk.Label(dialog, text="唯一设备标识符 (Device ID):", font=("Arial", 10, "bold")).pack(pady=(20, 5))
        unique_frame = ttk.Frame(dialog)
        unique_frame.pack()
        ttk.Label(unique_frame, text=self.unique_device_id, font=("Consolas", 12), foreground="blue").pack(side=tk.LEFT)
        ttk.Button(unique_frame, text="复制", command=lambda: self._copy_to_clipboard(self.unique_device_id)).pack(side=tk.LEFT, padx=5)
        ttk.Label(dialog, text="*请将此ID在Web后台注册", font=("Arial", 9), foreground="red").pack()
        
        # 分隔线
        ttk.Separator(dialog, orient=tk.HORIZONTAL).pack(fill=tk.X, padx=20, pady=10)
        
        # 酒店ID
        ttk.Label(dialog, text="酒店ID:").pack(pady=(10, 5))
        hotel_entry = ttk.Entry(dialog, textvariable=self.hotel_id_var, width=20)
        hotel_entry.pack()
        
        # 设备密钥
        ttk.Label(dialog, text="设备密钥 (Device Key):").pack(pady=(10, 5))
        key_entry = ttk.Entry(dialog, textvariable=self.device_key_var, width=40, show="*")
        key_entry.pack()
        ttk.Label(dialog, text="*Web后台审核通过后生成", font=("Arial", 9), foreground="gray").pack()
        
        # 分配的房间
        ttk.Label(dialog, text="分配房间:").pack(pady=(10, 5))
        room_label = ttk.Label(dialog, textvariable=self.room_id_var, font=("Arial", 12, "bold"), foreground="green")
        room_label.pack()
        
        def save_config():
            # 更新MQTT客户端的密钥
            if self.mqtt_client:
                self.mqtt_client.device_key = self.device_key_var.get()
                try:
                    self.mqtt_client.hotel_id = int(self.hotel_id_var.get()) if self.hotel_id_var.get() else None
                except:
                    self.mqtt_client.hotel_id = None
            
            messagebox.showinfo("提示", "配置已保存，请重新连接MQTT以生效")
            dialog.destroy()
        
        ttk.Button(dialog, text="保存", command=save_config).pack(pady=20)
    
    def _copy_to_clipboard(self, text):
        """复制文本到剪贴板"""
        self.root.clipboard_clear()
        self.root.clipboard_append(text)
        messagebox.showinfo("提示", "已复制到剪贴板")
    
    def _create_log_area(self):
        """创建日志区域"""
        log_frame = ttk.LabelFrame(self.main_frame, text="MQTT日志", padding="5")
        log_frame.grid(row=1, column=0, sticky=(tk.W, tk.E, tk.N, tk.S), pady=10)
        
        self.log_text = scrolledtext.ScrolledText(
            log_frame, height=10, wrap=tk.WORD, font=("Consolas", 9)
        )
        self.log_text.pack(fill=tk.BOTH, expand=True)
        self.log_text.config(state=tk.DISABLED)
        
        # 清除日志按钮
        ttk.Button(log_frame, text="清除日志", command=self._clear_logs).pack(anchor=tk.E, pady=5)
    
    def _setup_log_callback(self):
        """设置日志回调"""
        self.log_buffer.add_callback(self._on_log)
    
    def _on_log(self, log_entry):
        """日志回调函数"""
        def update():
            self.log_text.config(state=tk.NORMAL)
            self.log_text.insert(tk.END, log_entry + "\n")
            self.log_text.see(tk.END)
            self.log_text.config(state=tk.DISABLED)
        
        self.root.after(0, update)
    
    def _clear_logs(self):
        """清除日志"""
        self.log_text.config(state=tk.NORMAL)
        self.log_text.delete(1.0, tk.END)
        self.log_text.config(state=tk.DISABLED)
        self.log_buffer.clear()
    
    def _toggle_connection(self):
        """切换连接状态"""
        if self.connected:
            self.disconnect()
        else:
            self.connect()
    
    def connect(self):
        """连接MQTT"""
        try:
            broker = self.broker_var.get()
            port = int(self.port_var.get())
            device_key = self.device_key_var.get()
            
            self.mqtt_client = MQTTClient(self.device_id, self.device_type, broker, port, device_key)
            
            # 设置酒店ID
            try:
                self.mqtt_client.hotel_id = int(self.hotel_id_var.get()) if self.hotel_id_var.get() else None
            except:
                self.mqtt_client.hotel_id = None
            
            self._register_command_handlers()
            
            # 订阅命令主题
            cmd_topic = f"{TOPIC_DEVICE_COMMAND_PREFIX}/{self.device_type}/{self.device_id}"
            self.mqtt_client.subscribe(cmd_topic)
            
            # 订阅房间分配更新主题
            assign_topic = f"hotel/device/assignment/{self.unique_device_id}"
            self.mqtt_client.subscribe(assign_topic, self._on_room_assigned)
            
            if self.mqtt_client.connect():
                self.connected = True
                self.conn_btn.config(text="断开")
                self.status_label.config(text="● 在线", foreground="green")
                self._on_connected()
        except Exception as e:
            self.logger.error(f"连接失败: {e}")
    
    def _on_room_assigned(self, topic, payload):
        """处理房间分配更新"""
        try:
            data = json.loads(payload)
            room_id = data.get("room_id")
            hotel_id = data.get("hotel_id")
            device_key = data.get("device_key")
            
            if room_id:
                self.room_id_var.set(str(room_id))
                self.logger.info(f"房间已分配: {room_id}")
                
                # 更新UI显示
                self.root.after(0, lambda: messagebox.showinfo("房间分配", f"您已被分配到房间: {room_id}"))
            
            if hotel_id:
                self.hotel_id_var.set(str(hotel_id))
            
            if device_key:
                self.device_key_var.set(device_key)
                if self.mqtt_client:
                    self.mqtt_client.device_key = device_key
                    self.mqtt_client.audit_status = "approved"
        
        except Exception as e:
            self.logger.error(f"处理房间分配失败: {e}")
    
    def disconnect(self):
        """断开MQTT"""
        if self.mqtt_client:
            self.mqtt_client.disconnect()
            self.mqtt_client = None
        
        self.connected = False
        self.conn_btn.config(text="连接")
        self.status_label.config(text="● 离线", foreground="red")
        self._on_disconnected()
    
    def _register_command_handlers(self):
        """注册命令处理器（子类重写）"""
        pass
    
    def _on_connected(self):
        """连接成功回调（子类重写）"""
        # 连接成功后自动注册设备到Web后台
        self._register_device_to_web()
    
    def _register_device_to_web(self):
        """通过HTTP API注册设备到Web后台"""
        try:
            hotel_id = self.hotel_id_var.get()
            if not hotel_id:
                self.logger.info("未配置酒店ID，跳过HTTP注册")
                return
            
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
            
            # 发送HTTP POST请求到后端
            backend_url = f"http://{self.broker_var.get()}:9000/api/v1/devices/register"
            
            req = urllib.request.Request(
                backend_url,
                data=json.dumps(register_data).encode('utf-8'),
                headers={'Content-Type': 'application/json'},
                method='POST'
            )
            
            # 在后台线程中发送请求
            def do_register():
                try:
                    with urllib.request.urlopen(req, timeout=5) as response:
                        result = json.loads(response.read().decode('utf-8'))
                        if result.get('success'):
                            self.logger.info(f"设备注册成功: {result.get('data', {}).get('status', 'unknown')}")
                            # 如果已审核，更新密钥
                            if result.get('data', {}).get('device_key'):
                                self.device_key_var.set(result['data']['device_key'])
                                if self.mqtt_client:
                                    self.mqtt_client.device_key = result['data']['device_key']
                                    self.mqtt_client.audit_status = "approved"
                        else:
                            self.logger.warning(f"设备注册失败: {result.get('message')}")
                except Exception as e:
                    self.logger.error(f"HTTP注册请求失败: {e}")
            
            threading.Thread(target=do_register, daemon=True).start()
            
        except Exception as e:
            self.logger.error(f"设备注册失败: {e}")
    
    def _on_disconnected(self):
        """断开连接回调（子类重写）"""
        pass
    
    def run(self):
        """运行主循环"""
        self.root.mainloop()
