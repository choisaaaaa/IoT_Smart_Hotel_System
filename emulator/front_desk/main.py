"""
前台管理端仿真器 - 主程序
"""
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

import tkinter as tk
from tkinter import ttk, messagebox
from datetime import datetime
from common.device_base import BaseDeviceEmulator
from common.mqtt_client import MQTTClient
from common.config import (
    CMD_ISSUE_CARD, CMD_VERIFY_CARD, CMD_SWIPE_CARD,
    CMD_INCOMING_CALL, CMD_HANGUP_CALL
)


class RFIDCardSimulator:
    """RFID卡片模拟器"""
    
    def __init__(self):
        self.card_data = None  # 当前卡片数据
        self.has_card = False  # 是否有卡
    
    def issue_card(self, room_id):
        """开卡 - 写入房间号"""
        self.card_data = {"room_id": room_id, "issued_at": datetime.now().isoformat()}
        self.has_card = True
        return True, f"开卡成功: 房间{room_id}"
    
    def verify_card(self):
        """验卡 - 读取卡片"""
        if not self.has_card:
            return False, "未检测到有效房卡"
        room_id = self.card_data.get("room_id", "unknown")
        return True, f"验卡通过: 房间{room_id}"
    
    def swipe_card(self):
        """刷卡 - 模拟刷卡动作"""
        if not self.has_card:
            return False, "未检测到有效房卡"
        room_id = self.card_data.get("room_id", "unknown")
        return True, room_id
    
    def remove_card(self):
        """移除卡片"""
        self.has_card = False
        self.card_data = None
    
    def insert_card(self, room_id=None):
        """插入卡片（模拟）"""
        if room_id:
            self.card_data = {"room_id": room_id, "issued_at": datetime.now().isoformat()}
        self.has_card = True


class FrontDeskEmulator(BaseDeviceEmulator):
    """前台管理端仿真器"""
    
    def __init__(self, root):
        self.device_id = "front_desk_01"
        
        # 先初始化子类特有属性（在调用父类__init__之前）
        self.rfid = RFIDCardSimulator()
        self.target_room_var = tk.StringVar(value="301")
        self.last_card_room = ""
        self.led_color = (0, 0, 255)  # 默认蓝色
        self.front_id_var = tk.StringVar(value="01")  # 用于配置对话框
        
        super().__init__(
            root=root,
            title=f"智慧酒店 - 前台管理端仿真器 ({self.device_id})",
            device_id=self.device_id,
            device_type="front_desk",
            width=900,
            height=700
        )
    
    def _create_ui(self):
        """创建UI界面"""
        super()._create_ui()
        
        # 创建内容面板
        content_frame = ttk.Frame(self.main_frame)
        content_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        content_frame.columnconfigure(0, weight=1)
        content_frame.columnconfigure(1, weight=1)
        
        # 左侧面板 - RFID和状态
        self._create_left_panel(content_frame)
        
        # 右侧面板 - 快捷操作
        self._create_right_panel(content_frame)
    
    def _create_left_panel(self, parent):
        """创建左侧面板"""
        left_frame = ttk.LabelFrame(parent, text="RFID卡管理", padding="10")
        left_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S), padx=5, pady=5)
        
        # 卡片可视化
        card_frame = ttk.Frame(left_frame)
        card_frame.pack(fill=tk.X, pady=10)
        
        self.card_canvas = tk.Canvas(card_frame, width=150, height=100, bg="#f0f0f0", highlightthickness=1)
        self.card_canvas.pack()
        
        # 先创建状态变量，再绘制卡片
        self.card_status_var = tk.StringVar(value="无卡")
        self._draw_card()
        
        ttk.Label(card_frame, textvariable=self.card_status_var, font=("Arial", 10)).pack(pady=5)
        
        # 操作按钮
        btn_frame = ttk.Frame(left_frame)
        btn_frame.pack(fill=tk.X, pady=10)
        
        ttk.Button(btn_frame, text="开卡", command=self._issue_card, width=12).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="验卡", command=self._verify_card, width=12).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="模拟刷卡", command=self._swipe_card, width=12).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="移除卡", command=self._remove_card, width=12).pack(side=tk.LEFT, padx=5)
        
        # 目标房间设置
        room_frame = ttk.Frame(left_frame)
        room_frame.pack(fill=tk.X, pady=10)
        
        ttk.Label(room_frame, text="目标房间:").pack(side=tk.LEFT)
        ttk.Entry(room_frame, textvariable=self.target_room_var, width=10).pack(side=tk.LEFT, padx=5)
        
        # LED状态指示
        led_frame = ttk.LabelFrame(left_frame, text="状态指示灯", padding="10")
        led_frame.pack(fill=tk.X, pady=10)
        
        self.led_canvas = tk.Canvas(led_frame, width=50, height=50, bg="white", highlightthickness=1)
        self.led_canvas.pack()
        self._update_led()
        
        ttk.Label(led_frame, text="蓝=在线 绿=成功 红=错误").pack(pady=5)
    
    def _create_right_panel(self, parent):
        """创建右侧面板"""
        right_frame = ttk.LabelFrame(parent, text="快捷操作", padding="10")
        right_frame.grid(row=0, column=1, sticky=(tk.W, tk.E, tk.N, tk.S), padx=5, pady=5)
        
        # 呼叫控制
        call_frame = ttk.LabelFrame(right_frame, text="语音呼叫", padding="10")
        call_frame.pack(fill=tk.X, pady=10)
        
        ttk.Button(call_frame, text="📢 广播呼叫", command=self._broadcast_call, width=20).pack(pady=5)
        ttk.Button(call_frame, text="🔇 消音/挂断", command=self._hangup_call, width=20).pack(pady=5)
        
        # 目标房间显示
        ttk.Label(call_frame, text="当前目标房间:").pack(pady=(10, 0))
        ttk.Label(call_frame, textvariable=self.target_room_var, font=("Arial", 14, "bold")).pack()
        
        # 蜂鸣器模拟
        buzzer_frame = ttk.LabelFrame(right_frame, text="蜂鸣器", padding="10")
        buzzer_frame.pack(fill=tk.X, pady=10)
        
        ttk.Button(buzzer_frame, text="短鸣(成功)", command=lambda: self._beep(1), width=15).pack(pady=2)
        ttk.Button(buzzer_frame, text="双鸣(错误)", command=lambda: self._beep(2), width=15).pack(pady=2)
    
    def _draw_card(self):
        """绘制卡片"""
        self.card_canvas.delete("all")
        if self.rfid.has_card:
            # 有卡 - 绘制卡片
            self.card_canvas.create_rectangle(20, 20, 130, 80, fill="#FFD700", outline="#B8860B", width=2)
            self.card_canvas.create_text(75, 50, text="房卡", font=("Arial", 12, "bold"))
            if self.rfid.card_data:
                room_id = self.rfid.card_data.get("room_id", "")
                self.card_canvas.create_text(75, 70, text=f"房间{room_id}", font=("Arial", 9))
            self.card_status_var.set(f"有卡 - 房间{self.rfid.card_data.get('room_id', '')}" if self.rfid.card_data else "有卡")
        else:
            # 无卡
            self.card_canvas.create_rectangle(20, 20, 130, 80, fill="#f0f0f0", outline="#cccccc", dash=(4, 2))
            self.card_canvas.create_text(75, 50, text="无卡", font=("Arial", 10), fill="#999")
            self.card_status_var.set("无卡")
    
    def _update_led(self, r=0, g=0, b=255):
        """更新LED颜色"""
        color = f"#{r:02x}{g:02x}{b:02x}"
        self.led_canvas.delete("all")
        self.led_canvas.create_oval(10, 10, 40, 40, fill=color, outline="")
    
    def _beep(self, count=1):
        """蜂鸣器提示"""
        # 视觉反馈
        original_color = self.led_color
        self._update_led(255, 255, 0)  # 黄色闪烁
        self.root.after(100, lambda: self._update_led(*original_color))
        
        if count > 1:
            for i in range(1, count):
                self.root.after(i * 200, lambda: self._update_led(255, 255, 0))
                self.root.after(i * 200 + 100, lambda: self._update_led(*original_color))
    
    def _issue_card(self):
        """开卡操作"""
        room_id = self.target_room_var.get()
        success, msg = self.rfid.issue_card(room_id)
        self._draw_card()
        
        if success:
            self._update_led(0, 255, 0)  # 绿色
            self._beep(1)
            self.logger.info(msg)
        else:
            self._update_led(255, 0, 0)  # 红色
            self._beep(2)
        
        # 3秒后恢复蓝色
        self.root.after(3000, lambda: self._update_led(0, 0, 255))
    
    def _verify_card(self):
        """验卡操作"""
        success, msg = self.rfid.verify_card()
        self._draw_card()
        
        if success:
            self._update_led(0, 255, 0)
            self._beep(1)
            self.logger.info(msg)
        else:
            self._update_led(255, 0, 0)
            self._beep(2)
        
        self.root.after(3000, lambda: self._update_led(0, 0, 255))
    
    def _swipe_card(self):
        """刷卡操作 - 联动客房门锁"""
        success, result = self.rfid.swipe_card()
        
        if success:
            room_id = result
            self.last_card_room = room_id
            self._update_led(0, 255, 0)
            self._beep(1)
            self.logger.info(f"刷卡通过，房间{room_id}，正在发送开锁指令...")
            
            # 发送卡片UID事件（模拟RC522检测到UID）
            if self.mqtt_client and self.connected:
                import random
                uid_hex = "".join([f"{random.randint(0, 255):02X}" for _ in range(4)])
                self.mqtt_client.publish_card_uid_event(uid_hex)
                self.logger.info(f"已上报卡片UID: {uid_hex}")
            
            # 发送开锁指令到客房
            if self.mqtt_client and self.connected:
                self.mqtt_client.publish_to_room(room_id, "door_unlock")
                self.logger.info(f"已发送开锁指令到房间{room_id}")
        else:
            self._update_led(255, 0, 0)
            self._beep(2)
            self.logger.warning(result)
        
        self.root.after(3000, lambda: self._update_led(0, 0, 255))
    
    def _remove_card(self):
        """移除卡片"""
        self.rfid.remove_card()
        self._draw_card()
        self.logger.info("卡片已移除")
    
    def _broadcast_call(self):
        """广播呼叫"""
        room_id = self.target_room_var.get()
        if self.mqtt_client and self.connected:
            extra = {
                "call_id": f"call_{self.device_id}_{int(datetime.now().timestamp())}",
                "caller_id": self.device_id,
                "broadcast_text": f"前台呼叫房间{room_id}，请接听",
                "broadcast_audio_url": ""  # 后端可以填充实际的TTS音频URL
            }
            self.mqtt_client.publish_to_room(room_id, CMD_INCOMING_CALL, extra)
            self.logger.info(f"已向房间{room_id}发送广播呼叫")
            self._beep(1)
        else:
            messagebox.showwarning("警告", "MQTT未连接")
    
    def _hangup_call(self):
        """消音/挂断"""
        room_id = self.target_room_var.get()
        if self.mqtt_client and self.connected:
            extra = {
                "call_id": f"call_{self.device_id}_latest"
            }
            self.mqtt_client.publish_to_room(room_id, CMD_HANGUP_CALL, extra)
            self.logger.info(f"已向房间{room_id}发送挂断指令")
            self._beep(1)
        else:
            messagebox.showwarning("警告", "MQTT未连接")
    
    def _register_command_handlers(self):
        """注册命令处理器"""
        self.mqtt_client.register_command_handler(CMD_ISSUE_CARD, self._handle_issue_card)
        self.mqtt_client.register_command_handler(CMD_VERIFY_CARD, self._handle_verify_card)
        self.mqtt_client.register_command_handler(CMD_SWIPE_CARD, self._handle_swipe_card)
    
    def _handle_issue_card(self, data):
        """处理开卡命令"""
        room_id = data.get('command_value', {}).get('room_id', self.target_room_var.get())
        success, msg = self.rfid.issue_card(room_id)
        self._draw_card()
        self._beep(1 if success else 2)
        return success
    
    def _handle_verify_card(self, data):
        """处理验卡命令"""
        success, msg = self.rfid.verify_card()
        self._draw_card()
        self._beep(1 if success else 2)
        return success
    
    def _handle_swipe_card(self, data):
        """处理刷卡命令"""
        success, result = self.rfid.swipe_card()
        if success:
            self.last_card_room = result
            if self.mqtt_client and self.connected:
                self.mqtt_client.publish_to_room(result, "door_unlock")
        self._draw_card()
        self._beep(1 if success else 2)
        return success
    
    def _on_connected(self):
        """连接成功"""
        self._update_led(0, 0, 255)  # 蓝色
        self._beep(2)
    
    def _on_disconnected(self):
        """断开连接"""
        self._update_led(255, 0, 0)  # 红色
    
    def _show_config_dialog(self):
        """显示配置对话框"""
        dialog = tk.Toplevel(self.root)
        dialog.title("设备配置")
        dialog.geometry("300x200")
        dialog.transient(self.root)
        dialog.grab_set()
        
        ttk.Label(dialog, text="前台编号:").pack(pady=(20, 5))
        id_entry = ttk.Entry(dialog, textvariable=self.front_id_var, width=10)
        id_entry.pack()
        
        ttk.Label(dialog, text="目标房间:").pack(pady=(10, 5))
        room_entry = ttk.Entry(dialog, textvariable=self.target_room_var, width=10)
        room_entry.pack()
        
        def save_config():
            # 更新设备ID
            new_id = f"front_desk_{self.front_id_var.get()}"
            if new_id != self.device_id:
                self.device_id = new_id
                self.device_id_label.config(text=f"设备ID: {self.device_id}")
                self.root.title(f"智慧酒店 - 前台管理端仿真器 ({self.device_id})")
                # 如果已连接，需要重新连接
                if self.connected:
                    messagebox.showinfo("提示", "设备ID已更改，请重新连接MQTT")
                    self.disconnect()
            dialog.destroy()
        
        ttk.Button(dialog, text="保存", command=save_config).pack(pady=20)


def main():
    """主函数"""
    root = tk.Tk()
    app = FrontDeskEmulator(root)
    app.run()


if __name__ == "__main__":
    main()
