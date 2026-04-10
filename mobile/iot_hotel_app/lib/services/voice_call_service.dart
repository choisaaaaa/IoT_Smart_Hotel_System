import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/constants/api_constants.dart';

typedef RTCPeerConnection = dynamic;
typedef RTCSessionDescription = dynamic;
typedef RTCIceCandidate = dynamic;
typedef MediaStream = dynamic;

class VoiceCallService {
  static final VoiceCallService _instance = VoiceCallService._internal();
  factory VoiceCallService() => _instance;
  VoiceCallService._internal();

  io.Socket? _socket;
  bool _isInitialized = false;
  bool _isRegistered = false;
  String? _clientId;
  String? _clientName;
  Map<String, dynamic>? _onlineStatus;

  final StreamController<Map<String, dynamic>> _callEventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get callEvents => _callEventController.stream;

  bool get isConnected => _socket?.connected ?? false;
  bool get isRegistered => _isRegistered;
  String? get clientId => _clientId;
  String? get clientName => _clientName;
  Map<String, dynamic>? get onlineStatus => _onlineStatus;

  void init(String userId) {
    if (_isInitialized) return;

    _socket = io.io(ApiConstants.serverHost, <String, dynamic>{
      'transports': ['websocket', 'polling'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 1000,
    });

    _socket!.onConnect((_) {
      debugPrint('[VoiceCallService] WebSocket已连接');
      // 连接成功后自动注册
      if (_clientId != null) {
        registerClient(_clientId!);
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('[VoiceCallService] WebSocket已断开');
      _isRegistered = false;
    });

    _socket!.on('registered', (data) {
      debugPrint('[VoiceCallService] 注册成功: $data');
      _isRegistered = true;
      _clientName = data['clientName'];
      _callEventController.add({'type': 'registered', 'data': data});
    });

    _socket!.on('online_status', (data) {
      debugPrint('[VoiceCallService] 在线状态更新: $data');
      _onlineStatus = data;
      _callEventController.add({'type': 'online_status', 'data': data});
    });

    _socket!.on('incoming_call', (data) {
      debugPrint('[VoiceCallService] 收到来电: $data');
      _callEventController.add({'type': 'incoming_call', 'data': data});
    });

    _socket!.on('call_initiated', (data) {
      debugPrint('[VoiceCallService] 呼叫已发起: $data');
      _callEventController.add({'type': 'call_initiated', 'data': data});
    });

    _socket!.on('webrtc_offer', (data) async {
      await _handleOffer(data);
    });

    _socket!.on('webrtc_answer', (data) async {
      await _handleAnswer(data);
    });

    _socket!.on('webrtc_ice_candidate', (data) async {
      await _handleIceCandidate(data);
    });

    _socket!.on('call_answered', (data) {
      _callEventController.add({'type': 'call_answered', 'data': data});
    });

    _socket!.on('call_rejected', (data) {
      _callEventController.add({'type': 'call_rejected', 'data': data});
      _cleanup();
    });

    _socket!.on('call_hungup', (data) {
      _callEventController.add({'type': 'call_hungup', 'data': data});
      _cleanup();
    });

    _socket!.on('call_error', (data) {
      debugPrint('[VoiceCallService] 呼叫错误: $data');
      _callEventController.add({'type': 'call_error', 'data': data});
    });

    _socket!.on('error', (data) {
      debugPrint('[VoiceCallService] 错误: $data');
      _callEventController.add({'type': 'error', 'data': data});
    });

    _isInitialized = true;
  }

  /// 注册客户端（上线）
  void registerClient(String clientId) {
    _clientId = clientId;
    if (_socket?.connected == true) {
      debugPrint('[VoiceCallService] 注册客户端: $clientId');
      _socket!.emit('register_client', {
        'clientType': 'app',
        'clientId': clientId,
      });
    } else {
      debugPrint('[VoiceCallService] WebSocket未连接，等待连接后自动注册');
    }
  }

  /// 注销客户端（下线）
  void unregisterClient() {
    _isRegistered = false;
    _clientId = null;
    _clientName = null;
    if (_socket?.connected == true) {
      _socket!.disconnect();
    }
  }

  /// 获取在线状态
  void requestOnlineStatus() {
    if (_socket?.connected == true) {
      _socket!.emit('get_online_status');
    }
  }

  Future<void> startCall(String calleeId, String calleeType) async {
    if (_socket?.connected != true) {
      debugPrint('[VoiceCallService] WebSocket未连接，无法发起呼叫');
      _callEventController.add({
        'type': 'call_error',
        'data': {'message': '未连接到服务器，请先上线'}
      });
      return;
    }

    if (!_isRegistered) {
      debugPrint('[VoiceCallService] 客户端未注册，无法发起呼叫');
      _callEventController.add({
        'type': 'call_error',
        'data': {'message': '未上线，请先点击上线按钮'}
      });
      return;
    }

    debugPrint('[VoiceCallService] 发起呼叫: callee_type=$calleeType, callee_id=$calleeId');
    _socket?.emit('initiate_call', {
      'callee_type': calleeType,
      'callee_id': calleeId,
      'type': 'voice',
    });

    try {
      await _initPeerConnection(calleeId, calleeType, null);
    } catch (e) {
      debugPrint('WebRTC not available: $e');
    }
  }

  Future<void> answerCall(String callId, String callerId, String callerType) async {
    _socket?.emit('answer_call', {'callId': callId});
    try {
      await _initPeerConnection(callerId, callerType, callId);
    } catch (e) {
      debugPrint('WebRTC not available: $e');
    }
  }

  Future<void> rejectCall(String callId) async {
    _socket?.emit('reject_call', {'callId': callId});
  }

  Future<void> hangup(String callId) async {
    _socket?.emit('hangup_call', {'callId': callId});
    _cleanup();
  }

  Future<void> _initPeerConnection(String targetId, String targetType, String? callId) async {
    debugPrint('PeerConnection init for $targetId (WebRTC stub)');
  }

  Future<void> _handleOffer(Map<String, dynamic> data) async {
    debugPrint('Received WebRTC offer (stub)');
  }

  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    debugPrint('Received WebRTC answer (stub)');
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> data) async {
    debugPrint('Received ICE candidate (stub)');
  }

  void _cleanup() {
  }

  void dispose() {
    _cleanup();
    _socket?.disconnect();
    _callEventController.close();
  }
}
