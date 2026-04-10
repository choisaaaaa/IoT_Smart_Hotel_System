import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../services/payment_service.dart';

class BillsPage extends ConsumerStatefulWidget {
  const BillsPage({super.key});

  @override
  ConsumerState<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends ConsumerState<BillsPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  List<dynamic> _recentBills = [];
  String _dateRange = 'today';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadStats(),
      _loadRecentBills(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadStats() async {
    final result = await ref.read(paymentServiceProvider).getRevenueStats(
          range: _dateRange,
        );
    if (result.success && mounted) {
      setState(() => _stats = result.data);
    }
  }

  Future<void> _loadRecentBills() async {
    final result = await ref.read(paymentServiceProvider).getBills(
          limit: 20,
        );
    if (result.success && mounted) {
      setState(() => _recentBills = result.data ?? []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayRevenue = _stats?['today_revenue'] ?? 0.0;
    final monthRevenue = _stats?['month_revenue'] ?? 0.0;
    final pendingBills = _stats?['pending_bills'] ?? 0;
    final revenueTrend = _stats?['revenue_trend'] as List<dynamic>? ?? [];
    final incomeBreakdown = _stats?['income_breakdown'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('账单报表', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDateFilter(),
                    const SizedBox(height: 16),
                    _buildStatCards(todayRevenue, monthRevenue, pendingBills),
                    const SizedBox(height: 16),
                    if (revenueTrend.isNotEmpty) ...[
                      _buildRevenueChart(revenueTrend),
                      const SizedBox(height: 16),
                    ],
                    if (incomeBreakdown.isNotEmpty) ...[
                      _buildIncomePieChart(incomeBreakdown),
                      const SizedBox(height: 16),
                    ],
                    _buildRecentBills(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDateFilter() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _DateFilterChip(
              label: '今日',
              isSelected: _dateRange == 'today',
              onTap: () {
                setState(() => _dateRange = 'today');
                _loadStats();
              },
            ),
          ),
          Expanded(
            child: _DateFilterChip(
              label: '本周',
              isSelected: _dateRange == 'week',
              onTap: () {
                setState(() => _dateRange = 'week');
                _loadStats();
              },
            ),
          ),
          Expanded(
            child: _DateFilterChip(
              label: '本月',
              isSelected: _dateRange == 'month',
              onTap: () {
                setState(() => _dateRange = 'month');
                _loadStats();
              },
            ),
          ),
          Expanded(
            child: _DateFilterChip(
              label: '本年',
              isSelected: _dateRange == 'year',
              onTap: () {
                setState(() => _dateRange = 'year');
                _loadStats();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(double today, double month, int pending) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: '今日营收',
            value: '¥${today.toStringAsFixed(2)}',
            subtitle: '较昨日 ${today > 0 ? '+' : ''}${((today - (today * 0.9)) / (today * 0.9) * 100).toStringAsFixed(1)}%',
            icon: Icons.today,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: '本月累计',
            value: '¥${month.toStringAsFixed(2)}',
            subtitle: '目标完成度 ${(month / 100000 * 100).toStringAsFixed(0)}%',
            icon: Icons.calendar_month,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: '待结算',
            value: pending.toString(),
            subtitle: '笔账单待处理',
            icon: Icons.pending_actions,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueChart(List<dynamic> trend) {
    final spots = trend.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (e.value['amount'] ?? 0).toDouble());
    }).toList();

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2;

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '营收趋势',
            style: GoogleFonts.notoSansSc(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '¥${value.toInt()}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < trend.length) {
                          final date = trend[value.toInt()]['date']?.toString() ?? '';
                          return Text(
                            date.length >= 5 ? date.substring(5) : date,
                            style: TextStyle(color: Colors.grey[600], fontSize: 10),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (trend.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomePieChart(Map<String, dynamic> breakdown) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];

    final sections = breakdown.entries.toList().asMap().entries.map((e) {
      final index = e.key;
      final entry = e.value;
      final value = (entry.value as num).toDouble();
      final total = breakdown.values.fold<double>(0, (sum, v) => sum + (v as num));
      final percentage = total > 0 ? (value / total * 100) : 0;

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: value,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '收入构成',
            style: GoogleFonts.notoSansSc(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 30,
                    sectionsSpace: 2,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: breakdown.entries.toList().asMap().entries.map((e) {
                    final index = e.key;
                    final entry = e.value;
                    return _LegendItem(
                      color: colors[index % colors.length],
                      label: entry.key,
                      value: '¥${(entry.value as num).toStringAsFixed(0)}',
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentBills() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '近期账单',
                style: GoogleFonts.notoSansSc(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // 查看全部
                },
                child: const Text('查看全部'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_recentBills.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  '暂无账单数据',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
            )
          else
            ..._recentBills.take(10).map((bill) => _BillItem(bill: bill)),
        ],
      ),
    );
  }
}

class _DateFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DateFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.notoSansSc(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _BillItem extends StatelessWidget {
  final dynamic bill;

  const _BillItem({required this.bill});

  @override
  Widget build(BuildContext context) {
    final amount = (bill['amount'] ?? 0).toDouble();
    final status = bill['status'] ?? 'pending';
    final type = bill['type'] ?? 'room';
    final createdAt = bill['created_at']?.toString() ?? '';

    IconData typeIcon;
    String typeText;
    switch (type) {
      case 'room':
        typeIcon = Icons.hotel;
        typeText = '房费';
        break;
      case 'service':
        typeIcon = Icons.room_service;
        typeText = '服务费';
        break;
      case 'minibar':
        typeIcon = Icons.local_bar;
        typeText = '迷你吧';
        break;
      default:
        typeIcon = Icons.receipt;
        typeText = '其他';
    }

    Color statusColor;
    String statusText;
    switch (status) {
      case 'paid':
        statusColor = Colors.green;
        statusText = '已支付';
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusText = '待支付';
        break;
      case 'refunded':
        statusColor = Colors.grey;
        statusText = '已退款';
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(typeIcon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  createdAt.length > 10 ? createdAt.substring(0, 10) : createdAt,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
