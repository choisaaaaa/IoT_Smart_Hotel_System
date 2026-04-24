import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/constants/api_constants.dart';
import 'call_api_service.dart';

class VoiceCallService {
  static final VoiceCallService _instance = VoiceCallService._internal();
  factory VoiceCallService() => _instance;
  VoiceCallService._internal();

  final CallApiService _callApi = CallApiService();

  io.Socket? _socket;
  bool _isInitialized = false;
  bool _isRegistered = false;
  String? _clientId;
  String? _clientName;
  String? _clientType;
  Map<String, dynamic>? _onlineStatus;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  bool _isAudioOn = true;

  String? _currentCallId;
  String? _currentTargetId;
  String? _currentTargetType;

  Map<String, dynamic>? _pendingOffer;
  final List<Map<String, dynamic>> _pendingIceCandidates = [];

  final StreamController<Map<String, dynamic>> _callEventController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get callEvents => _callEventController.stream;

  final StreamController<MediaStream?> _remoteStreamController =
      StreamController<MediaStream?>.broadcast();
  Stream<MediaStream?> get remoteStream => _remoteStreamController.stream;

  bool get isConnected => _socket?.connected ?? false;
  bool get isRegistered => _isRegistered;
  String? get clientId => _clientId;
  String? get clientName => _clientName;
  String? get clientType => _clientType;
  Map<String, dynamic>? get onlineStatus => _onlineStatus;
  String? get currentCallId => _currentCallId;

  Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]
  };

  void init(String userId, {String clientType = 'front_desk'}) {
    _clientId = userId;
    _clientType = clientType;

    if (_isInitialized) {
      if (_socket?.connected == true) {
        registerClient(_clientId!);
      }
      return;
    }

    _socket = io.io(ApiConstants.serverHost, <String, dynamic>{
      'transports': ['websocket', 'polling'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 1000,
    });

    _socket!.onConnect((_) {
      debugPrint('[VoiceCallService] WebSocket已连接');
      if (_clientId != null) {
        registerClient(_clientId!);
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('[VoiceCallService] WebSocket已断开');
      _isRegistered = false;
      _callEventController.add({'type': 'disconnected', 'data': null});
    });

    _socket!.on('registered', (data) {
      debugPrint('[VoiceCallService] 注册成功: $data');
      _isRegistered = true;
      _clientName = data['clientName'];
      if (data['webrtcConfig'] != null) {
        _iceServers = data['webrtcConfig'] as Map<String, dynamic>;
        debugPrint('[VoiceCallService] 使用服务端WebRTC配置: $_iceServers');
      }
      _callEventController.add({'type': 'registered', 'data': data});
    });

    _socket!.on('online_status', (data) {
      debugPrint('[VoiceCallService] 在线状态更新');
      _onlineStatus = data is Map<String, dynamic> ? data : {'raw': data};
      _callEventController.add({'type': 'online_status', 'data': _onlineStatus});
    });

    _socket!.on('incoming_call', (data) {
      debugPrint('[VoiceCallService] 收到来电: $data');
      final callData = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
      if (callData['caller_id'] == _clientId) {
        debugPrint('[VoiceCallService] 忽略自己发起的来电');
        return;
      }
      _callEventController.add({'type': 'incoming_call', 'data': callData});
    });

    _socket!.on('call_initiated', (data) {
      debugPrint('[VoiceCallService] 呼叫已发起: $data');
      _callEventController.add({'type': 'call_initiated', 'data': data});
    });

    _socket!.on('webrtc_offer', (data) async {
      debugPrint('[VoiceCallService] 收到WebRTC Offer');
      final offerData = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
      await _handleOffer(offerData);
    });

    _socket!.on('webrtc_answer', (data) async {
      debugPrint('[VoiceCallService] 收到WebRTC Answer');
      final answerData = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
      await _handleAnswer(answerData);
    });

    _socket!.on('webrtc_ice_candidate', (data) async {
      debugPrint('[VoiceCallService] 收到ICE候选');
      final candidateData = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
      await _handleIceCandidate(candidateData);
    });

    _socket!.on('call_answered', (data) {
      debugPrint('[VoiceCallService] 通话已接听: $data');
      final answeredData = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
      _callEventController.add({'type': 'call_answered', 'data': answeredData});
    });

    _socket!.on('call_rejected', (data) {
      debugPrint('[VoiceCallService] 通话被拒接: $data');
      _callEventController.add({'type': 'call_rejected', 'data': data});
      _cleanup();
    });

    _socket!.on('call_hungup', (data) {
      debugPrint('[VoiceCallService] 通话已挂断: $data');
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

  void registerClient(String clientId) {
    _clientId = clientId;
    if (_socket?.connected == true) {
      debugPrint('[VoiceCallService] 注册客户端: $clientId, type: ${_clientType ?? "front_desk"}');
      _socket!.emit('register_client', {
        'clientType': _clientType ?? 'front_desk',
        'clientId': clientId,
      });
    } else {
      debugPrint('[VoiceCallService] WebSocket未连接，等待连接后自动注册');
    }
  }

  void unregisterClient() {
    _isRegistered = false;
    _clientName = null;
    if (_socket?.connected == true) {
      _socket!.emit('unregister_client');
    }
  }

  void requestOnlineStatus() {
    if (_socket?.connected == true) {
      _socket!.emit('get_online_status');
    }
  }

  Future<void> startCall(String calleeId, String calleeType) async {
    if (_socket?.connected != true) {
      _callEventController.add({
        'type': 'call_error',
        'data': {'message': '未连接到服务器，请先上线'}
      });
      return;
    }

    if (!_isRegistered) {
      _callEventController.add({
        'type': 'call_error',
        'data': {'message': '未上线，请先点击上线按钮'}
      });
      return;
    }

    if (_currentCallId != null) {
      _callEventController.add({
        'type': 'call_error',
        'data': {'message': '当前已有进行中的通话，请先挂断'}
      });
      return;
    }

    debugPrint('[VoiceCallService] 发起呼叫: callee_type=$calleeType, callee_id=$calleeId');

    final result = await _callApi.outbound(
      callerId: _clientId ?? '未知',
      calleeType: calleeType,
      calleeId: calleeId,
      callerType: _clientType ?? 'front_desk',
    );

    if (!result.success) {
      if ((result.message ?? '').contains('已在进行中')) {
        debugPrint('[VoiceCallService] 检测到残留通话，尝试清理后重试');
        final activeResult = await _callApi.getActive();
        if (activeResult.success && activeResult.data != null) {
          for (final call in activeResult.data!) {
            final callId = call['call_id'];
            if (callId != null) {
              await _callApi.hangup(callId.toString());
              debugPrint('[VoiceCallService] 已清理残留通话: $callId');
            }
          }
        }
        final retryResult = await _callApi.outbound(
          callerId: _clientId ?? '未知',
          calleeType: calleeType,
          calleeId: calleeId,
          callerType: _clientType ?? 'front_desk',
        );
        if (retryResult.success) {
          final callData = retryResult.data!;
          _currentCallId = callData['call_id'];
          _currentTargetId = calleeId;
          _currentTargetType = calleeType;
          _callEventController.add({
            'type': 'call_initiated',
            'data': callData,
          });
          return;
        }
      }
      _callEventController.add({
        'type': 'call_error',
        'data': {'message': result.message ?? '发起呼叫失败'}
      });
      return;
    }

    final callData = result.data!;
    _currentCallId = callData['call_id'];
    _currentTargetId = calleeId;
    _currentTargetType = calleeType;

    _callEventController.add({
      'type': 'call_initiated',
      'data': callData,
    });
  }

  Future<void> onCallAnswered(Map<String, dynamic> data) async {
    final callId = data['call_id'] ?? _currentCallId;
    if (callId == null) return;

    _currentCallId = callId;

    final targetType = data['callee_type'] ?? _currentTargetType ?? 'room';
    final targetId = data['callee_id'] ?? _currentTargetId ?? '';

    await _initPeerConnection(targetId, targetType, callId);

    if (_peerConnection != null) {
      try {
        final offer = await _peerConnection!.createOffer({
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': false,
        });
        await _peerConnection!.setLocalDescription(offer);

        _socket?.emit('webrtc_offer', {
          'target_type': targetType,
          'target_id': targetId,
          'offer': {
            'type': offer.type,
            'sdp': offer.sdp,
          },
          'call_id': callId,
        });
        debugPrint('[VoiceCallService] 主叫方已发送Offer, call_id: $callId');
      } catch (e) {
        debugPrint('[VoiceCallService] 创建Offer失败: $e');
      }
    }
  }

  Future<void> answerCall(String callId, String callerId, String callerType) async {
    final result = await _callApi.answer(callId);
    if (!result.success) {
      _callEventController.add({
        'type': 'call_error',
        'data': {'message': result.message ?? '接听失败'}
      });
      return;
    }

    _currentCallId = callId;
    _currentTargetId = callerId;
    _currentTargetType = callerType;

    await _initPeerConnection(callerId, callerType, callId);

    if (_peerConnection != null) {
      if (_pendingOffer != null) {
        debugPrint('[VoiceCallService] 处理缓存的Offer');
        await _processOffer(_pendingOffer!);
        _pendingOffer = null;
      } else {
        debugPrint('[VoiceCallService] 等待主叫方发送Offer...');
      }

      _processPendingIceCandidates();
    }
  }

  Future<void> rejectCall(String callId) async {
    await _callApi.reject(callId);
    _cleanup();
  }

  Future<void> hangup(String callId) async {
    await _callApi.hangup(callId);
    _socket?.emit('hangup_call', {'call_id': callId});
    _cleanup();
  }

  void toggleMute() {
    _isAudioOn = !_isAudioOn;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = _isAudioOn;
    });
  }

  bool get isMuted => !_isAudioOn;

  Future<void> _initPeerConnection(String targetId, String targetType, String? callId) async {
    await _cleanup();

    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
    } catch (e) {
      debugPrint('[VoiceCallService] 获取麦克风失败: $e');
      _callEventController.add({
        'type': 'call_error',
        'data': {'message': '无法访问麦克风，请检查权限'}
      });
      return;
    }

    _peerConnection = await createPeerConnection(_iceServers);

    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    _peerConnection?.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        _socket?.emit('webrtc_ice_candidate', {
          'target_type': targetType,
          'target_id': targetId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
          'call_id': callId ?? _currentCallId,
        });
      }
    };

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        debugPrint('[VoiceCallService] 收到远程音频流');
        _remoteStreamController.add(event.streams[0]);
      }
    };

    _peerConnection?.onConnectionState = (state) {
      debugPrint('[VoiceCallService] 连接状态: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _callEventController.add({
          'type': 'call_error',
          'data': {'message': '通话连接已断开'}
        });
        _cleanup();
      }
    };

    _currentTargetId = targetId;
    _currentTargetType = targetType;
    if (callId != null) {
      _currentCallId = callId;
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> data) async {
    debugPrint('[VoiceCallService] 处理Offer, call_id: ${data['call_id']}');

    if (_peerConnection == null) {
      debugPrint('[VoiceCallService] PeerConnection未初始化，缓存Offer');
      _pendingOffer = data;
      return;
    }

    await _processOffer(data);
  }

  Future<void> _processOffer(Map<String, dynamic> data) async {
    if (_peerConnection == null) return;

    try {
      final offer = RTCSessionDescription(
        data['offer']['sdp'] ?? '',
        data['offer']['type'] ?? 'offer',
      );
      await _peerConnection!.setRemoteDescription(offer);

      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });
      await _peerConnection!.setLocalDescription(answer);

      _socket?.emit('webrtc_answer', {
        'target_type': data['from_type'],
        'target_id': data['from_id'],
        'answer': {
          'type': answer.type,
          'sdp': answer.sdp,
        },
        'call_id': data['call_id'],
      });
      debugPrint('[VoiceCallService] 已发送Answer');
    } catch (e) {
      debugPrint('[VoiceCallService] 处理Offer失败: $e');
    }
  }

  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    if (_peerConnection == null) return;

    try {
      final answer = RTCSessionDescription(
        data['answer']['sdp'],
        data['answer']['type'],
      );
      await _peerConnection!.setRemoteDescription(answer);
      debugPrint('[VoiceCallService] 已设置远程Answer');

      _processPendingIceCandidates();
    } catch (e) {
      debugPrint('[VoiceCallService] 处理Answer失败: $e');
    }
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> data) async {
    if (_peerConnection != null) {
      try {
        final remoteDesc = await _peerConnection!.getRemoteDescription();
        if (remoteDesc != null) {
          final candidate = RTCIceCandidate(
            data['candidate']['candidate'],
            data['candidate']['sdpMid'],
            data['candidate']['sdpMLineIndex'],
          );
          await _peerConnection!.addCandidate(candidate);
          debugPrint('[VoiceCallService] ICE候选添加成功');
        } else {
          debugPrint('[VoiceCallService] 远程描述未设置，缓存ICE候选');
          _pendingIceCandidates.add(data);
        }
      } catch (e) {
        debugPrint('[VoiceCallService] 添加ICE候选失败: $e');
        _pendingIceCandidates.add(data);
      }
    } else {
      debugPrint('[VoiceCallService] PeerConnection未就绪，缓存ICE候选');
      _pendingIceCandidates.add(data);
    }
  }

  Future<void> _processPendingIceCandidates() async {
    while (_pendingIceCandidates.isNotEmpty && _peerConnection != null) {
      final data = _pendingIceCandidates.removeAt(0);
      try {
        final candidate = RTCIceCandidate(
          data['candidate']['candidate'],
          data['candidate']['sdpMid'],
          data['candidate']['sdpMLineIndex'],
        );
        await _peerConnection!.addCandidate(candidate);
      } catch (e) {
        debugPrint('[VoiceCallService] 处理缓存ICE候选失败: $e');
      }
    }
  }

  Future<void> _cleanup() async {
    _currentCallId = null;
    _currentTargetId = null;
    _currentTargetType = null;
    _pendingOffer = null;
    _pendingIceCandidates.clear();

    try {
      await _localStream?.dispose();
    } catch (_) {}
    _localStream = null;

    try {
      await _peerConnection?.close();
    } catch (_) {}
    _peerConnection = null;

    _remoteStreamController.add(null);
    _isAudioOn = true;
  }

  void dispose() {
    _cleanup();
    _socket?.disconnect();
    _callEventController.close();
  }
}
