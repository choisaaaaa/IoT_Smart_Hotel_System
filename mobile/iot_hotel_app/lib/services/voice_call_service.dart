import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

typedef RTCPeerConnection = dynamic;
typedef RTCSessionDescription = dynamic;
typedef RTCIceCandidate = dynamic;
typedef MediaStream = dynamic;

class VoiceCallService {
  static final VoiceCallService _instance = VoiceCallService._internal();
  factory VoiceCallService() => _instance;
  VoiceCallService._internal();

  IO.Socket? _socket;
  bool _isInitialized = false;

  final StreamController<Map<String, dynamic>> _callEventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get callEvents => _callEventController.stream;

  void init(String userId) {
    if (_isInitialized) return;

    _socket = IO.io('http://8.134.166.69:9000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket!.onConnect((_) {
      debugPrint('WebRTC Signaling Socket已连接');
      _socket!.emit('register_client', {
        'clientType': 'app',
        'clientId': userId,
      });
    });

    _socket!.on('incoming_call', (data) {
      _callEventController.add({'type': 'incoming_call', 'data': data});
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

    _isInitialized = true;
  }

  Future<void> startCall(String calleeId, String calleeType) async {
    _socket?.emit('initiate_call', {
      'callee_type': calleeType,
      'callee_id': calleeId,
      'type': 'voice',
    });

    try {
      await _initPeerConnection(calleeId, calleeType, null);
    } catch (e) {
      debugPrint('WebRTC not available: $e');
      _callEventController.add({'type': 'call_error', 'data': {'message': 'WebRTC功能暂不可用'}});
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
