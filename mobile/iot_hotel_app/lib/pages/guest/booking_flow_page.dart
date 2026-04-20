import 'package:flutter/material.dart' hide DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/date_utils.dart';
import '../../core/theme/app_colors.dart';
import '../../core/logic/member_logic.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';
import '../../services/auth_service.dart';
import '../../services/booking_service.dart';
import '../../services/hotel_service.dart';
import '../../services/member_service.dart';
import '../../services/payment_service.dart';
import '../../models/coupon.dart';
import '../../models/frequent_guest.dart';
import '../../models/member.dart';
import '../../models/room.dart';

class BookingFlowPage extends ConsumerStatefulWidget {
  final String hotelName;
  final String roomType;
  final double price;
  final int roomId;
  final int hotelId;
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final int? roomTypeId;

  const BookingFlowPage({
    super.key,
    required this.hotelName,
    required this.roomType,
    required this.price,
    required this.roomId,
    required this.hotelId,
    required this.checkInDate,
    required this.checkOutDate,
    this.roomTypeId,
  });

  @override
  ConsumerState<BookingFlowPage> createState() => _BookingFlowPageState();
}

class _BookingFlowPageState extends ConsumerState<BookingFlowPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _specialRequestController = TextEditingController();
  bool _isLoading = false;
  final int _roomCount = 1;
  List<Coupon> _coupons = [];
  Coupon? _selectedCoupon;
  List<Room> _availableRooms = [];
  Room? _selectedRoom;
  bool _isLoadingRooms = false;
  String _paymentMethod = 'balance';
  Map<String, dynamic>? _priceDetails;
  bool _usePoints = false;
  int _pointsToUse = 0;
  Member? _member;
  List<FrequentGuest> _frequentGuests = [];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadMemberInfo();
    _loadCoupons();
    _loadAvailableRooms();
    _loadFrequentGuests();
    _calculatePrice();
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    if (_phoneController.text.trim().length >= 11) {
      _calculatePrice();
    }
  }

  Future<void> _loadAvailableRooms() async {
    setState(() => _isLoadingRooms = true);
    try {
      List<Room> availableRooms = [];

      debugPrint('DEBUG: _loadAvailableRooms - hotelId=${widget.hotelId}, roomType=${widget.roomType}, roomTypeId=${widget.roomTypeId}');

      // 直接使用 getHotelRooms 获取酒店的所有房间
      final roomsResult = await ref.read(hotelServiceProvider).getHotelRooms(widget.hotelId);
      debugPrint('DEBUG: _loadAvailableRooms - roomsResult.success=${roomsResult.success}, data.length=${roomsResult.data?.length ?? 0}');
      
      if (roomsResult.success && roomsResult.data != null) {
        final allRooms = roomsResult.data!;
        debugPrint('DEBUG: _loadAvailableRooms - allRooms.length=${allRooms.length}');
        
        // 打印所有房间信息用于调试
        for (final r in allRooms) {
          debugPrint('DEBUG: Room - id=${r.id}, number=${r.roomNumber}, type=${r.roomType}, status=${r.roomStatus}, roomTypeId=${r.roomTypeId}');
        }
        
        // 过滤出可用状态且匹配当前房型的房间
        availableRooms = allRooms.where((r) {
          // 只显示可用房间
          final isAvailable = r.roomStatus == 'available' || r.roomStatus == 'clean' || r.roomStatus.isEmpty;
          final typeMatch = widget.roomTypeId != null && r.roomTypeId == widget.roomTypeId;
          final typeName = r.roomName ?? r.roomType;
          final nameMatch = typeName == widget.roomType || typeName.contains(widget.roomType);
          
          debugPrint('DEBUG: Filter - roomId=${r.id}, isAvailable=$isAvailable, typeMatch=$typeMatch, nameMatch=$nameMatch, typeName=$typeName');
          
          return isAvailable && (typeMatch || nameMatch);
        }).toList();
        
        debugPrint('DEBUG: _loadAvailableRooms - availableRooms.length=${availableRooms.length}');
      }

      if (mounted) {
        setState(() {
          _availableRooms = availableRooms;
          if (availableRooms.isNotEmpty) {
            if (widget.roomId > 0) {
              final initial = availableRooms.where((r) => r.id == widget.roomId).toList();
              _selectedRoom = initial.isNotEmpty ? initial.first : availableRooms.first;
            } else {
              _selectedRoom = availableRooms.first;
            }
          }
        });
        _calculatePrice();
      }
    } catch (e) {
      debugPrint('loadAvailableRooms: $e');
    } finally {
      if (mounted) setState(() => _isLoadingRooms = false);
    }
  }

  void _showRoomSelector() {
    if (_availableRooms.isEmpty && !_isLoadingRooms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无更多可选房间')));
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('选择具体房间', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_isLoadingRooms)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _availableRooms.map((room) {
                  final isSelected = _selectedRoom?.id == room.id;
                  return ChoiceChip(
                    label: Text('${room.roomNumber}号房'),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedRoom = room);
                        _calculatePrice();
                        Navigator.pop(ctx);
                      }
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  double _safeToDouble(dynamic v) { if (v is num) return v.toDouble(); if (v is String) return double.tryParse(v) ?? 0.0; return 0.0; }

  Future<void> _loadFrequentGuests() async {
    try {
      final dio = DioClient();
      final response = await dio.get(ApiConstants.frequentGuests);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final responseData = response.data['data'];
        final guestsList = responseData is Map ? responseData['guests'] : responseData;
        if (guestsList is List && mounted) {
          setState(() => _frequentGuests = guestsList.map((g) => FrequentGuest.fromJson(g as Map<String, dynamic>)).toList());
        }
      }
    } catch (e) {
      debugPrint('加载常住人失败: $e');
    }
  }

  void _fillFrequentGuest(FrequentGuest guest) {
    setState(() {
      _nameController.text = guest.name;
      _phoneController.text = guest.phone ?? '';
      _idNumberController.text = guest.idNumber;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已选择：${guest.name}')),
    );
  }

  Widget _buildPointsInputSection() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              const Text('使用积分', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const Spacer(),
              Container(
                width: 120,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _pointsToUse = (_pointsToUse - 100).clamp(0, _member?.points ?? 0);
                        });
                        _calculatePrice();
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        child: const Icon(Icons.remove, size: 18, color: AppColors.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: '0',
                        ),
                        controller: TextEditingController(text: _pointsToUse.toString()),
                        onChanged: (value) {
                          final points = int.tryParse(value) ?? 0;
                          setState(() {
                            _pointsToUse = points.clamp(0, _member?.points ?? 0);
                          });
                        },
                        onSubmitted: (_) => _calculatePrice(),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _pointsToUse = (_pointsToUse + 100).clamp(0, _member?.points ?? 0);
                        });
                        _calculatePrice();
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        child: const Icon(Icons.add, size: 18, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('全部', style: TextStyle(fontSize: 12)),
                backgroundColor: Colors.white,
                side: BorderSide(color: AppColors.divider),
                onPressed: () {
                  setState(() => _pointsToUse = _member?.points ?? 0);
                  _calculatePrice();
                },
              ),
              ActionChip(
                label: const Text('1000', style: TextStyle(fontSize: 12)),
                backgroundColor: Colors.white,
                side: BorderSide(color: AppColors.divider),
                onPressed: () {
                  setState(() => _pointsToUse = 1000.clamp(0, _member?.points ?? 0));
                  _calculatePrice();
                },
              ),
              ActionChip(
                label: const Text('5000', style: TextStyle(fontSize: 12)),
                backgroundColor: Colors.white,
                side: BorderSide(color: AppColors.divider),
                onPressed: () {
                  setState(() => _pointsToUse = 5000.clamp(0, _member?.points ?? 0));
                  _calculatePrice();
                },
              ),
              ActionChip(
                label: const Text('10000', style: TextStyle(fontSize: 12)),
                backgroundColor: Colors.white,
                side: BorderSide(color: AppColors.divider),
                onPressed: () {
                  setState(() => _pointsToUse = 10000.clamp(0, _member?.points ?? 0));
                  _calculatePrice();
                },
              ),
            ],
          ),
          if (_pointsToUse > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '可抵扣 ¥${(_pointsToUse / 10).toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  void _showPriceDetails() {
    final basePrice = _priceDetails != null ? _safeToDouble(_priceDetails!['base_price']) : widget.price * widget.checkOutDate.difference(widget.checkInDate).inDays;
    final memberDiscount = _priceDetails != null ? _safeToDouble(_priceDetails!['member_discount']) : 0.0;
    final couponDiscount = _priceDetails != null ? _safeToDouble(_priceDetails!['coupon_discount']) : 0.0;
    final pointsDiscount = _priceDetails != null ? _safeToDouble(_priceDetails!['points_discount']) : 0.0;
    final totalPrice = _priceDetails != null ? _safeToDouble(_priceDetails!['total_price']) : basePrice;
    final usedPoints = _priceDetails?['used_points'] is num ? (_priceDetails!['used_points'] as num).toInt() : 0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('价格明细', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildPriceDetailRow('房费总计', '¥${basePrice.toStringAsFixed(2)}'),
            if (memberDiscount > 0)
              _buildPriceDetailRow('会员优惠', '-¥${memberDiscount.toStringAsFixed(2)}', isDiscount: true),
            if (couponDiscount > 0)
              _buildPriceDetailRow('优惠券', '-¥${couponDiscount.toStringAsFixed(2)}', isDiscount: true),
            if (pointsDiscount > 0)
              _buildPriceDetailRow('积分抵扣', '-¥${pointsDiscount.toStringAsFixed(2)} ($usedPoints积分)', isDiscount: true),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('应付总额', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('¥${totalPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.secondary)),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceDetailRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: isDiscount ? Colors.red : AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 14, color: isDiscount ? Colors.red : AppColors.textPrimary, fontWeight: isDiscount ? FontWeight.w500 : FontWeight.normal)),
        ],
      ),
    );
  }

  Future<void> _calculatePrice() async {
    final phone = _phoneController.text.trim().isNotEmpty
        ? _phoneController.text.trim()
        : (await ref.read(authServiceProvider).getCurrentUser())?.phone;

    final targetRoomId = _selectedRoom?.id;
    if (targetRoomId == null || targetRoomId == 0) return;

    final result = await ref.read(bookingServiceProvider).calculatePrice(
          roomId: targetRoomId,
          checkInDate: widget.checkInDate,
          checkOutDate: widget.checkOutDate,
          guestPhone: phone,
          couponId: _selectedCoupon?.id,
          usedPoints: _usePoints ? _pointsToUse : 0,
        );

    if (result.success && mounted) {
      debugPrint('价格计算结果: ${result.data}');
      setState(() {
        _priceDetails = result.data;
      });
    } else if (mounted) {
      if (result.message?.contains('房间不存在') == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('获取房间信息失败，请尝试重新选择房间'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _loadMemberInfo() async {
    final result = await ref.read(memberServiceProvider).getMyAssets();
    if (result.success && mounted) {
      setState(() => _member = result.data);
    }
  }

  Future<void> _loadCoupons() async {
    try {
      final result = await ref.read(memberServiceProvider).getMyCoupons(
        hotelId: widget.hotelId,
      );
      if (result.success && mounted) {
        setState(() => _coupons = result.data ?? []);
      }
    } catch (e) {
      debugPrint('coupons: $e');
    } finally {
      if (mounted) setState(() {});
    }
  }

  void _showCouponSelector() async {
    final selected = await showModalBottomSheet<Coupon?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CouponBottomSheet(coupons: _coupons, selectedCoupon: _selectedCoupon),
    );

    if (mounted && selected != _selectedCoupon) {
      setState(() => _selectedCoupon = selected);
      _calculatePrice();
    }
  }

  Future<void> _loadUserInfo() async {
    final user = await ref.read(authServiceProvider).getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _nameController.text = user.username;
        _phoneController.text = '';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _idNumberController.dispose();
    _specialRequestController.dispose();
    super.dispose();
  }

  Future<void> _submitBookingAndPay() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写完整的入住信息')));
      return;
    }

    final targetRoomId = _selectedRoom?.id;

    if (targetRoomId == null || targetRoomId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先选择具体房间'), backgroundColor: AppColors.error));
      _showRoomSelector();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = await ref.read(authServiceProvider).getCurrentUser();
      final result = await ref.read(bookingServiceProvider).createBooking({
        'hotel_id': widget.hotelId,
        'room_id': targetRoomId,
        'room_type_id': widget.roomTypeId,
        'user_id': currentUser?.id,
        'guest_name': _nameController.text.trim(),
        'guest_phone': _phoneController.text.trim(),
        'guest_id_number': _idNumberController.text.trim(),
        'check_in_date': widget.checkInDate.toIso8601String().split('T')[0],
        'check_out_date': widget.checkOutDate.toIso8601String().split('T')[0],
        'guest_count': _roomCount,
        'payment_method': _paymentMethod,
        'special_requests': _specialRequestController.text.trim(),
        'coupon_id': _selectedCoupon?.id,
        'used_points': _usePoints ? _pointsToUse : 0,
        'status': 'pending',
      });

      if (!mounted) return;

      if (result.success) {
        final booking = result.data!;
        final orderId = booking.id;

        if (orderId == 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('订单ID无效')));
          }
          setState(() => _isLoading = false);
          return;
        }

        final totalPrice = _priceDetails?['total_price'] ?? booking.totalPrice;

        final createPayResult = await ref.read(paymentServiceProvider).createPayment({
          'order_type': 'booking',
          'order_id': orderId,
          'amount': totalPrice,
          'payment_method': _paymentMethod,
        });

        if (!createPayResult.success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(createPayResult.message ?? '创建支付订单失败')));
          }
          setState(() => _isLoading = false);
          return;
        }

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在确认支付状态...')));
        await Future.delayed(const Duration(seconds: 1));

        final paymentIdRaw = createPayResult.data?['id'];
        if (paymentIdRaw == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('支付订单创建异常，请稍后在订单中查看')));
          }
          setState(() => _isLoading = false);
          return;
        }
        final paymentId = paymentIdRaw is int ? paymentIdRaw : int.tryParse(paymentIdRaw.toString()) ?? 0;
        if (paymentId == 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('支付订单ID无效')));
          }
          setState(() => _isLoading = false);
          return;
        }
        final payResult = await ref.read(paymentServiceProvider).pay(paymentId);

        if (payResult.success && mounted) {
          _showSuccessDialog(booking.id, booking.displayBookingNumber);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(payResult.message ?? '支付确认失败，请稍后在订单中重试')));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '预订失败')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(int bookingId, String bookingNo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            SizedBox(width: 8),
            Text('预订并支付成功'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('预订编号：$bookingNo'),
            const SizedBox(height: 8),
            const Text('您的订单已生效，酒店将为您保留房间。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/orders');
            },
            child: const Text('查看订单', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/online-checkin/$bookingId', extra: {'bookingId': bookingId});
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('在线办理入住'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memberLevel = _member != null
        ? MemberLevel.fromKey(_member!.memberLevel)
        : MemberLevel.standard;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20), onPressed: () => context.pop()),
        title: const Text('确认订单', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildOrderSummaryCard(),
            _buildSectionCard('选择房间', [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('具体房间号', style: TextStyle(fontSize: 14)),
                subtitle: _selectedRoom != null
                    ? Text('${_selectedRoom!.roomNumber}号房 · ${_selectedRoom!.floor}层', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
                    : const Text('正在获取可用房间...', style: TextStyle(color: AppColors.textHint)),
                trailing: _isLoadingRooms
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_right, size: 20, color: AppColors.textHint),
                onTap: _showRoomSelector,
              ),
              const Text('温馨提示：您可以自由选择心仪的房间号进行预订', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
            ]),
            const SizedBox(height: 12),
            _buildSectionCard('入住人信息', [
              if (_frequentGuests.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('常用入住人', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          TextButton.icon(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                builder: (ctx) => Container(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('选择常住人', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 16),
                                      ..._frequentGuests.map((guest) => ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                          child: Text(guest.name.substring(0, 1), style: TextStyle(color: AppColors.primary)),
                                        ),
                                        title: Text(guest.name),
                                        subtitle: Text('${guest.idTypeLabel} ${guest.maskedIdNumber}'),
                                        trailing: const Icon(Icons.chevron_right),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          _fillFrequentGuest(guest);
                                        },
                                      )),
                                    ],
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.people_outline, size: 16),
                            label: const Text('选择', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _frequentGuests.take(3).map((guest) => ActionChip(
                          avatar: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            radius: 10,
                            child: Text(guest.name.substring(0, 1), style: TextStyle(fontSize: 10, color: AppColors.primary)),
                          ),
                          label: Text(guest.name, style: const TextStyle(fontSize: 12)),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: AppColors.divider),
                          padding: EdgeInsets.zero,
                          onPressed: () => _fillFrequentGuest(guest),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              _InfoInputRow(label: '姓名', controller: _nameController, hint: '请填写真实姓名'),
              _InfoInputRow(label: '手机号', controller: _phoneController, hint: '接收确认短信', keyboardType: TextInputType.phone),
              _InfoInputRow(label: '证件号码', controller: _idNumberController, hint: '请输入有效证件号'),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(value: true, onChanged: (v) {}, activeColor: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  const Text('保存到常用入住人名册', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ]),
            const SizedBox(height: 12),
            _buildSectionCard('特殊要求', [
              TextField(
                controller: _specialRequestController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: '如：高楼层、无烟房等',
                  hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _buildSectionCard('支付方式', [
              RadioGroup<String>(
                groupValue: _paymentMethod,
                onChanged: (v) { if (v != null) setState(() => _paymentMethod = v); },
                child: Column(
                  children: [
                    _buildPaymentOption('balance', Icons.account_balance_wallet_outlined, '余额支付 (推荐)', Colors.blue),
                    _buildPaymentOption('wechat', Icons.wechat_outlined, '微信支付', Colors.green),
                    _buildPaymentOption('alipay', Icons.payment_outlined, '支付宝', Colors.blueAccent),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _buildSectionCard('优惠与抵扣', [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('使用优惠券', style: TextStyle(fontSize: 14)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedCoupon != null
                          ? _selectedCoupon!.displayValue
                          : (_coupons.isNotEmpty ? '${_coupons.where((c) => c.isAvailable).length}张可用' : '无可用'),
                      style: TextStyle(
                        color: _selectedCoupon != null ? AppColors.secondary : AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20, color: AppColors.textHint),
                  ],
                ),
                onTap: _showCouponSelector,
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    const Text('积分抵扣', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: memberLevel.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${memberLevel.label} ${(_member?.points ?? 0) ~/ 10}元可抵',
                        style: TextStyle(color: memberLevel.color, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                subtitle: Text('可用 ${_member?.points ?? 0} 积分 (10积分=1元)', style: const TextStyle(fontSize: 12)),
                value: _usePoints,
                activeThumbColor: AppColors.primary,
                onChanged: (val) {
                  setState(() {
                    _usePoints = val;
                    if (val) {
                      final double basePrice = _priceDetails != null ? _safeToDouble(_priceDetails!['base_price']) : widget.price * widget.checkOutDate.difference(widget.checkInDate).inDays;
                      final double memberDiscount = _priceDetails != null ? _safeToDouble(_priceDetails!['member_discount']) : 0.0;
                      final double couponDiscount = _priceDetails != null ? _safeToDouble(_priceDetails!['coupon_discount']) : 0.0;
                      final double priceAfterDiscount = basePrice - memberDiscount - couponDiscount;
                      final int pointsNeeded = (priceAfterDiscount * 10).ceil();
                      final int availablePoints = _member?.points ?? 0;
                      _pointsToUse = pointsNeeded.clamp(0, availablePoints);
                    } else {
                      _pointsToUse = 0;
                    }
                  });
                  _calculatePrice();
                },
              ),
              if (_usePoints)
                _buildPointsInputSection(),
              if (memberLevel.discount < 1.0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: memberLevel.color.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: memberLevel.color.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.card_membership, color: memberLevel.color, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${memberLevel.label}专享 ${(memberLevel.discount * 10).toStringAsFixed(1)}折优惠',
                            style: TextStyle(color: memberLevel.color, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: _buildBottomPayBar(),
    );
  }

  Widget _buildOrderSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: const DecorationImage(
                    image: NetworkImage('https://images.unsplash.com/photo-1566073771259-6a8506099945?ixlib=rb-1.2.1&auto=format&fit=crop&w=200&q=80'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.hotelName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('${widget.roomType} · 1间', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDateItem('入住', widget.checkInDate),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${widget.checkOutDate.difference(widget.checkInDate).inDays}晚', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ),
              _buildDateItem('离店', widget.checkOutDate, isEnd: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateItem(String label, DateTime date, {bool isEnd = false}) {
    return Column(
      crossAxisAlignment: isEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(DateUtils.formatDashDate(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildBottomPayBar() {
    final basePrice = _priceDetails != null ? _safeToDouble(_priceDetails!['base_price']) : widget.price * widget.checkOutDate.difference(widget.checkInDate).inDays;
    final totalPrice = _priceDetails != null ? _safeToDouble(_priceDetails!['total_price']) : basePrice;
    final pointsUsed = _priceDetails?['used_points'] is num ? (_priceDetails!['used_points'] as num).toInt() : 0;
    final pointsDiscount = _priceDetails != null ? _safeToDouble(_priceDetails!['points_discount']) : 0.0;
    final couponDiscount = _priceDetails != null ? _safeToDouble(_priceDetails!['coupon_discount']) : 0.0;
    final memberLevel = MemberLevel.fromKey(_member?.memberLevel ?? 'standard');

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('总计', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _showPriceDetails,
                      child: Row(
                        children: [
                          Text(
                            '¥${totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(color: AppColors.secondary, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('明细', style: TextStyle(fontSize: 10, color: AppColors.primary)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (memberLevel.discount < 1.0)
                        _buildPriceTag('${memberLevel.label}${(memberLevel.discount * 10).toStringAsFixed(1)}折', AppColors.gold),
                      if (couponDiscount > 0)
                        _buildPriceTag('优惠券-¥${couponDiscount.toStringAsFixed(0)}', Colors.redAccent),
                      if (pointsUsed > 0)
                        _buildPriceTag('积分抵¥${pointsDiscount.toStringAsFixed(1)}', Colors.orange),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 140,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitBookingAndPay,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('立即预订', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceTag(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String value, IconData icon, String label, Color iconColor) {
    return InkWell(
      onTap: () => setState(() => _paymentMethod = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              activeColor: AppColors.primary,
            ),
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _InfoInputRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;

  const _InfoInputRow({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 14))),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponBottomSheet extends StatelessWidget {
  final List<Coupon> coupons;
  final Coupon? selectedCoupon;

  const _CouponBottomSheet({required this.coupons, this.selectedCoupon});

  @override
  Widget build(BuildContext context) {
    final availableCoupons = coupons.where((c) => c.isAvailable).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('选择优惠券', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('不使用优惠券'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: availableCoupons.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.confirmation_number_outlined, size: 48, color: AppColors.textHint.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          const Text('暂无可用优惠券', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: availableCoupons.length,
                      itemBuilder: (context, index) {
                        return _buildCouponItem(context, availableCoupons[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponItem(BuildContext context, Coupon coupon) {
    final isSelected = selectedCoupon?.id == coupon.id;

    return GestureDetector(
      onTap: () => Navigator.pop(context, coupon),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.secondary, AppColors.primary]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(coupon.displayValue, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(coupon.displayCondition, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(coupon.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('有效期至 ${coupon.displayExpiry}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 24)
            else
              Icon(Icons.circle_outlined, color: AppColors.textHint.withValues(alpha: 0.3), size: 24),
          ],
        ),
      ),
    );
  }
}
