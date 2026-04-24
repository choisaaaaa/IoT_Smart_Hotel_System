import 'package:flutter/material.dart' hide DateUtils;
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/date_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../core/auth/auth_state_notifier.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../services/auth_service.dart';
import '../../models/role_application.dart';
import '../../models/hotel.dart';
import '../../models/user.dart';

class PersonalInfoPage extends ConsumerStatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  ConsumerState<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends ConsumerState<PersonalInfoPage> {
  User? _user;
  List<RoleApplication> _applications = [];
  List<Hotel> _hotels = [];
  List<Hotel> _allHotels = [];
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

    final dio = DioClient();

    try {
      final meResponse = await dio.get(ApiConstants.authMe);
      if (meResponse.statusCode == 200 && meResponse.data['code'] == 200) {
        final data = meResponse.data['data'];
        if (data['managed_hotels'] != null) {
          setState(() => _hotels = List<Map<String, dynamic>>.from(data['managed_hotels']).map((h) => Hotel.fromJson(h)).toList());
        }
      }
    } catch (e) {
      debugPrint('managedHotels: $e');
    }

    try {
      final appResponse = await dio.get(ApiConstants.authRoleApplications);
      if (appResponse.statusCode == 200 && appResponse.data['code'] == 200) {
        setState(() => _applications = List<Map<String, dynamic>>.from(appResponse.data['data'] ?? []).map((a) => RoleApplication.fromJson(a)).toList());
      }
    } catch (e) {
      debugPrint('applications: $e');
    }

    try {
      final hotelResponse = await dio.get('${ApiConstants.hotels}/search');
      if (hotelResponse.statusCode == 200 && hotelResponse.data['code'] == 200) {
        final list = hotelResponse.data['data']?['hotels'] ?? hotelResponse.data['data'] ?? [];
        setState(() => _allHotels = List<Map<String, dynamic>>.from(list).map((h) => Hotel.fromJson(h)).toList());
      }
    } catch (e) {
      debugPrint('hotelList: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('个人信息', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
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
                  _buildEditableInfoCard(),
                  const SizedBox(height: 16),
                  _buildRoleCard(authState),
                  const SizedBox(height: 16),
                  _buildHotelBindingSection(authState),
                  const SizedBox(height: 16),
                  _buildApplicationsSection(),
                  const SizedBox(height: 16),
                  _buildPasswordSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard(AuthState authState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _showAvatarPicker,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Text(
                        (_user?.username ?? '?')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 1),
                        ),
                        child: const Icon(Icons.camera_alt, size: 12, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _user?.username ?? '未登录',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'UID: ${_user?.uid ?? '-'}',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _roleLabel(_user?.role),
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditableInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('基本信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: _showEditProfileDialog,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('编辑'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('用户名', _user?.username ?? '-'),
          _buildInfoRow('UID', _user?.uid ?? '-'),
          _buildInfoRow('手机号', _user?.phone ?? '-', onTap: _showEditPhoneDialog),
          _buildInfoRow('邮箱', _user?.email ?? '-', onTap: _showEditEmailDialog),
          _buildInfoRow('角色', _roleLabel(_user?.role)),
          _buildInfoRow('注册时间', DateUtils.formatDateDynamic(_user?.createdAt)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            Row(
              children: [
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 16, color: AppColors.textHint),
                ],
              ],
            ),
          ],
        ),
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
              title: Text(h.hotelName),
              subtitle: Text('酒店ID: ${h.id}'),
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

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
            const Text('更换头像', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('拍照功能开发中')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('相册选择功能开发中')));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _user?.username ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑个人信息'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: '用户名',
                prefixIcon: const Icon(Icons.person_outline, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final dio = DioClient();
                final response = await dio.put(ApiConstants.authMe, data: {
                  'username': nameCtrl.text.trim(),
                });
                if (response.statusCode == 200 && response.data['code'] == 200 && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('更新成功'), backgroundColor: AppColors.success),
                  );
                  _loadData();
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(response.data['message'] ?? '更新失败')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('更新失败，请重试')),
                  );
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showEditPhoneDialog() {
    final phoneCtrl = TextEditingController(text: _user?.phone ?? '');
    final codeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改手机号'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: '新手机号',
                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: codeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '验证码',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('验证码已发送')));
                  },
                  child: const Text('获取'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('手机号修改功能开发中')));
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showEditEmailDialog() {
    final emailCtrl = TextEditingController(text: _user?.email ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改邮箱'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: '邮箱地址',
            prefixIcon: const Icon(Icons.email_outlined, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final dio = DioClient();
                final response = await dio.put(ApiConstants.authMe, data: {
                  'email': emailCtrl.text.trim(),
                });
                if (response.statusCode == 200 && response.data['code'] == 200 && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('邮箱更新成功'), backgroundColor: AppColors.success),
                  );
                  _loadData();
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(response.data['message'] ?? '更新失败')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('更新失败，请重试')),
                  );
                }
              }
            },
            child: const Text('保存'),
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
                      value: h.id,
                      child: Text(h.hotelName, overflow: TextOverflow.ellipsis),
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
      final response = await dio.post(ApiConstants.authRoleApplication, data: {
        'application_type': type,
        if (hotelId != null) 'hotel_id': hotelId,
        if (hotelName != null) 'hotel_name': hotelName,
        if (hotelAddress != null) 'hotel_address': hotelAddress,
        'reason': reason?.isNotEmpty == true ? reason : null,
      });

      if (response.statusCode == 200 && response.data['code'] == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('申请已提交，请等待审核'), backgroundColor: AppColors.success));
        _loadData();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.data['message'] ?? '提交失败')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('提交失败，请重试')));
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
            Color statusColor;
            String statusText;
            switch (app.status) {
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
              leading: Icon(app.applicationType == 'create_hotel' ? Icons.add_business_outlined : Icons.badge_outlined, color: AppColors.primary),
              title: Text(app.applicationType == 'create_hotel' ? '创建酒店: ${app.hotelName ?? '-'}' : '绑定员工: ${app.hotelName ?? '-'}'),
              subtitle: Text('申请时间: ${DateUtils.formatDateDynamic(app.createdAt)}'),
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

  Widget _buildPasswordSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('账号安全', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.password_outlined, color: AppColors.primary),
            title: const Text('修改密码'),
            subtitle: const Text('通过旧密码验证修改', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
            onTap: _showChangePasswordDialog,
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt_outlined, color: AppColors.warning),
            title: const Text('重置密码'),
            subtitle: const Text('通过手机验证码重置', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
            onTap: _showResetPasswordDialog,
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldPwdCtrl = TextEditingController();
    final newPwdCtrl = TextEditingController();
    final confirmPwdCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改密码'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: oldPwdCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '旧密码',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) => v == null || v.isEmpty ? '请输入旧密码' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: newPwdCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '新密码',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) => v != null && v.length < 6 ? '密码长度不能少于6位' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmPwdCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '确认新密码',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return '请确认新密码';
                  if (v != newPwdCtrl.text) return '两次密码不一致';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final authState = ref.read(authStateProvider);
              final userId = authState.userId != null ? int.tryParse(authState.userId!) : null;
              if (userId == null) return;

              try {
                final dioClient = DioClient();
                final response = await dioClient.put(
                  '${ApiConstants.users}/$userId/password',
                  data: {
                    'oldPassword': oldPwdCtrl.text,
                    'newPassword': newPwdCtrl.text,
                  },
                );
                if (!ctx.mounted || !mounted) return;
                Navigator.pop(ctx);
                if (response.statusCode == 200 && response.data['code'] == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('密码修改成功'), backgroundColor: AppColors.success),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(response.data['message'] ?? '修改失败'), backgroundColor: AppColors.error),
                  );
                }
              } catch (e) {
                if (!ctx.mounted || !mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('修改失败，请重试'), backgroundColor: AppColors.error),
                );
              }
            },
            child: const Text('确认修改'),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog() {
    final phoneCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final pwdCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    int countdown = 0;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('重置密码'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: '手机号',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.isEmpty) return '请输入手机号';
                        if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(v)) return '手机号格式不正确';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: codeCtrl,
                            decoration: const InputDecoration(
                              labelText: '验证码',
                              prefixIcon: Icon(Icons.verified_user_outlined),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) => v == null || v.isEmpty ? '请输入验证码' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 110,
                          child: TextButton(
                            onPressed: countdown > 0
                                ? null
                                : () async {
                                    final phone = phoneCtrl.text.trim();
                                    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('请先输入正确的手机号')),
                                      );
                                      return;
                                    }
                                    final result = await ref.read(authServiceProvider).sendResetCode(phone);
                                    if (result.success) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('验证码已发送，默认123456'), backgroundColor: AppColors.success),
                                      );
                                      setDialogState(() => countdown = 60);
                                      Timer.periodic(const Duration(seconds: 1), (timer) {
                                        if (countdown <= 1) {
                                          timer.cancel();
                                          setDialogState(() => countdown = 0);
                                        } else {
                                          setDialogState(() => countdown--);
                                        }
                                      });
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(result.message ?? '发送失败'), backgroundColor: AppColors.error),
                                      );
                                    }
                                  },
                            child: Text(countdown > 0 ? '${countdown}s' : '获取验证码'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: pwdCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '新密码',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (v) => v != null && v.length < 6 ? '密码长度不能少于6位' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    try {
                      final result = await ref.read(authServiceProvider).resetPassword(
                        phoneCtrl.text.trim(),
                        pwdCtrl.text,
                        verificationCode: codeCtrl.text.trim(),
                      );
                      if (!ctx.mounted || !mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result.success ? '密码重置成功，请重新登录' : (result.message ?? '重置失败')),
                          backgroundColor: result.success ? AppColors.success : AppColors.error,
                        ),
                      );
                    } catch (e) {
                      if (!ctx.mounted || !mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('重置失败，请重试'), backgroundColor: AppColors.error),
                      );
                    }
                  },
                  child: const Text('确认重置'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
