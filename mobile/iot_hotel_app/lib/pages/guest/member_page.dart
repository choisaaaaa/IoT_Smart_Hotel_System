import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/member_service.dart';
import '../../core/logic/member_logic.dart';

class MemberPage extends ConsumerStatefulWidget {
  const MemberPage({super.key});

  @override
  ConsumerState<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends ConsumerState<MemberPage> {
  bool _isCheckinLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('会员中心', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildMemberCard(ref),
              const SizedBox(height: 16),
              _buildMemberRights(ref),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard(WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final assetsAsync = ref.watch(myAssetsProvider);

    return FutureBuilder(
      future: authService.getCurrentUser(),
      builder: (context, userSnapshot) {
        return assetsAsync.when(
          loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
          error: (err, stack) => SizedBox(height: 220, child: Center(child: Text('加载失败: $err'))),
          data: (apiResult) {
            final user = userSnapshot.data;
            final assets = apiResult.data ?? {};
            
            final lastCheckin = assets['last_checkin_date']?.toString();
            final today = DateTime.now().toIso8601String().split('T')[0];
            final bool isAlreadyCheckedIn = lastCheckin != null && lastCheckin.contains(today);

            final String levelKey = assets['member_level']?.toString() ?? 'standard';
            final level = MemberLevel.fromKey(levelKey);
            final experience = (assets['experience'] as num?)?.toInt() ?? 0;
            final nextExp = level.nextLevelExperience();
            final progress = (experience / nextExp).clamp(0.0, 1.0);

            return Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    level.color,
                    level.color.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: level.color.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Icon(Icons.blur_on_rounded, size: 150, color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('SMART HOTEL', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                              child: Text(level.label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white24,
                              child: const Icon(Icons.person, color: Colors.white, size: 32),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?.username ?? '未登录',
                                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'NO. ${user?.phone ?? '********'}',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontFamily: 'monospace'),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!isAlreadyCheckedIn)
                              ElevatedButton(
                                onPressed: _isCheckinLoading ? null : _handleCheckin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: level.color,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                child: _isCheckinLoading 
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('签到', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              )
                            else
                              ElevatedButton(
                                onPressed: null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.3),
                                  disabledForegroundColor: Colors.white70,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                child: const Text('已签到', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('成长值 $experience / $nextExp', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
                                Text('积分 ${assets['points'] ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.white.withValues(alpha: 0.2),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleCheckin() async {
    setState(() => _isCheckinLoading = true);
    final result = await ref.read(memberServiceProvider).checkin();
    if (mounted) {
      setState(() => _isCheckinLoading = false);
      if (result.alreadyCheckedIn) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('今日已签到过了哦')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('签到成功！获得 ${result.experience} 成长值')));
      }
      
      // 强制刷新会员服务缓存
      ref.invalidate(myAssetsProvider);
    }
  }

  Widget _buildMemberRights(WidgetRef ref) {
    final assetsAsync = ref.watch(myAssetsProvider);
    
    return assetsAsync.when(
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      error: (err, stack) => const SizedBox.shrink(),
      data: (apiResult) {
        final assets = apiResult.data ?? {};
        final level = MemberLevel.fromKey(assets['member_level']?.toString() ?? 'standard');
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('尊享权益', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(level.label, style: TextStyle(color: level.color, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildRightItem(Icons.percent_rounded, '订房折扣', '${(level.discount * 10).toStringAsFixed(1)}折')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildRightItem(Icons.bolt_rounded, '积分倍率', '${level.pointsMultiplier}倍积分')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRightItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
