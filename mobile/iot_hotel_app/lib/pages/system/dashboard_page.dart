import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/auth/auth_state_notifier.dart';
import '../../services/auth_service.dart';

class SystemDashboardPage extends ConsumerStatefulWidget {
  const SystemDashboardPage({super.key});

  @override
  ConsumerState<SystemDashboardPage> createState() => _SystemDashboardPageState();
}

class _SystemDashboardPageState extends ConsumerState<SystemDashboardPage> {
  int _selectedIndex = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.dashboard_rounded, label: '概览'),
    _NavItem(icon: Icons.hotel_rounded, label: '酒店'),
    _NavItem(icon: Icons.devices_rounded, label: '设备'),
    _NavItem(icon: Icons.people_rounded, label: '账户'),
    _NavItem(icon: Icons.fact_check_rounded, label: '审核'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _OverviewTab(),
      const _HotelsTab(),
      const _DevicesTab(),
      const _UsersTab(),
      const _ReviewTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('智联酒店 - 系统管理', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.notifications_rounded), onPressed: () {}),
          PopupMenuButton<String>(
            icon: const CircleAvatar(radius: 16, backgroundColor: Colors.white, child: Icon(Icons.person, size: 18, color: AppColors.primary)),
            onSelected: (value) async {
              if (value == 'logout') {
                await ref.read(authServiceProvider).logout();
                if (mounted) context.go('/login');
              } else if (value == 'switch_mode') {
                _showModeSwitchDialog();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'switch_mode', child: Row(children: [Icon(Icons.swap_horiz), SizedBox(width: 8), Text('切换模式')])),
              const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout), SizedBox(width: 8), Text('退出登录')])),
            ],
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: _navItems.map((n) => BottomNavigationBarItem(icon: Icon(n.icon), label: n.label)).toList(),
      ),
    );
  }

  void _showModeSwitchDialog() {
    final authState = ref.read(authStateProvider);
    final modes = <AppMode, String>{
      AppMode.customer: '顾客端',
      AppMode.reception: '前台端',
      AppMode.manager: '管理端',
      AppMode.guest: '游客端',
    };

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('切换模式'),
        children: modes.entries.where((e) => authState.canSwitchTo(e.key)).map((e) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authStateProvider.notifier).switchMode(e.key);
              _navigateToMode(e.key);
            },
            child: Row(children: [Icon(_modeIcon(e.key), color: AppColors.primary), const SizedBox(width: 12), Text(e.value, style: const TextStyle(fontSize: 16))]),
          );
        }).toList(),
      ),
    );
  }

  IconData _modeIcon(AppMode mode) {
    switch (mode) {
      case AppMode.guest: return Icons.visibility_outlined;
      case AppMode.customer: return Icons.person_outline;
      case AppMode.reception: return Icons.support_agent_outlined;
      case AppMode.manager: return Icons.admin_panel_settings_outlined;
      case AppMode.system: return Icons.security_outlined;
    }
  }

  void _navigateToMode(AppMode mode) {
    switch (mode) {
      case AppMode.guest:
      case AppMode.customer:
        context.go('/');
        break;
      case AppMode.reception:
        context.go('/reception');
        break;
      case AppMode.manager:
        context.go('/admin');
        break;
      case AppMode.system:
        context.go('/system');
        break;
    }
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _OverviewTab extends ConsumerStatefulWidget {
  const _OverviewTab();
  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final dio = DioClient();
      final hotelRes = await dio.get('${ApiConstants.hotels}search');
      int hotelCount = 0;
      if (hotelRes.statusCode == 200 && hotelRes.data['code'] == 200) {
        hotelCount = (hotelRes.data['data']?['hotels'] as List?)?.length ?? 0;
      }
      final userRes = await dio.get(ApiConstants.users);
      int userCount = 0;
      if (userRes.statusCode == 200 && userRes.data['code'] == 200) {
        final data = userRes.data['data'];
        userCount = (data is List) ? data.length : (data?['list'] as List?)?.length ?? 0;
      }
      final deviceRes = await dio.get(ApiConstants.devices);
      int deviceCount = 0;
      if (deviceRes.statusCode == 200 && deviceRes.data['code'] == 200) {
        final data = deviceRes.data['data'];
        deviceCount = (data is List) ? data.length : (data?['list'] as List?)?.length ?? 0;
      }
      if (mounted) setState(() => _stats = {'hotels': hotelCount, 'users': userCount, 'devices': deviceCount});
    } catch (e) {
      debugPrint('Error loading system stats: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('系统概览', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(children: [
          _statCard('酒店总数', _stats['hotels'] ?? 0, Icons.hotel, AppColors.primary),
          const SizedBox(width: 12),
          _statCard('用户总数', _stats['users'] ?? 0, Icons.people, AppColors.secondary),
          const SizedBox(width: 12),
          _statCard('设备总数', _stats['devices'] ?? 0, Icons.devices, AppColors.success),
        ]),
        const SizedBox(height: 24),
        const Text('快捷操作', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _quickAction(Icons.add_business, '新增酒店', () => context.push('/system/hotel-add')),
        _quickAction(Icons.person_add, '新增用户', () => context.push('/system/user-add')),
      ]),
    );
  }

  Widget _statCard(String title, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)]),
        child: Column(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) {
    return ListTile(leading: Icon(icon, color: AppColors.primary), title: Text(label), trailing: const Icon(Icons.chevron_right), onTap: onTap);
  }
}

class _HotelsTab extends StatefulWidget {
  const _HotelsTab();
  @override
  State<_HotelsTab> createState() => _HotelsTabState();
}

class _HotelsTabState extends State<_HotelsTab> {
  List<Map<String, dynamic>> _hotels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHotels();
  }

  Future<void> _loadHotels() async {
    try {
      final dio = DioClient();
      final res = await dio.get('${ApiConstants.hotels}search');
      if (res.statusCode == 200 && res.data['code'] == 200) {
        setState(() => _hotels = List<Map<String, dynamic>>.from(res.data['data']?['hotels'] ?? []));
      }
    } catch (e) {
      debugPrint('Error loading hotels: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _loadHotels,
      child: _hotels.isEmpty
          ? const Center(child: Text('暂无酒店'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _hotels.length,
              itemBuilder: (ctx, i) {
                final h = _hotels[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: 0.1), child: const Icon(Icons.hotel, color: AppColors.primary)),
                    title: Text(h['name'] ?? '未知酒店', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(h['location'] ?? ''),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('${h['star'] ?? 3}星', style: const TextStyle(color: AppColors.warning, fontSize: 12)),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}

class _DevicesTab extends StatefulWidget {
  const _DevicesTab();
  @override
  State<_DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<_DevicesTab> {
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      final dio = DioClient();
      final res = await dio.get(ApiConstants.devices);
      if (res.statusCode == 200 && res.data['code'] == 200) {
        final data = res.data['data'];
        setState(() => _devices = List<Map<String, dynamic>>.from(data is List ? data : (data?['list'] ?? [])));
      }
    } catch (e) {
      debugPrint('Error loading devices: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _loadDevices,
      child: _devices.isEmpty
          ? const Center(child: Text('暂无设备'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _devices.length,
              itemBuilder: (ctx, i) {
                final d = _devices[i];
                final status = d['status'] ?? d['device_status'] ?? 'unknown';
                Color statusColor;
                switch (status) {
                  case 'online': statusColor = AppColors.success; break;
                  case 'offline': statusColor = AppColors.textHint; break;
                  default: statusColor = AppColors.warning;
                }
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(Icons.devices, color: statusColor),
                    title: Text(d['device_name'] ?? d['name'] ?? '设备${d['id']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('ID: ${d['id']} | ${d['device_type'] ?? ''}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final dio = DioClient();
      final res = await dio.get(ApiConstants.users);
      if (res.statusCode == 200 && res.data['code'] == 200) {
        final data = res.data['data'];
        setState(() => _users = List<Map<String, dynamic>>.from(data is List ? data : (data?['list'] ?? [])));
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'system': return AppColors.error;
      case 'admin': case 'manager': return AppColors.primary;
      case 'staff': return AppColors.secondary;
      default: return AppColors.success;
    }
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'system': return '系统管理员';
      case 'admin': case 'manager': return '酒店经理';
      case 'staff': return '前台员工';
      case 'user': return '顾客';
      default: return '游客';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: _users.isEmpty
          ? const Center(child: Text('暂无用户'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (ctx, i) {
                final u = _users[i];
                final role = u['role'] ?? 'user';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: _roleColor(role).withValues(alpha: 0.1), child: Icon(Icons.person, color: _roleColor(role))),
                    title: Text(u['username'] ?? '未知', style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(u['email'] ?? u['phone'] ?? ''),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: _roleColor(role).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Text(_roleLabel(role), style: TextStyle(color: _roleColor(role), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ReviewTab extends StatefulWidget {
  const _ReviewTab();
  @override
  State<_ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<_ReviewTab> {
  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    try {
      final dio = DioClient();
      final res = await dio.get(ApiConstants.authRoleApplications);
      if (res.statusCode == 200 && res.data['code'] == 200) {
        setState(() => _applications = List<Map<String, dynamic>>.from(res.data['data'] ?? []));
      }
    } catch (e) {
      debugPrint('Error loading applications: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reviewApplication(int id, String status, {String? note}) async {
    try {
      final dio = DioClient();
      final res = await dio.put('${ApiConstants.authRoleApplications}/$id/review', data: {
        'status': status,
        if (note != null) 'review_note': note,
      });
      if (res.statusCode == 200 && res.data['code'] == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'approved' ? '已通过' : '已拒绝'), backgroundColor: AppColors.success));
          _loadApplications();
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.data['message'] ?? '操作失败')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作异常：$e')));
    }
  }

  void _showReviewDialog(Map<String, dynamic> app) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('审核申请 #${app['id']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('申请人: ${app['username'] ?? '-'}'),
            Text('类型: ${app['application_type'] == 'create_hotel' ? '创建酒店' : '绑定员工'}'),
            if (app['hotel_name'] != null) Text('酒店名: ${app['hotel_name']}'),
            if (app['hotel_address'] != null) Text('酒店地址: ${app['hotel_address']}'),
            if (app['reason'] != null) Text('理由: ${app['reason']}'),
            const SizedBox(height: 12),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: '审核备注 (可选)'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _reviewApplication(app['id'], 'rejected', note: noteCtrl.text.trim()); },
            child: const Text('拒绝', style: TextStyle(color: AppColors.error)),
          ),
          FilledButton(
            onPressed: () { Navigator.pop(ctx); _reviewApplication(app['id'], 'approved', note: noteCtrl.text.trim()); },
            child: const Text('通过'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final pendingApps = _applications.where((a) => a['status'] == 'pending').toList();
    final reviewedApps = _applications.where((a) => a['status'] != 'pending').toList();

    return RefreshIndicator(
      onRefresh: _loadApplications,
      child: DefaultTabController(
        length: 2,
        child: Column(children: [
          const TabBar(tabs: [Tab(text: '待审核'), Tab(text: '已审核')]),
          Expanded(child: TabBarView(children: [
            _buildAppList(pendingApps, showActions: true),
            _buildAppList(reviewedApps, showActions: false),
          ])),
        ]),
      ),
    );
  }

  Widget _buildAppList(List<Map<String, dynamic>> apps, {required bool showActions}) {
    if (apps.isEmpty) return const Center(child: Text('暂无数据'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: apps.length,
      itemBuilder: (ctx, i) {
        final app = apps[i];
        final status = app['status'] ?? 'pending';
        Color statusColor;
        String statusText;
        switch (status) {
          case 'approved': statusColor = AppColors.success; statusText = '已通过'; break;
          case 'rejected': statusColor = AppColors.error; statusText = '已拒绝'; break;
          default: statusColor = AppColors.warning; statusText = '待审核';
        }
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(app['application_type'] == 'create_hotel' ? Icons.add_business : Icons.badge, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(app['application_type'] == 'create_hotel' ? '创建酒店: ${app['hotel_name'] ?? '-'}' : '绑定员工: ${app['target_hotel_name'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 8),
              Text('申请人: ${app['username'] ?? '-'} | 时间: ${app['created_at']?.toString().substring(0, 10) ?? '-'}'),
              if (app['reason'] != null) Text('理由: ${app['reason']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              if (showActions) ...[
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  OutlinedButton(onPressed: () => _showReviewDialog(app), style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary), child: const Text('审核')),
                ]),
              ],
            ]),
          ),
        );
      },
    );
  }
}
