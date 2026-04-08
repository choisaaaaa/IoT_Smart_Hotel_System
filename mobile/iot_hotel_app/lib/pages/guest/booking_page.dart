import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../routes/app_router.dart';

class BookingPage extends ConsumerStatefulWidget {
  const BookingPage({super.key});

  @override
  ConsumerState<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends ConsumerState<BookingPage> with SingleTickerProviderStateMixin {
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
                icon: Icon(Icons.logout_rounded, color: innerBoxIsScrolled ? AppColors.textPrimary : Colors.white),
                onPressed: () async {
                  await ref.read(authServiceProvider).logout();
                  if (context.mounted) context.go('/login');
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text('客房预订', 
                style: GoogleFonts.notoSansSc(
                  color: innerBoxIsScrolled ? AppColors.textPrimary : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                          style: GoogleFonts.notoSansSc(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('智能客房体验，尽在指尖', 
                          style: GoogleFonts.notoSansSc(color: Colors.white.withOpacity(0.8), fontSize: 14)),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: _tabBar);
  }
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

class _BookingForm extends StatefulWidget {
  const _BookingForm();
  @override
  State<_BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends State<_BookingForm> {
  DateTime? _checkInDate = DateTime.now().add(const Duration(days: 1));
  DateTime? _checkOutDate = DateTime.now().add(const Duration(days: 2));
  String? _roomType = 'standard';
  int _guests = 1;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

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
              Expanded(child: _buildDateCard('入住日期', _checkInDate, (d) => setState(() => _checkInDate = d))),
              const SizedBox(width: 12),
              Expanded(child: _buildDateCard('退房日期', _checkOutDate, (d) => setState(() => _checkOutDate = d))),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('🏨 房型选择'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChoiceChip('标准间', 'standard'),
              _buildChoiceChip('豪华间', 'deluxe'),
              _buildChoiceChip('套房', 'suite'),
              _buildChoiceChip('总统套房', 'presidential'),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('👥 入住人数'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('人数', style: TextStyle(fontSize: 16)),
                Row(
                  children: [
                    IconButton(onPressed: _guests > 1 ? () => setState(() => _guests--) : null, icon: const Icon(Icons.remove_circle_outline)),
                    Text('$_guests', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: _guests < 4 ? () => setState(() => _guests++) : null, icon: const Icon(Icons.add_circle_outline, color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('👤 联系信息'),
          const SizedBox(height: 12),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: '姓名', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 16),
          TextField(controller: _phoneController, decoration: const InputDecoration(labelText: '手机号', prefixIcon: Icon(Icons.phone_outlined))),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _submitBooking,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text('立即预订', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: GoogleFonts.notoSansSc(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary));
  }

  Widget _buildDateCard(String label, DateTime? date, Function(DateTime) onSelected) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(context: context, initialDate: date ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
        if (d != null) onSelected(d);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(date != null ? DateFormat('MM-dd').format(date) : '请选择', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
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
      selectedColor: AppColors.primary.withOpacity(0.1),
      labelStyle: TextStyle(color: isSelected ? AppColors.primary : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSelected ? AppColors.primary : Colors.grey.shade300)),
      showCheckmark: false,
      backgroundColor: Colors.white,
    );
  }

  void _submitBooking() {
    if (_checkInDate == null || _checkOutDate == null || _nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写完整的预订信息'), behavior: SnackBarBehavior.floating));
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('预订成功'),
        content: const Text('您的预订申请已提交，请等待前台确认。'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('确定'))],
      ),
    );
  }
}

class _PopularRooms extends StatelessWidget {
  const _PopularRooms();

  @override
  Widget build(BuildContext context) {
    final rooms = [
      {'name': '标准间', 'price': 388, 'img': '🛏️', 'amenities': ['WiFi', '早餐']},
      {'name': '大床房', 'price': 588, 'img': '🛌', 'amenities': ['WiFi', '早餐', '迷你吧']},
      {'name': '套房', 'price': 1288, 'img': '🏠', 'amenities': ['WiFi', '早餐', '客厅', '迷你吧']},
      {'name': '豪华套房', 'price': 2088, 'img': '🏰', 'amenities': ['WiFi', '早餐', '客厅', '行政酒廊']},
    ];
    return ListView.builder(itemCount: rooms.length, padding: const EdgeInsets.all(16), itemBuilder: (context, i) {
      final r = rooms[i];
      return Card(
        margin: const EdgeInsets.only(bottom: 12), 
        child: Padding(
          padding: const EdgeInsets.all(14), 
          child: Row(
            children: [
              Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(r['img'] as String, style: const TextStyle(fontSize: 36)))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['name'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('¥${r['price']}/晚', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.secondary)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, children: (r['amenities'] as List).map((a) => Chip(label: Text(a as String, style: const TextStyle(fontSize: 11)), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact)).toList()),
              ])),
            ],
          ),
        ),
      );
    });
  }
}

class _MyBookings extends StatelessWidget {
  const _MyBookings();

  @override
  Widget build(BuildContext context) {
    final bookings = [
      {'room': '101号房', 'type': '标准间', 'status': 'confirmed', 'checkIn': '2026-04-10', 'checkOut': '2026-04-12'},
      {'room': '201号房', 'type': '大床房', 'status': 'pending', 'checkIn': '2026-04-15', 'checkOut': '2026-04-17'},
    ];
    return ListView.builder(itemCount: bookings.length, padding: const EdgeInsets.all(16), itemBuilder: (context, i) {
      final b = bookings[i];
      final isConfirmed = b['status'] == 'confirmed';
      return Card(
        margin: const EdgeInsets.only(bottom: 12), 
        child: ListTile(
          isThreeLine: true, 
          leading: const Icon(Icons.bed, size: 32, color: AppColors.primary), 
          title: Text(b['room'] as String, style: const TextStyle(fontWeight: FontWeight.bold)), 
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              Text('${b['type']} · ${b['checkIn']} ~ ${b['checkOut']}'),
              Container(
                margin: const EdgeInsets.only(top: 4), 
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), 
                decoration: BoxDecoration(
                  color: (isConfirmed ? AppColors.success : AppColors.warning).withOpacity(0.1), 
                  borderRadius: BorderRadius.circular(4),
                ), 
                child: Text(
                  isConfirmed ? '已确认' : '待确认', 
                  style: TextStyle(fontSize: 11, color: isConfirmed ? AppColors.success : AppColors.warning),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
