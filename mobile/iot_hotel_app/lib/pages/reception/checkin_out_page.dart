import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../services/booking_service.dart';
import '../../services/room_service.dart';
import '../../services/coupon_service.dart';
import '../../models/booking.dart';

class CheckInOutPage extends ConsumerStatefulWidget {
  const CheckInOutPage({super.key});

  @override
  ConsumerState<CheckInOutPage> createState() => _CheckInOutPageState();
}

class _CheckInOutPageState extends ConsumerState<CheckInOutPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Booking> _todayBookings = [];
  List<dynamic> _availableRooms = [];
  bool _isLoading = true;

  final _guestNameController = TextEditingController();
  final _guestPhoneController = TextEditingController();
  final _guestIdController = TextEditingController();
  int _guestCount = 1;
  String _paymentMethod = 'front_desk';
  String _idType = 'idcard';
  DateTime _checkInDate = DateTime.now();
  DateTime _checkOutDate = DateTime.now().add(const Duration(days: 1));
  int? _selectedRoomId;
  String? _selectedRoomName;
  double? _selectedRoomPrice;
  int? _selectedCouponId;
  double _manualDiscount = 1.0;
  double _manualReduce = 0;
  List<Map<String, dynamic>> _companions = [];
  List<dynamic> _availableCoupons = [];
  Map<String, dynamic>? _memberInfo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _guestNameController.dispose();
    _guestPhoneController.dispose();
    _guestIdController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final bookingsResult = await ref.read(bookingServiceProvider).getBookings(pageSize: 50);
      final roomsResult = await ref.read(roomServiceProvider).getRooms(status: 'available', pageSize: 100);

      if (mounted) {
        final rawList = bookingsResult.success ? (bookingsResult.data ?? <Booking>[]) : <Booking>[];
        final list = rawList.whereType<Booking>().toList();
        setState(() {
          _todayBookings = list.where((b) =>
            ['pending', 'confirmed', 'pre_checked_in', 'checked_in'].contains(b.status)
          ).toList();
          _availableRooms = roomsResult.success ? (roomsResult.data ?? []) : [];
        });
      }
    } catch (e) {
      debugPrint('todayBookings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _lookupMember(String phone) async {
    if (phone.length < 11) return;
    try {
      final result = await ref.read(bookingServiceProvider).lookupBooking(phone);
      if (result.success && result.data != null) {
        final booking = result.data!;
        setState(() => _memberInfo = {
          'guest_name': booking.guestName,
          'guest_phone': booking.guestPhone,
          'member_level': booking.status,
        });
      } else {
        setState(() => _memberInfo = null);
      }
    } catch (e) {
      debugPrint('lookupMember: $e');
    }
  }

  Future<void> _loadCouponsForUser() async {
    try {
      final result = await ref.read(couponServiceProvider).getCoupons();
      if (result.success && mounted) setState(() => _availableCoupons = result.data ?? []);
    } catch (e) {
      debugPrint('loadCoupons: $e');
    }
  }

  double get _estimatedPrice {
    if (_selectedRoomPrice == null) return 0;
    final nights = _checkOutDate.difference(_checkInDate).inDays;
    if (nights <= 0) return 0;
    double base = _selectedRoomPrice! * nights;
    base = base * _manualDiscount;
    base = base - _manualReduce;
    return base < 0 ? 0 : base;
  }

  @override
  Widget build(BuildContext context) {
    final preCheckIns = _todayBookings.where((b) => b.status == 'pre_checked_in').toList();
    final checkOuts = _todayBookings.where((b) => b.status == 'checked_in').toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(text: '入住办理'),
            Tab(text: '预入住审核${preCheckIns.isNotEmpty ? '(${preCheckIns.length})' : ''}'),
            Tab(text: '退房办理${checkOuts.isNotEmpty ? '(${checkOuts.length})' : ''}'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCheckInForm(),
                _buildPreCheckinList(preCheckIns),
                _buildCheckOutList(checkOuts),
              ],
            ),
    );
  }

  Widget _buildCheckInForm() {
    final confirmedBookings = _todayBookings.where((b) => b.status == 'confirmed' || b.status == 'pending').toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGuestInfoSection(),
          const SizedBox(height: 16),
          _buildRoomSelectionSection(),
          const SizedBox(height: 16),
          _buildPriceAndCouponSection(),
          const SizedBox(height: 16),
          _buildCompanionsSection(),
          const SizedBox(height: 16),
          _buildTodayBookingsSection(confirmedBookings),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _selectedRoomId != null ? _handleCreateAndCheckin : null,
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              child: const Text('确认入住', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildGuestInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('客人信息', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _guestNameController, decoration: const InputDecoration(labelText: '客人姓名 *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)))),
              const SizedBox(width: 12),
              Expanded(child: TextField(
                controller: _guestPhoneController,
                decoration: InputDecoration(
                  labelText: '联系电话 *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone_outlined),
                  suffixIcon: _memberInfo != null
                      ? Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text(_memberInfo?['member_level'] ?? '', style: TextStyle(color: AppColors.warning, fontSize: 10)),
                        )
                      : null,
                ),
                keyboardType: TextInputType.phone,
                onChanged: (v) => _lookupMember(v),
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<String>(
                  initialValue: _idType,
                  decoration: const InputDecoration(labelText: '证件类型', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'idcard', child: Text('身份证')),
                    DropdownMenuItem(value: 'passport', child: Text('护照')),
                    DropdownMenuItem(value: 'other', child: Text('其他')),
                  ],
                  onChanged: (v) => setState(() => _idType = v ?? 'idcard'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _guestIdController, decoration: const InputDecoration(labelText: '证件号码', border: OutlineInputBorder()))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  decoration: const InputDecoration(labelText: '支付方式', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'front_desk', child: Text('前台支付')),
                    DropdownMenuItem(value: 'alipay', child: Text('支付宝')),
                    DropdownMenuItem(value: 'wechat', child: Text('微信')),
                    DropdownMenuItem(value: 'cash', child: Text('现金')),
                    DropdownMenuItem(value: 'credit_card', child: Text('银行卡')),
                  ],
                  onChanged: (v) => setState(() => _paymentMethod = v ?? 'front_desk'),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                child: DropdownButtonFormField<int>(
                  initialValue: _guestCount,
                  decoration: const InputDecoration(labelText: '人数', border: OutlineInputBorder()),
                  items: List.generate(5, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}人'))),
                  onChanged: (v) => setState(() => _guestCount = v ?? 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('入住: ${_checkInDate.month}/${_checkInDate.day}', style: GoogleFonts.notoSansSc(fontSize: 14)),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final date = await showDatePicker(context: context, initialDate: _checkInDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                  if (date != null) setState(() => _checkInDate = date);
                },
              )),
              const SizedBox(width: 12),
              Expanded(child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('退房: ${_checkOutDate.month}/${_checkOutDate.day}', style: GoogleFonts.notoSansSc(fontSize: 14)),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final date = await showDatePicker(context: context, initialDate: _checkOutDate, firstDate: _checkInDate.add(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 90)));
                  if (date != null) setState(() => _checkOutDate = date);
                },
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoomSelectionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('选择房间', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${_availableRooms.length}间可售', style: TextStyle(color: AppColors.success, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedRoomId != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.success.withValues(alpha: 0.2))),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('已选: ${_selectedRoomName ?? ''}', style: GoogleFonts.notoSansSc(fontWeight: FontWeight.w600))),
                  Text('¥${_selectedRoomPrice?.toStringAsFixed(0) ?? ''}/晚', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  GestureDetector(onTap: () => setState(() { _selectedRoomId = null; _selectedRoomName = null; _selectedRoomPrice = null; }), child: const Icon(Icons.close, size: 18, color: AppColors.textHint)),
                ],
              ),
            )
          else if (_availableRooms.isEmpty)
            Center(child: Text('暂无可用房间', style: TextStyle(color: AppColors.textSecondary)))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableRooms.length > 5 ? 5 : _availableRooms.length,
                    itemBuilder: (context, index) {
                      final room = _availableRooms[index];
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedRoomId = room['id'] as int;
                          _selectedRoomName = '${room['room_number']}号房 · ${room['room_name'] ?? '标准间'}';
                          _selectedRoomPrice = double.tryParse(room['room_price']?.toString() ?? room['base_price']?.toString() ?? '0') ?? 0;
                        }),
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.divider)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${room['room_number']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('${room['room_name'] ?? '标准间'}', style: TextStyle(color: AppColors.textSecondary, fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 1),
                              const SizedBox(height: 4),
                              Text('¥${room['room_price'] ?? room['base_price'] ?? '-'}/晚', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_availableRooms.length > 5) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showRoomSelectionDialog(),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('滑动查看更多 (${_availableRooms.length - 5}间)', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                          const Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPriceAndCouponSection() {
    final nights = _checkOutDate.difference(_checkInDate).inDays;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('费用与优惠', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_selectedRoomPrice != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('¥${_selectedRoomPrice?.toStringAsFixed(0) ?? '0'} × $nights晚', style: TextStyle(color: AppColors.textSecondary)),
                Text('¥${(_selectedRoomPrice! * nights).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _selectedCouponId,
                  decoration: const InputDecoration(labelText: '优惠券', border: OutlineInputBorder(), isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('不使用优惠券')),
                    ..._availableCoupons.map<DropdownMenuItem<int?>>((c) => DropdownMenuItem(value: c['id'] as int, child: Text('${c['coupon_name'] ?? c['name'] ?? '优惠券'}'))),
                  ],
                  onChanged: (v) => setState(() => _selectedCouponId = v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(onPressed: _loadCouponsForUser, icon: const Icon(Icons.refresh, size: 20)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextField(
                decoration: const InputDecoration(labelText: '折扣率(0-1)', border: OutlineInputBorder(), isDense: true),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: _manualDiscount.toString()),
                onChanged: (v) => setState(() => _manualDiscount = double.tryParse(v) ?? 1.0),
              )),
              const SizedBox(width: 12),
              Expanded(child: TextField(
                decoration: const InputDecoration(labelText: '立减金额', border: OutlineInputBorder(), isDense: true, prefixText: '¥'),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: _manualReduce.toStringAsFixed(0)),
                onChanged: (v) => setState(() => _manualReduce = double.tryParse(v) ?? 0),
              )),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('预估应付', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('¥${_estimatedPrice.toStringAsFixed(2)}', style: GoogleFonts.notoSansSc(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompanionsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('同住人 (${_companions.length})', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton.icon(onPressed: _addCompanion, icon: const Icon(Icons.add, size: 18), label: const Text('添加')),
            ],
          ),
          if (_companions.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._companions.asMap().entries.map((entry) {
              final i = entry.key;
              final c = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  title: Text('${c['name'] ?? ''} · ${c['phone'] ?? ''}'),
                  subtitle: c['id_number'] != null ? Text('${c['id_number']}', style: const TextStyle(fontSize: 12)) : null,
                  trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error), onPressed: () => setState(() => _companions.removeAt(i))),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  void _addCompanion() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    String idType = 'idcard';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加同住人'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '姓名 *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: '手机号', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: idType,
              decoration: const InputDecoration(labelText: '证件类型', border: OutlineInputBorder()),
              items: const [DropdownMenuItem(value: 'idcard', child: Text('身份证')), DropdownMenuItem(value: 'passport', child: Text('护照'))],
              onChanged: (v) => idType = v ?? 'idcard',
            ),
            const SizedBox(height: 12),
            TextField(controller: idCtrl, decoration: const InputDecoration(labelText: '证件号码', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () {
            if (nameCtrl.text.isNotEmpty) {
              setState(() => _companions.add({'name': nameCtrl.text, 'phone': phoneCtrl.text, 'id_type': idType, 'id_number': idCtrl.text}));
            }
            Navigator.pop(ctx);
          }, child: const Text('添加')),
        ],
      ),
    );
  }

  Widget _buildTodayBookingsSection(List<Booking> confirmedBookings) {
    if (confirmedBookings.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('今日待入住预订 (${confirmedBookings.length})', style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...confirmedBookings.take(5).map((b) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(radius: 14, backgroundColor: AppColors.success, child: Icon(Icons.assignment_turned_in, size: 14, color: Colors.white)),
            title: Text('${b.guestName ?? '-'} · ${b.roomNumber ?? '${b.roomId}号房'}', style: GoogleFonts.notoSansSc(fontSize: 13)),
            subtitle: Text(b.guestPhone ?? '', style: const TextStyle(fontSize: 11)),
            trailing: FilledButton.tonal(
              onPressed: () => _handleQuickCheckin(b),
              style: FilledButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(60, 32)),
              child: const Text('入住', style: TextStyle(fontSize: 12)),
            ),
          )),
        ],
      ),
    );
  }

  Future<void> _handleQuickCheckin(Booking booking) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('确认入住'),
      content: Text('客人：${booking.guestName ?? '-'}，房间：${booking.roomNumber ?? '${booking.roomId}号房'}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: AppColors.success), child: const Text('确认')),
      ],
    ));
    if (confirm != true) return;

    try {
      final result = await ref.read(bookingServiceProvider).checkin(
        booking.id,
        guestName: booking.guestName,
        guestPhone: booking.guestPhone,
        guestIdNumber: booking.guestIdNumber,
      );
      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('入住办理成功'), backgroundColor: AppColors.success));
        _loadData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '操作失败')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
    }
  }

  Future<void> _handleCreateAndCheckin() async {
    if (_guestNameController.text.isEmpty || _guestPhoneController.text.isEmpty || _selectedRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写客人姓名、电话并选择房间')));
      return;
    }

    try {
      final createResult = await ref.read(bookingServiceProvider).createBooking({
        'guest_name': _guestNameController.text,
        'guest_phone': _guestPhoneController.text,
        'guest_id_number': _guestIdController.text.isEmpty ? null : _guestIdController.text,
        'id_type': _idType,
        'room_id': _selectedRoomId,
        'guest_count': _guestCount,
        'check_in_date': _checkInDate.toIso8601String().split('T')[0],
        'check_out_date': _checkOutDate.toIso8601String().split('T')[0],
        'payment_method': _paymentMethod,
        'coupon_id': _selectedCouponId,
        'companions': _companions.isNotEmpty ? _companions : null,
      });

      if (createResult.success && createResult.data != null) {
        final bookingId = createResult.data!.id;
        final checkinResult = await ref.read(bookingServiceProvider).checkin(
          bookingId,
          guestName: _guestNameController.text,
          guestPhone: _guestPhoneController.text,
          guestIdNumber: _guestIdController.text.isNotEmpty ? _guestIdController.text : null,
        );
        if (checkinResult.success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('入住办理成功'), backgroundColor: AppColors.success));
          _resetForm();
          _loadData();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(checkinResult.message ?? '入住失败，请手动办理')));
          _loadData();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(createResult.message ?? '创建预订失败')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
    }
  }

  void _resetForm() {
    _guestNameController.clear();
    _guestPhoneController.clear();
    _guestIdController.clear();
    setState(() {
      _selectedRoomId = null;
      _selectedRoomName = null;
      _selectedRoomPrice = null;
      _selectedCouponId = null;
      _manualDiscount = 1.0;
      _manualReduce = 0;
      _companions = [];
      _memberInfo = null;
      _guestCount = 1;
      _paymentMethod = 'front_desk';
      _idType = 'idcard';
      _checkInDate = DateTime.now();
      _checkOutDate = DateTime.now().add(const Duration(days: 1));
    });
  }

  Widget _buildPreCheckinList(List<Booking> bookings) {
    if (bookings.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle_outline, size: 48, color: AppColors.textHint.withValues(alpha: 0.3)), const SizedBox(height: 12), const Text('暂无预入住申请', style: TextStyle(color: AppColors.textSecondary))]));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final b = bookings[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${b.roomNumber ?? b.roomId.toString()}号房 · ${b.roomType ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Text('待审核', style: TextStyle(fontSize: 12, color: AppColors.warning))),
              ]),
              const SizedBox(height: 8),
              Text('客人：${b.guestName ?? '-'}  ${b.guestPhone ?? ''}', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              if (b.guestIdNumber != null) ...[
                const SizedBox(height: 4),
                Text('身份证号：${b.guestIdNumber}', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => _handlePreCheckinReview(b, false), style: OutlinedButton.styleFrom(foregroundColor: AppColors.error), child: const Text('拒绝'))),
                  const SizedBox(width: 12),
                  Expanded(child: FilledButton(onPressed: () => _handlePreCheckinReview(b, true), style: FilledButton.styleFrom(backgroundColor: AppColors.success), child: const Text('审核通过'))),
                ],
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildCheckOutList(List<Booking> bookings) {
    if (bookings.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.logout_outlined, size: 48, color: AppColors.textHint.withValues(alpha: 0.3)), const SizedBox(height: 12), const Text('暂无待退房订单', style: TextStyle(color: AppColors.textSecondary))]));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final b = bookings[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${b.roomNumber ?? b.roomId.toString()}号房 · ${b.roomType ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Text('在住', style: TextStyle(fontSize: 12, color: AppColors.info))),
              ]),
              const SizedBox(height: 8),
              Text('客人：${b.guestName ?? '-'}  ${b.guestPhone ?? ''}', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 4),
              Text('入住: ${b.checkInDate.month}/${b.checkInDate.day} ~ 退房: ${b.checkOutDate.month}/${b.checkOutDate.day}', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 40, child: FilledButton(
                onPressed: () => _handleAction(b),
                style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
                child: const Text('办理退房'),
              )),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _handlePreCheckinReview(Booking booking, bool approved) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approved ? '确认通过审核' : '确认拒绝'),
        content: Text('客人：${booking.guestName ?? '-'}，房间：${booking.roomNumber ?? '${booking.roomId}号房'}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: approved ? AppColors.success : AppColors.error), child: Text(approved ? '确认通过' : '确认拒绝')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      if (approved) {
        final result = await ref.read(bookingServiceProvider).checkin(
          booking.id,
          guestName: booking.guestName,
          guestPhone: booking.guestPhone,
          guestIdNumber: booking.guestIdNumber,
        );
        if (result.success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('审核通过，入住办理成功'), backgroundColor: AppColors.success));
          _loadData();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '操作失败')));
        }
      } else {
        final result = await ref.read(bookingServiceProvider).rejectPreCheckin(booking.id);
        if (result.success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已拒绝预入住申请')));
          _loadData();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '操作失败')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
    }
  }

  Future<void> _handleAction(Booking booking) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('确认退房'),
      content: Text('客人：${booking.guestName ?? '-'}，房间：${booking.roomNumber ?? '${booking.roomId}号房'}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: AppColors.warning), child: const Text('确认退房')),
      ],
    ));
    if (confirm != true) return;

    try {
      final result = await ref.read(bookingServiceProvider).checkout(booking.id);
      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('退房办理成功'), backgroundColor: AppColors.success));
        _loadData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '操作失败')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
    }
  }

  void _showRoomSelectionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('选择房间', style: GoogleFonts.notoSansSc(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('共${_availableRooms.length}间可售', style: TextStyle(color: AppColors.success, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.2, crossAxisSpacing: 8, mainAxisSpacing: 8),
                  itemCount: _availableRooms.length,
                  itemBuilder: (context, index) {
                    final room = _availableRooms[index];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRoomId = room['id'] as int;
                          _selectedRoomName = '${room['room_number']}号房 · ${room['room_name'] ?? '标准间'}';
                          _selectedRoomPrice = double.tryParse(room['room_price']?.toString() ?? room['base_price']?.toString() ?? '0') ?? 0;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.divider)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${room['room_number']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('${room['room_name'] ?? '标准间'}', style: TextStyle(color: AppColors.textSecondary, fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 1),
                            const SizedBox(height: 4),
                            Text('¥${room['room_price'] ?? room['base_price'] ?? '-'}/晚', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
