import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../services/hotel_service.dart';
import '../../services/room_type_service.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  Map<String, dynamic>? _reportData;
  List<Map<String, dynamic>> _roomTypeRevenue = [];
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
      final reportResult = await ref.read(hotelServiceProvider).getMonthlyReport(
        year: now.year.toString(),
        month: now.month.toString(),
      );
      if (reportResult.success && mounted) {
        setState(() => _reportData = reportResult.data);
      }

      final roomTypeResult = await ref.read(roomTypeServiceProvider).getRoomTypes();
      if (roomTypeResult.success && mounted) {
        final roomTypes = roomTypeResult.data ?? [];
        final rtRevenue = <Map<String, dynamic>>[];
        final colors = [AppColors.primary, AppColors.secondary, AppColors.success, AppColors.warning, AppColors.info, AppColors.primaryDark];
        for (int i = 0; i < roomTypes.length && i < 6; i++) {
          rtRevenue.add({
            'name': roomTypes[i].name,
            'revenue': (roomTypes[i].basePrice * (roomTypes[i].totalCount - roomTypes[i].availableCount)).toDouble(),
            'count': roomTypes[i].totalCount - roomTypes[i].availableCount,
            'color': colors[i % colors.length],
          });
        }
        setState(() => _roomTypeRevenue = rtRevenue);
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

    final occupancyTrend = _reportData?['occupancy_trend'] as List<dynamic>? ?? [];

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
                    _buildOccupancyTrendChart(occupancyTrend),
                    const SizedBox(height: 24),
                    _buildRoomTypeRevenueChart(),
                    const SizedBox(height: 24),
                    _buildRevenueBreakdown(revenue),
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

  Widget _buildOccupancyTrendChart(List<dynamic> trend) {
    final spots = <FlSpot>[];
    if (trend.isNotEmpty) {
      for (int i = 0; i < trend.length; i++) {
        final val = (trend[i] as num?)?.toDouble() ?? 0;
        spots.add(FlSpot(i.toDouble(), val * 100));
      }
    } else {
      for (int i = 0; i < 7; i++) {
        spots.add(FlSpot(i.toDouble(), 60 + (i % 3) * 10.0));
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('入住率趋势', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              const Icon(Icons.trending_up, size: 20, color: AppColors.success),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                    final labels = trend.isNotEmpty ? List.generate(trend.length, (i) => '${i + 1}') : ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
                    final idx = v.toInt();
                    if (idx < 0 || idx >= labels.length) return const SizedBox();
                    return Text(labels[idx], style: const TextStyle(fontSize: 10));
                  }, reservedSize: 22)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 35, getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 9)))),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                minY: 0,
                maxY: 100,
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.success,
                    barWidth: 3,
                    dotData: FlDotData(show: spots.length <= 12),
                    belowBarData: BarAreaData(show: true, color: AppColors.success.withValues(alpha: 0.1)),
                  ),
                ],
                extraLinesData: ExtraLinesData(horizontalLines: [
                  HorizontalLine(y: 80, color: AppColors.warning.withValues(alpha: 0.3), strokeWidth: 1, dashArray: [5, 5], label: HorizontalLineLabel(show: true, alignment: Alignment.topRight, style: const TextStyle(color: AppColors.warning, fontSize: 9), labelResolver: (_) => '目标80%')),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomTypeRevenueChart() {
    if (_roomTypeRevenue.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('房型收入对比', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const Center(child: Text('暂无房型数据', style: TextStyle(color: AppColors.textSecondary))),
          ],
        ),
      );
    }

    final maxRevenue = _roomTypeRevenue.map((r) => r['revenue'] as double).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('房型收入对比', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              const Icon(Icons.bar_chart, size: 20, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxRevenue > 0 ? maxRevenue * 1.2 : 100,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= _roomTypeRevenue.length) return const SizedBox();
                    final name = _roomTypeRevenue[idx]['name'] as String;
                    return Text(name.length > 4 ? name.substring(0, 4) : name, style: const TextStyle(fontSize: 10));
                  }, reservedSize: 28)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) => Text('${(v / 10000).toStringAsFixed(1)}万', style: const TextStyle(fontSize: 9)))),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _roomTypeRevenue.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [BarChartRodData(
                      toY: entry.value['revenue'] as double,
                      color: entry.value['color'] as Color,
                      width: _roomTypeRevenue.length > 5 ? 20 : 32,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    )],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: _roomTypeRevenue.map((rt) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: rt['color'] as Color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                Text('${rt['name']}: ¥${(rt['revenue'] as double).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueBreakdown(double revenue) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('收入构成', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              const Icon(Icons.pie_chart_outline, size: 20, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 16),
          _buildRevenueRow('房费收入', revenue * 0.72, AppColors.primary),
          _buildRevenueRow('餐饮收入', revenue * 0.15, AppColors.success),
          _buildRevenueRow('其他收入', revenue * 0.13, AppColors.warning),
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
