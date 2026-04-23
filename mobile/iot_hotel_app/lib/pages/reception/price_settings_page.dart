import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/type_utils.dart';
import '../../services/room_type_service.dart';

class PriceSettingsPage extends ConsumerStatefulWidget {
  const PriceSettingsPage({super.key});

  @override
  ConsumerState<PriceSettingsPage> createState() => _PriceSettingsPageState();
}

class _PriceSettingsPageState extends ConsumerState<PriceSettingsPage> {
  bool _isLoading = true;
  List<dynamic> _roomTypes = [];
  final Map<int, TextEditingController> _priceControllers = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(roomTypeServiceProvider).getRoomTypes();
      if (mounted) {
        setState(() {
          _roomTypes = result.success ? (result.data ?? []) : [];
        });
        // Initialize controllers for each room type
        for (final rt in _roomTypes) {
          final id = safeToInt(rt['id']);
          final price = safeToDouble(rt['base_price'] ?? rt['price']).toString();
          if (!_priceControllers.containsKey(id)) {
            _priceControllers[id] = TextEditingController(text: price);
          }
        }
      }
    } catch (e) {
      debugPrint('PriceSettings load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePrice(int roomTypeId) async {
    final controller = _priceControllers[roomTypeId];
    if (controller == null) return;

    final price = double.tryParse(controller.text);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的价格'), backgroundColor: AppColors.error),
      );
      return;
    }

    try {
      final result = await ref.read(roomTypeServiceProvider).updateRoomType(
            roomTypeId,
            {'base_price': price},
          );
      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('价格更新成功'), backgroundColor: AppColors.success),
        );
        _loadData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? '更新失败')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作失败，请重试')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('房价设置'),
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
              child: _roomTypes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hotel_outlined, size: 48, color: AppColors.textHint),
                          const SizedBox(height: 12),
                          Text('暂无房型数据', style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _roomTypes.length,
                      itemBuilder: (context, index) {
                        final rt = _roomTypes[index];
                        final id = safeToInt(rt['id']);
                        final name = rt['name']?.toString() ?? rt['code']?.toString() ?? '未知房型';
                        final currentPrice = safeToDouble(rt['base_price'] ?? rt['price']);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.bed_rounded, color: AppColors.primary, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: GoogleFonts.notoSansSc(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '当前价格: ¥${currentPrice.toStringAsFixed(0)}/晚',
                                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _priceControllers[id],
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        hintText: '输入新价格',
                                        prefixText: '¥ ',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        filled: true,
                                        fillColor: AppColors.background,
                                        contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  FilledButton(
                                    onPressed: () => _savePrice(id),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 10),
                                    ),
                                    child: const Text('保存'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
