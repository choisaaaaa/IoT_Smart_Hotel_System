import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../services/booking_service.dart';
import '../../models/booking.dart';

class OnlineCheckinPage extends ConsumerStatefulWidget {
  final int? bookingId;

  const OnlineCheckinPage({super.key, this.bookingId});

  @override
  ConsumerState<OnlineCheckinPage> createState() => _OnlineCheckinPageState();
}

class _OnlineCheckinPageState extends ConsumerState<OnlineCheckinPage> {
  int _currentStep = 0;
  final _searchController = TextEditingController();
  final _realNameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _plateController = TextEditingController();
  String _idType = 'idcard';
  String _arrivalTime = '14:00';
  bool _isSearching = false;
  bool _isConfirming = false;
  Booking? _foundBooking;
  String _roomPin = '';
  bool _agreedToTerms = false;

  final List<String> _arrivalTimeOptions = [
    '12:00', '13:00', '14:00', '15:00', '16:00',
    '17:00', '18:00', '19:00', '20:00', '21:00', '22:00',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.bookingId != null) {
      _searchController.text = widget.bookingId.toString();
      _searchBooking();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _realNameController.dispose();
    _idNumberController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _searchBooking() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入预订号或手机号')));
      return;
    }

    setState(() => _isSearching = true);
    try {
      final result = await ref.read(bookingServiceProvider).lookupBooking(keyword);
      if (result.success && mounted) {
        final booking = result.data;
        if (booking != null) {
          setState(() {
            _foundBooking = booking;
            _realNameController.text = booking.guestName ?? '';
          });
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('未找到匹配的预订')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('查询失败，请重试')));
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  bool _validateIdNumber() {
    final idNumber = _idNumberController.text.trim();
    if (idNumber.isEmpty) return false;
    if (_idType == 'idcard') {
      return idNumber.length == 18 && RegExp(r'^\d{17}[\dXx]$').hasMatch(idNumber);
    }
    return idNumber.length >= 5;
  }

  Future<void> _confirmCheckin() async {
    if (_foundBooking == null) return;
    if (_realNameController.text.isEmpty || _idNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写完整实名信息')));
      return;
    }
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请阅读并同意入住条款')));
      return;
    }

    setState(() => _isConfirming = true);
    try {
      final bookingId = _foundBooking!.id;
      final result = await ref.read(bookingServiceProvider).checkinOnline(bookingId, {
        'guest_phone': _foundBooking!.guestPhone ?? '',
        'real_name': _realNameController.text.trim(),
        'id_type': _idType,
        'id_number': _idNumberController.text.trim(),
        'arrival_time': _arrivalTime,
        'plate_number': _plateController.text.trim(),
      });

      if (result.success && mounted) {
        final data = result.data;
        setState(() {
          _roomPin = data?.roomNumber ?? '';
          _currentStep = 3;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '办理失败')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('办理失败，请重试')));
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('在线办理入住', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.primary.withValues(alpha: 0.05),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '如果您已完成预订，可在此提前办理入住手续，到店后直接领取房卡即可。',
                    style: TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: List.generate(4, (i) {
                final labels = ['验证预订', '填写信息', '确认提交', '办理完成'];
                final isActive = i <= _currentStep;
                return Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isActive ? AppColors.primary : AppColors.divider,
                              ),
                              child: Center(
                                child: i < _currentStep
                                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                                    : Text('${i + 1}', style: TextStyle(color: isActive ? Colors.white : AppColors.textHint, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(labels[i], style: TextStyle(fontSize: 10, color: isActive ? AppColors.primary : AppColors.textHint)),
                          ],
                        ),
                      ),
                      if (i < 3)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i < _currentStep ? AppColors.primary : AppColors.divider,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildStepContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0: return _buildStep0();
      case 1: return _buildStep1();
      case 2: return _buildStep2();
      case 3: return _buildStep3();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildStep0() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('步骤1: 验证预订信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '输入预订号或预留手机号',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: _isSearching ? null : _searchBooking,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onSubmitted: (_) => _searchBooking(),
            ),
            const SizedBox(height: 20),
            if (_isSearching)
              const Center(child: CircularProgressIndicator())
            else if (_foundBooking != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _foundBooking!.status == 'checked_in'
                      ? AppColors.info.withValues(alpha: 0.05)
                      : AppColors.success.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _foundBooking!.status == 'checked_in'
                        ? AppColors.info.withValues(alpha: 0.2)
                        : AppColors.success.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(
                        _foundBooking!.status == 'checked_in' ? Icons.info : Icons.check_circle,
                        color: _foundBooking!.status == 'checked_in' ? AppColors.info : AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _foundBooking!.status == 'checked_in'
                            ? '该预订已办理入住'
                            : _foundBooking!.status == 'pending'
                                ? '该预订尚未支付'
                                : '找到您的预订！',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _buildBookingInfoRow(Icons.person_outline, '入住人', _foundBooking!.guestName ?? '-'),
                    _buildBookingInfoRow(Icons.bed_outlined, '房型', _foundBooking!.displayRoomType),
                    _buildBookingInfoRow(Icons.calendar_today_outlined, '入住日期',
                      '${DateFormat('yyyy-MM-dd').format(_foundBooking!.checkInDate)} 至 ${DateFormat('yyyy-MM-dd').format(_foundBooking!.checkOutDate)}'),
                    _buildBookingInfoRow(Icons.nightlight_outlined, '入住天数', '${_foundBooking!.nights}晚'),
                    if (_foundBooking!.status == 'checked_in') ...[
                      const SizedBox(height: 8),
                      _buildBookingInfoRow(Icons.meeting_room_outlined, '房间号', _foundBooking!.roomNumber ?? '${_foundBooking!.roomId}号房'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_foundBooking!.status == 'confirmed') ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => setState(() => _currentStep = 1),
                    child: const Text('下一步：填写入住信息'),
                  ),
                ),
              ] else if (_foundBooking!.status == 'pre_checked_in') ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => setState(() => _currentStep = 1),
                    child: const Text('继续完善入住信息'),
                  ),
                ),
              ] else if (_foundBooking!.status == 'checked_in') ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => context.go('/room-service', extra: {'bookingId': widget.bookingId}),
                    child: const Text('前往客房服务'),
                  ),
                ),
              ] else if (_foundBooking!.status == 'pending') ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => context.go('/orders'),
                    child: const Text('前往订单支付'),
                  ),
                ),
              ],
            ] else ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.search_off, size: 48, color: AppColors.textHint.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      const Text('请输入预订号或手机号查询', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBookingInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('步骤2: 填写入住信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('正在为 ${_foundBooking?.guestName ?? '-'} 办理 ${_foundBooking?.displayRoomType ?? '-'} 入住', style: TextStyle(fontSize: 13, color: AppColors.primary)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildInputField('真实姓名', _realNameController, '与证件一致')),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('证件类型', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: _idType,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'idcard', child: Text('身份证/永居证/居住证')),
                          DropdownMenuItem(value: 'hkm_pass', child: Text('港澳居民来往内地通行证')),
                          DropdownMenuItem(value: 'taiwan_pass', child: Text('台湾居民来往大陆通行证')),
                          DropdownMenuItem(value: 'passport', child: Text('外国护照')),
                          DropdownMenuItem(value: 'other', child: Text('其他')),
                        ],
                        onChanged: (v) => setState(() => _idType = v ?? 'idcard'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInputField(
              '证件号码',
              _idNumberController,
              _idType == 'idcard' ? '请输入18位身份证号' : '请输入证件号码',
              keyboardType: TextInputType.text,
            ),
            if (_idType == 'idcard' && _idNumberController.text.isNotEmpty && !_validateIdNumber())
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('请输入正确的18位身份证号', style: TextStyle(fontSize: 12, color: AppColors.error)),
              ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('预计到达时间', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _arrivalTime,
                      isExpanded: true,
                      icon: const Icon(Icons.access_time, size: 20),
                      items: _arrivalTimeOptions.map((time) => DropdownMenuItem(
                        value: time,
                        child: Text(time),
                      )).toList(),
                      onChanged: (v) => setState(() => _arrivalTime = v ?? '14:00'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInputField('车牌号（可选）', _plateController, '如需停车请填写'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => setState(() => _currentStep = 0), child: const Text('上一步'))),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (_realNameController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写真实姓名')));
                        return;
                      }
                      if (_idNumberController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写证件号码')));
                        return;
                      }
                      if (_idType == 'idcard' && !_validateIdNumber()) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入正确的身份证号')));
                        return;
                      }
                      setState(() => _currentStep = 2);
                    },
                    child: const Text('下一步：确认'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, String hint, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('步骤3: 确认信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildConfirmRow('预订号', _foundBooking?.displayBookingNumber ?? '-'),
            _buildConfirmRow('酒店', _foundBooking?.hotelName ?? '智联酒店'),
            _buildConfirmRow('房间', _foundBooking?.displayRoomType ?? '-'),
            _buildConfirmRow('入住日期', DateFormat('yyyy-MM-dd').format(_foundBooking?.checkInDate ?? DateTime.now())),
            _buildConfirmRow('退房日期', DateFormat('yyyy-MM-dd').format(_foundBooking?.checkOutDate ?? DateTime.now().add(const Duration(days: 1)))),
            _buildConfirmRow('入住天数', '${_foundBooking?.nights ?? 1}晚'),
            const Divider(height: 24),
            _buildConfirmRow('客人姓名', _realNameController.text),
            _buildConfirmRow('证件类型', _idType == 'idcard' ? '身份证' : _idType == 'passport' ? '护照' : '港澳通行证'),
            _buildConfirmRow('证件号码', _maskIdNumber(_idNumberController.text)),
            _buildConfirmRow('预计到达', _arrivalTime),
            if (_plateController.text.isNotEmpty)
              _buildConfirmRow('车牌号', _plateController.text),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '请确保信息准确，到店后需出示有效证件核实。如信息有误可能影响入住。',
                      style: TextStyle(fontSize: 12, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _agreedToTerms,
                    onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                    activeColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showTermsDialog(),
                    child: Text.rich(
                      TextSpan(
                        text: '我已阅读并同意 ',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        children: [
                          TextSpan(text: '《入住条款》', style: TextStyle(fontSize: 12, color: AppColors.primary, decoration: TextDecoration.underline)),
                          TextSpan(text: ' 和 ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          TextSpan(text: '《隐私政策》', style: TextStyle(fontSize: 12, color: AppColors.primary, decoration: TextDecoration.underline)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => setState(() => _currentStep = 1), child: const Text('返回修改'))),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: (_agreedToTerms && !_isConfirming) ? _confirmCheckin : null,
                    child: _isConfirming
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('确认办理入住'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  String _maskIdNumber(String idNumber) {
    if (idNumber.length <= 10) return idNumber;
    return '${idNumber.substring(0, 6)}********${idNumber.substring(14)}';
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('入住条款'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('1. 入住时需出示有效身份证件进行实名登记。', style: TextStyle(fontSize: 13, height: 1.6)),
              Text('2. 入住时间一般为14:00后，退房时间为次日12:00前。', style: TextStyle(fontSize: 13, height: 1.6)),
              Text('3. 请爱护房间内设施设备，如有损坏需照价赔偿。', style: TextStyle(fontSize: 13, height: 1.6)),
              Text('4. 酒店内禁止吸烟，违者将按相关规定处理。', style: TextStyle(fontSize: 13, height: 1.6)),
              Text('5. 请勿在房间内进行违法活动，否则酒店有权报警处理。', style: TextStyle(fontSize: 13, height: 1.6)),
              Text('6. 贵重物品请寄存前台，遗失酒店不承担责任。', style: TextStyle(fontSize: 13, height: 1.6)),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('我已知晓'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
            ),
            const SizedBox(height: 16),
            const Text('预入住申请已提交！', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('您的入住信息已提交，请等待前台核实后完成正式入住。', style: TextStyle(color: AppColors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '到店后请向前台出示身份证件进行核实，核实通过后即可领取房卡正式入住。',
                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  const Text('预订房间', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    _foundBooking?.roomName ?? _foundBooking?.roomNumber ?? '${_foundBooking?.roomId ?? '-'}号房',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  if (_roomPin.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('临时密码：$_roomPin', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildQuickAction(Icons.room_service_outlined, '客房服务', () => context.go('/room-service', extra: {'bookingId': _foundBooking?.id})),
                      const SizedBox(width: 32),
                      _buildQuickAction(Icons.smart_toy_outlined, 'AI管家', () => context.go('/ai-butler', extra: {'bookingId': _foundBooking?.id})),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('返回首页'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => context.go('/orders'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
                child: const Text('查看我的订单'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
