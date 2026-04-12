import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../services/message_service.dart';

class NotificationCenterPage extends ConsumerStatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  ConsumerState<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends ConsumerState<NotificationCenterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _messages = [];
  int _unreadCount = 0;
  String _currentType = 'all';

  final List<Map<String, String>> _tabs = [
    {'key': 'all', 'label': '全部'},
    {'key': 'booking', 'label': '预订'},
    {'key': 'service', 'label': '服务'},
    {'key': 'system', 'label': '系统'},
    {'key': 'promotion', 'label': '优惠'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final type = _tabs[_tabController.index]['key']!;
    if (type != _currentType) {
      _currentType = type;
      _loadMessages();
    }
  }

  Future<void> _loadData() async {
    await Future.wait([_loadUnreadCount(), _loadMessages()]);
  }

  Future<void> _loadUnreadCount() async {
    final result = await ref.read(messageServiceProvider).getUnreadCount();
    if (result.success && mounted) {
      setState(() => _unreadCount = result.data ?? 0);
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final type = _currentType == 'all' ? null : _currentType;
      final result = await ref.read(messageServiceProvider).getMessages(type: type);
      if (result.success && mounted) {
        setState(() => _messages = result.data ?? []);
      }
    } catch (e) {
      debugPrint('鉁?messages: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(int messageId, int index) async {
    final result = await ref.read(messageServiceProvider).markAsRead(messageId);
    if (result.success && mounted) {
      setState(() {
        _messages[index]['is_read'] = true;
        _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
      });
    }
  }

  Future<void> _markAllAsRead() async {
    final result = await ref.read(messageServiceProvider).markAllAsRead();
    if (result.success && mounted) {
      setState(() {
        for (var msg in _messages) {
          msg['is_read'] = true;
        }
        _unreadCount = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已全部标记为已读'), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _deleteMessage(int messageId, int index) async {
    final result = await ref.read(messageServiceProvider).deleteMessage(messageId);
    if (result.success && mounted) {
      final wasUnread = _messages[index]['is_read'] != true;
      setState(() {
        _messages.removeAt(index);
        if (wasUnread) _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('消息已删除'), backgroundColor: AppColors.success),
      );
    }
  }

  IconData _getMessageIcon(String? type) {
    switch (type) {
      case 'booking':
        return Icons.calendar_today_rounded;
      case 'service':
        return Icons.room_service_rounded;
      case 'system':
        return Icons.info_rounded;
      case 'promotion':
        return Icons.local_offer_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getMessageIconColor(String? type) {
    switch (type) {
      case 'booking':
        return AppColors.primary;
      case 'service':
        return AppColors.info;
      case 'system':
        return AppColors.warning;
      case 'promotion':
        return AppColors.secondary;
      default:
        return AppColors.primary;
    }
  }

  String _getTypeLabel(String? type) {
    switch (type) {
      case 'booking':
        return '预订通知';
      case 'service':
        return '服务通知';
      case 'system':
        return '系统通知';
      case 'promotion':
        return '优惠活动';
      default:
        return '通知';
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';
    try {
      final date = DateTime.parse(timeStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
      if (diff.inDays < 1) return '${diff.inHours}小时前';
      if (diff.inDays < 7) return '${diff.inDays}天前';
      return DateFormat('MM-dd HH:mm').format(date);
    } catch (e) {
      return timeStr;
    }
  }

  void _showMessageDetail(Map<String, dynamic> message, int index) {
    if (message['is_read'] != true) {
      _markAsRead(message['id'] ?? 0, index);
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getMessageIconColor(message['type']).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getMessageIcon(message['type']),
                            color: _getMessageIconColor(message['type']),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getTypeLabel(message['type']),
                                style: GoogleFonts.notoSansSc(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                _formatTime(message['created_at']),
                                style: GoogleFonts.notoSansSc(
                                  fontSize: 11,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      message['title'] ?? '消息通知',
                      style: GoogleFonts.notoSansSc(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message['content'] ?? '',
                      style: GoogleFonts.notoSansSc(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        height: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
        title: Text(
          '消息中心',
          style: GoogleFonts.notoSansSc(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                '全部已读',
                style: GoogleFonts.notoSansSc(
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: GoogleFonts.notoSansSc(fontSize: 14, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.notoSansSc(fontSize: 14),
          tabAlignment: TabAlignment.start,
          tabs: _tabs.map((tab) => Tab(text: tab['label'])).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _messages.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.notifications_off_outlined,
                                  size: 64, color: AppColors.textHint),
                              const SizedBox(height: 16),
                              Text(
                                '暂无消息',
                                style: GoogleFonts.notoSansSc(
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isRead = message['is_read'] == true;
                        return _buildMessageItem(message, index, isRead);
                      },
                    ),
            ),
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> message, int index, bool isRead) {
    return Dismissible(
      key: ValueKey(message['id'] ?? index),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('删除消息'),
            content: const Text('确定要删除这条消息吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('删除'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) => _deleteMessage(message['id'] ?? 0, index),
      child: InkWell(
        onTap: () => _showMessageDetail(message, index),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : AppColors.primary.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRead ? AppColors.divider : AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getMessageIconColor(message['type']).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getMessageIcon(message['type']),
                  color: _getMessageIconColor(message['type']),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: const BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            message['title'] ?? '消息通知',
                            style: GoogleFonts.notoSansSc(
                              fontSize: 15,
                              fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                              color: isRead ? AppColors.textSecondary : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message['content'] ?? '',
                      style: GoogleFonts.notoSansSc(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getTypeLabel(message['type']),
                          style: GoogleFonts.notoSansSc(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                        Text(
                          _formatTime(message['created_at']),
                          style: GoogleFonts.notoSansSc(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
