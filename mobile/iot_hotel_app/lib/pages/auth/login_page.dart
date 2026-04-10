import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _showResetPasswordDialog() {
    final phoneCtrl = TextEditingController();
    final pwdCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.success ? '密码重置成功，请重新登录' : (result.message ?? '重置失败')),
                      backgroundColor: result.success ? AppColors.success : AppColors.error,
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('重置失败：$e')),
                );
              }
            },
            child: const Text('确认重置'),
          ),
        ],
      ),
    );
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final result = await ref.read(authServiceProvider).login(_usernameController.text.trim(), _passwordController.text);
      if (!mounted) return;

      if (result.success) {
        if (!context.mounted) return;
        // 根据用户角色导航到对应页面
        final user = result.data?['user'] as Map<String, dynamic>?;
        final role = user?['role'] as String? ?? 'user';
        switch (role) {
          case 'admin':
          case 'system':
            context.go('/system');
            break;
          case 'manager':
            context.go('/admin');
            break;
          case 'staff':
          case 'receptionist':
            context.go('/reception');
            break;
          default:
            context.go('/');
        }
      } else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '登录失败'), behavior: SnackBarBehavior.floating)); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('登录异常：$e'), behavior: SnackBarBehavior.floating));
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB), Color(0xFFE1F5FE)],
              ),
            ),
          ),
          // Decorative Circles
          Positioned(
            top: -100,
            right: -100,
            child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.3))),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withValues(alpha: 0.1))),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Card(
                  elevation: 8,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: const Icon(Icons.hotel_rounded, size: 48, color: Colors.white),
                          ),
                          const SizedBox(height: 24),
                          Text('智联酒店', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: 2)),
                          const SizedBox(height: 8),
                          Text('智慧酒店物联网控制系统', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                          const SizedBox(height: 40),
                          TextFormField(
                            controller: _usernameController,
                            decoration: const InputDecoration(labelText: '手机号', prefixIcon: Icon(Icons.phone_outlined), hintText: '请输入手机号'),
                            validator: (v) => v!.isEmpty ? '请输入手机号' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: '密码',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              hintText: '请输入密码',
                            ),
                            validator: (v) => v!.isEmpty ? '请输入密码' : null,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showResetPasswordDialog,
                              child: const Text('忘记密码？', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: FilledButton(
                              onPressed: _isLoading ? null : _login,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _isLoading 
                                ? const SpinKitThreeBounce(color: Colors.white, size: 20) 
                                : const Text('登 录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 4)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('没有账号？', style: TextStyle(color: AppColors.textSecondary)),
                              TextButton(
                                onPressed: () => context.push('/register'),
                                child: const Text('立即注册', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
