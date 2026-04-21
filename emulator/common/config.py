"""
配置管理模块
"""
import json
import os

# MQTT主题常量
TOPIC_DEVICE_STATUS_PREFIX = "hotel/device/status"
TOPIC_DEVICE_DATA_PREFIX = "hotel/device/data"
TOPIC_DEVICE_COMMAND_PREFIX = "hotel/device/command"
TOPIC_DEVICE_COMMAND_RESULT = "hotel/device/command/result"
TOPIC_SECURITY_EVENT = "hotel/security/event"
TOPIC_AI_REQUEST = "hotel/ai/request/room/{}"
TOPIC_AI_RESPONSE = "hotel/ai/response/room/{}"

# 命令类型常量
CMD_LIGHT_ON = "light_on"
CMD_LIGHT_OFF = "light_off"
CMD_AIR_ON = "air_on"
CMD_AIR_OFF = "air_off"
CMD_CURTAIN_OPEN = "curtain_open"
CMD_CURTAIN_CLOSE = "curtain_close"
CMD_DOOR_UNLOCK = "door_unlock"
CMD_DOOR_LOCK = "door_lock"
CMD_INCOMING_CALL = "incoming_call"
CMD_HANGUP_CALL = "hangup_call"
CMD_SCENE_WELCOME = "scene_welcome"
CMD_SCENE_READING = "scene_reading"
CMD_SCENE_NIGHT = "scene_night"
CMD_SCENE_SLEEP = "scene_sleep"
CMD_SCENE_NEXT = "scene_next"
CMD_ISSUE_CARD = "issue_card"
CMD_VERIFY_CARD = "verify_card"
CMD_SWIPE_CARD = "swipe_card"
CMD_BROADCAST_START = "broadcast_start"
CMD_BROADCAST_STOP = "broadcast_stop"
CMD_FLOOR_RESET = "floor_reset"

# 默认配置
DEFAULT_CONFIG = {
    "mqtt": {
        "broker": "mqtt://172.20.10.3:1883",
        "port": 1883,
        "username": "",
        "password": "",
        "keepalive": 60
    },
    "front_desk": {
        "device_id": "front_desk_01",
        "target_room": "301"
    },
    "floor": {
        "device_id": "floor_03"
    },
    "room": {
        "device_id": "room_301",
        "room_id": "301"
    }
}


class Config:
    """配置管理类"""
    
    def __init__(self, config_file=None):
        self.config_file = config_file or self._get_default_config_path()
        self.config = self._load_config()
    
    def _get_default_config_path(self):
        """获取默认配置文件路径"""
        return os.path.join(os.path.dirname(__file__), "..", "config.json")
    
    def _load_config(self):
        """加载配置文件"""
        if os.path.exists(self.config_file):
            try:
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except Exception as e:
                print(f"加载配置文件失败: {e}, 使用默认配置")
        return DEFAULT_CONFIG.copy()
    
    def save_config(self):
        """保存配置到文件"""
        try:
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json.dump(self.config, f, indent=2, ensure_ascii=False)
            return True
        except Exception as e:
            print(f"保存配置文件失败: {e}")
            return False
    
    def get(self, key, default=None):
        """获取配置项"""
        keys = key.split('.')
        value = self.config
        for k in keys:
            if isinstance(value, dict) and k in value:
                value = value[k]
            else:
                return default
        return value
    
    def set(self, key, value):
        """设置配置项"""
        keys = key.split('.')
        config = self.config
        for k in keys[:-1]:
            if k not in config:
                config[k] = {}
            config = config[k]
        config[keys[-1]] = value
        self.save_config()


# 全局配置实例
_global_config = None


def get_config(config_file=None):
    """获取全局配置实例"""
    global _global_config
    if _global_config is None:
        _global_config = Config(config_file)
    return _global_config
