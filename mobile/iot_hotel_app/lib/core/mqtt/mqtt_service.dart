import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../constants/mqtt_constants.dart';

class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  MqttServerClient? _client;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _disposed = false;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _reconnectBaseDelay = Duration(seconds: 2);
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  final Map<String, void Function(String)> _topicCallbacks = {};
  StreamSubscription? _messageSubscription;

  bool get isConnected => _isConnected;

  Future<bool> connect() async {
    if (_isConnecting || _isConnected) return _isConnected;
    _isConnecting = true;
    _disposed = false;

    try {
      _client = MqttServerClient.withPort(
        MqttConstants.brokerHost,
        '${MqttConstants.clientIdPrefix}${DateTime.now().millisecondsSinceEpoch}',
        MqttConstants.brokerPort,
      );

      _client!.logging(on: false);
      _client!.keepAlivePeriod = MqttConstants.keepAlive;
      _client!.connectTimeoutPeriod = MqttConstants.connectTimeout;
      _client!.onDisconnected = _onDisconnected;
      _client!.onConnected = _onConnected;
      _client!.onSubscribed = _onSubscribed;

      final connMsg = MqttConnectMessage()
          .withWillTopic('iot_hotel_app/disconnect')
          .withWillMessage('client_disconnected')
          .withWillQos(MqttQos.atMostOnce)
          .withWillRetain();

      if (MqttConstants.username.isNotEmpty) {
        connMsg.authenticateAs(MqttConstants.username, MqttConstants.password);
      }

      _client!.connectionMessage = connMsg;

      await _client!.connect();

      if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
        _isConnected = true;
        _reconnectAttempts = 0;
        _setupMessageListener();
        _startHeartbeat();
        _resubscribeAll();
        return true;
      }

      _scheduleReconnect();
      return false;
    } catch (e) {
      debugPrint('MQTT连接失败: $e');
      _isConnected = false;
      _scheduleReconnect();
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  void disconnect() {
    _disposed = true;
    _cancelReconnect();
    _stopHeartbeat();
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _client?.disconnect();
    _client = null;
    _isConnected = false;
  }

  void _onDisconnected() {
    debugPrint('MQTT已断开');
    _isConnected = false;
    _messageSubscription?.cancel();
    _messageSubscription = null;
    if (!_disposed) {
      _scheduleReconnect();
    }
  }

  void _onConnected() {
    debugPrint('MQTT已连接');
    _isConnected = true;
    _reconnectAttempts = 0;
  }

  void _onSubscribed(String topic) {
    debugPrint('已订阅Topic: $topic');
  }

  void _setupMessageListener() {
    _messageSubscription?.cancel();
    _messageSubscription = _client?.updates?.listen(
      (List<MqttReceivedMessage<MqttMessage?>>? messages) {
        if (messages == null || messages.isEmpty) return;
        final MqttPublishMessage recMess = messages[0].payload as MqttPublishMessage;
        final String payload = utf8.decode(recMess.payload.message, allowMalformed: true);
        final String topic = messages[0].topic;

        for (final entry in _topicCallbacks.entries) {
          if (topic.contains(entry.key)) {
            entry.value(payload);
          }
        }
      },
      onError: (error) {
        debugPrint('MQTT消息监听错误: $error');
      },
    );
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_isConnected && _client != null) {
        try {
          final builder = MqttClientPayloadBuilder();
          builder.addUTF8String(jsonEncode({
            'client_id': _client!.clientIdentifier,
            'timestamp': DateTime.now().toIso8601String(),
          }));
          _client!.publishMessage(
            'iot_hotel_app/heartbeat',
            MqttQos.atMostOnce,
            builder.payload!,
          );
        } catch (e) {
          debugPrint('MQTT心跳发送失败: $e');
        }
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _scheduleReconnect() {
    _cancelReconnect();
    if (_disposed) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('MQTT达到最大重连次数，停止重连');
      return;
    }

    final delay = _reconnectBaseDelay * (1 << _reconnectAttempts.clamp(0, 5));
    _reconnectAttempts++;
    debugPrint('MQTT将在${delay.inSeconds}秒后尝试第$_reconnectAttempts次重连');

    _reconnectTimer = Timer(delay, () async {
      if (!_disposed && !_isConnected && !_isConnecting) {
        debugPrint('MQTT开始第$_reconnectAttempts次重连');
        await connect();
      }
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _resubscribeAll() {
    if (!_isConnected || _client == null) return;
    for (final topic in _topicCallbacks.keys) {
      try {
        _client!.subscribe(topic, MqttQos.atLeastOnce);
      } catch (e) {
        debugPrint('MQTT重新订阅$topic失败: $e');
      }
    }
  }

  Future<void> subscribe(String topic) async {
    if (_isConnected && _client != null) {
      try {
        _client!.subscribe(topic, MqttQos.atLeastOnce);
      } catch (e) {
        debugPrint('MQTT订阅$topic失败: $e');
      }
    }
  }

  Future<void> publish(String topic, String message) async {
    if (_isConnected && _client != null) {
      try {
        final builder = MqttClientPayloadBuilder();
        builder.addUTF8String(message);
        _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      } catch (e) {
        debugPrint('MQTT发布消息失败: $e');
      }
    }
  }

  void onMessage(String topic, void Function(String message) callback) {
    _topicCallbacks[topic] = callback;
    if (_isConnected) {
      subscribe(topic);
    }
  }

  void removeCallback(String topic) {
    _topicCallbacks.remove(topic);
    if (_isConnected && _client != null) {
      try {
        _client!.unsubscribe(topic);
      } catch (e) {
        debugPrint('MQTT取消订阅$topic失败: $e');
      }
    }
  }
}
