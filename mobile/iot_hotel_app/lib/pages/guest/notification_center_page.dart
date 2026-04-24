import 'package:flutter/material.dart' hide DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/utils/date_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/notification_provider.dart';
import '../../services/message_service.dart';
import '../../models/app_notification.dart';

class NotificationCenterPage extends ConsumerStatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  ConsumerState<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends ConsumerState<NotificationCenterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<AppNotification> _apiMessages = [];
  String _currentType = 'all';

  final List<Map<String, String>> _tabs = [
    {'key': 'all', 'label': '全部'},
    {'key': 'alarm', 'label': '告警'},
    {'key': 'security', 'label': '安防'},
    {'key': 'call', 'label': '通话'},
    {'key': 'service', 'label': '服务'},
    {'key': 'system', 'label': '系统'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadApiMessages();
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
      setState(() => _currentType = type);
    }
  }

  Future<void> _loadApiMessages() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(messageServiceProvider).getMessages();
      if (result.success && mounted) {
        final data = result.data;
        if (data is List) {
          setState(() => _apiMessages = data.map((m) => AppNotification.fromJson(m as Map<String, dynamic>)).toList());
        }
      }
    } catch (e) {
      debugPrint('load messages: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(int messageId, int index) async {
    final result = await ref.read(messageServiceProvider).markAsRead(messageId);
    if (result.success && mounted) {
      setState(() => _apiMessages[index] = _apiMessages[index].copyWith(isRead: true));
    }
  }

  Future<void> _markAllAsRead() async {
    ref.read(realtimeNotificationProvider.notifier).markAllAsRead();
    final result = await ref.read(messageServiceProvider).markAllAsRead();
    if (result.success && mounted) {
      setState(() => _apiMessages = _apiMessages.map((m) => m.copyWith(isRead: true)).toList());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已全部标记为已读'), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _deleteMessage(int messageId, int index) async {
    final result = await ref.read(messageServiceProvider).deleteMessage(messageId);
    if (result.success && mounted) {
      setState(() => _apiMessages.removeAt(index));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('消息已删除'), backgroundColor: AppColors.success),
      );
    }
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    try {
      final localTime = time.toLocal();
      final now = DateTime.now();
      final diff = now.difference(localTime);
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
      if (diff.inDays < 1) return '${diff.inHours}小时前';
      if (diff.inDays < 7) return '${diff.inDays}天前';
      return DateUtils.formatDateTime(time);
    } catch (e) {
      return '';
    }
  }

  void _showMessageDetail(AppNotification message, {int? apiIndex}) {
    if (!message.isRead) {
      if (apiIndex != null) {
        _markAsRead(message.id, apiIndex);
      } else {
        ref.read(realtimeNotificationProvider.notifier).markAsRead(message.id);
      }
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
                            color: message.typeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(message.typeIcon, color: message.typeColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(message.typeLabel, style: GoogleFonts.notoSansSc(fontSize: 12, color: AppColors.textSecondary)),
                              Text(_formatTime(message.createdAt), style: GoogleFonts.notoSansSc(fontSize: 11, color: AppColors.textHint)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(message.title, style: GoogleFonts.notoSansSc(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text(message.content, style: GoogleFonts.notoSansSc(fontSize: 15, color: AppColors.textPrimary, height: 1.8)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<AppNotification> get _filteredNotifications {
    final realtimeNotifs = ref.watch(realtimeNotificationProvider).notifications;
    final all = [...realtimeNotifs, ..._apiMessages];
    final seen = <int>{};
    final deduped = <AppNotification>[];
    for (final n in all) {
      if (!seen.contains(n.id)) {
        seen.add(n.id);
        deduped.add(n);
      }
    }
    deduped.sort((a, b) => (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970)));
    if (_currentType == 'all') return deduped;
    return deduped.where((n) => n.type == _currentType).toList();
  }

  int get _totalUnread {
    final realtimeUnread = ref.watch(realtimeNotificationProvider).unreadCount;
    final apiUnread = _apiMessages.where((m) => !m.isRead).length;
    return realtimeUnread + apiUnread;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotifications;
    final totalUnread = _totalUnread;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '消息中心',
          style: GoogleFonts.notoSansSc(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        centerTitle: true,
        actions: [
          if (totalUnread > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text('全部已读', style: GoogleFonts.notoSansSc(fontSize: 14, color: AppColors.primary)),
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
          tabs: _tabs.map((tab) {
            final key = tab['key']!;
            final count = key == 'all'
                ? totalUnread
                : filtered.where((n) => n.type == key && !n.isRead).length;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tab['label']!),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.white)),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadApiMessages,
              child: filtered.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.notifications_off_outlined, size: 64, color: AppColors.textHint),
                              const SizedBox(height: 16),
                              Text('暂无消息', style: GoogleFonts.notoSansSc(fontSize: 16, color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              Text('实时通知将自动推送到这里', style: GoogleFonts.notoSansSc(fontSize: 13, color: AppColors.textHint)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final message = filtered[index];
                        final apiIndex = _apiMessages.indexWhere((m) => m.id == message.id);
                        return _buildMessageItem(message, apiIndex: apiIndex >= 0 ? apiIndex : null);
                      },
                    ),
            ),
    );
  }

  Widget _buildMessageItem(AppNotification message, {int? apiIndex}) {
    return Dismissible(
      key: ValueKey(message.id),
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
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('删除'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        if (apiIndex != null) {
          _deleteMessage(message.id, apiIndex);
        } else {
          ref.read(realtimeNotificationProvider.notifier).removeNotification(message.id);
        }
      },
      child: InkWell(
        onTap: () => _showMessageDetail(message, apiIndex: apiIndex),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: message.isRead ? Colors.white : message.typeColor.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: message.isRead ? AppColors.divider : message.typeColor.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: message.typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(message.typeIcon, color: message.typeColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!message.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: message.type == 'alarm' || message.type == 'security'
                                  ? AppColors.error
                                  : AppColors.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            message.title,
                            style: GoogleFonts.notoSansSc(
                              fontSize: 15,
                              fontWeight: message.isRead ? FontWeight.w500 : FontWeight.bold,
                              color: message.isRead ? AppColors.textSecondary : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message.content,
                      style: GoogleFonts.notoSansSc(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: message.typeColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            message.typeLabel,
                            style: GoogleFonts.notoSansSc(fontSize: 10, color: message.typeColor),
                          ),
                        ),
                        Text(
                          _formatTime(message.createdAt),
                          style: GoogleFonts.notoSansSc(fontSize: 11, color: AppColors.textHint),
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
