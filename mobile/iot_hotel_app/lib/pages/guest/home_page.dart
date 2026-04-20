import 'package:flutter/material.dart' hide DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/date_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../core/logic/member_logic.dart';
import '../../core/logic/search_dates.dart';
import '../../core/network/api_result.dart';
import '../../services/auth_service.dart';
import '../../services/member_service.dart';
import '../../services/message_service.dart';
import '../../services/booking_service.dart';
import '../../models/user.dart';
import '../../models/member.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(memberServiceProvider);
          ref.invalidate(userBookingsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(context, ref),
              _buildSearchCard(context),
              _buildQuickActions(context),
              _buildCurrentStay(context),
              _buildBanner(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);

    return Container(
      width: double.infinity,
      height: 260,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?ixlib=rb-1.2.1&auto=format&fit=crop&w=1350&q=80'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.3), Colors.transparent, Colors.white],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: FutureBuilder(
                  future: Future.wait([
                    authService.getCurrentUser(),
                    ref.read(memberServiceProvider).getMyAssets(),
                  ]),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final user = snapshot.data?[0] as User?;
                    final assetsResult = snapshot.data?[1] as ApiResult<Member>?;
                    final member = assetsResult?.data;

                    final displayName = user?.username ?? '游客';
                    final level = MemberLevel.fromKey(member?.memberLevel ?? 'standard');

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        Flexible(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: level.gradientColors),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(level.label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  displayName,
                                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.push('/ai-butler'),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => context.push('/notifications'),
                      child: FutureBuilder<int>(
                        future: ref.read(messageServiceProvider).getUnreadCount().then((r) => r.data ?? 0),
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          return Badge(
                            isLabelVisible: count > 0,
                            label: Text(count > 99 ? '99+' : '$count', style: const TextStyle(fontSize: 10)),
                            child: const Icon(Icons.notifications_none, color: Colors.white, size: 28),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了,';
    if (hour < 12) return '早上好,';
    if (hour < 14) return '中午好,';
    if (hour < 18) return '下午好,';
    return '晚上好,';
  }

  Widget _buildSearchCard(BuildContext context) {
    final searchDates = ref.watch(searchDatesProvider);
    final nights = searchDates.nights;

    return Transform.translate(
      offset: const Offset(0, -40),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Text('酒店预订', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
            const Divider(height: 32),
            GestureDetector(
              onTap: () => context.push('/hotel-list'),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, color: AppColors.primary, size: 16),
                            SizedBox(width: 4),
                            Text('目的地', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text('搜索城市/酒店/关键词', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Icon(Icons.search, color: AppColors.primary.withValues(alpha: 0.6)),
                ],
              ),
            ),
            const Divider(height: 32),
            GestureDetector(
              onTap: _selectDateRange,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('入住', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        Text(DateUtils.formatShortDate(searchDates.checkIn), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('$nights晚', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('离店', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        Text(DateUtils.formatShortDate(searchDates.checkOut), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () => context.push('/hotel-list'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                ),
                child: const Text('查询', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final searchDates = ref.read(searchDatesProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: searchDates.checkIn, end: searchDates.checkOut),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      ref.read(searchDatesProvider.notifier).updateDates(picked.start, picked.end);
    }
  }

  Widget _buildQuickActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionItem(Icons.calendar_today_outlined, '会员签到', onTap: () => context.push('/member')),
          _buildActionItem(Icons.bookmark_outline, '收藏/足迹', onTap: () => context.push('/favorites')),
          _buildActionItem(Icons.smart_toy_outlined, 'AI管家', onTap: () => context.push('/ai-butler')),
          _buildActionItem(Icons.headset_mic_outlined, '联系客服', onTap: () => context.push('/room-service', extra: {'initialTab': 3})),
        ],
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildCurrentStay(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final bookingsAsync = ref.watch(userBookingsProvider);

        return bookingsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (bookings) {
            final checkedIn = bookings.where((b) => b.status == 'checked_in').toList();
            if (checkedIn.isEmpty) return const SizedBox.shrink();

            final stay = checkedIn.first;
            final remaining = stay.checkOutDate.difference(DateTime.now());

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF30CFD0)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('当前入住中', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          remaining.inDays > 0 ? '剩余${remaining.inDays}天' : '今日退房',
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${stay.hotelName ?? '智联酒店'} · ${stay.displayRoomType}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.push('/room-service', extra: {'bookingId': stay.id}),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white54),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('客房服务', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.push('/ai-butler', extra: {'bookingId': stay.id}),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white54),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('AI管家', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.push('/checkout/${stay.id}', extra: {'bookingId': stay.id}),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white54),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('自助退房', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1566073771259-6a8506099945?ixlib=rb-1.2.1&auto=format&fit=crop&w=1350&q=80'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent]),
        ),
        child: const Text('把春天装进眼睛里\n花间赏花季邀您入画', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
