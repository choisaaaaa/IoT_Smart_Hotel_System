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
  String? _paymentMethodFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadStats(), _loadRecentBills()]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadStats() async {
    final result = await ref.read(paymentServiceProvider).getRevenueStats(range: _dateRange);
    if (result.success && mounted) setState(() => _stats = result.data);
  }

  Future<void> _loadRecentBills() async {
    final result = await ref.read(paymentServiceProvider).getBills(limit: 50);
    if (result.success && mounted) setState(() => _recentBills = result.data ?? []);
  }

  List<dynamic> get _filteredBills {
    var bills = _recentBills;
    if (_paymentMethodFilter != null) {
      bills = bills.where((b) => b['payment_method'] == _paymentMethodFilter).toList();
    }
    return bills;
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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('账单报表'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) {
              if (v == 'export') _exportReport();
              if (v == 'print') _printReport();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'export', child: Row(children: [Icon(Icons.download), SizedBox(width: 8), Text('导出报表')])),
              const PopupMenuItem(value: 'print', child: Row(children: [Icon(Icons.print), SizedBox(width: 8), Text('打印报表')])),
            ],
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
                    _buildPaymentMethodFilter(),
                    const SizedBox(height: 8),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: ['today', 'week', 'month', 'year'].map((key) {
          final labels = {'today': '今日', 'week': '本周', 'month': '本月', 'year': '本年'};
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() { _dateRange = key; _loadStats(); }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: _dateRange == key ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(6)),
                child: Center(child: Text(labels[key]!, style: TextStyle(color: _dateRange == key ? Colors.white : AppColors.textSecondary, fontWeight: _dateRange == key ? FontWeight.w600 : FontWeight.normal, fontSize: 13))),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatCards(double today, double month, int pending) {
    return Row(
      children: [
        Expanded(child: _StatCard(title: '今日营收', value: '¥${today.toStringAsFixed(2)}', icon: Icons.today, color: Colors.blue)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(title: '本月累计', value: '¥${month.toStringAsFixed(2)}', icon: Icons.calendar_month, color: Colors.green)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(title: '待结算', value: pending.toString(), subtitle: '笔账单待处理', icon: Icons.pending_actions, color: Colors.orange)),
      ],
    );
  }

  Widget _buildRevenueChart(List<dynamic> trend) {
    final spots = trend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['amount'] ?? 0).toDouble())).toList();
    final maxY = spots.isEmpty ? 100.0 : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('营收趋势', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) => Text('¥${value.toInt()}', style: TextStyle(color: Colors.grey[600], fontSize: 10)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                    if (value.toInt() >= 0 && value.toInt() < trend.length) {
                      final date = trend[value.toInt()]['date']?.toString() ?? '';
                      return Text(date.length >= 5 ? date.substring(5) : date, style: TextStyle(color: Colors.grey[600], fontSize: 10));
                    }
                    return const SizedBox();
                  })),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0, maxX: (trend.length - 1).toDouble(), minY: 0, maxY: maxY,
                lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: AppColors.primary, barWidth: 3, dotData: FlDotData(show: false), belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.1)))],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomePieChart(Map<String, dynamic> breakdown) {
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red];
    final sections = breakdown.entries.toList().asMap().entries.map((e) {
      final index = e.key;
      final entry = e.value;
      final value = (entry.value as num).toDouble();
      final total = breakdown.values.fold<double>(0, (sum, v) => sum + (v as num));
      final percentage = total > 0 ? (value / total * 100) : 0;
      return PieChartSectionData(color: colors[index % colors.length], value: value, title: '${percentage.toStringAsFixed(0)}%', radius: 60, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white));
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('收入构成', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(width: 150, height: 150, child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 30, sectionsSpace: 2))),
              const SizedBox(width: 16),
              Expanded(child: Column(children: breakdown.entries.toList().asMap().entries.map((e) {
                final index = e.key;
                final entry = e.value;
                return _LegendItem(color: colors[index % colors.length], label: entry.key, value: '¥${(entry.value as num).toStringAsFixed(0)}');
              }).toList())),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(label: const Text('全部'), selected: _paymentMethodFilter == null, onSelected: (_) => setState(() => _paymentMethodFilter = null)),
          const SizedBox(width: 8),
          FilterChip(label: const Text('前台支付'), selected: _paymentMethodFilter == 'front_desk', onSelected: (_) => setState(() => _paymentMethodFilter = 'front_desk')),
          const SizedBox(width: 8),
          FilterChip(label: const Text('支付宝'), selected: _paymentMethodFilter == 'alipay', onSelected: (_) => setState(() => _paymentMethodFilter = 'alipay')),
          const SizedBox(width: 8),
          FilterChip(label: const Text('微信'), selected: _paymentMethodFilter == 'wechat', onSelected: (_) => setState(() => _paymentMethodFilter = 'wechat')),
          const SizedBox(width: 8),
          FilterChip(label: const Text('现金'), selected: _paymentMethodFilter == 'cash', onSelected: (_) => setState(() => _paymentMethodFilter = 'cash')),
          const SizedBox(width: 8),
          FilterChip(label: const Text('银行卡'), selected: _paymentMethodFilter == 'credit_card', onSelected: (_) => setState(() => _paymentMethodFilter = 'credit_card')),
        ],
      ),
    );
  }

  Widget _buildRecentBills() {
    final bills = _filteredBills;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('近期账单', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('共${bills.length}条', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          if (bills.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('暂无账单数据', style: TextStyle(color: Colors.grey[500]))))
          else
            ...bills.take(15).map((bill) => _BillItem(bill: bill, onTap: () => _showBillDetail(bill))),
        ],
      ),
    );
  }

  void _showBillDetail(dynamic bill) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('账单明细', style: GoogleFonts.notoSansSc(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ]),
                  const Divider(),
                  _detailRow('账单号', bill['payment_no'] ?? bill['id']?.toString() ?? '-'),
                  _detailRow('客人', bill['guest_name'] ?? '-'),
                  _detailRow('房间', bill['room_number'] ?? '-'),
                  _detailRow('入住日期', _formatDateStr(bill['check_in_date'])),
                  _detailRow('退房日期', _formatDateStr(bill['check_out_date'])),
                  const Divider(),
                  Text('费用明细', style: GoogleFonts.notoSansSc(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (bill['items'] != null)
                    ...(bill['items'] as List).map((item) => _detailRow(item['item'] ?? item['description'] ?? '-', '¥${(item['amount'] ?? 0).toStringAsFixed(2)}'))
                  else
                    _detailRow('房费', '¥${(bill['amount'] ?? 0).toStringAsFixed(2)}'),
                  const Divider(),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('合计', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('¥${(bill['amount'] ?? bill['total_price'] ?? 0).toStringAsFixed(2)}', style: GoogleFonts.notoSansSc(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ]),
                  const SizedBox(height: 16),
                  if (bill['status'] == 'pending')
                    SizedBox(width: double.infinity, height: 44, child: FilledButton(
                      onPressed: () => _handleCollectPayment(bill),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                      child: const Text('确认收款'),
                    )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      ]),
    );
  }

  String _formatDateStr(dynamic dateVal) {
    if (dateVal == null) return '-';
    final s = dateVal.toString();
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  Future<void> _handleCollectPayment(dynamic bill) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('确认收款'),
      content: Text('金额：¥${(bill['amount'] ?? 0).toStringAsFixed(2)}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: AppColors.success), child: const Text('确认收款')),
      ],
    ));
    if (confirm != true) return;

    try {
      final paymentId = bill['id'];
      if (paymentId == null) return;
      final result = await ref.read(paymentServiceProvider).pay(paymentId);
      if (result.success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('收款成功'), backgroundColor: AppColors.success));
        _loadData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '收款失败')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
    }
  }

  void _exportReport() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('报表导出功能开发中')));
  }

  void _printReport() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('报表打印功能开发中')));
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  const _StatCard({required this.title, required this.value, this.subtitle, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 8), Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12))]),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.notoSansSc(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: TextStyle(color: Colors.grey[500], fontSize: 11))],
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _LegendItem({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    );
  }
}

class _BillItem extends StatelessWidget {
  final dynamic bill;
  final VoidCallback? onTap;
  const _BillItem({required this.bill, this.onTap});

  @override
  Widget build(BuildContext context) {
    final amount = (bill['amount'] ?? 0).toDouble();
    final status = bill['status'] ?? 'pending';
    final type = bill['type'] ?? bill['order_type'] ?? 'room';
    final createdAt = bill['created_at']?.toString() ?? '';
    final guestName = bill['guest_name'] ?? '';
    final roomNumber = bill['room_number'] ?? '';

    IconData typeIcon;
    String typeText;
    switch (type) {
      case 'room': case 'booking': typeIcon = Icons.hotel; typeText = '房费';
      case 'service': typeIcon = Icons.room_service; typeText = '服务费';
      case 'minibar': typeIcon = Icons.local_bar; typeText = '迷你吧';
      case 'delivery': typeIcon = Icons.delivery_dining; typeText = '送物';
      default: typeIcon = Icons.receipt; typeText = '其他';
    }

    Color statusColor;
    String statusText;
    switch (status) {
      case 'paid': case 'completed': statusColor = Colors.green; statusText = '已支付';
      case 'pending': statusColor = Colors.orange; statusText = '待支付';
      case 'refunded': statusColor = Colors.grey; statusText = '已退款';
      default: statusColor = Colors.grey; statusText = status;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(typeIcon, color: AppColors.primary, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(typeText, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  if (guestName.isNotEmpty || roomNumber.isNotEmpty)
                    Text('$guestName ${roomNumber.isNotEmpty ? '· $roomNumber' : ''}', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  Text(createdAt.length > 10 ? createdAt.substring(0, 10) : createdAt, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('¥${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
