import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../../services/room_type_service.dart';

class BookingPage extends ConsumerStatefulWidget {
  const BookingPage({super.key});

  @override
  ConsumerState<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends ConsumerState<BookingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            stretch: true,
            actions: [
              IconButton(
                icon: Icon(Icons.logout_rounded,
                    color:
                        innerBoxIsScrolled ? AppColors.textPrimary : Colors.white),
                onPressed: () async {
                  await ref.read(authServiceProvider).logout();
                  if (!context.mounted) return;
                  context.go('/login');
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text('客房预订',
                  style: GoogleFonts.notoSansSc(
                    color: innerBoxIsScrolled
                        ? AppColors.textPrimary
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                  )),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryLight],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        Text('欢迎来到智联酒店',
                            style: GoogleFonts.notoSansSc(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('智能客房体验，尽在指尖',
                            style: GoogleFonts.notoSansSc(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: '预订房间'),
                  Tab(text: '热门推荐'),
                  Tab(text: '我的订单'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: const [
            _BookingForm(),
            _PopularRooms(),
            _MyBookings(),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

class _BookingForm extends ConsumerStatefulWidget {
  const _BookingForm();
  @override
  ConsumerState<_BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends ConsumerState<_BookingForm> {
  DateTime? _checkInDate = DateTime.now().add(const Duration(days: 1));
  DateTime? _checkOutDate = DateTime.now().add(const Duration(days: 2));
  String? _roomType;
  int _guests = 1;
  List<dynamic> _roomTypes = [];
  bool _isLoadingRoomTypes = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRoomTypes();
  }

  Future<void> _loadRoomTypes() async {
    try {
      final result =
          await ref.read(roomTypeServiceProvider).getRoomTypes();
      if (result.success && mounted) {
        setState(() {
          _roomTypes = result.data ?? [];
          _isLoadingRoomTypes = false;
          if (_roomTypes.isNotEmpty && _roomType == null) {
            _roomType = _roomTypes[0]['type_code']?.toString() ??
                _roomTypes[0]['id']?.toString();
          }
        });
      } else if (mounted) {
        setState(() => _isLoadingRoomTypes = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRoomTypes = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('🗓️ 入住时间'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildDateCard(
                      '入住日期', _checkInDate, (d) => setState(() {
                        _checkInDate = d;
                        if (_checkOutDate != null && _checkOutDate!.isBefore(_checkInDate!)) {
                          _checkOutDate = d.add(const Duration(days: 1));
                        }
                      }))),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildDateCard(
                      '退房日期', _checkOutDate, (d) => setState(() => _checkOutDate = d))),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('🏨 房型选择'),
          const SizedBox(height: 12),
          _isLoadingRoomTypes
              ? const Center(
                  child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ))
              : _roomTypes.isEmpty
                  ? const Text('暂无可用房型', style: TextStyle(color: AppColors.textSecondary))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _roomTypes.map((rt) {
                        final code = rt['type_code']?.toString() ?? rt['id']?.toString() ?? '';
                        final name = rt['type_name'] ?? rt['name'] ?? '未知';
                        return _buildChoiceChip(name, code);
                      }).toList(),
                    ),
          const SizedBox(height: 24),
          _buildSectionTitle('👥 入住人数'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('人数', style: TextStyle(fontSize: 16)),
                Row(
                  children: [
                    IconButton(
                        onPressed:
                            _guests > 1 ? () => setState(() => _guests--) : null,
                        icon: const Icon(Icons.remove_circle_outline)),
                    Text('$_guests',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                        onPressed: _guests < 4
                            ? () => setState(() => _guests++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline,
                            color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('👤 联系信息'),
          const SizedBox(height: 12),
          TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                  labelText: '姓名', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 16),
          TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                  labelText: '手机号', prefixIcon: Icon(Icons.phone_outlined))),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _submitBooking,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16))),
              child: const Text('立即预订',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: GoogleFonts.notoSansSc(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary));
  }

  Widget _buildDateCard(
      String label, DateTime? date, Function(DateTime) onSelected) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
            context: context,
            initialDate: date ?? DateTime.now(),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365)));
        if (d != null) onSelected(d);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(date != null ? DateFormat('MM-dd').format(date) : '请选择',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String label, String value) {
    final isSelected = _roomType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (v) => setState(() => _roomType = v ? value : null),
      selectedColor: AppColors.primary.withValues(alpha: 0.1),
      labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
              color: isSelected ? AppColors.primary : Colors.grey.shade300)),
      showCheckmark: false,
      backgroundColor: Colors.white,
    );
  }

  void _submitBooking() async {
    if (_checkInDate == null ||
        _checkOutDate == null ||
        _nameController.text.isEmpty ||
        _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('请填写完整的预订信息'),
          behavior: SnackBarBehavior.floating));
      return;
    }

    try {
      final result = await ref.read(bookingServiceProvider).createBooking({
        'hotel_id': 1,
        'room_type': _roomType,
        'guest_name': _nameController.text.trim(),
        'guest_phone': _phoneController.text.trim(),
        'guest_count': _guests,
        'check_in_date': DateFormat('yyyy-MM-dd').format(_checkInDate!),
        'check_out_date': DateFormat('yyyy-MM-dd').format(_checkOutDate!),
      });

      if (!mounted) return;

      if (result.success) {
        final bookingData = result.data ?? {};
        final bookingId = bookingData['id'] ?? bookingData['booking_id'];
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('预订成功'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('预订编号：${bookingData['booking_no'] ?? bookingId ?? '-'}'),
                const SizedBox(height: 8),
                Text('${_nameController.text} · ${_phoneController.text}'),
                const SizedBox(height: 4),
                Text('${DateFormat('yyyy-MM-dd').format(_checkInDate!)} ~ ${DateFormat('yyyy-MM-dd').format(_checkOutDate!)}'),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/orders');
                  },
                  child: const Text('查看订单')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('确定')),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? '预订失败，请重试')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('预订异常：$e')));
      }
    }
  }
}

class _PopularRooms extends ConsumerStatefulWidget {
  const _PopularRooms();
  @override
  ConsumerState<_PopularRooms> createState() => _PopularRoomsState();
}

class _PopularRoomsState extends ConsumerState<_PopularRooms> {
  List<dynamic> _roomTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoomTypes();
  }

  Future<void> _loadRoomTypes() async {
    try {
      final result =
          await ref.read(roomTypeServiceProvider).getRoomTypes();
      if (result.success && mounted) {
        setState(() {
          _roomTypes = result.data ?? [];
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_roomTypes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hotel_outlined, size: 48, color: AppColors.textHint.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            const Text('暂无可用房型', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRoomTypes,
      child: ListView.builder(
        itemCount: _roomTypes.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, i) {
          final rt = _roomTypes[i];
          final name = rt['type_name'] ?? rt['name'] ?? '未知房型';
          final price = rt['base_price'] ?? rt['price'] ?? 0;
          final desc = rt['description'] ?? rt['facilities'] ?? '';
          final maxGuests = rt['max_occupancy'] ?? rt['capacity'] ?? 2;
          final bedType = rt['bed_type'] ?? rt['bed_type_name'] ?? '';
          final icon = _roomIcon(name);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/hotels/1'),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(12)),
                        child: Center(
                            child: Text(icon,
                                style: const TextStyle(fontSize: 36)))),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          if (bedType.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(bedType, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textHint), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                          const SizedBox(height: 4),
                          Text('¥$price/晚',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.secondary)),
                          Text('最多$maxGuests人',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textHint)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textHint),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _roomIcon(String name) {
    if (name.contains('总统') || name.contains('豪华')) return '🏰';
    if (name.contains('套房')) return '🏠';
    if (name.contains('大床')) return '🛌';
    return '🛏️';
  }
}

class _MyBookings extends ConsumerStatefulWidget {
  const _MyBookings();
  @override
  ConsumerState<_MyBookings> createState() => _MyBookingsState();
}

class _MyBookingsState extends ConsumerState<_MyBookings> {
  List<dynamic> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    try {
      final result =
          await ref.read(bookingServiceProvider).getBookings(pageSize: 50);
      if (result.success && mounted) {
        final data = result.data;
        List<dynamic> list = [];
        if (data != null && data.containsKey('list')) {
          list = List<dynamic>.from(data['list'] ?? []);
        } else if (data != null && data.containsKey('items')) {
          list = List<dynamic>.from(data['items'] ?? []);
        }
        setState(() {
          _bookings = list;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String? s) => switch (s?.toLowerCase()) {
        'confirmed' => AppColors.success,
        'pending' => AppColors.warning,
        'pre_checked_in' => AppColors.info,
        'checked_in' => AppColors.primary,
        'checked_out' => AppColors.textSecondary,
        'cancelled' => AppColors.error,
        _ => AppColors.textHint,
      };

  String _statusText(String? s) => switch (s?.toLowerCase()) {
        'confirmed' => '已支付',
        'pending' => '待付款',
        'pre_checked_in' => '待确认',
        'checked_in' => '已入住',
        'checked_out' => '已退房',
        'cancelled' => '已取消',
        _ => s ?? '未知',
      };

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textHint.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            const Text('暂无订单记录', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            FilledButton.tonal(
                onPressed: () => context.push('/hotels/1'),
                child: const Text('去预订')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: ListView.builder(
        itemCount: _bookings.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, i) {
          final b = _bookings[i];
          final status = b['status']?.toString() ?? '';
          final roomNumber = b['room_number'] ?? '-';
          final roomType = b['room_type'] ?? b['room_name'] ?? '';
          final checkIn = b['check_in_date'] ?? b['check_in'] ?? '';
          final checkOut = b['check_out_date'] ?? b['check_out'] ?? '';
          final guestName = b['guest_name'] ?? '';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/orders/${b['id']}'),
              child: ListTile(
                isThreeLine: true,
                leading: const Icon(Icons.bed, size: 32, color: AppColors.primary),
                title: Text('$roomNumber号房 · $roomType',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (guestName.isNotEmpty) Text(guestName),
                    Text('$checkIn ~ $checkOut'),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_statusText(status),
                          style: TextStyle(
                              fontSize: 11, color: _statusColor(status))),
                    ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
              ),
            ),
          );
        },
      ),
    );
  }
}
