import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../services/voice_call_service.dart';
import '../../services/room_service.dart';

class VoiceCallsPage extends ConsumerStatefulWidget {
  const VoiceCallsPage({super.key});

  @override
  ConsumerState<VoiceCallsPage> createState() => _VoiceCallsPageState();
}

class _VoiceCallsPageState extends ConsumerState<VoiceCallsPage> {
  final VoiceCallService _callService = VoiceCallService();
  bool _isOnline = false;
  String? _clientName;
  Map<String, dynamic>? _onlineStatus;
  List<Map<String, dynamic>> _callHistory = [];
  List<dynamic> _rooms = [];
  StreamSubscription? _callEventSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initCallService();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    final result = await ref.read(roomServiceProvider).getRooms(
          status: 'occupied',
          pageSize: 100,
        );
    if (result.success && mounted) {
      setState(() => _rooms = result.data ?? []);
    }
    setState(() => _isLoading = false);
  }

  void _initCallService() {
    _callService.init('reception_app');
    _callEventSubscription = _callService.callEvents.listen((event) {
      if (!mounted) return;

      switch (event['type']) {
        case 'registered':
          setState(() {
            _isOnline = true;
            _clientName = event['data']?['clientName'];
          });
          _callService.requestOnlineStatus();
          break;
        case 'online_status':
          setState(() => _onlineStatus = event['data']);
          break;
        case 'incoming_call':
          _showIncomingCallDialog(event['data']);
          break;
        case 'call_answered':
          Navigator.of(context).maybePop();
          _addToCallHistory(event['data'], 'answered');
          break;
        case 'call_rejected':
        case 'call_hungup':
          Navigator.of(context).maybePop();
          _addToCallHistory(event['data'], 'ended');
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

  void _addToCallHistory(Map<String, dynamic> callData, String status) {
    setState(() {
      _callHistory.insert(0, {
        'caller': callData['caller_name'] ?? callData['caller_id'] ?? '未知',
        'callee': callData['callee_name'] ?? callData['callee_id'] ?? '未知',
        'status': status,
        'time': DateTime.now(),
        'duration': callData['duration'] ?? 0,
      });
    });
  }

  void _showIncomingCallDialog(Map<String, dynamic> callData) {
    final callerName = callData['caller_name'] ?? callData['caller_id'] ?? '未知';
    final callId = callData['call_id'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_in_talk, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(callerName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('正在呼叫您...', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _callService.answerCall(
                        callId,
                        callData['caller_id'],
                        callData['caller_type'],
                      );
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.call),
                    label: const Text('接听'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _callService.rejectCall(callId);
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.call_end),
                    label: const Text('拒绝'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleOnlineStatus() {
    if (_isOnline) {
      _callService.unregisterClient();
      setState(() {
        _isOnline = false;
        _clientName = null;
        _onlineStatus = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已下线')),
      );
    } else {
      final userId = 'reception_${DateTime.now().millisecondsSinceEpoch}';
      _callService.registerClient(userId);
    }
  }

  Future<void> _makeCall(String calleeId, String calleeType, String calleeName) async {
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先点击上线按钮'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    _callService.startCall(calleeId, calleeType);

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
            Text('正在呼叫 $calleeName...', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            const Text('请稍候，对方即将接听', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _callService.hangup('current');
              Navigator.pop(ctx);
            },
            child: const Text('取消呼叫', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _callEventSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onlineRooms = _onlineStatus?['mobile']?.where((c) => c['type'] == 'guest_room')?.toList() ?? [];
    final onlineStaff = _onlineStatus?['web']?.where((c) => c['type'] == 'front_desk')?.toList() ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('语音通话', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _callService.requestOnlineStatus();
              _loadRooms();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatusCard(),
                _buildStatsRow(onlineRooms.length, onlineStaff.length),
                Expanded(
                  child: DefaultTabController(
                    length: 3,
                    child: Column(
                      children: [
                        const TabBar(
                          tabs: [
                            Tab(text: '客房'),
                            Tab(text: '员工'),
                            Tab(text: '通话记录'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildRoomGrid(onlineRooms),
                              _buildStaffGrid(onlineStaff),
                              _buildCallHistory(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _isOnline ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isOnline ? Icons.phone_in_talk : Icons.phone_disabled,
              color: _isOnline ? Colors.green : Colors.grey,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isOnline ? '在线' : '离线',
                  style: GoogleFonts.notoSansSc(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _isOnline ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isOnline
                      ? '身份: ${_clientName ?? '前台员工'}'
                      : '点击上线按钮开始接听呼叫',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _toggleOnlineStatus,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isOnline ? Colors.red : AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(_isOnline ? '下线' : '上线'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(int onlineRooms, int onlineStaff) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              title: '在线客房',
              value: onlineRooms.toString(),
              icon: Icons.hotel,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              title: '在线员工',
              value: onlineStaff.toString(),
              icon: Icons.people,
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              title: '今日通话',
              value: _callHistory.length.toString(),
              icon: Icons.call,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomGrid(List<dynamic> onlineRooms) {
    if (_rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hotel_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('暂无入住房间', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: _rooms.length,
      itemBuilder: (context, index) {
        final room = _rooms[index];
        final roomId = room['id'].toString();
        final isOnline = onlineRooms.any((c) => c['id'] == roomId);

        return _CallButton(
          name: '${room['room_number']}号房',
          subtitle: isOnline ? '在线' : '离线',
          icon: Icons.hotel,
          isOnline: isOnline,
          onTap: isOnline && _isOnline
              ? () => _makeCall(roomId, 'guest_room', '${room['room_number']}号房')
              : null,
        );
      },
    );
  }

  Widget _buildStaffGrid(List<dynamic> onlineStaff) {
    if (onlineStaff.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('暂无在线员工', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: onlineStaff.length,
      itemBuilder: (context, index) {
        final staff = onlineStaff[index];

        return _CallButton(
          name: staff['name'] ?? staff['id'] ?? '员工$index',
          subtitle: '在线',
          icon: Icons.person,
          isOnline: true,
          onTap: _isOnline
              ? () => _makeCall(staff['id'], 'front_desk', staff['name'] ?? '员工')
              : null,
        );
      },
    );
  }

  Widget _buildCallHistory() {
    if (_callHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('暂无通话记录', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _callHistory.length,
      itemBuilder: (context, index) {
        final call = _callHistory[index];
        final isIncoming = call['callee']?.toString().contains('reception') ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                isIncoming ? Icons.call_received : Icons.call_made,
                color: isIncoming ? Colors.green : Colors.blue,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      call['caller'] ?? '未知',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${call['time'].toString().substring(11, 16)} · ${call['status'] == 'answered' ? '已接听' : '已结束'}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (call['duration'] > 0)
                Text(
                  '${call['duration']}秒',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.notoSansSc(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.notoSansSc(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final String name;
  final String subtitle;
  final IconData icon;
  final bool isOnline;
  final VoidCallback? onTap;

  const _CallButton({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.isOnline,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isOnline ? Colors.white : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOnline ? AppColors.primary.withOpacity(0.3) : Colors.grey[300]!,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isOnline ? AppColors.primary.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isOnline ? AppColors.primary : Colors.grey,
                    size: 28,
                  ),
                ),
                if (isOnline)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isOnline ? Colors.black87 : Colors.grey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isOnline ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
