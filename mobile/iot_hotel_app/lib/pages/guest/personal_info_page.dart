import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/auth/auth_state_notifier.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';

class PersonalInfoPage extends ConsumerStatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  ConsumerState<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends ConsumerState<PersonalInfoPage> {
  User? _user;
  List<Map<String, dynamic>> _applications = [];
  List<Map<String, dynamic>> _hotels = [];
  List<Map<String, dynamic>> _allHotels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await ref.read(authServiceProvider).getCurrentUser();
    if (!mounted) return;
    setState(() => _user = user);

    try {
      final dio = DioClient();
      final meResponse = await dio.get(ApiConstants.authMe);
      if (meResponse.statusCode == 200 && meResponse.data['code'] == 200) {
        final data = meResponse.data['data'];
        if (data['managed_hotels'] != null) {
          setState(() => _hotels = List<Map<String, dynamic>>.from(data['managed_hotels']));
        }
      }

      final appResponse = await dio.get('${ApiConstants.baseUrl}auth/role-applications');
      if (appResponse.statusCode == 200 && appResponse.data['code'] == 200) {
        setState(() => _applications = List<Map<String, dynamic>>.from(appResponse.data['data'] ?? []));
      }

      final hotelResponse = await dio.get(ApiConstants.hotels, queryParameters: {'pageSize': 100});
      if (hotelResponse.statusCode == 200 && hotelResponse.data['code'] == 200) {
        final list = hotelResponse.data['data']?['list'] ?? hotelResponse.data['data'] ?? [];
        setState(() => _allHotels = List<Map<String, dynamic>>.from(list));
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('个人信息'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileCard(authState),
                  const SizedBox(height: 16),
                  _buildRoleCard(authState),
                  const SizedBox(height: 16),
                  _buildHotelBindingSection(authState),
                  const SizedBox(height: 16),
                  _buildApplicationsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard(AuthState authState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('基本信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildInfoRow('用户名', _user?.username ?? '-'),
          _buildInfoRow('UID', _user?.uid ?? '-'),
          _buildInfoRow('手机号', _user?.phone ?? '-'),
          _buildInfoRow('邮箱', _user?.email ?? '-'),
          _buildInfoRow('角色', _roleLabel(_user?.role)),
          _buildInfoRow('注册时间', _user?.createdAt?.toString().substring(0, 10) ?? '-'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'manager': return '酒店经理 (管理端)';
      case 'staff': return '前台员工 (前台端)';
      case 'user': return '顾客';
      case 'admin': return '系统管理员';
      case 'system': return '系统管理员';
      default: return '游客';
    }
  }

  Widget _buildRoleCard(AuthState authState) {
    final roleLevel = authState.roleLevel;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('权限等级', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildRoleLevelRow(0, '游客', '浏览酒店和房型', roleLevel >= 0),
          _buildRoleLevelRow(1, '顾客', '预订、入住、客房服务', roleLevel >= 1),
          _buildRoleLevelRow(2, '前台员工', '前台接待、客房管理', roleLevel >= 2),
          _buildRoleLevelRow(3, '酒店经理', '酒店管理、数据报表', roleLevel >= 3),
          const SizedBox(height: 8),
          Text(
            roleLevel < 2 ? '如需升级权限，请在下方申请酒店创建或员工绑定' : '您当前可使用以下端：${_availableModes(roleLevel)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleLevelRow(int level, String title, String desc, bool unlocked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(unlocked ? Icons.lock_open_outlined : Icons.lock_outline, size: 16, color: unlocked ? AppColors.success : AppColors.textHint),
          const SizedBox(width: 8),
          Text('Lv.$level $title', style: TextStyle(fontSize: 13, fontWeight: unlocked ? FontWeight.bold : FontWeight.normal, color: unlocked ? AppColors.textPrimary : AppColors.textHint)),
          const SizedBox(width: 8),
          Text('- $desc', style: TextStyle(fontSize: 12, color: unlocked ? AppColors.textSecondary : AppColors.textHint)),
        ],
      ),
    );
  }

  String _availableModes(int level) {
    final modes = ['游客端'];
    if (level >= 1) modes.add('顾客端');
    if (level >= 2) modes.add('前台端');
    if (level >= 3) modes.add('管理端');
    return modes.join('、');
  }

  Widget _buildHotelBindingSection(AuthState authState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('酒店绑定', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_hotels.isNotEmpty) ...[
            ..._hotels.map((h) => ListTile(
              leading: const Icon(Icons.hotel_outlined, color: AppColors.primary),
              title: Text(h['hotel_name'] ?? '未知酒店'),
              subtitle: Text('酒店ID: ${h['id']}'),
              dense: true,
            )),
            const Divider(),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showCreateHotelDialog(),
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('申请创建酒店 (升级为管理端)'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showBindEmployeeDialog(),
              icon: const Icon(Icons.badge_outlined),
              label: const Text('申请绑定酒店员工 (升级为前台端)'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.secondary, side: const BorderSide(color: AppColors.secondary)),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateHotelDialog() {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('申请创建酒店'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: '酒店名称', prefixIcon: Icon(Icons.hotel_outlined)), validator: (v) => v!.isEmpty ? '请输入酒店名称' : null),
              const SizedBox(height: 12),
              TextFormField(controller: addrCtrl, decoration: const InputDecoration(labelText: '酒店地址', prefixIcon: Icon(Icons.location_on_outlined)), validator: (v) => v!.isEmpty ? '请输入酒店地址' : null),
              const SizedBox(height: 12),
              TextFormField(controller: reasonCtrl, decoration: const InputDecoration(labelText: '申请理由 (可选)', prefixIcon: Icon(Icons.description_outlined)), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              await _submitApplication('create_hotel', hotelName: nameCtrl.text.trim(), hotelAddress: addrCtrl.text.trim(), reason: reasonCtrl.text.trim());
            },
            child: const Text('提交申请'),
          ),
        ],
      ),
    );
  }

  void _showBindEmployeeDialog() {
    final reasonCtrl = TextEditingController();
    int? selectedHotelId;

    if (_allHotels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无可选酒店，请稍后再试')));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('申请绑定酒店员工'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedHotelId,
                    decoration: const InputDecoration(
                      labelText: '选择酒店',
                      prefixIcon: Icon(Icons.hotel_outlined),
                      hintText: '请选择要绑定的酒店',
                    ),
                    items: _allHotels.map((h) => DropdownMenuItem<int>(
                      value: h['id'] as int,
                      child: Text(h['hotel_name'] ?? '酒店${h['id']}', overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setDialogState(() => selectedHotelId = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: reasonCtrl, decoration: const InputDecoration(labelText: '申请理由 (可选)', prefixIcon: Icon(Icons.description_outlined)), maxLines: 2),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                FilledButton(
                  onPressed: () async {
                    if (selectedHotelId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择酒店')));
                      return;
                    }
                    Navigator.pop(ctx);
                    await _submitApplication('bind_employee', hotelId: selectedHotelId, reason: reasonCtrl.text.trim());
                  },
                  child: const Text('提交申请'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitApplication(String type, {int? hotelId, String? hotelName, String? hotelAddress, String? reason}) async {
    try {
      final dio = DioClient();
      final response = await dio.post('${ApiConstants.baseUrl}auth/role-application', data: {
        'application_type': type,
        if (hotelId != null) 'hotel_id': hotelId,
        if (hotelName != null) 'hotel_name': hotelName,
        if (hotelAddress != null) 'hotel_address': hotelAddress,
        'reason': reason?.isNotEmpty == true ? reason : null,
      });

      if (response.statusCode == 200 && response.data['code'] == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('申请已提交，请等待审核'), backgroundColor: AppColors.success));
          _loadData();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.data['message'] ?? '提交失败')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('提交异常：$e')));
      }
    }
  }

  Widget _buildApplicationsSection() {
    if (_applications.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('我的申请', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._applications.map((app) {
            final type = app['application_type'] as String? ?? '';
            final status = app['status'] as String? ?? 'pending';
            final createdAt = app['created_at']?.toString().substring(0, 10) ?? '-';

            Color statusColor;
            String statusText;
            switch (status) {
              case 'approved':
                statusColor = AppColors.success;
                statusText = '已通过';
                break;
              case 'rejected':
                statusColor = AppColors.error;
                statusText = '已拒绝';
                break;
              default:
                statusColor = AppColors.warning;
                statusText = '待审核';
            }

            return ListTile(
              leading: Icon(type == 'create_hotel' ? Icons.add_business_outlined : Icons.badge_outlined, color: AppColors.primary),
              title: Text(type == 'create_hotel' ? '创建酒店: ${app['hotel_name'] ?? '-'}' : '绑定员工: ${app['target_hotel_name'] ?? '-'}'),
              subtitle: Text('申请时间: $createdAt'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              dense: true,
            );
          }),
        ],
      ),
    );
  }
}
