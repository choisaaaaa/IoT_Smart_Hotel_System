import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/hotel_service.dart';

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
      final result = await ref.read(hotelServiceProvider).getMonthlyReport(
        year: now.year.toString(),
        month: now.month.toString(),
      );
      if (result.success && mounted) {
        setState(() => _reportData = result.data);
      }
    } catch (e) {
      debugPrint('Error loading report: $e');
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

    return Scaffold(
      appBar: AppBar(title: const Text('统计报表')),
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
                    Text('月度收入趋势', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Container(
                      height: 220,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)]),
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: true, drawVerticalLine: false),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Text('${v.toInt() + 1}月', style: const TextStyle(fontSize: 10)), reservedSize: 22)),
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
                    const SizedBox(height: 24),
                    Text('收入构成', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)]),
                      child: Column(children: [
                        _buildRevenueRow('房费收入', revenue * 0.72, AppColors.primary),
                        _buildRevenueRow('餐饮收入', revenue * 0.15, AppColors.success),
                        _buildRevenueRow('其他收入', revenue * 0.13, AppColors.warning),
                      ]),
                    ),
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

  Widget _buildRevenueRow(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Text('¥${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ]),
    );
  }
}
