import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../constants/mqtt_constants.dart';

class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  MqttServerClient? _client;
  bool _isConnected = false;
  final Map<String, void Function(String)> _topicCallbacks = {};

  bool get isConnected => _isConnected;

  Future<bool> connect() async {
    try {
      _client = MqttServerClient.withPort(
        MqttConstants.brokerHost,
        '${MqttConstants.clientIdPrefix}${DateTime.now().millisecondsSinceEpoch}',
        MqttConstants.brokerPort,
      );

      _client!.logging(on: false);
      _client!.keepAlivePeriod = MqttConstants.keepAlive;
      _client!.onDisconnected = _onDisconnected;
      _client!.onConnected = _onConnected;
      _client!.onSubscribed = _onSubscribed;

     final connMsg = MqttConnectMessage()
        .authenticateAs(MqttConstants.username, MqttConstants.password)
        .withWillRetain(false)
        .withWillQos(MqttQos.atMostOnce);

      _client!.connectionMessage = connMsg;

      await _client!.connect();

      if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
        _isConnected = true;
        _setupMessageListener();
        return true;
      }
      return false;
    } catch (e) {
      print('MQTT连接失败: $e');
      _isConnected = false;
      return false;
    }
  }

  void disconnect() {
    _client?.disconnect();
    _isConnected = false;
  }

  Future<void> subscribe(String topic) async {
    if (_isConnected && _client != null) {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
    }
  }

  Future<void> publish(String topic, String message) async {
    if (_isConnected && _client != null) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    }
  }

  void onMessage(String topic, void Function(String message) callback) {
    _topicCallbacks[topic] = callback;
  }

  void removeCallback(String topic) {
    _topicCallbacks.remove(topic);
  }

  void _setupMessageListener() {
    _client?.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final MqttPublishMessage recMess = c![0].payload as MqttPublishMessage;
      final String pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      final String topic = c[0].topic;

      for (final entry in _topicCallbacks.entries) {
        if (topic.contains(entry.key)) {
          entry.value(pt);
        }
      }
    });
  }

  void _onConnected() {
    print('MQTT已连接');
  }

  void _onDisconnected() {
    print('MQTT已断开');
    _isConnected = false;
  }

  void _onSubscribed(String topic) {
    print('已订阅Topic: $topic');
  }
}
