import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../routes/app_router.dart';

class BookingFlowPage extends ConsumerStatefulWidget {
  final String hotelName;
  final String roomType;
  final double price;
  final int roomId;

  const BookingFlowPage({
    super.key,
    required this.hotelName,
    required this.roomType,
    required this.price,
    required this.roomId,
  });

  @override
  ConsumerState<BookingFlowPage> createState() => _BookingFlowPageState();
}

class _BookingFlowPageState extends ConsumerState<BookingFlowPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idNumberController = TextEditingController();
  bool _isLoading = false;
  int _roomCount = 1;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final user = await ref.read(authServiceProvider).getCurrentUser();
    if (user != null) {
      _nameController.text = user.username;
      // 手机号和身份证通常从用户信息中获取，这里模拟
      _phoneController.text = '18675064262';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  Future<void> _submitBooking() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写完整的入住信息')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      
      final result = await ref.read(bookingServiceProvider).createBooking({
        'room_id': widget.roomId,
        'guest_name': _nameController.text.trim(),
        'guest_phone': _phoneController.text.trim(),
        'guest_id_number': _idNumberController.text.trim(),
        'check_in_date': now.toIso8601String().split('T')[0],
        'check_out_date': tomorrow.toIso8601String().split('T')[0],
        'guest_count': _roomCount,
        'payment_method': 'online',
        'special_requests': '',
      });

      if (!mounted) return;

      if (result.success) {
        _showSuccessDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '预订失败')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('预订异常：$e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('预订成功'),
        content: const Text('您的订单已提交，请在我的订单中查看详情并支付。'),
        actions: [
          TextButton(
            onPressed: () {
              ctx.pop();
              context.go('/orders');
            },
            child: const Text('查看订单', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              ctx.pop();
              context.go('/');
            },
            child: const Text('返回首页'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20), onPressed: () => context.pop()),
        title: Text(widget.hotelName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildBookingInfo(),
            _buildGuestInfo(),
            _buildCouponSection(),
            _buildMemberBenefits(),
            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomSheet: _buildBottomPayBar(),
    );
  }

  Widget _buildBookingInfo() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('4月08日 今天 - 4月09日 明天', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(width: 8),
              Text('1晚', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              Spacer(),
              Text('房型详情', style: TextStyle(color: AppColors.primary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text('${widget.roomType} | 金会员9倍积分房', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const Text('28-30m² | 2张1.35米床 | 外景窗', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const Divider(height: 32),
          const Text('4月8日 18:00 前可免费取消，18:00 后不可取消', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildGuestInfo() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              const Text('订房信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              const Text('30秒入住 >', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: AppColors.textHint),
                onPressed: _roomCount > 1 ? () => setState(() => _roomCount--) : null,
              ),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('$_roomCount间', style: const TextStyle(fontWeight: FontWeight.bold))),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                onPressed: () => setState(() => _roomCount++),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _InfoInputRow(label: '入住人', controller: _nameController, hint: '请输入姓名'),
          _InfoInputRow(label: '联系手机', controller: _phoneController, hint: '请输入手机号', keyboardType: TextInputType.phone),
          _InfoInputRow(label: '身份证号', controller: _idNumberController, hint: '请输入身份证号以便快速入住'),
        ],
      ),
    );
  }

  Widget _buildCouponSection() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('订房优惠', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('优惠券', style: TextStyle(fontSize: 14)),
              Text('暂无可用 >', style: TextStyle(color: AppColors.textHint, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberBenefits() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('会员权益', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildBenefitRow(Icons.timer_outlined, '延迟退房', '金会员可延迟至14:00退房'),
          _buildBenefitRow(Icons.local_cafe_outlined, '免费早餐', '金会员享用双人精美早餐'),
          _buildBenefitRow(Icons.auto_awesome_outlined, '积分加速', '本订单可获得约2295积分'),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.gold),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildBottomPayBar() {
    final totalPrice = widget.price * _roomCount;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('合计 ', style: TextStyle(fontSize: 12)),
                    Text('¥${totalPrice.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.secondary, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    const Text('明细', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
                  ],
                ),
                const Text('已优惠 ¥34.00', style: TextStyle(color: AppColors.secondary, fontSize: 11)),
              ],
            ),
          ),
          SizedBox(
            width: 140,
            height: 48,
            child: FilledButton(
              onPressed: _isLoading ? null : _submitBooking,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('提交订单', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
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
