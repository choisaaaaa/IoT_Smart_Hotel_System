import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class HotelEditPage extends StatefulWidget {
  const HotelEditPage({super.key});

  @override
  State<HotelEditPage> createState() => _HotelEditPageState();
}

class _HotelEditPageState extends State<HotelEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: '智联酒店');
  final _addressController = TextEditingController(text: '深圳市南山区科技园路1000号');
  final _phoneController = TextEditingController(text: '0755-88888888');

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
      appBar: AppBar(title: const Text('酒店信息编辑'), actions: [TextButton(onPressed: _save, child: const Text('保存', style: TextStyle(color: Colors.white)))]),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Stack(alignment: Alignment.bottomRight, children: [
                Container(width: 120, height: 120, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.hotel, size: 48, color: AppColors.textHint)),
                Positioned(bottom: -4, right: -4, child: FloatingActionButton.small(onPressed: () {}, child: const Icon(Icons.camera_alt))),
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
              onChanged: (_) {},
              initialValue: '5',
            ),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 48, child: FilledButton(onPressed: _save, child: const Text('保存修改', style: TextStyle(fontSize: 16)))),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存成功')));
    }
  }
}
