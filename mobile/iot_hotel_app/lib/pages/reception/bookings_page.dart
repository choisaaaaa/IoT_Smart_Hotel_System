import 'package:flutter/material.dart' hide DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/utils/date_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../services/booking_service.dart';
import '../../models/booking.dart';

class BookingsPage extends ConsumerStatefulWidget {
  const BookingsPage({super.key});
  @override
  ConsumerState<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends ConsumerState<BookingsPage> {
  List<Booking> _bookings = [];
  bool _isLoading = true;
  String _filterStatus = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(bookingServiceProvider).getBookings(status: _filterStatus == 'all' ? null : _filterStatus, pageSize: 50);
      if (result.success && mounted) setState(() => _bookings = result.data ?? []);
    } catch (e) {
      debugPrint('✗ bookings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Booking> get _filteredBookings {
    if (_searchQuery.isEmpty) return _bookings;
    return _bookings.where((b) {
      final q = _searchQuery.toLowerCase();
      return (b.guestName ?? '').toLowerCase().contains(q) ||
          (b.bookingNumber ?? '').toLowerCase().contains(q) ||
          (b.guestPhone ?? '').toLowerCase().contains(q);
    }).toList();
  }

  String _statusText(String? s) => switch (s) { 'pending' => '待支付', 'confirmed' => '待入住', 'pre_checked_in' => '预入住', 'checked_in' => '已入住', 'checked_out' => '已完成', 'cancelled' => '已取消', 'paid' => '已支付', _ => s ?? '未知' };
  Color _statusColor(String? s) => switch (s) { 'pending' => Colors.orange, 'confirmed' => AppColors.primary, 'pre_checked_in' => Colors.cyan, 'checked_in' => AppColors.success, 'checked_out' => AppColors.textSecondary, 'cancelled' => AppColors.error, 'paid' => AppColors.success, _ => AppColors.textHint };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('预订管理'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadBookings),
        ],
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          color: Colors.white,
          child: TextField(
            decoration: InputDecoration(
              hintText: '搜索预订号/客人名/手机号',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(children: ['all', 'pending', 'confirmed', 'pre_checked_in', 'checked_in', 'checked_out', 'cancelled'].map((s) => Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(label: Text(s == 'all' ? '全部' : _statusText(s)), selected: _filterStatus == s, onSelected: (_) => setState(() { _filterStatus = s; _loadBookings(); })))).toList())),
        Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : _filteredBookings.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.calendar_month_outlined, size: 48, color: AppColors.textHint.withValues(alpha: 0.3)), const SizedBox(height: 12), const Text('暂无预订', style: TextStyle(color: AppColors.textSecondary))])) : RefreshIndicator(onRefresh: _loadBookings, child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: _filteredBookings.length, itemBuilder: (context, i) {
          final b = _filteredBookings[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('${b.guestName ?? '-'} · ${b.roomType ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _statusColor(b.status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(_statusText(b.status), style: TextStyle(color: _statusColor(b.status), fontSize: 12))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(b.guestPhone ?? '-', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(width: 16),
                      Icon(Icons.hotel, size: 14, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(b.roomNumber ?? '${b.roomId}号房', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text('${DateUtils.formatDotDate(b.checkInDate)} ~ ${DateUtils.formatDotDate(b.checkOutDate)}', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const Spacer(),
                      Text('¥${b.totalPrice.toStringAsFixed(0)}', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  if (b.bookingNumber != null) ...[
                    const SizedBox(height: 4),
                    Text('预订号: ${b.bookingNumber}', style: TextStyle(color: AppColors.textHint, fontSize: 11)),
                  ],
                  _buildActionButtons(b),
                ],
              ),
            ),
          );
        }))),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateBookingDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('新建预订'),
      ),
    );
  }

  Widget _buildActionButtons(Booking b) {
    final actions = <Widget>[];
    switch (b.status) {
      case 'pending':
        actions.addAll([
          TextButton(onPressed: () => _cancelBooking(b), style: TextButton.styleFrom(foregroundColor: AppColors.error), child: const Text('取消')),
          FilledButton(onPressed: () => _confirmBooking(b), style: FilledButton.styleFrom(backgroundColor: AppColors.success), child: const Text('确认预订')),
        ]);
      case 'confirmed':
        actions.addAll([
          TextButton(onPressed: () => _cancelBooking(b), style: TextButton.styleFrom(foregroundColor: AppColors.error), child: const Text('取消')),
          FilledButton(onPressed: () => _handleCheckin(b), style: FilledButton.styleFrom(backgroundColor: AppColors.success), child: const Text('办理入住')),
        ]);
      case 'pre_checked_in':
        actions.addAll([
          TextButton(onPressed: () => _rejectPreCheckin(b), style: TextButton.styleFrom(foregroundColor: AppColors.error), child: const Text('拒绝')),
          FilledButton(onPressed: () => _handleCheckin(b), style: FilledButton.styleFrom(backgroundColor: AppColors.success), child: const Text('审核通过')),
        ]);
      case 'checked_in':
        actions.add(FilledButton(onPressed: () => _handleCheckout(b), style: FilledButton.styleFrom(backgroundColor: AppColors.warning), child: const Text('办理退房')));
      default:
        break;
    }
    if (actions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
    );
  }

  Future<void> _confirmBooking(Booking b) async {
    try {
      final result = await ref.read(bookingServiceProvider).confirmBooking(b.id);
      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('预订已确认'), backgroundColor: AppColors.success));
        _loadBookings();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '操作失败')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
    }
  }

  Future<void> _cancelBooking(Booking b) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('确认取消'),
      content: Text('确定要取消 ${b.guestName ?? '-'} 的预订吗？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('返回')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: AppColors.error), child: const Text('确认取消')),
      ],
    ));
    if (confirm != true) return;

    try {
      final result = await ref.read(bookingServiceProvider).cancelBooking(b.id);
      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('取消成功'), backgroundColor: AppColors.success));
        _loadBookings();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '操作失败')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
    }
  }

  Future<void> _handleCheckin(Booking b) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('确认入住'),
      content: Text('客人：${b.guestName ?? '-'}，房间：${b.roomNumber ?? '${b.roomId}号房'}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: AppColors.success), child: const Text('确认')),
      ],
    ));
    if (confirm != true) return;

    try {
      final result = await ref.read(bookingServiceProvider).checkin(b.id);
      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('入住办理成功'), backgroundColor: AppColors.success));
        _loadBookings();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '操作失败')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
    }
  }

  Future<void> _rejectPreCheckin(Booking b) async {
    try {
      final result = await ref.read(bookingServiceProvider).rejectPreCheckin(b.id);
      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已拒绝预入住申请')));
        _loadBookings();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '操作失败')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
    }
  }

  Future<void> _handleCheckout(Booking b) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('确认退房'),
      content: Text('客人：${b.guestName ?? '-'}，房间：${b.roomNumber ?? '${b.roomId}号房'}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: AppColors.warning), child: const Text('确认退房')),
      ],
    ));
    if (confirm != true) return;

    try {
      final result = await ref.read(bookingServiceProvider).checkout(b.id);
      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('退房办理成功'), backgroundColor: AppColors.success));
        _loadBookings();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '操作失败')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
    }
  }

  void _showCreateBookingDialog() {
    final guestNameCtrl = TextEditingController();
    final guestPhoneCtrl = TextEditingController();
    final remarkCtrl = TextEditingController();
    DateTime checkIn = DateTime.now();
    DateTime checkOut = DateTime.now().add(const Duration(days: 1));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('新建预订', style: GoogleFonts.notoSansSc(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ]),
                  const SizedBox(height: 16),
                  TextField(controller: guestNameCtrl, decoration: const InputDecoration(labelText: '客人姓名 *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline))),
                  const SizedBox(height: 12),
                  TextField(controller: guestPhoneCtrl, decoration: const InputDecoration(labelText: '联系电话 *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_outlined)), keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text('入住: ${checkIn.month}/${checkIn.day}'), trailing: const Icon(Icons.calendar_today, size: 18), onTap: () async {
                      final date = await showDatePicker(context: ctx, initialDate: checkIn, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                      if (date != null) setModalState(() => checkIn = date);
                    })),
                    Expanded(child: ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text('退房: ${checkOut.month}/${checkOut.day}'), trailing: const Icon(Icons.calendar_today, size: 18), onTap: () async {
                      final date = await showDatePicker(context: ctx, initialDate: checkOut, firstDate: checkIn.add(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 90)));
                      if (date != null) setModalState(() => checkOut = date);
                    })),
                  ]),
                  const SizedBox(height: 12),
                  TextField(controller: remarkCtrl, decoration: const InputDecoration(labelText: '备注', border: OutlineInputBorder()), maxLines: 2),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () async {
                      if (guestNameCtrl.text.isEmpty || guestPhoneCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写客人姓名和电话')));
                        return;
                      }
                      try {
                        final result = await ref.read(bookingServiceProvider).createBooking({
                          'guest_name': guestNameCtrl.text,
                          'guest_phone': guestPhoneCtrl.text,
                          'check_in_date': checkIn.toIso8601String().split('T')[0],
                          'check_out_date': checkOut.toIso8601String().split('T')[0],
                          'special_requests': remarkCtrl.text.isEmpty ? null : remarkCtrl.text,
                          'payment_method': 'front_desk',
                        });
                        if (result.success && mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('预订创建成功'), backgroundColor: AppColors.success));
                          _loadBookings();
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '创建失败')));
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('创建失败，请重试')));
                      }
                    },
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('创建预订'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
