import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/ai_butler_service.dart';
import '../../services/voice_call_service.dart';

class AiButlerPage extends ConsumerStatefulWidget {
  final int? bookingId;
  final int? roomId;
  const AiButlerPage({super.key, this.bookingId, this.roomId});

  @override
  ConsumerState<AiButlerPage> createState() => _AiButlerPageState();
}

class _AiButlerPageState extends ConsumerState<AiButlerPage>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  String _currentTypingText = '';
  Timer? _typewriterTimer;
  int _typewriterIndex = 0;
  late AnimationController _pulseController;
  List<Map<String, String>> _smartSuggestions = [];
  final VoiceCallService _callService = VoiceCallService();
  StreamSubscription? _callEventSubscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadSmartSuggestions();
    _addWelcomeMessage();
    _initCallService();
  }

  void _initCallService() {
    if (widget.roomId == null) return;
    _callService.init('${widget.roomId}', clientType: 'room');
    _callEventSubscription = _callService.callEvents.listen((event) {
      if (!mounted) return;
      switch (event['type']) {
        case 'call_answered':
          Navigator.of(context).maybePop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('前台已接听'), backgroundColor: AppColors.success),
          );
          break;
        case 'call_rejected':
        case 'call_hungup':
          Navigator.of(context).maybePop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('通话已结束')),
          );
          break;
        case 'call_error':
          final message = event['data']?['message'] ?? '呼叫失败';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: AppColors.error),
          );
          break;
      }
    });
  }

  void _addWelcomeMessage() {
    _messages.add(_ChatMessage(
      text: '您好！我是您的AI智能管家 🤖\n\n我可以帮您：\n• 控制房间设备\n• 预订客房服务\n• 联系前台\n• 办理退房/续住\n\n请问有什么可以帮您的？',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _loadSmartSuggestions() async {
    final result = await ref.read(aiButlerServiceProvider).getSmartSuggestions();
    if (result.success && result.data != null) {
      final suggestions = result.data!['suggestions'];
      if (suggestions is List) {
        setState(() {
          _smartSuggestions = suggestions
              .map((s) => {
                    'icon': s['icon']?.toString() ?? '💡',
                    'text': s['text']?.toString() ?? '',
                    'action': s['action']?.toString() ?? '',
                  })
              .toList();
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    _typewriterTimer?.cancel();
    _callEventSubscription?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    _messageController.clear();
    _typewriterTimer?.cancel();

    setState(() {
      _messages.add(_ChatMessage(
        text: text.trim(),
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
      _currentTypingText = '';
    });
    _scrollToBottom();

    try {
      final result = await ref.read(aiButlerServiceProvider).sendMessage(
            text.trim(),
            roomId: widget.roomId,
            context: widget.bookingId != null ? 'booking_${widget.bookingId}' : null,
          );

      if (!mounted) return;

      String reply;
      List<Map<String, String>>? quickActions;
      String? action;
      String? target;

      if (result.success && result.data != null) {
        reply = result.data!['reply']?.toString() ?? result.data!['message']?.toString() ?? '抱歉，我暂时无法理解您的问题。';
        action = result.data!['action']?.toString();
        target = result.data!['target']?.toString();
        final actions = result.data!['quick_actions'] ?? result.data!['actions'];
        if (actions is List) {
          quickActions = actions.map((a) => {
            'label': a['label']?.toString() ?? a['text']?.toString() ?? '',
            'action': a['action']?.toString() ?? '',
          }).toList();
        }
      } else {
        reply = result.message ?? '服务暂时不可用，请稍后再试。';
      }

      setState(() => _isLoading = false);
      _startTypewriterEffect(reply, quickActions: quickActions);

      if (action == 'transfer' && target == 'front_desk') {
        _handleTransferToFrontDesk();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _startTypewriterEffect('抱歉，服务暂时不可用。您可以尝试联系前台获取帮助。');
      }
    }
  }

  void _handleTransferToFrontDesk() {
    if (widget.roomId == null) {
      context.push('/room-service', extra: {'bookingId': widget.bookingId, 'initialTab': 3});
      return;
    }

    _callService.startCall('all', 'front_desk');

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('正在转接前台...', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              const Text('AI管家正在为您呼叫前台', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final callId = _callService.currentCallId;
                if (callId != null) _callService.hangup(callId);
                Navigator.pop(ctx);
              },
              child: const Text('取消', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
    }
  }

  void _startTypewriterEffect(String fullText, {List<Map<String, String>>? quickActions}) {
    setState(() {
      _typewriterIndex = 0;
      _currentTypingText = '';
      _messages.add(_ChatMessage(
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
        quickActions: quickActions,
        isTyping: true,
      ));
    });
    _scrollToBottom();

    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_typewriterIndex < fullText.length) {
        setState(() {
          _typewriterIndex++;
          _currentTypingText = fullText.substring(0, _typewriterIndex);
          if (_messages.isNotEmpty && _messages.last.isTyping) {
            _messages[_messages.length - 1] = _ChatMessage(
              text: _currentTypingText,
              isUser: false,
              timestamp: DateTime.now(),
              quickActions: quickActions,
              isTyping: true,
            );
          }
        });
        _scrollToBottom();
      } else {
        timer.cancel();
        setState(() {
          if (_messages.isNotEmpty && _messages.last.isTyping) {
            _messages[_messages.length - 1] = _ChatMessage(
              text: fullText,
              isUser: false,
              timestamp: DateTime.now(),
              quickActions: quickActions,
              isTyping: false,
            );
          }
        });
      }
    });
  }

  void _handleQuickAction(String action) {
    switch (action) {
      case 'light_on':
      case 'light_off':
      case 'light_reading':
      case 'device_control':
      case 'device':
        context.push('/room-service', extra: {'bookingId': widget.bookingId});
        break;
      case 'ac_26':
      case 'ac_cool':
      case 'ac_low':
        context.push('/room-service', extra: {'bookingId': widget.bookingId});
        break;
      case 'room_service':
      case 'service':
      case 'recommend':
        context.push('/room-service', extra: {'bookingId': widget.bookingId, 'initialTab': 2});
        break;
      case 'call_front_desk':
      case 'front_desk':
      case 'transfer':
      case 'call':
        context.push('/room-service', extra: {'bookingId': widget.bookingId, 'initialTab': 3});
        break;
      case 'checkout':
        if (widget.bookingId != null) {
          context.push('/checkout/${widget.bookingId}', extra: {'bookingId': widget.bookingId});
        }
        break;
      case 'extend':
        if (widget.bookingId != null) {
          context.push('/extend-stay/${widget.bookingId}', extra: {'bookingId': widget.bookingId});
        }
        break;
      case 'housekeeping':
        _sendMessage('我需要预约清洁服务');
        break;
      default:
        _sendMessage(action);
    }
  }

  void _startVoiceInput() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('语音输入功能开发中，敬请期待'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF30CFD0)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI智能管家', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) => Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.success.withValues(alpha: _pulseController.value * 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('在线', style: TextStyle(color: AppColors.success, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_outlined, color: AppColors.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          if (_smartSuggestions.isNotEmpty) _buildSmartSuggestions(),
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildSmartSuggestions() {
    return Container(
      height: 50,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _smartSuggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _smartSuggestions[index];
          return GestureDetector(
            onTap: () => _handleQuickAction(suggestion['action'] ?? ''),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Text(suggestion['icon'] ?? '', style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(suggestion['text'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isLoading) {
          return _buildTypingIndicator();
        }
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF30CFD0)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(150),
                const SizedBox(width: 4),
                _buildDot(300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int delay) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final offset = (delay / 1000.0);
        final value = ((_pulseController.value + offset) % 1.0);
        final scale = 0.5 + 0.5 * (value < 0.5 ? value * 2 : 2 - value * 2);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    if (message.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16, left: 48),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF30CFD0)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(message.text, style: const TextStyle(color: Colors.white, fontSize: 14)),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 48),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF30CFD0)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.5),
                      ),
                      if (message.isTyping)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 2),
                            Container(
                              width: 2,
                              height: 14,
                              color: AppColors.primary,
                              margin: const EdgeInsets.only(left: 1),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (message.quickActions != null && message.quickActions!.isNotEmpty && !message.isTyping)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: message.quickActions!.map((action) {
                        return ActionChip(
                          label: Text(action['label'] ?? '', style: const TextStyle(fontSize: 12)),
                          backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                          labelStyle: const TextStyle(color: AppColors.primary),
                          onPressed: () => _handleQuickAction(action['action'] ?? ''),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.mic_outlined, color: AppColors.primary, size: 28),
            onPressed: _startVoiceInput,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
                decoration: InputDecoration(
                  hintText: '问我任何问题...',
                  hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.primary, size: 20),
                    onPressed: () => _sendMessage(_messageController.text),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<Map<String, String>>? quickActions;
  final bool isTyping;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.quickActions,
    this.isTyping = false,
  });
}
