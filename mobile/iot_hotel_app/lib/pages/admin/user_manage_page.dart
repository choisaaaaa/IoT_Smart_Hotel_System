import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/api_result.dart';
import '../../core/auth/auth_state_notifier.dart';
import '../../services/user_service.dart';

class UserManagePage extends ConsumerStatefulWidget {
  const UserManagePage({super.key});

  @override
  ConsumerState<UserManagePage> createState() => _UserManagePageState();
}

class _UserManagePageState extends ConsumerState<UserManagePage> {
  bool _isLoading = true;
  List<dynamic> _users = [];
  String _searchQuery = '';
  String? _roleFilter;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final result = await ref.read(userServiceProvider).getUsers(
          role: _roleFilter,
          pageSize: 100,
        );
    if (result.success && mounted) {
      setState(() => _users = result.data ?? []);
    }
    setState(() => _isLoading = false);
  }

  List<dynamic> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((u) {
      final username = (u['username'] ?? '').toString().toLowerCase();
      final phone = (u['phone'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return username.contains(query) || phone.contains(query);
    }).toList();
  }

  void _showEditDialog(Map<String, dynamic>? user) {
    final isEdit = user != null;
    final usernameController = TextEditingController(text: user?['username'] ?? '');
    final phoneController = TextEditingController(text: user?['phone'] ?? '');
    final emailController = TextEditingController(text: user?['email'] ?? '');
    String selectedRole = user?['role'] ?? AppRoles.customer;
    bool isActive = user?['is_active'] ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEdit ? '编辑用户' : '新增用户',
                        style: GoogleFonts.notoSansSc(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: '用户名 *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: '手机号 *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: '邮箱',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: '角色',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: AppRoles.customer, child: Text('顾客')),
                      DropdownMenuItem(value: AppRoles.staff, child: Text('前台员工')),
                      DropdownMenuItem(value: AppRoles.hotelAdmin, child: Text('酒店管理员')),
                      DropdownMenuItem(value: AppRoles.systemAdmin, child: Text('系统管理员')),
                    ],
                    onChanged: (value) {
                      if (value != null) setModalState(() => selectedRole = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('启用状态'),
                    value: isActive,
                    onChanged: (value) => setModalState(() => isActive = value),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final data = {
                        'username': usernameController.text,
                        'phone': phoneController.text,
                        'email': emailController.text.isEmpty ? null : emailController.text,
                        'role': selectedRole,
                        'is_active': isActive,
                      };

                      ApiResult<void> result;
                      if (isEdit) {
                        result = await ref.read(userServiceProvider).updateUser(
                          user['id'] as int,
                          data,
                        );
                      } else {
                        result = await ref.read(userServiceProvider).createUser(data);
                      }

                      if (result.success) {
                        _loadUsers();
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(isEdit ? '用户已更新' : '用户已创建')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(isEdit ? '保存修改' : '创建用户'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleUserStatus(Map<String, dynamic> user) async {
    final newStatus = !(user['is_active'] ?? true);
    final result = await ref.read(userServiceProvider).updateUser(
          user['id'],
          {'is_active': newStatus},
        );
    if (result.success) {
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newStatus ? '用户已启用' : '用户已禁用')),
        );
      }
    }
  }

  Color _roleColor(String? role) {
    final normalized = AppRoles.normalize(role);
    switch (normalized) {
      case AppRoles.systemAdmin:
        return Colors.red;
      case AppRoles.hotelAdmin:
        return Colors.orange;
      case AppRoles.staff:
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  String _roleText(String? role) {
    return AppRoles.displayName(AppRoles.normalize(role));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('用户管理', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('暂无用户数据', style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            return _UserCard(
                              user: user,
                              roleColor: _roleColor(user['role']),
                              roleText: _roleText(user['role']),
                              onEdit: () => _showEditDialog(user),
                              onToggleStatus: () => _toggleUserStatus(user),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(null),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('新增用户'),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: '搜索用户名/手机号',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: '全部',
              isSelected: _roleFilter == null,
              onTap: () {
                setState(() => _roleFilter = null);
                _loadUsers();
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: '顾客',
              isSelected: _roleFilter == 'user',
              onTap: () {
                setState(() => _roleFilter = 'user');
                _loadUsers();
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: '前台',
              isSelected: _roleFilter == 'staff',
              onTap: () {
                setState(() => _roleFilter = 'staff');
                _loadUsers();
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: '管理员',
              isSelected: _roleFilter == 'admin',
              onTap: () {
                setState(() => _roleFilter = 'admin');
                _loadUsers();
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: '系统',
              isSelected: _roleFilter == 'system',
              onTap: () {
                setState(() => _roleFilter = 'system');
                _loadUsers();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.notoSansSc(
            fontSize: 13,
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final dynamic user;
  final Color roleColor;
  final String roleText;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  const _UserCard({
    required this.user,
    required this.roleColor,
    required this.roleText,
    required this.onEdit,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = user['is_active'] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: roleColor.withValues(alpha: 0.1),
            child: Text(
              (user['username'] ?? '?')[0].toUpperCase(),
              style: TextStyle(
                color: roleColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user['username'] ?? '未知',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        roleText,
                        style: TextStyle(
                          color: roleColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '已禁用',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user['phone'] ?? '-',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                  break;
                case 'toggle':
                  onToggleStatus();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'edit', child: Text('编辑')),
              PopupMenuItem(
                value: 'toggle',
                child: Text(isActive ? '禁用' : '启用'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
