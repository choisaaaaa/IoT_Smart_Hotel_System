import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/booking_service.dart';

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
  String _arrivalTime = '';
  bool _isSearching = false;
  bool _isConfirming = false;
  Map<String, dynamic>? _foundBooking;
  String _roomPin = '';

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
        final data = result.data;
        if (data != null) {
          final booking = Map<String, dynamic>.from(data);
          if (!booking.containsKey('check_in_date') && booking.containsKey('check_in')) {
            booking['check_in_date'] = booking['check_in'];
          }
          if (!booking.containsKey('check_out_date') && booking.containsKey('check_out')) {
            booking['check_out_date'] = booking['check_out'];
          }
          if (!booking.containsKey('booking_number') && booking.containsKey('booking_no')) {
            booking['booking_number'] = booking['booking_no'];
          }
          if (!booking.containsKey('room_type') && booking.containsKey('room_name')) {
            booking['room_type'] = booking['room_name'];
          }
          if (!booking.containsKey('room_number') && booking.containsKey('room_name')) {
            booking['room_number'] = booking['room_name'];
          }
          setState(() {
            _foundBooking = booking;
            _realNameController.text = booking['guest_name']?.toString() ?? '';
          });
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('未找到匹配的预订')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('查询失败：$e')));
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _confirmCheckin() async {
    if (_foundBooking == null) return;
    if (_realNameController.text.isEmpty || _idNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写完整实名信息')));
      return;
    }

    setState(() => _isConfirming = true);
    try {
      final bookingId = _foundBooking!['id'] as int? ?? widget.bookingId ?? 0;
      final result = await ref.read(bookingServiceProvider).checkinOnline(bookingId, {
        'guest_phone': _foundBooking!['guest_phone']?.toString() ?? '',
        'real_name': _realNameController.text.trim(),
        'id_type': _idType,
        'id_number': _idNumberController.text.trim(),
        'arrival_time': _arrivalTime,
        'plate_number': _plateController.text.trim(),
      });

      if (result.success && mounted) {
        final data = result.data;
        setState(() {
          _roomPin = data?['room_pin']?.toString() ?? '';
          // 更新房间信息
          if (_foundBooking != null && data != null) {
            _foundBooking!['room_name'] = data['room_name'];
            _foundBooking!['room_number'] = data['room_number'];
            _foundBooking!['status'] = 'checked_in';
          }
          _currentStep = 3;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '办理失败')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('办理异常：$e')));
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
                  color: _foundBooking!['status'] == 'checked_in'
                      ? AppColors.info.withValues(alpha: 0.05)
                      : AppColors.success.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _foundBooking!['status'] == 'checked_in'
                        ? AppColors.info.withValues(alpha: 0.2)
                        : AppColors.success.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(
                        _foundBooking!['status'] == 'checked_in' ? Icons.info : Icons.check_circle,
                        color: _foundBooking!['status'] == 'checked_in' ? AppColors.info : AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _foundBooking!['status'] == 'checked_in'
                            ? '该预订已办理入住'
                            : _foundBooking!['status'] == 'pending'
                                ? '该预订尚未支付'
                                : '找到您的预订！',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Text('${_foundBooking!['guest_name'] ?? '-'} · ${_foundBooking!['room_type'] ?? _foundBooking!['room_name'] ?? '-'} · ${_foundBooking!['check_in_date'] ?? ''} 至 ${_foundBooking!['check_out_date'] ?? ''}'),
                    if (_foundBooking!['status'] == 'checked_in') ...[
                      const SizedBox(height: 8),
                      Text('房间号：${_foundBooking!['room_number'] ?? _foundBooking!['room_id'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_foundBooking!['status'] == 'confirmed') ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => setState(() => _currentStep = 1),
                    child: const Text('下一步：填写入住信息'),
                  ),
                ),
              ] else if (_foundBooking!['status'] == 'checked_in') ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => context.go('/room-service'),
                    child: const Text('前往客房服务'),
                  ),
                ),
              ] else if (_foundBooking!['status'] == 'pending') ...[
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
              child: Text('正在为 ${_foundBooking?['guest_name'] ?? '-'} 办理 ${_foundBooking?['room_type'] ?? '-'} 入住', style: TextStyle(fontSize: 13, color: AppColors.primary)),
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
                          DropdownMenuItem(value: 'idcard', child: Text('身份证')),
                          DropdownMenuItem(value: 'passport', child: Text('护照')),
                        ],
                        onChanged: (v) => setState(() => _idType = v ?? 'idcard'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInputField('证件号码', _idNumberController, '请输入证件号码'),
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
                      if (_realNameController.text.isEmpty || _idNumberController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写完整实名信息')));
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

  Widget _buildInputField(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
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
            _buildConfirmRow('预订号', '${_foundBooking?['id'] ?? '-'}'),
            _buildConfirmRow('房间', '${_foundBooking?['room_type'] ?? '-'}'),
            _buildConfirmRow('入住日期', '${_foundBooking?['check_in_date'] ?? '-'}'),
            _buildConfirmRow('退房日期', '${_foundBooking?['check_out_date'] ?? '-'}'),
            _buildConfirmRow('客人姓名', _realNameController.text),
            _buildConfirmRow('证件类型', _idType == 'idcard' ? '身份证' : '护照'),
            _buildConfirmRow('证件号码', _idNumberController.text),
            if (_plateController.text.isNotEmpty)
              _buildConfirmRow('车牌号', _plateController.text),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => setState(() => _currentStep = 1), child: const Text('返回修改'))),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _isConfirming ? null : _confirmCheckin,
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

  Widget _buildStep3() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.check_circle, color: AppColors.success, size: 64),
            const SizedBox(height: 16),
            const Text('在线入住办理成功！', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('您的房间已准备就绪，到店后请向前台出示此页面领取房卡。', style: TextStyle(color: AppColors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
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
                  const Text('入住房间', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    _foundBooking?['room_name'] ?? _foundBooking?['room_number'] ?? '${_foundBooking?['room_id'] ?? '-'}号房',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  if (_roomPin.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('房卡密码：$_roomPin', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ],
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
          ],
        ),
      ),
    );
  }
}
