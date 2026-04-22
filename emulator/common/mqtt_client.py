"""
MQTT客户端封装模块
"""
import json
import time
import threading
import hashlib
import hmac as hmac_mod
import paho.mqtt.client as mqtt
from datetime import datetime
from .logger import Logger, get_log_buffer
from .config import (
    TOPIC_DEVICE_STATUS_PREFIX,
    TOPIC_DEVICE_DATA_PREFIX,
    TOPIC_DEVICE_COMMAND_PREFIX,
    TOPIC_DEVICE_COMMAND_RESULT,
    TOPIC_SECURITY_EVENT,
    TOPIC_AI_RESPONSE,
    CMD_LIGHT, CMD_AIR, CMD_CURTAIN, CMD_DOOR, CMD_SCENE,
    CMD_INCOMING_CALL, CMD_HANGUP_CALL,
    CMD_VAL_ON, CMD_VAL_OFF, CMD_VAL_UNLOCK, CMD_VAL_LOCK,
    CMD_VAL_OPEN, CMD_VAL_CLOSE, CMD_VAL_STOP,
    CMD_VAL_WELCOME, CMD_VAL_SLEEP, CMD_VAL_LEAVE, CMD_VAL_READING
)


class MQTTClient:
    def __init__(self, device_id, device_type, broker="8.134.166.69", port=1883, device_key="", username="root", password="IotHotel2026", hotel_id=None):
        self.device_id = device_id
        self.device_type = device_type
        self.broker = broker
        self.port = port
        self.device_key = device_key
        self.username = username
        self.password = password
        self.hotel_id = hotel_id

        self.client = mqtt.Client(client_id=device_id)
        if self.username:
            self.client.username_pw_set(self.username, self.password)

        self.client.on_connect = self._on_connect
        self.client.on_disconnect = self._on_disconnect
        self.client.on_message = self._on_message

        self.connected = False
        self.subscriptions = {}
        self.command_handlers = {}
        self.logger = Logger(f"MQTT-{device_id}")
        self.log_buffer = get_log_buffer()

        self._stop_heartbeat = threading.Event()
        self._heartbeat_thread = None

        self.msg_sent = 0
        self.msg_received = 0
        self.reconnect_count = 0

        self._stop_health = threading.Event()
        self._health_thread = None

        self.audit_status = "approved" if device_key else "pending"
        self.on_message = None
        self.on_ai_response = None

    def _on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            self.connected = True
            self.logger.info(f"MQTT连接成功: {self.broker}:{self.port}")
            self.log_buffer.log("INFO", f"MQTT连接成功")

            for topic in self.subscriptions:
                self.client.subscribe(topic)
                self.logger.info(f"重新订阅: {topic}")

            self._start_heartbeat()
            self._start_health_report()
            self.publish_online_status()
            self.publish_health_report()
        else:
            self.logger.error(f"MQTT连接失败，返回码: {rc}")
            self.log_buffer.log("ERROR", f"MQTT连接失败，返回码: {rc}")

    def _on_disconnect(self, client, userdata, rc):
        self.connected = False
        self._stop_heartbeat.set()
        self._stop_health.set()
        if rc != 0:
            self.reconnect_count += 1
            self.logger.warning(f"MQTT意外断开，返回码: {rc}")
            self.log_buffer.log("WARNING", f"MQTT意外断开")

    def _on_message(self, client, userdata, msg):
        self.msg_received += 1
        topic = msg.topic

        # 处理二进制音频流
        if "hotel/call/audio/" in topic:
            if self.on_message:
                try:
                    self.on_message(topic, msg.payload)
                except Exception as e:
                    self.logger.error(f"音频流回调处理失败: {e}")
            return

        try:
            payload = msg.payload.decode('utf-8')
        except UnicodeDecodeError:
            self.logger.warning(f"无法解码主题 [{topic}] 的消息 payload")
            return

        self.logger.info(f"接收 [{topic}]: {payload}")
        self.log_buffer.log("RX", f"[{topic}] {payload}")

        callback = self.subscriptions.get(topic)
        if callback and callable(callback):
            try:
                callback(topic, payload)
            except Exception as e:
                self.logger.error(f"处理消息失败: {e}")

        if TOPIC_DEVICE_COMMAND_PREFIX in topic:
            self._handle_command(payload)

        if "hotel/ai/response/room/" in topic:
            try:
                data = json.loads(payload)
                if self.on_ai_response:
                    self.on_ai_response(data)
            except Exception as e:
                self.logger.error(f"处理 AI 响应失败: {e}")

        if self.on_message:
            try:
                self.on_message(topic, payload)
            except Exception as e:
                self.logger.error(f"消息回调处理失败: {e}")

    def publish_binary(self, topic, payload):
        if not self.connected:
            return False
        result = self.client.publish(topic, payload, qos=0)
        return result.rc == mqtt.MQTT_ERR_SUCCESS

    def _handle_command(self, payload):
        try:
            data = json.loads(payload)
            cmd_type = data.get('command_type')
            cmd_value = data.get('command_value', '')
            cmd_id = data.get('command_id', 0)
            device_id_in_cmd = data.get('device_id', '')

            if device_id_in_cmd and device_id_in_cmd != self.device_id:
                self.logger.warning(f"忽略非本机指令: target={device_id_in_cmd} self={self.device_id}")
                return

            composite_key = f"{cmd_type}:{cmd_value}" if cmd_value else cmd_type

            if composite_key in self.command_handlers:
                handler = self.command_handlers[composite_key]
                if handler and callable(handler):
                    result = handler(data)
                    self.publish_command_result(cmd_id, cmd_type, result)
                else:
                    self.logger.warning(f"命令处理器不可用: {composite_key}")
                    self.publish_command_result(cmd_id, cmd_type, False, f"处理器不可用: {composite_key}")
            elif cmd_type in self.command_handlers:
                handler = self.command_handlers[cmd_type]
                if handler and callable(handler):
                    result = handler(data)
                    self.publish_command_result(cmd_id, cmd_type, result)
                else:
                    self.logger.warning(f"命令处理器不可用: {cmd_type}")
                    self.publish_command_result(cmd_id, cmd_type, False, f"处理器不可用: {cmd_type}")
            else:
                self.logger.warning(f"未知命令: {cmd_type}={cmd_value}")
                self.publish_command_result(cmd_id, cmd_type, False, f"未知命令: {cmd_type}={cmd_value}")
        except json.JSONDecodeError:
            self.logger.error("命令JSON解析失败")
        except Exception as e:
            self.logger.error(f"处理命令失败: {e}")

    def _start_heartbeat(self):
        self._stop_heartbeat.clear()
        self._heartbeat_thread = threading.Thread(target=self._heartbeat_loop, daemon=True)
        self._heartbeat_thread.start()

    def _heartbeat_loop(self):
        while not self._stop_heartbeat.is_set():
            if self.connected:
                self.publish_heartbeat()
            for _ in range(60):
                if self._stop_heartbeat.is_set():
                    break
                time.sleep(1)

    def connect(self):
        try:
            self.logger.info(f"正在连接MQTT: {self.broker}:{self.port}")
            self.log_buffer.log("INFO", f"正在连接MQTT...")
            self.client.connect(self.broker, self.port, keepalive=60)
            self.client.loop_start()
            return True
        except Exception as e:
            self.logger.error(f"连接MQTT失败: {e}")
            self.log_buffer.log("ERROR", f"连接MQTT失败: {e}")
            return False

    def disconnect(self):
        self._stop_heartbeat.set()
        self._stop_health.set()
        self.client.loop_stop()
        self.client.disconnect()
        self.connected = False
        self.logger.info("MQTT已断开")
        self.log_buffer.log("INFO", "MQTT已断开")

    def subscribe(self, topic, callback=None):
        self.subscriptions[topic] = callback
        if self.connected:
            self.client.subscribe(topic)
            self.logger.info(f"订阅: {topic}")

    def _generate_signature(self, payload_dict):
        if not self.device_key:
            return None

        if 'timestamp' not in payload_dict:
            payload_dict['timestamp'] = datetime.now().isoformat()

        sign_payload = {k: v for k, v in payload_dict.items() if k != 'signature'}
        sign_str = json.dumps(sign_payload, ensure_ascii=False, separators=(',', ':'))

        signature = hmac_mod.new(
            self.device_key.encode('utf-8'),
            sign_str.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()

        return signature

    def publish(self, topic, payload):
        if not self.connected:
            self.logger.warning("MQTT未连接，无法发布消息")
            return False

        try:
            if isinstance(payload, dict):
                # 只要有密钥就进行签名，防止本地审核状态滞后导致的消息被后端拦截
                if self.device_key:
                    payload['timestamp'] = datetime.now().isoformat()
                    payload['signature'] = self._generate_signature(payload.copy())

                payload = json.dumps(payload, ensure_ascii=False)

            result = self.client.publish(topic, payload, qos=1)
            if result.rc == mqtt.MQTT_ERR_SUCCESS:
                self.msg_sent += 1
                self.logger.debug(f"发布 [{topic}]: {payload}")
                self.log_buffer.log("TX", f"[{topic}] {payload}")
                return True
            else:
                self.logger.error(f"发布失败: {result.rc}")
                return False
        except Exception as e:
            self.logger.error(f"发布消息失败: {e}")
            return False

    def register_command_handler(self, cmd_type, handler):
        self.command_handlers[cmd_type] = handler

    def publish_online_status(self):
        topic = TOPIC_DEVICE_STATUS_PREFIX
        payload = {
            "device_id": self.device_id,
            "device_type": self.device_type,
            "status": "online",
            "hotel_id": self.hotel_id
        }
        self.publish(topic, payload)

    def publish_heartbeat(self):
        topic = f"{TOPIC_DEVICE_STATUS_PREFIX}/{self.device_type}/{self.device_id}"
        payload = {
            "device_id": self.device_id,
            "device_type": self.device_type,
            "status": "online",
            "hotel_id": self.hotel_id,
            "battery_level": 100,
            "signal_strength": -50,
            "uptime": int(time.time()),
            "memory_usage": 45,
            "timestamp": datetime.now().isoformat()
        }
        return self.publish(topic, payload)

    def publish_sensor_data(self, sensor_type, value, unit=""):
        topic = f"{TOPIC_DEVICE_DATA_PREFIX}/{sensor_type}"
        payload = {
            "device_id": self.device_id,
            "sensor_type": sensor_type,
            "value": value,
            "unit": unit,
            "timestamp": datetime.now().isoformat()
        }
        return self.publish(topic, payload)

    def publish_command_result(self, cmd_id, cmd_type, success, result_msg=""):
        payload = {
            "device_id": self.device_id,
            "command_id": cmd_id,
            "command_type": cmd_type,
            "status": "success" if success else "failed",
            "result": result_msg or ("执行成功" if success else "执行失败"),
            "timestamp": datetime.now().isoformat()
        }
        return self.publish(TOPIC_DEVICE_COMMAND_RESULT, payload)

    def publish_security_event(self, event_type, level="info", event_data=None):
        payload = {
            "device_id": self.device_id,
            "event_type": event_type,
            "data": event_data or {},
            "level": level,
            "timestamp": datetime.now().isoformat()
        }
        return self.publish(TOPIC_SECURITY_EVENT, payload)

    def publish_to_room(self, room_id, cmd_type, cmd_value=None, extra_data=None):
        topic = f"{TOPIC_DEVICE_COMMAND_PREFIX}/room/room_{room_id}"
        payload = {
            "command_id": int(time.time() * 1000) % 100000,
            "device_id": f"room_{room_id}",
            "command_type": cmd_type,
            "created_by": self.device_id,
            "timestamp": datetime.now().isoformat()
        }
        if cmd_value:
            payload["command_value"] = cmd_value
        if extra_data:
            payload.update(extra_data)
        return self.publish(topic, payload)

    def _start_health_report(self):
        self._stop_health.clear()
        self._health_thread = threading.Thread(target=self._health_loop, daemon=True)
        self._health_thread.start()

    def _health_loop(self):
        while not self._stop_health.is_set():
            if self.connected:
                self.publish_health_report()
            for _ in range(600):
                if self._stop_health.is_set():
                    break
                time.sleep(1)

    def publish_health_report(self):
        topic = f"hotel/health/{self.device_type}/{self.device_id}"
        payload = {
            "device_id": self.device_id,
            "device_type": self.device_type,
            "firmware_version": "v1.2.0-smart",
            "uptime_sec": int(time.time()),
            "free_heap_bytes": 0,
            "rssi": -50,
            "reconnect_counts": self.reconnect_count,
            "timestamp": datetime.now().isoformat()
        }
        return self.publish(topic, payload)

    def publish_card_uid_event(self, uid_hex, room_id=None):
        payload = {
            "device_id": self.device_id,
            "device_type": "front_desk",
            "event_type": "card_uid_detected",
            "card_uid": uid_hex,
            "timestamp": datetime.now().isoformat()
        }
        if room_id:
            payload["room_id"] = room_id
        return self.publish(TOPIC_SECURITY_EVENT, payload)
