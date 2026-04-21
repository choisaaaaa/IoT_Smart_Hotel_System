"""
配置管理模块
"""
import json
import os

TOPIC_DEVICE_STATUS_PREFIX = "hotel/device/status"
TOPIC_DEVICE_DATA_PREFIX = "hotel/device/data"
TOPIC_DEVICE_COMMAND_PREFIX = "hotel/device/command"
TOPIC_DEVICE_COMMAND_RESULT = "hotel/device/command/result"
TOPIC_SECURITY_EVENT = "hotel/security/event"
TOPIC_AI_REQUEST = "hotel/ai/request/room/{}"
TOPIC_AI_RESPONSE = "hotel/ai/response/room/{}"
TOPIC_ROOM_SCENE = "hotel/room/{}/scene"
TOPIC_ROOM_SCENE_RESULT = "hotel/room/{}/scene/result"

CMD_LIGHT = "light"
CMD_AIR = "air"
CMD_CURTAIN = "curtain"
CMD_DOOR = "door"
CMD_SCENE = "scene"
CMD_INCOMING_CALL = "incoming_call"
CMD_HANGUP_CALL = "hangup_call"
CMD_ISSUE_CARD = "issue_card"
CMD_VERIFY_CARD = "verify_card"
CMD_SWIPE_CARD = "swipe_card"
CMD_BROADCAST_START = "broadcast_start"
CMD_BROADCAST_STOP = "broadcast_stop"
CMD_FLOOR_RESET = "floor_reset"

CMD_VAL_ON = "on"
CMD_VAL_OFF = "off"
CMD_VAL_UNLOCK = "unlock"
CMD_VAL_LOCK = "lock"
CMD_VAL_OPEN = "open"
CMD_VAL_CLOSE = "close"
CMD_VAL_STOP = "stop"
CMD_VAL_WELCOME = "welcome"
CMD_VAL_SLEEP = "sleep"
CMD_VAL_LEAVE = "leave"
CMD_VAL_READING = "reading"

SENSOR_TEMPERATURE = "temperature"
SENSOR_HUMIDITY = "humidity"
SENSOR_LIGHT = "light"
SENSOR_MOTION = "motion"
SENSOR_DOOR = "door"
SENSOR_SMOKE = "smoke"

DEFAULT_CONFIG = {
    "mqtt": {
        "broker": "8.134.166.69",
        "port": 1883,
        "username": "root",
        "password": "IotHotel2026",
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
    def __init__(self, config_file=None):
        self.config_file = config_file or self._get_default_config_path()
        self.config = self._load_config()

    def _get_default_config_path(self):
        return os.path.join(os.path.dirname(__file__), "..", "config.json")

    def _load_config(self):
        if os.path.exists(self.config_file):
            try:
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except Exception as e:
                print(f"加载配置文件失败: {e}, 使用默认配置")
        return DEFAULT_CONFIG.copy()

    def save_config(self):
        try:
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json.dump(self.config, f, indent=2, ensure_ascii=False)
            return True
        except Exception as e:
            print(f"保存配置文件失败: {e}")
            return False

    def get(self, key, default=None):
        keys = key.split('.')
        value = self.config
        for k in keys:
            if isinstance(value, dict) and k in value:
                value = value[k]
            else:
                return default
        return value

    def set(self, key, value):
        keys = key.split('.')
        config = self.config
        for k in keys[:-1]:
            if k not in config:
                config[k] = {}
            config = config[k]
        config[keys[-1]] = value
        self.save_config()


_global_config = None


def get_config(config_file=None):
    global _global_config
    if _global_config is None:
        _global_config = Config(config_file)
    return _global_config
