import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/hotel_service.dart';

class HotelEditPage extends ConsumerStatefulWidget {
  const HotelEditPage({super.key});

  @override
  ConsumerState<HotelEditPage> createState() => _HotelEditPageState();
}

class _HotelEditPageState extends ConsumerState<HotelEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: '智联酒店');
  final _addressController = TextEditingController(text: '深圳市南山区科技园路1000号');
  final _phoneController = TextEditingController(text: '0755-88888888');
  String _selectedStar = '5';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadHotelInfo();
  }

  Future<void> _loadHotelInfo() async {
    try {
      final result = await ref.read(hotelServiceProvider).getHotelInfo();
      if (result.success && mounted) {
        final data = result.data ?? {};
        setState(() {
          _nameController.text = data['hotel_name'] ?? data['name'] ?? '智联酒店';
          _addressController.text = data['hotel_address'] ?? data['address'] ?? '';
          _phoneController.text = data['hotel_phone'] ?? data['phone'] ?? '';
          _selectedStar = (data['hotel_star'] ?? data['star_rating'] ?? '5').toString();
        });
      }
    } catch (e) {
      debugPrint('Error loading hotel info: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('酒店信息编辑'), actions: [TextButton(onPressed: _save, child: Text(_isSaving ? '保存中...' : '保存', style: TextStyle(color: Colors.white)))]),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Stack(alignment: Alignment.bottomRight, children: [
                Container(width: 120, height: 120, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.hotel, size: 48, color: AppColors.textHint)),
                Positioned(bottom: -4, right: -4, child: FloatingActionButton.small(onPressed: () => _pickImage(), child: const Icon(Icons.camera_alt))),
              ]),
            ),
            const SizedBox(height: 24),
            TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: '酒店名称 *', prefixIcon: Icon(Icons.business)), validator: (v) => v!.isEmpty ? '请输入酒店名称' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _addressController, decoration: const InputDecoration(labelText: '地址', prefixIcon: Icon(Icons.location_on)), maxLines: 2),
            const SizedBox(height: 16),
            TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: '联系电话', prefixIcon: Icon(Icons.phone))),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: '星级', prefixIcon: Icon(Icons.star)),
              items: ['1','2','3','4','5'].map((s) => DropdownMenuItem(value: s, child: Text('$s星级'))).toList(),
              onChanged: (value) => setState(() => _selectedStar = value!),
              value: _selectedStar,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('保存修改', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('图片上传功能待接入')));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final result = await ref.read(hotelServiceProvider).updateHotelInfo({
        'hotel_name': _nameController.text.trim(),
        'hotel_address': _addressController.text.trim(),
        'hotel_phone': _phoneController.text.trim(),
        'hotel_star': int.tryParse(_selectedStar) ?? 5,
      });

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('酒店信息保存成功'), backgroundColor: AppColors.success));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message ?? '保存失败')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存异常：$e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
