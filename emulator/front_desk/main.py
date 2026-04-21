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
        
        # 业务状态
        self.rfid = RFIDCardSimulator()
        self.target_room_var = tk.StringVar(value="301")
        self.last_card_room = ""
        self.front_id_var = tk.StringVar(value="01")
        self.led_color = (0, 0, 255) # 默认蓝色
        
        super().__init__(
            root=root,
            title=f"智慧酒店 - 前台管理端仿真器 ({self.device_id})",
            device_id=self.device_id,
            device_type="front_desk",
            width=950,
            height=800
        )

    def _init_biz_ui(self):
        """初始化前台特有业务界面"""
        # 1. RFID 房卡管理卡片
        self._create_card(self.biz_frame, "RFID 智能房卡读写器").pack(fill=tk.X, pady=(0, 20))
        rfid_body = self.last_card_body
        
        # 卡片可视化区域
        viz_container = tk.Frame(rfid_body, bg="white")
        viz_container.pack(fill=tk.X, pady=10)
        
        # 卡片图形
        self.card_canvas = tk.Canvas(viz_container, width=240, height=140, bg="white", highlightthickness=0)
        self.card_canvas.pack(side=tk.LEFT, padx=20)
        
        # 卡片状态信息
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

        # RFID 操作按钮
        btn_grid = tk.Frame(rfid_body, bg="white")
        btn_grid.pack(fill=tk.X, pady=15)
        
        btn_style = {"width": 12, "relief": tk.FLAT, "font": ("Arial", 10, "bold"), "pady": 10}
        
        tk.Button(btn_grid, text="🆕 开卡写入", bg=self.colors['primary'], fg="white", command=self._issue_card, **btn_style).pack(side=tk.LEFT, expand=True, padx=5)
        tk.Button(btn_grid, text="🔍 验卡读取", bg=self.colors['success'], fg="white", command=self._verify_card, **btn_style).pack(side=tk.LEFT, expand=True, padx=5)
        tk.Button(btn_grid, text="📟 模拟刷卡", bg=self.colors['warning'], fg="white", command=self._swipe_card, **btn_style).pack(side=tk.LEFT, expand=True, padx=5)
        tk.Button(btn_grid, text="🗑️ 移除卡片", bg="#595959", fg="white", command=self._remove_card, **btn_style).pack(side=tk.LEFT, expand=True, padx=5)

        # 2. 快捷语音与控制
        self._create_card(self.biz_frame, "客房语音与远程控制").pack(fill=tk.X, pady=(0, 20))
        ctrl_body = self.last_card_body
        
        # 语音呼叫
        call_f = tk.Frame(ctrl_body, bg="white")
        call_f.pack(fill=tk.X, pady=10)
        tk.Label(call_f, text="📢 应急广播呼叫:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        tk.Button(call_f, text="发送语音提醒", bg=self.colors['danger'], fg="white", command=self._broadcast_call, **btn_style).pack(side=tk.RIGHT)
        
        # 挂断
        hangup_f = tk.Frame(ctrl_body, bg="white")
        hangup_f.pack(fill=tk.X, pady=10)
        tk.Label(hangup_f, text="🔇 停止呼叫/消音:", font=("Arial", 10), bg="white").pack(side=tk.LEFT)
        tk.Button(hangup_f, text="强制挂断", bg="#595959", fg="white", command=self._hangup_call, **btn_style).pack(side=tk.RIGHT)

        # 3. 硬件外设模拟
        self._create_card(self.biz_frame, "硬件交互外设模拟").pack(fill=tk.BOTH, expand=True)
        hw_body = self.last_card_body
        
        # 指示灯和蜂鸣器按钮
        led_container = tk.Frame(hw_body, bg="white")
        led_container.pack(side=tk.LEFT, fill=tk.Y, padx=10)
        
        self.led_canvas = tk.Canvas(led_container, width=60, height=60, bg="white", highlightthickness=0)
        self.led_canvas.pack(pady=5)
        self._update_led()
        tk.Label(led_container, text="状态指示灯", font=("Arial", 9), bg="white", fg=self.colors['text_secondary']).pack()

        # 蜂鸣器操作
        buzzer_container = tk.Frame(hw_body, bg="white")
        buzzer_container.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True, padx=20)
        
        tk.Label(buzzer_container, text="蜂鸣器手动测试:", font=("Arial", 10), bg="white").pack(anchor=tk.W, pady=5)
        tk.Button(buzzer_container, text="🔊 短鸣(操作成功)", bg=self.colors['success'], fg="white", 
                  command=lambda: self._beep(1), **btn_style).pack(fill=tk.X, pady=5)
        tk.Button(buzzer_container, text="🔇 双鸣(异常提醒)", bg=self.colors['danger'], fg="white", 
                  command=lambda: self._beep(2), **btn_style).pack(fill=tk.X, pady=5)

    def _connect(self):
        """覆盖基类连接方法，增加命令注册"""
        super()._connect()
        if self.connected:
            self._register_command_handlers()
            self._on_connected()

    def _disconnect(self):
        """覆盖基类断开连接方法"""
        super()._disconnect()
        self._on_disconnected()
    
    def _draw_card(self):
        """绘制卡片可视化界面"""
        self.card_canvas.delete("all")
        # 居中坐标
        cx, cy = 120, 70
        if self.rfid.has_card:
            # 有卡 - 绘制金色房卡
            self.card_canvas.create_rectangle(cx-100, cy-60, cx+100, cy+60, 
                                             fill="#FFD700", outline="#B8860B", width=3, round=10)
            # 装饰性芯片
            self.card_canvas.create_rectangle(cx-80, cy-20, cx-50, cy+10, fill="#C0C0C0", outline="#A0A0A0")
            
            self.card_canvas.create_text(cx+10, cy-10, text="HOTEL SMART CARD", font=("Arial", 10, "bold"), fill="#8B4513")
            if self.rfid.card_data:
                room_id = self.rfid.card_data.get("room_id", "")
                self.card_canvas.create_text(cx+10, cy+20, text=f"ROOM: {room_id}", font=("Consolas", 14, "bold"), fill="#333")
            self.card_status_var.set(f"已插入: 房间 {self.rfid.card_data.get('room_id', '???')}" if self.rfid.card_data else "空白卡片")
        else:
            # 无卡 - 虚线占位
            self.card_canvas.create_rectangle(cx-100, cy-60, cx+100, cy+60, 
                                             fill="#f9f9f9", outline="#dddddd", dash=(5, 5), width=2)
            self.card_canvas.create_text(cx, cy, text="请插入房卡", font=("Microsoft YaHei", 10), fill="#999")
            self.card_status_var.set("读卡器空闲")
    
    def _update_led(self, r=0, g=0, b=255):
        """更新LED颜色并保存状态"""
        self.led_color = (r, g, b)
        color = f"#{r:02x}{g:02x}{b:02x}"
        self.led_canvas.delete("all")
        self.led_canvas.create_oval(10, 10, 50, 50, fill=color, outline="")
    
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
