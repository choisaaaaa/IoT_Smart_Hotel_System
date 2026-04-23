import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/utils/date_utils.dart' as app_date_utils;
import '../../core/theme/app_colors.dart';
import '../../core/network/api_result.dart';
import '../../services/room_type_service.dart';
import '../../services/price_calendar_service.dart';

class PriceCalendarPage extends ConsumerStatefulWidget {
  const PriceCalendarPage({super.key});

  @override
  ConsumerState<PriceCalendarPage> createState() => _PriceCalendarPageState();
}

class _PriceCalendarPageState extends ConsumerState<PriceCalendarPage> {
  bool _isLoading = true;
  List<dynamic> _roomTypes = [];
  int? _selectedRoomTypeId;
  DateTime _currentMonth = DateTime.now();
  List<dynamic> _priceData = [];
  Map<String, dynamic>? _memberDiscounts;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadRoomTypes(),
      _loadMemberDiscounts(),
    ]);
    if (_selectedRoomTypeId != null) {
      await _loadPriceCalendar();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadRoomTypes() async {
    final result = await ref.read(roomTypeServiceProvider).getRoomTypes();
    if (result.success && mounted) {
      setState(() {
        _roomTypes = result.data ?? [];
        if (_roomTypes.isNotEmpty && _selectedRoomTypeId == null) {
          final rawId = _roomTypes.first['id'];
          _selectedRoomTypeId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
        }
      });
    }
  }

  Future<void> _loadMemberDiscounts() async {
    final result = await ref.read(priceCalendarServiceProvider).getMemberDiscounts();
    if (result.success && mounted) {
      setState(() => _memberDiscounts = result.data);
    }
  }

  Future<void> _loadPriceCalendar() async {
    if (_selectedRoomTypeId == null) return;

    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

    final result = await ref.read(priceCalendarServiceProvider).getPriceCalendar(
      roomTypeId: _selectedRoomTypeId!,
      startDate: DateFormat('yyyy-MM-dd').format(firstDay),
      endDate: DateFormat('yyyy-MM-dd').format(lastDay),
    );

    if (result.success && mounted) {
      setState(() => _priceData = result.data ?? []);
    }
  }

  Map<String, dynamic>? _getPriceForDate(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    try {
      return _priceData.firstWhere(
        (p) => p['date'] == dateStr,
        orElse: () => null,
      );
    } catch (e) {
      return null;
    }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _loadPriceCalendar();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _loadPriceCalendar();
  }

  void _showEditDialog(DateTime date, Map<String, dynamic>? existingPrice) {
    final basePriceController = TextEditingController(
      text: existingPrice != null
          ? existingPrice['base_price'].toString()
          : _getDefaultBasePrice().toString(),
    );
    final discountController = TextEditingController(
      text: (existingPrice != null
              ? existingPrice['discount_rate']?.toString()
              : '1.0') ??
          '1.0',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${app_date_utils.DateUtils.formatShortDate(date)} 价格设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: basePriceController,
              decoration: const InputDecoration(
                labelText: '当日基准价 (元)',
                prefixText: '¥',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: discountController,
              decoration: const InputDecoration(
                labelText: '折扣率 (1.0为不打折)',
                hintText: '如: 0.85 为85折',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildPricePreview(basePriceController, discountController),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          if (existingPrice != null)
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('确认删除'),
                    content: const Text('确定要删除该日期的价格设置吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  final result = await ref
                      .read(priceCalendarServiceProvider)
                      .deletePriceForDate(existingPrice['id']);
                  if (result.success) {
                    _loadPriceCalendar();
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('删除'),
            ),
          FilledButton(
            onPressed: () async {
              final basePrice = double.tryParse(basePriceController.text) ?? 0;
              final discountRate = double.tryParse(discountController.text) ?? 1.0;

              ApiResult result;
              if (existingPrice != null) {
                result = await ref.read(priceCalendarServiceProvider).updatePriceForDate(
                  priceId: existingPrice['id'],
                  basePrice: basePrice,
                  discountRate: discountRate,
                );
              } else {
                result = await ref.read(priceCalendarServiceProvider).setPriceForDate(
                  roomTypeId: _selectedRoomTypeId!,
                  date: DateFormat('yyyy-MM-dd').format(date),
                  basePrice: basePrice,
                  discountRate: discountRate,
                );
              }

              if (result.success) {
                _loadPriceCalendar();
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('价格设置成功')),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Widget _buildPricePreview(TextEditingController baseCtrl, TextEditingController discountCtrl) {
    return StatefulBuilder(
      builder: (context, setState) {
        final basePrice = double.tryParse(baseCtrl.text) ?? 0;
        final discountRate = double.tryParse(discountCtrl.text) ?? 1.0;
        final finalPrice = basePrice * discountRate;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '价格预览',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              _buildPreviewRow('执行价 (基础)', finalPrice),
              if (_memberDiscounts != null) ...[
                const Divider(height: 16),
                ...(_memberDiscounts!.entries.map((e) {
                  double discountValue;
                  if (e.value is double) {
                    discountValue = e.value as double;
                  } else if (e.value is int) {
                    discountValue = (e.value as int).toDouble();
                  } else if (e.value is String) {
                    discountValue = double.tryParse(e.value as String) ?? 1.0;
                  } else {
                    discountValue = 1.0;
                  }
                  final levelPrice = finalPrice * discountValue;
                  return _buildPreviewRow(_getLevelLabel(e.key), levelPrice);
                })),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreviewRow(String label, double price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          Text(
            '¥${price.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _getLevelLabel(String level) {
    final labels = {
      'diamond': '钻石会员',
      'platinum': '铂金会员',
      'gold': '金卡会员',
      'silver': '银卡会员',
      'bronze': '普通会员',
    };
    return labels[level] ?? level;
  }

  double _getDefaultBasePrice() {
    final selectedType = _roomTypes.firstWhere(
      (t) => t['id'] == _selectedRoomTypeId,
      orElse: () => {'base_price': 0},
    );
    final basePrice = selectedType['base_price'];
    if (basePrice is double) return basePrice;
    if (basePrice is int) return basePrice.toDouble();
    if (basePrice is String) return double.tryParse(basePrice) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
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
          : Column(
              children: [
                _buildRoomTypeSelector(),
                _buildMonthNavigator(),
                _buildWeekdayHeader(),
                Expanded(child: _buildCalendarGrid()),
                _buildLegend(),
              ],
            ),
    );
  }

  Widget _buildRoomTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          const Text('选择房型:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _selectedRoomTypeId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _roomTypes.map((type) {
                final rawId = type['id'];
                final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
                return DropdownMenuItem<int>(
                  value: id,
                  child: Text(type['name'] ?? '未命名'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedRoomTypeId = value);
                _loadPriceCalendar();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthNavigator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previousMonth,
          ),
          Text(
            app_date_utils.DateUtils.formatMonthYear(_currentMonth),
            style: GoogleFonts.notoSansSc(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeader() {
    final weekdays = ['日', '一', '二', '三', '四', '五', '六'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.grey[100],
      child: Row(
        children: weekdays.map((day) {
          return Expanded(
            child: Center(
              child: Text(
                day,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: day == '日' || day == '六' ? Colors.red : Colors.black87,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = firstDay.weekday % 7;

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.85,
      ),
      itemCount: 42,
      itemBuilder: (context, index) {
        final dayIndex = index - firstWeekday;
        if (dayIndex < 0 || dayIndex >= daysInMonth) {
          return const SizedBox.shrink();
        }

        final date = DateTime(_currentMonth.year, _currentMonth.month, dayIndex + 1);
        final priceData = _getPriceForDate(date);
        final isToday = DateUtils.isSameDay(date, DateTime.now());

        return _CalendarDayCell(
          date: date,
          priceData: priceData,
          defaultPrice: _getDefaultBasePrice(),
          isToday: isToday,
          onTap: () => _showEditDialog(date, priceData),
        );
      },
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _LegendItem(color: Colors.blue, label: '已设置价格'),
          const SizedBox(width: 24),
          _LegendItem(color: Colors.grey, label: '默认价格'),
          const SizedBox(width: 24),
          _LegendItem(color: Colors.orange, label: '有折扣'),
        ],
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final DateTime date;
  final Map<String, dynamic>? priceData;
  final double defaultPrice;
  final bool isToday;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.date,
    required this.priceData,
    required this.defaultPrice,
    required this.isToday,
    required this.onTap,
  });

  double _parseDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomPrice = priceData != null;
    final basePrice = hasCustomPrice
        ? _parseDouble(priceData!['base_price'], 0)
        : defaultPrice;
    final discountRate = hasCustomPrice
        ? _parseDouble(priceData!['discount_rate'], 1.0)
        : 1.0;
    final finalPrice = basePrice * discountRate;
    final hasDiscount = discountRate < 1.0;

    Color borderColor;
    if (hasCustomPrice) {
      borderColor = hasDiscount ? Colors.orange : Colors.blue;
    } else {
      borderColor = Colors.grey.shade300;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isToday ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
          border: Border.all(
            color: isToday ? AppColors.primary : borderColor,
            width: isToday ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? AppColors.primary : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '¥${finalPrice.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: hasCustomPrice ? AppColors.primary : Colors.grey,
              ),
            ),
            if (hasDiscount) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${(discountRate * 10).toStringAsFixed(1)}折',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
