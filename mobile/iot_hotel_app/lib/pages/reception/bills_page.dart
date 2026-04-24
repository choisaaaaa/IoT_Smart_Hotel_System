import 'package:flutter/material.dart' hide DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/type_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../services/payment_service.dart';

/// 安全转换为 double，兼容 int/double/String 及其他动态类型
double _toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '0') ?? 0.0;

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
    final todayRevenue = _toDouble(_stats?['today_revenue']);
    final monthRevenue = _toDouble(_stats?['month_revenue']);
    final pendingBills = safeToInt(_stats?['pending_bills']);
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
    // 固定显示近7日数据，不再提供日期筛选按钮
    return const SizedBox.shrink();
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

  double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Widget _buildRevenueChart(List<dynamic> trend) {
    // 只取最近7天的数据
    final recentTrend = trend.length > 7 ? trend.sublist(trend.length - 7) : trend;
    final spots = recentTrend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), _parseAmount(e.value['amount']))).toList();
    final maxY = spots.isEmpty ? 100.0 : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('营收趋势', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('近7日', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY > 0 ? maxY / 4 : 100),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, interval: maxY > 0 ? maxY / 4 : 100, getTitlesWidget: (value, meta) {
                    if (value == 0) return const Text('0', style: TextStyle(color: Colors.grey, fontSize: 10));
                    return Text('¥${(value / 1000).toStringAsFixed(0)}k', style: TextStyle(color: Colors.grey[600], fontSize: 9));
                  })),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= recentTrend.length) return const SizedBox();
                      final date = recentTrend[index]['date']?.toString() ?? '';
                      // 只显示月-日，例如 "04-23"
                      String displayDate = '';
                      if (date.length >= 10) {
                        displayDate = '${date.substring(5, 7)}-${date.substring(8, 10)}';
                      } else if (date.length >= 5) {
                        displayDate = date.substring(5);
                      }
                      // 旋转显示避免重叠
                      return Transform.rotate(
                        angle: -0.3,
                        child: Text(displayDate, style: TextStyle(color: Colors.grey[600], fontSize: 9)),
                      );
                    },
                  )),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0, maxX: (recentTrend.length - 1).toDouble(), minY: 0, maxY: maxY,
                lineBarsData: [LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 3,
                  dotData: FlDotData(show: recentTrend.length <= 10),
                  belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.1)),
                )],
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
      final value = _parseAmount(entry.value);
      final total = breakdown.values.fold<double>(0, (sum, v) => sum + _parseAmount(v));
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
                return _LegendItem(color: colors[index % colors.length], label: entry.key, value: '¥${_toDouble(entry.value).toStringAsFixed(0)}');
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
                  _detailRow('入住日期', DateUtils.formatDateDynamic(bill['check_in_date'])),
                  _detailRow('退房日期', DateUtils.formatDateDynamic(bill['check_out_date'])),
                  const Divider(),
                  Text('费用明细', style: GoogleFonts.notoSansSc(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (bill['items'] != null)
                    ...(bill['items'] as List).map((item) => _detailRow(item['item'] ?? item['description'] ?? '-', '¥${_toDouble(item['amount']).toStringAsFixed(2)}'))
                  else
                    _detailRow('房费', '¥${_toDouble(bill['amount']).toStringAsFixed(2)}'),
                  const Divider(),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('合计', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('¥${_toDouble(bill['amount'] ?? bill['total_price']).toStringAsFixed(2)}', style: GoogleFonts.notoSansSc(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
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

  Future<void> _handleCollectPayment(dynamic bill) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('确认收款'),
      content: Text('金额：¥${_toDouble(bill['amount']).toStringAsFixed(2)}'),
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
    final amountValue = bill['amount'];
    double amount;
    if (amountValue is num) {
      amount = amountValue.toDouble();
    } else if (amountValue is String) {
      amount = double.tryParse(amountValue) ?? 0.0;
    } else {
      amount = 0.0;
    }
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
      default: statusColor = Colors.grey; statusText = '未知';
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
                  Text(DateUtils.formatDateDynamic(createdAt), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
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
