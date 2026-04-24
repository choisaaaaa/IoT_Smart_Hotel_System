import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../core/services/realtime_service.dart';
import 'call_api_service.dart';

class VoiceCallService {
  static final VoiceCallService _instance = VoiceCallService._internal();
  factory VoiceCallService() => _instance;
  VoiceCallService._internal();

  final CallApiService _callApi = CallApiService();
  final RealtimeService _realtimeService = RealtimeService();

  bool _isInitialized = false;
  bool _isRegistered = false;
  String? _clientId;
  String? _clientName;
  String? _clientType;
  Map<String, dynamic>? _onlineStatus;

  String? _savedOriginalClientType;
  String? _savedOriginalClientId;
  int? _savedOriginalHotelId;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  bool _isAudioOn = true;

  String? _currentCallId;
  String? _currentTargetId;
  String? _currentTargetType;

  Map<String, dynamic>? _pendingOffer;
  final List<Map<String, dynamic>> _pendingIceCandidates = [];

  Timer? _reconnectTimer;
  bool _isReconnecting = false;
  bool _isInitializingCall = false;
  bool _isCleaningUp = false;
  String? _lastProcessedAnsweredCallId;

  final StreamController<Map<String, dynamic>> _callEventController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get callEvents => _callEventController.stream;

  final StreamController<MediaStream?> _remoteStreamController =
      StreamController<MediaStream?>.broadcast();
  Stream<MediaStream?> get remoteStream => _remoteStreamController.stream;

  bool get isConnected => _realtimeService.isConnected;
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

  StreamSubscription? _realtimeEventSub;

  void ensureListenersSetup() {
    if (_realtimeEventSub != null) return;
    _setupRealtimeListeners();
    _isInitialized = true;
    _savedOriginalClientType = _realtimeService.clientType;
    _savedOriginalClientId = _realtimeService.clientId;
    _savedOriginalHotelId = _realtimeService.hotelId;
  }

  void init(String userId, {String clientType = 'front_desk'}) {
    _clientId = userId;
    _clientType = clientType;

    if (_isInitialized) {
      registerClient(userId);
      return;
    }

    _setupRealtimeListeners();
    _isInitialized = true;

    _savedOriginalClientType = _realtimeService.clientType;
    _savedOriginalClientId = _realtimeService.clientId;
    _savedOriginalHotelId = _realtimeService.hotelId;

    registerClient(userId);
  }

  void _setupRealtimeListeners() {
    _realtimeEventSub?.cancel();
    _realtimeEventSub = _realtimeService.events.listen((event) {
      if (!_isInitialized) return;

      switch (event.type) {
        case 'registered':
          _isRegistered = true;
          _clientName = event.data?['clientName'];
          if (event.data?['webrtcConfig'] != null) {
            _iceServers = event.data!['webrtcConfig'] as Map<String, dynamic>;
            debugPrint('[VoiceCallService] 使用服务端WebRTC配置: $_iceServers');
          }
          _callEventController.add({'type': 'registered', 'data': event.data});
          break;
        case 'disconnected':
          _isRegistered = false;
          _callEventController.add({'type': 'disconnected', 'data': null});
          break;
        case 'online_status':
          _onlineStatus = event.data;
          _callEventController.add({'type': 'online_status', 'data': _onlineStatus});
          break;
        case 'incoming_call':
          final callData = event.data;
          if (callData?['caller_id'] == _clientId) {
            debugPrint('[VoiceCallService] 忽略自己发起的来电');
            return;
          }
          _callEventController.add({'type': 'incoming_call', 'data': callData});
          break;
        case 'call_initiated':
          _callEventController.add({'type': 'call_initiated', 'data': event.data});
          break;
        case 'webrtc_offer':
          _handleOffer(event.data ?? {});
          break;
        case 'webrtc_answer':
          _handleAnswer(event.data ?? {});
          break;
        case 'webrtc_ice_candidate':
          _handleIceCandidate(event.data ?? {});
          break;
        case 'call_answered':
          final answeredCallId = event.data?['call_id']?.toString();
          if (answeredCallId != null && answeredCallId == _lastProcessedAnsweredCallId) {
            debugPrint('[VoiceCallService] 忽略重复的call_answered事件: $answeredCallId');
            return;
          }
          _lastProcessedAnsweredCallId = answeredCallId;
          _callEventController.add({'type': 'call_answered', 'data': event.data});
          break;
        case 'call_rejected':
          _lastProcessedAnsweredCallId = null;
          _callEventController.add({'type': 'call_rejected', 'data': event.data});
          _cleanup();
          break;
        case 'call_hungup':
          _lastProcessedAnsweredCallId = null;
          _callEventController.add({'type': 'call_hungup', 'data': event.data});
          _cleanup();
          break;
        case 'call_error':
          _callEventController.add({'type': 'call_error', 'data': event.data});
          break;
      }
    });
  }

  void registerClient(String clientId) {
    _clientId = clientId;
    if (_realtimeService.isConnected) {
      debugPrint('[VoiceCallService] 注册客户端: $clientId, type: ${_clientType ?? "front_desk"}');
      _realtimeService.emitRegisterClient(
        clientType: _clientType ?? 'front_desk',
        clientId: clientId,
      );
    } else {
      debugPrint('[VoiceCallService] WebSocket未连接，等待连接后自动注册');
    }
  }

  void unregisterClient() {
    _isRegistered = false;
    _clientName = null;
    _realtimeService.unregisterClient();

    if (_savedOriginalClientId != null) {
      debugPrint('[VoiceCallService] 恢复原始注册: $_savedOriginalClientId, type: $_savedOriginalClientType');
      _realtimeService.emitRegisterClient(
        clientType: _savedOriginalClientType ?? 'app',
        clientId: _savedOriginalClientId!,
        hotelId: _savedOriginalHotelId,
      );
    }
  }

  void requestOnlineStatus() {
    _realtimeService.requestOnlineStatus();
  }

  Future<void> startCall(String calleeId, String calleeType) async {
    if (!_realtimeService.isConnected) {
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

    if (_isInitializingCall || _peerConnection != null) {
      debugPrint('[VoiceCallService] 通话正在初始化或已存在连接，忽略重复的onCallAnswered调用');
      return;
    }

    _isInitializingCall = true;
    _currentCallId = callId;

    final targetType = data['callee_type'] ?? _currentTargetType ?? 'room';
    final targetId = data['callee_id'] ?? _currentTargetId ?? '';

    try {
      await _initPeerConnection(targetId, targetType, callId);

      if (_peerConnection != null) {
        try {
          final offer = await _peerConnection!.createOffer({
            'offerToReceiveAudio': true,
            'offerToReceiveVideo': false,
          });
          await _peerConnection!.setLocalDescription(offer);

          _realtimeService.emitWebRTCOffer(
            targetType: targetType,
            targetId: targetId,
            offer: {
              'type': offer.type,
              'sdp': offer.sdp,
            },
            callId: callId,
          );
          debugPrint('[VoiceCallService] 主叫方已发送Offer, call_id: $callId');
        } catch (e) {
          debugPrint('[VoiceCallService] 创建Offer失败: $e');
        }
      }
    } finally {
      _isInitializingCall = false;
    }
  }

  Future<void> answerCall(String callId, String callerId, String callerType) async {
    if (_isInitializingCall || _peerConnection != null) {
      debugPrint('[VoiceCallService] 通话正在初始化或已存在连接，忽略重复的answerCall调用');
      return;
    }

    _isInitializingCall = true;

    try {
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
    } finally {
      _isInitializingCall = false;
    }
  }

  Future<void> rejectCall(String callId) async {
    await _callApi.reject(callId);
    _cleanup();
  }

  Future<void> hangup(String callId) async {
    _lastProcessedAnsweredCallId = null;
    await _callApi.hangup(callId);
    _realtimeService.emitHangupCall(callId);
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
    if (_peerConnection != null) {
      debugPrint('[VoiceCallService] PeerConnection已存在，先清理');
      await _cleanup();
    }

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
        _realtimeService.emitWebRTCIceCandidate(
          targetType: targetType,
          targetId: targetId,
          candidate: {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
          callId: callId ?? _currentCallId,
        );
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
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        if (_currentCallId == null) return;
        _callEventController.add({
          'type': 'call_error',
          'data': {'message': '通话连接已断开'}
        });
        _cleanup();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        if (_currentCallId == null) return;
        _cleanup();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        if (_currentCallId == null) return;
        debugPrint('[VoiceCallService] 连接暂时断开，等待恢复...');
        _callEventController.add({
          'type': 'call_reconnecting',
          'data': {'message': '通话连接不稳定，正在尝试恢复...'}
        });
        _attemptReconnect();
      }
    };

    _currentTargetId = targetId;
    _currentTargetType = targetType;
    if (callId != null) {
      _currentCallId = callId;
    }
  }

  void _attemptReconnect() {
    if (_isReconnecting || _currentCallId == null) return;
    _isReconnecting = true;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _isReconnecting = false;
      if (_peerConnection == null) return;

      final state = _peerConnection?.connectionState;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        debugPrint('[VoiceCallService] 连接未能自动恢复，执行清理');
        _callEventController.add({
          'type': 'call_error',
          'data': {'message': '通话连接已断开'}
        });
        _cleanup();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        debugPrint('[VoiceCallService] 连接已自动恢复');
        _callEventController.add({
          'type': 'registered',
          'data': {'message': '通话连接已恢复'}
        });
      }
    });
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

      _realtimeService.emitWebRTCAnswer(
        targetType: data['from_type'] ?? '',
        targetId: data['from_id'] ?? '',
        answer: {
          'type': answer.type,
          'sdp': answer.sdp,
        },
        callId: data['call_id'],
      );
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
    if (_isCleaningUp) return;
    _isCleaningUp = true;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isReconnecting = false;
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
    _isCleaningUp = false;
  }

  void dispose() {
    _cleanup();
    _realtimeEventSub?.cancel();
    _callEventController.close();
  }
}
