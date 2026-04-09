import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants/api_constants.dart';

class VoiceCallService {
  static final VoiceCallService _instance = VoiceCallService._internal();
  factory VoiceCallService() => _instance;
  VoiceCallService._internal();

  IO.Socket? _socket;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  bool _isInitialized = false;

  final StreamController<Map<String, dynamic>> _callEventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get callEvents => _callEventController.stream;

  void init(String userId) {
    if (_isInitialized) return;

    _socket = IO.io(ApiConstants.baseUrl, <String, dynamic>{
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
    // 1. 发起呼叫指令 (通过 REST API 或 Socket)
    // 这里演示使用 Socket 发起
    _socket?.emit('initiate_call', {
      'callee_type': calleeType,
      'callee_id': calleeId,
      'type': 'voice',
    });

    // 2. 初始化 WebRTC
    await _initPeerConnection(calleeId, calleeType, null);
    
    // 3. 创建 Offer
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    // 4. 发送 Offer
    _socket?.emit('webrtc_offer', {
      'target_type': calleeType,
      'target_id': calleeId,
      'offer': {'sdp': offer.sdp, 'type': offer.type},
      'call_id': 'temporary_id' // 实际应使用服务器返回的 call_id
    });
  }

  Future<void> answerCall(String callId, String callerId, String callerType) async {
    _socket?.emit('answer_call', {'callId': callId});
    await _initPeerConnection(callerId, callerType, callId);
  }

  Future<void> hangup(String callId) async {
    _socket?.emit('hangup_call', {'callId': callId});
    _cleanup();
  }

  Future<void> _initPeerConnection(String targetId, String targetType, String? callId) async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"},
      ]
    };

    _peerConnection = await createRTCPeerConnection(configuration);

    _peerConnection!.onIceCandidate = (candidate) {
      _socket?.emit('webrtc_ice_candidate', {
        'target_type': targetType,
        'target_id': targetId,
        'candidate': candidate.toMap(),
        'call_id': callId ?? ''
      });
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _callEventController.add({
          'type': 'remote_stream',
          'stream': event.streams[0],
        });
      }
    };

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });
  }

  Future<void> _handleOffer(Map<String, dynamic> data) async {
    if (_peerConnection == null) {
      await _initPeerConnection(data['from_id'], data['from_type'], data['call_id']);
    }

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(data['offer']['sdp'], data['offer']['type']),
    );

    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    _socket?.emit('webrtc_answer', {
      'target_type': data['from_type'],
      'target_id': data['from_id'],
      'answer': {'sdp': answer.sdp, 'type': answer.type},
      'call_id': data['call_id']
    });
  }

  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    if (_peerConnection != null) {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(data['answer']['sdp'], data['answer']['type']),
      );
    }
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> data) async {
    if (_peerConnection != null) {
      await _peerConnection!.addCandidate(
        RTCIceCandidate(data['candidate']['candidate'], data['candidate']['sdpMid'], data['candidate']['sdpMLineIndex']),
      );
    }
  }

  void _cleanup() {
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;
    
    _peerConnection?.close();
    _peerConnection?.dispose();
    _peerConnection = null;
  }

  void dispose() {
    _cleanup();
    _socket?.disconnect();
    _callEventController.close();
  }
}
