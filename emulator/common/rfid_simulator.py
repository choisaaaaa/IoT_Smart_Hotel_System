"""
RFID 卡片模拟器 - 共用组件
"""
import random
import json
from datetime import datetime

class RFIDCardSimulator:
    def __init__(self):
        self.card_data = None
        self.has_card = False
        self.uid = None

    def place_card(self, custom_uid=None):
        self.has_card = True
        # 关键修复：每次放置卡片时必须先清空旧卡残留数据，等待后续写入或后端同步
        self.card_data = None
        
        if custom_uid and custom_uid.strip():
            self.uid = custom_uid.strip().upper()
        else:
            # 随机生成一个 8 位十六进制 UID
            self.uid = ''.join(random.choices('0123456789ABCDEF', k=8))
        return True, f"卡片已放置 [UID: {self.uid}]"

    def issue_card(self, room_id, card_type='guest', holder_name=''):
        if not self.has_card:
            return False, "写入失败: 未检测到物理卡片"
        self.card_data = {
            "uid": self.uid,
            "room_id": room_id, 
            "card_type": card_type,
            "holder_name": holder_name,
            "issued_at": datetime.now().isoformat()
        }
        type_str = "房间卡" if card_type == 'guest' else "特权卡"
        return True, f"写卡成功: UID {self.uid} -> {type_str} ({room_id or card_type})"

    def verify_card(self):
        if not self.has_card:
            return False, "读取失败: 感应区无卡片"
        if not self.card_data:
            return True, f"读取成功: 空白卡 [UID: {self.uid}]"
        room_id = self.card_data.get("room_id", "unknown")
        return True, f"读取成功: UID {self.uid} | 房号 {room_id}"

    def swipe_card(self):
        if not self.has_card:
            return False, "刷卡失败: 请先放置卡片"
        # 即使没有写入业务数据 (card_data)，物理 UID 依然存在，允许刷卡
        return True, {
            "uid": self.uid,
            "data": self.card_data
        }

    def remove_card(self):
        self.has_card = False
        old_uid = self.uid
        self.uid = None
        # 关键修复：收回卡片时彻底清空数据状态
        self.card_data = None
        return True, f"卡片 {old_uid} 已取走"

    def reset_card(self):
        if not self.has_card:
            return False, "重置失败: 无物理卡片"
        self.card_data = None
        return True, "卡片数据已擦除 (格式化)"
