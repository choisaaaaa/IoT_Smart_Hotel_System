import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';

class RecentBrowsingPage extends StatefulWidget {
  const RecentBrowsingPage({super.key});

  @override
  State<RecentBrowsingPage> createState() => _RecentBrowsingPageState();
}

class _RecentBrowsingPageState extends State<RecentBrowsingPage> {
  List<Map<String, dynamic>> _browsingHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyStr = prefs.getString('browsing_history') ?? '[]';
      final List<dynamic> historyList = json.decode(historyStr);
      setState(() {
        _browsingHistory = historyList.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空浏览记录'),
        content: const Text('确定要清空所有浏览记录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('browsing_history');
      setState(() => _browsingHistory = []);
    }
  }

  Future<void> _removeItem(int index) async {
    setState(() => _browsingHistory.removeAt(index));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('browsing_history', json.encode(_browsingHistory));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('最近浏览'),
        actions: [
          if (_browsingHistory.isNotEmpty)
            TextButton(
              onPressed: _clearHistory,
              child: const Text('清空', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _browsingHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      const Text('暂无浏览记录', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _browsingHistory.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _browsingHistory[index];
                    return Dismissible(
                      key: Key('browsing_${item['hotel_id']}_$index'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete_outline, color: Colors.white),
                      ),
                      onDismissed: (_) => _removeItem(index),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          onTap: () => context.push('/hotel/${item['hotel_id']}'),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: item['image'] != null
                                      ? Image.network(item['image'], width: 80, height: 60, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPlaceholder())
                                      : _buildPlaceholder(),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      if (item['address'] != null)
                                        Text(item['address'], style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (item['price'] != null)
                                            Text('¥${item['price']}', style: const TextStyle(fontSize: 14, color: AppColors.secondary, fontWeight: FontWeight.bold)),
                                          if (item['price'] != null) const Text('起', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                          const Spacer(),
                                          Text(item['browsed_at'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 80,
      height: 60,
      color: AppColors.divider,
      child: const Icon(Icons.hotel, color: AppColors.textSecondary, size: 28),
    );
  }
}
