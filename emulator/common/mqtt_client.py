"""
MQTT客户端封装模块
"""
import json
import time
import threading
import hashlib
import hmac
import paho.mqtt.client as mqtt
from datetime import datetime
from .logger import Logger, get_log_buffer
from .config import (
    TOPIC_DEVICE_STATUS_PREFIX,
    TOPIC_DEVICE_DATA_PREFIX,
    TOPIC_DEVICE_COMMAND_PREFIX,
    TOPIC_DEVICE_COMMAND_RESULT,
    TOPIC_SECURITY_EVENT,
    TOPIC_AI_RESPONSE
)


class MQTTClient:
    """MQTT客户端封装类"""

    def __init__(self, device_id, device_type, broker="8.134.166.69", port=1883, device_key="", username="root", password="IotHotel2026", hotel_id=None):
        self.device_id = device_id
        self.device_type = device_type
        self.broker = broker
        self.port = port
        self.device_key = device_key  # 设备密钥，用于签名
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

        # 统计
        self.msg_sent = 0
        self.msg_received = 0
        self.reconnect_count = 0

        # 健康上报
        self._stop_health = threading.Event()
        self._health_thread = None

        # 认证状态
        self.audit_status = "pending"  # pending, approved, rejected
        # self.hotel_id 已在 __init__ 中赋值

    def _on_connect(self, client, userdata, flags, rc):
        """连接回调"""
        if rc == 0:
            self.connected = True
            self.logger.info(f"MQTT连接成功: {self.broker}:{self.port}")
            self.log_buffer.log("INFO", f"MQTT连接成功")

            # 重新订阅
            for topic in self.subscriptions:
                self.client.subscribe(topic)
                self.logger.info(f"重新订阅: {topic}")

            # 启动心跳
            self._start_heartbeat()

            # 启动健康上报
            self._start_health_report()

            # 发送上线状态
            self.publish_online_status()

            # 发送健康报告
            self.publish_health_report()
        else:
            self.logger.error(f"MQTT连接失败，返回码: {rc}")
            self.log_buffer.log("ERROR", f"MQTT连接失败，返回码: {rc}")

    def _on_disconnect(self, client, userdata, rc):
        """断开连接回调"""
        self.connected = False
        self._stop_heartbeat.set()
        self._stop_health.set()
        if rc != 0:
            self.reconnect_count += 1
            self.logger.warning(f"MQTT意外断开，返回码: {rc}")
            self.log_buffer.log("WARNING", f"MQTT意外断开")

    def _on_message(self, client, userdata, msg):
        """消息接收回调"""
        self.msg_received += 1
        topic = msg.topic
        payload = msg.payload.decode('utf-8')

        self.logger.info(f"接收 [{topic}]: {payload}")
        self.log_buffer.log("RX", f"[{topic}] {payload}")

        # 调用订阅回调
        if topic in self.subscriptions:
            try:
                self.subscriptions[topic](topic, payload)
            except Exception as e:
                self.logger.error(f"处理消息失败: {e}")

        # 处理命令
        if TOPIC_DEVICE_COMMAND_PREFIX in topic:
            self._handle_command(payload)
        
        # 处理 AI 响应
        if "hotel/ai/response/room/" in topic:
            try:
                data = json.loads(payload)
                if hasattr(self, 'on_ai_response') and self.on_ai_response:
                    self.on_ai_response(data)
            except Exception as e:
                self.logger.error(f"处理 AI 响应失败: {e}")

    def _handle_command(self, payload):
        """处理控制命令"""
        try:
            data = json.loads(payload)
            cmd_type = data.get('command_type')
            cmd_id = data.get('command_id', 0)
            device_id_in_cmd = data.get('device_id', '')

            # 验证device_id是否匹配
            if device_id_in_cmd and device_id_in_cmd != self.device_id:
                self.logger.warning(f"忽略非本机指令: target={device_id_in_cmd} self={self.device_id}")
                return

            if cmd_type in self.command_handlers:
                handler = self.command_handlers[cmd_type]
                result = handler(data)
                self.publish_command_result(cmd_id, cmd_type, result)
            else:
                self.logger.warning(f"未知命令: {cmd_type}")
                self.publish_command_result(cmd_id, cmd_type, False, "未知命令")
        except json.JSONDecodeError:
            self.logger.error("命令JSON解析失败")
        except Exception as e:
            self.logger.error(f"处理命令失败: {e}")

    def _start_heartbeat(self):
        """启动心跳线程"""
        self._stop_heartbeat.clear()
        self._heartbeat_thread = threading.Thread(target=self._heartbeat_loop, daemon=True)
        self._heartbeat_thread.start()

    def _heartbeat_loop(self):
        """心跳循环"""
        while not self._stop_heartbeat.is_set():
            if self.connected:
                self.publish_heartbeat()
            # 60秒心跳间隔
            for _ in range(60):
                if self._stop_heartbeat.is_set():
                    break
                time.sleep(1)

    def connect(self):
        """连接MQTT Broker"""
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
        """断开MQTT连接"""
        self._stop_heartbeat.set()
        self._stop_health.set()
        self.client.loop_stop()
        self.client.disconnect()
        self.connected = False
        self.logger.info("MQTT已断开")
        self.log_buffer.log("INFO", "MQTT已断开")

    def subscribe(self, topic, callback=None):
        """订阅主题"""
        self.subscriptions[topic] = callback
        if self.connected:
            self.client.subscribe(topic)
            self.logger.info(f"订阅: {topic}")

    def _generate_signature(self, payload_dict):
        """生成消息签名"""
        if not self.device_key:
            return None

        # 添加时间戳
        payload_dict['timestamp'] = datetime.now().isoformat()

        # 按key排序并拼接成字符串
        sorted_items = sorted(payload_dict.items())
        sign_str = '&'.join([f"{k}={v}" for k, v in sorted_items if k != 'signature'])

        # 使用HMAC-SHA256生成签名
        signature = hmac.new(
            self.device_key.encode('utf-8'),
            sign_str.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()

        return signature

    def publish(self, topic, payload):
        """发布消息"""
        if not self.connected:
            self.logger.warning("MQTT未连接，无法发布消息")
            return False

        try:
            if isinstance(payload, dict):
                # 如果已审核，添加签名
                if self.audit_status == "approved" and self.device_key:
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
        """注册命令处理器"""
        self.command_handlers[cmd_type] = handler

    def publish_online_status(self):
        """发布在线状态"""
        topic = TOPIC_DEVICE_STATUS_PREFIX
        payload = {
            "device_id": self.device_id,
            "device_type": self.device_type,
            "status": "online",
            "hotel_id": self.hotel_id
        }
        self.publish(topic, payload)

    def publish_heartbeat(self):
        """发布心跳"""
        topic = f"{TOPIC_DEVICE_STATUS_PREFIX}/{self.device_type}/{self.device_id}"
        payload = {
            "device_id": self.device_id,
            "status": "online",
            "battery_level": 100,
            "signal_strength": -50,
            "uptime": int(time.time()),
            "memory_usage": 45,
            "timestamp": datetime.now().isoformat()
        }
        return self.publish(topic, payload)

    def publish_sensor_data(self, sensor_type, value, unit):
        """发布传感器数据"""
        topic = f"{TOPIC_DEVICE_DATA_PREFIX}/{sensor_type}/{self.device_id}"
        payload = {
            "device_id": self.device_id,
            "sensor_type": sensor_type,
            "value": value,
            "unit": unit,
            "timestamp": datetime.now().isoformat()
        }
        return self.publish(topic, payload)

    def publish_command_result(self, cmd_id, cmd_type, success, result_msg=""):
        """发布命令执行结果"""
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
        """发布安防事件"""
        payload = {
            "device_id": self.device_id,
            "event_type": event_type,
            "event_data": event_data or {},
            "level": level,
            "timestamp": datetime.now().isoformat()
        }
        return self.publish(TOPIC_SECURITY_EVENT, payload)

    def publish_to_room(self, room_id, cmd_type, extra_data=None):
        """向客房发送命令"""
        topic = f"{TOPIC_DEVICE_COMMAND_PREFIX}/room/room_{room_id}"
        payload = {
            "command_id": int(time.time() * 1000) % 100000,
            "device_id": f"room_{room_id}",
            "command_type": cmd_type,
            "created_by": self.device_id,
            "timestamp": datetime.now().isoformat()
        }
        if extra_data:
            payload.update(extra_data)
        return self.publish(topic, payload)

    def _start_health_report(self):
        """启动健康上报线程"""
        self._stop_health.clear()
        self._health_thread = threading.Thread(target=self._health_loop, daemon=True)
        self._health_thread.start()

    def _health_loop(self):
        """健康上报循环（每10分钟）"""
        while not self._stop_health.is_set():
            if self.connected:
                self.publish_health_report()
            # 10分钟间隔
            for _ in range(600):
                if self._stop_health.is_set():
                    break
                time.sleep(1)

    def publish_health_report(self):
        """发布健康报告"""
        topic = f"hotel/health/{self.device_type}/{self.device_id}"
        payload = {
            "device_id": self.device_id,
            "device_type": self.device_type,
            "firmware_version": "v1.1.0-emulator",
            "uptime_sec": int(time.time()),
            "free_heap_bytes": 0,  # 模拟值
            "rssi": -50,  # 模拟信号强度
            "reconnect_counts": self.reconnect_count,
            "timestamp": datetime.now().isoformat()
        }
        return self.publish(topic, payload)

    def publish_card_uid_event(self, uid_hex):
        """发布卡片UID检测事件（前台专用）"""
        payload = {
            "device_id": self.device_id,
            "device_type": "front_desk",
            "event_type": "card_uid_detected",
            "card_uid": uid_hex,
            "timestamp": datetime.now().isoformat()
        }
        return self.publish(TOPIC_SECURITY_EVENT, payload)
