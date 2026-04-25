import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../services/hotel_service.dart';
import '../../services/auth_service.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  Map<String, dynamic>? _reportData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final hotelId = await ref.read(authServiceProvider).getCurrentHotelId();
      final reportResult = await ref.read(hotelServiceProvider).getMonthlyReport(
        year: now.year.toString(),
        month: now.month.toString(),
        hotelId: hotelId,
      );
      if (reportResult.success && mounted) {
        setState(() => _reportData = reportResult.data);
      }
    } catch (e) {
      debugPrint('report: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final revenue = double.tryParse(_reportData?['total_revenue']?.toString() ?? '0') ?? 0;
    final orders = _reportData?['total_orders'] ?? 0;
    final avgPrice = double.tryParse(_reportData?['avg_room_price']?.toString() ?? '0') ?? 0;
    final occupancyRate = double.tryParse(_reportData?['occupancy_rate']?.toString() ?? '0') ?? 0;
    final monthlyRevenue = _reportData?['monthly_revenue'] as List<dynamic>? ?? List.filled(12, 0);
    final incomeComposition = _reportData?['income_composition'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('统计报表'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReport,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('本月概览', style: GoogleFonts.notoSansSc(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.6,
                      children: [
                        _buildStatCard('本月收入', '¥${revenue.toStringAsFixed(0)}', Icons.payments_rounded, AppColors.primary),
                        _buildStatCard('订单数', '$orders', Icons.receipt_long_rounded, AppColors.success),
                        _buildStatCard('平均房价', '¥${avgPrice.toStringAsFixed(0)}', Icons.bed_rounded, AppColors.info),
                        _buildStatCard('入住率', '${(occupancyRate * 100).toStringAsFixed(0)}%', Icons.trending_up_rounded, AppColors.warning),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildMonthlyRevenueChart(monthlyRevenue),
                    const SizedBox(height: 24),
                    _buildRevenueBreakdown(revenue, incomeComposition),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 8), Text(title, style: TextStyle(color: AppColors.textSecondary, fontSize: 13))]),
        Text(value, style: GoogleFonts.notoSansSc(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  Widget _buildMonthlyRevenueChart(List<dynamic> monthlyRevenue) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('月度收入趋势', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              const Icon(Icons.show_chart, size: 20, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                    if (v.toInt() % 2 != 0) return const SizedBox();
                    return Text('${v.toInt() + 1}月', style: const TextStyle(fontSize: 10));
                  }, reservedSize: 22)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) => Text('${(v / 10000).toStringAsFixed(1)}万', style: const TextStyle(fontSize: 9)))),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(monthlyRevenue.length, (i) => FlSpot(i.toDouble(), (monthlyRevenue[i] as num?)?.toDouble() ?? 0)),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.1)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueBreakdown(double revenue, List<dynamic> incomeComposition) {
    // 支付方式颜色列表
    final colors = [AppColors.primary, AppColors.success, AppColors.warning, AppColors.info, AppColors.secondary, AppColors.primaryDark];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('支付方式', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              const Icon(Icons.payment_rounded, size: 20, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 16),
          if (incomeComposition.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('暂无数据', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ),
            )
          else
            ...incomeComposition.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value as Map<String, dynamic>;
              final name = item['name']?.toString() ?? '未知';
              final value = (item['value'] as num?)?.toDouble() ?? 0;
              final color = colors[index % colors.length];
              return _buildRevenueRow(name, value, color);
            }),
        ],
      ),
    );
  }

  Widget _buildRevenueRow(String label, double amount, Color color) {
    final total = double.tryParse(_reportData?['total_revenue']?.toString() ?? '0') ?? 0;
    final percent = total > 0 ? (amount / total * 100).toStringAsFixed(0) : '0';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
            Text('$percent%', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color)),
            const SizedBox(width: 12),
            Text('¥${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? amount / total : 0,
              backgroundColor: color.withValues(alpha: 0.1),
              color: color,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
