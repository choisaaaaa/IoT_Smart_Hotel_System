import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账单报表')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _ReportCard(title: '本月收入', amount: '¥128,600', change: '+12.5%', isUp: true)),
                const SizedBox(width: 12),
                Expanded(child: _ReportCard(title: '本月订单', amount: '356', change: '+8.2%', isUp: true)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _ReportCard(title: '平均房价', amount: '¥562', change: '-2.1%', isUp: false)),
                const SizedBox(width: 12),
                Expanded(child: _ReportCard(title: '入住率', amount: '78.5%', change: '+5.3%', isUp: true)),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('收入趋势', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), TextButton.icon(onPressed: () {}, icon: const Icon(Icons.download, size: 18), label: const Text('导出'))]),
                    const SizedBox(height: 200, child: Center(child: Text('收入趋势图表', style: TextStyle(color: AppColors.textSecondary)))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('房型分布', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ...['标准间', '大床房', '套房', '豪华套房'].map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t, style: const TextStyle(fontSize: 14)), Text('${[45, 25, 18, 12][['标准间','大床房','套房','豪华套装'].indexOf(t)]}%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))]),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(value: [0.45, 0.25, 0.18, 0.12][['标准间','大床房','套房','豪华套装'].indexOf(t)], backgroundColor: AppColors.divider, color: AppColors.primary),
                      ]),
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String amount;
  final String change;
  final bool isUp;
  const _ReportCard({required this.title, required this.amount, required this.change, required this.isUp});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text(amount, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: isUp ? AppColors.success : AppColors.error), Text(change, style: TextStyle(fontSize: 12, color: isUp ? AppColors.success : AppColors.error))]),
          ],
        ),
      ),
    );
  }
}
