import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../core/theme/app_colors.dart';
import '../../routes/app_router.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final result = await ref.read(authServiceProvider).login(_usernameController.text.trim(), _passwordController.text);
      if (!mounted) return;

      if (result.success) {
        if (!context.mounted) return;
        final user = result.data?['user'];
        final role = user['role'] ?? 'guest';
        switch (role) {
          case 'admin':
            context.go('/admin');
            break;
          case 'reception':
            context.go('/reception');
            break;
          default:
            context.go('/guest');
            break;
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
                            decoration: const InputDecoration(labelText: '用户名', prefixIcon: Icon(Icons.person_outline_rounded), hintText: '请输入用户名'),
                            validator: (v) => v!.isEmpty ? '请输入用户名' : null,
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
                          const SizedBox(height: 24),
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('快捷登录', style: TextStyle(color: AppColors.textHint, fontSize: 12))),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildRoleChip('管理员', 'admin', Colors.blue),
                              const SizedBox(width: 8),
                              _buildRoleChip('前台', 'reception', Colors.orange),
                              const SizedBox(width: 8),
                              _buildRoleChip('住客', 'guest', Colors.green),
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

  Widget _buildRoleChip(String label, String role, Color color) {
    return ActionChip(
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.2)),
      onPressed: () {
        _usernameController.text = role == 'admin' ? 'admin' : role == 'reception' ? 'reception' : 'guest';
        _passwordController.text = '123456';
      },
    );
  }
}
